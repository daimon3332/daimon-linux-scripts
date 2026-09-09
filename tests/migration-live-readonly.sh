#!/usr/bin/env bash
set -o pipefail
SOURCE="${DAIMON_TEST_SOURCE:-/root/linux-daimon/linux-toolbox.sh}"
[ -f "$SOURCE" ] || exit 1
load_function() {
    local body
    body=$(awk -v name="$1" '
        $0 ~ "^" name "\\(\\) [({]" {active=1; closing=($0 ~ /\($/ ? ")" : "}")}
        active {print}
        active && $0 == closing {exit}
    ' "$SOURCE")
    [ -n "$body" ] && bash -n <<< "$body" && eval "$body"
}
while IFS= read -r fn; do load_function "$fn" || exit 1; done < <(
    awk '/^rclone_status_text\(\)/ {active=1} /^crontab_sync_backup_dir\(\)/ {active=0}
        active && /^[a-zA-Z_]+\(\) [({]/ {sub(/\(.*/, ""); print}' "$SOURCE"
)
root_use() { :; }
failed=0
printf 'Installed source: %s\n' "$SOURCE"
bash -n "$SOURCE" || exit 1
docker ps --format '{{.Names}}|{{.Status}}' || failed=1
nginx -t || failed=1
systemctl is-active nginx || failed=1
LC_ALL=C ufw status || failed=1
if [ "${EXPECT_RETIRED:-0}" = 1 ]; then
    [ -z "$(docker ps -aq)" ] || failed=1
    printf 'Retained volumes: %s\n' "$(docker volume ls -q | wc -l)"
else
    directories=$(rclone_compose_directories) || exit 1
    while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        printf '\nProject: %s\n' "$dir"
        if rclone_compose_context "$dir" && rclone_compose_preflight "$dir" verify && rclone_compose_status "$dir"; then
            echo 'PASS runtime and preflight'
        else
            echo 'FAIL runtime or preflight'
            failed=1
        fi
    done <<< "$directories"
    if [ -n "${DAIMON_VERIFY_IP:-}" ]; then
        rclone_migration_verify <<< "$DAIMON_VERIFY_IP"$'\n' || failed=1
    fi
fi
echo 'No restore, start, firewall change, DNS change or production backup was performed.'
exit "$failed"
