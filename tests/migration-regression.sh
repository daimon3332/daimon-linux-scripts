#!/usr/bin/env bash
set -o pipefail
case "$(uname -s)" in MINGW*) export MSYS="${MSYS:+$MSYS }winsymlinks:nativestrict" ;; esac
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$ROOT/.tmp"
WORK=$(mktemp -d "$ROOT/.tmp/migration.XXXXXX") || exit 1
trap 'rm -rf -- "$WORK"' EXIT
export TMPDIR="$WORK"
export DAIMON_RESTORE_ROOT="$WORK/root"
export DAIMON_NGINX_DIR="$WORK/nginx"
mkdir -p "$DAIMON_RESTORE_ROOT" "$DAIMON_NGINX_DIR"
tr -d '\r' < "${DAIMON_TEST_SOURCE:-$ROOT/linux-toolbox.sh}" > "$WORK/source.sh"
SOURCE="$WORK/source.sh"
if ! python3 --version >/dev/null 2>&1; then
    python3() { python "$@" | tr -d '\r'; }
fi

load_function() {
    local body
    body=$(awk -v name="$1" '
        $0 ~ "^[[:space:]]*" name "\\(\\) [({]" {
            active=1; match($0,/[^[:space:]]/); indent=substr($0,1,RSTART-1)
            closing=($0 ~ /\($/ ? ")" : "}")
        }
        active {print}
        active && $0 == indent closing {exit}
    ' "$SOURCE")
    [ -n "$body" ] && bash -n <<< "$body" && eval "$body"
}
while IFS= read -r fn; do
    load_function "$fn" || exit 1
done < <(awk '/^rclone_status_text\(\)/ {active=1} /^crontab_sync_backup_dir\(\)/ {active=0}
    active && /^[a-zA-Z_]+\(\) [({]/ {sub(/\(.*/, ""); print}' "$SOURCE")
root_use() { :; }
passed=0 failed=0
check() {
    local name="$1"
    shift
    [[ "$name" == *"${DAIMON_TEST_FILTER:-}"* ]] || return 0
    if ( "$@" ) > "$WORK/test.out" 2>&1; then
        printf 'PASS %s\n' "$name"
        passed=$((passed + 1))
    else
        printf 'FAIL %s\n' "$name"
        cat "$WORK/test.out"
        failed=$((failed + 1))
    fi
}

test_missing_nginx() {
    command() {
        if [[ "$1" = -v && "$2" = nginx ]]; then return 1; fi
        builtin command "$@"
    }
    ! rclone_check_nginx_after_restore
}
test_reload_failure() {
    nginx() { return 0; }
    systemctl() { return 1; }
    ! rclone_check_nginx_after_restore
}
test_link_failure() {
    mkdir() { :; }
    rclone() { printf 'fixture-site\n'; }
    ln() { return 1; }
    ! rclone_rebuild_sites_enabled_links fixture:backup
}
test_no_link_fallback() {
    local output
    mkdir() { :; }
    rclone() { return 1; }
    find() { printf 'disabled-local-site\n'; }
    ln() { printf 'WRONG_SITE_ENABLED\n'; }
    output=$(rclone_rebuild_sites_enabled_links fixture:backup)
    local rc=$?
    [ "$rc" -ne 0 ] && [[ "$output" != *WRONG_SITE_ENABLED* ]]
}
test_names() {
    local input="$1" expected="$2"
    rclone() {
        case "$1" in
            lsd) printf '0 2026-09-08 00:00:00 -1 folder  two  spaces\n'
                for i in {2..9}; do printf '0 2026-09-08 00:00:00 -1 folder%s\n' "$i"; done ;;
            lsjson) printf '[{"Name":"folder  two  spaces","IsDir":true}'
                for i in {2..9}; do printf ',{"Name":"folder%s","IsDir":true}' "$i"; done
                printf ']\n' ;;
            *) return 1 ;;
        esac
    }
    rclone_select_remote_dirs_multi fixture:server fixture <<< "$input" || return 1
    [ "${RCLONE_SELECTED_DIRS[0]}" = "$expected" ]
}
test_error_privacy() {
    local output
    rclone() { printf 'invalid_grant https://fixture.invalid/?tempauth=PRIVATE_FIXTURE\n' >&2; return 1; }
    output=$(rclone_select_remote_dir fixture:server fixture)
    [ "$?" -ne 0 ] && [[ "$output" != *PRIVATE_FIXTURE* ]]
}
test_config_failure() {
    local output
    bitwarden_check_requirements() { :; }
    bitwarden_rclone_conf_file() { printf '%s\n' "$WORK/absent/rclone.conf"; }
    rclone_select_remote() { RCLONE_SELECTED_REMOTE=fixture; }
    rclone_remote_state() { printf 'invalid\n'; }
    rclone() { return 1; }
    docker() { return 1; }
    output=$(bitwarden_configure_rclone_conf)
    [ "$?" -ne 0 ] && [ ! -e "$WORK/absent/rclone.conf" ]
}
test_restore_active_volume() {
    local output
    bitwarden_check_requirements() { :; }
    bitwarden_restore_preflight() { return 1; }
    rclone() { case "$1" in ls) printf '100 backup.20260908.zip\n' ;; *) return 0 ;; esac; }
    docker() { printf 'UNSAFE_RESTORE_EXECUTED\n'; }
    output=$(bitwarden_restore_data <<< $'1\ny')
    [ "$?" -ne 0 ] && [[ "$output" != *UNSAFE_RESTORE_EXECUTED* ]]
}

test_folder_restore() {
    local mode="$1" root="$WORK/folder-$1" input="$WORK/input-$1" rc=0
    mkdir -p "$root/app" "$input"
    printf old > "$root/app/config"
    printf new > "$input/config"
    printf added > "$input/new-file"
    docker() { [ "$1" = ps ]; }
    rclone() {
        case "$1" in
            size) printf '{"bytes":16}\n' ;;
            copy) [ "$mode" != download ] && cp -a "$input/." "$3/" ;;
            check) [ "$mode" != checksum ] ;;
            *) return 1 ;;
        esac
    }
    if [ "$mode" = space ]; then rclone_require_space() { return 1; }; fi
    if [ "$mode" = rename ] || [ "$mode" = concurrent ]; then
        mv() {
            if [[ "$*" = *'/result '* ]]; then
                [ "$mode" != concurrent ] || mkdir -p "${@: -1}"
                return 1
            fi
            command mv "$@"
        }
    fi
    rclone_restore_folder fixture:app "$root" app "${2:-replace}" || rc=$?
    case "$mode" in
        success) [ "$rc" = 0 ] && [ "$(cat "$root/app/config")" = new ] && [ "$(cat "$root/app/new-file")" = added ] ;;
        keep) [ "$rc" = 0 ] && [ "$(cat "$root/app/config")" = old ] && [ "$(cat "$root/app/new-file")" = added ] ;;
        concurrent) [ "$rc" -ne 0 ] && [ "$(cat "$root"/.daimon-restore.*/previous/config)" = old ] ;;
        *) [ "$rc" -ne 0 ] && [ "$(cat "$root/app/config")" = old ] && [ ! -e "$root/app/new-file" ] ;;
    esac
}
test_live_mount_guard() {
    local MSYS2_ARG_CONV_EXCL='*' output
    export MSYS2_ARG_CONV_EXCL
    docker() {
        case "$1" in
            ps) printf 'fixture\n' ;;
            inspect) printf '[{"Name":"/active","Mounts":[{"Source":"/root/service/data"}]}]\n' ;;
            *) return 1 ;;
        esac
    }
    output=$(rclone_assert_inactive /root/service)
    [ "$?" -ne 0 ] && [[ "$output" = *active* ]]
}
test_daemon_guard() {
    docker() { return 1; }
    ! rclone_assert_inactive /root/service
}
test_remote_state() {
    local mode="$1" conf="$WORK/probe.conf"
    printf '[fixture]\ntype = local\n' > "$conf"
    rclone() {
        case "$mode" in
            valid) return 0 ;;
            invalid) echo 'invalid_grant PRIVATE_FIXTURE' >&2; return 1 ;;
            unknown) echo 'network timeout PRIVATE_FIXTURE' >&2; return 1 ;;
        esac
    }
    timeout() { shift; "$@"; }
    [ "$(rclone_remote_state "$conf" fixture:)" = "$mode" ]
}
test_nginx_transaction() {
    local scenario="$1" fixture="$WORK/nginx-$1" backup="$WORK/nginx-$1/source"
    local DAIMON_NGINX_DIR="$fixture/target" DAIMON_DOMAIN_DIR="$fixture/domain"
    mkdir -p "$backup/sites-available" "$backup/domain" "$DAIMON_NGINX_DIR/sites-available" "$DAIMON_NGINX_DIR/sites-enabled"
    printf original > "$DAIMON_NGINX_DIR/sites-available/local-disabled"
    printf incoming > "$backup/sites-available/new-site"
    printf 'new-site\n' > "$backup/enabled_sites.txt"
    rclone_nginx_prepare() { :; }
    rclone_nginx_allow_ports() { :; }
    rclone_assert_inactive() { :; }
    nginx() { [ "$scenario" != invalid ] || [ ! -f "$DAIMON_NGINX_DIR/sites-available/new-site" ]; }
    systemctl() { :; }
    if [ "$scenario" = missing ]; then rm "$backup/enabled_sites.txt"; fi
    if [ "$scenario" = link ]; then ln() { return 1; }; fi
    if [ "$scenario" = relative ]; then
        cp "$backup/sites-available/new-site" "$DAIMON_NGINX_DIR/sites-available/new-site"
        ln -s ../sites-available/new-site "$DAIMON_NGINX_DIR/sites-enabled/new-site" || return 1
    fi
    if [ "$scenario" = stopped ]; then
        systemctl() {
            case "$1" in
                is-active) [ -e "$fixture/running" ] ;;
                start) touch "$fixture/running" ;;
                stop) rm -f "$fixture/running" ;;
                enable) return 1 ;;
                *) return 0 ;;
            esac
        }
    fi
    if [ "$scenario" = success ] || [ "$scenario" = relative ]; then
        rclone_nginx_apply "$backup" all keep || return 1
        rclone_nginx_apply "$backup" all keep || return 1
        [ -L "$DAIMON_NGINX_DIR/sites-enabled/new-site" ] && [ ! -e "$DAIMON_NGINX_DIR/sites-enabled/local-disabled" ]
    else
        ! rclone_nginx_apply "$backup" all keep || return 1
        [ "$scenario" != stopped ] || [ ! -e "$fixture/running" ] || return 1
        [ ! -e "$DAIMON_NGINX_DIR/sites-available/new-site" ] && [ "$(cat "$DAIMON_NGINX_DIR/sites-available/local-disabled")" = original ]
    fi
}
test_compose_state() {
    local mode="$1" rc=0
    rclone_compose_run() {
        shift
        case "$*" in
            'config --format json') printf '{"services":{"app":{}}}\n' ;;
            'config --services') printf 'app\n' ;;
            'ps -a --format json')
                case "$mode" in
                    error) return 1 ;;
                    unhealthy) printf '[{"Service":"app","State":"running","Health":"unhealthy"}]\n' ;;
                    starting) printf '[{"Service":"app","State":"running","Health":"starting"}]\n' ;;
                    healthy) printf '[{"Service":"app","State":"running","Health":"healthy"}]\n' ;;
                esac ;;
        esac
    }
    rclone_compose_status "$WORK" || rc=$?
    case "$mode:$rc" in healthy:0|starting:1|error:2|unhealthy:3) return 0 ;; *) return 1 ;; esac
}
test_compose_missing_bind() {
    rclone_compose_run() {
        shift
        case "$*" in
            'config --format json') printf '{"name":"fixture","services":{"app":{"volumes":[{"type":"bind","source":"/missing-fixture-source"}]}}}\n' ;;
            'config --services') printf 'app\n' ;;
        esac
    }
    docker() { :; }
    ! rclone_compose_preflight "$WORK"
}
test_compose_failed_ps_caller() {
    local output
    docker() { :; }
    rclone_compose_directories() { printf '%s\n' "$WORK/project"; }
    rclone_compose_context() { :; }
    rclone_compose_preflight() { :; }
    rclone_compose_status() { return 2; }
    rclone_compose_run() { printf 'UNSAFE_START\n'; }
    output=$(rclone_restore_docker_compose_projects <<< y)
    [ "$?" -ne 0 ] && [[ "$output" != *UNSAFE_START* ]]
}

