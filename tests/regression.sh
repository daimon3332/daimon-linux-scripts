#!/usr/bin/env bash
set -o pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$ROOT/.tmp"
WORK=$(mktemp -d "$ROOT/.tmp/regression.XXXXXX") || exit 1
trap 'case "$WORK" in "$ROOT"/.tmp/regression.*) rm -rf -- "$WORK" ;; esac' EXIT
tr -d '\r' < "${DAIMON_TEST_SOURCE:-$ROOT/linux-toolbox.sh}" > "$WORK/source.sh"
SOURCE="$WORK/source.sh"
export TMPDIR="$WORK"
passed=0 failed=0

# Load definitions only: sourcing the toolbox itself would run system migrations.
load_function() {
    local name="$1" body
    body=$(awk -v name="$name" '
        $0 ~ "^[[:space:]]*" name "\\(\\) [({]" {
            active=1; match($0, /[^[:space:]]/); indent=substr($0, 1, RSTART-1)
            close_char=($0 ~ /\($/ ? ")" : "}")
        }
        active {print}
        active && $0 == indent close_char {exit}
    ' "$SOURCE")
    [ -n "$body" ] && bash -n <<< "$body" && eval "$body"
}

root_use() { :; }
clear() { :; }
send_stats() { :; }
break_end() { :; }

check() {
    local name="$1"; shift
    [[ "$name" == *"${DAIMON_TEST_FILTER:-}"* ]] || return 0
    if ( "$@" ) > "$WORK/test.out" 2>&1; then
        printf 'PASS %s\n' "$name"
        [ "${DAIMON_TEST_VERBOSE:-0}" = 1 ] && cat "$WORK/test.out"
        passed=$((passed + 1))
    else
        printf 'FAIL %s\n' "$name"
        cat "$WORK/test.out"
        failed=$((failed + 1))
    fi
}

for fn in validate_tcp_port validate_config_name daimon_strip_github_proxy \
    daimon_jsdelivr_url daimon_github_url_candidates daimon_download_to \
    daimon_migrate_path fix_dpkg add_swap delete_swap bitwarden_backup_data \
    rclone_install_tool daimon_network_verify_bbr_fq ufw_manager \
    one_click_config_manager restart_shell_after_tool_install kejilion_sh; do
    load_function "$fn" || exit 1
done
# Optional on the unfixed revision, required by its callers after the fix.
for fn in ssh_current_ports ufw_allow_current_ssh daimon_network_verify_active_fq \
    rclone_install_cn_release daimon_network_apply_custom_optimize \
    daimon_network_verify_sysctl_file handle_tool_numbers bitwarden_configure_rclone_conf; do
    load_function "$fn" || true
done

for fn in rclone_config_path rclone_restore_name_valid rclone_tree_safe rclone_assert_inactive rclone_require_space \
    rclone_nginx_prepare rclone_nginx_allow_ports rclone_nginx_cert_valid rclone_nginx_apply \
    rclone_check_nginx_after_restore; do
    load_function "$fn" || true
done

test_regions() {
    daimon_is_cn() { [ "$region" = CN ]; }
    local region url=https://github.com/rclone/rclone/releases/latest/download/version.txt result
    for region in CN HK SG ''; do
        result=$(daimon_github_url_candidates "$url")
        if [ "$region" = CN ]; then
            [[ "$result" == "https://gh-proxy.com/$url"$'\n'* ]] || return 1
        else
            [ "$result" = "$url" ] || return 1
        fi
    done
}
test_jsdelivr_refs() {
    [ "$(daimon_jsdelivr_url https://raw.githubusercontent.com/o/r/refs/heads/main/a.sh)" = \
      https://testingcf.jsdelivr.net/gh/o/r@main/a.sh ]
}
test_download_preserves_cache() {
    local target="$WORK/cache.sh"
    printf 'original\n' > "$target"
    daimon_github_url_candidates() { echo https://invalid.example/script; }
    curl() {
        while [ "$#" -gt 0 ]; do
            if [ "$1" = -o ]; then printf partial > "$2"; break; fi
            shift
        done
        return 28
    }
    wget() { printf partial > "$2"; return 1; }
    ! daimon_download_to https://invalid.example/script "$target" || return 1
    [ "$(cat "$target")" = original ]
}
test_migration_preserves_source() {
    local DAIMON_ROOT_DIR=/root/linux-daimon
    local trace="$WORK/migration.trace"
    : > "$trace"
    id() { echo 0; }
    function [() {
        if [[ "${1:-}" = '!' && "${2:-}" = -e && "${3:-}" = /root/linux-daimon/backup ]]; then return 1; fi
        case "${1:-}:${2:-}" in
            -e:/root/backup|-e:/root/linux-daimon/backup|-d:/root/backup|-d:/root/linux-daimon/backup) return 0 ;;
            -L:*) return 1 ;;
        esac
        builtin [ "$@"
    }
    mkdir() { :; }
    realpath() { printf '%s\n' "${@: -1}"; }
    cp() { echo copy >> "$trace"; return 1; }
    mv() { echo move >> "$trace"; return 1; }
    rm() { echo delete >> "$trace"; }
    daimon_migrate_path /root/backup /root/linux-daimon/backup || true
    ! grep -qE 'delete|move' "$trace"
}
test_package_lock() {
    local trace="$WORK/package.trace"
    : > "$trace"
    pkill() { echo kill >> "$trace"; }
    rm() { echo remove-lock >> "$trace"; }
    dpkg() { return 1; }
    ! fix_dpkg || return 1
    [ ! -s "$trace" ]
}
test_package_failure() {
    load_function install || return 1
    command() {
        if [ "${1:-}" = -v ]; then [ "$2" = apt ]; else builtin command "$@"; fi
    }
    apt() { [ "${*: -1}" != first ]; }
    ! install first second
}
test_cleanup_failure() {
    load_function linux_clean || return 1
    local manager="$1" failed=0 failure_at=1
    [ "$manager" != apt ] || failure_at=2
    command() {
        if [ "${1:-}" = -v ]; then
            [ "$2" = "$manager" ] || [ "$2" = journalctl ]
        else builtin command "$@"; fi
    }
    package() { failed=$((failed + 1)); [ "$failed" -ne "$failure_at" ]; }
    apt() { package "$@"; }
    dnf() { package "$@"; }
    yum() { package "$@"; }
    apk() { package "$@"; }
    pacman() { [ "${1:-}" = -Qdtq ] && { echo unused-package; return 0; }; package "$@"; }
    zypper() { package "$@"; }
    pkg() { package "$@"; }
    rpm() { :; }
    fix_dpkg() { :; }
    rm() { :; }
    journalctl() { :; }
    ! linux_clean
}
test_cleanup_boundaries() {
    load_function linux_clean || return 1
    local manager="$1" trace="$WORK/cleanup-$1.trace"
    : > "$trace"
    command() {
        if [ "${1:-}" = -v ]; then [ "$2" = "$manager" ]; else builtin command "$@"; fi
    }
    apk() { :; }
    opkg() { :; }
    pkg() { :; }
    rm() { printf '%s\n' "$*" >> "$trace"; }
    linux_clean || return 1
    [ ! -s "$trace" ]
}
test_cleanup_journal() {
    load_function linux_clean || return 1
    local trace="$WORK/journal-clean.trace"
    : > "$trace"
    command() {
        if [ "${1:-}" = -v ]; then [ "$2" = apt ] || [ "$2" = journalctl ]; else builtin command "$@"; fi
    }
    fix_dpkg() { :; }
    apt() { :; }
    journalctl() { printf '%s\n' "$*" >> "$trace"; }
    linux_clean || return 1
    ! grep -q -- '--vacuum-time=1s' "$trace" && grep -q -- '--vacuum-size=500M' "$trace"
}
test_submenu_eof() {
    local name="$1" count=0 sub_choice='' choice=''
    load_function "$name" || return 1
    crontab_sync_reconcile_legacy() { :; }
    add_swap() { return 77; }
    read() { count=$((count + 1)); [ "$count" -lt 3 ] || exit 77; return 1; }
    "$name" </dev/null
    [ "$count" -eq 1 ]
}
test_update_syntax() {
    load_function daimon_validate_update_file || return 1
    local fixture="$WORK/broken-update.sh"
    printf '#!/bin/bash\nDAIMON_NAME="linux-tools-daimon"\nif then\n' > "$fixture"
    ! daimon_validate_update_file "$fixture"
}
test_self_install_source() {
    load_function daimon_self_install || return 1
    local dir="$WORK/startup" DAIMON_LOCAL_SCRIPT="$WORK/startup/installed.sh"
    local DAIMON_OLD_LOCAL_SCRIPT="$WORK/startup/old.sh" DAIMON_UPDATE_URL=''
    mkdir -p "$dir"
    cd "$dir" || return 1
    printf '#!/bin/bash\necho unrelated\n' > linux-toolbox.sh
    printf '#!/bin/bash\necho installed\n' > "$DAIMON_LOCAL_SCRIPT"
    local trace="$WORK/self-install.trace"
    : > "$trace"
    sed() { :; }
    chmod() { :; }
    ln() { :; }
    cp() { echo "$*" >> "$trace"; }
    daimon_install_script_file() { echo "$*" >> "$trace"; }
    daimon_self_install || true
    ! grep -qE '(^| )\./linux-toolbox\.sh ' "$trace"
}
test_atomic_script_install() {
    load_function daimon_validate_update_file || return 1
    load_function daimon_install_script_file || return 1
    local source="$WORK/replacement.sh" target="$WORK/running.sh" original
    printf '#!/bin/bash\nDAIMON_NAME="linux-tools-daimon"\necho replacement\n' > "$source"
    printf 'original\n' > "$target"
    exec 3< "$target"
    daimon_install_script_file "$source" "$target" || return 1
    read -r original <&3
    exec 3<&-
    [ "$original" = original ] && cmp -s "$source" "$target"
}
test_ssh_key_names() {
    load_function ssh_private_key_name_valid || return 1
    local name
    for name in ../id /tmp/id authorized_keys known_hosts config id.pub . .. ''; do
        ! ssh_private_key_name_valid "$name" || return 1
    done
    ssh_private_key_name_valid id_ed25519
}
test_ssh_allow_order() {
    load_function ssh_config_manager || return 1
    local trace="$WORK/ssh-order.trace" count=0 SSH_CONNECTION='a 1 b 64400'
    : > "$trace"
    sshd() { echo 'port 64400'; }
    ss() { :; }
    ufw() { :; }
    read() {
        count=$((count + 1))
        case "$count" in
            1)
                ssh_config_backup() { :; }
                ssh_set_option() { echo write >> "$trace"; }
                ssh_restart_safe() { echo restart >> "$trace"; }
                ufw_allow_current_ssh() { echo allow >> "$trace"; return 1; }
                printf -v "${@: -1}" 1 ;;
            2) printf -v "${@: -1}" 64401 ;;
            *) printf -v "${@: -1}" 0 ;;
        esac
    }
    ssh_config_manager || return 1
    [ "$(cat "$trace")" = allow ]
}
test_shortcut_collision() {
    load_function linux_Settings || return 1
    load_function daimon_shortcut_available || true
    local trace="$WORK/shortcut.trace" count=0
    : > "$trace"
    find() { :; }
    ln() { echo overwrite >> "$trace"; }
    read() {
        count=$((count + 1))
        case "$count" in
            1) printf -v "${@: -1}" 1 ;;
            2) printf -v "${@: -1}" bash ;;
            *) printf -v "${@: -1}" 0 ;;
        esac
    }
    linux_Settings || return 1
    [ ! -s "$trace" ]
}
test_unmount_lookup() {
    load_function unmount_partition || return 1
    local trace="$WORK/unmount.trace"
    : > "$trace"
    read() { printf -v "${@: -1}" sdb1; }
    lsblk() { echo /mnt/data; }
    findmnt() { echo /mnt/data; }
    umount() { printf '%s\n' "$*" >> "$trace"; }
    rmdir() { echo remove-directory >> "$trace"; }
    unmount_partition || return 1
    [ "$(cat "$trace")" = '/dev/sdb1' ]
}
test_regular_user_validation() {
    load_function daimon_regular_user_valid || return 1
    id() { case "${@: -1}" in root) echo 0 ;; nobody) echo 65534 ;; alice) echo 1000 ;; *) return 1 ;; esac; }
    local name
    for name in root nobody missing ../alice 'alice/path' '-alice' ''; do
        ! daimon_regular_user_valid "$name" || return 1
    done
    daimon_regular_user_valid alice
}
load_nginx_functions() {
    local fixture="$WORK/nginx-functions.sh"
    awk '/cat .*<<.DAIMON_CERT_NGINX_SCRIPT./ {active=1;next}
        active && /^if .*--install-renewal/ {exit}
        active && $0 != "set -e" {print}' "$SOURCE" > "$fixture"
    [ -s "$fixture" ] && bash -n "$fixture" && source "$fixture"
}
test_nginx_menu_no_install() {
    local mode="${1:-return}" fixture="$WORK/nginx-wrapper.sh" trace="$WORK/nginx-install.trace" status=0
    declare -f rclone_restore_name_valid rclone_tree_safe rclone_assert_inactive rclone_require_space \
        rclone_nginx_prepare rclone_nginx_allow_ports rclone_nginx_cert_valid rclone_nginx_apply \
        rclone_check_nginx_after_restore > "$fixture"
    awk '/^ssl_nginx_manager\(\)/ {active=1} active {print}
        active && /^DAIMON_CERT_NGINX_SCRIPT$/ {closed=1}
        active && closed && /^}/ {exit}' "$SOURCE" >> "$fixture"
    [ -s "$fixture" ] || return 1
    printf '\nssl_nginx_manager\n' >> "$fixture"
    : > "$trace"
    mkdir -p "$WORK/nginx-home"
    apt() { echo install >> "$trace"; return 1; }
    curl() { echo download >> "$trace"; return 1; }
    dnf() { apt "$@"; }
    yum() { apt "$@"; }
    systemctl() { echo service >> "$trace"; return 1; }
    crontab() { [ "${1:-}" = -l ] || echo cron-write >> "$trace"; return 1; }
    export -f apt curl dnf yum systemctl crontab
    export trace HOME="$WORK/nginx-home" DAIMON_SCRIPT_DIR="$WORK/nginx-scripts"
    export DAIMON_BACKUP_DIR="$WORK/nginx-backup" DAIMON_BACKUP_SH_DIR="$WORK/nginx-backup-sh"
    export DAIMON_UPDATE_CERT_HELPER_ONLY=0
    case "$mode" in
        return) bash "$fixture" <<< 0 || return 1 ;;
        invalid) bash "$fixture" <<< $'invalid\n\n0' || return 1 ;;
        eof) bash "$fixture" </dev/null || status=$?; [ "$status" -le 1 ] || return 1 ;;
    esac
    [ ! -s "$trace" ]
}
test_nginx_dependency_failure() {
    load_nginx_functions || return 1
    local manager="$1" calls=0
    command() {
        if [ "${1:-}" = -v ]; then [ "$2" = "$manager" ]; else builtin command "$@"; fi
    }
    apt() { calls=$((calls + 1)); [ "$calls" -gt 1 ]; }
    dnf() { return 1; }
    yum() { return 1; }
    ! install_deps
}
test_acme_dependency_failure() {
    load_nginx_functions || return 1
    local trace="$WORK/acme-dependency.trace" HOME="$WORK/acme-home" ACME="$WORK/acme-home/acme.sh" status=0
    mkdir -p "$HOME"
    : > "$trace"
    install_deps() { echo dependencies >> "$trace"; return 1; }
    curl() { echo download >> "$trace"; }
    sh() { echo installer >> "$trace"; }
    ( install_acme ) || status=$?
    [ "$status" -ne 0 ] && [ "$(cat "$trace")" = dependencies ]
}
test_nginx_service_failure() {
    load_nginx_functions || return 1
    local stage="$1" trace="$WORK/nginx-service.trace"
    : > "$trace"
    command() {
        if [ "${1:-}" = -v ]; then [ "$2" = nginx ]; else builtin command "$@"; fi
    }
    systemctl() { echo "$1" >> "$trace"; [ "$1" != "$stage" ]; }
    nginx_domain_enable_auto_backup() { echo backup >> "$trace"; }
    ! install_nginx || return 1
    ! grep -q backup "$trace"
}
test_nginx_renewal_failure() {
    load_nginx_functions || return 1
    nginx_domain_ensure_renew_cron() { return 1; }
    ! setup_cron
}
test_nginx_config_install_failure() {
    load_nginx_functions || return 1
    local body
    mkdir -p "$WORK/domain/example.com" "$WORK/nginx/sites-available" "$WORK/nginx/sites-enabled"
    printf fixture > "$WORK/domain/example.com/fullchain.pem"
    printf fixture > "$WORK/domain/example.com/privkey.pem"
    body=$(declare -f config_nginx)
    body=${body//\/root\/domain/$WORK/domain}
    eval "${body//\/etc\/nginx/$WORK/nginx}"
    install_nginx() { return 1; }
    nginx() { :; }
    systemctl() { :; }
    ! config_nginx example.com fixture 8080 || return 1
    [ ! -e "$WORK/nginx/sites-available/fixture" ]
}
test_acme_download_failure() {
    load_nginx_functions || return 1
    local HOME="$WORK/acme-download" ACME="$WORK/acme-download/acme.sh"
    mkdir -p "$HOME"
    install_deps() { :; }
    curl() { printf 'partial installer\n'; return 28; }
    sh() { cat >/dev/null; printf '#!/bin/sh\nexit 0\n' > "$ACME"; chmod +x "$ACME"; }
    ! install_acme
}
test_nginx_page_input() {
    load_nginx_functions || return 1
    local input_name="$1" input_port="$2" count=0 trace="$WORK/nginx-page.trace" status=0
    : > "$trace"
    read() {
        count=$((count + 1))
        if [ "$count" -eq 1 ]; then printf -v "${@: -1}" '%s' "$input_name"
        else printf -v "${@: -1}" '%s' "$input_port"; fi
    }
    install_nginx() { echo reached-install >> "$trace"; exit 77; }
    ( create_test_page ) || status=$?
    [ "$status" -ne 0 ] && [ ! -s "$trace" ]
}
test_nginx_page_ownership() {
    load_nginx_functions || return 1
    local mode="$1" body fn count=0 trace="$WORK/page-removal.trace"
    mkdir -p "$WORK/web/example" "$WORK/nginx/sites-available" "$WORK/nginx/sites-enabled"
    printf 'business data\n' > "$WORK/web/example/index.html"
    printf 'server {}\n' > "$WORK/nginx/sites-available/example"
    [ "$mode" != managed ] || printf 'example\n' > "$WORK/web/example/.daimon-test-page"
    for fn in remove_test_page nginx_test_page_is_managed; do
        body=$(declare -f "$fn") || continue
        body=${body//\/var\/www/$WORK/web}
        eval "${body//\/etc\/nginx/$WORK/nginx}"
    done
    : > "$trace"
    read() { count=$((count + 1)); if [ "$count" -eq 1 ]; then printf -v "${@: -1}" 1; else printf -v "${@: -1}" y; fi; }
    rm() { printf '%s\n' "$*" >> "$trace"; }
    nginx() { :; }
    remove_test_page || return 1
    if [ "$mode" = managed ]; then grep -Fq -- "$WORK/web/example" "$trace"
    else [ ! -s "$trace" ]; fi
}
test_swapoff_failure() {
    local trace="$WORK/swap.trace" DAIMON_ROOT_DIR="$WORK"
    : > "$trace"
    daimon_swap_is_managed() { return 0; }
    daimon_swap_is_active() { return 0; }
    swapoff() { return 1; }
    rm() { echo remove >> "$trace"; }
    sed() { echo fstab >> "$trace"; }
    ! delete_swap || return 1
    [ ! -s "$trace" ]
}
test_swap_input() {
    local trace="$WORK/swap-input.trace" input DAIMON_ROOT_DIR="$WORK"
    : > "$trace"
    swapoff() { echo swapoff >> "$trace"; }
    wipefs() { echo wipefs >> "$trace"; }
    rm() { echo remove >> "$trace"; }
    fallocate() { echo allocate >> "$trace"; exit 77; }
    chmod() { :; }
    mkswap() { :; }
    swapon() { :; }
    sed() { :; }
    for input in 0 -1 abc 1.5 999999999999999999999999; do
        ! add_swap "$input" || return 1
    done
    [ ! -s "$trace" ]
}
test_swap_activation_failure() {
    local DAIMON_ROOT_DIR="$WORK" backing="$WORK/managed-swap" active=1 calls=0
    printf original > "$backing"
    daimon_swap_is_managed() { return 0; }
    daimon_swap_is_active() { [ "$active" -eq 1 ]; }
    function [() {
        local args=() arg
        for arg in "$@"; do
            if [[ "$arg" = /swapfile ]]; then args+=("$backing"); else args+=("$arg"); fi
        done
        builtin [ "${args[@]}"
    }
    mv() {
        local args=() arg
        for arg in "$@"; do
            if [[ "$arg" = /swapfile ]]; then args+=("$backing"); else args+=("$arg"); fi
        done
        command mv "${args[@]}"
    }
    rm() {
        local args=() arg
        for arg in "$@"; do
            if [[ "$arg" = /swapfile ]]; then args+=("$backing"); else args+=("$arg"); fi
        done
        command rm "${args[@]}"
    }
    stat() { echo fixture-inode; }
    mktemp() { command mktemp "$WORK/swap.XXXXXX"; }
    fallocate() { :; }
    mkswap() { printf replacement > "$1"; }
    swapoff() { active=0; }
    swapon() { calls=$((calls + 1)); [ "$calls" -gt 1 ] || return 1; active=1; }
    ! add_swap 1 || return 1
    [ "$(cat "$backing")" = original ] && [ "$active" -eq 1 ]
}
test_backup_exit_status() {
    docker() {
        if [ "$1" = ps ]; then echo vaultwarden-backup; return 0; fi
        echo 'upload backup file to storage system'
        return 1
    }
    ! bitwarden_backup_data
}
test_rclone_failed_installer() {
    local prepared=0
    install() { :; }
    daimon_is_cn() { return 1; }
    daimon_run_cached_script() { return 1; }
    rclone_prepare_config() { prepared=1; }
    rclone() { echo 'rclone v1.0.0'; }
    ! rclone_install_tool || return 1
    [ "$prepared" -eq 0 ]
}
test_rclone_up_to_date() {
    local prepared=0
    install() { :; }
    daimon_is_cn() { return 1; }
    daimon_run_cached_script() { return 3; }
    rclone_prepare_config() { prepared=1; }
    rclone() { echo 'rclone v1.75.1'; }
    rclone_install_tool && [ "$prepared" -eq 1 ]
}
test_rclone_release() {
    local test_arch="$1" corrupt="$2" expected="$3" trace="$WORK/release.trace"
    local DAIMON_RCLONE_BIN_DIR="$WORK/bin-$test_arch-$corrupt"
    mkdir -p "$DAIMON_RCLONE_BIN_DIR"
    printf original > "$DAIMON_RCLONE_BIN_DIR/rclone"
    : > "$trace"
    uname() { echo "$test_arch"; }
    daimon_download_to() {
        echo "$1" >> "$trace"
        case "$1" in
            */version.txt) printf 'rclone v1.75.1\n' > "$2" ;;
            */SHA256SUMS)
                local hash
                hash=$(printf fixture | sha256sum | cut -d' ' -f1)
                [ "$corrupt" = no ] || hash=$(printf invalid | sha256sum | cut -d' ' -f1)
                printf '%s  rclone-v1.75.1-linux-%s.zip\n' "$hash" "$expected" > "$2"
                ;;
            *.zip) printf fixture > "$2" ;;
            *) return 1 ;;
        esac
    }
    unzip() {
        [ "$1" = -tq ] && return 0
        printf '#!/bin/sh\nprintf "rclone v1.75.1\\n"\n'
    }
    if [ "$corrupt" = yes ] || [ "$expected" = unsupported ]; then
        ! rclone_install_cn_release || return 1
        [ "$(cat "$DAIMON_RCLONE_BIN_DIR/rclone")" = original ]
    else
        rclone_install_cn_release || return 1
        grep -q "rclone-v1.75.1-linux-$expected.zip" "$trace" &&
            [ "$("$DAIMON_RCLONE_BIN_DIR/rclone" version)" = 'rclone v1.75.1' ]
    fi
}
test_network_rollback() {
    local DAIMON_BBR_FQ_CONF="$WORK/bbr.conf" DAIMON_NETWORK_OPTIMIZE_CONF="$WORK/network.conf"
    local DAIMON_NETWORK_LEGACY_CONF="$WORK/legacy.conf" state="$WORK/sysctl.state" key value
    printf old-bbr > "$DAIMON_BBR_FQ_CONF"
    printf old-network > "$DAIMON_NETWORK_OPTIMIZE_CONF"
    printf '%s\n' net.core.default_qdisc net.ipv4.tcp_congestion_control > "$WORK/keys"
    awk '/^daimon_network_apply_custom_optimize\(\)/ {active=1}
        active && /^(net|vm|fs)\.[^|]+\|/ {split($0,a,"|");print a[1]}
        active && /^}/ {exit}' "$SOURCE" >> "$WORK/keys"
    while read -r key; do printf '%s=17\n' "$key"; done < "$WORK/keys" > "$state"
    cp "$state" "$state.original"
    daimon_network_bbr_supported() { :; }
    daimon_network_verify_active_fq() { :; }
    daimon_network_enable_bbr_fq() { printf new-bbr > "$DAIMON_BBR_FQ_CONF"; }
    daimon_network_verify_bbr_fq() { return 1; }
    daimon_network_show_conflicting_sysctl_configs() { :; }
    daimon_network_cleanup_old_qdisc_service() { :; }
    sysctl() {
        case "$1" in
            -n) awk -F= -v k="$2" '$1==k {print $2;found=1} END{exit !found}' "$state" ;;
            -p)
                while IFS='=' read -r key value; do
                    [[ "$key" = net.* || "$key" = fs.* || "$key" = vm.* ]] || continue
                    awk -F= -v k="$key" '$1!=k' "$state" > "$state.new"
                    printf '%s=%s\n' "$key" "$value" >> "$state.new"
                    mv "$state.new" "$state"
                done < "$2"
                ;;
            --system) return 0 ;;
            *) return 1 ;;
        esac
    }
    ! daimon_network_apply_custom_optimize || return 1
    [ "$(cat "$DAIMON_BBR_FQ_CONF")" = old-bbr ] || return 1
    [ "$(cat "$DAIMON_NETWORK_OPTIMIZE_CONF")" = old-network ] || return 1
    diff -u <(sort "$state.original") <(sort "$state")
}
test_tool_numbers() {
    local mode="$1" trace="$WORK/tools.trace" n
    local tool_ids=(vim cpcat ctrld starship bat btop tree ripgrep fd fzf blesh yazi fastfetch ncdu nexttrace iperf3)
    : > "$trace"
    install_tool_by_id() { echo "$1" >> "$trace"; [ "$mode" != failed ] || [ "$1" != vim ]; }
    remove_tool_by_id() { echo "$1" >> "$trace"; }
    tool_installed() { [ "$mode" != failed ] || [ "$1" != vim ]; }
    case "$mode" in
        failed) ! handle_tool_numbers install '1 2' ;;
        leading-zero) handle_tool_numbers install 08 && [ "$(cat "$trace")" = ripgrep ] ;;
        all)
            for n in $(seq 1 16); do handle_tool_numbers install "$n" || return 1; done
            [ "$(wc -l < "$trace")" -eq 16 ] || return 1
            [ "$(cat "$trace")" = "$(printf '%s\n' "${tool_ids[@]}")" ]
            ;;
    esac
}
test_bitwarden_config_privacy() {
    local output
    bitwarden_check_requirements() { :; }
    rclone_config_path() { printf '%s\n' "$WORK/config"; }
    rclone_select_remote() { return 1; }
    mkdir() { :; }
    chmod() { :; }
    rclone() { :; }
    docker() { echo 'token = {"access_token":"PRIVATE_FIXTURE"}'; return 1; }
    output=$(bitwarden_configure_rclone_conf 2>&1)
    [ "$?" -ne 0 ] && [[ "$output" != *PRIVATE_FIXTURE* ]]
}
test_main_eof() {
    local count=0 choice='' DAIMON_CERT_HELPER_MARKER="$WORK/absent"
    crontab_sync_reconcile_legacy() { :; }
    read() { count=$((count + 1)); [ "$count" -lt 3 ] || exit 77; return 1; }
    kejilion_sh </dev/null
    [ "$count" -eq 1 ]
}
test_ufw_unknown_ports() {
    local trace="$WORK/ufw.trace" SSH_CONNECTION=''
    : > "$trace"
    install() { :; }
    sshd() { return 1; }
    ss() { return 1; }
    grep() { return 1; }
    ufw() { echo "$*" >> "$trace"; }
    ufw_manager <<< $'1\n0' || return 1
    ! command grep -q enable "$trace"
}
test_ufw_allow_failure() {
    local trace="$WORK/ufw-allow.trace" SSH_CONNECTION='198.51.100.1 12345 192.0.2.1 64400'
    : > "$trace"
    install() { :; }
    ssh_current_ports() { echo 64400; }
    ufw() { echo "$*" >> "$trace"; [ "${1:-}" != allow ]; }
    ufw_manager <<< $'1\n0' || return 1
    ! grep -q enable "$trace"
}
test_active_qdisc() {
    local mode="$1"
    sysctl() {
        case "$*" in *tcp_congestion_control*) echo bbr ;; *default_qdisc*) echo fq ;; esac
    }
    ip() { echo 'default via 192.0.2.1 dev eth0'; }
    tc() {
        if [ "$mode" = good ]; then
            printf '%s\n' 'qdisc mq 0: root' 'qdisc fq 0: parent :1' 'qdisc fq 0: parent :2'
        else
            echo 'qdisc fq_codel 0: root'
        fi
    }
    if [ "$mode" = good ]; then daimon_network_verify_bbr_fq
    else ! daimon_network_verify_bbr_fq; fi
}
test_batch_continues() {
    local trace="$WORK/batch.trace"
    : > "$trace"
    one_click_config_manager <<< 0
    reload_shell_configs_safely() { :; }
    exec() { exit 77; }
    linux_tools() { restart_shell_after_tool_install; }
    one_click_set_timezone_locale() { echo timezone >> "$trace"; }
    one_click_config_run_all <<< '9 10'
    grep -q timezone "$trace"
}
test_main_menu() {
    local number expected trace="$WORK/menu.trace" name
    crontab_sync_reconcile_legacy() { :; }
    local DAIMON_CERT_HELPER_MARKER="$WORK/absent"
    for name in linux_info linux_update linux_clean one_click_config_manager linux_Settings \
        linux_tools linux_docker ssh_config_manager ufw_manager ssl_nginx_manager fail2ban_manager \
        linux_bbr warp_manager rclone_manager bitwarden_manager crontab_sync_manager \
        common_one_click_scripts kejilion_update; do
        eval "$name() { echo '$name' >> \"\$trace\"; }"
    done
    while read -r number expected; do
        : > "$trace"
        ( kejilion_sh <<< "$number"$'\n0' ) || return 1
        [ "$(cat "$trace")" = "$expected" ] || return 1
    done <<'EOF'
1 linux_info
2 linux_update
3 linux_clean
4 one_click_config_manager
5 linux_Settings
6 linux_tools
7 linux_tools
8 linux_docker
9 ssh_config_manager
10 ufw_manager
11 ssl_nginx_manager
12 fail2ban_manager
13 linux_bbr
14 warp_manager
15 rclone_manager
16 bitwarden_manager
17 crontab_sync_manager
18 common_one_click_scripts
00 kejilion_update
0
EOF
}