test_credentials_transaction() {
    local mode="$1" fixture="$WORK/credentials-$1" output rc=0
    local fixture_target="$fixture/volume/rclone/rclone.conf"
    mkdir -p "$(dirname "$fixture_target")"
    printf '[BitwardenBackup]\ntype = local\nold = preserved\n[other]\ntype = local\nmarker = untouched\n' > "$fixture_target"
    cp "$fixture_target" "$fixture/original"
    bitwarden_check_requirements() { :; }
    bitwarden_rclone_conf_file() { printf '%s\n' "$fixture_target"; }
    bitwarden_volume_name() { echo fixture-volume; }
    bitwarden_backup_image() { echo sha256:fixture; }
    rclone_config_path() { printf '%s\n' "$fixture/source.conf"; }
    rclone_select_remote() { RCLONE_SELECTED_REMOTE=selected; }
    rclone() { printf '{"selected":{"type":"local","marker":"replacement","token":"PRIVATE_FIXTURE"}}\n'; }
    docker() {
        case "$1" in
            run)
                [[ "$*" = *'--entrypoint rclone'* ]] || return 0
                printf 'PRIVATE_FIXTURE\n'
                [ "$mode" != invalid ] || return 1
                [ "$mode" != concurrent ] || printf 'concurrent-update\n' > "$fixture_target"
                ;;
            volume) [[ "$*" != *--format* ]] || printf '%s\n' "$fixture/volume" ;;
            *) return 1 ;;
        esac
    }
    timeout() { shift; "$@"; }
    output=$(bitwarden_configure_rclone_conf) || rc=$?
    [[ "$output" != *PRIVATE_FIXTURE* ]] || return 1
    case "$mode" in
        invalid) [ "$rc" -ne 0 ] && cmp -s "$fixture_target" "$fixture/original" ;;
        concurrent) [ "$rc" -ne 0 ] && [ "$(cat "$fixture_target")" = concurrent-update ] ;;
        success) [ "$rc" = 0 ] && grep -q 'marker = replacement' "$fixture_target" && grep -q 'marker = untouched' "$fixture_target" && ! grep -q 'old = preserved' "$fixture_target" ;;
    esac
}
test_vault_archive() {
    local mode="$1" fixture="$WORK/archive-$1" rc=0
    mkdir -p "$fixture/extracted" "$fixture/previous"
    python3 - "$fixture" "$mode" <<'PY' || return 1
import io, json, sqlite3, sys, tarfile
from pathlib import Path
root, mode = Path(sys.argv[1]), sys.argv[2]
with sqlite3.connect(root / "extracted/db.fixture.sqlite3") as conn:
    conn.execute("CREATE TABLE users(id INTEGER)")
    conn.execute("CREATE TABLE ciphers(id INTEGER)")
    conn.execute("INSERT INTO users VALUES (1)")
    conn.execute("INSERT INTO ciphers VALUES (1)")
(root / "extracted/config.fixture.json").write_text(json.dumps({"fixture":True}))
for kind in ("rsakey", "attachments", "sends"):
    with tarfile.open(root / ("extracted/" + kind + ".fixture.tar"), "w") as archive:
        path = "rsa_key.pem" if kind == "rsakey" else kind + "/file"
        if mode == "traversal" and kind == "attachments":
            path = "../escaped"
        info = tarfile.TarInfo(path)
        info.size = 7
        archive.addfile(info, io.BytesIO(b"fixture"))
if mode == "corrupt":
    (root / "extracted/db.fixture.sqlite3").write_bytes(b"not-a-database")
PY
    bitwarden_prepare_restored_files "$fixture/extracted" "$fixture/result" "$fixture/previous" || rc=$?
    if [ "$mode" = success ]; then
        [ "$rc" = 0 ] && [ -s "$fixture/result/db.sqlite3" ] && [ "$(cat "$fixture/result/attachments/file")" = fixture ] && [ "$(cat "$fixture/result/sends/file")" = fixture ]
    else
        [ "$rc" -ne 0 ] && [ ! -e "$fixture/escaped" ]
    fi
}
test_generated_sync_failure() {
    local kind="$1" fixture="$WORK/sync-$1"
    load_function crontab_sync_write_script || return 1
    crontab_sync_log_dir() { printf '%s\n' "$fixture/logs"; }
    crontab_sync_write_script "$kind" "$fixture/task.sh" || return 1
    rclone() { return 1; }
    export -f rclone
    sed "s|^LOG_DIR=.*|LOG_DIR='$fixture/logs'|" "$fixture/task.sh" > "$fixture/isolated.sh"
    ! bash "$fixture/isolated.sh"
}

test_remote_names_privacy() {
    local output
    rclone() { printf '{"fixture":{"type":"local","token":"PRIVATE_FIXTURE"}}\n'; }
    output=$(rclone_config_remotes "$WORK/conf") || return 1
    [ "$output" = $'fixture\tlocal' ]
}
test_compose_context_labels() {
    local fixture="$WORK/context" actual
    local MSYS2_ARG_CONV_EXCL='*'
    export MSYS2_ARG_CONV_EXCL
    mkdir -p "$fixture"
    printf 'services: {}\n' > "$fixture/base.yml"
    printf 'services: {}\n' > "$fixture/override.yml"
    docker() {
        case "$1" in
            ps) echo fixture ;;
            inspect) printf '[{"Config":{"Labels":{"com.docker.compose.project":"explicit","com.docker.compose.project.working_dir":"%s","com.docker.compose.project.config_files":"%s/base.yml,%s/override.yml"}}}]\n' "$fixture" "$fixture" "$fixture" ;;
        esac
    }
    rclone_compose_context "$fixture" || return 1
    actual=$(printf '%s\n' "${RCLONE_COMPOSE_ARGS[@]}")
    [ "$actual" = "$(printf '%s\n' -p explicit -f "$fixture/base.yml" -f "$fixture/override.yml")" ]
}
test_missing_certificate_files() {
    local fixture="$WORK/certificates"
    mkdir -p "$fixture"
    ! rclone_nginx_cert_valid "$fixture"
}
test_symlink_restore_guard() {
    local fixture="$WORK/symlink"
    mkdir -p "$fixture/real"
    ln -s "$fixture/real" "$fixture/alias" || return 1
    ! rclone_tree_safe "$fixture/alias"
}