check 'CN proxies; HK, SG and unknown remain direct' test_regions
check 'jsDelivr normalizes refs/heads raw URLs' test_jsdelivr_refs
check 'failed download cannot replace a cached file' test_download_preserves_cache
check 'failed migration preserves source data' test_migration_preserves_source
check 'package locks are not killed or deleted' test_package_lock
check 'package failure cannot be hidden by a later success' test_package_failure
for manager in apt dnf yum apk pacman zypper pkg unsupported; do
    check "cleanup propagates $manager package failure" test_cleanup_failure "$manager"
done
for manager in apk opkg pkg; do
    check "cleanup preserves shared logs and temporary files on $manager" test_cleanup_boundaries "$manager"
done
check 'cleanup retains journal history within the existing size limit' test_cleanup_journal
check 'update rejects syntactically invalid scripts' test_update_syntax
check 'startup ignores unrelated scripts in the working directory' test_self_install_source
check 'script replacement preserves readers of the old inode' test_atomic_script_install
check 'SSH private key names reject traversal and reserved files' test_ssh_key_names
check 'SSH allow failure prevents config write and restart' test_ssh_allow_order
check 'shortcut cannot overwrite the bash executable' test_shortcut_collision
check 'unmount locates the mount by its source device' test_unmount_lookup
check 'user management rejects system users and path input' test_regular_user_validation
check 'Nginx menu return does not install acme or packages' test_nginx_menu_no_install
check 'Nginx full entry handles invalid input without changes' test_nginx_menu_no_install invalid
check 'Nginx full entry stops on EOF without changes' test_nginx_menu_no_install eof
for manager in apt dnf yum; do
    check "Nginx stops after $manager dependency failure" test_nginx_dependency_failure "$manager"