check 'missing nginx must fail' test_missing_nginx
check 'reload and restart failure must fail' test_reload_failure
check 'link failure must propagate' test_link_failure
check 'remote failure must not enable unrelated sites' test_no_link_fallback
check 'directory names preserve repeated spaces' test_names 1 'folder  two  spaces'
check 'directory selection accepts decimal 08' test_names 08 folder8
check 'remote errors never expose authorization URLs' test_error_privacy
check 'credential failure preserves original configuration' test_config_failure
check 'active volume preflight stops the restore caller' test_restore_active_volume
for mode in success download checksum space rename concurrent; do
    check "directory transaction $mode" test_folder_restore "$mode"
done
check 'directory conflict keep policy adds only missing files' test_folder_restore keep keep
check 'live nested bind mount blocks parent restoration' test_live_mount_guard
check 'daemon query failure blocks restoration' test_daemon_guard
for mode in valid invalid unknown; do check "remote status $mode" test_remote_state "$mode"; done
for mode in success missing invalid link relative stopped; do check "Nginx transaction $mode" test_nginx_transaction "$mode"; done
for mode in healthy unhealthy starting error; do check "Compose state $mode" test_compose_state "$mode"; done
check 'missing bind source prevents Compose startup' test_compose_missing_bind
check 'failed Compose status query cannot become startup' test_compose_failed_ps_caller
for mode in success invalid concurrent; do check "credential transaction $mode" test_credentials_transaction "$mode"; done
for mode in success corrupt traversal; do check "Vaultwarden archive $mode" test_vault_archive "$mode"; done
for kind in bitwarden custom; do check "generated $kind sync propagates failure" test_generated_sync_failure "$kind"; done
check 'remote names and types do not expose tokens' test_remote_names_privacy
check 'Compose labels preserve project name and override files' test_compose_context_labels
check 'missing certificate files fail validation' test_missing_certificate_files
check 'symlink restoration target is rejected' test_symlink_restore_guard

printf '%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