done
check 'Nginx does not download acme after dependency failure' test_acme_dependency_failure
check 'Nginx start failure cannot report installation success' test_nginx_service_failure start
check 'Nginx enable failure cannot report installation success' test_nginx_service_failure enable
check 'Nginx inactive service cannot report installation success' test_nginx_service_failure is-active
check 'Nginx renewal failure reaches the caller' test_nginx_renewal_failure
check 'Nginx config is not written after installation failure' test_nginx_config_install_failure
check 'Nginx acme download failure is not hidden by the installer' test_acme_download_failure
check 'Nginx test page rejects traversal before installation' test_nginx_page_input ../protected 8080
check 'Nginx test page rejects injected port before installation' test_nginx_page_input fixture '8080;include bad;'
check 'Nginx test page removal preserves unowned business directories' test_nginx_page_ownership business
check 'Nginx test page removal accepts an owned fixture' test_nginx_page_ownership managed
check 'system tools menu stops on EOF' test_submenu_eof linux_Settings
check 'one-click menu stops on EOF without using defaults' test_submenu_eof one_click_config_manager
check 'swapoff failure preserves swap and fstab' test_swapoff_failure
check 'invalid swap sizes make no changes' test_swap_input
check 'failed swap activation restores the previous file and activation' test_swap_activation_failure
check 'backup log marker cannot override nonzero exit' test_backup_exit_status
check 'failed rclone install cannot report success or create config' test_rclone_failed_installer
check 'official rclone exit 3 means already current' test_rclone_up_to_date
check 'rclone AMD64 release is checked and installed atomically' test_rclone_release x86_64 no amd64
check 'rclone ARM64 release selects the correct asset' test_rclone_release aarch64 no arm64
check 'rclone corrupt archive preserves the old executable' test_rclone_release x86_64 yes amd64
check 'unsupported rclone architecture makes no changes' test_rclone_release unknown no unsupported
check 'network failure restores runtime values and both config files' test_network_rollback
check 'all 16 third-party tool IDs are reachable' test_tool_numbers all
check 'tool index 08 is decimal, not invalid octal' test_tool_numbers leading-zero
check 'batch tool failure propagates to its caller' test_tool_numbers failed
check 'Bitwarden config validation never prints credentials' test_bitwarden_config_privacy
check 'main menu stops safely on EOF' test_main_eof
check 'UFW cannot enable with unknown SSH ports' test_ufw_unknown_ports
check 'UFW cannot enable after allow-rule failure' test_ufw_allow_failure
check 'mq with fq leaf queues passes verification' test_active_qdisc good
check 'fq_codel does not pass BBR+FQ verification' test_active_qdisc bad
check 'batch installs continue to timezone step' test_batch_continues
check 'all 20 main-menu branches dispatch correctly' test_main_menu
printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
