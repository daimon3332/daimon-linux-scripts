#!/bin/bash
sh_v="1.0.0"


gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_kjlan='\033[96m'


canshu="default"
permission_granted="false"
ENABLE_STATS="false"

validate_domain_name() {
	[[ "$1" =~ ^([A-Za-z0-9-]+\.)+[A-Za-z]{2,63}$ ]]
}

validate_tcp_port() {
	[[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

validate_config_name() {
	[[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] && [ "$1" != "." ] && [ "$1" != ".." ]
}

openclaw_read_import_path() {
	local prompt="${1:-请输入备份包路径}" path
	read -e -p "$prompt（输入 0 取消）: " path || return 1
	[ "$path" = "0" ] && return 0
	path="${path/#\~/$HOME}"
	if [ -f "$path" ]; then
		realpath -m "$path" 2>/dev/null || printf '%s\n' "$path"
	else
		echo "❌ 文件不存在: $path" >&2
		return 1
	fi
}

DAIMON_NAME="linux-tools-daimon"
DAIMON_BIN="d"
DAIMON_ROOT_DIR="/root/linux-daimon"
DAIMON_SCRIPT_DIR="$DAIMON_ROOT_DIR/daimon"
DAIMON_BACKUP_DIR="$DAIMON_ROOT_DIR/backup"
DAIMON_BACKUP_SH_DIR="$DAIMON_ROOT_DIR/backup-sh"
DAIMON_TOOLS_DIR="$DAIMON_ROOT_DIR/tools"
DAIMON_FZF_DIR="$DAIMON_TOOLS_DIR/fzf"
DAIMON_DOCKER_COMPOSE_UPDATE_DIR="$DAIMON_ROOT_DIR/docker-compose-update"
DAIMON_UPDATE_URL="https://daimon-linux-scripts.333186.xyz/linux-toolbox.sh"
DAIMON_UPDATE_GITHUB_URL="https://raw.githubusercontent.com/daimon3332/linux-tools-daimon/master/linux-toolbox.sh"
DAIMON_UPDATE_GITHUB_PROXY_URL="https://gh-proxy.com/raw.githubusercontent.com/daimon3332/linux-tools-daimon/master/linux-toolbox.sh"
DAIMON_LOCAL_SCRIPT="$DAIMON_ROOT_DIR/linux-toolbox.sh"
DAIMON_OLD_LOCAL_SCRIPT="$DAIMON_ROOT_DIR/daimon.sh"
DAIMON_REPO_URL="https://github.com/daimon3332/linux-tools-daimon"
DAIMON_AGREEMENT_URL="https://github.com/daimon3332/linux-tools-daimon/blob/master/USER_AGREEMENT.md"
DAIMON_GITHUB_PROXY_PRIMARY="https://gh-proxy.com/"
DAIMON_CERT_HELPER_MARKER="$DAIMON_ROOT_DIR/.update-cert-helper"
mkdir -p "$DAIMON_SCRIPT_DIR" "$DAIMON_BACKUP_DIR" "$DAIMON_BACKUP_SH_DIR" "$DAIMON_TOOLS_DIR" "$DAIMON_DOCKER_COMPOSE_UPDATE_DIR" >/dev/null 2>&1 || true

daimon_migrate_path() {
	local old_path="$1"
	local new_path="$2"
	[ "$(id -u 2>/dev/null)" = "0" ] || return 0
	[ -e "$old_path" ] || [ -L "$old_path" ] || return 0
	[ "$old_path" != "$new_path" ] || return 0
	case "$old_path" in
		/root/daimon|/root/backup|/root/backup-sh|/root/docker-compose-update|/root/.fzf|/root/linux-toolbox.sh|/root/daimon.sh) ;;
		*) return 0 ;;
	esac
	[ ! -L "$old_path" ] && [ ! -L "$new_path" ] || return 1
	case "$(realpath -m -- "$new_path")" in
		"$(realpath -m -- "$DAIMON_ROOT_DIR")"/*) ;;
		*) return 1 ;;
	esac
	mkdir -p "$(dirname "$new_path")" || return 1
	# Legacy paths may contain user data. Copy only; never delete conflicts or sources.
	if [ -d "$old_path" ]; then
		mkdir -p "$new_path" && cp -an -- "$old_path"/. "$new_path"/
	else
		cp -an -- "$old_path" "$new_path"
	fi
}


daimon_migrate_runtime_layout() {
	[ "$(id -u 2>/dev/null)" = "0" ] || return 0
	daimon_migrate_path "/root/daimon" "$DAIMON_SCRIPT_DIR"
	daimon_migrate_path "/root/backup" "$DAIMON_BACKUP_DIR"
	daimon_migrate_path "/root/backup-sh" "$DAIMON_BACKUP_SH_DIR"
	daimon_migrate_path "/root/docker-compose-update" "$DAIMON_DOCKER_COMPOSE_UPDATE_DIR"
	daimon_migrate_path "/root/.fzf" "$DAIMON_FZF_DIR"
	daimon_migrate_path "/root/linux-toolbox.sh" "$DAIMON_LOCAL_SCRIPT"
	daimon_migrate_path "/root/daimon.sh" "$DAIMON_OLD_LOCAL_SCRIPT"

}

daimon_migrate_runtime_layout

daimon_country() {
	if [ -n "${DAIMON_COUNTRY_CACHE:-}" ]; then
		echo "$DAIMON_COUNTRY_CACHE"
		return 0
	fi
	if command -v curl >/dev/null 2>&1; then
		DAIMON_COUNTRY_CACHE=$(curl -s --max-time 5 https://ipinfo.io 2>/dev/null | grep -oE '"country"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | cut -d'"' -f4)
		[ -z "$DAIMON_COUNTRY_CACHE" ] && DAIMON_COUNTRY_CACHE=$(curl -s --max-time 5 https://ipinfo.io/country 2>/dev/null | tr -d '[:space:]')
	fi
	echo "$DAIMON_COUNTRY_CACHE"
}

daimon_is_cn() {
	[ "$(daimon_country)" = "CN" ]
}

daimon_strip_github_proxy() {
	local url="$1"
	case "$url" in
		https://gh-proxy.com/http*) echo "${url#https://gh-proxy.com/}" ;;
		https://ghproxy.net/http*) echo "${url#https://ghproxy.net/}" ;;
		https://ghfast.top/http*) echo "${url#https://ghfast.top/}" ;;
		https://gh.kejilion.pro/raw.githubusercontent.com/*) echo "https://${url#https://gh.kejilion.pro/}" ;;
		https://gh.kejilion.pro/github.com/*) echo "https://${url#https://gh.kejilion.pro/}" ;;
		*) echo "$url" ;;
	esac
}

daimon_jsdelivr_url() {
	local url="$1" path owner repo branch rest
	case "$url" in
		https://raw.githubusercontent.com/*)
			path="${url#https://raw.githubusercontent.com/}"
			owner="${path%%/*}"; path="${path#*/}"
			repo="${path%%/*}"; path="${path#*/}"
			path="${path#refs/heads/}"
			branch="${path%%/*}"; rest="${path#*/}"
			[ -n "$owner" ] && [ -n "$repo" ] && [ -n "$branch" ] && [ -n "$rest" ] && echo "https://testingcf.jsdelivr.net/gh/${owner}/${repo}@${branch}/${rest}"
			;;
		https://github.com/*/raw/refs/heads/*)
			path="${url#https://github.com/}"
			owner="${path%%/*}"; path="${path#*/}"
			repo="${path%%/*}"; path="${path#*/raw/refs/heads/}"
			branch="${path%%/*}"; rest="${path#*/}"
			[ -n "$owner" ] && [ -n "$repo" ] && [ -n "$branch" ] && [ -n "$rest" ] && echo "https://testingcf.jsdelivr.net/gh/${owner}/${repo}@${branch}/${rest}"
			;;
	esac
}

daimon_github_url_candidates() {
	local url jsdelivr
	url=$(daimon_strip_github_proxy "$1")
	if ! daimon_is_cn; then
		echo "$url"
		return 0
	fi
	case "$url" in
		https://raw.githubusercontent.com/*|https://github.com/*)
			echo "https://gh-proxy.com/$url"
			echo "https://ghproxy.net/$url"
			jsdelivr=$(daimon_jsdelivr_url "$url")
			[ -n "$jsdelivr" ] && echo "$jsdelivr"
			echo "https://ghfast.top/$url"
			echo "$url"
			;;
		*)
			echo "$url"
			;;
	esac
}

daimon_url() {
	daimon_github_url_candidates "$1" | head -1
}

daimon_download_to() {
	local url="$1"
	local target="$2"
	local download_timeout="${3:-180}" real_url tmp
	mkdir -p "$(dirname "$target")" || return 1
	tmp=$(mktemp "${target}.download.XXXXXX") || return 1
	while IFS= read -r real_url; do
		[ -z "$real_url" ] && continue
		echo -e "${gl_kjlan}尝试下载: $real_url${gl_bai}"
		if curl -fsSL --connect-timeout 10 --max-time "$download_timeout" \
			--speed-limit 1024 --speed-time 15 --retry 1 --retry-max-time "$download_timeout" \
			"$real_url" -o "$tmp" && [ -s "$tmp" ]; then
			mv -f -- "$tmp" "$target" && return 0
			break
		fi
		if command -v wget >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1 &&
			timeout "$download_timeout" wget --timeout=15 --tries=1 -qO "$tmp" "$real_url" && [ -s "$tmp" ]; then
			mv -f -- "$tmp" "$target" && return 0
			break
		fi
	done < <(daimon_github_url_candidates "$url")
	rm -f -- "$tmp"
	return 1
}

daimon_update_fallback_url() {
	if [ "$canshu" = "CN" ] || daimon_is_cn; then
		echo "$DAIMON_UPDATE_GITHUB_PROXY_URL"
	else
		echo "$DAIMON_UPDATE_GITHUB_URL"
	fi
}

daimon_try_download_url() {
	local url="$1"
	local target="$2"
	echo "下载地址: $url"
	rm -f "$target" 2>/dev/null || true
	curl -fsSL --connect-timeout 10 --max-time 60 --retry 2 -o "$target" "$url" 2>/dev/null && [ -s "$target" ] && return 0
	if command -v wget >/dev/null 2>&1; then
		timeout 60 wget --timeout=15 --tries=1 -qO "$target" "$url" 2>/dev/null && [ -s "$target" ] && return 0
	fi
	return 1
}

daimon_validate_update_file() {
	local file="$1"
	if [ ! -s "$file" ]; then
		echo -e "${gl_hong}校验失败：下载文件为空${gl_bai}"
		return 1
	fi
	if ! head -1 "$file" 2>/dev/null | grep -q '^#!/bin/bash'; then
		echo -e "${gl_hong}校验失败：下载到的不是 linux-toolbox.sh 脚本${gl_bai}"
		echo "文件首行: $(head -1 "$file" 2>/dev/null)"
		return 1
	fi
	if ! grep -q 'DAIMON_NAME="linux-tools-daimon"' "$file" 2>/dev/null; then
		echo -e "${gl_hong}校验失败：未检测到 linux-tools-daimon 标识${gl_bai}"
		return 1
	fi
	bash -n "$file" || { echo "更新脚本语法校验失败，未安装。"; return 1; }
	return 0
}

daimon_install_script_file() {
	local source="$1" target="$2" staged
	daimon_validate_update_file "$source" || return 1
	staged=$(mktemp "${target}.XXXXXX") || return 1
	if ! command install -m 755 "$source" "$staged" || ! mv -f -- "$staged" "$target"; then
		rm -f -- "$staged"
		return 1
	fi
}

daimon_download_update_file() {
	local target="$1"
	local primary="${DAIMON_UPDATE_URL:-https://daimon-linux-scripts.333186.xyz/linux-toolbox.sh}"
	local fallback
	fallback=$(daimon_update_fallback_url)

	if daimon_try_download_url "$primary" "$target" && daimon_validate_update_file "$target"; then
		return 0
	fi

	echo -e "${gl_huang}主更新地址失败，切换 GitHub 仓库地址...${gl_bai}"
	if daimon_try_download_url "$fallback" "$target" && daimon_validate_update_file "$target"; then
		return 0
	fi

	if [ "$fallback" != "$DAIMON_UPDATE_GITHUB_URL" ]; then
		echo -e "${gl_huang}指定 GitHub 代理失败，继续尝试备用 GitHub 代理...${gl_bai}"
		if daimon_download_to "$DAIMON_UPDATE_GITHUB_URL" "$target" && daimon_validate_update_file "$target"; then
			return 0
		fi
	fi

	rm -f "$target" 2>/dev/null || true
	return 1
}

daimon_download() {
	local url="$1"
	local name="$2"
	mkdir -p "$DAIMON_SCRIPT_DIR" >/dev/null 2>&1 || return 1
	local target="$DAIMON_SCRIPT_DIR/$name"
	if [ -s "$target" ]; then
		echo -e "${gl_lv}使用本地缓存: $target${gl_bai}"
		chmod +x "$target" >/dev/null 2>&1
		return 0
	fi
	echo -e "${gl_kjlan}下载到: $target${gl_bai}"
	daimon_download_to "$url" "$target" || return 1
	chmod +x "$target" >/dev/null 2>&1
}

daimon_git_clone() {
	local repo_url="$1"
	local target="$2"
	shift 2
	local clone_url
	while IFS= read -r clone_url; do
		[ -z "$clone_url" ] && continue
		echo -e "${gl_kjlan}尝试克隆: $clone_url${gl_bai}"
		git clone "$@" "$clone_url" "$target" && return 0
	done < <(daimon_github_url_candidates "$repo_url")
	return 1
}

daimon_run_cached_script() {
	local url="$1"
	local name="$2"
	shift 2
	daimon_download "$url" "$name" || return 1
	if [ -n "${DAIMON_SCRIPT_TIMEOUT:-}" ]; then
		timeout "$DAIMON_SCRIPT_TIMEOUT" bash "$DAIMON_SCRIPT_DIR/$name" "$@"
	else
		bash "$DAIMON_SCRIPT_DIR/$name" "$@"
	fi
}


daimon_exec_cached_script() {
	local url="$1"
	local name="$2"
	shift 2
	daimon_download "$url" "$name" || exit 1
	clear
	echo -e "${gl_kjlan}已退出 daimon，正在运行: bash $DAIMON_SCRIPT_DIR/$name $*${gl_bai}"
	exec bash "$DAIMON_SCRIPT_DIR/$name" "$@"
}


quanju_canshu() {
if [ "$canshu" = "CN" ] || daimon_is_cn; then
	zhushi=0
	gh_proxy="$DAIMON_GITHUB_PROXY_PRIMARY"https://
elif [ "$canshu" = "V6" ]; then
	zhushi=1
	gh_proxy="$DAIMON_GITHUB_PROXY_PRIMARY"https://
else
	zhushi=1  # 0 表示执行，1 表示不执行
	gh_proxy="https://"
fi

gh_https_url="$gh_proxy"

}
quanju_canshu



# 定义一个函数来执行命令
run_command() {
	if [ "$zhushi" -eq 0 ]; then
		"$@"
	fi
}


canshu_v6() {
	if grep -q '^canshu="V6"' /usr/local/bin/d > /dev/null 2>&1; then
		sed -i 's/^canshu="default"/canshu="V6"/' "$DAIMON_LOCAL_SCRIPT"
	elif grep -q '^canshu="V6"' "$DAIMON_LOCAL_SCRIPT.bak" "$DAIMON_OLD_LOCAL_SCRIPT.bak" > /dev/null 2>&1; then
		sed -i 's/^canshu="default"/canshu="V6"/' "$DAIMON_LOCAL_SCRIPT"
	fi
}


CheckFirstRun_true() {
	if grep -q '^permission_granted="true"' /usr/local/bin/d > /dev/null 2>&1; then
		sed -i 's/^permission_granted="false"/permission_granted="true"/' "$DAIMON_LOCAL_SCRIPT"
	elif grep -q '^permission_granted="true"' "$DAIMON_LOCAL_SCRIPT.bak" "$DAIMON_OLD_LOCAL_SCRIPT.bak" > /dev/null 2>&1; then
		sed -i 's/^permission_granted="false"/permission_granted="true"/' "$DAIMON_LOCAL_SCRIPT"
	fi
}



# 收集功能埋点信息的函数，记录当前脚本版本号，使用时间，系统版本，CPU架构，机器所在国家和用户使用的功能名称，绝对不涉及任何敏感信息，请放心！请相信我！
# 为什么要设计这个功能，目的更好的了解用户喜欢使用的功能，进一步优化功能推出更多符合用户需求的功能。
# 全文可搜搜 send_stats 函数调用位置，透明开源，如有顾虑可拒绝使用。



send_stats() {
	if [ "$ENABLE_STATS" == "false" ]; then
		return
	fi

	local country=$(curl -s ipinfo.io/country)
	local os_info=$(grep PRETTY_NAME /etc/os-release | cut -d '=' -f2 | tr -d '"')
	local cpu_arch=$(uname -m)

	(
		curl -s -X POST "https://api.kejilion.pro/api/log" \
			-H "Content-Type: application/json" \
			-d "{\"action\":\"$1\",\"timestamp\":\"$(date -u '+%Y-%m-%d %H:%M:%S')\",\"country\":\"$country\",\"os_info\":\"$os_info\",\"cpu_arch\":\"$cpu_arch\",\"version\":\"$sh_v\"}" \
		&>/dev/null
	) &

}


yinsiyuanquan2() {

if grep -q '^ENABLE_STATS="false"' /usr/local/bin/d > /dev/null 2>&1; then
	sed -i 's/^ENABLE_STATS="false"/ENABLE_STATS="false"/' "$DAIMON_LOCAL_SCRIPT"
elif grep -q '^ENABLE_STATS="false"' "$DAIMON_LOCAL_SCRIPT.bak" "$DAIMON_OLD_LOCAL_SCRIPT.bak" > /dev/null 2>&1; then
	sed -i 's/^ENABLE_STATS="false"/ENABLE_STATS="false"/' "$DAIMON_LOCAL_SCRIPT"
fi

}



canshu_v6
CheckFirstRun_true
yinsiyuanquan2


daimon_self_install() {
	local running
	running=$(readlink -f -- "${BASH_SOURCE[0]}" 2>/dev/null || true)
	if { [ "$running" = /usr/local/bin/d ] || [ "$running" = "$DAIMON_LOCAL_SCRIPT" ]; } &&
		[ -s /usr/local/bin/d ] && [ -s "$DAIMON_LOCAL_SCRIPT" ]; then
		return 0
	fi
	# 直接运行 linux-toolbox.sh 时自动安装快捷命令 d，不再需要单独的 install.sh
	sed -i '/^alias d=/d' ~/.bashrc > /dev/null 2>&1
	sed -i '/^alias d=/d' ~/.profile > /dev/null 2>&1
	sed -i '/^alias d=/d' ~/.bash_profile > /dev/null 2>&1

	local tmp_file="/tmp/linux-toolbox.sh"
	local local_source=""
	local keep_permission="false"

	if grep -q '^permission_granted="true"' /usr/local/bin/d "$DAIMON_LOCAL_SCRIPT" "$DAIMON_OLD_LOCAL_SCRIPT" >/dev/null 2>&1; then
		keep_permission="true"
	fi

	# Install only the executing file, never a same-named file from the working directory.
	if [ -n "${BASH_SOURCE[0]}" ] && [ -f "${BASH_SOURCE[0]}" ] && ! echo "${BASH_SOURCE[0]}" | grep -Eq '^/dev/fd/|^/proc/.*/fd/' && head -1 "${BASH_SOURCE[0]}" 2>/dev/null | grep -q '^#!/bin/bash'; then
		local_source="${BASH_SOURCE[0]}"
	elif [ -f "$0" ] && ! echo "$0" | grep -Eq '^/dev/fd/|^/proc/.*/fd/' && head -1 "$0" 2>/dev/null | grep -q '^#!/bin/bash'; then
		local_source="$0"
	fi

	if [ -n "$local_source" ]; then
		daimon_install_script_file "$local_source" "$DAIMON_LOCAL_SCRIPT" || return 1
	elif [ -n "$DAIMON_UPDATE_URL" ]; then
		if daimon_download_update_file "$tmp_file" >/dev/null 2>&1; then
			daimon_install_script_file "$tmp_file" "$DAIMON_LOCAL_SCRIPT" || return 1
		fi
	fi

	if [ -s "$DAIMON_LOCAL_SCRIPT" ]; then
		chmod +x "$DAIMON_LOCAL_SCRIPT" > /dev/null 2>&1
		daimon_install_script_file "$DAIMON_LOCAL_SCRIPT" /usr/local/bin/d || return 1
		chmod +x /usr/local/bin/d > /dev/null 2>&1
		ln -sf /usr/local/bin/d /usr/bin/d > /dev/null 2>&1
		if [ "$keep_permission" = "true" ]; then
			sed -i 's/^permission_granted="false"/permission_granted="true"/' "$DAIMON_LOCAL_SCRIPT" >/dev/null 2>&1
			sed -i 's/^permission_granted="false"/permission_granted="true"/' /usr/local/bin/d >/dev/null 2>&1
		fi
	fi
}

daimon_self_install



CheckFirstRun_false() {
	if grep -q '^permission_granted="false"' /usr/local/bin/d > /dev/null 2>&1; then
		UserLicenseAgreement
	fi
}

# 提示用户同意条款
UserLicenseAgreement() {
	clear
	echo -e "${gl_kjlan}欢迎使用linux-tools-daimon${gl_bai}"
	echo "首次使用脚本，请先阅读并确认以下说明。"
	echo "项目名称: linux-tools-daimon"
	echo "开源仓库: ${DAIMON_REPO_URL}"
	echo "用户说明: ${DAIMON_AGREEMENT_URL}"
	echo "使用说明: 本脚本为个人开源工具，按现状提供，请在了解命令作用后自行决定是否执行。"
	echo "风险提示: 脚本中的系统配置、Docker、Nginx、证书、网络优化等操作可能修改服务器状态，请提前备份重要数据。"
	echo -e "----------------------"
	read -e -p "是否已阅读并确认继续使用？(y/n): " user_input || exit 1


	if [ "$user_input" = "y" ] || [ "$user_input" = "Y" ]; then
		send_stats "许可同意"
		sed -i 's/^permission_granted="false"/permission_granted="true"/' "$DAIMON_LOCAL_SCRIPT"
		sed -i 's/^permission_granted="false"/permission_granted="true"/' /usr/local/bin/d
	else
		send_stats "许可拒绝"
		clear
		exit
	fi
}

CheckFirstRun_false





ip_address() {

get_public_ip() {
	curl -s https://ipinfo.io/ip && echo
}

get_local_ip() {
	ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[^ ]+' || \
	hostname -I 2>/dev/null | awk '{print $1}' || \
	ifconfig 2>/dev/null | grep -E 'inet [0-9]' | grep -v '127.0.0.1' | awk '{print $2}' | head -n1
}

public_ip=$(get_public_ip)
isp_info=$(curl -s --max-time 3 http://ipinfo.io/org)


if echo "$isp_info" | grep -Eiq 'CHINANET|mobile|unicom|telecom'; then
  ipv4_address=$(get_local_ip)
else
  ipv4_address="$public_ip"
fi


# ipv4_address=$(curl -s https://ipinfo.io/ip && echo)
ipv6_address=$(curl -s --max-time 1 https://v6.ipinfo.io/ip && echo)

}



install() {
	if [ $# -eq 0 ]; then
		echo "未提供软件包参数!"
		return 1
	fi

	local package
	for package in "$@"; do
		if ! command -v "$package" &>/dev/null; then
			echo -e "${gl_kjlan}正在安装 $package...${gl_bai}"
			if command -v dnf &>/dev/null; then
				dnf makecache || return 1
				dnf install -y epel-release || return 1
				dnf install -y "$package" || return 1
			elif command -v yum &>/dev/null; then
				yum makecache || return 1
				yum install -y epel-release || return 1
				yum install -y "$package" || return 1
			elif command -v apt &>/dev/null; then
				DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt update -y || return 1
				DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt install -y \
					-o Dpkg::Options::="--force-confdef" \
					-o Dpkg::Options::="--force-confold" \
					"$package" || return 1
			elif command -v apk &>/dev/null; then
				apk update || return 1
				apk add "$package" || return 1
			elif command -v pacman &>/dev/null; then
				pacman -Syu --noconfirm "$package" || return 1
			elif command -v zypper &>/dev/null; then
				zypper refresh || return 1
				zypper install -y "$package" || return 1
			elif command -v opkg &>/dev/null; then
				opkg update || return 1
				opkg install "$package" || return 1
			elif command -v pkg &>/dev/null; then
				pkg update || return 1
				pkg install -y "$package" || return 1
			else
				echo "未知的包管理器!"
				return 1
			fi
		fi
	done
}


check_disk_space() {
	local required_gb=$1
	local path=${2:-/}

	mkdir -p "$path"

	local required_space_mb=$((required_gb * 1024))
	local available_space_mb=$(df -m "$path" | awk 'NR==2 {print $4}')

	if [ "$available_space_mb" -lt "$required_space_mb" ]; then
		echo -e "${gl_huang}提示: ${gl_bai}磁盘空间不足！"
		echo "当前可用空间: $((available_space_mb/1024))G"
		echo "最小需求空间: ${required_gb}G"
		echo "无法继续安装，请清理磁盘空间后重试。"
		send_stats "磁盘空间不足"
		break_end
		kejilion
	fi
}



install_dependency() {
	switch_mirror false false
	check_port
	check_swap
	prefer_ipv4
	auto_optimize_dns
	install wget unzip tar jq grep

}

remove() {
	if [ $# -eq 0 ]; then
		echo "未提供软件包参数!"
		return 1
	fi

	for package in "$@"; do
		echo -e "${gl_kjlan}正在卸载 $package...${gl_bai}"
		if command -v dnf &>/dev/null; then
			dnf remove -y "$package"
		elif command -v yum &>/dev/null; then
			yum remove -y "$package"
		elif command -v apt &>/dev/null; then
			apt purge -y "$package"
		elif command -v apk &>/dev/null; then
			apk del "$package"
		elif command -v pacman &>/dev/null; then
			pacman -Rns --noconfirm "$package"
		elif command -v zypper &>/dev/null; then
			zypper remove -y "$package"
		elif command -v opkg &>/dev/null; then
			opkg remove "$package"
		elif command -v pkg &>/dev/null; then
			pkg delete -y "$package"
		else
			echo "未知的包管理器!"
			return 1
		fi
	done
}


# 通用 systemctl 函数，适用于各种发行版
systemctl() {
	local COMMAND="$1"
	shift

	if command -v apk &>/dev/null; then
		if [ "$#" -eq 0 ]; then
			service "$COMMAND"
		else
			local SERVICE_NAME
			for SERVICE_NAME in "$@"; do
				service "$SERVICE_NAME" "$COMMAND" || return $?
			done
		fi
	else
		/bin/systemctl "$COMMAND" "$@"
	fi
}


# 重启服务
restart() {
	local RC
	systemctl restart "$@"
	RC=$?
	if [ "$RC" -eq 0 ]; then
		echo "$1 服务已重启。"
	else
		echo "错误：重启 $1 服务失败。"
	fi
	return "$RC"
}

# 启动服务
start() {
	local RC
	systemctl start "$@"
	RC=$?
	if [ "$RC" -eq 0 ]; then
		echo "$1 服务已启动。"
	else
		echo "错误：启动 $1 服务失败。"
	fi
	return "$RC"
}

# 停止服务
stop() {
	local RC
	systemctl stop "$@"
	RC=$?
	if [ "$RC" -eq 0 ]; then
		echo "$1 服务已停止。"
	else
		echo "错误：停止 $1 服务失败。"
	fi
	return "$RC"
}

# 查看服务状态
status() {
	local RC
	systemctl status "$@"
	RC=$?
	if [ "$RC" -eq 0 ]; then
		echo "$1 服务状态已显示。"
	else
		echo "错误：无法显示 $1 服务状态。"
	fi
	return "$RC"
}


enable() {
	local SERVICE_NAME="$1"
	local RC
	if command -v apk &>/dev/null; then
		rc-update add "$SERVICE_NAME" default
	else
	   /bin/systemctl enable "$SERVICE_NAME"
	fi
	RC=$?

	if [ "$RC" -eq 0 ]; then
		echo "$SERVICE_NAME 已设置为开机自启。"
	else
		echo "错误：设置 $SERVICE_NAME 开机自启失败。"
	fi
	return "$RC"
}



break_end() {
	  echo -e "${gl_lv}操作完成${gl_bai}"
	  echo "按任意键继续..."
	  read -n 1 -s -r -p ""
	  echo ""
	  clear
}

kejilion() {
			cd ~
			kejilion_sh
}




stop_containers_or_kill_process() {
	local port=$1
	local containers=$(docker ps --filter "publish=$port" --format "{{.ID}}" 2>/dev/null)

	if [ -n "$containers" ]; then
		docker stop $containers
	else
		install lsof
		for pid in $(lsof -t -i:$port); do
			kill -9 $pid
		done
	fi
}


check_port() {
	stop_containers_or_kill_process 80
	stop_containers_or_kill_process 443
}


install_add_docker_cn() {
	mkdir -p /etc/docker
	cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://hub.333186.xyz",
    "https://docker.m.daocloud.io",
    "https://docker.1ms.run",
    "https://docker.registry.cyou"
  ]
}
EOF
	enable docker
	start docker
	restart docker
}

docker_mirror_menu() {
	install vim
	mkdir -p /etc/docker
	local mirrors=(
		"https://hub.333186.xyz"
		"https://docker.m.daocloud.io"
		"https://docker.1ms.run"
		"https://docker.registry.cyou"
	)
	local mirror_names=(
		"hub.333186.xyz"
		"docker.m.daocloud.io"
		"docker.1ms.run"
		"docker.registry.cyou"
	)
	clear
	echo "Docker 镜像源多选"
	echo "------------------------"
	for i in "${!mirrors[@]}"; do
		printf "%2d. %-24s %s\n" "$((i+1))" "${mirror_names[$i]}" "${mirrors[$i]}"
	done
	echo "------------------------"
	echo "输入编号，使用空格分隔；直接回车使用默认源：1 2 3 4"
	echo "输入 0 返回上一级菜单"
	read -e -p "请选择: " selected || return 1
	[ "$selected" = "0" ] && return 90
	selected=${selected:-"1 2 3 4"}
	{
		echo '{'
		echo '  "registry-mirrors": ['
		local first=1
		for idx in $selected; do
			if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt ${#mirrors[@]} ]; then
				echo -e "${gl_huang}跳过无效编号: $idx${gl_bai}" >&2
				continue
			fi
			local mirror="${mirrors[$((idx-1))]}"
			[ -z "$mirror" ] && continue
			if [ "$first" -eq 0 ]; then echo ','; fi
			printf '    "%s"' "$mirror"
			first=0
		done
		echo
		echo '  ]'
		echo '}'
	} > /etc/docker/daemon.json
	cat /etc/docker/daemon.json
	restart docker
}

docker_mirror_default_urls() {
	printf '%s\n' \
		"https://hub.333186.xyz" \
		"https://docker.m.daocloud.io" \
		"https://docker.1ms.run" \
		"https://docker.registry.cyou"
}

docker_mirror_normalize_host() {
	local s="$1"
	s="${s#http://}"
	s="${s#https://}"
	s="${s%%/*}"
	echo "$s"
}

docker_mirror_scheme_url() {
	local s="$1"
	if [[ "$s" =~ ^https?:// ]]; then
		echo "${s%/}"
	else
		echo "https://${s%/}"
	fi
}

docker_mirror_size_mb() {
	awk -v b="$1" 'BEGIN { printf "%.2f", b / 1024 / 1024 }'
}

docker_mirror_rate_mb_s() {
	awk -v mb="$1" -v sec="$2" 'BEGIN { if (sec > 0) printf "%.2f", mb / sec; else printf "0.00" }'
}

docker_mirror_cleanup_test_image() {
	local ref="$1"
	docker image rm -f "$ref" >/dev/null 2>&1 || true
	docker image prune -f >/dev/null 2>&1 || true
}

docker_mirror_ask_official() {
	local answer
	read -e -p "是否加入官方镜像源 registry-1.docker.io？(y/N): " answer || return 1
	case "$answer" in
		[Yy]) return 0 ;;
		*) return 1 ;;
	esac
}

docker_mirror_speed_run() {
	local timeout_sec="$1"
	local rounds="$2"
	shift 2
	local mirrors=("$@")
	local image="${IMAGE:-library/python:3.12-slim}"
	local platform="${PLATFORM:-}"
	local pull_args=()
	local round mirror base_url host ref start_ms end_ms status size_bytes rc pull_time mb speed

	if ! command -v docker >/dev/null 2>&1; then
		echo -e "${gl_hong}未检测到 docker，请先安装并启动 Docker。${gl_bai}"
		return 1
	fi
	if ! command -v timeout >/dev/null 2>&1 || ! command -v awk >/dev/null 2>&1; then
		echo -e "${gl_hong}缺少 timeout 或 awk 命令。${gl_bai}"
		return 1
	fi
	if [ ${#mirrors[@]} -eq 0 ]; then
		echo -e "${gl_huang}没有可测速的镜像源。${gl_bai}"
		return 1
	fi
	[ -n "$platform" ] && pull_args+=(--platform "$platform")

	echo "image=$image timeout=${timeout_sec}s rounds=$rounds"
	echo "说明：每次测速前后会删除测试镜像引用并清理 dangling 镜像；若本机已有相同镜像层缓存，结果仍可能偏快。"
	echo "------------------------"
	for round in $(seq 1 "$rounds"); do
		for mirror in "${mirrors[@]}"; do
			base_url="$(docker_mirror_scheme_url "$mirror")"
			host="$(docker_mirror_normalize_host "$mirror")"
			ref="${host}/${image}"
			echo "round=${round} mirror=${base_url}"
			docker_mirror_cleanup_test_image "$ref"
			start_ms="$(date +%s%3N)"
			if timeout "${timeout_sec}s" docker pull "${pull_args[@]}" "$ref" >/dev/null 2>&1; then
				end_ms="$(date +%s%3N)"
				status="OK"
				size_bytes="$(docker image inspect -f '{{.Size}}' "$ref" 2>/dev/null || echo 0)"
				docker_mirror_cleanup_test_image "$ref"
			else
				rc=$?
				end_ms="$(date +%s%3N)"
				if [ "$rc" -eq 124 ]; then
					status="FAIL(timeout ${timeout_sec}s)"
				else
					status="FAIL"
				fi
				size_bytes=0
				docker_mirror_cleanup_test_image "$ref"
			fi
			pull_time="$(awk -v s="$start_ms" -v e="$end_ms" 'BEGIN { printf "%.3f", (e - s) / 1000 }')"
			mb="$(docker_mirror_size_mb "$size_bytes")"
			speed="$(docker_mirror_rate_mb_s "$mb" "$pull_time")"
			echo "${status} pull=${pull_time}s size=${mb}MB approx=${speed}MB/s"
			echo
		done
	done
}

docker_mirror_collect_defaults() {
	local selected="$1"
	local add_official="$2"
	local default_mirrors=()
	local mirrors=()
	local idx
	mapfile -t default_mirrors < <(docker_mirror_default_urls)
	selected=${selected:-"1 2 3 4"}
	for idx in $selected; do
		if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt ${#default_mirrors[@]} ]; then
			echo -e "${gl_huang}跳过无效编号: $idx${gl_bai}" >&2
			continue
		fi
		mirrors+=("${default_mirrors[$((idx-1))]}")
	done
	[ "$add_official" = "yes" ] && mirrors+=("https://registry-1.docker.io")
	printf '%s\n' "${mirrors[@]}"
}

docker_mirror_speed_test_menu() {
	local default_mirrors=()
	mapfile -t default_mirrors < <(docker_mirror_default_urls)
	while true; do
		clear
		echo "Docker镜像源测速"
		echo "------------------------"
		echo "默认镜像源："
		for i in "${!default_mirrors[@]}"; do
			printf "%2d. %s\n" "$((i+1))" "${default_mirrors[$i]}"
		done
		echo "官方镜像源: https://registry-1.docker.io"
		echo "------------------------"
		echo "1. 测速默认镜像源"
		echo "2. 测速第三方镜像源"
		echo "3. 测速第三方镜像源 + 默认镜像源"
		echo "0. 返回上一级菜单"
		echo "------------------------"
		read -e -p "请输入你的选择: " choice || return 1
		case "$choice" in
			1)
				local selected timeout_sec rounds add_official mirrors=()
				read -e -i "1 2 3 4" -p "请选择默认镜像源编号（空格分隔）: " selected || return 1
				read -e -i "100" -p "请输入超时时间（秒）: " timeout_sec || return 1
				read -e -i "1" -p "请输入测速轮数: " rounds || return 1
				if docker_mirror_ask_official; then add_official=yes; else add_official=no; fi
				mapfile -t mirrors < <(docker_mirror_collect_defaults "$selected" "$add_official")
				docker_mirror_speed_run "${timeout_sec:-100}" "${rounds:-1}" "${mirrors[@]}"
				break_end
				;;
			2)
				local third timeout_sec rounds mirrors=()
				read -e -p "请输入第三方镜像源地址: " third || return 1
				[ -z "$third" ] && echo "镜像源不能为空" && break_end && continue
				read -e -i "100" -p "请输入超时时间（秒）: " timeout_sec || return 1
				read -e -i "1" -p "请输入测速轮数: " rounds || return 1
				mirrors+=("$(docker_mirror_scheme_url "$third")")
				if docker_mirror_ask_official; then mirrors+=("https://registry-1.docker.io"); fi
				docker_mirror_speed_run "${timeout_sec:-100}" "${rounds:-1}" "${mirrors[@]}"
				break_end
				;;
			3)
				local third selected timeout_sec rounds add_official mirrors=() default_selected=()
				read -e -p "请输入第三方镜像源地址: " third || return 1
				[ -z "$third" ] && echo "镜像源不能为空" && break_end && continue
				read -e -i "1 2 3 4" -p "请选择默认镜像源编号（空格分隔）: " selected || return 1
				read -e -i "100" -p "请输入超时时间（秒）: " timeout_sec || return 1
				read -e -i "1" -p "请输入测速轮数: " rounds || return 1
				mirrors+=("$(docker_mirror_scheme_url "$third")")
				if docker_mirror_ask_official; then add_official=yes; else add_official=no; fi
				mapfile -t default_selected < <(docker_mirror_collect_defaults "$selected" "$add_official")
				mirrors+=("${default_selected[@]}")
				docker_mirror_speed_run "${timeout_sec:-100}" "${rounds:-1}" "${mirrors[@]}"
				break_end
				;;
			0) return ;;
			*) echo "无效的输入!"; break_end ;;
		esac
	done
}


linuxmirrors_install_docker() {

local country=$(curl -s ipinfo.io/country)
if [ "$country" = "CN" ]; then
	daimon_run_cached_script "https://linuxmirrors.cn/docker.sh" "linuxmirrors-docker.sh" \
	  --source mirrors.huaweicloud.com/docker-ce \
	  --source-registry docker.1ms.run \
	  --protocol https \
	  --use-intranet-source false \
	  --install-latest true \
	  --close-firewall false \
	  --ignore-backup-tips
else
	daimon_run_cached_script "https://linuxmirrors.cn/docker.sh" "linuxmirrors-docker.sh" \
	  --source download.docker.com \
	  --source-registry registry.hub.docker.com \
	  --protocol https \
	  --use-intranet-source false \
	  --install-latest true \
	  --close-firewall false \
	  --ignore-backup-tips
fi

install_add_docker_cn

}



install_add_docker() {
	echo -e "${gl_kjlan}正在安装docker环境...${gl_bai}"
	if command -v apt &>/dev/null || command -v yum &>/dev/null || command -v dnf &>/dev/null; then
		linuxmirrors_install_docker
	else
		install docker docker-compose
		install_add_docker_cn

	fi
	sleep 2
}


install_docker() {
	if ! command -v docker &>/dev/null; then
		install_add_docker
	fi
}


docker_ps() {
while true; do
	clear
	send_stats "Docker容器管理"
	echo "Docker容器列表"
	docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
	echo ""
	echo "容器操作"
	echo "------------------------"
	echo "1. 创建新的容器"
	echo "------------------------"
	echo "2. 启动指定容器             6. 启动所有容器"
	echo "3. 停止指定容器             7. 停止所有容器"
	echo "4. 删除指定容器             8. 删除所有容器"
	echo "5. 重启指定容器             9. 重启所有容器"
	echo "------------------------"
	echo "11. 进入指定容器           12. 查看容器日志"
	echo "13. 查看容器网络           14. 查看容器占用"
	echo "------------------------"
	echo "15. 开启容器端口访问       16. 关闭容器端口访问"
	echo "------------------------"
	echo "0. 返回上一级选单"
	echo "------------------------"
	read -e -p "请输入你的选择: " sub_choice || return 1
	case $sub_choice in
		1)
			send_stats "新建容器"
			read -e -p "请输入创建命令: " dockername || return 1
			$dockername
			;;
		2)
			send_stats "启动指定容器"
			read -e -p "请输入容器名（多个容器名请用空格分隔）: " dockername || return 1
			docker start $dockername
			;;
		3)
			send_stats "停止指定容器"
			read -e -p "请输入容器名（多个容器名请用空格分隔）: " dockername || return 1
			docker stop $dockername
			;;
		4)
			send_stats "删除指定容器"
			read -e -p "请输入容器名（多个容器名请用空格分隔）: " dockername || return 1
			docker rm -f $dockername
			;;
		5)
			send_stats "重启指定容器"
			read -e -p "请输入容器名（多个容器名请用空格分隔）: " dockername || return 1
			docker restart $dockername
			;;
		6)
			send_stats "启动所有容器"
			docker start $(docker ps -a -q)
			;;
		7)
			send_stats "停止所有容器"
			docker stop $(docker ps -q)
			;;
		8)
			send_stats "删除所有容器"
			read -e -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定删除所有容器吗？(Y/N): ")" choice || return 1
			case "$choice" in
			  [Yy])
				docker rm -f $(docker ps -a -q)
				;;
			  [Nn])
				;;
			  *)
				echo "无效的选择，请输入 Y 或 N。"
				;;
			esac
			;;
		9)
			send_stats "重启所有容器"
			docker restart $(docker ps -q)
			;;
		11)
			send_stats "进入容器"
			read -e -p "请输入容器名: " dockername || return 1
			docker exec -it $dockername /bin/sh
			break_end
			;;
		12)
			send_stats "查看容器日志"
			read -e -p "请输入容器名: " dockername || return 1
			docker logs $dockername
			break_end
			;;
		13)
			send_stats "查看容器网络"
			echo ""
			container_ids=$(docker ps -q)
			echo "------------------------------------------------------------"
			printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"
			for container_id in $container_ids; do
				local container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")
				local container_name=$(echo "$container_info" | awk '{print $1}')
				local network_info=$(echo "$container_info" | cut -d' ' -f2-)
				while IFS= read -r line; do
					local network_name=$(echo "$line" | awk '{print $1}')
					local ip_address=$(echo "$line" | awk '{print $2}')
					printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
				done <<< "$network_info"
			done
			break_end
			;;
		14)
			send_stats "查看容器占用"
			docker stats --no-stream
			break_end
			;;

		15)
			send_stats "允许容器端口访问"
			read -e -p "请输入容器名: " docker_name || return 1
			ip_address
			clear_container_rules "$docker_name" "$ipv4_address"
			local docker_port=$(docker port $docker_name | awk -F'[:]' '/->/ {print $NF}' | uniq)
			check_docker_app_ip
			break_end
			;;

		16)
			send_stats "阻止容器端口访问"
			read -e -p "请输入容器名: " docker_name || return 1
			ip_address
			block_container_port "$docker_name" "$ipv4_address"
			local docker_port=$(docker port $docker_name | awk -F'[:]' '/->/ {print $NF}' | uniq)
			check_docker_app_ip
			break_end
			;;

		0)
			return 90
			;;
		*)
			break  # 跳出循环，退出菜单
			;;
	esac
done
}


docker_image() {
while true; do
	clear
	send_stats "Docker镜像管理"
	echo "Docker镜像列表"
	docker image ls
	echo ""
	echo "镜像操作"
	echo "------------------------"
	echo "1. 获取指定镜像             3. 删除指定镜像"
	echo "2. 更新指定镜像             4. 删除所有镜像"
	echo "------------------------"
	echo "0. 返回上一级选单"
	echo "------------------------"
	read -e -p "请输入你的选择: " sub_choice || return 1
	case $sub_choice in
		1)
			send_stats "拉取镜像"
			read -e -p "请输入镜像名（多个镜像名请用空格分隔）: " imagenames || return 1
			for name in $imagenames; do
				echo -e "${gl_kjlan}正在获取镜像: $name${gl_bai}"
				docker pull $name
			done
			;;
		2)
			send_stats "更新镜像"
			read -e -p "请输入镜像名（多个镜像名请用空格分隔）: " imagenames || return 1
			for name in $imagenames; do
				echo -e "${gl_kjlan}正在更新镜像: $name${gl_bai}"
				docker pull $name
			done
			;;
		3)
			send_stats "删除镜像"
			read -e -p "请输入镜像名（多个镜像名请用空格分隔）: " imagenames || return 1
			for name in $imagenames; do
				docker rmi -f $name
			done
			;;
		4)
			send_stats "删除所有镜像"
			read -e -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定删除所有镜像吗？(Y/N): ")" choice || return 1
			case "$choice" in
			  [Yy])
				docker rmi -f $(docker images -q)
				;;
			  [Nn])
				;;
			  *)
				echo "无效的选择，请输入 Y 或 N。"
				;;
			esac
			;;
		0)
			return 90
			;;
		*)
			break  # 跳出循环，退出菜单
			;;
	esac
done


}





check_crontab_installed() {
	if ! command -v crontab >/dev/null 2>&1; then
		install_crontab
	fi
}



install_crontab() {

	if [ -f /etc/os-release ]; then
		. /etc/os-release
		case "$ID" in
			ubuntu|debian|kali)
				apt update
				apt install -y cron
				systemctl enable cron
				systemctl start cron
				;;
			centos|rhel|almalinux|rocky|fedora)
				yum install -y cronie
				systemctl enable crond
				systemctl start crond
				;;
			alpine)
				apk add --no-cache cronie
				rc-update add crond
				rc-service crond start
				;;
			arch|manjaro)
				pacman -S --noconfirm cronie
				systemctl enable cronie
				systemctl start cronie
				;;
			opensuse|suse|opensuse-tumbleweed)
				zypper install -y cron
				systemctl enable cron
				systemctl start cron
				;;
			iStoreOS|openwrt|ImmortalWrt|lede)
				opkg update
				opkg install cron
				/etc/init.d/cron enable
				/etc/init.d/cron start
				;;
			FreeBSD)
				pkg install -y cronie
				sysrc cron_enable="YES"
				service cron start
				;;
			*)
				echo "不支持的发行版: $ID"
				return
				;;
		esac
	else
		echo "无法确定操作系统。"
		return
	fi

	echo -e "${gl_lv}crontab 已安装且 cron 服务正在运行。${gl_bai}"
}



docker_ipv6_on() {
	root_use
	install jq

	local CONFIG_FILE="/etc/docker/daemon.json"
	local REQUIRED_IPV6_CONFIG='{"ipv6": true, "fixed-cidr-v6": "2001:db8:1::/64"}'

	# 检查配置文件是否存在，如果不存在则创建文件并写入默认设置
	if [ ! -f "$CONFIG_FILE" ]; then
		echo "$REQUIRED_IPV6_CONFIG" | jq . > "$CONFIG_FILE"
		restart docker
	else
		# 使用jq处理配置文件的更新
		local ORIGINAL_CONFIG=$(<"$CONFIG_FILE")

		# 检查当前配置是否已经有 ipv6 设置
		local CURRENT_IPV6=$(echo "$ORIGINAL_CONFIG" | jq '.ipv6 // false')

		# 更新配置，开启 IPv6
		if [[ "$CURRENT_IPV6" == "false" ]]; then
			UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq '. + {ipv6: true, "fixed-cidr-v6": "2001:db8:1::/64"}')
		else
			UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq '. + {"fixed-cidr-v6": "2001:db8:1::/64"}')
		fi

		# 对比原始配置与新配置
		if [[ "$ORIGINAL_CONFIG" == "$UPDATED_CONFIG" ]]; then
			echo -e "${gl_huang}当前已开启ipv6访问${gl_bai}"
		else
			echo "$UPDATED_CONFIG" | jq . > "$CONFIG_FILE"
			restart docker
		fi
	fi
}


docker_ipv6_off() {
	root_use
	install jq

	local CONFIG_FILE="/etc/docker/daemon.json"

	# 检查配置文件是否存在
	if [ ! -f "$CONFIG_FILE" ]; then
		echo -e "${gl_hong}配置文件不存在${gl_bai}"
		return
	fi

	# 读取当前配置
	local ORIGINAL_CONFIG=$(<"$CONFIG_FILE")

	# 使用jq处理配置文件的更新
	local UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq 'del(.["fixed-cidr-v6"]) | .ipv6 = false')

	# 检查当前的 ipv6 状态
	local CURRENT_IPV6=$(echo "$ORIGINAL_CONFIG" | jq -r '.ipv6 // false')

	# 对比原始配置与新配置
	if [[ "$CURRENT_IPV6" == "false" ]]; then
		echo -e "${gl_huang}当前已关闭ipv6访问${gl_bai}"
	else
		echo "$UPDATED_CONFIG" | jq . > "$CONFIG_FILE"
		restart docker
		echo -e "${gl_huang}已成功关闭ipv6访问${gl_bai}"
	fi
}



save_iptables_rules() {
	mkdir -p /etc/iptables
	touch /etc/iptables/rules.v4
	iptables-save > /etc/iptables/rules.v4
	check_crontab_installed
	crontab -l | grep -v 'iptables-restore' | crontab - > /dev/null 2>&1
	(crontab -l ; echo '@reboot iptables-restore < /etc/iptables/rules.v4') | crontab - > /dev/null 2>&1

}




iptables_open() {
	install iptables
	save_iptables_rules
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -F

	ip6tables -P INPUT ACCEPT
	ip6tables -P FORWARD ACCEPT
	ip6tables -P OUTPUT ACCEPT
	ip6tables -F

}



open_port() {
	local ports=($@)  # 将传入的参数转换为数组
	if [ ${#ports[@]} -eq 0 ]; then
		echo "请提供至少一个端口号"
		return 1
	fi

	install iptables

	for port in "${ports[@]}"; do
		# 删除已存在的关闭规则
		iptables -D INPUT -p tcp --dport $port -j DROP 2>/dev/null
		iptables -D INPUT -p udp --dport $port -j DROP 2>/dev/null

		# 添加打开规则
		if ! iptables -C INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null; then
			iptables -I INPUT 1 -p tcp --dport $port -j ACCEPT
		fi

		if ! iptables -C INPUT -p udp --dport $port -j ACCEPT 2>/dev/null; then
			iptables -I INPUT 1 -p udp --dport $port -j ACCEPT
			echo "已打开端口 $port"
		fi
	done

	save_iptables_rules
	send_stats "已打开端口"
}


close_port() {
	local ports=($@)  # 将传入的参数转换为数组
	if [ ${#ports[@]} -eq 0 ]; then
		echo "请提供至少一个端口号"
		return 1
	fi

	install iptables

	for port in "${ports[@]}"; do
		# 删除已存在的打开规则
		iptables -D INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null
		iptables -D INPUT -p udp --dport $port -j ACCEPT 2>/dev/null

		# 添加关闭规则
		if ! iptables -C INPUT -p tcp --dport $port -j DROP 2>/dev/null; then
			iptables -I INPUT 1 -p tcp --dport $port -j DROP
		fi

		if ! iptables -C INPUT -p udp --dport $port -j DROP 2>/dev/null; then
			iptables -I INPUT 1 -p udp --dport $port -j DROP
			echo "已关闭端口 $port"
		fi
	done

	# 删除已存在的规则（如果有）
	iptables -D INPUT -i lo -j ACCEPT 2>/dev/null
	iptables -D FORWARD -i lo -j ACCEPT 2>/dev/null

	# 插入新规则到第一条
	iptables -I INPUT 1 -i lo -j ACCEPT
	iptables -I FORWARD 1 -i lo -j ACCEPT

	save_iptables_rules
	send_stats "已关闭端口"
}


allow_ip() {
	local ips=($@)  # 将传入的参数转换为数组
	if [ ${#ips[@]} -eq 0 ]; then
		echo "请提供至少一个IP地址或IP段"
		return 1
	fi

	install iptables

	for ip in "${ips[@]}"; do
		# 删除已存在的阻止规则
		iptables -D INPUT -s $ip -j DROP 2>/dev/null

		# 添加允许规则
		if ! iptables -C INPUT -s $ip -j ACCEPT 2>/dev/null; then
			iptables -I INPUT 1 -s $ip -j ACCEPT
			echo "已放行IP $ip"
		fi
	done

	save_iptables_rules
	send_stats "已放行IP"
}

block_ip() {
	local ips=($@)  # 将传入的参数转换为数组
	if [ ${#ips[@]} -eq 0 ]; then
		echo "请提供至少一个IP地址或IP段"
		return 1
	fi

	install iptables

	for ip in "${ips[@]}"; do
		# 删除已存在的允许规则
		iptables -D INPUT -s $ip -j ACCEPT 2>/dev/null

		# 添加阻止规则
		if ! iptables -C INPUT -s $ip -j DROP 2>/dev/null; then
			iptables -I INPUT 1 -s $ip -j DROP
			echo "已阻止IP $ip"
		fi
	done

	save_iptables_rules
	send_stats "已阻止IP"
}







enable_ddos_defense() {
	# 开启防御 DDoS
	iptables -A DOCKER-USER -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT
	iptables -A DOCKER-USER -p tcp --syn -j DROP
	iptables -A DOCKER-USER -p udp -m limit --limit 3000/s -j ACCEPT
	iptables -A DOCKER-USER -p udp -j DROP
	iptables -A INPUT -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT
	iptables -A INPUT -p tcp --syn -j DROP
	iptables -A INPUT -p udp -m limit --limit 3000/s -j ACCEPT
	iptables -A INPUT -p udp -j DROP

	send_stats "开启DDoS防御"
}

# 关闭DDoS防御
disable_ddos_defense() {
	# 关闭防御 DDoS
	iptables -D DOCKER-USER -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT 2>/dev/null
	iptables -D DOCKER-USER -p tcp --syn -j DROP 2>/dev/null
	iptables -D DOCKER-USER -p udp -m limit --limit 3000/s -j ACCEPT 2>/dev/null
	iptables -D DOCKER-USER -p udp -j DROP 2>/dev/null
	iptables -D INPUT -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT 2>/dev/null
	iptables -D INPUT -p tcp --syn -j DROP 2>/dev/null
	iptables -D INPUT -p udp -m limit --limit 3000/s -j ACCEPT 2>/dev/null
	iptables -D INPUT -p udp -j DROP 2>/dev/null

	send_stats "关闭DDoS防御"
}





# 管理国家IP规则的函数
manage_country_rules() {
	local action="$1"
	shift  # 去掉第一个参数，剩下的全是国家代码

	install ipset

	for country_code in "$@"; do
		local ipset_name="${country_code,,}_block"
		local download_url="http://www.ipdeny.com/ipblocks/data/countries/${country_code,,}.zone"

		case "$action" in
			block)
				if ! ipset list "$ipset_name" &> /dev/null; then
					ipset create "$ipset_name" hash:net
				fi

				if ! wget -q "$download_url" -O "${country_code,,}.zone"; then
					echo "错误：下载 $country_code 的 IP 区域文件失败"
					continue
				fi

				while IFS= read -r ip; do
					ipset add "$ipset_name" "$ip" 2>/dev/null
				done < "${country_code,,}.zone"

				iptables -I INPUT -m set --match-set "$ipset_name" src -j DROP

				echo "已成功阻止 $country_code 的 IP 地址"
				rm "${country_code,,}.zone"
				;;

			allow)
				if ! ipset list "$ipset_name" &> /dev/null; then
					ipset create "$ipset_name" hash:net
				fi

				if ! wget -q "$download_url" -O "${country_code,,}.zone"; then
					echo "错误：下载 $country_code 的 IP 区域文件失败"
					continue
				fi

				ipset flush "$ipset_name"
				while IFS= read -r ip; do
					ipset add "$ipset_name" "$ip" 2>/dev/null
				done < "${country_code,,}.zone"


				iptables -P INPUT DROP
				iptables -A INPUT -m set --match-set "$ipset_name" src -j ACCEPT

				echo "已成功允许 $country_code 的 IP 地址"
				rm "${country_code,,}.zone"
				;;

			unblock)
				iptables -D INPUT -m set --match-set "$ipset_name" src -j DROP 2>/dev/null

				if ipset list "$ipset_name" &> /dev/null; then
					ipset destroy "$ipset_name"
				fi

				echo "已成功解除 $country_code 的 IP 地址限制"
				;;

			*)
				echo "用法: manage_country_rules {block|allow|unblock} <country_code...>"
				;;
		esac
	done
}










iptables_panel() {
  root_use
  install iptables
  save_iptables_rules
  while true; do
		  clear
		  echo "高级防火墙管理"
		  send_stats "高级防火墙管理"
		  echo "------------------------"
		  iptables -L INPUT
		  echo ""
		  echo "防火墙管理"
		  echo "------------------------"
		  echo "1.  开放指定端口                 2.  关闭指定端口"
		  echo "3.  开放所有端口                 4.  关闭所有端口"
		  echo "------------------------"
		  echo "5.  IP白名单                  	 6.  IP黑名单"
		  echo "7.  清除指定IP"
		  echo "------------------------"
		  echo "11. 允许PING                  	 12. 禁止PING"
		  echo "------------------------"
		  echo "13. 启动DDOS防御                 14. 关闭DDOS防御"
		  echo "------------------------"
		  echo "15. 阻止指定国家IP               16. 仅允许指定国家IP"
		  echo "17. 解除指定国家IP限制"
		  echo "------------------------"
		  echo "0. 返回上一级选单"
		  echo "------------------------"
		  read -e -p "请输入你的选择: " sub_choice || return 1
		  case $sub_choice in
			  1)
				  read -e -p "请输入开放的端口号: " o_port || return 1
				  open_port $o_port
				  send_stats "开放指定端口"
				  ;;
			  2)
				  read -e -p "请输入关闭的端口号: " c_port || return 1
				  close_port $c_port
				  send_stats "关闭指定端口"
				  ;;
			  3)
				  # 开放所有端口
				  current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')
				  iptables -F
				  iptables -X
				  iptables -P INPUT ACCEPT
				  iptables -P FORWARD ACCEPT
				  iptables -P OUTPUT ACCEPT
				  iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
				  iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
				  iptables -A INPUT -i lo -j ACCEPT
				  iptables -A FORWARD -i lo -j ACCEPT
				  iptables -A INPUT -p tcp --dport $current_port -j ACCEPT
				  iptables-save > /etc/iptables/rules.v4
				  send_stats "开放所有端口"
				  ;;
			  4)
				  # 关闭所有端口
				  current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')
				  iptables -F
				  iptables -X
				  iptables -P INPUT DROP
				  iptables -P FORWARD DROP
				  iptables -P OUTPUT ACCEPT
				  iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
				  iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
				  iptables -A INPUT -i lo -j ACCEPT
				  iptables -A FORWARD -i lo -j ACCEPT
				  iptables -A INPUT -p tcp --dport $current_port -j ACCEPT
				  iptables-save > /etc/iptables/rules.v4
				  send_stats "关闭所有端口"
				  ;;

			  5)
				  # IP 白名单
				  read -e -p "请输入放行的IP或IP段: " o_ip || return 1
				  allow_ip $o_ip
				  ;;
			  6)
				  # IP 黑名单
				  read -e -p "请输入封锁的IP或IP段: " c_ip || return 1
				  block_ip $c_ip
				  ;;
			  7)
				  # 清除指定 IP
				  read -e -p "请输入清除的IP: " d_ip || return 1
				  iptables -D INPUT -s $d_ip -j ACCEPT 2>/dev/null
				  iptables -D INPUT -s $d_ip -j DROP 2>/dev/null
				  iptables-save > /etc/iptables/rules.v4
				  send_stats "清除指定IP"
				  ;;
			  11)
				  # 允许 PING
				  iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
				  iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT
				  iptables-save > /etc/iptables/rules.v4
				  send_stats "允许PING"
				  ;;
			  12)
				  # 禁用 PING
				  iptables -D INPUT -p icmp --icmp-type echo-request -j ACCEPT 2>/dev/null
				  iptables -D OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT 2>/dev/null
				  iptables-save > /etc/iptables/rules.v4
				  send_stats "禁用PING"
				  ;;
			  13)
				  enable_ddos_defense
				  ;;
			  14)
				  disable_ddos_defense
				  ;;

			  15)
				  read -e -p "请输入阻止的国家代码（多个国家代码可用空格隔开如 CN US JP）: " country_code || return 1
				  manage_country_rules block $country_code
				  send_stats "允许国家 $country_code 的IP"
				  ;;
			  16)
				  read -e -p "请输入允许的国家代码（多个国家代码可用空格隔开如 CN US JP）: " country_code || return 1
				  manage_country_rules allow $country_code
				  send_stats "阻止国家 $country_code 的IP"
				  ;;

			  17)
				  read -e -p "请输入清除的国家代码（多个国家代码可用空格隔开如 CN US JP）: " country_code || return 1
				  manage_country_rules unblock $country_code
				  send_stats "清除国家 $country_code 的IP"
				  ;;

			  *)
				  break  # 跳出循环，退出菜单
				  ;;
		  esac
  done

}






daimon_swap_is_active() {
	awk '$1 == "/swapfile" {found=1} END {exit !found}' /proc/swaps
}

daimon_swap_is_managed() {
	[ -f "$DAIMON_ROOT_DIR/.swapfile-managed" ] &&
		[ ! -L /swapfile ] && [ -f /swapfile ] &&
		[ "$(stat -c '%d:%i' /swapfile)" = "$(cat "$DAIMON_ROOT_DIR/.swapfile-managed")" ]
}

add_swap() {
	root_use
	local new_swap="${1:-}" tmp old_swap="" was_active=0
	if ! [[ "$new_swap" =~ ^[1-9][0-9]{0,6}$ ]] || [ "$new_swap" -gt 1048576 ]; then
		echo "虚拟内存大小必须为 1-1048576 MiB 的整数"
		return 1
	fi
	if { [ -e /swapfile ] || [ -L /swapfile ]; } && ! daimon_swap_is_managed; then
		echo "现有 /swapfile 的归属未确认，未修改；其他 swap 文件和分区保持不变。"
		return 1
	fi
	tmp=$(mktemp /swapfile.daimon.XXXXXX) || return 1
	if ! chmod 600 "$tmp" || ! fallocate -l "${new_swap}M" "$tmp" || ! mkswap "$tmp"; then
		rm -f -- "$tmp"
		return 1
	fi
	mkdir -p "$DAIMON_ROOT_DIR" || { rm -f -- "$tmp"; return 1; }
	if [ -e /swapfile ]; then
		old_swap=$(mktemp /swapfile.daimon.old.XXXXXX) || { rm -f -- "$tmp"; return 1; }
	fi
	daimon_swap_is_active && was_active=1
	if [ "$was_active" -eq 1 ] && ! swapoff /swapfile; then
		rm -f -- "$tmp"
		[ -z "$old_swap" ] || rm -f -- "$old_swap"
		echo "swapoff 失败，原虚拟内存和 fstab 保持不变。"
		return 1
	fi
	if [ -n "$old_swap" ] && ! mv -f -- /swapfile "$old_swap"; then
		rm -f -- "$tmp" "$old_swap"
		[ "$was_active" -eq 0 ] || swapon /swapfile
		return 1
	fi
	if ! mv -f -- "$tmp" /swapfile || ! swapon /swapfile || ! daimon_swap_is_active; then
		if daimon_swap_is_active && ! swapoff /swapfile; then
			echo "新 swap 停用失败，原文件保留在: $old_swap"
			return 1
		fi
		rm -f -- "$tmp"
		if [ -n "$old_swap" ]; then
			mv -f -- "$old_swap" /swapfile || { echo "恢复失败，原 swap 保留在: $old_swap"; return 1; }
			[ "$was_active" -eq 0 ] || swapon /swapfile || { echo "原 swap 文件已恢复，但重新启用失败。"; return 1; }
		else
			rm -f /swapfile
		fi
		echo "新 swap 启用失败，已恢复原文件，fstab 未修改。"
		return 1
	fi
	stat -c '%d:%i' /swapfile > "$DAIMON_ROOT_DIR/.swapfile-managed" || { echo "归属标记写入失败，原文件保留在: $old_swap"; return 1; }
	[ -z "$old_swap" ] || rm -f -- "$old_swap"
	sed -i '\|^[[:space:]]*/swapfile[[:space:]]|d' /etc/fstab || return 1
	echo "/swapfile swap swap defaults 0 0" >> /etc/fstab || return 1

	if [ -f /etc/alpine-release ]; then
		echo "nohup swapon /swapfile" > /etc/local.d/swap.start
		chmod +x /etc/local.d/swap.start
		rc-update add local
	fi

	echo -e "虚拟内存大小已调整为${gl_huang}${new_swap}${gl_bai}M"
}

delete_swap() {
	root_use
	if ! daimon_swap_is_managed; then
		echo "未检测到本脚本创建并标记的 /swapfile，未删除任何文件。"
		return 1
	fi
	if daimon_swap_is_active && ! swapoff /swapfile; then
		echo "swapoff 失败，未删除虚拟内存或修改 fstab。"
		return 1
	fi
	rm -f /swapfile || return 1
	sed -i '\|^[[:space:]]*/swapfile[[:space:]]|d' /etc/fstab || return 1
	rm -f "$DAIMON_ROOT_DIR/.swapfile-managed"
	rm -f /etc/local.d/swap.start 2>/dev/null || true
	echo -e "${gl_lv}已删除脚本创建的 /swapfile 虚拟内存，并清理 /etc/fstab 持久化配置。${gl_bai}"
}




check_swap() {

local swap_total=$(free -m | awk 'NR==3{print $2}')

# 判断是否需要创建虚拟内存
[ "$swap_total" -gt 0 ] || add_swap 1024


}









ldnmp_v() {

	  # 获取nginx版本
	  local nginx_version=$(docker exec nginx nginx -v 2>&1)
	  local nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
	  echo -n -e "nginx : ${gl_huang}v$nginx_version${gl_bai}"

	  # 获取mysql版本
	  local dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	  local mysql_version=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SELECT VERSION();" 2>/dev/null | tail -n 1)
	  echo -n -e "            mysql : ${gl_huang}v$mysql_version${gl_bai}"

	  # 获取php版本
	  local php_version=$(docker exec php php -v 2>/dev/null | grep -oP "PHP \K[0-9]+\.[0-9]+\.[0-9]+")
	  echo -n -e "            php : ${gl_huang}v$php_version${gl_bai}"

	  # 获取redis版本
	  local redis_version=$(docker exec redis redis-server -v 2>&1 | grep -oP "v=+\K[0-9]+\.[0-9]+")
	  echo -e "            redis : ${gl_huang}v$redis_version${gl_bai}"

	  echo "------------------------"
	  echo ""

}



install_ldnmp_conf() {

  # 创建必要的目录和文件
  cd /home && mkdir -p web/html web/mysql web/certs web/conf.d web/stream.d web/redis web/log/nginx web/letsencrypt && touch web/docker-compose.yml
  wget -O /home/web/nginx.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/nginx10.conf
  wget -O /home/web/conf.d/default.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/default10.conf

  default_server_ssl

  # 下载 docker-compose.yml 文件并进行替换
  wget -O /home/web/docker-compose.yml ${gh_proxy}raw.githubusercontent.com/kejilion/docker/main/LNMP-docker-compose-10.yml
  dbrootpasswd=$(openssl rand -base64 16) ; dbuse=$(openssl rand -hex 4) ; dbusepasswd=$(openssl rand -base64 8)

  # 在 docker-compose.yml 文件中进行替换
  sed -i "s#webroot#$dbrootpasswd#g" /home/web/docker-compose.yml
  sed -i "s#kejilionYYDS#$dbusepasswd#g" /home/web/docker-compose.yml
  sed -i "s#kejilion#$dbuse#g" /home/web/docker-compose.yml

}


update_docker_compose_with_db_creds() {

  cp /home/web/docker-compose.yml /home/web/docker-compose1.yml

  if ! grep -q "letsencrypt" /home/web/docker-compose.yml; then
	wget -O /home/web/docker-compose.yml ${gh_proxy}raw.githubusercontent.com/kejilion/docker/main/LNMP-docker-compose-10.yml

  	dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose1.yml | tr -d '[:space:]')
  	dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /home/web/docker-compose1.yml | tr -d '[:space:]')
  	dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose1.yml | tr -d '[:space:]')

	sed -i "s#webroot#$dbrootpasswd#g" /home/web/docker-compose.yml
	sed -i "s#kejilionYYDS#$dbusepasswd#g" /home/web/docker-compose.yml
	sed -i "s#kejilion#$dbuse#g" /home/web/docker-compose.yml
  fi

  if grep -q "kjlion/nginx:alpine" /home/web/docker-compose1.yml; then
  	sed -i 's|kjlion/nginx:alpine|nginx:alpine|g' /home/web/docker-compose.yml  > /dev/null 2>&1
	sed -i 's|nginx:alpine|kjlion/nginx:alpine|g' /home/web/docker-compose.yml  > /dev/null 2>&1
  fi

}





auto_optimize_dns() {
	# 获取国家代码（如 CN、US 等）
	local country=$(curl -s ipinfo.io/country)

	# 根据国家设置 DNS
	if [ "$country" = "CN" ]; then
		local dns1_ipv4="223.5.5.5"
		local dns2_ipv4="119.29.29.29"
		local dns1_ipv6="2400:3200::1"
		local dns2_ipv6="2402:4e00::"
	else
		local dns1_ipv4="1.1.1.1"
		local dns2_ipv4="8.8.8.8"
		local dns1_ipv6="2606:4700:4700::1111"
		local dns2_ipv6="2001:4860:4860::8888"
	fi

	set_dns


}


prefer_ipv4() {
grep -q '^precedence ::ffff:0:0/96  100' /etc/gai.conf 2>/dev/null \
	|| echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf
echo "已切换为 IPv4 优先"
send_stats "已切换为 IPv4 优先"
}




install_ldnmp() {

	  update_docker_compose_with_db_creds

	  cd /home/web && docker compose up -d
	  sleep 1
  	  crontab -l 2>/dev/null | grep -v 'logrotate' | crontab -
  	  (crontab -l 2>/dev/null; echo '0 2 * * * docker exec nginx apk add logrotate && docker exec nginx logrotate -f /etc/logrotate.conf') | crontab -

	  fix_phpfpm_conf php
	  fix_phpfpm_conf php74

	  # mysql调优
	  wget -O /home/custom_mysql_config.cnf ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/custom_mysql_config-1.cnf
	  docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
	  rm -rf /home/custom_mysql_config.cnf



	  restart_ldnmp
	  sleep 2

	  clear
	  echo "LDNMP环境安装完毕"
	  echo "------------------------"
	  ldnmp_v

}


write_certbot_renewal_script() {
	local script_file="$DAIMON_SCRIPT_DIR/auto_cert_renewal.sh"
	mkdir -p "$DAIMON_SCRIPT_DIR" /var/log/certbot
	cat > "$script_file" <<'EOF'
#!/bin/bash
set -u
CERT_DIR="/home/web/certs"
WEBROOT="/home/web/letsencrypt"
LOG_FILE="/var/log/certbot/renew.log"
LOCK_DIR="/run/lock/daimon-certbot-renew.lock.d"
mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$LOCK_DIR")"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then exit 0; fi
trap 'rm -rf "$LOCK_DIR"' EXIT
status=0
{
    for cert_file in "$CERT_DIR"/*_cert.pem; do
        [ -f "$cert_file" ] || continue
        domain=$(basename "$cert_file" _cert.pem)
        expiry=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2- || true)
        expiry_ts=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
        days_left=$(( (expiry_ts - $(date +%s)) / 86400 ))
        [ "$days_left" -gt 15 ] && continue
        if ! docker inspect nginx >/dev/null 2>&1 || [ "$(docker inspect nginx --format '{{.State.Running}}' 2>/dev/null)" != true ]; then
            echo "$domain: nginx is not running; skipped without starting it"
            status=1
            continue
        fi
        if [ ! -d "$WEBROOT" ] || ! docker exec nginx sh -c "grep -Rqs letsencrypt /etc/nginx/conf.d /etc/nginx/sites-enabled 2>/dev/null"; then
            echo "$domain: webroot challenge configuration is missing; skipped"
            status=1
            continue
        fi
        if ! docker run --rm -v /etc/letsencrypt:/etc/letsencrypt -v "$WEBROOT:/var/www/letsencrypt" certbot/certbot certonly --webroot -w /var/www/letsencrypt -d "$domain" --email your@email.com --agree-tos --no-eff-email --key-type ecdsa; then
            echo "$domain: certbot webroot renewal failed"
            status=1
            continue
        fi
        cp "/etc/letsencrypt/live/$domain/fullchain.pem" "$CERT_DIR/${domain}_cert.pem"
        cp "/etc/letsencrypt/live/$domain/privkey.pem" "$CERT_DIR/${domain}_key.pem"
        if ! docker exec nginx nginx -t || ! docker exec nginx nginx -s reload; then
            echo "$domain: nginx reload failed"
            status=1
        fi
    done
} >> "$LOG_FILE" 2>&1
exit "$status"
EOF
	chmod 700 "$script_file"
	cat > /etc/logrotate.d/daimon-certbot-renew <<'EOF'
/var/log/certbot/renew.log {
    daily
    rotate 30
    size 10M
    missingok
    notifempty
    compress
    copytruncate
}
EOF
}

install_certbot() {
	write_certbot_renewal_script
	check_crontab_installed
	local cron_job="0 0 * * * /bin/bash $DAIMON_SCRIPT_DIR/auto_cert_renewal.sh >> /var/log/certbot/renew.log 2>&1"
	crontab -l 2>/dev/null | grep -vF "$DAIMON_SCRIPT_DIR/auto_cert_renewal.sh" | crontab -
	(crontab -l 2>/dev/null; echo "$cron_job") | crontab -
	echo "已配置 Docker Nginx webroot 续签任务"
}


install_ssltls() {
	  mkdir -p /home/web/letsencrypt/.well-known/acme-challenge /home/web/certs
	  if ! docker inspect nginx >/dev/null 2>&1 || [ "$(docker inspect nginx --format '{{.State.Running}}' 2>/dev/null)" != true ]; then
		  echo "Docker nginx 未运行，不会自动启动；请先配置并启动 webroot 站点。"
		  return 1
	  fi

	  local file_path="/etc/letsencrypt/live/$yuming/fullchain.pem"
	  if [ ! -f "$file_path" ]; then
		 	local ipv4_pattern='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
			local ipv6_pattern='^(([0-9A-Fa-f]{1,4}:){1,7}:|([0-9A-Fa-f]{1,4}:){7,7}[0-9A-Fa-f]{1,4}|::1)$'
			if [[ ($yuming =~ $ipv4_pattern || $yuming =~ $ipv6_pattern) ]]; then
				mkdir -p /etc/letsencrypt/live/$yuming/
				if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
					openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout /etc/letsencrypt/live/$yuming/privkey.pem -out /etc/letsencrypt/live/$yuming/fullchain.pem -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
				else
					openssl genpkey -algorithm Ed25519 -out /etc/letsencrypt/live/$yuming/privkey.pem
					openssl req -x509 -key /etc/letsencrypt/live/$yuming/privkey.pem -out /etc/letsencrypt/live/$yuming/fullchain.pem -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
				fi
			else
				if ! docker exec nginx sh -c "grep -Rqs letsencrypt /etc/nginx/conf.d /etc/nginx/sites-enabled 2>/dev/null"; then
					echo "未检测到 Docker nginx 的 webroot challenge 配置，未执行签发。"
					return 1
				fi
				docker run --rm -v /etc/letsencrypt:/etc/letsencrypt -v /home/web/letsencrypt:/var/www/letsencrypt certbot/certbot certonly --webroot -w /var/www/letsencrypt -d "$yuming" --email your@email.com --agree-tos --no-eff-email --key-type ecdsa
			fi
	  fi
	  mkdir -p /home/web/certs/
	  cp /etc/letsencrypt/live/$yuming/fullchain.pem /home/web/certs/${yuming}_cert.pem > /dev/null 2>&1
	  cp /etc/letsencrypt/live/$yuming/privkey.pem /home/web/certs/${yuming}_key.pem > /dev/null 2>&1

	  docker exec nginx nginx -t && docker exec nginx nginx -s reload
}



install_ssltls_text() {
	echo -e "${gl_huang}$yuming 公钥信息${gl_bai}"
	cat /etc/letsencrypt/live/$yuming/fullchain.pem
	echo ""
	echo -e "${gl_huang}$yuming 私钥信息${gl_bai}"
	cat /etc/letsencrypt/live/$yuming/privkey.pem
	echo ""
	echo -e "${gl_huang}证书存放路径${gl_bai}"
	echo "公钥: /etc/letsencrypt/live/$yuming/fullchain.pem"
	echo "私钥: /etc/letsencrypt/live/$yuming/privkey.pem"
	echo ""
}





add_ssl() {
echo -e "${gl_huang}快速申请SSL证书，过期前自动续签${gl_bai}"
yuming="${1:-}"
if [ -z "$yuming" ]; then
	add_yuming
fi
install_docker
install_certbot
docker run --rm -v /etc/letsencrypt/:/etc/letsencrypt certbot/certbot delete --cert-name "$yuming" -n 2>/dev/null
install_ssltls
certs_status
install_ssltls_text
ssl_ps
}


ssl_ps() {
	echo -e "${gl_huang}已申请的证书到期情况${gl_bai}"
	echo "站点信息                      证书到期时间"
	echo "------------------------"
	for cert_dir in /etc/letsencrypt/live/*; do
	  local cert_file="$cert_dir/fullchain.pem"
	  if [ -f "$cert_file" ]; then
		local domain=$(basename "$cert_dir")
		local expire_date=$(openssl x509 -noout -enddate -in "$cert_file" | awk -F'=' '{print $2}')
		local formatted_date=$(date -d "$expire_date" '+%Y-%m-%d')
		printf "%-30s%s\n" "$domain" "$formatted_date"
	  fi
	done
	echo ""
}




default_server_ssl() {
install openssl

if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
	openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout /home/web/certs/default_server.key -out /home/web/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
else
	openssl genpkey -algorithm Ed25519 -out /home/web/certs/default_server.key
	openssl req -x509 -key /home/web/certs/default_server.key -out /home/web/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
fi

openssl rand -out /home/web/certs/ticket12.key 48
openssl rand -out /home/web/certs/ticket13.key 80

}


certs_status() {

	sleep 1

	local file_path="/etc/letsencrypt/live/$yuming/fullchain.pem"
	if [ -f "$file_path" ]; then
		send_stats "域名证书申请成功"
	else
		send_stats "域名证书申请失败"
		echo -e "${gl_hong}注意: ${gl_bai}证书申请失败，请检查以下可能原因并重试："
		echo -e "1. 域名拼写错误 ➠ 请检查域名输入是否正确"
		echo -e "2. DNS解析问题 ➠ 确认域名已正确解析到本服务器IP"
		echo -e "3. 网络配置问题 ➠ 如使用Cloudflare Warp等虚拟网络请暂时关闭"
		echo -e "4. 防火墙限制 ➠ 检查80/443端口是否开放，确保验证可访问"
		echo -e "5. 申请次数超限 ➠ Let's Encrypt有每周限额(5次/域名/周)"
		echo -e "6. 国内备案限制 ➠ 中国大陆环境请确认域名是否备案"
		echo "------------------------"
		echo "1. 重新申请        2. 导入已有证书        0. 退出"
		echo "------------------------"
		read -e -p "请输入你的选择: " sub_choice || return 1
		case $sub_choice in
	  	  1)
	  	  	send_stats "重新申请"
		  	echo "请再次尝试部署 $webname"
		  	add_yuming
		  	install_ssltls
		  	certs_status

	  		  ;;
	  	  2)
	  	  	send_stats "导入已有证书"

			# 定义文件路径
			local cert_file="/home/web/certs/${yuming}_cert.pem"
			local key_file="/home/web/certs/${yuming}_key.pem"

			mkdir -p /home/web/certs

			# 1. 输入证书 (ECC 和 RSA 证书开头都是 BEGIN CERTIFICATE)
			echo "请粘贴 证书 (CRT/PEM) 内容 (按两次回车结束)："
			local cert_content=""
			while IFS= read -r line; do
				[[ -z "$line" && "$cert_content" == *"-----BEGIN"* ]] && break
				cert_content+="${line}"$'\n'
			done

			# 2. 输入私钥 (兼容 RSA, ECC, PKCS#8)
			echo "请粘贴 证书私钥 (Private Key) 内容 (按两次回车结束)："
			local key_content=""
			while IFS= read -r line; do
				[[ -z "$line" && "$key_content" == *"-----BEGIN"* ]] && break
				key_content+="${line}"$'\n'
			done

			# 3. 智能校验
			# 只要包含 "BEGIN CERTIFICATE" 和 "PRIVATE KEY" 即可通过
			if [[ "$cert_content" == *"-----BEGIN CERTIFICATE-----"* && "$key_content" == *"PRIVATE KEY-----"* ]]; then
				echo -n "$cert_content" > "$cert_file"
				echo -n "$key_content" > "$key_file"

				chmod 644 "$cert_file"
				chmod 600 "$key_file"

				# 识别当前证书类型并显示
				if [[ "$key_content" == *"EC PRIVATE KEY"* ]]; then
					echo "检测到 ECC 证书已成功保存。"
				else
					echo "检测到 RSA 证书已成功保存。"
				fi
				auth_method="ssl_imported"
			else
				echo "错误：无效的证书或私钥格式！"
				certs_status
			fi
	  		  ;;
	  	  *)
		  	  exit
	  		  ;;
		esac
	fi

}


repeat_add_yuming() {
if [ -e /home/web/conf.d/$yuming.conf ]; then
  send_stats "域名重复使用"
  web_del "${yuming}" > /dev/null 2>&1
fi

}


add_yuming() {
	  ip_address
	  echo -e "先将域名解析到本机IP: ${gl_huang}$ipv4_address  $ipv6_address${gl_bai}"
	  read -e -p "请输入你的IP或者解析过的域名: " yuming || return 1
}


check_ip_and_get_access_port() {
	local yuming="$1"

	local ipv4_pattern='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
	local ipv6_pattern='^(([0-9A-Fa-f]{1,4}:){1,7}:|([0-9A-Fa-f]{1,4}:){7,7}[0-9A-Fa-f]{1,4}|::1)$'

	if [[ "$yuming" =~ $ipv4_pattern || "$yuming" =~ $ipv6_pattern ]]; then
		read -e -p "请输入访问/监听端口，回车默认使用 80: " access_port || return 1
		access_port=${access_port:-80}
	fi
}



update_nginx_listen_port() {
	local yuming="$1"
	local access_port="$2"
	local conf="/home/web/conf.d/${yuming}.conf"

	# 如果 access_port 为空，则跳过
	[ -z "$access_port" ] && return 0

	# 删除所有 listen 行
	sed -i '/^[[:space:]]*listen[[:space:]]\+/d' "$conf"

	# 在 server { 后插入新的 listen
	sed -i "/server {/a\\
	listen ${access_port};\\
	listen [::]:${access_port};
" "$conf"
}



add_db() {
	  dbname=$(echo "$yuming" | sed -e 's/[^A-Za-z0-9]/_/g')
	  dbname="${dbname}"

	  dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	  dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	  dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	  docker exec mysql mysql -u root -p"$dbrootpasswd" -e "CREATE DATABASE $dbname; GRANT ALL PRIVILEGES ON $dbname.* TO \"$dbuse\"@\"%\";"
}


restart_ldnmp() {
	  docker exec nginx chown -R nginx:nginx /var/www/html > /dev/null 2>&1
	  docker exec nginx mkdir -p /var/cache/nginx/proxy > /dev/null 2>&1
	  docker exec nginx mkdir -p /var/cache/nginx/fastcgi > /dev/null 2>&1
	  docker exec nginx chown -R nginx:nginx /var/cache/nginx/proxy > /dev/null 2>&1
	  docker exec nginx chown -R nginx:nginx /var/cache/nginx/fastcgi > /dev/null 2>&1
	  docker exec php chown -R www-data:www-data /var/www/html > /dev/null 2>&1
	  docker exec php74 chown -R www-data:www-data /var/www/html > /dev/null 2>&1
	  cd /home/web && docker compose restart


}

nginx_upgrade() {

  local ldnmp_pods="nginx"
  cd /home/web/
  docker rm -f $ldnmp_pods > /dev/null 2>&1
  docker images --filter=reference="kjlion/${ldnmp_pods}*" -q | xargs docker rmi > /dev/null 2>&1
  docker images --filter=reference="${ldnmp_pods}*" -q | xargs docker rmi > /dev/null 2>&1
  docker compose up -d --force-recreate $ldnmp_pods
  crontab -l 2>/dev/null | grep -v 'logrotate' | crontab -
  (crontab -l 2>/dev/null; echo '0 2 * * * docker exec nginx apk add logrotate && docker exec nginx logrotate -f /etc/logrotate.conf') | crontab -
  docker exec nginx chown -R nginx:nginx /var/www/html
  docker exec nginx mkdir -p /var/cache/nginx/proxy
  docker exec nginx mkdir -p /var/cache/nginx/fastcgi
  docker exec nginx chown -R nginx:nginx /var/cache/nginx/proxy
  docker exec nginx chown -R nginx:nginx /var/cache/nginx/fastcgi
  docker restart $ldnmp_pods > /dev/null 2>&1

  send_stats "更新$ldnmp_pods"
  echo "更新${ldnmp_pods}完成"

}

phpmyadmin_upgrade() {
  local ldnmp_pods="phpmyadmin"
  local docker_port=8877
  local dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
  local dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')

  cd /home/web/
  docker rm -f $ldnmp_pods > /dev/null 2>&1
  docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
  curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/docker/refs/heads/main/docker-compose.phpmyadmin.yml
  docker compose -f docker-compose.phpmyadmin.yml up -d
  clear
  ip_address

  check_docker_app_ip
  echo "登录信息: "
  echo "用户名: $dbuse"
  echo "密码: $dbusepasswd"
  echo
  send_stats "启动$ldnmp_pods"
}


cf_purge_cache() {
  local CONFIG_FILE="/home/web/config/cf-purge-cache.txt"
  local API_TOKEN
  local EMAIL
  local ZONE_IDS

  # 检查配置文件是否存在
  if [ -f "$CONFIG_FILE" ]; then
	# 从配置文件读取 API_TOKEN 和 zone_id
	read API_TOKEN EMAIL ZONE_IDS < "$CONFIG_FILE"
	# 将 ZONE_IDS 转换为数组
	ZONE_IDS=($ZONE_IDS)
  else
	# 提示用户是否清理缓存
	read -e -p "需要清理 Cloudflare 的缓存吗？（y/n）: " answer || return 1
	if [[ "$answer" == "y" ]]; then
	  echo "CF信息保存在$CONFIG_FILE，可以后期修改CF信息"
	  read -e -p "请输入你的 API_TOKEN: " API_TOKEN || return 1
	  read -e -p "请输入你的CF用户名: " EMAIL || return 1
	  read -e -p "请输入 zone_id（多个用空格分隔）: " -a ZONE_IDS || return 1

	  mkdir -p /home/web/config/
	  echo "$API_TOKEN $EMAIL ${ZONE_IDS[*]}" > "$CONFIG_FILE"
	fi
  fi

  # 循环遍历每个 zone_id 并执行清除缓存命令
  for ZONE_ID in "${ZONE_IDS[@]}"; do
	echo "正在清除缓存 for zone_id: $ZONE_ID"
	curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
	-H "X-Auth-Email: $EMAIL" \
	-H "X-Auth-Key: $API_TOKEN" \
	-H "Content-Type: application/json" \
	--data '{"purge_everything":true}'
  done

  echo "缓存清除请求已发送完毕。"
}



web_cache() {
  send_stats "清理站点缓存"
  cf_purge_cache
  cd /home/web && docker compose restart
}



web_del() {

	send_stats "删除站点数据"
	yuming_list="${1:-}"
	if [ -z "$yuming_list" ]; then
		read -e -p "删除站点数据，请输入你的域名（多个域名用空格隔开）: " yuming_list || return 1
		if [[ -z "$yuming_list" ]]; then
			return
		fi
	fi

	for yuming in $yuming_list; do
		if ! validate_domain_name "$yuming"; then echo "跳过非法域名: $yuming"; continue; fi
		echo "正在删除域名: $yuming"
		rm -rf "/home/web/html/$yuming" "/home/web/conf.d/$yuming.conf" \
			"/home/web/certs/${yuming}_key.pem" "/home/web/certs/${yuming}_cert.pem"
		echo "已删除反代配置与证书；数据库未删除"
	done

	docker exec nginx nginx -s reload

}


nginx_waf() {
	local mode=$1

	if ! grep -q "kjlion/nginx:alpine" /home/web/docker-compose.yml; then
		wget -O /home/web/nginx.conf "${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/nginx10.conf"
	fi

	# 根据 mode 参数来决定开启或关闭 WAF
	if [ "$mode" == "on" ]; then
		# 开启 WAF：去掉注释
		sed -i 's|# load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;|load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# modsecurity on;|\1modsecurity on;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# modsecurity_rules_file /etc/nginx/modsec/modsecurity.conf;|\1modsecurity_rules_file /etc/nginx/modsec/modsecurity.conf;|' /home/web/nginx.conf > /dev/null 2>&1
	elif [ "$mode" == "off" ]; then
		# 关闭 WAF：加上注释
		sed -i 's|^load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;|# load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)modsecurity on;|\1# modsecurity on;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)modsecurity_rules_file /etc/nginx/modsec/modsecurity.conf;|\1# modsecurity_rules_file /etc/nginx/modsec/modsecurity.conf;|' /home/web/nginx.conf > /dev/null 2>&1
	else
		echo "无效的参数：使用 'on' 或 'off'"
		return 1
	fi

	# 检查 nginx 镜像并根据情况处理
	if grep -q "kjlion/nginx:alpine" /home/web/docker-compose.yml; then
		docker exec nginx nginx -s reload
	else
		sed -i 's|nginx:alpine|kjlion/nginx:alpine|g' /home/web/docker-compose.yml
		nginx_upgrade
	fi

}

check_waf_status() {
	if grep -q "^\s*#\s*modsecurity on;" /home/web/nginx.conf; then
		waf_status=""
	elif grep -q "modsecurity on;" /home/web/nginx.conf; then
		waf_status=" WAF已开启"
	else
		waf_status=""
	fi
}


check_cf_mode() {
	if [ -f "/etc/fail2ban/action.d/cloudflare-docker.conf" ]; then
		CFmessage=" cf模式已开启"
	else
		CFmessage=""
	fi
}


nginx_http_on() {

local ipv4_pattern='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
local ipv6_pattern='^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))))$'
if [[ ($yuming =~ $ipv4_pattern || $yuming =~ $ipv6_pattern) ]]; then
	sed -i '/if (\$scheme = http) {/,/}/s/^/#/' /home/web/conf.d/${yuming}.conf
fi

}


patch_wp_memory_limit() {
  local MEMORY_LIMIT="${1:-256M}"      # 第一个参数，默认256M
  local MAX_MEMORY_LIMIT="${2:-256M}"  # 第二个参数，默认256M
  local TARGET_DIR="/home/web/html"    # 路径写死

  find "$TARGET_DIR" -type f -name "wp-config.php" | while read -r FILE; do
	# 删除旧定义
	sed -i "/define(['\"]WP_MEMORY_LIMIT['\"].*/d" "$FILE"
	sed -i "/define(['\"]WP_MAX_MEMORY_LIMIT['\"].*/d" "$FILE"

	# 插入新定义，放在含 "Happy publishing" 的行前
	awk -v insert="define('WP_MEMORY_LIMIT', '$MEMORY_LIMIT');\ndefine('WP_MAX_MEMORY_LIMIT', '$MAX_MEMORY_LIMIT');" \
	'
	  /Happy publishing/ {
		print insert
	  }
	  { print }
	' "$FILE" > "$FILE.tmp" && mv -f "$FILE.tmp" "$FILE"

	echo "[+] Replaced WP_MEMORY_LIMIT in $FILE"
  done
}




patch_wp_debug() {
  local DEBUG="${1:-false}"           # 第一个参数，默认false
  local DEBUG_DISPLAY="${2:-false}"   # 第二个参数，默认false
  local DEBUG_LOG="${3:-false}"       # 第三个参数，默认false
  local TARGET_DIR="/home/web/html"   # 路径写死

  find "$TARGET_DIR" -type f -name "wp-config.php" | while read -r FILE; do
	# 删除旧定义
	sed -i "/define(['\"]WP_DEBUG['\"].*/d" "$FILE"
	sed -i "/define(['\"]WP_DEBUG_DISPLAY['\"].*/d" "$FILE"
	sed -i "/define(['\"]WP_DEBUG_LOG['\"].*/d" "$FILE"

	# 插入新定义，放在含 "Happy publishing" 的行前
	awk -v insert="define('WP_DEBUG_DISPLAY', $DEBUG_DISPLAY);\ndefine('WP_DEBUG_LOG', $DEBUG_LOG);" \
	'
	  /Happy publishing/ {
		print insert
	  }
	  { print }
	' "$FILE" > "$FILE.tmp" && mv -f "$FILE.tmp" "$FILE"

	echo "[+] Replaced WP_DEBUG settings in $FILE"
  done
}




patch_wp_url() {
  local HOME_URL="$1"
  local SITE_URL="$2"
  local TARGET_DIR="/home/web/html"

  find "$TARGET_DIR" -type f -name "wp-config-sample.php" | while read -r FILE; do
	# 删除旧定义
	sed -i "/define(['\"]WP_HOME['\"].*/d" "$FILE"
	sed -i "/define(['\"]WP_SITEURL['\"].*/d" "$FILE"

	# 生成插入内容
	INSERT="
define('WP_HOME', '$HOME_URL');
define('WP_SITEURL', '$SITE_URL');
"

	# 插入到 “Happy publishing” 之前
	awk -v insert="$INSERT" '
	  /Happy publishing/ {
		print insert
	  }
	  { print }
	' "$FILE" > "$FILE.tmp" && mv -f "$FILE.tmp" "$FILE"

	echo "[+] Updated WP_HOME and WP_SITEURL in $FILE"
  done
}








nginx_br() {

	local mode=$1

	if ! grep -q "kjlion/nginx:alpine" /home/web/docker-compose.yml; then
		wget -O /home/web/nginx.conf "${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/nginx10.conf"
	fi

	if [ "$mode" == "on" ]; then
		# 开启 Brotli：去掉注释
		sed -i 's|# load_module /etc/nginx/modules/ngx_http_brotli_filter_module.so;|load_module /etc/nginx/modules/ngx_http_brotli_filter_module.so;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|# load_module /etc/nginx/modules/ngx_http_brotli_static_module.so;|load_module /etc/nginx/modules/ngx_http_brotli_static_module.so;|' /home/web/nginx.conf > /dev/null 2>&1

		sed -i 's|^\(\s*\)# brotli on;|\1brotli on;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# brotli_static on;|\1brotli_static on;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# brotli_comp_level \(.*\);|\1brotli_comp_level \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# brotli_buffers \(.*\);|\1brotli_buffers \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# brotli_min_length \(.*\);|\1brotli_min_length \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# brotli_window \(.*\);|\1brotli_window \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# brotli_types \(.*\);|\1brotli_types \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i '/brotli_types/,+6 s/^\(\s*\)#\s*/\1/' /home/web/nginx.conf

	elif [ "$mode" == "off" ]; then
		# 关闭 Brotli：加上注释
		sed -i 's|^load_module /etc/nginx/modules/ngx_http_brotli_filter_module.so;|# load_module /etc/nginx/modules/ngx_http_brotli_filter_module.so;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^load_module /etc/nginx/modules/ngx_http_brotli_static_module.so;|# load_module /etc/nginx/modules/ngx_http_brotli_static_module.so;|' /home/web/nginx.conf > /dev/null 2>&1

		sed -i 's|^\(\s*\)brotli on;|\1# brotli on;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)brotli_static on;|\1# brotli_static on;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)brotli_comp_level \(.*\);|\1# brotli_comp_level \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)brotli_buffers \(.*\);|\1# brotli_buffers \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)brotli_min_length \(.*\);|\1# brotli_min_length \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)brotli_window \(.*\);|\1# brotli_window \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)brotli_types \(.*\);|\1# brotli_types \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i '/brotli_types/,+6 {
			/^[[:space:]]*[^#[:space:]]/ s/^\(\s*\)/\1# /
		}' /home/web/nginx.conf

	else
		echo "无效的参数：使用 'on' 或 'off'"
		return 1
	fi

	# 检查 nginx 镜像并根据情况处理
	if grep -q "kjlion/nginx:alpine" /home/web/docker-compose.yml; then
		docker exec nginx nginx -s reload
	else
		sed -i 's|nginx:alpine|kjlion/nginx:alpine|g' /home/web/docker-compose.yml
		nginx_upgrade
	fi


}



nginx_zstd() {

	local mode=$1

	if ! grep -q "kjlion/nginx:alpine" /home/web/docker-compose.yml; then
		wget -O /home/web/nginx.conf "${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/nginx10.conf"
	fi

	if [ "$mode" == "on" ]; then
		# 开启 Zstd：去掉注释
		sed -i 's|# load_module /etc/nginx/modules/ngx_http_zstd_filter_module.so;|load_module /etc/nginx/modules/ngx_http_zstd_filter_module.so;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|# load_module /etc/nginx/modules/ngx_http_zstd_static_module.so;|load_module /etc/nginx/modules/ngx_http_zstd_static_module.so;|' /home/web/nginx.conf > /dev/null 2>&1

		sed -i 's|^\(\s*\)# zstd on;|\1zstd on;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# zstd_static on;|\1zstd_static on;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# zstd_comp_level \(.*\);|\1zstd_comp_level \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# zstd_buffers \(.*\);|\1zstd_buffers \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# zstd_min_length \(.*\);|\1zstd_min_length \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# zstd_types \(.*\);|\1zstd_types \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i '/zstd_types/,+6 s/^\(\s*\)#\s*/\1/' /home/web/nginx.conf



	elif [ "$mode" == "off" ]; then
		# 关闭 Zstd：加上注释
		sed -i 's|^load_module /etc/nginx/modules/ngx_http_zstd_filter_module.so;|# load_module /etc/nginx/modules/ngx_http_zstd_filter_module.so;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^load_module /etc/nginx/modules/ngx_http_zstd_static_module.so;|# load_module /etc/nginx/modules/ngx_http_zstd_static_module.so;|' /home/web/nginx.conf > /dev/null 2>&1

		sed -i 's|^\(\s*\)zstd on;|\1# zstd on;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)zstd_static on;|\1# zstd_static on;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)zstd_comp_level \(.*\);|\1# zstd_comp_level \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)zstd_buffers \(.*\);|\1# zstd_buffers \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)zstd_min_length \(.*\);|\1# zstd_min_length \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)zstd_types \(.*\);|\1# zstd_types \2;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i '/zstd_types/,+6 {
			/^[[:space:]]*[^#[:space:]]/ s/^\(\s*\)/\1# /
		}' /home/web/nginx.conf


	else
		echo "无效的参数：使用 'on' 或 'off'"
		return 1
	fi

	# 检查 nginx 镜像并根据情况处理
	if grep -q "kjlion/nginx:alpine" /home/web/docker-compose.yml; then
		docker exec nginx nginx -s reload
	else
		sed -i 's|nginx:alpine|kjlion/nginx:alpine|g' /home/web/docker-compose.yml
		nginx_upgrade
	fi



}








nginx_gzip() {

	local mode=$1
	if [ "$mode" == "on" ]; then
		sed -i 's|^\(\s*\)# gzip on;|\1gzip on;|' /home/web/nginx.conf > /dev/null 2>&1
	elif [ "$mode" == "off" ]; then
		sed -i 's|^\(\s*\)gzip on;|\1# gzip on;|' /home/web/nginx.conf > /dev/null 2>&1
	else
		echo "无效的参数：使用 'on' 或 'off'"
		return 1
	fi

	docker exec nginx nginx -s reload

}






web_security() {
	  send_stats "LDNMP环境防御"
	  while true; do
		check_f2b_status
		check_waf_status
		check_cf_mode
			  clear
			  echo -e "服务器网站防御程序 ${check_f2b_status}${gl_lv}${CFmessage}${waf_status}${gl_bai}"
			  echo "------------------------"
			  echo "1. 安装防御程序"
			  echo "------------------------"
			  echo "5. 查看SSH拦截记录                6. 查看网站拦截记录"
			  echo "7. 查看防御规则列表               8. 查看日志实时监控"
			  echo "------------------------"
			  echo "11. 配置拦截参数                  12. 清除所有拉黑的IP"
			  echo "------------------------"
			  echo "21. cloudflare模式                22. 高负载开启5秒盾"
			  echo "------------------------"
			  echo "31. 开启WAF                       32. 关闭WAF"
			  echo "33. 开启DDOS防御                  34. 关闭DDOS防御"
			  echo "------------------------"
			  echo "9. 卸载防御程序"
			  echo "------------------------"
			  echo "0. 返回上一级选单"
			  echo "------------------------"
			  read -e -p "请输入你的选择: " sub_choice || return 1
			  case $sub_choice in
				  1)
					  f2b_install_sshd
					  cd /etc/fail2ban/filter.d
					  curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/fail2ban-nginx-cc.conf
					  wget ${gh_proxy}raw.githubusercontent.com/linuxserver/fail2ban-confs/master/filter.d/nginx-418.conf
					  wget ${gh_proxy}raw.githubusercontent.com/linuxserver/fail2ban-confs/master/filter.d/nginx-deny.conf
					  wget ${gh_proxy}raw.githubusercontent.com/linuxserver/fail2ban-confs/master/filter.d/nginx-unauthorized.conf
					  wget ${gh_proxy}raw.githubusercontent.com/linuxserver/fail2ban-confs/master/filter.d/nginx-bad-request.conf

					  cd /etc/fail2ban/jail.d/
					  curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/config/main/fail2ban/nginx-docker-cc.conf
					  sed -i "/cloudflare/d" /etc/fail2ban/jail.d/nginx-docker-cc.conf
					  f2b_status
					  ;;
				  5)
					  echo "------------------------"
					  f2b_sshd
					  echo "------------------------"
					  ;;
				  6)

					  echo "------------------------"
					  local xxx="fail2ban-nginx-cc"
					  f2b_status_xxx
					  echo "------------------------"
					  local xxx="nginx-418"
					  f2b_status_xxx
					  echo "------------------------"
					  local xxx="nginx-bad-request"
					  f2b_status_xxx
					  echo "------------------------"
					  local xxx="nginx-badbots"
					  f2b_status_xxx
					  echo "------------------------"
					  local xxx="nginx-botsearch"
					  f2b_status_xxx
					  echo "------------------------"
					  local xxx="nginx-deny"
					  f2b_status_xxx
					  echo "------------------------"
					  local xxx="nginx-http-auth"
					  f2b_status_xxx
					  echo "------------------------"
					  local xxx="nginx-unauthorized"
					  f2b_status_xxx
					  echo "------------------------"
					  local xxx="php-url-fopen"
					  f2b_status_xxx
					  echo "------------------------"

					  ;;

				  7)
					  fail2ban-client status
					  ;;
				  8)
					  tail -f /var/log/fail2ban.log

					  ;;
				  9)
					  remove fail2ban
					  rm -rf /etc/fail2ban
					  crontab -l | grep -v "CF-Under-Attack.sh" | crontab - 2>/dev/null
					  echo "Fail2Ban防御程序已卸载"
					  break
					  ;;

				  11)
					  install vim
					  vim /etc/fail2ban/jail.d/nginx-docker-cc.conf
					  f2b_status
					  break
					  ;;

				  12)
					  fail2ban-client unban --all
					  ;;

				  21)
					  send_stats "cloudflare模式"
					  echo "到cf后台右上角我的个人资料，选择左侧API令牌，获取Global API Key"
					  echo "https://dash.cloudflare.com/login"
					  read -e -p "输入CF的账号: " cfuser || return 1
					  read -e -p "输入CF的Global API Key: " cftoken || return 1

					  wget -O /home/web/conf.d/default.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/default11.conf
					  docker exec nginx nginx -s reload

					  cd /etc/fail2ban/jail.d/
					  curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/config/main/fail2ban/nginx-docker-cc.conf

					  cd /etc/fail2ban/action.d
					  curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/config/main/fail2ban/cloudflare-docker.conf

					  sed -i "s/kejilion@outlook.com/$cfuser/g" /etc/fail2ban/action.d/cloudflare-docker.conf
					  sed -i "s/APIKEY00000/$cftoken/g" /etc/fail2ban/action.d/cloudflare-docker.conf
					  f2b_status

					  echo "已配置cloudflare模式，可在cf后台，站点-安全性-事件中查看拦截记录"
					  ;;

				  22)
					  send_stats "高负载开启5秒盾"
					  echo -e "${gl_huang}网站每5分钟自动检测，当达检测到高负载会自动开盾，低负载也会自动关闭5秒盾。${gl_bai}"
					  echo "--------------"
					  echo "获取CF参数: "
					  echo -e "到cf后台右上角我的个人资料，选择左侧API令牌，获取${gl_huang}Global API Key${gl_bai}"
					  echo -e "到cf后台域名概要页面右下方获取${gl_huang}区域ID${gl_bai}"
					  echo "https://dash.cloudflare.com/login"
					  echo "--------------"
					  read -e -p "输入CF的账号: " cfuser || return 1
					  read -e -p "输入CF的Global API Key: " cftoken || return 1
					  read -e -p "输入CF中域名的区域ID: " cfzonID || return 1

					  install jq bc
					  check_crontab_installed
					  rm -f "$DAIMON_SCRIPT_DIR/CF-Under-Attack.sh"
					  daimon_download "${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/CF-Under-Attack.sh" "CF-Under-Attack.sh"
					  sed -i "s/AAAA/$cfuser/g" "$DAIMON_SCRIPT_DIR/CF-Under-Attack.sh"
					  sed -i "s/BBBB/$cftoken/g" "$DAIMON_SCRIPT_DIR/CF-Under-Attack.sh"
					  sed -i "s/CCCC/$cfzonID/g" "$DAIMON_SCRIPT_DIR/CF-Under-Attack.sh"

					  local cron_job="*/5 * * * * bash $DAIMON_SCRIPT_DIR/CF-Under-Attack.sh"

					  local existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

					  if [ -z "$existing_cron" ]; then
						  (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
						  echo "高负载自动开盾脚本已添加"
					  else
						  echo "自动开盾脚本已存在，无需添加"
					  fi

					  ;;

				  31)
					  nginx_waf on
					  echo "站点WAF已开启"
					  send_stats "站点WAF已开启"
					  ;;

				  32)
				  	  nginx_waf off
					  echo "站点WAF已关闭"
					  send_stats "站点WAF已关闭"
					  ;;

				  33)
					  enable_ddos_defense
					  ;;

				  34)
					  disable_ddos_defense
					  ;;

				  *)
					  break
					  ;;
			  esac
	  break_end
	  done
}



check_ldnmp_mode() {

	local MYSQL_CONTAINER="mysql"
	local MYSQL_CONF="/etc/mysql/conf.d/custom_mysql_config.cnf"

	# 检查 MySQL 配置文件中是否包含 4096M
	if docker exec "$MYSQL_CONTAINER" grep -q "4096M" "$MYSQL_CONF" 2>/dev/null; then
		mode_info=" 高性能模式"
	else
		mode_info=" 标准模式"
	fi



}


check_nginx_compression() {

	local CONFIG_FILE="/home/web/nginx.conf"

	# 检查 zstd 是否开启且未被注释（整行以 zstd on; 开头）
	if grep -qE '^\s*zstd\s+on;' "$CONFIG_FILE"; then
		zstd_status=" zstd压缩已开启"
	else
		zstd_status=""
	fi

	# 检查 brotli 是否开启且未被注释
	if grep -qE '^\s*brotli\s+on;' "$CONFIG_FILE"; then
		br_status=" br压缩已开启"
	else
		br_status=""
	fi

	# 检查 gzip 是否开启且未被注释
	if grep -qE '^\s*gzip\s+on;' "$CONFIG_FILE"; then
		gzip_status=" gzip压缩已开启"
	else
		gzip_status=""
	fi
}




web_optimization() {
		  while true; do
		  	  check_ldnmp_mode
			  check_nginx_compression
			  clear
			  send_stats "优化LDNMP环境"
			  echo -e "优化LDNMP环境${gl_lv}${mode_info}${gzip_status}${br_status}${zstd_status}${gl_bai}"
			  echo "------------------------"
			  echo "1. 标准模式              2. 高性能模式 (推荐2H4G以上)"
			  echo "------------------------"
			  echo "3. 开启gzip压缩          4. 关闭gzip压缩"
			  echo "5. 开启br压缩            6. 关闭br压缩"
			  echo "7. 开启zstd压缩          8. 关闭zstd压缩"
			  echo "------------------------"
			  echo "0. 返回上一级选单"
			  echo "------------------------"
			  read -e -p "请输入你的选择: " sub_choice || return 1
			  case $sub_choice in
				  1)
				  send_stats "站点标准模式"

				  local cpu_cores=$(nproc)
				  local connections=$((1024 * ${cpu_cores}))
				  sed -i "s/worker_processes.*/worker_processes ${cpu_cores};/" /home/web/nginx.conf
				  sed -i "s/worker_connections.*/worker_connections ${connections};/" /home/web/nginx.conf


				  # php调优
				  wget -O /home/optimized_php.ini ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/optimized_php.ini
				  docker cp /home/optimized_php.ini php:/usr/local/etc/php/conf.d/optimized_php.ini
				  docker cp /home/optimized_php.ini php74:/usr/local/etc/php/conf.d/optimized_php.ini
				  rm -rf /home/optimized_php.ini

				  # php调优
				  wget -O /home/www.conf ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/www-1.conf
				  docker cp /home/www.conf php:/usr/local/etc/php-fpm.d/www.conf
				  docker cp /home/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
				  rm -rf /home/www.conf

				  patch_wp_memory_limit
				  patch_wp_debug

				  fix_phpfpm_conf php
				  fix_phpfpm_conf php74

				  # mysql调优
				  wget -O /home/custom_mysql_config.cnf ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/custom_mysql_config-1.cnf
				  docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
				  rm -rf /home/custom_mysql_config.cnf


				  cd /home/web && docker compose restart

				  optimize_balanced


				  echo "LDNMP环境已设置成 标准模式"

					  ;;
				  2)
				  send_stats "站点高性能模式"

				  # nginx调优
				  local cpu_cores=$(nproc)
				  local connections=$((2048 * ${cpu_cores}))
				  sed -i "s/worker_processes.*/worker_processes ${cpu_cores};/" /home/web/nginx.conf
				  sed -i "s/worker_connections.*/worker_connections ${connections};/" /home/web/nginx.conf

				  # php调优
				  wget -O /home/optimized_php.ini ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/optimized_php.ini
				  docker cp /home/optimized_php.ini php:/usr/local/etc/php/conf.d/optimized_php.ini
				  docker cp /home/optimized_php.ini php74:/usr/local/etc/php/conf.d/optimized_php.ini
				  rm -rf /home/optimized_php.ini

				  # php调优
				  wget -O /home/www.conf ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/www.conf
				  docker cp /home/www.conf php:/usr/local/etc/php-fpm.d/www.conf
				  docker cp /home/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
				  rm -rf /home/www.conf

				  patch_wp_memory_limit 512M 512M
				  patch_wp_debug

				  fix_phpfpm_conf php
				  fix_phpfpm_conf php74

				  # mysql调优
				  wget -O /home/custom_mysql_config.cnf ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/custom_mysql_config.cnf
				  docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
				  rm -rf /home/custom_mysql_config.cnf

				  cd /home/web && docker compose restart

				  optimize_web_server

				  echo "LDNMP环境已设置成 高性能模式"

					  ;;
				  3)
				  send_stats "nginx_gzip on"
				  nginx_gzip on
					  ;;
				  4)
				  send_stats "nginx_gzip off"
				  nginx_gzip off
					  ;;
				  5)
				  send_stats "nginx_br on"
				  nginx_br on
					  ;;
				  6)
				  send_stats "nginx_br off"
				  nginx_br off
					  ;;
				  7)
				  send_stats "nginx_zstd on"
				  nginx_zstd on
					  ;;
				  8)
				  send_stats "nginx_zstd off"
				  nginx_zstd off
					  ;;
				  *)
					  break
					  ;;
			  esac
			  break_end

		  done


}










check_docker_app() {
	if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "$docker_name" ; then
		check_docker="${gl_lv}已安装${gl_bai}"
	else
		check_docker="${gl_hui}未安装${gl_bai}"
	fi
}



# check_docker_app() {

# if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "$docker_name"; then
# 	check_docker="${gl_lv}已安装${gl_bai}"
# else
# 	check_docker="${gl_hui}未安装${gl_bai}"
# fi

# }


check_docker_app_ip() {
echo "------------------------"
echo "访问地址:"
ip_address



if [ -n "$ipv4_address" ]; then
	echo "http://$ipv4_address:${docker_port}"
fi

if [ -n "$ipv6_address" ]; then
	echo "http://[$ipv6_address]:${docker_port}"
fi

local search_pattern1="$ipv4_address:${docker_port}"
local search_pattern2="127.0.0.1:${docker_port}"

for file in /home/web/conf.d/*; do
	if [ -f "$file" ]; then
		if grep -q "$search_pattern1" "$file" 2>/dev/null || grep -q "$search_pattern2" "$file" 2>/dev/null; then
			echo "https://$(basename "$file" | sed 's/\.conf$//')"
		fi
	fi
done


}


check_docker_image_update() {
	local container_name=$1
	update_status=""

	# 1. 区域检查
	local country=$(curl -s --max-time 2 ipinfo.io/country)
	[[ "$country" == "CN" ]] && return

	# 2. 获取本地镜像信息
	local container_info=$(docker inspect --format='{{.Created}},{{.Config.Image}}' "$container_name" 2>/dev/null)
	[[ -z "$container_info" ]] && return

	local container_created=$(echo "$container_info" | cut -d',' -f1)
	local full_image_name=$(echo "$container_info" | cut -d',' -f2)
	local container_created_ts=$(date -d "$container_created" +%s 2>/dev/null)

	# 3. 智能路由判断
	if [[ "$full_image_name" == ghcr.io* ]]; then
		# --- 场景 A: 镜像在 GitHub (ghcr.io) ---
		# 提取仓库路径，例如 ghcr.io/onexru/oneimg -> onexru/oneimg
		local repo_path=$(echo "$full_image_name" | sed 's/ghcr.io\///' | cut -d':' -f1)
		# 注意：ghcr.io 的 API 比较复杂，通常最快的方法是查 GitHub Repo 的 Release
		local api_url="https://api.github.com/repos/$repo_path/releases/latest"
		local remote_date=$(curl -s "$api_url" | jq -r '.published_at' 2>/dev/null)

	elif [[ "$full_image_name" == *"oneimg"* ]]; then
		# --- 场景 B: 特殊指定 (即便在 Docker Hub，也想通过 GitHub Release 判断) ---
		local api_url="https://api.github.com/repos/onexru/oneimg/releases/latest"
		local remote_date=$(curl -s "$api_url" | jq -r '.published_at' 2>/dev/null)

	else
		# --- 场景 C: 标准 Docker Hub ---
		local image_repo=${full_image_name%%:*}
		local image_tag=${full_image_name##*:}
		[[ "$image_repo" == "$image_tag" ]] && image_tag="latest"
		[[ "$image_repo" != */* ]] && image_repo="library/$image_repo"

		local api_url="https://hub.docker.com/v2/repositories/$image_repo/tags/$image_tag"
		local remote_date=$(curl -s "$api_url" | jq -r '.last_updated' 2>/dev/null)
	fi

	# 4. 时间戳对比
	if [[ -n "$remote_date" && "$remote_date" != "null" ]]; then
		local remote_ts=$(date -d "$remote_date" +%s 2>/dev/null)
		if [[ $container_created_ts -lt $remote_ts ]]; then
			update_status="${gl_huang}发现新版本!${gl_bai}"
		fi
	fi
}







block_container_port() {
	local container_name_or_id=$1
	local allowed_ip=$2

	# 获取容器的 IP 地址
	local container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name_or_id")

	if [ -z "$container_ip" ]; then
		return 1
	fi

	install iptables


	# 检查并封禁其他所有 IP
	if ! iptables -C DOCKER-USER -p tcp -d "$container_ip" -j DROP &>/dev/null; then
		iptables -I DOCKER-USER -p tcp -d "$container_ip" -j DROP
	fi

	# 检查并放行指定 IP
	if ! iptables -C DOCKER-USER -p tcp -s "$allowed_ip" -d "$container_ip" -j ACCEPT &>/dev/null; then
		iptables -I DOCKER-USER -p tcp -s "$allowed_ip" -d "$container_ip" -j ACCEPT
	fi

	# 检查并放行本地网络 127.0.0.0/8
	if ! iptables -C DOCKER-USER -p tcp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT &>/dev/null; then
		iptables -I DOCKER-USER -p tcp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT
	fi



	# 检查并封禁其他所有 IP
	if ! iptables -C DOCKER-USER -p udp -d "$container_ip" -j DROP &>/dev/null; then
		iptables -I DOCKER-USER -p udp -d "$container_ip" -j DROP
	fi

	# 检查并放行指定 IP
	if ! iptables -C DOCKER-USER -p udp -s "$allowed_ip" -d "$container_ip" -j ACCEPT &>/dev/null; then
		iptables -I DOCKER-USER -p udp -s "$allowed_ip" -d "$container_ip" -j ACCEPT
	fi

	# 检查并放行本地网络 127.0.0.0/8
	if ! iptables -C DOCKER-USER -p udp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT &>/dev/null; then
		iptables -I DOCKER-USER -p udp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT
	fi

	if ! iptables -C DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT &>/dev/null; then
		iptables -I DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT
	fi


	echo "已阻止IP+端口访问该服务"
	save_iptables_rules
}




clear_container_rules() {
	local container_name_or_id=$1
	local allowed_ip=$2

	# 获取容器的 IP 地址
	local container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name_or_id")

	if [ -z "$container_ip" ]; then
		return 1
	fi

	install iptables


	# 清除封禁其他所有 IP 的规则
	if iptables -C DOCKER-USER -p tcp -d "$container_ip" -j DROP &>/dev/null; then
		iptables -D DOCKER-USER -p tcp -d "$container_ip" -j DROP
	fi

	# 清除放行指定 IP 的规则
	if iptables -C DOCKER-USER -p tcp -s "$allowed_ip" -d "$container_ip" -j ACCEPT &>/dev/null; then
		iptables -D DOCKER-USER -p tcp -s "$allowed_ip" -d "$container_ip" -j ACCEPT
	fi

	# 清除放行本地网络 127.0.0.0/8 的规则
	if iptables -C DOCKER-USER -p tcp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT &>/dev/null; then
		iptables -D DOCKER-USER -p tcp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT
	fi





	# 清除封禁其他所有 IP 的规则
	if iptables -C DOCKER-USER -p udp -d "$container_ip" -j DROP &>/dev/null; then
		iptables -D DOCKER-USER -p udp -d "$container_ip" -j DROP
	fi

	# 清除放行指定 IP 的规则
	if iptables -C DOCKER-USER -p udp -s "$allowed_ip" -d "$container_ip" -j ACCEPT &>/dev/null; then
		iptables -D DOCKER-USER -p udp -s "$allowed_ip" -d "$container_ip" -j ACCEPT
	fi

	# 清除放行本地网络 127.0.0.0/8 的规则
	if iptables -C DOCKER-USER -p udp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT &>/dev/null; then
		iptables -D DOCKER-USER -p udp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT
	fi


	if iptables -C DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT &>/dev/null; then
		iptables -D DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT
	fi


	echo "已允许IP+端口访问该服务"
	save_iptables_rules
}






block_host_port() {
	local port=$1
	local allowed_ip=$2

	if [[ -z "$port" || -z "$allowed_ip" ]]; then
		echo "错误：请提供端口号和允许访问的 IP。"
		echo "用法: block_host_port <端口号> <允许的IP>"
		return 1
	fi

	install iptables


	# 拒绝其他所有 IP 访问
	if ! iptables -C INPUT -p tcp --dport "$port" -j DROP &>/dev/null; then
		iptables -I INPUT -p tcp --dport "$port" -j DROP
	fi

	# 允许指定 IP 访问
	if ! iptables -C INPUT -p tcp --dport "$port" -s "$allowed_ip" -j ACCEPT &>/dev/null; then
		iptables -I INPUT -p tcp --dport "$port" -s "$allowed_ip" -j ACCEPT
	fi

	# 允许本机访问
	if ! iptables -C INPUT -p tcp --dport "$port" -s 127.0.0.0/8 -j ACCEPT &>/dev/null; then
		iptables -I INPUT -p tcp --dport "$port" -s 127.0.0.0/8 -j ACCEPT
	fi





	# 拒绝其他所有 IP 访问
	if ! iptables -C INPUT -p udp --dport "$port" -j DROP &>/dev/null; then
		iptables -I INPUT -p udp --dport "$port" -j DROP
	fi

	# 允许指定 IP 访问
	if ! iptables -C INPUT -p udp --dport "$port" -s "$allowed_ip" -j ACCEPT &>/dev/null; then
		iptables -I INPUT -p udp --dport "$port" -s "$allowed_ip" -j ACCEPT
	fi

	# 允许本机访问
	if ! iptables -C INPUT -p udp --dport "$port" -s 127.0.0.0/8 -j ACCEPT &>/dev/null; then
		iptables -I INPUT -p udp --dport "$port" -s 127.0.0.0/8 -j ACCEPT
	fi

	# 允许已建立和相关连接的流量
	if ! iptables -C INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT &>/dev/null; then
		iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
	fi

	echo "已阻止IP+端口访问该服务"
	save_iptables_rules
}




clear_host_port_rules() {
	local port=$1
	local allowed_ip=$2

	if [[ -z "$port" || -z "$allowed_ip" ]]; then
		echo "错误：请提供端口号和允许访问的 IP。"
		echo "用法: clear_host_port_rules <端口号> <允许的IP>"
		return 1
	fi

	install iptables


	# 清除封禁所有其他 IP 访问的规则
	if iptables -C INPUT -p tcp --dport "$port" -j DROP &>/dev/null; then
		iptables -D INPUT -p tcp --dport "$port" -j DROP
	fi

	# 清除允许本机访问的规则
	if iptables -C INPUT -p tcp --dport "$port" -s 127.0.0.0/8 -j ACCEPT &>/dev/null; then
		iptables -D INPUT -p tcp --dport "$port" -s 127.0.0.0/8 -j ACCEPT
	fi

	# 清除允许指定 IP 访问的规则
	if iptables -C INPUT -p tcp --dport "$port" -s "$allowed_ip" -j ACCEPT &>/dev/null; then
		iptables -D INPUT -p tcp --dport "$port" -s "$allowed_ip" -j ACCEPT
	fi


	# 清除封禁所有其他 IP 访问的规则
	if iptables -C INPUT -p udp --dport "$port" -j DROP &>/dev/null; then
		iptables -D INPUT -p udp --dport "$port" -j DROP
	fi

	# 清除允许本机访问的规则
	if iptables -C INPUT -p udp --dport "$port" -s 127.0.0.0/8 -j ACCEPT &>/dev/null; then
		iptables -D INPUT -p udp --dport "$port" -s 127.0.0.0/8 -j ACCEPT
	fi

	# 清除允许指定 IP 访问的规则
	if iptables -C INPUT -p udp --dport "$port" -s "$allowed_ip" -j ACCEPT &>/dev/null; then
		iptables -D INPUT -p udp --dport "$port" -s "$allowed_ip" -j ACCEPT
	fi


	echo "已允许IP+端口访问该服务"
	save_iptables_rules

}



setup_docker_dir() {

	mkdir -p /home /home/docker 2>/dev/null

	if [ -d "/vol1/1000/" ] && [ ! -d "/vol1/1000/docker" ]; then
		cp -f /home/docker /home/docker1 2>/dev/null
		rm -rf /home/docker 2>/dev/null
		mkdir -p /vol1/1000/docker 2>/dev/null
		ln -s /vol1/1000/docker /home/docker 2>/dev/null
	fi

	if [ -d "/volume1/" ] && [ ! -d "/volume1/docker" ]; then
		cp -f /home/docker /home/docker1 2>/dev/null
		rm -rf /home/docker 2>/dev/null
		mkdir -p /volume1/docker 2>/dev/null
		ln -s /volume1/docker /home/docker 2>/dev/null
	fi


}


add_app_id() {
mkdir -p /home/docker
touch /home/docker/appno.txt
grep -qxF "${app_id}" /home/docker/appno.txt || echo "${app_id}" >> /home/docker/appno.txt

}



docker_app() {
send_stats "${docker_name}管理"

while true; do
	clear
	check_docker_app
	check_docker_image_update $docker_name
	echo -e "$docker_name $check_docker $update_status"
	echo "$docker_describe"
	echo "$docker_url"
	if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "$docker_name"; then
		if [ ! -f "/home/docker/${docker_name}_port.conf" ]; then
			local docker_port=$(docker port "$docker_name" | head -n1 | awk -F'[:]' '/->/ {print $NF; exit}')
			docker_port=${docker_port:-0000}
			echo "$docker_port" > "/home/docker/${docker_name}_port.conf"
		fi
		local docker_port=$(cat "/home/docker/${docker_name}_port.conf")
		check_docker_app_ip
	fi
	echo ""
	echo "------------------------"
	echo "1. 安装              2. 更新            3. 卸载"
	echo "------------------------"
	echo "5. 添加域名访问      6. 删除域名访问"
	echo "7. 允许IP+端口访问   8. 阻止IP+端口访问"
	echo "------------------------"
	echo "0. 返回上一级选单"
	echo "------------------------"
	read -e -p "请输入你的选择: " choice || return 1
	 case $choice in
		1)
			setup_docker_dir
			check_disk_space $app_size /home/docker
			while true; do
				read -e -p "输入应用对外服务端口，回车默认使用${docker_port}端口: " app_port || return 1
				local app_port=${app_port:-${docker_port}}

				if ss -tuln | grep -q ":$app_port "; then
					echo -e "${gl_hong}错误: ${gl_bai}端口 $app_port 已被占用，请更换一个端口"
					send_stats "应用端口已被占用"
				else
					local docker_port=$app_port
					break
				fi
			done

			install jq
			install_docker
			docker_rum
			echo "$docker_port" > "/home/docker/${docker_name}_port.conf"

			add_app_id

			clear
			echo "$docker_name 已经安装完成"
			check_docker_app_ip
			echo ""
			$docker_use
			$docker_passwd
			send_stats "安装$docker_name"
			;;
		2)
			docker rm -f "$docker_name"
			docker rmi -f "$docker_img"
			docker_rum

			add_app_id

			clear
			echo "$docker_name 已经安装完成"
			check_docker_app_ip
			echo ""
			$docker_use
			$docker_passwd
			send_stats "更新$docker_name"
			;;
		3)
			docker rm -f "$docker_name"
			docker rmi -f "$docker_img"
			rm -rf "/home/docker/$docker_name"
			rm -f /home/docker/${docker_name}_port.conf

			sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
			echo "应用已卸载"
			send_stats "卸载$docker_name"
			;;

		5)
			echo "${docker_name}域名访问设置"
			send_stats "${docker_name}域名访问设置"
			add_yuming
			ldnmp_Proxy ${yuming} 127.0.0.1 ${docker_port}
			block_container_port "$docker_name" "$ipv4_address"
			;;

		6)
			echo "域名格式 example.com 不带https://"
			web_del
			;;

		7)
			send_stats "允许IP访问 ${docker_name}"
			clear_container_rules "$docker_name" "$ipv4_address"
			;;

		8)
			send_stats "阻止IP访问 ${docker_name}"
			block_container_port "$docker_name" "$ipv4_address"
			;;

		*)
			break
			;;
	 esac
	 break_end
done

}





docker_app_plus() {
	send_stats "$app_name"
	while true; do
		clear
		check_docker_app
		check_docker_image_update $docker_name
		echo -e "$app_name $check_docker $update_status"
		echo "$app_text"
		echo "$app_url"
		if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "$docker_name"; then
			if [ ! -f "/home/docker/${docker_name}_port.conf" ]; then
				local docker_port=$(docker port "$docker_name" | head -n1 | awk -F'[:]' '/->/ {print $NF; exit}')
				docker_port=${docker_port:-0000}
				echo "$docker_port" > "/home/docker/${docker_name}_port.conf"
			fi
			local docker_port=$(cat "/home/docker/${docker_name}_port.conf")
			check_docker_app_ip
		fi
		echo ""
		echo "------------------------"
		echo "1. 安装             2. 更新             3. 卸载"
		echo "------------------------"
		echo "5. 添加域名访问     6. 删除域名访问"
		echo "7. 允许IP+端口访问  8. 阻止IP+端口访问"
		echo "------------------------"
		echo "0. 返回上一级选单"
		echo "------------------------"
		read -e -p "输入你的选择: " choice || return 1
		case $choice in
			1)
				setup_docker_dir
				check_disk_space $app_size /home/docker

				while true; do
					read -e -p "输入应用对外服务端口，回车默认使用${docker_port}端口: " app_port || return 1
					local app_port=${app_port:-${docker_port}}

					if ss -tuln | grep -q ":$app_port "; then
						echo -e "${gl_hong}错误: ${gl_bai}端口 $app_port 已被占用，请更换一个端口"
						send_stats "应用端口已被占用"
					else
						local docker_port=$app_port
						break
					fi
				done

				install jq
				install_docker
				docker_app_install
				echo "$docker_port" > "/home/docker/${docker_name}_port.conf"

				add_app_id
				send_stats "$app_name 安装"
				;;

			2)
				docker_app_update
				add_app_id
				send_stats "$app_name 更新"
				;;

			3)
				docker_app_uninstall
				rm -f /home/docker/${docker_name}_port.conf

				sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
				send_stats "$app_name 卸载"
				;;

			5)
				echo "${docker_name}域名访问设置"
				send_stats "${docker_name}域名访问设置"
				add_yuming
				ldnmp_Proxy ${yuming} 127.0.0.1 ${docker_port}
				block_container_port "$docker_name" "$ipv4_address"

				;;
			6)
				echo "域名格式 example.com 不带https://"
				web_del
				;;
			7)
				send_stats "允许IP访问 ${docker_name}"
				clear_container_rules "$docker_name" "$ipv4_address"
				;;
			8)
				send_stats "阻止IP访问 ${docker_name}"
				block_container_port "$docker_name" "$ipv4_address"
				;;
			*)
				break
				;;
		esac
		break_end
	done
}





prometheus_install() {

local PROMETHEUS_DIR="/home/docker/monitoring/prometheus"
local GRAFANA_DIR="/home/docker/monitoring/grafana"
local NETWORK_NAME="monitoring"

# Create necessary directories
mkdir -p $PROMETHEUS_DIR
mkdir -p $GRAFANA_DIR

# Set correct ownership for Grafana directory
chown -R 472:472 $GRAFANA_DIR

if [ ! -f "$PROMETHEUS_DIR/prometheus.yml" ]; then
	curl -o "$PROMETHEUS_DIR/prometheus.yml" ${gh_proxy}raw.githubusercontent.com/kejilion/config/refs/heads/main/prometheus/prometheus.yml
fi

# Create Docker network for monitoring
docker network create $NETWORK_NAME

# Run Node Exporter container
docker run -d \
  --name=node-exporter \
  --network $NETWORK_NAME \
  --restart=always \
  prom/node-exporter

# Run Prometheus container
docker run -d \
  --name prometheus \
  -v $PROMETHEUS_DIR/prometheus.yml:/etc/prometheus/prometheus.yml \
  -v $PROMETHEUS_DIR/data:/prometheus \
  --network $NETWORK_NAME \
  --restart=always \
  --user 0:0 \
  prom/prometheus:latest

# Run Grafana container
docker run -d \
  --name grafana \
  -p ${docker_port}:3000 \
  -v $GRAFANA_DIR:/var/lib/grafana \
  --network $NETWORK_NAME \
  --restart=always \
  grafana/grafana:latest

}




tmux_run() {
	# Check if the session already exists
	tmux has-session -t $SESSION_NAME 2>/dev/null
	# $? is a special variable that holds the exit status of the last executed command
	if [ $? != 0 ]; then
	  # Session doesn't exist, create a new one
	  tmux new -s $SESSION_NAME
	else
	  # Session exists, attach to it
	  tmux attach-session -t $SESSION_NAME
	fi
}


tmux_run_d() {

local base_name="tmuxd"
local tmuxd_ID=1

# 检查会话是否存在的函数
session_exists() {
  tmux has-session -t $1 2>/dev/null
}

# 循环直到找到一个不存在的会话名称
while session_exists "$base_name-$tmuxd_ID"; do
  local tmuxd_ID=$((tmuxd_ID + 1))
done

# 创建新的 tmux 会话
tmux new -d -s "$base_name-$tmuxd_ID" "$tmuxd"


}



f2b_status() {
	 fail2ban-client reload
	 sleep 3
	 fail2ban-client status
}

f2b_status_xxx() {
	fail2ban-client status $xxx
}

check_f2b_status() {
	if command -v fail2ban-client >/dev/null 2>&1; then
		check_f2b_status="${gl_lv}已安装${gl_bai}"
	else
		check_f2b_status="${gl_hui}未安装${gl_bai}"
	fi
}

f2b_install_sshd() {

	docker rm -f fail2ban >/dev/null 2>&1
	install fail2ban
	start fail2ban
	enable fail2ban

	if command -v dnf &>/dev/null; then
		cd /etc/fail2ban/jail.d/
		curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/config/main/fail2ban/centos-ssh.conf
	fi

	if command -v apt &>/dev/null; then
		install rsyslog
		systemctl start rsyslog
		systemctl enable rsyslog
	fi

}

f2b_sshd() {
	if grep -q 'Alpine' /etc/issue; then
		xxx=alpine-sshd
		f2b_status_xxx
	else
		xxx=sshd
		f2b_status_xxx
	fi
}

# 基础参数配置：封禁时长(bantime)、时间窗口(findtime)、重试次数(maxretry)
# 说明：
# - 优先写入 /etc/fail2ban/jail.d/sshd.local（覆盖默认 jail 配置，升级不易丢）
# - 若是 Alpine 且 jail 名称不同，依然写 sshd.local；Fail2Ban 会按 jail 名称匹配
f2b_basic_config() {
	root_use
	install vim

	if ! command -v fail2ban-client >/dev/null 2>&1; then
		echo -e "${gl_hui}未检测到 fail2ban-client，请先安装 fail2ban。${gl_bai}"
		return
	fi

	local jail_name="sshd"
	if grep -qi 'Alpine' /etc/issue 2>/dev/null; then
		# Alpine 默认 jail 通常为 sshd；仅当检测到自定义 alpine-sshd 规则时才切换
		if [ -f /etc/fail2ban/filter.d/alpine-sshd.conf ] || [ -f /etc/fail2ban/jail.d/alpine-ssh.conf ] || [ -f /etc/fail2ban/jail.d/alpine-sshd.local ]; then
			jail_name="alpine-sshd"
		fi
	fi

	echo "即将配置 SSH jail：$jail_name"
	read -e -p "封禁时长 bantime (秒/分钟/小时，如 3600 或 1h) [默认 1h]: " bantime || return 1
	read -e -p "时间窗口 findtime (秒/分钟/小时，如 600 或 10m) [默认 10m]: " findtime || return 1
	read -e -p "重试次数 maxretry (整数) [默认 5]: " maxretry || return 1

	bantime=${bantime:-1h}
	findtime=${findtime:-10m}
	maxretry=${maxretry:-5}

	mkdir -p /etc/fail2ban/jail.d
	cat > /etc/fail2ban/jail.d/sshd.local <<EOF
[$jail_name]
# Managed by kejilion.sh
# Note: enable the jail so these parameters take effect
enabled = true
bantime = $bantime
findtime = $findtime
maxretry = $maxretry
EOF

	# Ensure a logfile exists for sshd jail on Debian/Ubuntu minimal images
	# (without it, fail2ban-server may refuse to start)
	if [ "$jail_name" = "sshd" ]; then
		if [ -f /etc/fail2ban/jail.d/sshd.local ]; then
			grep -qE '^\s*logpath\s*=' /etc/fail2ban/jail.d/sshd.local || echo 'logpath = /var/log/auth.log' >> /etc/fail2ban/jail.d/sshd.local
		fi
	fi

	echo -e "${gl_lv}已写入配置${gl_bai}: /etc/fail2ban/jail.d/sshd.local"
	fail2ban-client reload >/dev/null 2>&1 || true
	sleep 2
	fail2ban-client status $jail_name || true
}

# 直接打开主配置/覆盖配置编辑（vim）
# 优先编辑 /etc/fail2ban/jail.d/sshd.local（更安全），若不存在则创建
f2b_edit_config() {
	root_use
	install vim

	if [ ! -d /etc/fail2ban ]; then
		echo -e "${gl_hui}/etc/fail2ban 不存在，请先安装 fail2ban。${gl_bai}"
		return
	fi

	mkdir -p /etc/fail2ban/jail.d
	local cfg="/etc/fail2ban/jail.d/sshd.local"
	[ -f "$cfg" ] || printf "[sshd]\n# bantime/findtime/maxretry\n" > "$cfg"

	vim "$cfg"
	echo -e "${gl_lv}已保存${gl_bai}，正在 reload fail2ban..."
	fail2ban-client reload >/dev/null 2>&1 || true
}



server_reboot() {

	read -e -p "$(echo -e "${gl_huang}提示: ${gl_bai}现在重启服务器吗？(Y/N): ")" rboot || return 1
	case "$rboot" in
	  [Yy])
		echo "已重启"
		reboot
		;;
	  *)
		echo "已取消"
		;;
	esac


}





output_status() {
	output=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
		$1 ~ /^(eth|ens|enp|eno)[0-9]+/ {
			rx_total += $2
			tx_total += $10
		}
		END {
			rx_units = "Bytes";
			tx_units = "Bytes";
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "K"; }
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "M"; }
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "G"; }

			if (tx_total > 1024) { tx_total /= 1024; tx_units = "K"; }
			if (tx_total > 1024) { tx_total /= 1024; tx_units = "M"; }
			if (tx_total > 1024) { tx_total /= 1024; tx_units = "G"; }

			printf("%.2f%s %.2f%s\n", rx_total, rx_units, tx_total, tx_units);
		}' /proc/net/dev)

	rx=$(echo "$output" | awk '{print $1}')
	tx=$(echo "$output" | awk '{print $2}')

}




ldnmp_install_status_one() {

   if docker inspect "php" &>/dev/null; then
	clear
	send_stats "无法再次安装LDNMP环境"
	echo -e "${gl_huang}提示: ${gl_bai}建站环境已安装。无需再次安装！"
	break_end
	linux_ldnmp
   fi

}


ldnmp_install_all() {
cd ~
send_stats "安装LDNMP环境"
root_use
clear
echo -e "${gl_huang}LDNMP环境未安装，开始安装LDNMP环境...${gl_bai}"
check_disk_space 3 /home
install_dependency
install_docker
install_certbot
install_ldnmp_conf
install_ldnmp

}


nginx_install_all() {
cd ~
send_stats "安装nginx环境"
root_use
clear
echo -e "${gl_huang}nginx未安装，开始安装nginx环境...${gl_bai}"
install_dependency
install_docker
install_certbot
install_ldnmp_conf
nginx_upgrade
clear
local nginx_version=$(docker exec nginx nginx -v 2>&1)
local nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
echo "nginx已安装完成"
echo -e "当前版本: ${gl_huang}v$nginx_version${gl_bai}"
echo ""

}




ldnmp_install_status() {

	if ! docker inspect "php" &>/dev/null; then
		send_stats "请先安装LDNMP环境"
		ldnmp_install_all
	fi

}


nginx_install_status() {

	if ! docker inspect "nginx" &>/dev/null; then
		send_stats "请先安装nginx环境"
		nginx_install_all
	fi

}




ldnmp_web_on() {
	  clear
	  echo "您的 $webname 搭建好了！"
	  echo "https://$yuming"
	  echo "------------------------"
	  echo "$webname 安装信息如下: "

}

nginx_web_on() {
	clear

	local ipv4_pattern='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
	local ipv6_pattern='^(([0-9A-Fa-f]{1,4}:){1,7}:|([0-9A-Fa-f]{1,4}:){7,7}[0-9A-Fa-f]{1,4}|::1)$'

	echo "您的 $webname 搭建好了！"

	if [[ "$yuming" =~ $ipv4_pattern || "$yuming" =~ $ipv6_pattern ]]; then
		mv /home/web/conf.d/"$yuming".conf /home/web/conf.d/"${yuming}_${access_port}".conf
		echo "http://$yuming:$access_port"
	elif grep -q '^[[:space:]]*#.*if (\$scheme = http)' "/home/web/conf.d/"$yuming".conf"; then
		echo "http://$yuming"
	else
		echo "https://$yuming"
	fi
}



ldnmp_wp() {
  clear
  # wordpress
  webname="WordPress"
  yuming="${1:-}"
  send_stats "安装$webname"
  echo "开始部署 $webname"
  if [ -z "$yuming" ]; then
	add_yuming
  fi
  repeat_add_yuming
  ldnmp_install_status


  install_ssltls
  certs_status
  add_db

  wget -O /home/web/conf.d/map.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/map.conf
  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/wordpress.com.conf
  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
  nginx_http_on


  cd /home/web/html
  mkdir $yuming
  cd $yuming
  wget -O latest.zip ${gh_proxy}github.com/kejilion/Website_source_code/raw/refs/heads/main/wp-latest.zip
  unzip latest.zip
  rm latest.zip
  echo "define('FS_METHOD', 'direct'); define('WP_REDIS_HOST', 'redis'); define('WP_REDIS_PORT', '6379'); define('WP_REDIS_MAXTTL', 86400); define('WP_CACHE_KEY_SALT', '${yuming}_');" >> /home/web/html/$yuming/wordpress/wp-config-sample.php
  sed -i "s|database_name_here|$dbname|g" /home/web/html/$yuming/wordpress/wp-config-sample.php
  sed -i "s|username_here|$dbuse|g" /home/web/html/$yuming/wordpress/wp-config-sample.php
  sed -i "s|password_here|$dbusepasswd|g" /home/web/html/$yuming/wordpress/wp-config-sample.php
  sed -i "s|localhost|mysql|g" /home/web/html/$yuming/wordpress/wp-config-sample.php
  patch_wp_url "https://$yuming" "https://$yuming"
  cp /home/web/html/$yuming/wordpress/wp-config-sample.php /home/web/html/$yuming/wordpress/wp-config.php


  restart_ldnmp
  nginx_web_on

}



ldnmp_Proxy() {
	clear
	webname="反向代理-IP+端口"
	yuming="${1:-}"
	reverseproxy="${2:-}"
	port="${3:-}"

	send_stats "安装$webname"
	echo "开始部署 $webname"
	if [ -z "$yuming" ]; then
		add_yuming
	fi

	check_ip_and_get_access_port "$yuming"

	if [ -z "$reverseproxy" ]; then
		read -e -p "请输入你的反代IP (回车默认本机IP 127.0.0.1): " reverseproxy || return 1
		reverseproxy=${reverseproxy:-127.0.0.1}
	fi

	if [ -z "$port" ]; then
		read -e -p "请输入你的反代端口: " port || return 1
	fi
	nginx_install_status


	install_ssltls
	certs_status

	wget -O /home/web/conf.d/map.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/map.conf
	wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy-backend.conf

	backend=$(tr -dc 'A-Za-z' < /dev/urandom | head -c 8)
	sed -i "s/backend_yuming_com/backend_$backend/g" /home/web/conf.d/"$yuming".conf


	sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

	reverseproxy_port="$reverseproxy:$port"
	upstream_servers=""
	for server in $reverseproxy_port; do
		upstream_servers="$upstream_servers    server $server;\n"
	done

	sed -i "s/# 动态添加/$upstream_servers/g" /home/web/conf.d/$yuming.conf
	sed -i '/remote_addr/d' /home/web/conf.d/$yuming.conf

	update_nginx_listen_port "$yuming" "$access_port"

	nginx_http_on
	docker exec nginx nginx -s reload
	nginx_web_on
}



ldnmp_Proxy_backend() {
	clear
	webname="反向代理-负载均衡"

	send_stats "安装$webname"
	echo "开始部署 $webname"
	if [ -z "$yuming" ]; then
		add_yuming
	fi

	check_ip_and_get_access_port "$yuming"

	if [ -z "$reverseproxy_port" ]; then
		read -e -p "请输入你的多个反代IP+端口用空格隔开（例如 127.0.0.1:3000 127.0.0.1:3002）： " reverseproxy_port || return 1
	fi

	nginx_install_status

	install_ssltls
	certs_status

	wget -O /home/web/conf.d/map.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/map.conf
	wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy-backend.conf

	backend=$(tr -dc 'A-Za-z' < /dev/urandom | head -c 8)
	sed -i "s/backend_yuming_com/backend_$backend/g" /home/web/conf.d/"$yuming".conf


	sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

	upstream_servers=""
	for server in $reverseproxy_port; do
		upstream_servers="$upstream_servers    server $server;\n"
	done

	sed -i "s/# 动态添加/$upstream_servers/g" /home/web/conf.d/$yuming.conf


	update_nginx_listen_port "$yuming" "$access_port"

	nginx_http_on
	docker exec nginx nginx -s reload
	nginx_web_on
}






list_stream_services() {

	STREAM_DIR="/home/web/stream.d"
	printf "%-25s %-18s %-25s %-20s\n" "服务名" "通信类型" "本机地址" "后端地址"

	if [ -z "$(ls -A "$STREAM_DIR")" ]; then
		return
	fi

	for conf in "$STREAM_DIR"/*; do
		# 服务名取文件名
		service_name=$(basename "$conf" .conf)

		# 获取 upstream 块中的 server 后端 IP:端口
		backend=$(grep -Po '(?<=server )[^;]+' "$conf" | head -n1)

		# 获取 listen 端口
		listen_port=$(grep -Po '(?<=listen )[^;]+' "$conf" | head -n1)

		# 默认本地 IP
		ip_address
		local_ip="$ipv4_address"

		# 获取通信类型，优先从文件名后缀或内容判断
		if grep -qi 'udp;' "$conf"; then
			proto="udp"
		else
			proto="tcp"
		fi

		# 拼接监听 IP:端口
		local_addr="$local_ip:$listen_port"

		printf "%-22s %-14s %-21s %-20s\n" "$service_name" "$proto" "$local_addr" "$backend"
	done
}









stream_panel() {
	send_stats "Stream四层代理"
	local app_id="104"
	local docker_name="nginx"

	while true; do
		clear
		check_docker_app
		check_docker_image_update $docker_name
		echo -e "Stream四层代理转发工具 $check_docker $update_status"
		echo "NGINX Stream 是 NGINX 的 TCP/UDP 代理模块，用于实现高性能的 传输层流量转发和负载均衡。"
		echo "------------------------"
		if [ -d "/home/web/stream.d" ]; then
			list_stream_services
		fi
		echo ""
		echo "------------------------"
		echo "1. 安装               2. 更新               3. 卸载"
		echo "------------------------"
		echo "4. 添加转发服务       5. 修改转发服务       6. 删除转发服务"
		echo "------------------------"
		echo "0. 返回上一级选单"
		echo "------------------------"
		read -e -p "输入你的选择: " choice || return 1
		case $choice in
			1)
				nginx_install_status
				add_app_id
				send_stats "安装Stream四层代理"
				;;
			2)
				update_docker_compose_with_db_creds
				nginx_upgrade
				add_app_id
				send_stats "更新Stream四层代理"
				;;
			3)
				read -e -p "确定要删除 nginx 容器吗？这可能会影响网站功能！(y/N): " confirm || return 1
				if [[ "$confirm" =~ ^[Yy]$ ]]; then
					docker rm -f nginx
					sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
					send_stats "更新Stream四层代理"
					echo "nginx 容器已删除。"
				else
					echo "操作已取消。"
				fi

				;;

			4)
				ldnmp_Proxy_backend_stream
				add_app_id
				send_stats "添加四层代理"
				;;
			5)
				send_stats "编辑转发配置"
				read -e -p "请输入你要编辑的服务名: " stream_name || return 1
				install vim
				vim /home/web/stream.d/$stream_name.conf
				docker restart nginx
				send_stats "修改四层代理"
				;;
			6)
				send_stats "删除转发配置"
				read -e -p "请输入你要删除的服务名: " stream_name || return 1
				rm /home/web/stream.d/$stream_name.conf > /dev/null 2>&1
				docker restart nginx
				send_stats "删除四层代理"
				;;
			*)
				break
				;;
		esac
		break_end
	done
}



ldnmp_Proxy_backend_stream() {
	clear
	webname="Stream四层代理-负载均衡"

	send_stats "安装$webname"
	echo "开始部署 $webname"

	# 获取代理名称
	read -erp "请输入代理转发名称 (如 mysql_proxy): " proxy_name || return 1
	if [ -z "$proxy_name" ]; then
		echo "名称不能为空"; return 1
	fi

	# 获取监听端口
	read -erp "请输入本机监听端口 (如 3306): " listen_port || return 1
	if ! [[ "$listen_port" =~ ^[0-9]+$ ]]; then
		echo "端口必须是数字"; return 1
	fi

	echo "请选择协议类型："
	echo "1. TCP    2. UDP"
	read -erp "请输入序号 [1-2]: " proto_choice || return 1

	case "$proto_choice" in
		1) proto="tcp"; listen_suffix="" ;;
		2) proto="udp"; listen_suffix=" udp" ;;
		*) echo "无效选择"; return 1 ;;
	esac

	read -e -p "请输入你的一个或者多个后端IP+端口用空格隔开（例如 10.13.0.2:3306 10.13.0.3:3306）： " reverseproxy_port || return 1

	nginx_install_status
	cd /home && mkdir -p web/stream.d
	grep -q '^[[:space:]]*stream[[:space:]]*{' /home/web/nginx.conf || echo -e '\nstream {\n    include /etc/nginx/stream.d/*.conf;\n}' | tee -a /home/web/nginx.conf
	wget -O /home/web/stream.d/$proxy_name.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy-backend-stream.conf

	backend=$(tr -dc 'A-Za-z' < /dev/urandom | head -c 8)
	sed -i "s/backend_yuming_com/${proxy_name}_${backend}/g" /home/web/stream.d/"$proxy_name".conf
	sed -i "s|listen 80|listen $listen_port $listen_suffix|g" /home/web/stream.d/$proxy_name.conf
	sed -i "s|listen \[::\]:|listen [::]:${listen_port} ${listen_suffix}|g" "/home/web/stream.d/${proxy_name}.conf"

	upstream_servers=""
	for server in $reverseproxy_port; do
		upstream_servers="$upstream_servers    server $server;\n"
	done

	sed -i "s/# 动态添加/$upstream_servers/g" /home/web/stream.d/$proxy_name.conf

	docker exec nginx nginx -s reload
	clear
	echo "您的 $webname 搭建好了！"
	echo "------------------------"
	echo "访问地址:"
	ip_address
	if [ -n "$ipv4_address" ]; then
		echo "$ipv4_address:${listen_port}"
	fi
	if [ -n "$ipv6_address" ]; then
		echo "$ipv6_address:${listen_port}"
	fi
	echo ""
}





find_container_by_host_port() {
	port="$1"
	docker_name=$(docker ps --format '{{.ID}} {{.Names}}' | while read id name; do
		if docker port "$id" | grep -q ":$port"; then
			echo "$name"
			break
		fi
	done)
}




ldnmp_web_status() {
	root_use
	while true; do
		local cert_count=$(ls /home/web/certs/*_cert.pem 2>/dev/null | wc -l)
		local output="${gl_lv}${cert_count}${gl_bai}"

		local dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
		local db_count=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SHOW DATABASES;" 2> /dev/null | grep -Ev "Database|information_schema|mysql|performance_schema|sys" | wc -l)
		local db_output="${gl_lv}${db_count}${gl_bai}"

		clear
		send_stats "LDNMP站点管理"
		echo "LDNMP环境"
		echo "------------------------"
		ldnmp_v

		echo -e "站点: ${output}                      证书到期时间"
		echo -e "------------------------"
		for cert_file in /home/web/certs/*_cert.pem; do
		  local domain=$(basename "$cert_file" | sed 's/_cert.pem//')
		  if [ -n "$domain" ]; then
			local expire_date=$(openssl x509 -noout -enddate -in "$cert_file" | awk -F'=' '{print $2}')
			local formatted_date=$(date -d "$expire_date" '+%Y-%m-%d')
			printf "%-30s%s\n" "$domain" "$formatted_date"
		  fi
		done

		for conf_file in /home/web/conf.d/*_*.conf; do
		  [ -e "$conf_file" ] || continue
		  basename "$conf_file" .conf
		done

		for conf_file in /home/web/conf.d/*.conf; do
		  [ -e "$conf_file" ] || continue

		  filename=$(basename "$conf_file")

		  if [ "$filename" = "map.conf" ] || [ "$filename" = "default.conf" ]; then
			continue
		  fi

		  if ! grep -q "ssl_certificate" "$conf_file"; then
			basename "$conf_file" .conf
		  fi
		done

		echo "------------------------"
		echo ""
		echo -e "数据库: ${db_output}"
		echo -e "------------------------"
		local dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
		docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SHOW DATABASES;" 2> /dev/null | grep -Ev "Database|information_schema|mysql|performance_schema|sys"

		echo "------------------------"
		echo ""
		echo "站点目录"
		echo "------------------------"
		echo -e "数据 ${gl_hui}/home/web/html${gl_bai}     证书 ${gl_hui}/home/web/certs${gl_bai}     配置 ${gl_hui}/home/web/conf.d${gl_bai}"
		echo "------------------------"
		echo ""
		echo "操作"
		echo "------------------------"
		echo "1.  申请/更新域名证书               2.  克隆站点域名"
		echo "3.  清理站点缓存                    4.  创建关联站点"
		echo "5.  查看访问日志                    6.  查看错误日志"
		echo "7.  编辑全局配置                    8.  编辑站点配置"
		echo "9.  管理站点数据库                  10. 查看站点分析报告"
		echo "------------------------"
		echo "20. 删除指定站点数据"
		echo "------------------------"
		echo "0. 返回上一级选单"
		echo "------------------------"
		read -e -p "请输入你的选择: " sub_choice || return 1
		case $sub_choice in
			1)
				send_stats "申请域名证书"
				read -e -p "请输入你的域名: " yuming || return 1
				install_certbot
				docker run --rm -v /etc/letsencrypt/:/etc/letsencrypt certbot/certbot delete --cert-name "$yuming" -n 2>/dev/null
				install_ssltls
				certs_status

				;;

			2)
				send_stats "克隆站点域名"
				read -e -p "请输入旧域名: " oddyuming || return 1
				read -e -p "请输入新域名: " yuming || return 1
				install_certbot
				install_ssltls
				certs_status


				add_db
				local odd_dbname=$(echo "$oddyuming" | sed -e 's/[^A-Za-z0-9]/_/g')
				local odd_dbname="${odd_dbname}"

				docker exec mysql mysqldump -u root -p"$dbrootpasswd" $odd_dbname | docker exec -i mysql mysql -u root -p"$dbrootpasswd" $dbname

				local tables=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -D $dbname -e "SHOW TABLES;" | awk '{ if (NR>1) print $1 }')
				for table in $tables; do
					columns=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -D $dbname -e "SHOW COLUMNS FROM $table;" | awk '{ if (NR>1) print $1 }')
					for column in $columns; do
						docker exec mysql mysql -u root -p"$dbrootpasswd" -D $dbname -e "UPDATE $table SET $column = REPLACE($column, '$oddyuming', '$yuming') WHERE $column LIKE '%$oddyuming%';"
					done
				done

				# 网站目录替换
				cp -r /home/web/html/$oddyuming /home/web/html/$yuming

				find /home/web/html/$yuming -type f -exec sed -i "s/$odd_dbname/$dbname/g" {} +
				find /home/web/html/$yuming -type f -exec sed -i "s/$oddyuming/$yuming/g" {} +

				cp /home/web/conf.d/$oddyuming.conf /home/web/conf.d/$yuming.conf
				sed -i "s/$oddyuming/$yuming/g" /home/web/conf.d/$yuming.conf

				cd /home/web && docker compose restart

				;;


			3)
				web_cache
				;;
			4)
				send_stats "创建关联站点"
				echo -e "为现有的站点再关联一个新域名用于访问"
				read -e -p "请输入现有的域名: " oddyuming || return 1
				read -e -p "请输入新域名: " yuming || return 1
				install_certbot
				install_ssltls
				certs_status

				cp /home/web/conf.d/$oddyuming.conf /home/web/conf.d/$yuming.conf
				sed -i "s|server_name $oddyuming|server_name $yuming|g" /home/web/conf.d/$yuming.conf
				sed -i "s|/etc/nginx/certs/${oddyuming}_cert.pem|/etc/nginx/certs/${yuming}_cert.pem|g" /home/web/conf.d/$yuming.conf
				sed -i "s|/etc/nginx/certs/${oddyuming}_key.pem|/etc/nginx/certs/${yuming}_key.pem|g" /home/web/conf.d/$yuming.conf

				docker exec nginx nginx -s reload

				;;
			5)
				send_stats "查看访问日志"
				tail -n 200 /home/web/log/nginx/access.log
				break_end
				;;
			6)
				send_stats "查看错误日志"
				tail -n 200 /home/web/log/nginx/error.log
				break_end
				;;
			7)
				send_stats "编辑全局配置"
				install vim
				vim /home/web/nginx.conf
				docker exec nginx nginx -s reload
				;;

			8)
				send_stats "编辑站点配置"
				read -e -p "编辑站点配置，请输入你要编辑的域名: " yuming || return 1
				install vim
				vim /home/web/conf.d/$yuming.conf
				docker exec nginx nginx -s reload
				;;
			9)
				phpmyadmin_upgrade
				break_end
				;;
			10)
				send_stats "查看站点数据"
				install goaccess
				goaccess --log-format=COMBINED /home/web/log/nginx/access.log
				;;

			20)
				web_del
				docker run --rm -v /etc/letsencrypt/:/etc/letsencrypt certbot/certbot delete --cert-name "$yuming" -n 2>/dev/null

				;;
			*)
				break  # 跳出循环，退出菜单
				;;
		esac
	done


}


check_panel_app() {
if $lujing > /dev/null 2>&1; then
	check_panel="${gl_lv}已安装${gl_bai}"
else
	check_panel=""
fi
}



install_panel() {
send_stats "${panelname}管理"
while true; do
	clear
	check_panel_app
	echo -e "$panelname $check_panel"
	echo "${panelname}是一款时下流行且强大的运维管理面板。"
	echo "官网介绍: $panelurl "

	echo ""
	echo "------------------------"
	echo "1. 安装            2. 管理            3. 卸载"
	echo "------------------------"
	echo "0. 返回上一级选单"
	echo "------------------------"
	read -e -p "请输入你的选择: " choice || return 1
	 case $choice in
		1)
			check_disk_space 1
			install wget
			iptables_open
			panel_app_install

			add_app_id
			send_stats "${panelname}安装"
			;;
		2)
			panel_app_manage

			add_app_id
			send_stats "${panelname}控制"

			;;
		3)
			panel_app_uninstall

			sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
			send_stats "${panelname}卸载"
			;;
		*)
			break
			;;
	 esac
	 break_end
done

}



check_frp_app() {

if [ -d "/home/frp/" ]; then
	check_frp="${gl_lv}已安装${gl_bai}"
else
	check_frp="${gl_hui}未安装${gl_bai}"
fi

}



donlond_frp() {
  role="$1"
  config_file="/home/frp/${role}.toml"

  docker run -d \
	--name "$role" \
	--restart=always \
	--network host \
	-v "$config_file":"/frp/${role}.toml" \
	kjlion/frp:alpine \
	"/frp/${role}" -c "/frp/${role}.toml"

}




generate_frps_config() {

	send_stats "安装frp服务端"
	# 生成随机端口和凭证
	local bind_port=8055
	local dashboard_port=8056
	local token=$(openssl rand -hex 16)
	local dashboard_user="user_$(openssl rand -hex 4)"
	local dashboard_pwd=$(openssl rand -hex 8)

	mkdir -p /home/frp
	touch /home/frp/frps.toml
	cat <<EOF > /home/frp/frps.toml
[common]
bind_port = $bind_port
authentication_method = token
token = $token
dashboard_port = $dashboard_port
dashboard_user = $dashboard_user
dashboard_pwd = $dashboard_pwd
EOF

	donlond_frp frps

	# 输出生成的信息
	ip_address
	echo "------------------------"
	echo "客户端部署时需要用的参数"
	echo "服务IP: $ipv4_address"
	echo "token: $token"
	echo
	echo "FRP面板信息"
	echo "FRP面板地址: http://$ipv4_address:$dashboard_port"
	echo "FRP面板用户名: $dashboard_user"
	echo "FRP面板密码: $dashboard_pwd"
	echo

	open_port 8055 8056

}



configure_frpc() {
	send_stats "安装frp客户端"
	read -e -p "请输入外网对接IP: " server_addr || return 1
	read -e -p "请输入外网对接token: " token || return 1
	echo

	mkdir -p /home/frp
	touch /home/frp/frpc.toml
	cat <<EOF > /home/frp/frpc.toml
[common]
server_addr = ${server_addr}
server_port = 8055
token = ${token}

EOF

	donlond_frp frpc

	open_port 8055

}

add_forwarding_service() {
	send_stats "添加frp内网服务"
	# 提示用户输入服务名称和转发信息
	read -e -p "请输入服务名称: " service_name || return 1
	read -e -p "请输入转发类型 (tcp/udp) [回车默认tcp]: " service_type || return 1
	local service_type=${service_type:-tcp}
	read -e -p "请输入内网IP [回车默认127.0.0.1]: " local_ip || return 1
	local local_ip=${local_ip:-127.0.0.1}
	read -e -p "请输入内网端口: " local_port || return 1
	read -e -p "请输入外网端口: " remote_port || return 1

	# 将用户输入写入配置文件
	cat <<EOF >> /home/frp/frpc.toml
[$service_name]
type = ${service_type}
local_ip = ${local_ip}
local_port = ${local_port}
remote_port = ${remote_port}

EOF

	# 输出生成的信息
	echo "服务 $service_name 已成功添加到 frpc.toml"

	docker restart frpc

	open_port $local_port

}



delete_forwarding_service() {
	send_stats "删除frp内网服务"
	# 提示用户输入需要删除的服务名称
	read -e -p "请输入需要删除的服务名称: " service_name || return 1
	# 使用 sed 删除该服务及其相关配置
	sed -i "/\[$service_name\]/,/^$/d" /home/frp/frpc.toml
	echo "服务 $service_name 已成功从 frpc.toml 删除"

	docker restart frpc

}


list_forwarding_services() {
	local config_file="$1"

	# 打印表头
	printf "%-20s %-25s %-30s %-10s\n" "服务名称" "内网地址" "外网地址" "协议"

	awk '
	BEGIN {
		server_addr=""
		server_port=""
		current_service=""
	}

	/^server_addr = / {
		gsub(/"|'"'"'/, "", $3)
		server_addr=$3
	}

	/^server_port = / {
		gsub(/"|'"'"'/, "", $3)
		server_port=$3
	}

	/^\[.*\]/ {
		# 如果已有服务信息，在处理新服务之前打印当前服务
		if (current_service != "" && current_service != "common" && local_ip != "" && local_port != "") {
			printf "%-16s %-21s %-26s %-10s\n", \
				current_service, \
				local_ip ":" local_port, \
				server_addr ":" remote_port, \
				type
		}

		# 更新当前服务名称
		if ($1 != "[common]") {
			gsub(/[\[\]]/, "", $1)
			current_service=$1
			# 清除之前的值
			local_ip=""
			local_port=""
			remote_port=""
			type=""
		}
	}

	/^local_ip = / {
		gsub(/"|'"'"'/, "", $3)
		local_ip=$3
	}

	/^local_port = / {
		gsub(/"|'"'"'/, "", $3)
		local_port=$3
	}

	/^remote_port = / {
		gsub(/"|'"'"'/, "", $3)
		remote_port=$3
	}

	/^type = / {
		gsub(/"|'"'"'/, "", $3)
		type=$3
	}

	END {
		# 打印最后一个服务的信息
		if (current_service != "" && current_service != "common" && local_ip != "" && local_port != "") {
			printf "%-16s %-21s %-26s %-10s\n", \
				current_service, \
				local_ip ":" local_port, \
				server_addr ":" remote_port, \
				type
		}
	}' "$config_file"
}



# 获取 FRP 服务端端口
get_frp_ports() {
	mapfile -t ports < <(ss -tulnape | grep frps | awk '{print $5}' | awk -F':' '{print $NF}' | sort -u)
}

# 生成访问地址
generate_access_urls() {
	# 首先获取所有端口
	get_frp_ports

	# 检查是否有非 8055/8056 的端口
	local has_valid_ports=false
	for port in "${ports[@]}"; do
		if [[ $port != "8055" && $port != "8056" ]]; then
			has_valid_ports=true
			break
		fi
	done

	# 只在有有效端口时显示标题和内容
	if [ "$has_valid_ports" = true ]; then
		echo "FRP服务对外访问地址:"

		# 处理 IPv4 地址
		for port in "${ports[@]}"; do
			if [[ $port != "8055" && $port != "8056" ]]; then
				echo "http://${ipv4_address}:${port}"
			fi
		done

		# 处理 IPv6 地址（如果存在）
		if [ -n "$ipv6_address" ]; then
			for port in "${ports[@]}"; do
				if [[ $port != "8055" && $port != "8056" ]]; then
					echo "http://[${ipv6_address}]:${port}"
				fi
			done
		fi

		# 处理 HTTPS 配置
		for port in "${ports[@]}"; do
			if [[ $port != "8055" && $port != "8056" ]]; then
				local frps_search_pattern="${ipv4_address}:${port}"
				local frps_search_pattern2="127.0.0.1:${port}"
				for file in /home/web/conf.d/*.conf; do
					if [ -f "$file" ]; then
						if grep -q "$frps_search_pattern" "$file" 2>/dev/null || grep -q "$frps_search_pattern2" "$file" 2>/dev/null; then
							echo "https://$(basename "$file" .conf)"
						fi
					fi
				done
			fi
		done
	fi
}


frps_main_ports() {
	ip_address
	generate_access_urls
}




frps_panel() {
	send_stats "FRP服务端"
	local app_id="55"
	local docker_name="frps"
	local docker_port=8056
	while true; do
		clear
		check_frp_app
		check_docker_image_update $docker_name
		echo -e "FRP服务端 $check_frp $update_status"
		echo "构建FRP内网穿透服务环境，将无公网IP的设备暴露到互联网"
		echo "官网介绍: ${gh_https_url}github.com/fatedier/frp/"
		echo "视频教学: https://www.bilibili.com/video/BV1yMw6e2EwL?t=124.0"
		if [ -d "/home/frp/" ]; then
			check_docker_app_ip
			frps_main_ports
		fi
		echo ""
		echo "------------------------"
		echo "1. 安装                  2. 更新                  3. 卸载"
		echo "------------------------"
		echo "5. 内网服务域名访问      6. 删除域名访问"
		echo "------------------------"
		echo "7. 允许IP+端口访问       8. 阻止IP+端口访问"
		echo "------------------------"
		echo "00. 刷新服务状态         0. 返回上一级选单"
		echo "------------------------"
		read -e -p "输入你的选择: " choice || return 1
		case $choice in
			1)
				install jq grep ss
				install_docker
				generate_frps_config

				add_app_id
				echo "FRP服务端已经安装完成"
				;;
			2)
				crontab -l | grep -v 'frps' | crontab - > /dev/null 2>&1
				tmux kill-session -t frps >/dev/null 2>&1
				docker rm -f frps && docker rmi kjlion/frp:alpine >/dev/null 2>&1
				[ -f /home/frp/frps.toml ] || cp /home/frp/frp_0.61.0_linux_amd64/frps.toml /home/frp/frps.toml
				donlond_frp frps

				add_app_id
				echo "FRP服务端已经更新完成"
				;;
			3)
				crontab -l | grep -v 'frps' | crontab - > /dev/null 2>&1
				tmux kill-session -t frps >/dev/null 2>&1
				docker rm -f frps && docker rmi kjlion/frp:alpine
				rm -rf /home/frp

				close_port 8055 8056

				sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
				echo "应用已卸载"
				;;
			5)
				echo "将内网穿透服务反代成域名访问"
				send_stats "FRP对外域名访问"
				add_yuming
				read -e -p "请输入你的内网穿透服务端口: " frps_port || return 1
				ldnmp_Proxy ${yuming} 127.0.0.1 ${frps_port}
				block_host_port "$frps_port" "$ipv4_address"
				;;
			6)
				echo "域名格式 example.com 不带https://"
				web_del
				;;

			7)
				send_stats "允许IP访问"
				read -e -p "请输入需要放行的端口: " frps_port || return 1
				clear_host_port_rules "$frps_port" "$ipv4_address"
				;;

			8)
				send_stats "阻止IP访问"
				echo "如果你已经反代域名访问了，可用此功能阻止IP+端口访问，这样更安全。"
				read -e -p "请输入需要阻止的端口: " frps_port || return 1
				block_host_port "$frps_port" "$ipv4_address"
				;;

			00)
				send_stats "刷新FRP服务状态"
				echo "已经刷新FRP服务状态"
				;;

			*)
				break
				;;
		esac
		break_end
	done
}


frpc_panel() {
	send_stats "FRP客户端"
	local app_id="56"
	local docker_name="frpc"
	local docker_port=8055
	while true; do
		clear
		check_frp_app
		check_docker_image_update $docker_name
		echo -e "FRP客户端 $check_frp $update_status"
		echo "与服务端对接，对接后可创建内网穿透服务到互联网访问"
		echo "官网介绍: ${gh_https_url}github.com/fatedier/frp/"
		echo "视频教学: https://www.bilibili.com/video/BV1yMw6e2EwL?t=173.9"
		echo "------------------------"
		if [ -d "/home/frp/" ]; then
			[ -f /home/frp/frpc.toml ] || cp /home/frp/frp_0.61.0_linux_amd64/frpc.toml /home/frp/frpc.toml
			list_forwarding_services "/home/frp/frpc.toml"
		fi
		echo ""
		echo "------------------------"
		echo "1. 安装               2. 更新               3. 卸载"
		echo "------------------------"
		echo "4. 添加对外服务       5. 删除对外服务       6. 手动配置服务"
		echo "------------------------"
		echo "0. 返回上一级选单"
		echo "------------------------"
		read -e -p "输入你的选择: " choice || return 1
		case $choice in
			1)
				install jq grep ss
				install_docker
				configure_frpc

				add_app_id
				echo "FRP客户端已经安装完成"
				;;
			2)
				crontab -l | grep -v 'frpc' | crontab - > /dev/null 2>&1
				tmux kill-session -t frpc >/dev/null 2>&1
				docker rm -f frpc && docker rmi kjlion/frp:alpine >/dev/null 2>&1
				[ -f /home/frp/frpc.toml ] || cp /home/frp/frp_0.61.0_linux_amd64/frpc.toml /home/frp/frpc.toml
				donlond_frp frpc

				add_app_id
				echo "FRP客户端已经更新完成"
				;;

			3)
				crontab -l | grep -v 'frpc' | crontab - > /dev/null 2>&1
				tmux kill-session -t frpc >/dev/null 2>&1
				docker rm -f frpc && docker rmi kjlion/frp:alpine
				rm -rf /home/frp
				close_port 8055

				sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
				echo "应用已卸载"
				;;

			4)
				add_forwarding_service
				;;

			5)
				delete_forwarding_service
				;;

			6)
				install vim
				vim /home/frp/frpc.toml
				docker restart frpc
				;;

			*)
				break
				;;
		esac
		break_end
	done
}




yt_menu_pro() {

	local app_id="66"
	local VIDEO_DIR="/home/yt-dlp"
	local URL_FILE="$VIDEO_DIR/urls.txt"
	local ARCHIVE_FILE="$VIDEO_DIR/archive.txt"

	mkdir -p "$VIDEO_DIR"

	while true; do

		if [ -x "/usr/local/bin/yt-dlp" ]; then
		   local YTDLP_STATUS="${gl_lv}已安装${gl_bai}"
		else
		   local YTDLP_STATUS="${gl_hui}未安装${gl_bai}"
		fi

		clear
		send_stats "yt-dlp 下载工具"
		echo -e "yt-dlp $YTDLP_STATUS"
		echo -e "yt-dlp 是一个功能强大的视频下载工具，支持 YouTube、Bilibili、Twitter 等数千站点。"
		echo -e "官网地址：${gh_https_url}github.com/yt-dlp/yt-dlp"
		echo "-------------------------"
		echo "已下载视频列表:"
		ls -td "$VIDEO_DIR"/*/ 2>/dev/null || echo "（暂无）"
		echo "-------------------------"
		echo "1.  安装               2.  更新               3.  卸载"
		echo "-------------------------"
		echo "5.  单个视频下载       6.  批量视频下载       7.  自定义参数下载"
		echo "8.  下载为MP3音频      9.  删除视频目录       10. Cookie管理（开发中）"
		echo "-------------------------"
		echo "0. 返回上一级选单"
		echo "-------------------------"
		read -e -p "请输入选项编号: " choice || return 1

		case $choice in
			1)
				send_stats "正在安装 yt-dlp..."
				echo "正在安装 yt-dlp..."
				install ffmpeg
				daimon_download_to "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" "/usr/local/bin/yt-dlp"
				chmod a+rx /usr/local/bin/yt-dlp

				add_app_id
				echo "安装完成。按任意键继续..."
				read ;;
			2)
				send_stats "正在更新 yt-dlp..."
				echo "正在更新 yt-dlp..."
				yt-dlp -U

				add_app_id
				echo "更新完成。按任意键继续..."
				read ;;
			3)
				send_stats "正在卸载 yt-dlp..."
				echo "正在卸载 yt-dlp..."
				rm -f /usr/local/bin/yt-dlp

				sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
				echo "卸载完成。按任意键继续..."
				read ;;
			5)
				send_stats "单个视频下载"
				read -e -p "请输入视频链接: " url || return 1
				yt-dlp -P "$VIDEO_DIR" -f "bv*+ba/b" --merge-output-format mp4 \
					--write-subs --sub-langs all \
					--write-thumbnail --embed-thumbnail \
					--write-info-json \
					-o "$VIDEO_DIR/%(title)s/%(title)s.%(ext)s" \
					--no-overwrites --no-post-overwrites "$url"
				read -e -p "下载完成，按任意键继续..." ;;
			6)
				send_stats "批量视频下载"
				install vim
				if [ ! -f "$URL_FILE" ]; then
				  echo -e "# 输入多个视频链接地址\n# https://www.bilibili.com/bangumi/play/ep733316?spm_id_from=333.337.0.0&from_spmid=666.25.episode.0" > "$URL_FILE"
				fi
				vim $URL_FILE
				echo "现在开始批量下载..."
				yt-dlp -P "$VIDEO_DIR" -f "bv*+ba/b" --merge-output-format mp4 \
					--write-subs --sub-langs all \
					--write-thumbnail --embed-thumbnail \
					--write-info-json \
					-a "$URL_FILE" \
					-o "$VIDEO_DIR/%(title)s/%(title)s.%(ext)s" \
					--no-overwrites --no-post-overwrites
				read -e -p "批量下载完成，按任意键继续..." ;;
			7)
				send_stats "自定义视频下载"
				read -e -p "请输入完整 yt-dlp 参数（不含 yt-dlp）: " custom || return 1
				yt-dlp -P "$VIDEO_DIR" $custom \
					--write-subs --sub-langs all \
					--write-thumbnail --embed-thumbnail \
					--write-info-json \
					-o "$VIDEO_DIR/%(title)s/%(title)s.%(ext)s" \
					--no-overwrites --no-post-overwrites
				read -e -p "执行完成，按任意键继续..." ;;
			8)
				send_stats "MP3下载"
				read -e -p "请输入视频链接: " url || return 1
				yt-dlp -P "$VIDEO_DIR" -x --audio-format mp3 \
					--write-subs --sub-langs all \
					--write-thumbnail --embed-thumbnail \
					--write-info-json \
					-o "$VIDEO_DIR/%(title)s/%(title)s.%(ext)s" \
					--no-overwrites --no-post-overwrites "$url"
				read -e -p "音频下载完成，按任意键继续..." ;;

			9)
				send_stats "删除视频"
				read -e -p "请输入删除视频名称: " rmdir || return 1
				if [ -z "$rmdir" ] || [ "$rmdir" = "." ] || [ "$rmdir" = ".." ] || [[ "$rmdir" == */* ]]; then
					echo -e "${gl_hong}名称无效，未删除任何内容。${gl_bai}"
				elif [ ! -e "$VIDEO_DIR/$rmdir" ]; then
					echo -e "${gl_huang}未找到 $rmdir，未删除任何内容。${gl_bai}"
				else
					rm -rf "$VIDEO_DIR/$rmdir"
					echo -e "${gl_lv}已删除 $rmdir${gl_bai}"
				fi
				;;
			*)
				break ;;
		esac
	done
}





current_timezone() {
	if grep -q 'Alpine' /etc/issue; then
	   date +"%Z %z"
	else
	   timedatectl | grep "Time zone" | awk '{print $3}'
	fi

}


set_timedate() {
	local shiqu="$1"
	if grep -q 'Alpine' /etc/issue; then
		install tzdata
		cp /usr/share/zoneinfo/${shiqu} /etc/localtime
		hwclock --systohc
	else
		timedatectl set-timezone ${shiqu}
	fi
}



# 修复dpkg中断问题
fix_dpkg() {
	DEBIAN_FRONTEND=noninteractive dpkg --configure -a || {
		echo "dpkg 修复失败或正被其他进程占用；请等待现有任务完成后重试，不会强杀进程或删除锁。"
		return 1
	}
}


linux_update() {
	echo -e "${gl_kjlan}正在系统更新...${gl_bai}"
	if command -v dnf &>/dev/null; then
		dnf -y update
	elif command -v yum &>/dev/null; then
		yum -y update
	elif command -v apt &>/dev/null; then
		fix_dpkg || return 1
		DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt update -y || return 1
		DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt full-upgrade -y \
			-o Dpkg::Options::="--force-confdef" \
			-o Dpkg::Options::="--force-confold"
	elif command -v apk &>/dev/null; then
		apk update && apk upgrade
	elif command -v pacman &>/dev/null; then
		pacman -Syu --noconfirm
	elif command -v zypper &>/dev/null; then
		zypper refresh
		zypper update
	elif command -v opkg &>/dev/null; then
		opkg update
	else
		echo "未知的包管理器!"
		return
	fi
}



linux_clean() {
	echo -e "${gl_kjlan}正在系统清理...${gl_bai}"
	if command -v dnf &>/dev/null; then
		rpm --rebuilddb
		dnf autoremove -y
		dnf clean all
		dnf makecache
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v yum &>/dev/null; then
		rpm --rebuilddb
		yum autoremove -y
		yum clean all
		yum makecache
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v apt &>/dev/null; then
		fix_dpkg || return 1
		DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt autoremove --purge -y || return 1
		DEBIAN_FRONTEND=noninteractive apt clean -y
		DEBIAN_FRONTEND=noninteractive apt autoclean -y
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v apk &>/dev/null; then
		echo "清理包管理器缓存..."
		apk cache clean
		echo "删除系统日志..."
		rm -rf /var/log/*
		echo "删除APK缓存..."
		rm -rf /var/cache/apk/*
		echo "删除临时文件..."
		rm -rf /tmp/*

	elif command -v pacman &>/dev/null; then
		pacman -Rns $(pacman -Qdtq) --noconfirm
		pacman -Scc --noconfirm
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v zypper &>/dev/null; then
		zypper clean --all
		zypper refresh
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v opkg &>/dev/null; then
		echo "删除系统日志..."
		rm -rf /var/log/*
		echo "删除临时文件..."
		rm -rf /tmp/*

	elif command -v pkg &>/dev/null; then
		echo "清理未使用的依赖..."
		pkg autoremove -y
		echo "清理包管理器缓存..."
		pkg clean -y
		echo "删除系统日志..."
		rm -rf /var/log/*
		echo "删除临时文件..."
		rm -rf /tmp/*

	else
		echo "未知的包管理器!"
		return
	fi
	return
}



bbr_on() {

# 统一写入到 sysctl.d 以防与内核调优模块打架
local CONF="/etc/sysctl.d/99-kejilion-bbr.conf"
mkdir -p /etc/sysctl.d
echo "net.core.default_qdisc=fq" > "$CONF"
echo "net.ipv4.tcp_congestion_control=bbr" >> "$CONF"

# 清理可能导致冲突的旧版 sysctl.conf 残留
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf 2>/dev/null
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf 2>/dev/null

sysctl -p "$CONF" >/dev/null 2>&1 || sysctl --system >/dev/null 2>&1

}


set_dns() {

ip_address

backup_resolv_conf_once
chattr -i /etc/resolv.conf
> /etc/resolv.conf

if [ -n "$ipv4_address" ]; then
	echo "nameserver $dns1_ipv4" >> /etc/resolv.conf
	echo "nameserver $dns2_ipv4" >> /etc/resolv.conf
fi

if [ -n "$ipv6_address" ]; then
	echo "nameserver $dns1_ipv6" >> /etc/resolv.conf
	echo "nameserver $dns2_ipv6" >> /etc/resolv.conf
fi

if [ ! -s /etc/resolv.conf ]; then
	echo "nameserver 223.5.5.5" >> /etc/resolv.conf
	echo "nameserver 8.8.8.8" >> /etc/resolv.conf
fi

chattr +i /etc/resolv.conf

}


backup_resolv_conf_once() {
	local backup_file="/etc/resolv.conf.daimon.bak"
	if [ -f /etc/resolv.conf ] && [ ! -f "$backup_file" ]; then
		cp -L /etc/resolv.conf "$backup_file" 2>/dev/null || cat /etc/resolv.conf > "$backup_file" 2>/dev/null || true
	fi
}

restore_dns_config() {
	local backup_file="/etc/resolv.conf.daimon.bak"
	chattr -i /etc/resolv.conf >/dev/null 2>&1 || true

	if [ -f "$backup_file" ]; then
		cat "$backup_file" > /etc/resolv.conf
		echo "已恢复之前备份的 DNS 配置: $backup_file"
	else
		cat > /etc/resolv.conf <<'EOF'
nameserver 127.0.0.53
options edns0 trust-ad
search .
EOF
		echo "未找到备份，已恢复为 Ubuntu/systemd-resolved 常见本地 DNS: 127.0.0.53"
	fi

	chattr -i /etc/resolv.conf >/dev/null 2>&1 || true
}


set_dns_ui() {
root_use
send_stats "优化DNS"
while true; do
	clear
	echo "优化DNS地址"
	echo "------------------------"
	echo "当前DNS地址"
	cat /etc/resolv.conf
	echo "------------------------"
	echo ""
	echo "1. 国外DNS优化: "
	echo " v4: 1.1.1.1 8.8.8.8"
	echo " v6: 2606:4700:4700::1111 2001:4860:4860::8888"
	echo "2. 国内DNS优化: "
	echo " v4: 223.5.5.5 119.29.29.29"
	echo " v6: 2400:3200::1 2402:4e00::"
	echo "3. 手动编辑DNS配置"
	echo "4. 恢复之前的DNS配置（没有备份则恢复为 127.0.0.53）"
	echo "------------------------"
	echo "0. 返回上一级选单"
	echo "------------------------"
	read -e -p "请输入你的选择: " Limiting || return 1
	case "$Limiting" in
	  1)
		local dns1_ipv4="1.1.1.1"
		local dns2_ipv4="8.8.8.8"
		local dns1_ipv6="2606:4700:4700::1111"
		local dns2_ipv6="2001:4860:4860::8888"
		set_dns
		send_stats "国外DNS优化"
		;;
	  2)
		local dns1_ipv4="223.5.5.5"
		local dns2_ipv4="119.29.29.29"
		local dns1_ipv6="2400:3200::1"
		local dns2_ipv6="2402:4e00::"
		set_dns
		send_stats "国内DNS优化"
		;;
	  3)
		install vim
		backup_resolv_conf_once
		chattr -i /etc/resolv.conf
		vim /etc/resolv.conf
		chattr +i /etc/resolv.conf
		send_stats "手动编辑DNS配置"
		;;
	  4)
		restore_dns_config
		send_stats "恢复DNS配置"
		;;
	  *)
		break
		;;
	esac
done

}



restart_ssh() {
	systemctl restart sshd > /dev/null 2>&1 || systemctl restart ssh > /dev/null 2>&1

}



correct_ssh_config() {

	local sshd_config="/etc/ssh/sshd_config"


	if grep -Eq "^\s*PasswordAuthentication\s+no" "$sshd_config"; then
		sed -i -e 's/^\s*#\?\s*PermitRootLogin .*/PermitRootLogin prohibit-password/' \
			   -e 's/^\s*#\?\s*PasswordAuthentication .*/PasswordAuthentication no/' \
			   -e 's/^\s*#\?\s*PubkeyAuthentication .*/PubkeyAuthentication yes/' \
			   -e 's/^\s*#\?\s*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' "$sshd_config"
	else
		sed -i -e 's/^\s*#\?\s*PermitRootLogin .*/PermitRootLogin yes/' \
			   -e 's/^\s*#\?\s*PasswordAuthentication .*/PasswordAuthentication yes/' \
			   -e 's/^\s*#\?\s*PubkeyAuthentication .*/PubkeyAuthentication yes/' "$sshd_config"
	fi

	rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
}


new_ssh_port() {

  local new_port=$1

  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

  sed -i '/^\s*#\?\s*Port\s\+/d' /etc/ssh/sshd_config
  echo "Port $new_port" >> /etc/ssh/sshd_config

  correct_ssh_config

  restart_ssh
  open_port $new_port
  remove iptables-persistent ufw firewalld iptables-services > /dev/null 2>&1

  echo "SSH 端口已修改为: $new_port"

  sleep 1

}



sshkey_on() {

	sed -i -e 's/^\s*#\?\s*PermitRootLogin .*/PermitRootLogin prohibit-password/' \
		   -e 's/^\s*#\?\s*PasswordAuthentication .*/PasswordAuthentication no/' \
		   -e 's/^\s*#\?\s*PubkeyAuthentication .*/PubkeyAuthentication yes/' \
		   -e 's/^\s*#\?\s*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
	rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
	restart_ssh
	echo -e "${gl_lv}用户密钥登录模式已开启，已关闭密码登录模式，重连将会生效${gl_bai}"

}



add_sshkey() {
	chmod 700 "${HOME}"
	mkdir -p "${HOME}/.ssh"
	chmod 700 "${HOME}/.ssh"
	touch "${HOME}/.ssh/authorized_keys"

	ssh-keygen -t ed25519 -C "xxxx@gmail.com" -f "${HOME}/.ssh/sshkey" -N ""

	cat "${HOME}/.ssh/sshkey.pub" >> "${HOME}/.ssh/authorized_keys"
	chmod 600 "${HOME}/.ssh/authorized_keys"

	ip_address
	echo -e "私钥信息已生成，务必复制保存，可保存成 ${gl_huang}${ipv4_address}_ssh.key${gl_bai} 文件，用于以后的SSH登录"

	echo "--------------------------------"
	cat "${HOME}/.ssh/sshkey"
	echo "--------------------------------"

	sshkey_on
}





import_sshkey() {

	local public_key="$1"
	local base_dir="${2:-$HOME}"
	local ssh_dir="${base_dir}/.ssh"
	local auth_keys="${ssh_dir}/authorized_keys"

	if [[ -z "$public_key" ]]; then
		read -e -p "请输入您的SSH公钥内容（通常以 'ssh-rsa' 或 'ssh-ed25519' 开头）: " public_key || return 1
	fi

	if [[ -z "$public_key" ]]; then
		echo -e "${gl_hong}错误：未输入公钥内容。${gl_bai}"
		return 1
	fi

	if [[ ! "$public_key" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
		echo -e "${gl_hong}错误：看起来不像合法的 SSH 公钥。${gl_bai}"
		return 1
	fi

	if grep -Fxq "$public_key" "$auth_keys" 2>/dev/null; then
		echo "该公钥已存在，无需重复添加"
		return 0
	fi

	mkdir -p "$ssh_dir"
	chmod 700 "$ssh_dir"
	touch "$auth_keys"
	echo "$public_key" >> "$auth_keys"
	chmod 600 "$auth_keys"

	sshkey_on
}



fetch_remote_ssh_keys() {

	local keys_url="$1"
	local base_dir="${2:-$HOME}"
	local ssh_dir="${base_dir}/.ssh"
	local authorized_keys="${ssh_dir}/authorized_keys"
	local temp_file

	if [[ -z "${keys_url}" ]]; then
		read -e -p "请输入您的远端公钥URL： " keys_url || return 1
	fi

	echo "此脚本将从远程 URL 拉取 SSH 公钥，并添加到 ${authorized_keys}"
	echo ""
	echo "远程公钥地址："
	echo "  ${keys_url}"
	echo ""

	# 创建临时文件
	temp_file=$(mktemp)

	# 下载公钥
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL --connect-timeout 10 "${keys_url}" -o "${temp_file}" || {
			echo "错误：无法从 URL 下载公钥（网络问题或地址无效）" >&2
			rm -f "${temp_file}"
			return 1
		}
	elif command -v wget >/dev/null 2>&1; then
		wget -q --timeout=10 -O "${temp_file}" "${keys_url}" || {
			echo "错误：无法从 URL 下载公钥（网络问题或地址无效）" >&2
			rm -f "${temp_file}"
			return 1
		}
	else
		echo "错误：系统中未找到 curl 或 wget，无法下载公钥" >&2
		rm -f "${temp_file}"
		return 1
	fi

	# 检查内容是否有效
	if [[ ! -s "${temp_file}" ]]; then
		echo "错误：下载到的文件为空，URL 可能不包含任何公钥" >&2
		rm -f "${temp_file}"
		return 1
	fi

	mkdir -p "${ssh_dir}"
	chmod 700 "${ssh_dir}"
	touch "${authorized_keys}"
	chmod 600 "${authorized_keys}"

	# 备份原有 authorized_keys
	if [[ -f "${authorized_keys}" ]]; then
		cp "${authorized_keys}" "${authorized_keys}.bak.$(date +%Y%m%d-%H%M%S)"
		echo "已备份原有 authorized_keys 文件"
	fi

	# 追加公钥（避免重复）
	local added=0
	while IFS= read -r line; do
		[[ -z "${line}" || "${line}" =~ ^# ]] && continue

		if ! grep -Fxq "${line}" "${authorized_keys}" 2>/dev/null; then
			echo "${line}" >> "${authorized_keys}"
			((added++))
		fi
	done < "${temp_file}"

	rm -f "${temp_file}"

	echo ""
	if (( added > 0 )); then
		echo "成功添加 ${added} 条新的公钥到 ${authorized_keys}"
		sshkey_on
	else
		echo "没有新的公钥需要添加（可能已全部存在）"
	fi

	echo ""
}




fetch_github_ssh_keys() {

	local username="$1"
	local base_dir="${2:-$HOME}"

	echo "操作前，请确保您已在 GitHub 账户中添加了 SSH 公钥："
	echo "  1. 登录 ${gh_https_url}github.com/settings/keys"
	echo "  2. 点击 New SSH key 或 Add SSH key"
	echo "  3. Title 可随意填写（例如：Home Laptop 2026）"
	echo "  4. 将本地公钥内容（通常是 ~/.ssh/id_ed25519.pub 或 id_rsa.pub 的全部内容）粘贴到 Key 字段"
	echo "  5. 点击 Add SSH key 完成添加"
	echo ""
	echo "添加完成后，GitHub 会公开提供您的所有公钥，地址为："
	echo "  ${gh_https_url}github.com/您的用户名.keys"
	echo ""


	if [[ -z "${username}" ]]; then
		read -e -p "请输入您的 GitHub 用户名（username，不含 @）： " username || return 1
	fi

	if [[ -z "${username}" ]]; then
		echo "错误：GitHub 用户名不能为空" >&2
		return 1
	fi

	keys_url="${gh_https_url}github.com/${username}.keys"

	fetch_remote_ssh_keys "${keys_url}" "${base_dir}"

}


sshkey_panel() {
  root_use
  send_stats "用户密钥登录"
  while true; do
	  clear
	  local REAL_STATUS=$(grep -i "^PubkeyAuthentication" /etc/ssh/sshd_config | tr '[:upper:]' '[:lower:]')
	  if [[ "$REAL_STATUS" =~ "yes" ]]; then
		  IS_KEY_ENABLED="${gl_lv}已启用${gl_bai}"
	  else
	  	  IS_KEY_ENABLED="${gl_hui}未启用${gl_bai}"
	  fi
  	  echo -e "用户密钥登录模式 ${IS_KEY_ENABLED}"
  	  echo "进阶玩法: https://blog.kejilion.pro/ssh-key"
  	  echo "------------------------------------------------"
  	  echo "将会生成密钥对，更安全的方式SSH登录"
	  echo "------------------------"
	  echo "1. 生成新密钥对                  2. 手动输入已有公钥"
	  echo "3. 从GitHub导入已有公钥          4. 从URL导入已有公钥"
	  echo "5. 编辑公钥文件                  6. 查看本机密钥"
	  echo "------------------------"
	  echo "0. 返回上一级选单"
	  echo "------------------------"
	  read -e -p "请输入你的选择: " host_dns || return 1
	  case $host_dns in
		  1)
	  		send_stats "生成新密钥"
	  		add_sshkey
			break_end
			  ;;
		  2)
			send_stats "导入已有公钥"
			import_sshkey
			break_end
			  ;;
		  3)
			send_stats "导入GitHub远端公钥"
			fetch_github_ssh_keys
			break_end
			  ;;
		  4)
			send_stats "导入URL远端公钥"
			read -e -p "请输入您的远端公钥URL： " keys_url || return 1
			fetch_remote_ssh_keys "${keys_url}"
			break_end
			  ;;

		  5)
			send_stats "编辑公钥文件"
			install vim
			vim ${HOME}/.ssh/authorized_keys
			break_end
			  ;;

		  6)
			send_stats "查看本机密钥"
			echo "------------------------"
			echo "公钥信息"
			cat ${HOME}/.ssh/authorized_keys
			echo "------------------------"
			echo "私钥信息"
			cat ${HOME}/.ssh/sshkey
			echo "------------------------"
			break_end
			  ;;
		  *)
			  break  # 跳出循环，退出菜单
			  ;;
	  esac
  done


}






add_sshpasswd() {

	root_use
	send_stats "设置密码登录模式"
	echo "设置密码登录模式"

	local target_user="$1"

	# 如果没有通过参数传入，则交互输入
	if [[ -z "$target_user" ]]; then
		read -e -p "请输入要修改密码的用户名（默认 root）: " target_user || return 1
	fi

	# 回车不输入，默认 root
	target_user=${target_user:-root}

	# 校验用户是否存在
	if ! id "$target_user" >/dev/null 2>&1; then
		echo "错误：用户 $target_user 不存在"
		return 1
	fi

	passwd "$target_user"

	if [[ "$target_user" == "root" ]]; then
		sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
	fi

	sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
	rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*

	restart_ssh

	echo -e "${gl_lv}密码设置完毕，已更改为密码登录模式！${gl_bai}"
}














root_use() {
clear
[ "$EUID" -ne 0 ] && echo -e "${gl_huang}提示: ${gl_bai}该功能需要root用户才能运行！" && break_end && kejilion
}














bbrv3() {
		  root_use
		  send_stats "bbrv3管理"

		  xanmod_add_repo() {
				local keyring="/usr/share/keyrings/xanmod-archive-keyring.gpg"
				local list_file="/etc/apt/sources.list.d/xanmod-release.list"
				local key_url="https://dl.xanmod.org/archive.key"
				local fallback_key_url="${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/archive.key"
				local os_codename=""

				if command -v lsb_release >/dev/null 2>&1; then
					os_codename=$(lsb_release -sc)
				elif [ -r /etc/os-release ]; then
					os_codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
				fi
				
				# 兼容官方已移除的老系统代号（回退使用 releases 尝试旧包库）
				if ! echo "bookworm trixie forky sid noble plucky questing resolute faye gigi wilma xia zara zena" | grep -qw "$os_codename"; then
					os_codename="releases"
				fi
				
				# 官方已彻底移除对 jammy, focal, bullseye 等老系统的 apt 支持
				if echo "jammy focal bullseye buster" | grep -qw "$os_codename" || [ "$os_codename" = "releases" ]; then
					echo -e "${gl_hong}XanMod 官方已停止对当前系统($os_codename)的 APT 源支持，请升级至 Debian12 / Ubuntu24 或更高版本。${gl_bai}"
					return 1
				fi

				if [ -z "$os_codename" ]; then
					echo "无法获取系统代号，无法配置XanMod源"
					return 1
				fi

				install wget gnupg ca-certificates
				mkdir -p /usr/share/keyrings /etc/apt/sources.list.d
				if ! wget -qO - "$key_url" | gpg --dearmor -o "$keyring" --yes; then
					echo "官方密钥下载失败，尝试备用下载源..."
					wget -qO - "$fallback_key_url" | gpg --dearmor -o "$keyring" --yes || return 1
				fi
				chmod 644 "$keyring"
				echo "deb [signed-by=$keyring] http://deb.xanmod.org $os_codename main" > "$list_file"
		  }

		  xanmod_detect_psabi_level() {
				local psabi_output=""
				psabi_output=$(awk 'BEGIN {
					while (!/flags/) if (getline < "/proc/cpuinfo" != 1) exit 1
					if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1
					if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2
					if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3
					if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4
					if (level > 0) { print level; exit }
					exit 1
				}' /proc/cpuinfo 2>/dev/null) || return 1
				printf '%s' "$psabi_output" | tr -dc '0-9' | head -c 1
		  }

		  xanmod_package_available() {
				local package="$1"
				apt-cache policy "$package" 2>/dev/null | grep -q 'Candidate: [^ ]'
		  }

		  xanmod_detect_package() {
				local psabi_level=""
				local level=""
				local package=""
				local prefix_list="linux-xanmod linux-xanmod-lts"

				psabi_level=$(xanmod_detect_psabi_level) || return 1
				[ -n "$psabi_level" ] || return 1
				[ "$psabi_level" -gt 3 ] && psabi_level=3

				apt update -y >/dev/null 2>&1

				for prefix in $prefix_list; do
					level="$psabi_level"
					while [ "$level" -ge 1 ]; do
						package="${prefix}-x64v${level}"
						if xanmod_package_available "$package"; then
							if [ "$level" != "$psabi_level" ] || [ "$prefix" = "linux-xanmod-lts" ]; then
								echo "已自动匹配合适安装包: $package" >&2
							fi
							printf '%s\n' "$package"
							return 0
						fi
						level=$((level - 1))
					done
				done

				echo "软件源中未找到适配此CPU的XanMod内核包" >&2
				return 1
		  }

		  xanmod_installed() {
				dpkg-query -W -f='${Package}\n' 'linux-*xanmod*' 2>/dev/null | grep -q '^linux-.*xanmod'
		  }

		  xanmod_install_or_update() {
				local action="$1"
				local package=""

				check_disk_space 3
				check_swap
				xanmod_add_repo || {
					echo "XanMod官方仓库配置失败，请稍后重试"
					return 1
				}

				package=$(xanmod_detect_package) || {
					echo "无法识别当前CPU或找不到匹配内核包，已取消安装"
					return 1
				}

				apt update -y
				if [ "$action" = "update" ]; then
					apt install -y --only-upgrade "$package" || apt install -y "$package" || {
						echo "XanMod内核更新失败，请检查软件源或稍后重试"
						return 1
					}
				else
					apt install -y "$package" || {
						echo "XanMod内核安装失败，请检查软件源或稍后重试"
						return 1
					}
				fi

				bbr_on || {
					echo "BBR3参数写入失败，请检查系统配置"
					return 1
				}
				echo "XanMod BBRv3内核处理完成。重启后生效"
				server_reboot
		  }

		  xanmod_uninstall() {
				apt purge -y 'linux-*xanmod*'
				apt autoremove -y
				update-grub 2>/dev/null || true
				rm -f /etc/apt/sources.list.d/xanmod-release.list
				rm -f /usr/share/keyrings/xanmod-archive-keyring.gpg
				echo "XanMod内核已卸载。重启后生效"
				server_reboot
		  }

		  local cpu_arch=$(uname -m)
		  if [ "$cpu_arch" = "aarch64" ]; then
			daimon_run_cached_script "https://jhb.ovh/jb/bbrv3arm.sh" "bbrv3arm.sh"
			break_end
			linux_Settings
		  fi

		  if [ -r /etc/os-release ]; then
			. /etc/os-release
			if [ "$ID" != "debian" ] && [ "$ID" != "ubuntu" ]; then
				echo "当前环境不支持，仅支持Debian和Ubuntu系统"
				break_end
				linux_Settings
			fi
		  else
			echo "无法确定操作系统类型"
			break_end
			linux_Settings
		  fi

		  if xanmod_installed; then
			while true; do
				  clear
				  local kernel_version=$(uname -r)
				  echo "您已安装xanmod的BBRv3内核"
				  echo "当前内核版本: $kernel_version"

				  echo ""
				  echo "内核管理"
				  echo "------------------------"
				  echo "1. 更新BBRv3内核              2. 卸载BBRv3内核"
				  echo "------------------------"
				  echo "0. 返回上一级选单"
				  echo "------------------------"
				  read -e -p "请输入你的选择: " sub_choice || return 1

				  case $sub_choice in
					  1)
						xanmod_install_or_update update
						;;
					  2)
						xanmod_uninstall
						;;
					  *)
						break
						;;

				  esac
			done
		else

		  clear
		  echo "设置BBR3加速"
		  echo "视频介绍: https://www.bilibili.com/video/BV14K421x7BS?t=0.1"
		  echo "------------------------------------------------"
		  echo "仅支持Debian/Ubuntu"
		  echo "请备份数据，将为你升级Linux内核开启BBR3"
		  echo "------------------------------------------------"
		  read -e -p "确定继续吗？(Y/N): " choice || return 1

		  case "$choice" in
			[Yy])
			xanmod_install_or_update install
			  ;;
			[Nn])
			  echo "已取消"
			  ;;
			*)
			  echo "无效的选择，请输入 Y 或 N。"
			  ;;
		  esac
		fi

}

elrepo_install() {
	# 导入 ELRepo GPG 公钥
	echo "导入 ELRepo GPG 公钥..."
	rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
	# 检测系统版本
	local os_version=$(rpm -q --qf "%{VERSION}" $(rpm -qf /etc/os-release) 2>/dev/null | awk -F '.' '{print $1}')
	local os_name=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
	# 确保我们在一个支持的操作系统上运行
	if [[ "$os_name" != *"Red Hat"* && "$os_name" != *"AlmaLinux"* && "$os_name" != *"Rocky"* && "$os_name" != *"Oracle"* && "$os_name" != *"CentOS"* ]]; then
		echo "不支持的操作系统：$os_name"
		break_end
		linux_Settings
	fi
	# 打印检测到的操作系统信息
	echo "检测到的操作系统: $os_name $os_version"
	# 根据系统版本安装对应的 ELRepo 仓库配置
	if [[ "$os_version" == 8 ]]; then
		echo "安装 ELRepo 仓库配置 (版本 8)..."
		yum -y install https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm
	elif [[ "$os_version" == 9 ]]; then
		echo "安装 ELRepo 仓库配置 (版本 9)..."
		yum -y install https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm
	elif [[ "$os_version" == 10 ]]; then
		echo "安装 ELRepo 仓库配置 (版本 10)..."
		yum -y install https://www.elrepo.org/elrepo-release-10.el10.elrepo.noarch.rpm
	else
		echo "不支持的系统版本：$os_version"
		break_end
		linux_Settings
	fi
	# 启用 ELRepo 内核仓库并安装最新的主线内核
	echo "启用 ELRepo 内核仓库并安装最新的主线内核..."
	# yum -y --enablerepo=elrepo-kernel install kernel-ml
	yum --nogpgcheck -y --enablerepo=elrepo-kernel install kernel-ml
	echo "已安装 ELRepo 仓库配置并更新到最新主线内核。"
	server_reboot

}


elrepo() {
		  root_use
		  send_stats "红帽内核管理"
		  if uname -r | grep -q 'elrepo'; then
			while true; do
				  clear
				  kernel_version=$(uname -r)
				  echo "您已安装elrepo内核"
				  echo "当前内核版本: $kernel_version"

				  echo ""
				  echo "内核管理"
				  echo "------------------------"
				  echo "1. 更新elrepo内核              2. 卸载elrepo内核"
				  echo "------------------------"
				  echo "0. 返回上一级选单"
				  echo "------------------------"
				  read -e -p "请输入你的选择: " sub_choice || return 1

				  case $sub_choice in
					  1)
						dnf remove -y elrepo-release
						rpm -qa | grep elrepo | grep kernel | xargs rpm -e --nodeps
						elrepo_install
						send_stats "更新红帽内核"
						server_reboot

						  ;;
					  2)
						dnf remove -y elrepo-release
						rpm -qa | grep elrepo | grep kernel | xargs rpm -e --nodeps
						echo "elrepo内核已卸载。重启后生效"
						send_stats "卸载红帽内核"
						server_reboot

						  ;;
					  *)
						  break  # 跳出循环，退出菜单
						  ;;

				  esac
			done
		else

		  clear
		  echo "请备份数据，将为你升级Linux内核"
		  echo "视频介绍: https://www.bilibili.com/video/BV1mH4y1w7qA?t=529.2"
		  echo "------------------------------------------------"
		  echo "仅支持红帽系列发行版 CentOS/RedHat/Alma/Rocky/oracle "
		  echo "升级Linux内核可提升系统性能和安全，建议有条件的尝试，生产环境谨慎升级！"
		  echo "------------------------------------------------"
		  read -e -p "确定继续吗？(Y/N): " choice || return 1

		  case "$choice" in
			[Yy])
			  check_swap
			  elrepo_install
			  send_stats "升级红帽内核"
			  server_reboot
			  ;;
			[Nn])
			  echo "已取消"
			  ;;
			*)
			  echo "无效的选择，请输入 Y 或 N。"
			  ;;
		  esac
		fi

}




clamav_freshclam() {
	echo -e "${gl_kjlan}正在更新病毒库...${gl_bai}"
	docker run --rm \
		--name clamav \
		--mount source=clam_db,target=/var/lib/clamav \
		clamav/clamav-debian:latest \
		freshclam
}

clamav_scan() {
	if [ $# -eq 0 ]; then
		echo "请指定要扫描的目录。"
		return
	fi

	echo -e "${gl_kjlan}正在扫描目录 $*... ${gl_bai}"

	# 构建 mount 参数
	local MOUNT_PARAMS=""
	for dir in "$@"; do
		MOUNT_PARAMS+="--mount type=bind,source=${dir},target=/mnt/host${dir} "
	done

	# 构建 clamscan 命令参数
	local SCAN_PARAMS=""
	for dir in "$@"; do
		SCAN_PARAMS+="/mnt/host${dir} "
	done

	mkdir -p /home/docker/clamav/log/ > /dev/null 2>&1
	> /home/docker/clamav/log/scan.log > /dev/null 2>&1

	# 执行 Docker 命令
	docker run --rm \
		--name clamav \
		--mount source=clam_db,target=/var/lib/clamav \
		$MOUNT_PARAMS \
		-v /home/docker/clamav/log/:/var/log/clamav/ \
		clamav/clamav-debian:latest \
		clamscan -r --log=/var/log/clamav/scan.log $SCAN_PARAMS

	echo -e "${gl_lv}$* 扫描完成，病毒报告存放在${gl_huang}/home/docker/clamav/log/scan.log${gl_bai}"
	echo -e "${gl_lv}如果有病毒请在${gl_huang}scan.log${gl_lv}文件中搜索FOUND关键字确认病毒位置 ${gl_bai}"

}







clamav() {
		  root_use
		  send_stats "病毒扫描管理"
		  while true; do
				clear
				echo "clamav病毒扫描工具"
				echo "视频介绍: https://www.bilibili.com/video/BV1TqvZe4EQm?t=0.1"
				echo "------------------------"
				echo "是一个开源的防病毒软件工具，主要用于检测和删除各种类型的恶意软件。"
				echo "包括病毒、特洛伊木马、间谍软件、恶意脚本和其他有害软件。"
				echo "------------------------"
				echo -e "${gl_lv}1. 全盘扫描 ${gl_bai}             ${gl_huang}2. 重要目录扫描 ${gl_bai}            ${gl_kjlan} 3. 自定义目录扫描 ${gl_bai}"
				echo "------------------------"
				echo "0. 返回上一级选单"
				echo "------------------------"
				read -e -p "请输入你的选择: " sub_choice || return 1
				case $sub_choice in
					1)
					  send_stats "全盘扫描"
					  install_docker
					  docker volume create clam_db > /dev/null 2>&1
					  clamav_freshclam
					  clamav_scan /
					  break_end

						;;
					2)
					  send_stats "重要目录扫描"
					  install_docker
					  docker volume create clam_db > /dev/null 2>&1
					  clamav_freshclam
					  clamav_scan /etc /var /usr /home /root
					  break_end
						;;
					3)
					  send_stats "自定义目录扫描"
					  read -e -p "请输入要扫描的目录，用空格分隔（例如：/etc /var /usr /home /root）: " directories || return 1
					  install_docker
					  clamav_freshclam
					  clamav_scan $directories
					  break_end
						;;
					*)
					  break  # 跳出循环，退出菜单
						;;
				esac
		  done

}


# ============================================================================
# Linux 内核调优模块（重构版）
# 统一核心函数 + 场景差异化参数 + 持久化到配置文件 + 硬件自适应
# 替换原 optimize_high_performance / optimize_balanced / optimize_web_server / restore_defaults
# ============================================================================

# 获取内存大小（MB）
_get_mem_mb() {
	awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo
}

# 统一内核调优核心函数
# 参数: $1 = 模式名称, $2 = 场景 (high/balanced/web/stream/game)
_kernel_optimize_core() {
	local mode_name="$1"
	local scene="${2:-high}"
	local CONF="/etc/sysctl.d/99-kejilion-optimize.conf"
	local MEM_MB=$(_get_mem_mb)

	echo -e "${gl_lv}切换到${mode_name}...${gl_bai}"

	# ── 根据场景设定参数 ──
	local SWAPPINESS DIRTY_RATIO DIRTY_BG_RATIO OVERCOMMIT MIN_FREE_KB VFS_PRESSURE
	local RMEM_MAX WMEM_MAX TCP_RMEM TCP_WMEM
	local SOMAXCONN BACKLOG SYN_BACKLOG
	local PORT_RANGE SCHED_AUTOGROUP THP NUMA FIN_TIMEOUT
	local KEEPALIVE_TIME KEEPALIVE_INTVL KEEPALIVE_PROBES

	case "$scene" in
		high|stream|game)
			# 高性能/直播/低延迟：激进参数
			SWAPPINESS=10
			DIRTY_RATIO=15
			DIRTY_BG_RATIO=5
			OVERCOMMIT=1
			VFS_PRESSURE=50
			RMEM_MAX=67108864
			WMEM_MAX=67108864
			TCP_RMEM="4096 262144 67108864"
			TCP_WMEM="4096 262144 67108864"
			SOMAXCONN=8192
			BACKLOG=250000
			SYN_BACKLOG=8192
			PORT_RANGE="1024 65535"
			SCHED_AUTOGROUP=0
			THP="never"
			NUMA=0
			FIN_TIMEOUT=10
			KEEPALIVE_TIME=300
			KEEPALIVE_INTVL=30
			KEEPALIVE_PROBES=5
			;;
		web)
			# 网站服务器：高并发优先
			SWAPPINESS=10
			DIRTY_RATIO=20
			DIRTY_BG_RATIO=10
			OVERCOMMIT=1
			VFS_PRESSURE=50
			RMEM_MAX=33554432
			WMEM_MAX=33554432
			TCP_RMEM="4096 131072 33554432"
			TCP_WMEM="4096 131072 33554432"
			SOMAXCONN=16384
			BACKLOG=10000
			SYN_BACKLOG=16384
			PORT_RANGE="1024 65535"
			SCHED_AUTOGROUP=0
			THP="never"
			NUMA=0
			FIN_TIMEOUT=15
			KEEPALIVE_TIME=600
			KEEPALIVE_INTVL=60
			KEEPALIVE_PROBES=5
			;;
		balanced)
			# 均衡模式：适度优化
			SWAPPINESS=30
			DIRTY_RATIO=20
			DIRTY_BG_RATIO=10
			OVERCOMMIT=0
			VFS_PRESSURE=75
			RMEM_MAX=16777216
			WMEM_MAX=16777216
			TCP_RMEM="4096 87380 16777216"
			TCP_WMEM="4096 65536 16777216"
			SOMAXCONN=4096
			BACKLOG=5000
			SYN_BACKLOG=4096
			PORT_RANGE="1024 49151"
			SCHED_AUTOGROUP=1
			THP="always"
			NUMA=1
			FIN_TIMEOUT=30
			KEEPALIVE_TIME=600
			KEEPALIVE_INTVL=60
			KEEPALIVE_PROBES=5
			;;
	esac

	# ── 根据内存大小自适应调整 ──
	if [ "$MEM_MB" -ge 16384 ]; then
		MIN_FREE_KB=131072
		[ "$scene" != "balanced" ] && SWAPPINESS=5
	elif [ "$MEM_MB" -ge 4096 ]; then
		MIN_FREE_KB=65536
	elif [ "$MEM_MB" -ge 1024 ]; then
		MIN_FREE_KB=32768
		# 小内存缩小缓冲区
		if [ "$scene" != "balanced" ]; then
			RMEM_MAX=16777216
			WMEM_MAX=16777216
			TCP_RMEM="4096 87380 16777216"
			TCP_WMEM="4096 65536 16777216"
		fi
	else
		MIN_FREE_KB=16384
		SWAPPINESS=30
		OVERCOMMIT=0
		RMEM_MAX=4194304
		WMEM_MAX=4194304
		TCP_RMEM="4096 32768 4194304"
		TCP_WMEM="4096 32768 4194304"
		SOMAXCONN=1024
		BACKLOG=1000
	fi

	# ── 直播场景额外：UDP 缓冲区加大 ──
	local STREAM_EXTRA=""
	if [ "$scene" = "stream" ]; then
		STREAM_EXTRA="
# 直播推流 UDP 优化
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.ipv4.tcp_notsent_lowat = 16384"
	fi

	# ── 低延迟场景额外：低延迟优先 ──
	local GAME_EXTRA=""
	if [ "$scene" = "game" ]; then
		GAME_EXTRA="
# 低延迟优化
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_slow_start_after_idle = 0"
	fi

	# ── 加载 BBR 模块 ──
	local CC="bbr"
	local QDISC="fq"
	local KVER
	KVER=$(uname -r | grep -oP '^\d+\.\d+')
	if printf '%s\n%s' "4.9" "$KVER" | sort -V -C; then
		if ! lsmod 2>/dev/null | grep -q tcp_bbr; then
			modprobe tcp_bbr 2>/dev/null
		fi
		if ! sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -q bbr; then
			CC="cubic"
			QDISC="fq_codel"
		fi
	else
		CC="cubic"
		QDISC="fq_codel"
	fi

	# ── 备份已有配置 ──
	[ -f "$CONF" ] && cp "$CONF" "${CONF}.bak.$(date +%s)"

	# ── 写入配置文件（持久化） ──
	echo -e "${gl_lv}写入优化配置...${gl_bai}"
	cat > "$CONF" << SYSCTL
# kejilion 内核调优配置
# 模式: $mode_name | 场景: $scene
# 内存: ${MEM_MB}MB | 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# ── TCP 拥塞控制 ──
net.core.default_qdisc = $QDISC
net.ipv4.tcp_congestion_control = $CC

# ── TCP 缓冲区 ──
net.core.rmem_max = $RMEM_MAX
net.core.wmem_max = $WMEM_MAX
net.core.rmem_default = $(echo "$TCP_RMEM" | awk '{print $2}')
net.core.wmem_default = $(echo "$TCP_WMEM" | awk '{print $2}')
net.ipv4.tcp_rmem = $TCP_RMEM
net.ipv4.tcp_wmem = $TCP_WMEM

# ── 连接队列 ──
net.core.somaxconn = $SOMAXCONN
net.core.netdev_max_backlog = $BACKLOG
net.ipv4.tcp_max_syn_backlog = $SYN_BACKLOG

# ── TCP 连接优化 ──
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = $FIN_TIMEOUT
net.ipv4.tcp_keepalive_time = $KEEPALIVE_TIME
net.ipv4.tcp_keepalive_intvl = $KEEPALIVE_INTVL
net.ipv4.tcp_keepalive_probes = $KEEPALIVE_PROBES
net.ipv4.tcp_max_tw_buckets = 65536
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1

# ── 端口与内存 ──
net.ipv4.ip_local_port_range = $PORT_RANGE
net.ipv4.tcp_mem = $((MEM_MB * 1024 / 8)) $((MEM_MB * 1024 / 4)) $((MEM_MB * 1024 / 2))
net.ipv4.tcp_max_orphans = 32768

# ── 虚拟内存 ──
vm.swappiness = $SWAPPINESS
vm.dirty_ratio = $DIRTY_RATIO
vm.dirty_background_ratio = $DIRTY_BG_RATIO
vm.overcommit_memory = $OVERCOMMIT
vm.min_free_kbytes = $MIN_FREE_KB
vm.vfs_cache_pressure = $VFS_PRESSURE

# ── CPU/内核调度 ──
kernel.sched_autogroup_enabled = $SCHED_AUTOGROUP
$([ -f /proc/sys/kernel/numa_balancing ] && echo "kernel.numa_balancing = $NUMA" || echo "# numa_balancing 不支持")

# ── 安全防护 ──
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# ── 文件描述符 ──
fs.file-max = 1048576
fs.nr_open = 1048576

# ── 连接跟踪 ──
$(if [ -f /proc/sys/net/netfilter/nf_conntrack_max ]; then
echo "net.netfilter.nf_conntrack_max = $((SOMAXCONN * 32))"
echo "net.netfilter.nf_conntrack_tcp_timeout_established = 7200"
echo "net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30"
echo "net.netfilter.nf_conntrack_tcp_timeout_close_wait = 15"
echo "net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 15"
else
echo "# conntrack 未启用"
fi)
$STREAM_EXTRA
$GAME_EXTRA
SYSCTL

	# ── 应用配置（逐行，跳过不支持的参数） ──
	echo -e "${gl_lv}应用优化参数...${gl_bai}"
	local applied=0 skipped=0
	while IFS= read -r line; do
		# 跳过注释和空行
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ -z "${line// /}" ]] && continue
		if sysctl -w "$line" >/dev/null 2>&1; then
			applied=$((applied + 1))
		else
			skipped=$((skipped + 1))
		fi
	done < "$CONF"
	echo -e "${gl_lv}已应用 ${applied} 项参数${skipped:+，跳过 ${skipped} 项不支持的参数}${gl_bai}"

	# ── 透明大页面 ──
	if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
		echo "$THP" > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null
	fi

	# ── 文件描述符限制 ──
	if ! grep -q "# kejilion-optimize" /etc/security/limits.conf 2>/dev/null; then
		cat >> /etc/security/limits.conf << 'LIMITS'

# kejilion-optimize
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
LIMITS
	fi

	# ── BBR 持久化 ──
	if [ "$CC" = "bbr" ]; then
		echo "tcp_bbr" > /etc/modules-load.d/bbr.conf 2>/dev/null
		# 清理旧的 sysctl.conf 里的 bbr 配置（避免冲突）
		sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf 2>/dev/null
	fi

	echo -e "${gl_lv}${mode_name} 优化完成！配置已持久化到 ${CONF}${gl_bai}"
	echo -e "${gl_lv}内存: ${MEM_MB}MB | 拥塞算法: ${CC} | 队列: ${QDISC}${gl_bai}"
}

# ── 各模式入口函数（保持原有调用接口不变） ──

optimize_high_performance() {
	_kernel_optimize_core "${tiaoyou_moshi:-高性能优化模式}" "high"
}

optimize_balanced() {
	_kernel_optimize_core "均衡优化模式" "balanced"
}

optimize_web_server() {
	_kernel_optimize_core "网站搭建优化模式" "web"
}

# ── 还原默认设置（完全清理） ──
restore_defaults() {
	echo -e "${gl_lv}还原到默认设置...${gl_bai}"

	local CONF="/etc/sysctl.d/99-kejilion-optimize.conf"

	# 删除优化配置文件（含外链自动调优配置）
	rm -f "$CONF"
	rm -f /etc/sysctl.d/99-network-optimize.conf

	# 清理 sysctl.conf 里可能残留的 bbr 配置
	sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf 2>/dev/null

	# 重新加载系统默认配置
	sysctl --system 2>/dev/null | tail -1

	# 还原透明大页面
	[ -f /sys/kernel/mm/transparent_hugepage/enabled ] && \
		echo always > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null

	# 清理文件描述符配置
	if grep -q "# kejilion-optimize" /etc/security/limits.conf 2>/dev/null; then
		sed -i '/# kejilion-optimize/,+4d' /etc/security/limits.conf
	fi

	# 清理 BBR 持久化
	rm -f /etc/modules-load.d/bbr.conf 2>/dev/null

	echo -e "${gl_lv}系统已还原到默认设置${gl_bai}"
}


Kernel_optimize() {
	root_use
	while true; do
	  clear
	  send_stats "Linux内核调优管理"
	  local current_mode=$(grep "^# 模式:" /etc/sysctl.d/99-kejilion-optimize.conf 2>/dev/null | sed 's/# 模式: //' | awk -F'|' '{print $1}' | xargs)
	  [ -z "$current_mode" ] && [ -f /etc/sysctl.d/99-network-optimize.conf ] && current_mode="自动调优模式"
	  echo "Linux系统内核参数优化"
	  if [ -n "$current_mode" ]; then
		  echo -e "当前模式: ${gl_lv}${current_mode}${gl_bai}"
	  else
		  echo -e "当前模式: ${gl_hui}未优化${gl_bai}"
	  fi
	  echo "视频介绍: https://www.bilibili.com/video/BV1Kb421J7yg?t=0.1"
	  echo "------------------------------------------------"
	  echo "提供多种系统参数调优模式，用户可以根据自身使用场景进行选择切换。"
	  echo -e "${gl_huang}提示: ${gl_bai}生产环境请谨慎使用！"
	  echo -e "--------------------"
	  echo -e "1. 高性能优化模式：     最大化系统性能，激进的内存和网络参数。"
	  echo -e "2. 均衡优化模式：       在性能与资源消耗之间取得平衡，适合日常使用。"
	  echo -e "3. 网站优化模式：       针对网站服务器优化，超高并发连接队列。"
	  echo -e "4. 直播优化模式：       针对直播推流优化，UDP 缓冲区加大，减少延迟。"
	  echo -e "5. 低延迟优化模式：     针对低延迟服务优化。"
	  echo -e "6. 还原默认设置：       将系统设置还原为默认配置。"
	  echo -e "7. 自动调优：           根据测试数据自动调优内核参数。"
	  echo "--------------------"
	  echo "0. 返回上一级选单"
	  echo "--------------------"
	  read -e -p "请输入你的选择: " sub_choice || return 1
	  case $sub_choice in
		  1)
			  cd ~
			  clear
			  local tiaoyou_moshi="高性能优化模式"
			  optimize_high_performance
			  send_stats "高性能模式优化"
			  ;;
		  2)
			  cd ~
			  clear
			  optimize_balanced
			  send_stats "均衡模式优化"
			  ;;
		  3)
			  cd ~
			  clear
			  optimize_web_server
			  send_stats "网站优化模式"
			  ;;
		  4)
			  cd ~
			  clear
			  _kernel_optimize_core "直播优化模式" "stream"
			  send_stats "直播推流优化"
			  ;;
		  5)
			  cd ~
			  clear
			  _kernel_optimize_core "低延迟优化模式" "game"
			  send_stats "低延迟优化"
			  ;;
		  6)
			  cd ~
			  clear
			  restore_defaults
			  daimon_download "${gh_proxy}raw.githubusercontent.com/kejilion/sh/refs/heads/main/network-optimize.sh" "network-optimize.sh" && source "$DAIMON_SCRIPT_DIR/network-optimize.sh" && restore_network_defaults
			  send_stats "还原默认设置"
			  ;;

		  7)
			  cd ~
			  clear
			  daimon_run_cached_script "${gh_proxy}raw.githubusercontent.com/kejilion/sh/refs/heads/main/network-optimize.sh" "network-optimize.sh"
			  send_stats "内核自动调优"
			  ;;

		  *)
			  break
			  ;;
	  esac
	  break_end
	done
}







update_locale() {
	local lang=$1
	local locale_file=$2
	local pause_after="${3:-true}"
	local locale_pattern="${locale_file//./\\.}"

	if [ -f /etc/os-release ]; then
		. /etc/os-release
		case $ID in
			debian|ubuntu|kali)
				install locales
				if grep -Eq "^[[:space:]]*#?[[:space:]]*${locale_pattern}([[:space:]]|$)" /etc/locale.gen; then
					sed -i "s/^\s*#\?\s*${locale_file}/${locale_file}/" /etc/locale.gen
				else
					echo "${locale_file} UTF-8" >> /etc/locale.gen
				fi
				locale-gen
				echo "LANG=${lang}" > /etc/default/locale
				export LANG=${lang}
				echo -e "${gl_lv}系统语言已经修改为: $lang 重新连接SSH生效。${gl_bai}"
				hash -r
				[ "$pause_after" = "false" ] || break_end

				;;
			centos|rhel|almalinux|rocky|fedora)
				install glibc-langpack-zh
				localectl set-locale LANG=${lang}
				echo "LANG=${lang}" | tee /etc/locale.conf
				echo -e "${gl_lv}系统语言已经修改为: $lang 重新连接SSH生效。${gl_bai}"
				hash -r
				[ "$pause_after" = "false" ] || break_end
				;;
			*)
				echo "不支持的系统: $ID"
				[ "$pause_after" = "false" ] || break_end
				;;
		esac
	else
		echo "不支持的系统，无法识别系统类型。"
		[ "$pause_after" = "false" ] || break_end
	fi
}




linux_language() {
root_use
send_stats "切换系统语言"
while true; do
  clear
  echo "当前系统语言: $LANG"
  echo "------------------------"
  echo "1. en_US.UTF-8（英文）          2. zh_CN.UTF-8（中文简体）"
  echo "3. zh_TW.UTF-8（中文繁体）      4. ja_JP.UTF-8（日文）"
  echo "5. ko_KR.UTF-8（韩文）          6. de_DE.UTF-8（德文）"
  echo "7. fr_FR.UTF-8（法文）          8. es_ES.UTF-8（西班牙文）"
  echo "9. ru_RU.UTF-8（俄文）"
  echo "------------------------"
  echo "0. 返回上一级选单"
  echo "------------------------"
  read -e -p "输入你的选择: " choice || return 1

  case $choice in
	  1)
		  update_locale "en_US.UTF-8" "en_US.UTF-8"
		  send_stats "切换到英文"
		  ;;
	  2)
		  update_locale "zh_CN.UTF-8" "zh_CN.UTF-8"
		  send_stats "切换到简体中文"
		  ;;
	  3)
		  update_locale "zh_TW.UTF-8" "zh_TW.UTF-8"
		  send_stats "切换到繁体中文"
		  ;;
	  4)
		  update_locale "ja_JP.UTF-8" "ja_JP.UTF-8"
		  send_stats "切换到日文"
		  ;;
	  5)
		  update_locale "ko_KR.UTF-8" "ko_KR.UTF-8"
		  send_stats "切换到韩文"
		  ;;
	  6)
		  update_locale "de_DE.UTF-8" "de_DE.UTF-8"
		  send_stats "切换到德文"
		  ;;
	  7)
		  update_locale "fr_FR.UTF-8" "fr_FR.UTF-8"
		  send_stats "切换到法文"
		  ;;
	  8)
		  update_locale "es_ES.UTF-8" "es_ES.UTF-8"
		  send_stats "切换到西班牙文"
		  ;;
	  9)
		  update_locale "ru_RU.UTF-8" "ru_RU.UTF-8"
		  send_stats "切换到俄文"
		  ;;
	  *)
		  break
		  ;;
  esac
done
}



shell_bianse_profile() {

if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
	sed -i '/^PS1=/d' ~/.bashrc
	echo "${bianse}" >> ~/.bashrc
	source ~/.bashrc >/dev/null 2>&1 || true
else
	sed -i '/^PS1=/d' ~/.profile
	echo "${bianse}" >> ~/.profile
	source ~/.profile >/dev/null 2>&1 || true
fi
echo -e "${gl_lv}变更完成，已尝试重新加载 shell 配置；重新连接 SSH 后完全生效。${gl_bai}"

hash -r
break_end

}



shell_bianse() {
  root_use
  send_stats "命令行美化工具"
  while true; do
	clear
	echo "命令行美化工具"
	echo "------------------------"
	echo -e "1. \033[1;32mroot \033[1;34mlocalhost \033[1;31m~ \033[0m${gl_bai}#"
	echo -e "2. \033[1;35mroot \033[1;36mlocalhost \033[1;33m~ \033[0m${gl_bai}#"
	echo -e "3. \033[1;31mroot \033[1;32mlocalhost \033[1;34m~ \033[0m${gl_bai}#"
	echo -e "4. \033[1;36mroot \033[1;33mlocalhost \033[1;37m~ \033[0m${gl_bai}#"
	echo -e "5. \033[1;37mroot \033[1;31mlocalhost \033[1;32m~ \033[0m${gl_bai}#"
	echo -e "6. \033[1;33mroot \033[1;34mlocalhost \033[1;35m~ \033[0m${gl_bai}#"
	echo -e "7. root localhost ~ #"
	echo "------------------------"
	echo "0. 返回上一级选单"
	echo "------------------------"
	read -e -p "输入你的选择: " choice || return 1

	case $choice in
	  1)
		local bianse="PS1='\[\033[1;32m\]\u\[\033[0m\]@\[\033[1;34m\]\h\[\033[0m\] \[\033[1;31m\]\w\[\033[0m\] # '"
		shell_bianse_profile

		;;
	  2)
		local bianse="PS1='\[\033[1;35m\]\u\[\033[0m\]@\[\033[1;36m\]\h\[\033[0m\] \[\033[1;33m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  3)
		local bianse="PS1='\[\033[1;31m\]\u\[\033[0m\]@\[\033[1;32m\]\h\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  4)
		local bianse="PS1='\[\033[1;36m\]\u\[\033[0m\]@\[\033[1;33m\]\h\[\033[0m\] \[\033[1;37m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  5)
		local bianse="PS1='\[\033[1;37m\]\u\[\033[0m\]@\[\033[1;31m\]\h\[\033[0m\] \[\033[1;32m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  6)
		local bianse="PS1='\[\033[1;33m\]\u\[\033[0m\]@\[\033[1;34m\]\h\[\033[0m\] \[\033[1;35m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  7)
		local bianse=""
		shell_bianse_profile
		;;
	  *)
		break
		;;
	esac

  done
}




linux_trash() {
  root_use
  send_stats "系统回收站"

  local bashrc_profile="/root/.bashrc"
  local TRASH_DIR="$HOME/.local/share/Trash/files"

  while true; do

	local trash_status
	if ! grep -q "trash-put" "$bashrc_profile"; then
		trash_status="${gl_hui}未启用${gl_bai}"
	else
		trash_status="${gl_lv}已启用${gl_bai}"
	fi

	clear
	echo -e "当前回收站 ${trash_status}"
	echo -e "启用后rm删除的文件先进入回收站，防止误删重要文件！"
	echo "------------------------------------------------"
	ls -l --color=auto "$TRASH_DIR" 2>/dev/null || echo "回收站为空"
	echo "------------------------"
	echo "1. 启用回收站          2. 关闭回收站"
	echo "3. 还原内容            4. 清空回收站"
	echo "------------------------"
	echo "0. 返回上一级选单"
	echo "------------------------"
	read -e -p "输入你的选择: " choice || return 1

	case $choice in
	  1)
		install trash-cli
		sed -i '/alias rm/d' "$bashrc_profile"
		echo "alias rm='trash-put'" >> "$bashrc_profile"
		source "$bashrc_profile"
		echo "回收站已启用，删除的文件将移至回收站。"
		sleep 2
		;;
	  2)
		remove trash-cli
		sed -i '/alias rm/d' "$bashrc_profile"
		echo "alias rm='rm -i'" >> "$bashrc_profile"
		source "$bashrc_profile"
		echo "回收站已关闭，文件将直接删除。"
		sleep 2
		;;
	  3)
		read -e -p "输入要还原的文件名: " file_to_restore || return 1
		if [ -e "$TRASH_DIR/$file_to_restore" ]; then
		  mv "$TRASH_DIR/$file_to_restore" "$HOME/"
		  echo "$file_to_restore 已还原到主目录。"
		else
		  echo "文件不存在。"
		fi
		;;
	  4)
		read -e -p "确认清空回收站？[y/n]: " confirm || return 1
		if [[ "$confirm" == "y" ]]; then
		  trash-empty
		  echo "回收站已清空。"
		fi
		;;
	  *)
		break
		;;
	esac
  done
}

linux_fav() {
send_stats "命令收藏夹"
		daimon_run_cached_script "${gh_proxy}raw.githubusercontent.com/byJoey/cmdbox/refs/heads/main/install.sh" "cmdbox-install.sh"
}

# 创建备份
create_backup() {
	send_stats "创建备份"
	local TIMESTAMP=$(date +"%Y%m%d%H%M%S")

	# 提示用户输入备份目录
	echo "创建备份示例："
	echo "  - 备份单个目录: /var/www"
	echo "  - 备份多个目录: /etc /home /var/log"
	echo "  - 直接回车将使用默认目录 (/etc /usr /home)"
	read -e -p "请输入要备份的目录（多个目录用空格分隔，直接回车则使用默认目录）：" input || return 1

	# 如果用户没有输入目录，则使用默认目录
	if [ -z "$input" ]; then
		BACKUP_PATHS=(
			"/etc"              # 配置文件和软件包配置
			"/usr"              # 已安装的软件文件
			"/home"             # 用户数据
		)
	else
		# 将用户输入的目录按空格分隔成数组
		IFS=' ' read -r -a BACKUP_PATHS <<< "$input"
	fi

	# 生成备份文件前缀
	local PREFIX=""
	for path in "${BACKUP_PATHS[@]}"; do
		# 提取目录名称并去除斜杠
		dir_name=$(basename "$path")
		PREFIX+="${dir_name}_"
	done

	# 去除最后一个下划线
	local PREFIX=${PREFIX%_}

	# 生成备份文件名
	local BACKUP_NAME="${PREFIX}_$TIMESTAMP.tar.gz"

	# 打印用户选择的目录
	echo "您选择的备份目录为："
	for path in "${BACKUP_PATHS[@]}"; do
		echo "- $path"
	done

	# 创建备份
	echo "正在创建备份 $BACKUP_NAME..."
	install tar
	tar -czvf "$BACKUP_DIR/$BACKUP_NAME" "${BACKUP_PATHS[@]}"

	# 检查命令是否成功
	if [ $? -eq 0 ]; then
		echo "备份创建成功: $BACKUP_DIR/$BACKUP_NAME"
	else
		echo "备份创建失败！"
		exit 1
	fi
}

# 恢复备份
restore_backup() {
	send_stats "恢复备份"
	# 选择要恢复的备份
	read -e -p "请输入要恢复的备份文件名: " BACKUP_NAME || return 1

	# 检查备份文件是否存在
	if [ ! -f "$BACKUP_DIR/$BACKUP_NAME" ]; then
		echo "备份文件不存在！"
		exit 1
	fi

	echo "正在恢复备份 $BACKUP_NAME..."
	tar -xzvf "$BACKUP_DIR/$BACKUP_NAME" -C /

	if [ $? -eq 0 ]; then
		echo "备份恢复成功！"
	else
		echo "备份恢复失败！"
		exit 1
	fi
}

# 列出备份
list_backups() {
	echo "可用的备份："
	ls -1 "$BACKUP_DIR"
}

# 删除备份
delete_backup() {
	send_stats "删除备份"

	read -e -p "请输入要删除的备份文件名: " BACKUP_NAME || return 1

	# 检查备份文件是否存在
	if [ ! -f "$BACKUP_DIR/$BACKUP_NAME" ]; then
		echo "备份文件不存在！"
		exit 1
	fi

	# 删除备份
	rm -f "$BACKUP_DIR/$BACKUP_NAME"

	if [ $? -eq 0 ]; then
		echo "备份删除成功！"
	else
		echo "备份删除失败！"
		exit 1
	fi
}

# 备份主菜单
linux_backup() {
	BACKUP_DIR="/backups"
	mkdir -p "$BACKUP_DIR"
	while true; do
		clear
		send_stats "系统备份功能"
		echo "系统备份功能"
		echo "------------------------"
		list_backups
		echo "------------------------"
		echo "1. 创建备份        2. 恢复备份        3. 删除备份"
		echo "------------------------"
		echo "0. 返回上一级选单"
		echo "------------------------"
		read -e -p "请输入你的选择: " choice || return 1
		case $choice in
			1) create_backup ;;
			2) restore_backup ;;
			3) delete_backup ;;
			*) break ;;
		esac
		read -e -p "按回车键继续..."
	done
}









# SSH 输入标准化函数
kj_ssh_validate_host() {
	local host="$1"
	[[ -n "$host" && ! "$host" =~ [[:space:]] && "$host" =~ ^[A-Za-z0-9._:-]+$ ]]
}

kj_ssh_validate_port() {
	local port="$1"
	[[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

kj_ssh_validate_user() {
	local user="$1"
	[[ -n "$user" && "$user" =~ ^[A-Za-z_][A-Za-z0-9._-]*$ ]]
}

kj_ssh_read_host_port() {
	local host_prompt="$1"
	local port_prompt="$2"
	local default_port="${3:-22}"

	while true; do
		read -e -p "$host_prompt" KJ_SSH_HOST || return 1
		if kj_ssh_validate_host "$KJ_SSH_HOST"; then
			break
		fi
		echo "错误: 请输入有效的服务器地址。"
	done

	while true; do
		read -e -p "$port_prompt" KJ_SSH_PORT || return 1
		KJ_SSH_PORT=${KJ_SSH_PORT:-$default_port}
		if kj_ssh_validate_port "$KJ_SSH_PORT"; then
			break
		fi
		echo "错误: 端口必须是 1-65535 之间的数字。"
	done
}

kj_ssh_read_host_user_port() {
	local host_prompt="$1"
	local user_prompt="$2"
	local port_prompt="$3"
	local default_user="${4:-root}"
	local default_port="${5:-22}"

	kj_ssh_read_host_port "$host_prompt" "$port_prompt" "$default_port"

	while true; do
		read -e -p "$user_prompt" KJ_SSH_USER || return 1
		KJ_SSH_USER=${KJ_SSH_USER:-$default_user}
		if kj_ssh_validate_user "$KJ_SSH_USER"; then
			break
		fi
		echo "错误: 用户名格式不正确。"
	done
}

kj_ssh_parse_remote() {
	local remote_raw="$1"
	local default_user="${2:-root}"
	local remote_user remote_host

	if [[ "$remote_raw" == *@* ]]; then
		remote_user="${remote_raw%@*}"
		remote_host="${remote_raw#*@}"
	else
		remote_user="$default_user"
		remote_host="$remote_raw"
	fi

	if ! kj_ssh_validate_user "$remote_user"; then
		echo "错误: SSH 用户名格式不正确。"
		return 1
	fi

	if ! kj_ssh_validate_host "$remote_host"; then
		echo "错误: SSH 主机地址格式不正确。"
		return 1
	fi

	KJ_SSH_USER="$remote_user"
	KJ_SSH_HOST="$remote_host"
	KJ_SSH_REMOTE="$remote_user@$remote_host"
}

kj_ssh_read_auth() {
	local key_file="$1"
	local password_or_key=""

	echo "请选择身份验证方式:"
	echo "1. 密码"
	echo "2. 密钥"
	read -e -p "请输入选择 (1/2): " auth_choice || return 1

	case $auth_choice in
		1)
			read -s -p "请输入密码: " password_or_key || return 1
			echo
			if [ -z "$password_or_key" ]; then
				echo "错误: 密码不能为空。"
				return 1
			fi
			KJ_SSH_AUTH_METHOD="password"
			KJ_SSH_AUTH_SECRET="$password_or_key"
			;;
		2)
			echo "请粘贴密钥内容 (粘贴完成后按两次回车)："
			while IFS= read -r line; do
				if [[ -z "$line" && "$password_or_key" == *"-----BEGIN"* ]]; then
					break
				fi
				if [[ -n "$line" || "$password_or_key" == *"-----BEGIN"* ]]; then
					password_or_key+="${line}"$'\n'
				fi
			done

			if [[ "$password_or_key" != *"-----BEGIN"* || "$password_or_key" != *"PRIVATE KEY-----"* ]]; then
				echo "无效的密钥内容！"
				return 1
			fi

			mkdir -p "$(dirname "$key_file")"
			echo -n "$password_or_key" > "$key_file"
			chmod 600 "$key_file"
			KJ_SSH_AUTH_METHOD="key"
			KJ_SSH_AUTH_SECRET="$key_file"
			;;
		*)
			echo "无效的选择！"
			return 1
			;;
	esac
}

kj_ssh_read_password() {
	local prompt="${1:-请输入密码: }"
	while true; do
		read -e -s -p "$prompt" KJ_SSH_PASSWORD || return 1
		echo
		[ -n "$KJ_SSH_PASSWORD" ] && break
		echo "错误: 密码不能为空。"
	done
}

kj_ssh_read_port() {
	local port_prompt="$1"
	local default_port="${2:-22}"
	while true; do
		read -e -p "$port_prompt" KJ_SSH_PORT || return 1
		KJ_SSH_PORT=${KJ_SSH_PORT:-$default_port}
		if kj_ssh_validate_port "$KJ_SSH_PORT"; then
			return 0
		fi
		echo "错误: 端口必须是 1-65535 之间的数字。"
	done
}

# 显示连接列表
list_connections() {
	echo "已保存的连接:"
	echo "------------------------"
	cat "$CONFIG_FILE" | awk -F'|' '{print NR " - " $1 " (" $2 ")"}'
	echo "------------------------"
}


# 添加新连接
add_connection() {
	send_stats "添加新连接"
	echo "创建新连接示例："
	echo "  - 连接名称: my_server"
	echo "  - IP地址: 192.168.1.100"
	echo "  - 用户名: root"
	echo "  - 端口: 22"
	echo "------------------------"
	read -e -p "请输入连接名称: " name || return 1

	kj_ssh_read_host_user_port "请输入IP地址: " "请输入用户名 (默认: root): " "请输入端口号 (默认: 22): " "root" "22"
	if ! kj_ssh_read_auth "$KEY_DIR/$name.key"; then
		return
	fi

	echo "$name|$KJ_SSH_HOST|$KJ_SSH_USER|$KJ_SSH_PORT|$KJ_SSH_AUTH_SECRET" >> "$CONFIG_FILE"
	echo "连接已保存!"
}



# 删除连接
delete_connection() {
	send_stats "删除连接"
	read -e -p "请输入要删除的连接编号: " num || return 1

	local connection=$(sed -n "${num}p" "$CONFIG_FILE")
	if [[ -z "$connection" ]]; then
		echo "错误：未找到对应的连接。"
		return
	fi

	IFS='|' read -r name ip user port password_or_key <<< "$connection"

	# 如果连接使用的是密钥文件，则删除该密钥文件
	if [[ "$password_or_key" == "$KEY_DIR"* ]]; then
		rm -f "$password_or_key"
	fi

	sed -i "${num}d" "$CONFIG_FILE"
	echo "连接已删除!"
}

# 使用连接
use_connection() {
	send_stats "使用连接"
	read -e -p "请输入要使用的连接编号: " num || return 1

	local connection=$(sed -n "${num}p" "$CONFIG_FILE")
	if [[ -z "$connection" ]]; then
		echo "错误：未找到对应的连接。"
		return
	fi

	IFS='|' read -r name ip user port password_or_key <<< "$connection"

	echo "正在连接到 $name ($ip)..."
	if [[ -f "$password_or_key" ]]; then
		# 使用密钥连接
		ssh -o StrictHostKeyChecking=no -i "$password_or_key" -p "$port" "$user@$ip"
		if [[ $? -ne 0 ]]; then
			echo "连接失败！请检查以下内容："
			echo "1. 密钥文件路径是否正确：$password_or_key"
			echo "2. 密钥文件权限是否正确（应为 600）。"
			echo "3. 目标服务器是否允许使用密钥登录。"
		fi
	else
		# 使用密码连接
		if ! command -v sshpass &> /dev/null; then
			echo "错误：未安装 sshpass，请先安装 sshpass。"
			echo "安装方法："
			echo "  - Ubuntu/Debian: apt install sshpass"
			echo "  - CentOS/RHEL: yum install sshpass"
			return
		fi
		sshpass -p "$password_or_key" ssh -o StrictHostKeyChecking=no -p "$port" "$user@$ip"
		if [[ $? -ne 0 ]]; then
			echo "连接失败！请检查以下内容："
			echo "1. 用户名和密码是否正确。"
			echo "2. 目标服务器是否允许密码登录。"
			echo "3. 目标服务器的 SSH 服务是否正常运行。"
		fi
	fi
}


ssh_manager() {
	send_stats "ssh远程连接工具"

	CONFIG_FILE="$HOME/.ssh_connections"
	KEY_DIR="$HOME/.ssh/ssh_manager_keys"

	# 检查配置文件和密钥目录是否存在，如果不存在则创建
	if [[ ! -f "$CONFIG_FILE" ]]; then
		touch "$CONFIG_FILE"
	fi

	if [[ ! -d "$KEY_DIR" ]]; then
		mkdir -p "$KEY_DIR"
		chmod 700 "$KEY_DIR"
	fi

	while true; do
		clear
		echo "SSH 远程连接工具"
		echo "可以通过SSH连接到其他Linux系统上"
		echo "------------------------"
		list_connections
		echo "1. 创建新连接        2. 使用连接        3. 删除连接"
		echo "------------------------"
		echo "0. 返回上一级选单"
		echo "------------------------"
		read -e -p "请输入你的选择: " choice || return 1
		case $choice in
			1) add_connection ;;
			2) use_connection ;;
			3) delete_connection ;;
			0) break ;;
			*) echo "无效的选择，请重试。" ;;
		esac
	done
}












# 列出可用的硬盘分区
list_partitions() {
	echo "可用的硬盘分区："
	lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT | grep -v "sr\|loop"
}


# 持久化挂载分区
mount_partition() {
	send_stats "挂载分区"
	read -e -p "请输入要挂载的分区名称（例如 sda1）: " PARTITION || return 1

	DEVICE="/dev/$PARTITION"
	MOUNT_POINT="/mnt/$PARTITION"

	# 检查分区是否存在
	if ! lsblk -no NAME | grep -qw "$PARTITION"; then
		echo "分区不存在！"
		return 1
	fi

	# 检查是否已挂载
	if mount | grep -qw "$DEVICE"; then
		echo "分区已经挂载！"
		return 1
	fi

	# 获取 UUID
	UUID=$(blkid -s UUID -o value "$DEVICE")
	if [ -z "$UUID" ]; then
		echo "无法获取 UUID！"
		return 1
	fi

	# 获取文件系统类型
	FSTYPE=$(blkid -s TYPE -o value "$DEVICE")
	if [ -z "$FSTYPE" ]; then
		echo "无法获取文件系统类型！"
		return 1
	fi

	# 创建挂载点
	mkdir -p "$MOUNT_POINT"

	# 挂载
	if ! mount "$DEVICE" "$MOUNT_POINT"; then
		echo "分区挂载失败！"
		rmdir "$MOUNT_POINT"
		return 1
	fi

	echo "分区已成功挂载到 $MOUNT_POINT"

	# 检查 /etc/fstab 是否已经存在 UUID 或挂载点
	if awk -v uuid="UUID=$UUID" -v point="$MOUNT_POINT" '$1 == uuid || $2 == point {found=1} END {exit !found}' /etc/fstab; then
		echo "/etc/fstab 中已存在该分区记录，跳过写入"
		return 0
	fi

	# 写入 /etc/fstab
	echo "UUID=$UUID $MOUNT_POINT $FSTYPE defaults,nofail 0 2" >> /etc/fstab

	echo "已写入 /etc/fstab，实现持久化挂载"
}


# 卸载分区
unmount_partition() {
	send_stats "卸载分区"
	read -e -p "请输入要卸载的分区名称（例如 sda1）: " PARTITION || return 1
	[[ "$PARTITION" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || return 1
	local MOUNT_POINT
	MOUNT_POINT=$(findmnt -rn -S "/dev/$PARTITION" -o TARGET)
	if [ -z "$MOUNT_POINT" ]; then
		echo "分区未挂载！"
		return
	fi

	# 卸载分区
	umount "/dev/$PARTITION"

	if [ $? -eq 0 ]; then
		echo "分区卸载成功: $MOUNT_POINT"
	else
		echo "分区卸载失败！"
		return 1
	fi
}

# 列出已挂载的分区
list_mounted_partitions() {
	echo "已挂载的分区："
	df -h | grep -v "tmpfs\|udev\|overlay"
}

# 格式化分区
format_partition() {
	send_stats "格式化分区"
	read -e -p "请输入要格式化的分区名称（例如 sda1）: " PARTITION || return 1

	# 检查分区是否存在
	if ! lsblk -o NAME | grep -w "$PARTITION" > /dev/null; then
		echo "分区不存在！"
		return
	fi

	# 检查分区是否已经挂载
	if lsblk -o MOUNTPOINT | grep -w "$PARTITION" > /dev/null; then
		echo "分区已经挂载，请先卸载！"
		return
	fi

	# 选择文件系统类型
	echo "请选择文件系统类型："
	echo "1. ext4"
	echo "2. xfs"
	echo "3. ntfs"
	echo "4. vfat"
	read -e -p "请输入你的选择: " FS_CHOICE || return 1

	case $FS_CHOICE in
		1) FS_TYPE="ext4" ;;
		2) FS_TYPE="xfs" ;;
		3) FS_TYPE="ntfs" ;;
		4) FS_TYPE="vfat" ;;
		*) echo "无效的选择！"; return ;;
	esac

	# 确认格式化
	read -e -p "确认格式化分区 /dev/$PARTITION 为 $FS_TYPE 吗？(y/n): " CONFIRM || return 1
	if [ "$CONFIRM" != "y" ]; then
		echo "操作已取消。"
		return
	fi

	# 格式化分区
	echo "正在格式化分区 /dev/$PARTITION 为 $FS_TYPE ..."
	mkfs.$FS_TYPE "/dev/$PARTITION"

	if [ $? -eq 0 ]; then
		echo "分区格式化成功！"
	else
		echo "分区格式化失败！"
	fi
}

# 检查分区状态
check_partition() {
	send_stats "检查分区状态"
	read -e -p "请输入要检查的分区名称（例如 sda1）: " PARTITION || return 1

	# 检查分区是否存在
	if ! lsblk -o NAME | grep -w "$PARTITION" > /dev/null; then
		echo "分区不存在！"
		return
	fi

	# 检查分区状态
	echo "检查分区 /dev/$PARTITION 的状态："
	fsck "/dev/$PARTITION"
}

# 主菜单
disk_manager() {
	send_stats "硬盘管理功能"
	while true; do
		clear
		echo "硬盘分区管理"
		echo -e "${gl_huang}该功能内部测试阶段，请勿在生产环境使用。${gl_bai}"
		echo "------------------------"
		list_partitions
		echo "------------------------"
		echo "1. 挂载分区        2. 卸载分区        3. 查看已挂载分区"
		echo "4. 格式化分区      5. 检查分区状态"
		echo "------------------------"
		echo "0. 返回上一级选单"
		echo "------------------------"
		read -e -p "请输入你的选择: " choice || return 1
		case $choice in
			1) mount_partition ;;
			2) unmount_partition ;;
			3) list_mounted_partitions ;;
			4) format_partition ;;
			5) check_partition ;;
			*) break ;;
		esac
		read -e -p "按回车键继续..."
	done
}




# 显示任务列表
list_tasks() {
	echo "已保存的同步任务:"
	echo "---------------------------------"
	awk -F'|' '{print NR " - " $1 " ( " $2 " -> " $3":"$4 " )"}' "$CONFIG_FILE"
	echo "---------------------------------"
}

# 添加新任务
add_task() {
	send_stats "添加新同步任务"
	echo "创建新同步任务示例："
	echo "  - 任务名称: backup_www"
	echo "  - 本地目录: /var/www"
	echo "  - 远程地址: user@192.168.1.100"
	echo "  - 远程目录: /backup/www"
	echo "  - 端口号 (默认 22)"
	echo "---------------------------------"
	read -e -p "请输入任务名称: " name || return 1
	read -e -p "请输入本地目录: " local_path || return 1
	read -e -p "请输入远程目录: " remote_path || return 1

	while true; do
		read -e -p "请输入远程用户@IP: " remote || return 1
		if kj_ssh_parse_remote "$remote" "root"; then
			remote="$KJ_SSH_REMOTE"
			break
		fi
	done

	kj_ssh_read_port "请输入 SSH 端口 (默认 22): " "22"
	port="$KJ_SSH_PORT"

	if ! kj_ssh_read_auth "$KEY_DIR/${name}_sync.key"; then
		return
	fi
	auth_method="$KJ_SSH_AUTH_METHOD"
	password_or_key="$KJ_SSH_AUTH_SECRET"

	echo "请选择同步模式:"
	echo "1. 标准模式 (-avz)"
	echo "2. 删除目标文件 (-avz --delete)"
	read -e -p "请选择 (1/2): " mode || return 1
	case $mode in
		1) options="-avz" ;;
		2) options="-avz --delete" ;;
		*) echo "无效选择，使用默认 -avz"; options="-avz" ;;
	esac

	echo "$name|$local_path|$remote|$remote_path|$port|$options|$auth_method|$password_or_key" >> "$CONFIG_FILE"

	install rsync rsync

	echo "任务已保存!"
}


# 删除任务
delete_task() {
	send_stats "删除同步任务"
	read -e -p "请输入要删除的任务编号: " num || return 1

	local task=$(sed -n "${num}p" "$CONFIG_FILE")
	if [[ -z "$task" ]]; then
		echo "错误：未找到对应的任务。"
		return
	fi

	IFS='|' read -r name local_path remote remote_path port options auth_method password_or_key <<< "$task"

	# 如果任务使用的是密钥文件，则删除该密钥文件
	if [[ "$auth_method" == "key" && "$password_or_key" == "$KEY_DIR"* ]]; then
		rm -f "$password_or_key"
	fi

	sed -i "${num}d" "$CONFIG_FILE"
	echo "任务已删除!"
}


run_task() {
	send_stats "执行同步任务"

	CONFIG_FILE="$HOME/.rsync_tasks"
	CRON_FILE="$HOME/.rsync_cron"

	# 解析参数
	local direction="push"  # 默认是推送到远端
	local num

	if [[ "$1" == "push" || "$1" == "pull" ]]; then
		direction="$1"
		num="$2"
	else
		num="$1"
	fi

	# 如果没有传入任务编号，提示用户输入
	if [[ -z "$num" ]]; then
		read -e -p "请输入要执行的任务编号: " num || return 1
	fi

	local task=$(sed -n "${num}p" "$CONFIG_FILE")
	if [[ -z "$task" ]]; then
		echo "错误: 未找到该任务!"
		return
	fi

	IFS='|' read -r name local_path remote remote_path port options auth_method password_or_key <<< "$task"

	# 根据同步方向调整源和目标路径
	if [[ "$direction" == "pull" ]]; then
		echo "正在拉取同步到本地: $remote:$local_path -> $remote_path"
		source="$remote:$local_path"
		destination="$remote_path"
	else
		echo "正在推送同步到远端: $local_path -> $remote:$remote_path"
		source="$local_path"
		destination="$remote:$remote_path"
	fi

	# 添加 SSH 连接通用参数
	local ssh_options="-p $port -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

	if [[ "$auth_method" == "password" ]]; then
		if ! command -v sshpass &> /dev/null; then
			echo "错误：未安装 sshpass，请先安装 sshpass。"
			echo "安装方法："
			echo "  - Ubuntu/Debian: apt install sshpass"
			echo "  - CentOS/RHEL: yum install sshpass"
			return
		fi
		sshpass -p "$password_or_key" rsync $options -e "ssh $ssh_options" "$source" "$destination"
	else
		# 检查密钥文件是否存在和权限是否正确
		if [[ ! -f "$password_or_key" ]]; then
			echo "错误：密钥文件不存在：$password_or_key"
			return
		fi

		if [[ "$(stat -c %a "$password_or_key")" != "600" ]]; then
			echo "警告：密钥文件权限不正确，正在修复..."
			chmod 600 "$password_or_key"
		fi

		rsync $options -e "ssh -i $password_or_key $ssh_options" "$source" "$destination"
	fi

	if [[ $? -eq 0 ]]; then
		echo "同步完成!"
	else
		echo "同步失败! 请检查以下内容："
		echo "1. 网络连接是否正常"
		echo "2. 远程主机是否可访问"
		echo "3. 认证信息是否正确"
		echo "4. 本地和远程目录是否有正确的访问权限"
	fi
}


# 创建定时任务
schedule_task() {
	send_stats "添加同步定时任务"

	read -e -p "请输入要定时同步的任务编号: " num || return 1
	if ! [[ "$num" =~ ^[0-9]+$ ]]; then
		echo "错误: 请输入有效的任务编号！"
		return
	fi

	echo "请选择定时执行间隔："
	echo "1) 每小时执行一次"
	echo "2) 每天执行一次"
	echo "3) 每周执行一次"
	read -e -p "请输入选项 (1/2/3): " interval || return 1

	local random_minute=$(shuf -i 0-59 -n 1)  # 生成 0-59 之间的随机分钟数
	local cron_time=""
	case "$interval" in
		1) cron_time="$random_minute * * * *" ;;  # 每小时，随机分钟执行
		2) cron_time="$random_minute 0 * * *" ;;  # 每天，随机分钟执行
		3) cron_time="$random_minute 0 * * 1" ;;  # 每周，随机分钟执行
		*) echo "错误: 请输入有效的选项！" ; return ;;
	esac

	local cron_job="$cron_time k rsync_run $num"
	local cron_job="$cron_time k rsync_run $num"

	# 检查是否已存在相同任务
	if crontab -l | grep -q "k rsync_run $num"; then
		echo "错误: 该任务的定时同步已存在！"
		return
	fi

	# 创建到用户的 crontab
	(crontab -l 2>/dev/null; echo "$cron_job") | crontab -
	echo "定时任务已创建: $cron_job"
}

# 查看定时任务
view_tasks() {
	echo "当前的定时任务:"
	echo "---------------------------------"
	crontab -l | grep "k rsync_run"
	echo "---------------------------------"
}

# 删除定时任务
delete_task_schedule() {
	send_stats "删除同步定时任务"
	read -e -p "请输入要删除的任务编号: " num || return 1
	if ! [[ "$num" =~ ^[0-9]+$ ]]; then
		echo "错误: 请输入有效的任务编号！"
		return
	fi

	crontab -l | grep -v "k rsync_run $num" | crontab -
	echo "已删除任务编号 $num 的定时任务"
}


# 任务管理主菜单
rsync_manager() {
	CONFIG_FILE="$HOME/.rsync_tasks"
	CRON_FILE="$HOME/.rsync_cron"

	while true; do
		clear
		echo "Rsync 远程同步工具"
		echo "远程目录之间同步，支持增量同步，高效稳定。"
		echo "---------------------------------"
		list_tasks
		echo
		view_tasks
		echo
		echo "1. 创建新任务                 2. 删除任务"
		echo "3. 执行本地同步到远端         4. 执行远端同步到本地"
		echo "5. 创建定时任务               6. 删除定时任务"
		echo "---------------------------------"
		echo "0. 返回上一级选单"
		echo "---------------------------------"
		read -e -p "请输入你的选择: " choice || return 1
		case $choice in
			1) add_task ;;
			2) delete_task ;;
			3) run_task push;;
			4) run_task pull;;
			5) schedule_task ;;
			6) delete_task_schedule ;;
			0) break ;;
			*) echo "无效的选择，请重试。" ;;
		esac
		read -e -p "按回车键继续..."
	done
}









service_status_text() {
	local service_name="$1"
	shift || true
	local unit state found=false
	if command -v systemctl >/dev/null 2>&1; then
		for unit in "$service_name" "$service_name.service" "$@"; do
			[ -z "$unit" ] && continue
			state=$(command systemctl is-active "$unit" 2>/dev/null | head -n 1)
			if [ "$state" = "active" ]; then
				echo "运行中"
				return
			fi
			if command systemctl status "$unit" 2>/dev/null | grep -q 'Active: active'; then
				echo "运行中"
				return
			fi
			if command systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q . || command systemctl status "$unit" >/dev/null 2>&1; then
				found=true
			fi
		done
		if [ "$found" = "true" ]; then
			echo "未运行"
		else
			echo "未检测到服务"
		fi
		return
	fi
	echo "无法检测"
}

sshd_effective_value() {
	local key="$1"
	local value="" sshd_bin
	value=$(sshd_config_value "$key")
	if [ -n "$value" ]; then
		normalize_ssh_bool "$value"
		return
	fi
	sshd_bin=$(sshd_bin_path)
	if [ -n "$sshd_bin" ]; then
		value=$("$sshd_bin" -T 2>/dev/null | awk -v k="$key" '$1==k {print $2; exit}')
	fi
	normalize_ssh_bool "$value"
}

sshd_bin_path() {
	local bin
	bin=$(command -v sshd 2>/dev/null || true)
	if [ -n "$bin" ]; then
		echo "$bin"
	elif [ -x /usr/sbin/sshd ]; then
		echo "/usr/sbin/sshd"
	fi
}

normalize_ssh_bool() {
	local value
	value=$(printf "%s" "$1" | tr '[:upper:]' '[:lower:]')
	case "$value" in
		yes|true|on) echo "yes" ;;
		no|false|off) echo "no" ;;
		*) echo "$1" ;;
	esac
}

sshd_config_value() {
	local key="$1" value="" locale_key
	locale_key=$(printf "%s" "$key" | tr '[:upper:]' '[:lower:]')

	_parse_sshd_config_file() {
		local file="$1" raw line first pattern inc_file
		[ -f "$file" ] || return 0
		while IFS= read -r raw || [ -n "$raw" ]; do
			line="${raw%%#*}"
			set -- $line
			[ "$#" -eq 0 ] && continue
			first=$(printf "%s" "$1" | tr '[:upper:]' '[:lower:]')
			[ "$first" = "match" ] && return 0
			if [ "$first" = "include" ]; then
				shift
				for pattern in "$@"; do
					for inc_file in $pattern; do
						[ -f "$inc_file" ] && _parse_sshd_config_file "$inc_file"
					done
				done
				continue
			fi
			if [ "$first" = "$locale_key" ] && [ "$#" -ge 2 ]; then
				value="$2"
			fi
		done < "$file"
	}

	_parse_sshd_config_file /etc/ssh/sshd_config
	if [ -z "$value" ]; then
		local inc_file
		for inc_file in /etc/ssh/sshd_config.d/*.conf; do
			[ -f "$inc_file" ] && _parse_sshd_config_file "$inc_file"
		done
	fi
	echo "$value"
}

system_info_ssh() {
	local service ports listening_ports password_auth kbd_auth pubkey_auth password_login sshd_bin
	service=$(service_status_text ssh sshd ssh.service sshd.service)
	listening_ports=$(ss -ltnp 2>/dev/null | awk '/sshd/ {p=$4; sub(/.*:/,"",p); if (p ~ /^[0-9]+$/) print p}' | sort -nu | xargs 2>/dev/null)
	if [ -n "$listening_ports" ]; then
		service="运行中"
		ports="$listening_ports"
	fi
	sshd_bin=$(sshd_bin_path)
	[ -z "$ports" ] && [ -n "$sshd_bin" ] && ports=$("$sshd_bin" -T 2>/dev/null | awk '$1=="port"{print $2}' | xargs 2>/dev/null)
	if [ -z "$ports" ]; then
		ports=$(awk 'tolower($1)=="port"{print $2}' /etc/ssh/sshd_config 2>/dev/null | xargs)
	fi
	[ -z "$ports" ] && ports="22"
	password_auth=$(sshd_effective_value passwordauthentication)
	kbd_auth=$(sshd_effective_value kbdinteractiveauthentication)
	[ -z "$kbd_auth" ] && kbd_auth=$(sshd_effective_value challengeresponseauthentication)
	pubkey_auth=$(sshd_effective_value pubkeyauthentication)
	if [ "$password_auth" = "yes" ] || [ "$kbd_auth" = "yes" ]; then
		password_login="yes"
	elif [ "$password_auth" = "no" ] || [ "$kbd_auth" = "no" ]; then
		password_login="no"
	else
		password_login="未知"
	fi
	[ -z "$pubkey_auth" ] && pubkey_auth="未知"
	echo "服务: $service | 端口: $ports | 密码登录: $password_login | 密钥登录: $pubkey_auth"
}

system_info_ufw() {
	local status
	if ! command -v ufw >/dev/null 2>&1; then
		echo "未安装"
		return
	fi
	status=$(ufw status 2>/dev/null | head -n 1 | sed 's/^Status: /状态: /')
	[ -z "$status" ] && status="已安装，状态无法读取"
	echo "$status"
}

system_info_docker() {
	local version daemon_status containers images service
	if ! command -v docker >/dev/null 2>&1; then
		echo "未安装"
		return
	fi
	version=$(docker --version 2>/dev/null | sed 's/,.*//')
	if docker info >/dev/null 2>&1; then
		daemon_status="运行中"
		containers=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
		images=$(docker images -q 2>/dev/null | wc -l | tr -d ' ')
		echo "${version:-Docker 已安装} | Daemon: $daemon_status | 运行容器: ${containers:-0} | 镜像: ${images:-0}"
	else
		service=$(service_status_text docker)
		echo "${version:-Docker 已安装} | Daemon: 不可用 | systemd: $service"
	fi
}

system_info_nginx() {
	local info service docker_nginx
	info=""
	if command -v nginx >/dev/null 2>&1; then
		info=$(nginx -v 2>&1 | sed 's#nginx version: ##')
		service=$(service_status_text nginx)
		info="${info:-Nginx 已安装} | 服务: $service"
	fi
	if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx nginx; then
		docker_nginx="Docker容器: nginx 运行中"
	fi
	if [ -n "$info" ] && [ -n "$docker_nginx" ]; then
		echo "$info | $docker_nginx"
	elif [ -n "$info" ]; then
		echo "$info"
	elif [ -n "$docker_nginx" ]; then
		echo "$docker_nginx"
	else
		echo "未安装/未检测到 nginx 容器"
	fi
}

system_info_fail2ban() {
	local service status
	if ! command -v fail2ban-client >/dev/null 2>&1 && [ ! -d /etc/fail2ban ]; then
		echo "未安装"
		return
	fi
	if fail2ban-client status >/dev/null 2>&1; then
		service="运行中"
	else
		service=$(service_status_text fail2ban)
	fi
	status=$(fail2ban-client status 2>/dev/null | awk -F: '/Jail list/{gsub(/^[ \t]+/,"",$2); print $2}')
	[ -z "$status" ] && status="无 jail 或无法读取"
	echo "服务: $service | Jail: $status"
}

system_info_rclone() {
	if ! command -v rclone >/dev/null 2>&1; then
		echo "未安装"
		return
	fi
	rclone version 2>/dev/null | head -n 1
}

system_info_bitwarden() {
	local result="" names config_status config_path
	if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
		names=$(docker ps -a --format '{{.Names}}:{{.Status}}' 2>/dev/null | grep -Ei '(vaultwarden|bitwarden)' | xargs)
		[ -n "$names" ] && result="$names"
	fi
	config_path="/var/lib/docker/volumes/vaultwarden-rclone-data/_data/rclone/rclone.conf"
	if grep -q '^\[BitwardenBackup\]' "$config_path" 2>/dev/null; then
		config_status="备份rclone配置: 已配置"
	elif [ -f "$config_path" ]; then
		config_status="备份rclone配置: 文件存在但缺少 [BitwardenBackup]"
	else
		config_status="备份rclone配置: 未配置"
	fi
	if [ -n "$result" ]; then
		echo "$result | $config_status"
	else
		echo "未检测到 vaultwarden/bitwarden 相关容器 | $config_status"
	fi
}

system_info_language() {
	local lang
	lang=$(locale 2>/dev/null | awk -F= '$1=="LANG"{print $2; exit}' | tr -d '"')
	[ -z "$lang" ] && lang="${LANG:-未知}"
	echo "$lang"
}

linux_info() {



	clear
	echo -e "${gl_kjlan}正在查询系统信息……${gl_bai}"
	send_stats "系统信息查询"

	ip_address

	local cpu_info=$(lscpu | awk -F': +' '/Model name:/ {print $2; exit}')

	local cpu_usage_percent=$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else printf "%.0f\n", (($2+$4-u1) * 100 / (t-t1))}' \
		<(grep 'cpu ' /proc/stat) <(sleep 1; grep 'cpu ' /proc/stat))

	local cpu_cores=$(nproc)

	local cpu_freq=$(cat /proc/cpuinfo | grep "MHz" | head -n 1 | awk '{printf "%.1f GHz\n", $4/1000}')

	local mem_info=$(free -b | awk 'NR==2{printf "%.2f/%.2fM (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')

	local disk_info=$(df -h | awk '$NF=="/"{printf "%s/%s (%s)", $3, $2, $5}')

	local ipinfo=$(curl -s ipinfo.io)
	local country=$(echo "$ipinfo" | grep 'country' | awk -F': ' '{print $2}' | tr -d '",')
	local city=$(echo "$ipinfo" | grep 'city' | awk -F': ' '{print $2}' | tr -d '",')
	local isp_info=$(echo "$ipinfo" | grep 'org' | awk -F': ' '{print $2}' | tr -d '",')

	local load=$(uptime | awk '{print $(NF-2), $(NF-1), $NF}')
	local dns_addresses=$(awk '/^nameserver/{printf "%s ", $2} END {print ""}' /etc/resolv.conf)


	local cpu_arch=$(uname -m)

	local hostname=$(uname -n)

	local kernel_version=$(uname -r)

	local congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
	local queue_algorithm=$(sysctl -n net.core.default_qdisc)

	local os_info=$(grep PRETTY_NAME /etc/os-release | cut -d '=' -f2 | tr -d '"')

	output_status

	local current_time=$(date "+%Y-%m-%d %I:%M %p")


	local swap_info=$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) {percentage=0} else {percentage=used*100/total}; printf "%dM/%dM (%d%%)", used, total, percentage}')

	local runtime=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d时 ", run_hours); printf("%d分\n", run_minutes)}')

	local timezone=$(current_timezone)
	local language_info=$(system_info_language)
	local ssh_info=$(system_info_ssh)
	local ufw_info=$(system_info_ufw)
	local docker_info=$(system_info_docker)
	local nginx_info=$(system_info_nginx)
	local fail2ban_info=$(system_info_fail2ban)
	local rclone_info=$(system_info_rclone)
	local bitwarden_info=$(system_info_bitwarden)

	local tcp_count=$(ss -t | wc -l)
	local udp_count=$(ss -u | wc -l)

	clear
	echo -e "系统信息查询"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}主机名:         ${gl_bai}$hostname"
	echo -e "${gl_kjlan}系统版本:       ${gl_bai}$os_info"
	echo -e "${gl_kjlan}Linux版本:      ${gl_bai}$kernel_version"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}CPU架构:        ${gl_bai}$cpu_arch"
	echo -e "${gl_kjlan}CPU型号:        ${gl_bai}$cpu_info"
	echo -e "${gl_kjlan}CPU核心数:      ${gl_bai}$cpu_cores"
	echo -e "${gl_kjlan}CPU频率:        ${gl_bai}$cpu_freq"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}CPU占用:        ${gl_bai}$cpu_usage_percent%"
	echo -e "${gl_kjlan}系统负载:       ${gl_bai}$load"
	echo -e "${gl_kjlan}TCP|UDP连接数:  ${gl_bai}$tcp_count|$udp_count"
	echo -e "${gl_kjlan}物理内存:       ${gl_bai}$mem_info"
	echo -e "${gl_kjlan}虚拟内存:       ${gl_bai}$swap_info"
	echo -e "${gl_kjlan}硬盘占用:       ${gl_bai}$disk_info"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}总接收:         ${gl_bai}$rx"
	echo -e "${gl_kjlan}总发送:         ${gl_bai}$tx"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}网络算法:       ${gl_bai}$congestion_algorithm $queue_algorithm"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}运营商:         ${gl_bai}$isp_info"
	if [ -n "$ipv4_address" ]; then
		echo -e "${gl_kjlan}IPv4地址:       ${gl_bai}$ipv4_address"
	fi

	if [ -n "$ipv6_address" ]; then
		echo -e "${gl_kjlan}IPv6地址:       ${gl_bai}$ipv6_address"
	else
		echo -e "${gl_kjlan}IPv6地址:       ${gl_bai}无"
	fi
	echo -e "${gl_kjlan}DNS地址:        ${gl_bai}$dns_addresses"
	echo -e "${gl_kjlan}地理位置:       ${gl_bai}$country $city"
	echo -e "${gl_kjlan}系统时间:       ${gl_bai}$timezone $current_time"
	echo -e "${gl_kjlan}本地语言:       ${gl_bai}$language_info"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}SSH信息:        ${gl_bai}$ssh_info"
	echo -e "${gl_kjlan}UFW状态:        ${gl_bai}$ufw_info"
	echo -e "${gl_kjlan}Docker:         ${gl_bai}$docker_info"
	echo -e "${gl_kjlan}Nginx:          ${gl_bai}$nginx_info"
	echo -e "${gl_kjlan}Fail2ban:       ${gl_bai}$fail2ban_info"
	echo -e "${gl_kjlan}rclone:         ${gl_bai}$rclone_info"
	echo -e "${gl_kjlan}Bitwarden:      ${gl_bai}$bitwarden_info"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}运行时长:       ${gl_bai}$runtime"
	echo



}







DAIMON_BBR_FQ_CONF="/etc/sysctl.d/99-daimon-bbr-fq.conf"
DAIMON_NETWORK_OPTIMIZE_CONF="/etc/sysctl.d/99-daimon-network-optimize.conf"
DAIMON_NETWORK_LEGACY_CONF="/etc/sysctl.d/99-network-optimize.conf"

daimon_network_bbr_supported() {
	modprobe tcp_bbr 2>/dev/null || true
	sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr
}

daimon_network_verify_bbr_fq() {
	[ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" = "bbr" ] &&
		[ "$(sysctl -n net.core.default_qdisc 2>/dev/null)" = "fq" ] &&
		daimon_network_verify_active_fq
}

daimon_network_verify_active_fq() {
	local interfaces iface queues
	command -v tc >/dev/null 2>&1 || { echo "缺少 tc，无法验证实际队列。" >&2; return 1; }
	interfaces=$({ ip -o -4 route show default; ip -o -6 route show default; } 2>/dev/null |
		awk '{for(i=1;i<NF;i++) if($i=="dev") print $(i+1)}' | sort -u)
	[ -n "$interfaces" ] || { echo "没有默认路由，无法验证实际队列。" >&2; return 1; }
	for iface in $interfaces; do
		queues=$(tc qdisc show dev "$iface" 2>/dev/null) || return 1
		if ! printf '%s\n' "$queues" | awk '
			$1 == "qdisc" && $2 != "ingress" && $2 != "clsact" {
				if ($0 ~ / root([[:space:]]|$)/) root=$2
				if ($0 ~ / parent /) {leaves++; if($2!="fq") other++}
			}
			END {exit !(root=="fq" || (root=="mq" && leaves>0 && other==0))}
		'; then
			echo "网卡 $iface 的实际队列不是 fq / mq+fq；未覆盖现有队列，请先确认队列配置。" >&2
			return 1
		fi
	done
}

daimon_network_verify_sysctl_file() {
	local file="$1" line key expected actual failed=0
	while IFS= read -r line || [ -n "$line" ]; do
		case "$line" in ''|'#'*) continue ;; esac
		key=${line%%=*}
		expected=${line#*=}
		key=$(printf '%s' "$key" | xargs)
		expected=$(printf '%s' "$expected" | xargs)
		actual=$(sysctl -n "$key" 2>/dev/null | xargs)
		if [ "$actual" != "$expected" ]; then
			echo -e "${gl_hong}参数验证失败: $key，期望 $expected，实际 ${actual:-不可用}${gl_bai}"
			failed=1
		fi
	done < "$file"
	[ "$failed" -eq 0 ]
}

daimon_network_show_conflicting_sysctl_configs() {
	local managed_file="$1" line key expected key_pattern match source rest line_number definition other found=0
	[ -f "$managed_file" ] || return 0
	while IFS= read -r line || [ -n "$line" ]; do
		case "$line" in ''|'#'*) continue ;; esac
		key=${line%%=*}
		expected=${line#*=}
		key=$(printf '%s' "$key" | xargs)
		expected=$(printf '%s' "$expected" | xargs)
		key_pattern=${key//./\\.}
		while IFS= read -r match; do
			source=${match%%:*}
			[ "$source" = "$managed_file" ] && continue
			rest=${match#*:}
			line_number=${rest%%:*}
			definition=${rest#*:}
			other=${definition#*=}
			other=$(printf '%s' "$other" | xargs)
			[ "$other" = "$expected" ] && continue
			if [ "$found" -eq 0 ]; then
				echo -e "${gl_huang}检测到其他 sysctl 配置定义了不同值：${gl_bai}"
			fi
			printf '  %s:%s: %s=%s（本模块=%s）\n' "$source" "$line_number" "$key" "$other" "$expected"
			found=1
		done < <(grep -HnE "^[[:space:]]*${key_pattern}[[:space:]]*=" \
			/etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null || true)
	done < "$managed_file"
	[ "$found" -eq 0 ] || echo -e "${gl_huang}上述文件可能在重启或全量重载时覆盖本模块参数；脚本不会自动修改它们。${gl_bai}"
}

daimon_network_show_other_bbr_configs() {
	local found
	found=$(grep -HnE '^[[:space:]]*net\.(ipv4\.tcp_congestion_control|core\.default_qdisc)[[:space:]]*=' \
		/etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | grep -vF "$DAIMON_BBR_FQ_CONF:" || true)
	if [ -n "$found" ]; then
		echo -e "${gl_huang}检测到其他 BBR/队列配置来源，请确认没有冲突：${gl_bai}"
		printf '%s\n' "$found"
	fi
}

daimon_network_enable_bbr_fq() {
	local tmp old_conf="" old_cc old_qdisc rollback_failed=0
	if ! daimon_network_bbr_supported; then
		echo -e "${gl_hong}当前内核不支持 BBR，未写入任何 BBR/FQ 配置。${gl_bai}"
		echo "请进入主菜单 13 的 BBR 管理，明确选择并安装适合当前系统的内核。"
		return 2
	fi
	daimon_network_verify_active_fq || return 1

	old_cc=$(sysctl -n net.ipv4.tcp_congestion_control) || return 1
	old_qdisc=$(sysctl -n net.core.default_qdisc) || return 1
	mkdir -p /etc/sysctl.d || return 1
	tmp=$(mktemp) || return 1
	if [ -f "$DAIMON_BBR_FQ_CONF" ]; then
		old_conf=$(mktemp) || { rm -f "$tmp"; return 1; }
		cp -a "$DAIMON_BBR_FQ_CONF" "$old_conf" || { rm -f "$tmp" "$old_conf"; return 1; }
	fi
	cat > "$tmp" <<'EOF'
# linux-tools-daimon BBR + FQ
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
	if command install -m 644 "$tmp" "$DAIMON_BBR_FQ_CONF" &&
		sysctl -p "$DAIMON_BBR_FQ_CONF" >/dev/null 2>&1 && daimon_network_verify_bbr_fq; then
		rm -f "$tmp" "$old_conf"
		return 0
	fi
	rm -f "$tmp"

	if [ -n "$old_conf" ]; then
		cp -a "$old_conf" "$DAIMON_BBR_FQ_CONF" || rollback_failed=1
	else
		rm -f "$DAIMON_BBR_FQ_CONF" || rollback_failed=1
	fi
	sysctl -w "net.core.default_qdisc=$old_qdisc" "net.ipv4.tcp_congestion_control=$old_cc" >/dev/null || rollback_failed=1
	[ "$(sysctl -n net.core.default_qdisc)" = "$old_qdisc" ] || rollback_failed=1
	[ "$(sysctl -n net.ipv4.tcp_congestion_control)" = "$old_cc" ] || rollback_failed=1
	if [ "$rollback_failed" -eq 0 ]; then
		rm -f "$old_conf"
		echo -e "${gl_hong}BBR + FQ 验证失败，原配置和运行态已恢复。${gl_bai}"
	else
		echo -e "${gl_hong}BBR + FQ 回滚不完整；原配置备份: ${old_conf:-无}；原算法: $old_cc；原队列: $old_qdisc${gl_bai}"
	fi
	daimon_network_show_other_bbr_configs
	return 1
}

one_click_enable_bbr_fq() {
	root_use
	local status
	daimon_network_enable_bbr_fq
	status=$?
	[ "$status" -eq 0 ] || return "$status"
	echo -e "${gl_lv}已开启 BBR + FQ 加速${gl_bai}"
	sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc 2>/dev/null || true
}

one_click_install_docker_auto() {
	root_use
	install curl
	local country mirror
	country=$(curl -s --max-time 8 ipinfo.io 2>/dev/null | grep -oE '"country"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | cut -d'"' -f4)
	[ -z "$country" ] && country=$(curl -s --max-time 5 ipinfo.io/country 2>/dev/null | tr -d '[:space:]')
	if [ "$country" = "CN" ]; then
		mirror=1
		echo "检测到国家/地区: CN，使用国内 Docker 镜像源（阿里云，失败切清华/官方）"
	else
		mirror=2
		echo "检测到国家/地区: ${country:-未知}，使用 Docker 官方源"
	fi

	mkdir -p "$DAIMON_SCRIPT_DIR"
	cat > "$DAIMON_SCRIPT_DIR/install-docker-auto.sh" <<'EOF'
#!/bin/bash
set -e
MIRROR=${1:-2}
DOCKER_OFFICIAL="https://download.docker.com"
ALIYUN_MIRROR="https://mirrors.aliyun.com/docker-ce"
TUNA_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/docker-ce"
if [ "$MIRROR" = "1" ]; then
    DOWNLOAD_URL="$ALIYUN_MIRROR"
    BACKUP_URL="$TUNA_MIRROR"
    echo "使用镜像: 阿里云 (备用: 清华)"
else
    DOWNLOAD_URL="$DOCKER_OFFICIAL"
    BACKUP_URL=""
    echo "使用镜像: Docker官方"
fi
if [ "$(id -u)" != "0" ]; then SUDO="sudo"; else SUDO=""; fi
cleanup_old() {
    echo "清理旧版本..."
    case "$DISTRO" in
        ubuntu|debian|raspbian) $SUDO apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true ;;
        centos|rhel|rocky|almalinux) $SUDO yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true ;;
        fedora) $SUDO dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine 2>/dev/null || true ;;
    esac
}
detect_distro() {
    if [ -r /etc/os-release ]; then . /etc/os-release; DISTRO=$ID; DISTRO_VERSION=$VERSION_ID
    elif [ -r /etc/debian_version ]; then DISTRO="debian"; DISTRO_VERSION=$(cat /etc/debian_version)
    elif [ -r /etc/redhat-release ]; then DISTRO="centos"
    else echo "无法检测系统"; exit 1; fi
}
get_debian_codename() {
    case "$1" in
        ubuntu) case "$DISTRO_VERSION" in 24.04) echo noble ;; 23.10) echo mantic ;; 23.04) echo lunar ;; 22.04) echo jammy ;; 20.04) echo focal ;; 18.04) echo bionic ;; *) lsb_release -cs 2>/dev/null || echo jammy ;; esac ;;
        debian|raspbian) case "${DISTRO_VERSION%%.*}" in 13) echo trixie ;; 12) echo bookworm ;; 11) echo bullseye ;; 10) echo buster ;; *) echo bookworm ;; esac ;;
    esac
}
test_url() { curl -fsSL --connect-timeout 5 "$1" >/dev/null 2>&1; }
select_mirror() {
    local gpg_path="linux/ubuntu/gpg"
    [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "raspbian" ] && gpg_path="linux/debian/gpg"
    if test_url "$DOWNLOAD_URL/$gpg_path"; then echo "镜像源可用: $DOWNLOAD_URL"; return 0
    elif [ -n "$BACKUP_URL" ] && test_url "$BACKUP_URL/$gpg_path"; then echo "主镜像不可用，切换到备用源: $BACKUP_URL"; DOWNLOAD_URL="$BACKUP_URL"; return 0
    elif [ "$MIRROR" = "1" ]; then echo "国内镜像均不可用，切换到官方源"; DOWNLOAD_URL="$DOCKER_OFFICIAL"; return 0
    else echo "无法连接到镜像源"; return 1; fi
}
install_debian() {
    local codename=$(get_debian_codename "$DISTRO") repo_distro="$DISTRO"
    [ "$DISTRO" = "raspbian" ] && repo_distro="debian"
    echo "系统: $DISTRO $DISTRO_VERSION ($codename)"
    $SUDO env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt update -y || true
    $SUDO env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        ca-certificates curl gnupg lsb-release
    $SUDO install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "$DOWNLOAD_URL/linux/$repo_distro/gpg" | $SUDO gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $DOWNLOAD_URL/linux/$repo_distro $codename stable" | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
    $SUDO env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt update -y
    $SUDO env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}
install_rhel() {
    echo "系统: $DISTRO $DISTRO_VERSION"
    $SUDO yum install -y yum-utils
    $SUDO yum-config-manager --add-repo "$DOWNLOAD_URL/linux/centos/docker-ce.repo"
    [ "$DOWNLOAD_URL" != "$DOCKER_OFFICIAL" ] && $SUDO sed -i "s|https://download.docker.com|$DOWNLOAD_URL|g" /etc/yum.repos.d/docker-ce.repo
    $SUDO yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}
install_fedora() {
    echo "系统: Fedora $DISTRO_VERSION"
    $SUDO dnf install -y dnf-plugins-core
    $SUDO dnf config-manager --add-repo "$DOWNLOAD_URL/linux/fedora/docker-ce.repo"
    [ "$DOWNLOAD_URL" != "$DOCKER_OFFICIAL" ] && $SUDO sed -i "s|https://download.docker.com|$DOWNLOAD_URL|g" /etc/yum.repos.d/docker-ce.repo
    $SUDO dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}
start_docker() { if command -v systemctl >/dev/null 2>&1; then $SUDO systemctl enable docker; $SUDO systemctl start docker; fi; }
show_result() { echo; echo "========================================"; echo "Docker 安装完成!"; echo "========================================"; docker --version; docker compose version; }
main() {
    detect_distro
    cleanup_old
    select_mirror
    case "$DISTRO" in
        ubuntu|debian|raspbian) install_debian ;;
        centos|rhel|rocky|almalinux) install_rhel ;;
        fedora) install_fedora ;;
        *) echo "不支持的系统: $DISTRO"; exit 1 ;;
    esac
    start_docker
    show_result
}
main
EOF
	chmod +x "$DAIMON_SCRIPT_DIR/install-docker-auto.sh"
	bash "$DAIMON_SCRIPT_DIR/install-docker-auto.sh" "$mirror"
	install_add_docker_cn
}

daimon_network_cleanup_old_qdisc_service() {
	if command -v systemctl >/dev/null 2>&1; then
		command systemctl disable --now daimon-network-optimize.service >/dev/null 2>&1 || true
	fi
	rm -f /etc/systemd/system/daimon-network-optimize.service /usr/local/bin/daimon-network-optimize-apply.sh
	rm -f /etc/sysctl.d/99-network-restore-before-daimon.conf
	command -v systemctl >/dev/null 2>&1 && command systemctl daemon-reload >/dev/null 2>&1 || true
}

daimon_network_apply_custom_optimize() {
	root_use
	local tmp snapshot key value actual file unsupported=0 rollback_failed=0
	daimon_network_bbr_supported || { echo "当前内核不支持 BBR，未修改配置。"; return 2; }
	daimon_network_verify_active_fq || return 1
	snapshot=$(mktemp -d) || return 1
	tmp="$snapshot/new.conf"
	for file in "$DAIMON_BBR_FQ_CONF" "$DAIMON_NETWORK_OPTIMIZE_CONF"; do
		if [ -e "$file" ]; then
			cp -a "$file" "$snapshot/$(basename "$file")" || { rm -rf "$snapshot"; return 1; }
		fi
	done
	for key in net.core.default_qdisc net.ipv4.tcp_congestion_control; do
		actual=$(sysctl -n "$key") || { rm -rf "$snapshot"; return 1; }
		printf '%s=%s\n' "$key" "$actual" >> "$snapshot/runtime.conf"
	done
	cat > "$tmp" <<'EOF'
# linux-tools-daimon custom network optimization
EOF
	while IFS='|' read -r key value; do
		[ -n "$key" ] || continue
		if actual=$(sysctl -n "$key" 2>/dev/null); then
			printf '%s=%s\n' "$key" "$value" >> "$tmp"
			printf '%s=%s\n' "$key" "$actual" >> "$snapshot/runtime.conf"
		else
			echo -e "${gl_huang}跳过当前内核不支持的参数: $key${gl_bai}"
			unsupported=$((unsupported + 1))
		fi
	done <<'EOF'
net.core.rmem_max|134217728
net.core.wmem_max|134217728
net.core.netdev_max_backlog|300000
net.ipv4.tcp_rmem|4096 131072 134217728
net.ipv4.tcp_wmem|4096 131072 134217728
fs.file-max|2097152
net.ipv4.tcp_tw_reuse|1
net.ipv4.tcp_fastopen|3
net.ipv4.tcp_window_scaling|1
net.ipv4.tcp_max_syn_backlog|262144
net.core.somaxconn|65535
net.ipv4.ip_local_port_range|1024 65535
vm.swappiness|10
net.ipv4.tcp_slow_start_after_idle|0
net.ipv4.tcp_limit_output_bytes|4194304
net.ipv4.tcp_mtu_probing|1
EOF
	if ! daimon_network_enable_bbr_fq ||
		! command install -m 644 "$tmp" "$DAIMON_NETWORK_OPTIMIZE_CONF" ||
		! sysctl -p "$DAIMON_NETWORK_OPTIMIZE_CONF" >/dev/null ||
		! daimon_network_verify_sysctl_file "$DAIMON_NETWORK_OPTIMIZE_CONF" ||
		! daimon_network_verify_bbr_fq; then
		for file in "$DAIMON_BBR_FQ_CONF" "$DAIMON_NETWORK_OPTIMIZE_CONF"; do
			if [ -f "$snapshot/$(basename "$file")" ]; then
				cp -a "$snapshot/$(basename "$file")" "$file" || rollback_failed=1
			else
				rm -f "$file" || rollback_failed=1
			fi
		done
		sysctl -p "$snapshot/runtime.conf" >/dev/null || rollback_failed=1
		daimon_network_verify_sysctl_file "$snapshot/runtime.conf" || rollback_failed=1
		if [ "$rollback_failed" -eq 0 ]; then
			rm -rf "$snapshot"
			echo -e "${gl_hong}网络优化失败，原配置和运行态参数已恢复。${gl_bai}"
		else
			echo -e "${gl_hong}网络优化失败且回滚不完整，快照保留在: $snapshot${gl_bai}"
		fi
		return 1
	fi
	rm -rf "$snapshot"
	rm -f "$DAIMON_NETWORK_LEGACY_CONF"
	echo -e "${gl_lv}自定义网络优化已应用。只写入 sysctl 参数，配置文件: $DAIMON_NETWORK_OPTIMIZE_CONF${gl_bai}"
	[ "$unsupported" -gt 0 ] && echo -e "${gl_huang}已自适应跳过 $unsupported 个不受支持的参数。${gl_bai}"
	daimon_network_show_conflicting_sysctl_configs "$DAIMON_NETWORK_OPTIMIZE_CONF"
	send_stats "自定义网络优化"
}

daimon_network_show_custom_status() {
	local key
	echo "内核版本: $(uname -r)"
	if daimon_network_bbr_supported; then
		echo -e "BBR 内核支持: ${gl_lv}支持${gl_bai}"
	else
		echo -e "BBR 内核支持: ${gl_hong}不支持${gl_bai}"
	fi
	echo "sysctl 配置："
	for key in \
		net.core.default_qdisc \
		net.ipv4.tcp_congestion_control \
		net.core.rmem_max \
		net.core.wmem_max \
		net.core.netdev_max_backlog \
		net.ipv4.tcp_rmem \
		net.ipv4.tcp_wmem \
		fs.file-max \
		net.ipv4.tcp_tw_reuse \
		net.ipv4.tcp_fastopen \
		net.ipv4.tcp_window_scaling \
		net.ipv4.tcp_max_syn_backlog \
		net.core.somaxconn \
		net.ipv4.ip_local_port_range \
		vm.swappiness \
		net.ipv4.tcp_slow_start_after_idle \
		net.ipv4.tcp_limit_output_bytes \
		net.ipv4.tcp_mtu_probing
	do
		printf "  %-38s %s\n" "$key" "$(sysctl -n "$key" 2>/dev/null || echo 未支持)"
	done
	echo "实际网卡队列："
	tc qdisc show 2>/dev/null || echo "  无法读取（需要 tc）"
	echo "------------------------------------------------"
	echo "BBR 模块信息："
	modinfo tcp_bbr 2>/dev/null | grep -E '^(filename|version|description):' || echo "  未检测到 tcp_bbr 模块信息"
	echo "------------------------------------------------"
	if [ -f "$DAIMON_BBR_FQ_CONF" ]; then
		echo -e "BBR/FQ 配置: ${gl_lv}已安装${gl_bai} ($DAIMON_BBR_FQ_CONF)"
	else
		echo -e "BBR/FQ 配置: ${gl_hui}未由 daimon 管理${gl_bai}"
	fi
	if [ -f "$DAIMON_NETWORK_OPTIMIZE_CONF" ]; then
		echo -e "自定义优化配置: ${gl_lv}已安装${gl_bai} ($DAIMON_NETWORK_OPTIMIZE_CONF)"
	else
		echo -e "自定义优化配置: ${gl_hui}未安装${gl_bai}"
	fi
	daimon_network_show_other_bbr_configs
	daimon_network_show_conflicting_sysctl_configs "$DAIMON_NETWORK_OPTIMIZE_CONF"
}

daimon_network_clear_custom_optimize() {
	root_use
	daimon_network_cleanup_old_qdisc_service
	rm -f "$DAIMON_NETWORK_OPTIMIZE_CONF" "$DAIMON_NETWORK_LEGACY_CONF"
	sysctl --system >/dev/null 2>&1 || true
	echo "已清除自定义网络优化配置，BBR/FQ 保持不变；其他运行态参数可能需要重启后恢复系统默认值。"
	send_stats "清除自定义网络优化"
}

one_click_network_auto_optimize() {
	daimon_network_apply_custom_optimize
}

one_click_auto_dns_optimize() {
	root_use
	local country
	country=$(daimon_country)
	if [ "$country" = "CN" ]; then
		local dns1_ipv4="223.5.5.5"
		local dns2_ipv4="119.29.29.29"
		local dns1_ipv6="2400:3200::1"
		local dns2_ipv6="2402:4e00::"
		echo "检测到国家/地区: CN，自动使用国内 DNS 优化"
		set_dns
		send_stats "一键国内DNS优化"
	else
		local dns1_ipv4="1.1.1.1"
		local dns2_ipv4="8.8.8.8"
		local dns1_ipv6="2606:4700:4700::1111"
		local dns2_ipv6="2001:4860:4860::8888"
		echo "检测到国家/地区: ${country:-未知}，自动使用国外 DNS 优化"
		set_dns
		send_stats "一键国外DNS优化"
	fi
}

one_click_set_timezone_locale() {
	root_use
	set_timedate Asia/Shanghai
	update_locale "en_US.UTF-8" "en_US.UTF-8" false
	echo "已设置时区为 Asia/Shanghai，本地语言为 en_US.UTF-8"
	send_stats "一键配置时区和本地语言"
}

one_click_config_manager() {
	one_click_config_run_item() {
		export DEBIAN_FRONTEND=noninteractive
		export NEEDRESTART_MODE=a
		export APT_LISTCHANGES_FRONTEND=none
		case "$1" in
			2) linux_update ;;
			3) linux_clean ;;
			4) add_swap 1024 ;;
			5) one_click_auto_dns_optimize ;;
			6) one_click_enable_bbr_fq ;;
			7) one_click_install_docker_auto ;;
			8) one_click_network_auto_optimize ;;
			9) linux_tools thirdparty-install-all ;;
			10) one_click_set_timezone_locale ;;
			*) echo "跳过无效编号: $1" ;;
		esac
	}

	one_click_config_run_all() {
		local nums n failed=0 DAIMON_DEFER_SHELL_RESTART=1
		export DEBIAN_FRONTEND=noninteractive
		export NEEDRESTART_MODE=a
		export APT_LISTCHANGES_FRONTEND=none
		nums="2 3 4 5 6 7 8 9 10"
		read -e -i "$nums" -p "请确认/修改要执行的配置编号（默认全选，空格分隔）: " nums || return 1
		if [ -z "$nums" ]; then
			echo "未选择任何配置项"
			return
		fi
		for n in $nums; do
			one_click_config_run_item "$n" || { echo "配置项 $n 执行失败"; failed=1; }
		done
		return "$failed"
	}

	while true; do
		clear
		echo "一键配置"
		echo "------------------------"
		echo -e "${gl_kjlan}1.   ${gl_bai}配置全部（默认回车，执行前可删减编号）"
		echo -e "${gl_kjlan}2.   ${gl_bai}系统更新"
		echo -e "${gl_kjlan}3.   ${gl_bai}系统清理"
		echo -e "${gl_kjlan}4.   ${gl_bai}设置虚拟内存 1G"
		echo -e "${gl_kjlan}5.   ${gl_bai}优化 DNS 地址"
		echo -e "${gl_kjlan}6.   ${gl_bai}开启 BBR 加速（BBR + FQ）"
		echo -e "${gl_kjlan}7.   ${gl_bai}安装 Docker（自动判断国内/国外源）"
		echo -e "${gl_kjlan}8.   ${gl_bai}应用自定义网络优化"
		echo -e "${gl_kjlan}9.   ${gl_bai}安装第三方工具（全部安装，可在第三方工具菜单精细调整）"
		echo -e "${gl_kjlan}10.  ${gl_bai}修改时区和本地语言（Asia/Shanghai + en_US.UTF-8）"
		echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
		echo "------------------------"
		read -e -p "请输入你的选择（默认 1 配置全部）: " sub_choice || return 1
		case "$sub_choice" in
			""|1) one_click_config_run_all ;;
			2|3|4|5|6|7|8|9|10) one_click_config_run_item "$sub_choice" ;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}



# ===== system tools restored helper functions =====
create_user_with_sshkey() {
	local new_username="$1"
	local is_sudo="${2:-false}"
	local sshkey_vl

	if [ -z "$new_username" ]; then
		echo "用法：create_user_with_sshkey <用户名> [true|false]"
		return 1
	fi
	[[ "$new_username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { echo "用户名格式无效"; return 1; }

	if id "$new_username" >/dev/null 2>&1; then
		echo "用户已存在: $new_username"
	else
		useradd -m -s /bin/bash "$new_username" || return 1
		echo "已创建用户: $new_username"
	fi

	if [ "$is_sudo" = "true" ]; then
		install sudo
		usermod -aG sudo "$new_username" 2>/dev/null || true
		cat > "/etc/sudoers.d/$new_username" <<EOF
$new_username ALL=(ALL) NOPASSWD:ALL
EOF
		chmod 440 "/etc/sudoers.d/$new_username"
		echo "已赋予 sudo 免密权限: $new_username"
	fi

	echo "导入公钥示例："
	echo "  URL：      ${gh_https_url}github.com/torvalds.keys"
	echo "  直接粘贴： ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
	read -e -p "请输入 ${new_username} 的公钥（可留空跳过）: " sshkey_vl || return 1
	[ -z "$sshkey_vl" ] && return 0

	local user_home="/home/$new_username"
	mkdir -p "$user_home/.ssh"
	chmod 700 "$user_home/.ssh"
	case "$sshkey_vl" in
		http://*|https://*)
			send_stats "从 URL 导入 SSH 公钥"
			fetch_remote_ssh_keys "$sshkey_vl" "$user_home"
			;;
		ssh-rsa*|ssh-ed25519*|ssh-ecdsa*)
			send_stats "公钥直接导入"
			grep -qxF "$sshkey_vl" "$user_home/.ssh/authorized_keys" 2>/dev/null || echo "$sshkey_vl" >> "$user_home/.ssh/authorized_keys"
			;;
		*)
			echo "公钥格式不正确，已跳过导入"
			;;
	esac
	chmod 600 "$user_home/.ssh/authorized_keys" 2>/dev/null || true
	chown -R "$new_username:$new_username" "$user_home/.ssh"
}

env_menu() {
	local bashrc_file="$HOME/.bashrc"
	local profile_file="$HOME/.profile"

	show_env_vars() {
		clear
		echo "当前已生效环境变量（节选）"
		echo "------------------------------------------------"
		printf "%-20s %s\n" "变量名" "值"
		for v in USER HOME SHELL LANG PWD EDITOR VISUAL PATH; do
			printf "%-20s %s\n" "$v" "${!v}"
		done
		echo "------------------------------------------------"
		echo "~/.bashrc 中 export 项："
		grep -n '^export ' "$bashrc_file" 2>/dev/null || echo "无"
		echo "------------------------------------------------"
		echo "~/.profile 中 export 项："
		grep -n '^export ' "$profile_file" 2>/dev/null || echo "无"
	}

	add_env_var() {
		local name value target
		read -e -p "变量名（如 JAVA_HOME）: " name || return 1
		[ -z "$name" ] && return
		read -e -p "变量值: " value || return 1
		echo "1. 写入 ~/.bashrc（默认）"
		echo "2. 写入 ~/.profile"
		read -e -p "请选择写入位置: " target || return 1
		local file="$bashrc_file"
		[ "$target" = "2" ] && file="$profile_file"
		touch "$file"
		sed -i "/^export ${name}=/d" "$file"
		echo "export ${name}=\"${value}\"" >> "$file"
		source "$file" >/dev/null 2>&1 || true
		export "$name=$value"
		echo "已写入并尝试重新加载: $file"
	}

	delete_env_var() {
		local name
		read -e -p "请输入要删除的变量名: " name || return 1
		[ -z "$name" ] && return
		sed -i "/^export ${name}=/d" "$bashrc_file" "$profile_file" 2>/dev/null || true
		unset "$name"
		[ -f "$bashrc_file" ] && source "$bashrc_file" >/dev/null 2>&1 || true
		[ -f "$profile_file" ] && source "$profile_file" >/dev/null 2>&1 || true
		echo "已删除变量配置并尝试重新加载: $name"
	}

	while true; do
		clear
		echo "系统变量管理工具"
		echo "------------------------------------------------"
		echo "1. 查看当前环境变量"
		echo "2. 添加/修改环境变量"
		echo "3. 删除环境变量"
		echo "0. 返回上一级选单"
		echo "------------------------------------------------"
		read -e -p "请输入你的选择: " choice || return 1
		case "$choice" in
			1) show_env_vars ;;
			2) add_env_var ;;
			3) delete_env_var ;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}

github_proxy_sources_file() {
	echo "${DAIMON_SCRIPT_DIR:-/root/linux-daimon/daimon}/github_proxy_sources.txt"
}

github_proxy_init_sources() {
	local file
	file=$(github_proxy_sources_file)
	mkdir -p "$(dirname "$file")" >/dev/null 2>&1 || true
	if [ ! -s "$file" ] || grep -Eq 'raw.githubusercontent.com\||ghproxy.homeboyc.cn|github.akams.cn' "$file"; then
		cat > "$file" <<'EOF'
gh-proxy.com|https://gh-proxy.com/https://raw.githubusercontent.com/komari-monitor/komari-agent/main/install.sh
ghproxy.net|https://ghproxy.net/https://raw.githubusercontent.com/komari-monitor/komari-agent/main/install.sh
testingcf.jsdelivr.net|https://testingcf.jsdelivr.net/gh/komari-monitor/komari-agent@main/install.sh
ghfast.top|https://ghfast.top/https://raw.githubusercontent.com/komari-monitor/komari-agent/main/install.sh
EOF
	fi
}

github_proxy_show_sources() {
	github_proxy_init_sources
	local file idx=1 name url
	file=$(github_proxy_sources_file)
	while IFS='|' read -r name url; do
		[ -z "$name" ] && continue
		printf "%2d. %-24s %s\n" "$idx" "$name" "$url"
		idx=$((idx + 1))
	done < "$file"
}

github_proxy_add_source() {
	github_proxy_init_sources
	local name url file
	file=$(github_proxy_sources_file)
	read -e -p "请输入镜像名称: " name || return 1
	read -e -p "请输入测速URL: " url || return 1
	[ -z "$name" ] || [ -z "$url" ] && echo "名称和URL不能为空" && return 1
	sed -i "/^${name//\//\\/}|/d" "$file"
	echo "$name|$url" >> "$file"
	echo "已添加: $name"
}

github_proxy_delete_source() {
	github_proxy_init_sources
	local file num tmp
	file=$(github_proxy_sources_file)
	github_proxy_show_sources
	read -e -p "请输入要删除的编号: " num || return 1
	[[ "$num" =~ ^[0-9]+$ ]] || return 1
	tmp=$(mktemp)
	awk -F'|' -v n="$num" 'NF && ++i != n {print}' "$file" > "$tmp"
	cat "$tmp" > "$file"
	rm -f "$tmp"
	echo "已删除编号: $num"
}

github_proxy_speed_test() {
	github_proxy_init_sources
	local file out idx name url tmp result http_code time_total speed size
	file=$(github_proxy_sources_file)
	out="/tmp/daimon_github_proxy_speed.txt"
	: > "$out"
	echo "开始测速 GitHub 镜像源（小文件、短超时，下载后自动删除）..."
	idx=0
	while IFS='|' read -r name url; do
		[ -z "$name" ] && continue
		idx=$((idx + 1))
		tmp="/tmp/daimon_github_proxy_${idx}.tmp"
		echo "== Testing: $name"
		result=$(curl -L --connect-timeout 5 --max-time 15 --retry 0 -o "$tmp" -w "%{http_code} %{time_total} %{speed_download} %{size_download}" -s "$url")
		http_code=$(echo "$result" | awk '{print $1}')
		time_total=$(echo "$result" | awk '{print $2}')
		speed=$(echo "$result" | awk '{print $3}')
		size=$(echo "$result" | awk '{print $4}')
		if [ "$http_code" = "200" ] && [ "${size:-0}" -gt 1000 ]; then
			printf "%s\t%s\t%s\t%s\t%s\n" "$speed" "$time_total" "$size" "$http_code" "$name" >> "$out"
			echo "OK  HTTP:$http_code  TIME:${time_total}s  SPEED:${speed}B/s  SIZE:${size}B"
		else
			printf "0\t%s\t%s\t%s\t%s\n" "$time_total" "$size" "$http_code" "$name" >> "$out"
			echo "FAIL  HTTP:$http_code  TIME:${time_total}s  SIZE:${size}B"
		fi
		rm -f "$tmp"
	done < "$file"
	echo "------------------------------------------------"
	echo "Speed ranking:"
	sort -nr "$out" | awk -F '\t' 'BEGIN{printf "%-4s %-28s %-12s %-10s %-10s %-8s\n","Rank","Proxy","Speed","Time","Size","HTTP"}{s=$1; if(s>=1048576){sf=sprintf("%.2f MB/s",s/1048576)}else if(s>=1024){sf=sprintf("%.2f KB/s",s/1024)}else{sf=sprintf("%.0f B/s",s)} printf "%-4d %-28s %-12s %-10ss %-10s %-8s\n",NR,$5,sf,$2,$3,$4}'
	rm -f "$out"
}

github_proxy_manager() {
	while true; do
		clear
		echo "github镜像源"
		echo "------------------------------------------------"
		echo "当前镜像源列表："
		github_proxy_show_sources
		echo "------------------------------------------------"
		echo "1. 添加镜像源"
		echo "2. 删除镜像源"
		echo "3. 测速"
		echo "0. 返回上一级选单"
		echo "------------------------------------------------"
		read -e -p "请输入你的选择: " choice || return 1
		case "$choice" in
			1) github_proxy_add_source ;;
			2) github_proxy_delete_source ;;
			3) github_proxy_speed_test ;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}

show_ssh_ip_info() {
	clear
	send_stats "查看ssh的ip"
	echo "查看ssh的ip"
	echo "------------------------------------------------"
	local current_ip="" current_port=""
	if [ -n "$SSH_CONNECTION" ]; then
		current_ip=$(echo "$SSH_CONNECTION" | awk '{print $1}')
		current_port=$(echo "$SSH_CONNECTION" | awk '{print $2}')
	elif [ -n "$SSH_CLIENT" ]; then
		current_ip=$(echo "$SSH_CLIENT" | awk '{print $1}')
		current_port=$(echo "$SSH_CLIENT" | awk '{print $2}')
	else
		current_ip=$(who am i 2>/dev/null | awk -F'[()]' '{print $2}' | awk '{print $1}')
	fi

	echo "当前 SSH 连接IP："
	if [ -n "$current_ip" ]; then
		[ -n "$current_port" ] && echo "  $current_ip:$current_port" || echo "  $current_ip"
	else
		echo "  未检测到当前 SSH 连接IP（可能不是通过 SSH 登录）"
	fi

	echo "------------------------------------------------"
	echo "所有 SSH 连接地址："
	if command -v ss >/dev/null 2>&1; then
		ss -tnp 2>/dev/null | awk 'NR==1 || /sshd/ {print}' || true
	else
		netstat -tnp 2>/dev/null | awk 'NR==1 || /sshd/ {print}' || true
	fi
}

net_menu() {
	show_nics() {
		local path nic state ipaddr mac
		echo "================ 当前网卡信息 ================"
		printf "%-18s %-12s %-22s %-20s\n" "网卡名" "状态" "IPv4地址" "MAC地址"
		echo "------------------------------------------------"
		for path in /sys/class/net/*; do
			[ -e "$path" ] || continue
			nic=${path##*/}
			state=$(cat "/sys/class/net/$nic/operstate" 2>/dev/null)
			ipaddr=$(ip -4 addr show "$nic" 2>/dev/null | awk '/inet /{print $2}' | head -n1)
			mac=$(cat "/sys/class/net/$nic/address" 2>/dev/null)
			printf "%-18s %-12s %-22s %-20s\n" "$nic" "$state" "${ipaddr:-无}" "$mac"
		done
		echo "================================================"
	}
	while true; do
		clear
		show_nics
		echo ""
		echo "=========== 网卡管理菜单 ==========="
		echo "1. 启用网卡"
		echo "2. 禁用网卡"
		echo "3. 查看网卡详细信息"
		echo "4. 刷新网卡信息"
		echo "0. 返回上一级选单"
		echo "===================================="
		read -e -p "请输入你的选择: " choice || return 1
		case "$choice" in
			1) read -e -p "请输入网卡名: " nic || return 1; [ -n "$nic" ] && ip link set "$nic" up ;;
			2) read -e -p "请输入网卡名: " nic || return 1; [ -n "$nic" ] && ip link set "$nic" down ;;
			3) read -e -p "请输入网卡名: " nic || return 1; [ -n "$nic" ] && { ip addr show "$nic"; echo; ethtool "$nic" 2>/dev/null || true; } ;;
			4) continue ;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}

journalctl_log_manager() {
	root_use
	send_stats "journalctl日志管理"
	while true; do
		clear
		echo "journalctl日志管理"
		echo "------------------------------------------------"
		echo "1. 配置自动清理（默认最多500M、保留1G空闲、单文件50M、保留1个月）"
		echo "2. 查看日志磁盘占用大小"
		echo "3. 查看某服务的日志（最后200条）"
		echo "4. 按时间保留日志（默认7天）"
		echo "5. 按大小保留日志（默认500M）"
		echo "0. 返回上一级菜单"
		echo "------------------------------------------------"
		read -e -p "请输入你的选择: " choice || return 1
		case "$choice" in
			1)
				local system_max_use system_keep_free system_max_file_size max_retention_sec
				read -e -p "SystemMaxUse 最大总占用（默认 500M）: " system_max_use || return 1
				system_max_use=${system_max_use:-500M}
				read -e -p "SystemKeepFree 系统至少保留空闲空间（默认 1G）: " system_keep_free || return 1
				system_keep_free=${system_keep_free:-1G}
				read -e -p "SystemMaxFileSize 单个 journal 文件最大大小（默认 50M）: " system_max_file_size || return 1
				system_max_file_size=${system_max_file_size:-50M}
				read -e -p "MaxRetentionSec 最长保留时间（默认 1month）: " max_retention_sec || return 1
				max_retention_sec=${max_retention_sec:-1month}
				mkdir -p /etc/systemd/journald.conf.d
				cat > /etc/systemd/journald.conf.d/99-daimon-journal.conf <<EOF
[Journal]
SystemMaxUse=$system_max_use
SystemKeepFree=$system_keep_free
SystemMaxFileSize=$system_max_file_size
MaxRetentionSec=$max_retention_sec
EOF
				systemctl restart systemd-journald 2>/dev/null || service systemd-journald restart 2>/dev/null || true
				echo "已写入 /etc/systemd/journald.conf.d/99-daimon-journal.conf"
				;;
			2) journalctl --disk-usage ;;
			3) read -e -p "请输入服务名（可不带 .service）: " svc || return 1; [ -z "$svc" ] && continue; [[ "$svc" != *.service ]] && svc="$svc.service"; journalctl -u "$svc" -n 200 --no-pager ;;
			4) read -e -p "保留时间（默认 7d）: " t || return 1; journalctl --vacuum-time="${t:-7d}" ;;
			5) read -e -p "保留大小（默认 500M）: " z || return 1; journalctl --vacuum-size="${z:-500M}" ;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}

system_network_auto_optimize() {
	root_use
	local status open_bbr
	while true; do
		clear
		echo "系统网络自适应优化"
		echo "------------------------------------------------"
		echo -e "当前内核版本: ${gl_huang}$(uname -r)${gl_bai}"
		echo -e "当前拥塞算法: ${gl_huang}$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 未知)${gl_bai}"
		echo -e "当前队列算法: ${gl_huang}$(sysctl -n net.core.default_qdisc 2>/dev/null || echo 未知)${gl_bai}"
		if daimon_network_bbr_supported; then
			echo -e "BBR 内核支持: ${gl_lv}支持，无需安装新内核${gl_bai}"
		else
			echo -e "BBR 内核支持: ${gl_hong}不支持，需要通过 BBR 管理安装兼容内核${gl_bai}"
		fi
		if [ -f "$DAIMON_NETWORK_OPTIMIZE_CONF" ]; then
			echo -e "自定义优化配置: ${gl_lv}已安装${gl_bai} ($DAIMON_NETWORK_OPTIMIZE_CONF)"
		else
			echo -e "自定义优化配置: ${gl_hui}未安装${gl_bai}"
		fi
		echo "------------------------------------------------"
		echo "说明：优先使用当前内核；支持 BBR 时无需换内核，不支持时可进入 BBR 管理选择内核。"
		echo "参数配置: $DAIMON_NETWORK_OPTIMIZE_CONF"
		echo "------------------------------------------------"
		echo "1. 应用自定义网络优化"
		echo "2. 查看当前网络优化状态"
		echo "3. 清除自定义网络优化"
		echo "0. 返回上一级菜单"
		echo "------------------------------------------------"
		read -e -p "请输入你的选择: " choice || return 1
		case "$choice" in
			1)
				daimon_network_apply_custom_optimize
				status=$?
				if [ "$status" -eq 2 ]; then
					read -e -p "是否进入 BBR 管理选择兼容内核？[y/N]: " open_bbr || return 1
					case "$open_bbr" in [Yy]) linux_bbr ;; esac
				fi
				;;
			2) daimon_network_show_custom_status ;;
			3) daimon_network_clear_custom_optimize ;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}

system_ipv6_status() {
	echo "------------------------------------------------"
	echo "IPv6 当前状态："
	sysctl net.ipv6.conf.all.disable_ipv6 net.ipv6.conf.default.disable_ipv6 net.ipv6.conf.lo.disable_ipv6 2>/dev/null || true
	ip -6 addr show scope global 2>/dev/null | awk '/inet6/{print "  "$2" "$NF}' || true
}

system_disable_ipv6() {
	root_use
	local CONF="/etc/sysctl.d/99-daimon-ipv6.conf"
	[ -f "$CONF" ] && cp "$CONF" "${CONF}.bak.$(date +%Y%m%d%H%M%S)"
	cat > "$CONF" <<'EOF'
# linux-tools-daimon IPv6 配置：禁用 IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
	sysctl -p "$CONF" >/dev/null 2>&1 || sysctl --system >/dev/null 2>&1
	for f in /proc/sys/net/ipv6/conf/*/disable_ipv6; do [ -e "$f" ] && echo 1 > "$f" 2>/dev/null || true; done
	echo -e "${gl_lv}IPv6 已禁用。配置文件: $CONF${gl_bai}"
	system_ipv6_status
	send_stats "禁用IPv6"
}

system_enable_ipv6() {
	root_use
	local CONF="/etc/sysctl.d/99-daimon-ipv6.conf"
	[ -f "$CONF" ] && cp "$CONF" "${CONF}.bak.$(date +%Y%m%d%H%M%S)"
	cat > "$CONF" <<'EOF'
# linux-tools-daimon IPv6 配置：开启 IPv6
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
EOF
	sysctl -p "$CONF" >/dev/null 2>&1 || sysctl --system >/dev/null 2>&1
	for f in /proc/sys/net/ipv6/conf/*/disable_ipv6; do [ -e "$f" ] && echo 0 > "$f" 2>/dev/null || true; done
	echo -e "${gl_lv}IPv6 已开启。配置文件: $CONF${gl_bai}"
	system_ipv6_status
	send_stats "开启IPv6"
}

cpcat_manager() {
	while true; do
		clear
		local bashrc_file="$HOME/.bashrc"
		local cpcat_status="${gl_hong}未配置${gl_bai}"
		if [ -f "$bashrc_file" ] && grep -q '^# ========== cpcat clipboard setup ==========$' "$bashrc_file"; then
			cpcat_status="${gl_lv}已配置${gl_bai}"
		fi
		echo "配置/删除cpcat"
		echo "------------------------------------------------"
		echo -e "当前状态: $cpcat_status"
		echo "功能说明: cpcat 文件路径，可通过 OSC 52 快速复制文件内容到剪贴板"
		echo "示例: cpcat /root/test.txt"
		echo "------------------------------------------------"
		echo "1. 配置 cpcat 到 ~/.bashrc"
		echo "2. 删除 ~/.bashrc 中的 cpcat 配置"
		echo "0. 返回上一级菜单"
		echo "------------------------------------------------"
		read -e -p "请输入你的选择: " cpcat_choice || return 1
		case "$cpcat_choice" in
			1)
				local tmp_file
				touch "$bashrc_file"
				tmp_file=$(mktemp)
				awk '/^# ========== cpcat clipboard setup ==========$/ {skip=1; next} /^[[:space:]]*# ========== end cpcat clipboard setup ==========$/ {skip=0; next} !skip {print}' "$bashrc_file" > "$tmp_file"
				cat "$tmp_file" > "$bashrc_file"
				rm -f "$tmp_file"
				cat >> "$bashrc_file" <<'EOF'

# ========== cpcat clipboard setup ==========
# 一键复制文件内容到剪贴板
cpcat() {
    if [ -f "$1" ]; then
        printf "\033]52;c;$(base64 < "$1" | tr -d '\n')\a"
        echo "✅ 已复制到剪贴板: $1"
    else
        echo "❌ 文件不存在: $1"
    fi
}
# ========== end cpcat clipboard setup ==========
EOF
				source "$bashrc_file" >/dev/null 2>&1 || true
				echo "已配置 cpcat。已执行 source ~/.bashrc。"
				;;
			2)
				[ -f "$bashrc_file" ] || { echo "~/.bashrc 不存在"; break_end; continue; }
				local tmp_file
				tmp_file=$(mktemp)
				awk '/^# ========== cpcat clipboard setup ==========$/ {skip=1; next} /^[[:space:]]*# ========== end cpcat clipboard setup ==========$/ {skip=0; next} !skip {print}' "$bashrc_file" > "$tmp_file"
				cat "$tmp_file" > "$bashrc_file"
				rm -f "$tmp_file"
				source "$bashrc_file" >/dev/null 2>&1 || true
				echo "已删除 cpcat 配置。"
				;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}
# ===== end system tools restored helper functions =====


daimon_shortcut_available() {
	local name="$1" path
	[[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,31}$ ]] || return 1
	for path in "/usr/local/bin/$name" "/usr/bin/$name"; do
		if [ -e "$path" ] || [ -L "$path" ]; then
			[ "$(readlink -f -- "$path")" = /usr/local/bin/d ] || return 1
		fi
	done
}

daimon_regular_user_valid() {
	local uid
	[[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || return 1
	uid=$(id -u -- "$1" 2>/dev/null) || return 1
	[[ "$uid" =~ ^[0-9]+$ ]] && [ "$uid" -ge 1000 ] && [ "$uid" -ne 65534 ]
}

linux_Settings() {
	while true; do
		clear
		echo -e "系统工具"
		echo -e "${gl_kjlan}------------------------"
		# 使用 ANSI 光标定位对齐第二列，避免中文宽字符导致空格补齐不稳定
		printf "%b\033[55G%b\n" "${gl_kjlan}1.   ${gl_bai}设置脚本启动快捷键" "${gl_kjlan}2.   ${gl_bai}更换系统软件包镜像源"
		printf "%b\033[55G%b\n" "${gl_kjlan}3.   ${gl_bai}优化DNS地址" "${gl_kjlan}4.   ${gl_bai}切换优先ipv4/ipv6"
		printf "%b\033[55G%b\n" "${gl_kjlan}5.   ${gl_bai}修改虚拟内存大小" "${gl_kjlan}6.   ${gl_bai}用户管理"
		printf "%b\033[55G%b\n" "${gl_kjlan}7.   ${gl_bai}系统时区调整" "${gl_kjlan}8.   ${gl_bai}修改主机名"
		printf "%b\033[55G%b\n" "${gl_kjlan}9.   ${gl_bai}本机host解析" "${gl_kjlan}10.  ${gl_bai}系统变量管理工具"
		printf "%b\033[55G%b\n" "${gl_kjlan}11.  ${gl_bai}github镜像源" "${gl_kjlan}12.  ${gl_bai}查看ssh的ip"
		printf "%b\033[55G%b\n" "${gl_kjlan}13.  ${gl_bai}网卡管理工具" "${gl_kjlan}14.  ${gl_bai}journalctl日志管理"
		printf "%b\033[55G%b\n" "${gl_kjlan}15.  ${gl_bai}系统网络自适应优化" "${gl_kjlan}16.  ${gl_bai}禁用IPv6"
		printf "%b\033[55G%b\n" "${gl_kjlan}17.  ${gl_bai}开启IPv6" "${gl_kjlan}18.  ${gl_bai}设置本地语言"
		printf "%b\033[55G%b\n" "${gl_kjlan}19.  ${gl_bai}Docker镜像源测速" "${gl_kjlan}20.  ${gl_bai}卸载daimon脚本"
		echo -e "${gl_kjlan}------------------------"
		echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		read -e -p "请输入你的选择: " sub_choice || return 1

		case "$sub_choice" in
			1)
				while true; do
					clear
					read -e -p "请输入你的快捷按键（默认 d，输入0退出）: " kuaijiejian || return 1
					kuaijiejian=${kuaijiejian:-d}
					[ "$kuaijiejian" = "0" ] && break
					if ! daimon_shortcut_available "$kuaijiejian"; then
						echo "快捷键无效或与现有命令冲突，未修改任何文件。"
						break_end; continue
					fi
					root_use
					find /usr/local/bin/ -maxdepth 1 -type l -exec bash -c 'for link do [ "$(readlink -f -- "$link")" = /usr/local/bin/d ] && rm -f -- "$link"; done' bash {} + 2>/dev/null || true
					if [ "$kuaijiejian" != d ] && ! ln -sf /usr/local/bin/d "/usr/local/bin/$kuaijiejian"; then
						echo "快捷键创建失败"; break_end; continue
					fi
					if ! ln -sf /usr/local/bin/d "/usr/bin/$kuaijiejian"; then
						echo "快捷键创建失败"; break_end; continue
					fi
					echo "快捷键已设置: $kuaijiejian"
					send_stats "脚本快捷键已设置"
					break_end
					break
				done
				;;
			2)
				root_use
				send_stats "更换系统软件包镜像源"
				clear
				echo "更换系统软件包镜像源"
				echo "将执行：bash <(curl -sSL https://linuxmirrors.cn/main.sh)"
				bash <(curl -sSL https://linuxmirrors.cn/main.sh)
				;;
			3) set_dns_ui ;;
			4)
				root_use
				send_stats "设置v4/v6优先级"
				while true; do
					clear
					echo "设置v4/v6优先级"
					echo "------------------------"
					if grep -Eq '^\s*precedence\s+::ffff:0:0/96\s+100\s*$' /etc/gai.conf 2>/dev/null; then
						echo -e "当前网络优先级设置: ${gl_huang}IPv4${gl_bai} 优先"
					else
						echo -e "当前网络优先级设置: ${gl_huang}IPv6${gl_bai} 优先"
					fi
					echo ""
					echo "------------------------"
					echo "1. IPv4 优先          2. IPv6 优先          3. IPv6 修复工具"
					echo "------------------------"
					echo "0. 返回上一级选单"
					echo "------------------------"
					read -e -p "选择优先的网络: " choice || return 1
					case "$choice" in
						1) prefer_ipv4 ;;
						2) rm -f /etc/gai.conf; echo "已切换为 IPv6 优先"; send_stats "已切换为 IPv6 优先" ;;
						3) clear; daimon_run_cached_script "https://jhb.ovh/jb/v6.sh" "jhb-v6.sh"; echo "该功能由jhb大神提供，感谢他！"; send_stats "ipv6修复" ;;
						0) break ;;
						*) echo "无效的输入!" ;;
					esac
					[ "$choice" = "0" ] || break_end
				done
				;;
			5)
				root_use
				send_stats "设置虚拟内存"
				while true; do
					clear
					echo "设置虚拟内存"
					local swap_used swap_total swap_info
					swap_used=$(free -m | awk 'NR==3{print $3}')
					swap_total=$(free -m | awk 'NR==3{print $2}')
					swap_info=$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) {percentage=0} else {percentage=used*100/total}; printf "%dM/%dM (%d%%)", used, total, percentage}')
					echo -e "当前虚拟内存: ${gl_huang}$swap_info${gl_bai}"
					echo "------------------------"
					echo "1. 分配1024M         2. 分配2048M         3. 分配4096M         4. 自定义大小"
					echo "5. 删除虚拟内存（删除 /swapfile）"
					echo "------------------------"
					echo "0. 返回上一级选单"
					echo "------------------------"
					read -e -p "请输入你的选择: " choice || return 1
					case "$choice" in
						1) send_stats "已设置1G虚拟内存"; add_swap 1024 ;;
						2) send_stats "已设置2G虚拟内存"; add_swap 2048 ;;
						3) send_stats "已设置4G虚拟内存"; add_swap 4096 ;;
						4) read -e -p "请输入虚拟内存大小（单位M）: " new_swap || return 1; [ -n "$new_swap" ] && add_swap "$new_swap"; send_stats "已设置自定义虚拟内存" ;;
						5) send_stats "删除虚拟内存"; delete_swap ;;
						0) break ;;
						*) echo "无效的输入!" ;;
					esac
					[ "$choice" = "0" ] || break_end
				done
				;;
			6)
				while true; do
					root_use
					send_stats "用户管理"
					clear
					echo "用户列表"
					echo "----------------------------------------------------------------------------"
					printf "%-24s %-34s %-20s %-10s\n" "用户名" "用户目录" "用户组" "sudo权限"
					while IFS=: read -r username _ userid groupid _ homedir shell; do
						[ "$userid" -lt 1000 ] && [ "$username" != "root" ] && continue
						local groups sudo_status
						groups=$(groups "$username" 2>/dev/null | cut -d : -f 2)
						if sudo -n -lU "$username" 2>/dev/null | grep -q "(ALL) \(NOPASSWD: \)\?ALL" || id -nG "$username" 2>/dev/null | grep -qw sudo; then
							sudo_status="Yes"
						else
							sudo_status="No"
						fi
						printf "%-24s %-34s %-20s %-10s\n" "$username" "$homedir" "$groups" "$sudo_status"
					done < /etc/passwd
					echo ""
					echo "账户操作"
					echo "------------------------"
					echo "1. 创建普通用户             2. 创建高级用户（含sudo权限）"
					echo "------------------------"
					echo "3. 赋予最高权限             4. 取消最高权限"
					echo "------------------------"
					echo "5. 删除账号"
					echo "------------------------"
					echo "0. 返回上一级选单"
					echo "------------------------"
					read -e -p "请输入你的选择: " choice || return 1
					case "$choice" in
						1) read -e -p "请输入新用户名: " new_username || return 1; [ -n "$new_username" ] && create_user_with_sshkey "$new_username" false ;;
						2) read -e -p "请输入新用户名: " new_username || return 1; [ -n "$new_username" ] && create_user_with_sshkey "$new_username" true ;;
						3) read -e -p "请输入用户名: " username || return 1; daimon_regular_user_valid "$username" && { install sudo && usermod -aG sudo "$username" && { echo "$username ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$username"; chmod 440 "/etc/sudoers.d/$username"; }; } ;;
						4) read -e -p "请输入用户名: " username || return 1; daimon_regular_user_valid "$username" && { rm -f "/etc/sudoers.d/$username"; sed -i "/^$username\s*ALL=(ALL)/d" /etc/sudoers 2>/dev/null || true; gpasswd -d "$username" sudo 2>/dev/null || true; } ;;
						5)
							read -e -p "请输入要删除的用户名: " username || return 1
							if ! daimon_regular_user_valid "$username" || [ "$username" = "${SUDO_USER:-${USER:-}}" ]; then
								echo "不能删除系统账号、不存在的账号或当前登录账号。"
							else
								read -e -p "再次输入用户名确认删除账号及其主目录: " confirm_user || return 1
								[ "$confirm_user" = "$username" ] && userdel -r "$username"
							fi
							;;
						0) break ;;
						*) echo "无效的输入!" ;;
					esac
					[ "$choice" = "0" ] || break_end
				done
				;;
			7)
				root_use
				send_stats "换时区"
				while true; do
					clear
					echo "系统时间信息"
					local timezone current_time
					timezone=$(current_timezone)
					current_time=$(date +"%Y-%m-%d %H:%M:%S")
					echo "当前系统时区：$timezone"
					echo "当前系统时间：$current_time"
					echo ""
					echo "时区切换"
					echo "------------------------"
					echo "亚洲"
					echo "1.  中国上海时间             2.  中国香港时间"
					echo "3.  日本东京时间             4.  韩国首尔时间"
					echo "5.  新加坡时间               6.  印度加尔各答时间"
					echo "7.  阿联酋迪拜时间           8.  澳大利亚悉尼时间"
					echo "9.  泰国曼谷时间"
					echo "------------------------"
					echo "欧洲"
					echo "11. 英国伦敦时间             12. 法国巴黎时间"
					echo "13. 德国柏林时间             14. 俄罗斯莫斯科时间"
					echo "15. 荷兰阿姆斯特丹时间       16. 西班牙马德里时间"
					echo "------------------------"
					echo "美洲"
					echo "21. 美国西部时间             22. 美国东部时间"
					echo "23. 加拿大温哥华时间         24. 墨西哥城时间"
					echo "25. 巴西圣保罗时间           26. 阿根廷布宜诺斯艾利斯时间"
					echo "------------------------"
					echo "31. UTC全球标准时间"
					echo "------------------------"
					echo "0. 返回上一级选单"
					echo "------------------------"
					read -e -p "请输入你的选择: " choice || return 1
					case "$choice" in
						1) set_timedate Asia/Shanghai ;;
						2) set_timedate Asia/Hong_Kong ;;
						3) set_timedate Asia/Tokyo ;;
						4) set_timedate Asia/Seoul ;;
						5) set_timedate Asia/Singapore ;;
						6) set_timedate Asia/Kolkata ;;
						7) set_timedate Asia/Dubai ;;
						8) set_timedate Australia/Sydney ;;
						9) set_timedate Asia/Bangkok ;;
						11) set_timedate Europe/London ;;
						12) set_timedate Europe/Paris ;;
						13) set_timedate Europe/Berlin ;;
						14) set_timedate Europe/Moscow ;;
						15) set_timedate Europe/Amsterdam ;;
						16) set_timedate Europe/Madrid ;;
						21) set_timedate America/Los_Angeles ;;
						22) set_timedate America/New_York ;;
						23) set_timedate America/Vancouver ;;
						24) set_timedate America/Mexico_City ;;
						25) set_timedate America/Sao_Paulo ;;
						26) set_timedate America/Argentina/Buenos_Aires ;;
						31) set_timedate UTC ;;
						0) break ;;
						*) echo "无效的输入!" ;;
					esac
					[ "$choice" = "0" ] || break_end
				done
				;;
			8)
				root_use
				send_stats "修改主机名"
				while true; do
					clear
					local current_hostname new_hostname
					current_hostname=$(uname -n)
					echo -e "当前主机名: ${gl_huang}$current_hostname${gl_bai}"
					echo "------------------------"
					read -e -p "请输入新的主机名（输入0退出）: " new_hostname || return 1
					if [ -n "$new_hostname" ] && [ "$new_hostname" != "0" ]; then
						if [ -f /etc/alpine-release ]; then
							echo "$new_hostname" > /etc/hostname
							hostname "$new_hostname"
						else
							hostnamectl set-hostname "$new_hostname"
							echo "$new_hostname" > /etc/hostname
							systemctl restart systemd-hostnamed 2>/dev/null || true
						fi
						if grep -q "127.0.0.1" /etc/hosts; then
							sed -i "s/^127.0.0.1 .*/127.0.0.1       $new_hostname localhost localhost.localdomain/g" /etc/hosts
						else
							echo "127.0.0.1       $new_hostname localhost localhost.localdomain" >> /etc/hosts
						fi
						if grep -q "^::1" /etc/hosts; then
							sed -i "s/^::1 .*/::1             $new_hostname localhost localhost.localdomain ipv6-localhost ipv6-loopback/g" /etc/hosts
						else
							echo "::1             $new_hostname localhost localhost.localdomain ipv6-localhost ipv6-loopback" >> /etc/hosts
						fi
						echo "主机名已更改为: $new_hostname"
						send_stats "主机名已更改"
						break_end
					else
						break
					fi
				done
				;;
			9)
				root_use
				send_stats "本地host解析"
				while true; do
					clear
					echo "本机host解析列表"
					echo "如果你在这里添加解析匹配，将不再使用动态解析了"
					cat /etc/hosts
					echo ""
					echo "操作"
					echo "------------------------"
					echo "1. 添加新的解析              2. 删除解析地址"
					echo "------------------------"
					echo "0. 返回上一级选单"
					echo "------------------------"
					read -e -p "请输入你的选择: " host_dns || return 1
					case "$host_dns" in
						1) read -e -p "请输入新的解析记录 格式: 110.25.5.33 example.com : " addhost || return 1; [ -n "$addhost" ] && echo "$addhost" >> /etc/hosts; send_stats "本地host解析新增" ;;
						2) read -e -p "请输入需要删除的解析内容关键字: " delhost || return 1; [ -n "$delhost" ] && sed -i "/$delhost/d" /etc/hosts; send_stats "本地host解析删除" ;;
						0) break ;;
						*) echo "无效的输入!" ;;
					esac
					[ "$host_dns" = "0" ] || break_end
				done
				;;
			10) clear; env_menu ;;
			11) github_proxy_manager ;;
			12) show_ssh_ip_info; break_end ;;
			13) clear; net_menu ;;
			14) journalctl_log_manager ;;
			15) system_network_auto_optimize ;;
			16) clear; system_disable_ipv6; break_end ;;
			17) clear; system_enable_ipv6; break_end ;;
			18) clear; linux_language ;;
			19) docker_mirror_speed_test_menu ;;
			20)
				clear
				send_stats "卸载daimon脚本"
				echo "卸载daimon脚本"
				echo "------------------------------------------------"
				echo "将彻底卸载daimon脚本，不影响你其他功能"
				read -e -p "确定继续吗？(Y/N): " choice || return 1
				case "$choice" in
					[Yy])
						clear
						(crontab -l 2>/dev/null | grep -v "kejilion.sh") | crontab - 2>/dev/null || true
						rm -f /usr/local/bin/d /usr/bin/d
						rm -f "$DAIMON_LOCAL_SCRIPT" "$DAIMON_OLD_LOCAL_SCRIPT"
						echo "脚本已卸载，再见！"
						break_end
						clear
						exit
						;;
					[Nn]) echo "已取消" ;;
					*) echo "无效的选择，请输入 Y 或 N。" ;;
				esac
				;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
	done
}


linux_tools() {
  local thirdparty_ids=(vim cpcat ctrld starship bat btop tree ripgrep fd fzf blesh yazi fastfetch ncdu nexttrace iperf3)
  local thirdparty_names=("vim" "cpcat" "Ctrl+D" "starship" "bat" "btop" "tree" "ripgrep" "fd" "fzf" "ble.sh" "yazi" "fastfetch" "ncdu" "NextTrace" "iperf3")
  local thirdparty_desc=("文本编辑器+默认编辑器" "复制文件内容到剪贴板" "删除下一个单词绑定" "终端提示符美化" "终端高亮增强" "现代监控" "目录树" "快速文本搜索" "快速文件查找" "模糊搜索" "Bash 行编辑增强" "文件管理" "系统概览" "磁盘占用" "路由追踪" "网络性能测试")

  local programming_ids=(python npm nodejs bun uv git claude codex)
  local programming_names=("python" "npm" "nodejs" "bun" "uv" "git" "ClaudeCode" "Codex")
  local programming_desc=("Python 运行环境" "npm 包管理器" "Node.js 运行环境" "Bun 运行环境" "Python 包管理器" "版本控制" "AI 编程助手" "AI 编程助手")

  reload_bashrc_safely() {
    # 不在当前脚本进程里直接 source ~/.bashrc：
    # ble.sh / fzf / prompt 这类交互配置重复加载时可能导致 TTY detached 或 stty 异常。
    # 配置写入后由 restart_shell_after_tool_install 统一 exec bash 生效。
    hash -r 2>/dev/null || true
  }

  reload_shell_configs_safely() {
    reload_bashrc_safely
    hash -r 2>/dev/null || true
  }

  restart_shell_after_tool_install() {
    reload_shell_configs_safely
    [ "${DAIMON_DEFER_SHELL_RESTART:-0}" = 1 ] && return 0
    echo -e "${gl_lv}工具安装完成，正在使用 exec bash 重新进入命令行...${gl_bai}"
    exec bash
  }

  configure_vim_editor() {
    touch "$HOME/.bashrc"
    grep -qxF 'export EDITOR=vim' "$HOME/.bashrc" 2>/dev/null || echo 'export EDITOR=vim' >> "$HOME/.bashrc"
    grep -qxF 'export VISUAL=vim' "$HOME/.bashrc" 2>/dev/null || echo 'export VISUAL=vim' >> "$HOME/.bashrc"
    ensure_blesh_block_last
    reload_bashrc_safely
    echo "已设置默认编辑器: EDITOR=vim, VISUAL=vim"
  }

  remove_vim_editor_config() {
    [ -f "$HOME/.bashrc" ] && sed -i '/^export EDITOR=vim$/d;/^export VISUAL=vim$/d' "$HOME/.bashrc"
    reload_bashrc_safely
    echo "已删除 vim 默认编辑器配置"
  }

  remove_cpcat_config() {
    [ -f "$HOME/.bashrc" ] || return 0
    local tmp_file
    tmp_file=$(mktemp)
    awk '/^# ========== cpcat clipboard setup ==========$/ {skip=1; next} /^[[:space:]]*# ========== end cpcat clipboard setup ==========$/ {skip=0; next} !skip {print}' "$HOME/.bashrc" > "$tmp_file"
    cat "$tmp_file" > "$HOME/.bashrc"
    rm -f "$tmp_file"
  }

  configure_cpcat() {
    touch "$HOME/.bashrc"
    remove_cpcat_config
    cat >> "$HOME/.bashrc" << 'EOF'

# ========== cpcat clipboard setup ==========
# 一键复制文件内容到剪贴板
cpcat() {
    if [ -f "$1" ]; then
        printf "\033]52;c;$(base64 < "$1" | tr -d '\n')\a"
        echo "✅ 已复制到剪贴板: $1"
    else
        echo "❌ 文件不存在: $1"
    fi
}
# ========== end cpcat clipboard setup ==========
EOF
    ensure_blesh_block_last
    reload_bashrc_safely
    echo "已配置 cpcat"
  }

  remove_ctrld_config() {
    [ -f "$HOME/.bashrc" ] || return 0
    local tmp_file
    tmp_file=$(mktemp)
    awk '/^# ==================== Ctrl\+D 改为删除下一个单词 ====================$/ {skip=1; next} /^[[:space:]]*# ==================== end Ctrl\+D 改为删除下一个单词 ====================$/ {skip=0; next} !skip {print}' "$HOME/.bashrc" | sed '/^bind '\''"\\C-d": kill-word'\''$/d' > "$tmp_file"
    cat "$tmp_file" > "$HOME/.bashrc"
    rm -f "$tmp_file"
  }

  configure_ctrld() {
    touch "$HOME/.bashrc"
    remove_ctrld_config
    cat >> "$HOME/.bashrc" << 'EOF'

# ==================== Ctrl+D 改为删除下一个单词 ====================
bind '"\C-d": kill-word'
# ==================== end Ctrl+D 改为删除下一个单词 ====================
EOF
    ensure_blesh_block_last
    reload_bashrc_safely
    echo "已配置 Ctrl+D 删除下一个单词"
  }

  configure_fd_alias() {
    touch "$HOME/.bashrc"
    sed -i "/^alias fd='fdfind'$/d;/^alias fd=fdfind$/d;/^alias fd=\"fdfind\"$/d" "$HOME/.bashrc" 2>/dev/null || true
    echo "alias fd='fdfind'" >> "$HOME/.bashrc"
    if [ -L /usr/local/bin/fd ] && readlink /usr/local/bin/fd 2>/dev/null | grep -q 'fdfind'; then
      rm -f /usr/local/bin/fd 2>/dev/null || true
    fi
    ensure_blesh_block_last
    reload_bashrc_safely
    echo "已配置 fd 别名: alias fd='fdfind'"
  }

  remove_fd_alias() {
    [ -f "$HOME/.bashrc" ] && sed -i "/^alias fd='fdfind'$/d;/^alias fd=fdfind$/d;/^alias fd=\"fdfind\"$/d" "$HOME/.bashrc" 2>/dev/null || true
    if [ -L /usr/local/bin/fd ] && readlink /usr/local/bin/fd 2>/dev/null | grep -q 'fdfind'; then
      rm -f /usr/local/bin/fd 2>/dev/null || true
    fi
    reload_bashrc_safely
    echo "已删除 fd 别名"
  }

  remove_fzf_config() {
    remove_shell_block "$HOME/.bashrc" '# ========== fzf 核心配置 ==========' '# ========== end fzf 核心配置 =========='
    [ -f "$HOME/.bashrc" ] && sed -i '/\.fzf\.bash/d;/\.fzf\/bin/d;/\/root\/linux-daimon\/tools\/fzf/d;/FZF_DEFAULT_COMMAND/d;/FZF_DEFAULT_OPTS/d;/FZF_CTRL_T_OPTS/d;/FZF_ALT_C_OPTS/d;/BAT_PREVIEW/d' "$HOME/.bashrc" 2>/dev/null || true
  }

  configure_fzf() {
    if ! tool_installed fd; then
      echo "fzf 需要 fd/fdfind，正在安装 fd..."
      install_tool_by_id fd
    fi
    if ! tool_installed bat; then
      echo "fzf 预览需要 bat/batcat，正在安装 bat..."
      install_tool_by_id bat
    fi
    if ! tool_installed tree; then
      echo "fzf Alt+C 目录预览需要 tree，正在安装 tree..."
      install_tool_by_id tree
    fi
    install git

    if [ -d "$DAIMON_FZF_DIR/.git" ]; then
      git -C "$DAIMON_FZF_DIR" pull --ff-only || true
    else
      rm -rf "$DAIMON_FZF_DIR"
      daimon_git_clone "https://github.com/junegunn/fzf.git" "$DAIMON_FZF_DIR" --depth 1
    fi

    if [ -x "$DAIMON_FZF_DIR/install" ]; then
      "$DAIMON_FZF_DIR/install" --key-bindings --completion --no-update-rc
    fi

    touch "$HOME/.bashrc"
    remove_fzf_config
    cat >> "$HOME/.bashrc" <<'EOF'

# ========== fzf 核心配置 ==========

# git clone 安装的 fzf 默认在 /root/linux-daimon/tools/fzf/bin，先加入 PATH，避免 command -v 找不到
[ -d "/root/linux-daimon/tools/fzf/bin" ] && export PATH="/root/linux-daimon/tools/fzf/bin:$PATH"

# 如果没有安装 fzf，只跳过 fzf 配置，不 return 整个 ~/.bashrc
if command -v fzf >/dev/null 2>&1; then
  # 默认使用 fd/fdfind 列文件
  if command -v fdfind >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fdfind --type f --strip-cwd-prefix --hidden --follow --exclude .git'
  elif command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
  fi

  # bat/batcat 兼容
  if command -v batcat >/dev/null 2>&1; then
    BAT_PREVIEW='batcat --color=always --style=numbers --line-range=:500 {}'
  elif command -v bat >/dev/null 2>&1; then
    BAT_PREVIEW='bat --color=always --style=numbers --line-range=:500 {}'
  else
    BAT_PREVIEW='sed -n "1,500p" {}'
  fi

  export FZF_DEFAULT_OPTS="
    --height 50%
    --layout=reverse
    --border
    --inline-info
    --preview '$BAT_PREVIEW'
    --preview-window=right:50%
    --bind 'ctrl-/:toggle-preview'
  "

  export FZF_CTRL_T_OPTS="--preview '$BAT_PREVIEW'"

  if command -v tree >/dev/null 2>&1; then
    export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"
  else
    export FZF_ALT_C_OPTS="--preview 'ls -la {} | head -200'"
  fi
fi
# ========== end fzf 核心配置 ==========
EOF
    ensure_blesh_block_last
    reload_bashrc_safely
    "$DAIMON_FZF_DIR/bin/fzf" --version 2>/dev/null || fzf --version 2>/dev/null || true
    echo "fzf 已通过 git clone 安装到 $DAIMON_FZF_DIR 并写入 ~/.bashrc 配置"
  }

  remove_fzf_all() {
    remove_fzf_config
    rm -rf "$DAIMON_FZF_DIR"
    remove fzf
    reload_bashrc_safely
    echo "已删除 fzf、$DAIMON_FZF_DIR 和 ~/.bashrc 中的 fzf 配置"
  }

  remove_blesh_config() {
    remove_shell_block "$HOME/.bashrc" '# ========== ble.sh setup ==========' '# ========== end ble.sh setup =========='
    [ -f "$HOME/.bashrc" ] && sed -i '\#\.local/share/blesh/ble\.sh#d;\#blesh/ble\.sh#d' "$HOME/.bashrc" 2>/dev/null || true
  }

  ensure_blesh_block_last() {
    [ -f "$HOME/.local/share/blesh/ble.sh" ] || return 0
    touch "$HOME/.bashrc"
    remove_blesh_config
    cat >> "$HOME/.bashrc" <<'EOF'

# ========== ble.sh setup ==========
[ -f ~/.local/share/blesh/ble.sh ] && source ~/.local/share/blesh/ble.sh
# ========== end ble.sh setup ==========
EOF
  }

  configure_blesh() {
    install git make
    if [ -d "$HOME/ble.sh/.git" ]; then
      git -C "$HOME/ble.sh" pull --ff-only || true
      git -C "$HOME/ble.sh" submodule update --init --recursive || true
    else
      rm -rf "$HOME/ble.sh"
      daimon_git_clone "https://github.com/akinomyoga/ble.sh.git" "$HOME/ble.sh" --recursive
    fi

    (cd "$HOME/ble.sh" && make install)

    ensure_blesh_block_last

    cat > "$HOME/.blerc" <<'EOF'
# 自动补全
bleopt complete_auto_complete=1
# history 自动补全
bleopt complete_auto_history=1
# 使用fzf的快捷键
if command -v fzf >/dev/null 2>&1 || [ -x "/root/linux-daimon/tools/fzf/bin/fzf" ]; then
   ble-import -d integration/fzf-key-bindings
 fi
EOF
    ensure_blesh_block_last
    reload_bashrc_safely
    echo "ble.sh 已安装并配置 ~/.bashrc 和 ~/.blerc"
  }

  remove_blesh_all() {
    remove_blesh_config
    rm -rf "$HOME/ble.sh" "$HOME/.local/share/blesh" "$HOME/.blerc"
    reload_bashrc_safely
    echo "已删除 ble.sh、~/.blerc 和 ~/.bashrc 中的 ble.sh 配置"
  }

  stop_disable_service_safely() {
    local service_name="$1"
    if command -v systemctl >/dev/null 2>&1 && [ -x /bin/systemctl ]; then
      /bin/systemctl stop "$service_name" >/dev/null 2>&1 || true
      /bin/systemctl disable "$service_name" >/dev/null 2>&1 || true
    elif command -v service >/dev/null 2>&1; then
      service "$service_name" stop >/dev/null 2>&1 || true
    fi
  }

  remove_fail2ban_all() {
    stop_disable_service_safely fail2ban
    remove fail2ban
    rm -rf /etc/fail2ban /var/lib/fail2ban
    rm -f /var/log/fail2ban.log
    echo "已彻底删除 fail2ban、配置目录和日志文件"
  }

  remove_iptables_persistent_all() {
    stop_disable_service_safely netfilter-persistent
    stop_disable_service_safely iptables
    remove iptables-persistent netfilter-persistent iptables-services
    rm -rf /etc/iptables
    echo "已彻底删除 iptables-persistent/netfilter-persistent 和 /etc/iptables"
  }

  remove_ufw_all() {
    ufw disable >/dev/null 2>&1 || true
    stop_disable_service_safely ufw
    remove ufw
    rm -rf /etc/ufw /var/lib/ufw
    echo "已彻底删除 ufw、配置目录和状态目录"
  }

  remove_firewalld_all() {
    stop_disable_service_safely firewalld
    remove firewalld
    rm -rf /etc/firewalld
    echo "已彻底删除 firewalld 和 /etc/firewalld"
  }


  remove_shell_block() {
    local file="$1"
    local start_pattern="$2"
    local end_pattern="$3"
    [ -f "$file" ] || return 0
    local tmp_file
    tmp_file=$(mktemp)
    awk -v start="$start_pattern" -v end="$end_pattern" '
      $0 == start {skip=1; next}
      $0 == end {skip=0; next}
      !skip {print}
    ' "$file" > "$tmp_file"
    cat "$tmp_file" > "$file"
    rm -f "$tmp_file"
  }

  remove_starship_config() {
    remove_shell_block "$HOME/.bashrc" '# ========== starship prompt setup ==========' '# ========== end starship prompt setup =========='
    remove_shell_block "$HOME/.zshrc" '# ========== starship prompt setup ==========' '# ========== end starship prompt setup =========='
    [ -f "$HOME/.bashrc" ] && sed -i '/starship init bash/d' "$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && sed -i '/starship init zsh/d' "$HOME/.zshrc"
  }

  configure_starship() {
    root_use
    install curl tar gzip
    mkdir -p "$DAIMON_SCRIPT_DIR" "$HOME/.config"
    local starship_arch starship_target starship_url starship_tar starship_tmp starship_bin

    if daimon_is_cn; then
      case "$(uname -m)" in
        x86_64|amd64) starship_arch="x86_64" ;;
        aarch64|arm64) starship_arch="aarch64" ;;
        i686|i386) starship_arch="i686" ;;
        *) starship_arch="" ;;
      esac

      if [ -z "$starship_arch" ]; then
        echo "当前架构暂不支持自动安装 starship: $(uname -m)"
        return 1
      fi

      starship_target="${starship_arch}-unknown-linux-musl"
      starship_url="https://gh-proxy.com/https://github.com/starship/starship/releases/latest/download/starship-${starship_target}.tar.gz"
      starship_tar="/tmp/starship.tar.gz"
      starship_tmp="/tmp/starship-install"

      rm -rf "$starship_tmp" "$starship_tar" 2>/dev/null || true
      mkdir -p "$starship_tmp"

      if curl -L --retry 5 -o "$starship_tar" "$starship_url" && tar -xzf "$starship_tar" -C "$starship_tmp"; then
        starship_bin="$starship_tmp/starship"
        [ -f "$starship_bin" ] || starship_bin=$(find "$starship_tmp" -type f -name starship | head -1)
        [ -n "$starship_bin" ] && command install -m 755 "$starship_bin" /usr/local/bin/starship
      fi

      rm -rf "$starship_tmp" "$starship_tar" 2>/dev/null || true
    else
      curl -sS https://starship.rs/install.sh | sh -s -- -y
    fi

    if ! command -v starship >/dev/null 2>&1; then
      remove_starship_config
      echo "starship 安装失败，已移除 ~/.bashrc 中的 starship 初始化，避免出现 command not found"
      return 1
    fi

    touch "$HOME/.bashrc"
    remove_starship_config
    cat >> "$HOME/.bashrc" <<'EOF'
# ========== starship prompt setup ==========
eval "$(starship init bash)"
# ========== end starship prompt setup ==========
EOF
    touch "$HOME/.zshrc"
    cat >> "$HOME/.zshrc" <<'EOF'
# ========== starship prompt setup ==========
eval "$(starship init zsh)"
# ========== end starship prompt setup ==========
EOF

    cat > "$HOME/.config/starship.toml" <<'EOF'
"$schema" = 'https://starship.rs/config-schema.json'

format = """
[](red)\
$os\
$username\
[](bg:peach fg:red)\
$directory\
[](bg:yellow fg:peach)\
$git_branch\
$git_status\
[](fg:yellow bg:green)\
$c\
$rust\
$golang\
$nodejs\
$bun\
$php\
$java\
$kotlin\
$haskell\
$python\
[](fg:green bg:sapphire)\
$conda\
[](fg:sapphire bg:lavender)\
$time\
[ ](fg:lavender)\
$cmd_duration\
$line_break\
$character"""

palette = 'catppuccin_mocha'

[os]
disabled = false
style = "bg:red fg:crust"

[os.symbols]
Windows = ""
Ubuntu = ""
SUSE = ""
Raspbian = ""
Mint = ""
Macos = ""
Manjaro = ""
Linux = ""
Gentoo = ""
Fedora = ""
Alpine = ""
Amazon = ""
Android = ""
AOSC = ""
Arch = ""
Artix = ""
CentOS = ""
Debian = ""
Redhat = ""
RedHatEnterprise = ""

[username]
show_always = true
style_user = "bg:red fg:crust"
style_root = "bg:red fg:crust"
format = '[ $user]($style)'

[directory]
style = "bg:peach fg:crust"
format = "[ $path ]($style)"
home_symbol = "/root"
truncate_to_repo = false
truncation_length = 100
truncation_symbol = ""
fish_style_pwd_dir_length = 0

[directory.substitutions]
"Documents" = " "
"Downloads" = " "
"Music" = " "
"Pictures" = " "
"Developer" = " "

[git_branch]
symbol = ""
style = "bg:yellow"
format = '[[ $symbol $branch ](fg:crust bg:yellow)]($style)'

[git_status]
style = "bg:yellow"
format = '[[($all_status$ahead_behind )](fg:crust bg:yellow)]($style)'

[nodejs]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[bun]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[c]
symbol = " "
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[rust]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[golang]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[php]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[java]
symbol = " "
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[kotlin]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[haskell]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[python]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version)(\(#$virtualenv\)) ](fg:crust bg:green)]($style)'

[docker_context]
symbol = ""
style = "bg:sapphire"
format = '[[ $symbol( $context) ](fg:crust bg:sapphire)]($style)'

[conda]
symbol = "  "
style = "fg:crust bg:sapphire"
format = '[$symbol$environment ]($style)'
ignore_base = false

[time]
disabled = false
time_format = "%R"
style = "bg:lavender"
format = '[[  $time ](fg:crust bg:lavender)]($style)'

[line_break]
disabled = false

[character]
disabled = false
success_symbol = '[❯](bold fg:green)'
error_symbol = '[❯](bold fg:red)'
vimcmd_symbol = '[❮](bold fg:green)'
vimcmd_replace_one_symbol = '[❮](bold fg:lavender)'
vimcmd_replace_symbol = '[❮](bold fg:lavender)'
vimcmd_visual_symbol = '[❮](bold fg:yellow)'

[cmd_duration]
show_milliseconds = true
format = " in $duration "
style = "bg:lavender"
disabled = false
show_notifications = true
min_time_to_notify = 45000

[palettes.catppuccin_mocha]
rosewater = "#f5e0dc"
flamingo = "#f2cdcd"
pink = "#f5c2e7"
mauve = "#cba6f7"
red = "#f38ba8"
maroon = "#eba0ac"
peach = "#fab387"
yellow = "#f9e2af"
green = "#a6e3a1"
teal = "#94e2d5"
sky = "#89dceb"
sapphire = "#74c7ec"
blue = "#89b4fa"
lavender = "#b4befe"
text = "#cdd6f4"
subtext1 = "#bac2de"
subtext0 = "#a6adc8"
overlay2 = "#9399b2"
overlay1 = "#7f849c"
overlay0 = "#6c7086"
surface2 = "#585b70"
surface1 = "#45475a"
surface0 = "#313244"
base = "#1e1e2e"
mantle = "#181825"
crust = "#11111b"

[palettes.catppuccin_frappe]
rosewater = "#f2d5cf"
flamingo = "#eebebe"
pink = "#f4b8e4"
mauve = "#ca9ee6"
red = "#e78284"
maroon = "#ea999c"
peach = "#ef9f76"
yellow = "#e5c890"
green = "#a6d189"
teal = "#81c8be"
sky = "#99d1db"
sapphire = "#85c1dc"
blue = "#8caaee"
lavender = "#babbf1"
text = "#c6d0f5"
subtext1 = "#b5bfe2"
subtext0 = "#a5adce"
overlay2 = "#949cbb"
overlay1 = "#838ba7"
overlay0 = "#737994"
surface2 = "#626880"
surface1 = "#51576d"
surface0 = "#414559"
base = "#303446"
mantle = "#292c3c"
crust = "#232634"

[palettes.catppuccin_latte]
rosewater = "#dc8a78"
flamingo = "#dd7878"
pink = "#ea76cb"
mauve = "#8839ef"
red = "#d20f39"
maroon = "#e64553"
peach = "#fe640b"
yellow = "#df8e1d"
green = "#40a02b"
teal = "#179299"
sky = "#04a5e5"
sapphire = "#209fb5"
blue = "#1e66f5"
lavender = "#7287fd"
text = "#4c4f69"
subtext1 = "#5c5f77"
subtext0 = "#6c6f85"
overlay2 = "#7c7f93"
overlay1 = "#8c8fa1"
overlay0 = "#9ca0b0"
surface2 = "#acb0be"
surface1 = "#bcc0cc"
surface0 = "#ccd0da"
base = "#eff1f5"
mantle = "#e6e9ef"
crust = "#dce0e8"

[palettes.catppuccin_macchiato]
rosewater = "#f4dbd6"
flamingo = "#f0c6c6"
pink = "#f5bde6"
mauve = "#c6a0f6"
red = "#ed8796"
maroon = "#ee99a0"
peach = "#f5a97f"
yellow = "#eed49f"
green = "#a6da95"
teal = "#8bd5ca"
sky = "#91d7e3"
sapphire = "#7dc4e4"
blue = "#8aadf4"
lavender = "#b7bdf8"
text = "#cad3f5"
subtext1 = "#b8c0e0"
subtext0 = "#a5adcb"
overlay2 = "#939ab7"
overlay1 = "#8087a2"
overlay0 = "#6e738d"
surface2 = "#5b6078"
surface1 = "#494d64"
surface0 = "#363a4f"
base = "#24273a"
mantle = "#1e2030"
crust = "#181926"
EOF
    ensure_blesh_block_last
    reload_bashrc_safely
    starship --version 2>/dev/null || true
    echo "starship 已安装并写入配置: $HOME/.config/starship.toml"
  }

  remove_starship_all() {
    remove_starship_config
    rm -f "$HOME/.config/starship.toml"
    rm -f "$DAIMON_SCRIPT_DIR/starship-install.sh"
    rm -f /usr/local/bin/starship /usr/bin/starship "$HOME/.local/bin/starship" "$HOME/.cargo/bin/starship" 2>/dev/null || true
    reload_bashrc_safely
    echo "已彻底删除 starship、shell 初始化配置和 ~/.config/starship.toml"
  }

  remove_bat_config() {
    local bashrc_file="$HOME/.bashrc"
    [ -f "$bashrc_file" ] || return 0
    local tmp_file
    tmp_file=$(mktemp)
    awk '
      /^# ========== bat terminal color setup ==========$/ {skip=1; next}
      /^[[:space:]]*# ========== end bat terminal color setup ==========$/ {skip=0; next}
      /^# ========== bat 终端着色增强 ==========$/ {skip=1; next}
      skip && /^[[:space:]]*fi[[:space:]]*$/ {skip=0; next}
      !skip {print}
    ' "$bashrc_file" > "$tmp_file"
    cat "$tmp_file" > "$bashrc_file"
    rm -f "$tmp_file"
    rm -f "$HOME/.bat.sh"
  }

  configure_bat_terminal() {
    if ! command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
      install bat
    fi
    if ! command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
      echo "bat 安装失败或当前系统未提供 bat/batcat 命令"
      return 1
    fi
    local bashrc_file="$HOME/.bashrc"
    local bat_file="$HOME/.bat.sh"
    touch "$bashrc_file"
    remove_bat_config
    cat > "$bat_file" <<'EOF'
  # 避免 alias 抢在函数前面生效
  unalias bat cat docker ping ip ss ps df free systemctl journalctl git lsblk netstat ufw 2>/dev/null

  # Debian/Ubuntu 上 bat 通常叫 batcat
  if command -v batcat >/dev/null 2>&1; then
    __BAT_BIN="batcat"
  elif command -v bat >/dev/null 2>&1; then
    __BAT_BIN="bat"
  else
    __BAT_BIN=""
  fi

  if [ -n "$__BAT_BIN" ]; then
    alias bat="$__BAT_BIN"

    __bat_filter() {
      local lang="${1:-log}"
      if [ -t 1 ]; then
        "$__BAT_BIN" --paging=never --style=plain --color=always -l "$lang"
      else
        command cat
      fi
    }

    cat() {
      if [ -t 1 ]; then
        "$__BAT_BIN" --paging=never --style=plain "$@"
      else
        command cat "$@"
      fi
    }

    bcat()  { __bat_filter log; }
    blog()  { __bat_filter log; }
    bjson() { __bat_filter json; }
    byaml() { __bat_filter yaml; }
    bconf() { __bat_filter conf; }
    bsh()   { __bat_filter bash; }
    bdiff() { __bat_filter diff; }
    bhttp() { __bat_filter http; }

    bauto() {
      local tmp lang
      tmp="$(mktemp)"
      command cat > "$tmp"
      if python3 -m json.tool "$tmp" >/dev/null 2>&1; then
        lang="json"
      elif grep -qE '^(diff --git|@@ |--- |\+\+\+ )' "$tmp"; then
        lang="diff"
      elif grep -qE '^[[:space:]]*[A-Za-z0-9_.-]+:[[:space:]]*' "$tmp"; then
        lang="yaml"
      elif head -n 1 "$tmp" | grep -qE '^#!.*(ba|z|k)?sh'; then
        lang="bash"
      else
        lang="log"
      fi
      if [ -t 1 ]; then
        "$__BAT_BIN" --paging=never --style=plain --color=always -l "$lang" "$tmp"
      else
        command cat "$tmp"
      fi
      rm -f "$tmp"
    }

    raw() { command "$@"; }

    docker() {
      case "$1" in
        ps|images|info|version|stats|events) command docker "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]} ;;
        inspect) command docker "$@" 2>&1 | __bat_filter json; return ${PIPESTATUS[0]} ;;
        logs) command docker "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]} ;;
        compose)
          case "$2" in
            config) command docker "$@" 2>&1 | __bat_filter yaml; return ${PIPESTATUS[0]} ;;
            ps|logs|events|images|top) command docker "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]} ;;
            *) command docker "$@" ;;
          esac
          ;;
        *) command docker "$@" ;;
      esac
    }

    ping() { command ping "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]}; }
    ip() { command ip "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]}; }
    ss() { command ss "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]}; }
    netstat() { command netstat "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]}; }
    ps() { command ps "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]}; }
    df() { command df "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]}; }
    free() { command free "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]}; }
    lsblk() { command lsblk "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]}; }
    systemctl() { command systemctl --no-pager "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]}; }
    journalctl() { command journalctl --no-pager "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]}; }

    ufw() {
      case "$1" in
        status|show|app) command ufw "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]} ;;
        *) command ufw "$@" ;;
      esac
    }

    git() {
      case "$1" in
        diff|show) command git -c color.ui=never "$@" 2>&1 | __bat_filter diff; return ${PIPESTATUS[0]} ;;
        status|log|branch|remote) command git -c color.ui=never "$@" 2>&1 | __bat_filter log; return ${PIPESTATUS[0]} ;;
        *) command git "$@" ;;
      esac
    }
  fi
EOF
    cat >> "$bashrc_file" <<'EOF'
# ========== bat 终端着色增强 ==========
if [ -f ~/.bat.sh ]; then
    source ~/.bat.sh
fi
EOF
    ensure_blesh_block_last
    reload_bashrc_safely
    echo "bat 终端高亮配置已写入: $bat_file"
  }

  remove_bat_all() {
    remove_bat_config
    remove bat batcat
    reload_bashrc_safely
    echo "已删除 bat 终端高亮配置，并尝试卸载 bat/batcat"
  }

  install_yazi_griffo() {
    root_use
    if command -v apt >/dev/null 2>&1; then
      install curl gnupg ca-certificates lsb-release
      curl -sS https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc \
        | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg || return 1
      echo "deb https://debian.griffo.io/apt $(lsb_release -sc 2>/dev/null) main" \
        | tee /etc/apt/sources.list.d/debian.griffo.io.list >/dev/null
      DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt update -y
      DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        yazi
    else
      install yazi
    fi
    yazi --version 2>/dev/null || true
  }

  remove_yazi_all() {
    remove yazi
    rm -rf "$HOME/.config/yazi" "$HOME/.local/share/yazi" "$HOME/.cache/yazi"
    if command -v apt >/dev/null 2>&1; then
      rm -f /etc/apt/sources.list.d/debian.griffo.io.list
      rm -f /etc/apt/trusted.gpg.d/debian.griffo.io.gpg
      apt update -y 2>/dev/null || true
    fi
  }

  install_nexttrace() {
    root_use
    if command -v apt >/dev/null 2>&1; then
      install curl ca-certificates
      command install -d -m 0755 /etc/apt/keyrings
      curl -fsSL -o /tmp/nexttrace-archive-keyring.gpg "https://github.com/nxtrace/nexttrace-debs/releases/latest/download/nexttrace-archive-keyring.gpg" || return 1
      command install -m 0644 /tmp/nexttrace-archive-keyring.gpg /etc/apt/keyrings/nexttrace.gpg
      rm -f /tmp/nexttrace-archive-keyring.gpg
      printf '%s\n' \
        'Types: deb' \
        'URIs: https://github.com/nxtrace/nexttrace-debs/releases/latest/download/' \
        'Suites: ./' \
        'Signed-By: /etc/apt/keyrings/nexttrace.gpg' \
        | tee /etc/apt/sources.list.d/nexttrace.sources >/dev/null
      DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt update -y
      DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        nexttrace
    else
      install nexttrace
    fi
    nexttrace --version 2>/dev/null | head -n 1 || true
  }

  remove_nexttrace_all() {
    remove nexttrace
    if command -v apt >/dev/null 2>&1; then
      rm -f /etc/apt/keyrings/nexttrace.gpg /etc/apt/sources.list.d/nexttrace.sources
      apt update -y 2>/dev/null || true
    fi
  }

  python_312_is_default() {
    command -v python3.12 >/dev/null 2>&1 || return 1
    python --version 2>&1 | grep -q '^Python 3\.12\.'
  }

  install_python_312() {
    root_use
    local python312_bin
    if command -v apt >/dev/null 2>&1; then
      DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt update -y
      if ! apt-cache show python3.12 >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt install -y \
          -o Dpkg::Options::="--force-confdef" \
          -o Dpkg::Options::="--force-confold" \
          software-properties-common || return 1
        if ! command -v add-apt-repository >/dev/null 2>&1; then
          echo "未检测到 add-apt-repository，无法添加 Python 3.12 软件源"
          return 1
        fi
        add-apt-repository -y ppa:deadsnakes/ppa || return 1
        mkdir -p "$DAIMON_SCRIPT_DIR"
        touch "$DAIMON_SCRIPT_DIR/python312-deadsnakes-added"
        DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt update -y
      fi
      DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        python3.12 python3.12-venv python3.12-dev python3-pip || return 1
    else
      install python3.12
    fi

    python312_bin="$(command -v python3.12 2>/dev/null || true)"
    if [ -n "$python312_bin" ]; then
      if [ -e /usr/local/bin/python ] && [ "$(readlink /usr/local/bin/python 2>/dev/null)" != "/etc/alternatives/daimon-python" ]; then
        echo "检测到 /usr/local/bin/python 已存在，跳过默认 python 切换"
      elif command -v update-alternatives >/dev/null 2>&1; then
        update-alternatives --install /usr/local/bin/python daimon-python "$python312_bin" 312
        update-alternatives --set daimon-python "$python312_bin"
      fi
    fi

    hash -r 2>/dev/null || true
    python3.12 --version 2>/dev/null || true
    python --version 2>/dev/null || true
    if ! command -v python3.12 >/dev/null 2>&1; then
      echo "Python 3.12 安装失败"
      return 1
    fi
    if ! python_312_is_default; then
      echo "Python 3.12 已安装，但 python 默认命令未切换到 3.12"
      return 1
    fi
  }

  remove_python_312_all() {
    if command -v update-alternatives >/dev/null 2>&1; then
      update-alternatives --remove daimon-python /usr/bin/python3.12 2>/dev/null || true
    fi
    if [ -L /usr/local/bin/python ] && [ "$(readlink /usr/local/bin/python 2>/dev/null)" = "/etc/alternatives/daimon-python" ]; then
      rm -f /usr/local/bin/python
    fi
    remove python3.12 python3.12-venv python3.12-dev
    if [ -f "$DAIMON_SCRIPT_DIR/python312-deadsnakes-added" ] && command -v add-apt-repository >/dev/null 2>&1; then
      add-apt-repository --remove -y ppa:deadsnakes/ppa 2>/dev/null || true
      rm -f "$DAIMON_SCRIPT_DIR/python312-deadsnakes-added"
      apt update -y 2>/dev/null || true
    fi
  }


  load_nvm_env() {
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion" 2>/dev/null || true
  }

  install_nvm_lts_auto() {
    install curl ca-certificates
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
      if daimon_is_cn; then
        bash -c "$(curl -fsSL https://gitee.com/RubyMetric/nvm-cn/raw/main/install.sh)" || return 1
      else
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash || return 1
      fi
    fi

    load_nvm_env
    if ! command -v nvm >/dev/null 2>&1; then
      echo "nvm 安装失败或未能加载"
      return 1
    fi

    nvm install --lts || return 1
    nvm alias default 'lts/*' || return 1
    nvm use default >/dev/null 2>&1 || true
    hash -r 2>/dev/null || true
    node -v
    npm -v
  }

  remove_nvm_all() {
    remove nodejs npm 2>/dev/null || true
    rm -rf "$HOME/.nvm" "$HOME/.npm" "$HOME/.node-gyp"
    [ -f "$HOME/.bashrc" ] && sed -i '/NVM_DIR/d;/nvm\.sh/d;/bash_completion.*nvm/d;/nvm-cn/d' "$HOME/.bashrc" 2>/dev/null || true
    [ -f "$HOME/.profile" ] && sed -i '/NVM_DIR/d;/nvm\.sh/d;/bash_completion.*nvm/d;/nvm-cn/d' "$HOME/.profile" 2>/dev/null || true
    [ -f "$HOME/.bash_profile" ] && sed -i '/NVM_DIR/d;/nvm\.sh/d;/bash_completion.*nvm/d;/nvm-cn/d' "$HOME/.bash_profile" 2>/dev/null || true
    reload_shell_configs_safely
    echo "已删除 nvm、Node.js、npm 及相关用户缓存"
  }

  configure_claude_code_settings() {
    mkdir -p "$HOME/.claude"
    cat > "$HOME/.claude/settings.json" <<'EOF'
{
  "env": {
    "DISABLE_INSTALLATION_CHECKS": "1",
    "ENABLE_TOOL_SEARCH": "true",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-opus-4-8",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME": "claude-opus-4-8",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-8[1M]",
    "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME": "claude-opus-4-8",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-opus-4-8[1M]",
    "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "claude-opus-4-8",
    "ANTHROPIC_MODEL": "claude-opus-4-8[1m]",
    "ANTHROPIC_REASONING_MODEL": "claude-opus-4-8[1m]",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "DISABLE_AUTOUPDATER": "1",
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_API_KEY": "12346"
  },
  "includeCoAuthoredBy": false,
  "model": "opus[1m]",
  "skipDangerousModePermissionPrompt": true,
  "hasCompletedOnboarding": true
}
EOF

    if command -v python3 >/dev/null 2>&1; then
      [ -f "$HOME/.claude.json" ] || printf '{}\n' > "$HOME/.claude.json"
      python3 - "$HOME/.claude.json" <<'PY'
import json
import sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}
data["hasCompletedOnboarding"] = True
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
    else
      printf '{\n  "hasCompletedOnboarding": true\n}\n' > "$HOME/.claude.json"
    fi
  }

  install_claude_code_auto() {
    export PATH="$HOME/.local/bin:$PATH"
    if command -v claude >/dev/null 2>&1; then
      claude update 2>/dev/null || true
    elif daimon_is_cn; then
      install_nvm_lts_auto || return 1
      load_nvm_env
      npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com || return 1
    else
      install curl
      curl -fsSL https://claude.ai/install.sh | bash || return 1
      export PATH="$HOME/.local/bin:$PATH"
    fi

    configure_claude_code_settings
    if ! command -v claude >/dev/null 2>&1; then
      echo "ClaudeCode 安装失败或 claude 命令不在 PATH"
      return 1
    fi
    claude --version
  }

  remove_claude_code_all() {
    load_nvm_env
    npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
    rm -rf "$HOME/.claude"
    rm -f "$HOME/.claude.json"
    reload_shell_configs_safely
    echo "已删除 ClaudeCode 和 ~/.claude 配置"
  }

  configure_codex_settings() {
    mkdir -p "$HOME/.codex"
    cat > "$HOME/.codex/config.toml" <<'EOF'
model = "gpt-5.5"
model_reasoning_effort = "high"
disable_response_storage = true
fast_mode = true
service_tier = "fast"
personality = "pragmatic"
approval_policy = "never"
sandbox_mode = "danger-full-access"
web_search = "cached"
approvals_reviewer = "user"
model_provider = "default"

[notice]
hide_full_access_warning = true

[sandbox_workspace_write]
network_access = true

[features]
multi_agent = false
unified_exec = false
collaboration_modes = false
steer = false
memories = false
apps = false
js_repl = false

[model_providers]

[model_providers.default]
name = "default"
base_url = "https://api.deepseek.com"
wire_api = "responses"
requires_openai_auth = false
experimental_bearer_token = "default"
EOF
  }

  install_codex_cli() {
    if ! command -v npm >/dev/null 2>&1; then
      install_nvm_lts_auto || return 1
    else
      load_nvm_env
    fi
    npm install -g @openai/codex@latest || return 1
    configure_codex_settings
    if ! command -v codex >/dev/null 2>&1; then
      echo "Codex 安装失败或 codex 命令不在 PATH"
      return 1
    fi
    codex --version
  }

  remove_codex_all() {
    load_nvm_env
    npm uninstall -g @openai/codex 2>/dev/null || true
    rm -f "$HOME/.codex/config.toml"
    rmdir "$HOME/.codex" 2>/dev/null || true
    reload_shell_configs_safely
    echo "已删除 Codex 和 ~/.codex/config.toml"
  }

  tool_installed() {
    local id="$1"
    case "$id" in
      vim) command -v vim >/dev/null 2>&1 && grep -qxF 'export EDITOR=vim' "$HOME/.bashrc" 2>/dev/null && grep -qxF 'export VISUAL=vim' "$HOME/.bashrc" 2>/dev/null ;;
      cpcat) grep -q '^# ========== cpcat clipboard setup ==========$' "$HOME/.bashrc" 2>/dev/null ;;
      ctrld) grep -q '^# ==================== Ctrl+D 改为删除下一个单词 ====================$' "$HOME/.bashrc" 2>/dev/null || grep -q '^bind '\''"\\C-d": kill-word'\''$' "$HOME/.bashrc" 2>/dev/null ;;
      starship) command -v starship >/dev/null 2>&1 && [ -f "$HOME/.config/starship.toml" ] ;;
      bat) (command -v batcat >/dev/null 2>&1 || command -v bat >/dev/null 2>&1) && [ -f "$HOME/.bat.sh" ] && grep -q '^# ========== bat 终端着色增强 ==========$' "$HOME/.bashrc" 2>/dev/null ;;
      ripgrep) command -v rg >/dev/null 2>&1 ;;
      fd) command -v fd >/dev/null 2>&1 || (command -v fdfind >/dev/null 2>&1 && grep -Eq "^alias fd=('fdfind'|\"fdfind\"|fdfind)$" "$HOME/.bashrc" 2>/dev/null) ;;
      fzf) [ -x "$DAIMON_FZF_DIR/bin/fzf" ] && grep -q '^# ========== fzf 核心配置 ==========$' "$HOME/.bashrc" 2>/dev/null ;;
      blesh) [ -f "$HOME/.local/share/blesh/ble.sh" ] && grep -q '^# ========== ble.sh setup ==========$' "$HOME/.bashrc" 2>/dev/null ;;
      python) python_312_is_default ;;
      npm) command -v npm >/dev/null 2>&1 ;;
      nodejs) command -v node >/dev/null 2>&1 ;;
      iptables-persistent) command -v netfilter-persistent >/dev/null 2>&1 || dpkg -s iptables-persistent >/dev/null 2>&1 ;;
      firewalld) command -v firewall-cmd >/dev/null 2>&1 ;;
      claude) command -v claude >/dev/null 2>&1 && [ -f "$HOME/.claude/settings.json" ] ;;
      codex) command -v codex >/dev/null 2>&1 && [ -f "$HOME/.codex/config.toml" ] ;;
      *) command -v "$id" >/dev/null 2>&1 ;;
    esac
  }

  show_tool_status() {
    echo -e "${gl_kjlan}------------------------${gl_bai}"
    for ((i=0; i<${#tool_ids[@]}; i++)); do
      local status="未安装"
      local color="$gl_hong"
      if tool_installed "${tool_ids[i]}"; then
        status="已安装"
        color="$gl_lv"
      fi
      printf "%2d. %-20s %-18s %b%s%b\n" "$((i+1))" "${tool_names[i]}" "${tool_desc[i]}" "$color" "$status" "$gl_bai"
    done
    echo -e "${gl_kjlan}------------------------${gl_bai}"
  }

  install_tool_by_id() {
    local id="$1"
    case "$id" in
      vim)
        if tool_installed vim || command -v vim >/dev/null 2>&1; then
          echo "vim 已安装，正在检查并设置默认编辑器..."
        else
          install vim
        fi
        configure_vim_editor
        vim --version 2>/dev/null | head -n 1 || true
        ;;
      cpcat)
        configure_cpcat
        ;;
      ctrld)
        configure_ctrld
        ;;
      starship)
        configure_starship
        ;;
      bat)
        configure_bat_terminal
        ;;
      ripgrep)
        install ripgrep
        rg --version 2>/dev/null | head -n 1 || true
        ;;
      fd)
        install fd-find
        configure_fd_alias
        fd --version 2>/dev/null || fdfind --version 2>/dev/null || true
        ;;
      fzf)
        configure_fzf
        ;;
      blesh)
        configure_blesh
        ;;
      python)
        install_python_312
        ;;
      npm|nodejs)
        install_nvm_lts_auto
        ;;
      bun)
        if tool_installed bun; then
          bun --version
        else
          install curl unzip
          daimon_run_cached_script "https://bun.sh/install" "bun-install.sh"
          export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
          export PATH="$BUN_INSTALL/bin:$PATH"
          reload_shell_configs_safely
          bun --version 2>/dev/null || true
        fi
        ;;
      uv)
        if tool_installed uv; then
          uv --version
        else
          install curl
          daimon_run_cached_script "https://astral.sh/uv/install.sh" "uv-install.sh"
          export PATH="$HOME/.local/bin:$PATH"
          reload_shell_configs_safely
          uv --version 2>/dev/null || true
        fi
        ;;
      iptables-persistent)
        if command -v apt >/dev/null 2>&1; then
          DEBIAN_FRONTEND=noninteractive apt update -y && DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent
        elif command -v dnf >/dev/null 2>&1; then
          dnf install -y iptables-services
        elif command -v yum >/dev/null 2>&1; then
          yum install -y iptables-services
        else
          install iptables-persistent
        fi
        ;;
      ufw)
        install ufw
        ufw status 2>/dev/null || true
        ;;
      firewalld)
        install firewalld
        systemctl enable firewalld >/dev/null 2>&1 || true
        systemctl start firewalld >/dev/null 2>&1 || true
        firewall-cmd --state 2>/dev/null || true
        ;;
      fastfetch)
        root_use
        if command -v apt >/dev/null 2>&1; then
          DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt update -y
          DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt install -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            software-properties-common
          add-apt-repository -y ppa:zhangsongcui3371/fastfetch
          DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt update -y
          DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt install -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            fastfetch
        else
          install fastfetch
        fi
        fastfetch --version 2>/dev/null || true
        ;;
      yazi)
        install_yazi_griffo
        ;;
      nexttrace)
        install_nexttrace
        ;;
      git|curl|tree|wget|sudo|socat|htop|iftop|unzip|tar|tmux|ffmpeg|btop|ncdu|iperf3)
        install "$id"
        command -v "$id" >/dev/null 2>&1 && "$id" --version 2>/dev/null | head -n 1 || true
        ;;
      fail2ban)
        install fail2ban
        systemctl enable fail2ban >/dev/null 2>&1 || true
        systemctl start fail2ban >/dev/null 2>&1 || true
        fail2ban-client status 2>/dev/null || true
        ;;
      claude)
        install_claude_code_auto
        ;;
      codex)
        install_codex_cli
        ;;
      *) echo "未知工具: $id" ;;
    esac
  }

  remove_tool_by_id() {
    local id="$1"
    case "$id" in
      vim) remove_vim_editor_config; remove vim ;;
      cpcat) remove_cpcat_config; reload_bashrc_safely; echo "已删除 cpcat 配置" ;;
      ctrld) remove_ctrld_config; reload_bashrc_safely; echo "已删除 Ctrl+D 绑定" ;;
      starship) remove_starship_all ;;
      bat) remove_bat_all ;;
      btop) remove btop; rm -rf "$HOME/.config/btop" ;;
      yazi) remove_yazi_all ;;
      fastfetch)
        remove fastfetch
        if command -v add-apt-repository >/dev/null 2>&1; then
          add-apt-repository --remove -y ppa:zhangsongcui3371/fastfetch 2>/dev/null || true
          apt update -y 2>/dev/null || true
        fi
        rm -rf "$HOME/.config/fastfetch"
        ;;
      htop) remove htop; rm -rf "$HOME/.config/htop" "$HOME/.htoprc" ;;
      ripgrep) remove ripgrep ;;
      fd) remove_fd_alias; remove fd-find ;;
      fzf) remove_fzf_all ;;
      blesh) remove_blesh_all ;;
      nexttrace) remove_nexttrace_all ;;
      python) remove_python_312_all ;;
      npm|nodejs) remove_nvm_all ;;
      iptables-persistent) remove_iptables_persistent_all ;;
      ufw) remove_ufw_all ;;
      firewalld) remove_firewalld_all ;;
      fail2ban) remove_fail2ban_all ;;
      claude) remove_claude_code_all ;;
      codex) remove_codex_all ;;
      bun) rm -rf "$HOME/.bun"; sed -i '/bun\/bin/d' ~/.bashrc ~/.profile ~/.bash_profile 2>/dev/null || true; reload_shell_configs_safely ;;
      uv) rm -f "$HOME/.local/bin/uv" "$HOME/.local/bin/uvx"; reload_shell_configs_safely ;;
      *) remove "$id" ;;
    esac
  }

  handle_tool_numbers() {
    local action="$1"
    local input="$2"
    local n id failed=0
    for n in $input; do
      if ! [[ "$n" =~ ^[0-9]{1,3}$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt ${#tool_ids[@]} ]; then
        echo "跳过无效编号: $n"
        failed=1
        continue
      fi
      id="${tool_ids[$((10#$n-1))]}"
      if [ "$action" = "install" ]; then
        if ! install_tool_by_id "$id" || ! tool_installed "$id"; then
          echo "工具安装或验证失败: $id"
          failed=1
        fi
      else
        remove_tool_by_id "$id" || failed=1
      fi
    done
    return "$failed"
  }

  all_tool_numbers() {
    seq 1 ${#tool_ids[@]} | tr '\n' ' '
  }

  tool_category_menu() {
    local category_key="$1"
    local category_title="$2"
    local tool_ids=()
    local tool_names=()
    local tool_desc=()

    case "$category_key" in
      thirdparty)
        tool_ids=("${thirdparty_ids[@]}")
        tool_names=("${thirdparty_names[@]}")
        tool_desc=("${thirdparty_desc[@]}")
        ;;
      programming)
        tool_ids=("${programming_ids[@]}")
        tool_names=("${programming_names[@]}")
        tool_desc=("${programming_desc[@]}")
        ;;
      *)
        echo "未知分类: $category_key"
        break_end
        return
        ;;
    esac

    while true; do
      clear
      echo -e "$category_title"
      show_tool_status
      echo -e "${gl_kjlan}1.   ${gl_bai}安装工具（支持多选，输入工具编号，如: 1 4 6）"
      echo -e "${gl_kjlan}2.   ${gl_bai}卸载工具（支持多选，输入工具编号，如: 7 10）"
      echo -e "${gl_kjlan}3.   ${gl_bai}全部安装"
      echo -e "${gl_kjlan}4.   ${gl_bai}全部卸载"
      echo -e "${gl_kjlan}0.   ${gl_bai}返回上一级菜单"
      echo -e "${gl_kjlan}------------------------${gl_bai}"
      read -e -p "请输入你的选择: " sub_choice || return 1
      case $sub_choice in
        1)
          read -e -p "请输入要安装的工具编号（支持多选，空格分隔）: " nums || return 1
          handle_tool_numbers install "$nums" && [ -n "$nums" ] && restart_shell_after_tool_install
          ;;
        2)
          read -e -p "请输入要卸载的工具编号（支持多选，空格分隔）: " nums || return 1
          handle_tool_numbers remove "$nums"
          ;;
        3)
          nums="$(all_tool_numbers)"
          read -e -i "$nums" -p "请确认/修改要安装的工具编号（默认全选，空格分隔）: " nums || return 1
          handle_tool_numbers install "$nums" && [ -n "$nums" ] && restart_shell_after_tool_install
          ;;
        4)
          nums="$(all_tool_numbers)"
          read -e -i "$nums" -p "请确认/修改要卸载的工具编号（默认全选，空格分隔）: " nums || return 1
          read -e -p "确认卸载以上编号对应工具？(y/N): " confirm || return 1
          if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            handle_tool_numbers remove "$nums"
          else
            echo "已取消"
          fi
          ;;
        0) return ;;
        *) echo "无效的输入!" ;;
      esac
      break_end
    done
  }

  case "${1:-}" in
    thirdparty)
      tool_category_menu thirdparty "第三方工具"
      return
      ;;
    thirdparty-install-all)
      local tool_ids=("${thirdparty_ids[@]}")
      handle_tool_numbers install "$(seq 1 ${#tool_ids[@]} | tr '\n' ' ')" || return 1
      restart_shell_after_tool_install
      return
      ;;
    programming|basic)
      tool_category_menu programming "编程工具"
      return
      ;;
    programming-install-all)
      local tool_ids=("${programming_ids[@]}")
      handle_tool_numbers install "$(seq 1 ${#tool_ids[@]} | tr '\n' ' ')" || return 1
      restart_shell_after_tool_install
      return
      ;;
  esac

  while true; do
    clear
    echo -e "工具管理"
    echo -e "${gl_kjlan}1.   ${gl_bai}第三方工具"
    echo -e "${gl_kjlan}2.   ${gl_bai}编程工具"
    echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
    echo -e "${gl_kjlan}------------------------${gl_bai}"
    read -e -p "请输入你的选择: " sub_choice || return 1
    case $sub_choice in
      1) tool_category_menu thirdparty "第三方工具" ;;
      2) tool_category_menu programming "编程工具" ;;
      0) return ;;
      *) echo "无效的输入!"; break_end ;;
    esac
  done
}




linux_bbr() {
	clear
	send_stats "bbr管理"
	install wget curl
	mkdir -p "$DAIMON_SCRIPT_DIR"
	local tcpx="$DAIMON_SCRIPT_DIR/tcpx.sh" tmp
	local tcpx_url="https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcpx.sh"
	tmp=$(mktemp "$DAIMON_SCRIPT_DIR/tcpx.sh.tmp.XXXXXX") || return 1
	if daimon_download_to "$tcpx_url" "$tmp" && [ -s "$tmp" ] && bash -n "$tmp"; then
		chmod +x "$tmp"
		mv -f "$tmp" "$tcpx"
		echo -e "${gl_lv}BBR 管理脚本已更新到上游最新版${gl_bai}"
	else
		rm -f "$tmp"
		if [ ! -s "$tcpx" ] || ! bash -n "$tcpx"; then
			echo -e "${gl_hong}BBR 管理脚本下载失败，且没有可用缓存${gl_bai}"
			return 1
		fi
		echo -e "${gl_huang}上游更新失败，继续使用本地缓存: $tcpx${gl_bai}"
	fi
	chmod +x "$tcpx"
	bash "$tcpx"
}







docker_ssh_migration() {

	is_compose_container() {
		local container=$1
		docker inspect "$container" | jq -e '.[0].Config.Labels["com.docker.compose.project"]' >/dev/null 2>&1
	}

	docker_migration_list_backups() {
		local BACKUP_ROOT="/tmp"
		echo -e "${gl_kjlan}当前备份列表:${gl_bai}"
		ls -1dt ${BACKUP_ROOT}/docker_backup_* 2>/dev/null || echo "无备份"
	}



	# ----------------------------
	# 备份
	# ----------------------------
	docker_migration_backup() {
		send_stats "Docker备份"

		echo -e "${gl_kjlan}正在备份 Docker 容器...${gl_bai}"
		docker ps --format '{{.Names}}'
		read -e -p  "请输入要备份的容器名（多个空格分隔，回车备份全部运行中容器）: " containers || return 1

		install tar jq gzip
		install_docker

		local BACKUP_ROOT="/tmp"
		local DATE_STR=$(date +%Y%m%d_%H%M%S)
		local TARGET_CONTAINERS=()
		if [ -z "$containers" ]; then
			mapfile -t TARGET_CONTAINERS < <(docker ps --format '{{.Names}}')
		else
			read -ra TARGET_CONTAINERS <<< "$containers"
		fi
		[[ ${#TARGET_CONTAINERS[@]} -eq 0 ]] && { echo -e "${gl_hong}没有找到容器${gl_bai}"; return; }

		local BACKUP_DIR="${BACKUP_ROOT}/docker_backup_${DATE_STR}"
		mkdir -p "$BACKUP_DIR"
		chmod 700 "$BACKUP_DIR"

		local RESTORE_SCRIPT="${BACKUP_DIR}/docker_restore.sh"
		echo "#!/bin/bash" > "$RESTORE_SCRIPT"
		echo "set -e" >> "$RESTORE_SCRIPT"
		echo "# 自动生成的还原脚本" >> "$RESTORE_SCRIPT"

		# 记录已打包过的 Compose 项目路径，避免重复打包
		declare -A PACKED_COMPOSE_PATHS=()

		for c in "${TARGET_CONTAINERS[@]}"; do
			echo -e "${gl_lv}备份容器: $c${gl_bai}"
			local inspect_file="${BACKUP_DIR}/${c}_inspect.json"
			docker inspect "$c" > "$inspect_file"

			if is_compose_container "$c"; then
				echo -e "${gl_kjlan}检测到 $c 是 docker-compose 容器${gl_bai}"
				local project_dir=$(docker inspect "$c" | jq -r '.[0].Config.Labels["com.docker.compose.project.working_dir"] // empty')
				local project_name=$(docker inspect "$c" | jq -r '.[0].Config.Labels["com.docker.compose.project"] // empty')

				if [ -z "$project_dir" ]; then
					read -e -p  "未检测到 compose 目录，请手动输入路径: " project_dir || return 1
				fi

				# 如果该 Compose 项目已经打包过，跳过
				if [[ -n "${PACKED_COMPOSE_PATHS[$project_dir]}" ]]; then
					echo -e "${gl_huang}Compose 项目 [$project_name] 已备份过，跳过重复打包...${gl_bai}"
					continue
				fi

				if [ -f "$project_dir/docker-compose.yml" ]; then
					echo "compose" > "${BACKUP_DIR}/backup_type_${project_name}"
					echo "$project_dir" > "${BACKUP_DIR}/compose_path_${project_name}.txt"
					tar -czf "${BACKUP_DIR}/compose_project_${project_name}.tar.gz" -C "$project_dir" .
					echo "# docker-compose 恢复: $project_name" >> "$RESTORE_SCRIPT"
					echo "cd \"$project_dir\" && docker compose up -d" >> "$RESTORE_SCRIPT"
					PACKED_COMPOSE_PATHS["$project_dir"]=1
					echo -e "${gl_lv}Compose 项目 [$project_name] 已打包: ${project_dir}${gl_bai}"
				else
					echo -e "${gl_hong}未找到 docker-compose.yml，跳过此容器...${gl_bai}"
				fi
			else
				# 普通容器备份卷
				local VOL_PATHS
				VOL_PATHS=$(docker inspect "$c" --format '{{range .Mounts}}{{.Source}} {{end}}')
				for path in $VOL_PATHS; do
					echo "打包卷: $path"
					tar -czpf "${BACKUP_DIR}/${c}_$(basename $path).tar.gz" -C / "$(echo $path | sed 's/^\///')"
				done

				# 端口
				local PORT_ARGS=""
				mapfile -t PORTS < <(jq -r '.[0].HostConfig.PortBindings | to_entries[] | "\(.value[0].HostPort):\(.key | split("/")[0])"' "$inspect_file" 2>/dev/null)
				for p in "${PORTS[@]}"; do PORT_ARGS+="-p $p "; done

				# 环境变量
				local ENV_VARS=""
				mapfile -t ENVS < <(jq -r '.[0].Config.Env[] | @sh' "$inspect_file")
				for e in "${ENVS[@]}"; do ENV_VARS+="-e $e "; done

				# 卷映射
				local VOL_ARGS=""
				for path in $VOL_PATHS; do VOL_ARGS+="-v $path:$path "; done

				# 镜像
				local IMAGE
				IMAGE=$(jq -r '.[0].Config.Image' "$inspect_file")

				echo -e "\n# 还原容器: $c" >> "$RESTORE_SCRIPT"
				echo "docker run -d --name $c $PORT_ARGS $VOL_ARGS $ENV_VARS $IMAGE" >> "$RESTORE_SCRIPT"
			fi
		done


		# 备份 /home/docker 下的所有文件（不含子目录）
		if [ -d "/home/docker" ]; then
			echo -e "${gl_kjlan}备份 /home/docker 下的文件...${gl_bai}"
			find /home/docker -maxdepth 1 -type f | tar -czf "${BACKUP_DIR}/home_docker_files.tar.gz" -T -
			echo -e "${gl_lv}/home/docker 下的文件已打包到: ${BACKUP_DIR}/home_docker_files.tar.gz${gl_bai}"
		fi

		find "$BACKUP_DIR" -type f -exec chmod 600 {} +; chmod 700 "$RESTORE_SCRIPT"
		echo -e "${gl_lv}备份完成: ${BACKUP_DIR}${gl_bai}"
		echo -e "${gl_lv}可用还原脚本: ${RESTORE_SCRIPT}${gl_bai}"


	}

	# ----------------------------
	# 还原
	# ----------------------------
	docker_migration_restore() {

		send_stats "Docker还原"
		read -e -p  "请输入要还原的备份目录: " BACKUP_DIR || return 1
		[[ ! -d "$BACKUP_DIR" || "$BACKUP_DIR" != /tmp/docker_backup_* ]] && { echo -e "${gl_hong}备份目录不存在或路径不受支持${gl_bai}"; return; }

		echo -e "${gl_kjlan}开始执行还原操作...${gl_bai}"

		install tar jq gzip
		install_docker

		# --------- 优先还原 Compose 项目 ---------
		for f in "$BACKUP_DIR"/backup_type_*; do
			[[ ! -f "$f" ]] && continue
			if grep -q "compose" "$f"; then
				project_name=$(basename "$f" | sed 's/backup_type_//')
				path_file="$BACKUP_DIR/compose_path_${project_name}.txt"
				[[ -f "$path_file" ]] && original_path=$(cat "$path_file") || original_path=""
				[[ -z "$original_path" ]] && read -e -p  "未找到原始路径，请输入还原目录路径: " original_path

				# 检查该 compose 项目的容器是否已经在运行
				running_count=$(docker ps --filter "label=com.docker.compose.project=$project_name" --format '{{.Names}}' | wc -l)
				if [[ "$running_count" -gt 0 ]]; then
					echo -e "${gl_huang}Compose 项目 [$project_name] 已有容器在运行，跳过还原...${gl_bai}"
					continue
				fi

				read -e -p  "确认还原 Compose 项目 [$project_name] 到路径 [$original_path] ? (y/n): " confirm || return 1
				[[ "$confirm" != "y" ]] && read -e -p  "请输入新的还原路径: " original_path

				mkdir -p "$original_path"
				tar -xzf "$BACKUP_DIR/compose_project_${project_name}.tar.gz" -C "$original_path"
				echo -e "${gl_lv}Compose 项目 [$project_name] 已解压到: $original_path${gl_bai}"

				cd "$original_path" || return
				docker compose down || true
				docker compose up -d
				echo -e "${gl_lv}Compose 项目 [$project_name] 还原完成！${gl_bai}"
			fi
		done

		# --------- 继续还原普通容器 ---------
		echo -e "${gl_kjlan}检查并还原普通 Docker 容器...${gl_bai}"
		local has_container=false
		for json in "$BACKUP_DIR"/*_inspect.json; do
			[[ ! -f "$json" ]] && continue
			has_container=true
			container=$(basename "$json" | sed 's/_inspect.json//')
			echo -e "${gl_lv}处理容器: $container${gl_bai}"

			# 检查容器是否已经存在且正在运行
			if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
				echo -e "${gl_huang}容器 [$container] 已在运行，跳过还原...${gl_bai}"
				continue
			fi

			IMAGE=$(jq -r '.[0].Config.Image' "$json")
			[[ -z "$IMAGE" || "$IMAGE" == "null" ]] && { echo -e "${gl_hong}未找到镜像信息，跳过: $container${gl_bai}"; continue; }

			# 端口映射
			PORT_ARGS=""
			mapfile -t PORTS < <(jq -r '.[0].HostConfig.PortBindings | to_entries[]? | "\(.value[0].HostPort):\(.key | split("/")[0])"' "$json")
			for p in "${PORTS[@]}"; do
				[[ -n "$p" ]] && PORT_ARGS="$PORT_ARGS -p $p"
			done

			# 环境变量
			ENV_ARGS=""
			mapfile -t ENVS < <(jq -r '.[0].Config.Env[]' "$json")
			for e in "${ENVS[@]}"; do
				ENV_ARGS="$ENV_ARGS -e \"$e\""
			done

			# 卷映射 + 卷数据恢复
			VOL_ARGS=""
			mapfile -t VOLS < <(jq -r '.[0].Mounts[] | "\(.Source):\(.Destination)"' "$json")
			for v in "${VOLS[@]}"; do
				VOL_SRC=$(echo "$v" | cut -d':' -f1)
				VOL_DST=$(echo "$v" | cut -d':' -f2)
				mkdir -p "$VOL_SRC"
				VOL_ARGS="$VOL_ARGS -v $VOL_SRC:$VOL_DST"

				VOL_FILE="$BACKUP_DIR/${container}_$(basename $VOL_SRC).tar.gz"
				if [[ -f "$VOL_FILE" ]]; then
					echo "恢复卷数据: $VOL_SRC"
					tar -tzf "$VOL_FILE" >/dev/null 2>&1 || { echo "归档校验失败: $VOL_FILE"; continue; }
					tar --extract --gzip --file "$VOL_FILE" --directory / --no-same-owner
				fi
			done

			# 删除已存在但未运行的容器
			if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
				echo -e "${gl_huang}容器 [$container] 存在但未运行，删除旧容器...${gl_bai}"
				docker rm -f "$container"
			fi

			# 启动容器
			echo "执行还原命令: docker run -d --name \"$container\" $PORT_ARGS $VOL_ARGS $ENV_ARGS \"$IMAGE\""
			local -a run_args=(run -d --name "$container")
			for p in "${PORTS[@]}"; do [ -n "$p" ] && run_args+=( -p "$p" ); done
			for e in "${ENVS[@]}"; do [ -n "$e" ] && run_args+=( -e "$e" ); done
			for v in "${VOLS[@]}"; do [ -n "$v" ] && run_args+=( -v "$v" ); done
			run_args+=("$IMAGE")
			docker "${run_args[@]}"
		done

		[[ "$has_container" == false ]] && echo -e "${gl_huang}未找到普通容器的备份信息${gl_bai}"

		# 还原 /home/docker 下的文件
		if [ -f "$BACKUP_DIR/home_docker_files.tar.gz" ]; then
			echo -e "${gl_kjlan}正在还原 /home/docker 下的文件...${gl_bai}"
			mkdir -p /home/docker
			tar -xzf "$BACKUP_DIR/home_docker_files.tar.gz" -C /
			echo -e "${gl_lv}/home/docker 下的文件已还原完成${gl_bai}"
		else
			echo -e "${gl_huang}未找到 /home/docker 下文件的备份，跳过...${gl_bai}"
		fi


	}


	# ----------------------------
	# 迁移
	# ----------------------------
	docker_migration_migrate() {
		send_stats "Docker迁移"
		install jq
		read -e -p  "请输入要迁移的备份目录: " BACKUP_DIR || return 1
			[[ ! -d "$BACKUP_DIR" || "$BACKUP_DIR" != /tmp/docker_backup_* ]] && { echo -e "${gl_hong}备份目录不存在或路径不受支持${gl_bai}"; return; }

		kj_ssh_read_host_user_port "目标服务器IP: " "目标服务器SSH用户名 [默认root]: " "目标服务器SSH端口 [默认22]: " "root" "22"
		local TARGET_IP="$KJ_SSH_HOST"
		local TARGET_USER="$KJ_SSH_USER"
		local TARGET_PORT="$KJ_SSH_PORT"

		local LATEST_TAR="$BACKUP_DIR"

		echo -e "${gl_huang}传输备份中...${gl_bai}"
		if [[ -z "$TARGET_PASS" ]]; then
			# 使用密钥登录
			if ! scp -P "$TARGET_PORT" -o StrictHostKeyChecking=no -r "$LATEST_TAR" "$TARGET_USER@$TARGET_IP:/tmp/"; then
				echo -e "${gl_hong}迁移失败，请检查 SSH 连接${gl_bai}"; return 1
			fi
			echo -e "${gl_lv}迁移完成${gl_bai}"
		fi

	}

	# ----------------------------
	# 删除备份
	# ----------------------------
	docker_migration_delete_backup() {
		send_stats "Docker备份文件删除"
		read -e -p  "请输入要删除的备份目录: " BACKUP_DIR || return 1
		[[ ! -d "$BACKUP_DIR" || "$BACKUP_DIR" != /tmp/docker_backup_* ]] && { echo -e "${gl_hong}备份目录不存在或路径不受支持${gl_bai}"; return; }
		read -e -p "确认删除 $BACKUP_DIR？[y/N]: " confirm || return 1
		[[ "$confirm" != "y" && "$confirm" != "Y" ]] && return 0
		rm -rf "$BACKUP_DIR"
		echo -e "${gl_lv}已删除备份: ${BACKUP_DIR}${gl_bai}"
	}

	# ----------------------------
	# 主菜单
	# ----------------------------
	main_menu() {
		send_stats "Docker备份迁移还原"
		while true; do
			clear
			echo "------------------------"
			echo -e "Docker备份/迁移/还原工具"
			echo "------------------------"
			docker_migration_list_backups
			echo -e ""
			echo "------------------------"
			echo -e "1. 备份docker项目"
			echo -e "2. 迁移docker项目"
			echo -e "3. 还原docker项目"
			echo -e "4. 删除docker项目的备份文件"
			echo "------------------------"
			echo -e "0. 返回上一级选单"
			echo "------------------------"
			read -e -p  "请选择: " choice || return 1
			case $choice in
				1) docker_migration_backup ;;
				2) docker_migration_migrate ;;
				3) docker_migration_restore ;;
				4) docker_migration_delete_backup ;;
				0) return ;;
				*) echo -e "${gl_hong}无效选项${gl_bai}" ;;
			esac
		break_end
		done
	}

	main_menu
}





docker_compose_update_script_dir() {
	echo "${DAIMON_DOCKER_COMPOSE_UPDATE_DIR:-/root/linux-daimon/docker-compose-update}"
}

docker_compose_update_log_dir() {
	echo "/var/log/docker-compose-update"
}

docker_compose_update_sanitize_name() {
	echo "$1" | sed 's/[[:space:]\/\\:]/_/g; s/[^A-Za-z0-9_.-]/_/g'
}

docker_compose_update_project_id() {
	local project="$1"
	local workdir="$2"
	local config_files="$3"
	local digest
	if command -v sha256sum >/dev/null 2>&1; then
		digest=$(printf '%s\0%s\0%s' "$project" "$workdir" "$config_files" | sha256sum | awk '{print $1}')
	else
		digest=$(printf '%s\0%s\0%s' "$project" "$workdir" "$config_files" | cksum | awk '{print $1}')
	fi
	printf '%.12s\n' "$digest"
}

docker_compose_update_discover_projects() {
	command -v docker >/dev/null 2>&1 || return 0
	local name project workdir config_files first_config key
	local -A project_map
	while IFS= read -r name; do
		[ -n "$name" ] || continue
		project=$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$name" 2>/dev/null || true)
		workdir=$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' "$name" 2>/dev/null || true)
		config_files=$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.project.config_files" }}' "$name" 2>/dev/null || true)
		[ "$project" = "<no value>" ] && project=""
		[ "$workdir" = "<no value>" ] && workdir=""
		[ "$config_files" = "<no value>" ] && config_files=""
		if [ -z "$workdir" ] && [ -n "$config_files" ]; then
			first_config="${config_files%%,*}"
			workdir=$(dirname "$first_config" 2>/dev/null || true)
		fi
		if [ -z "$project" ] || [ -z "$workdir" ]; then
			continue
		fi
		key="${project}"$'\034'"${workdir}"$'\034'"${config_files}"
		project_map["$key"]=$(printf '%s\t%s\t%s' "$project" "$workdir" "$config_files")
	done < <(docker ps -a --format '{{.Names}}' 2>/dev/null || true)
	for key in "${!project_map[@]}"; do
		printf '%s\n' "${project_map[$key]}"
	done | sort
}

docker_compose_update_script_file() {
	local project="$1"
	local workdir="$2"
	local config_files="${3:-}"
	local safe_project project_id
	safe_project=$(docker_compose_update_sanitize_name "$project")
	project_id=$(docker_compose_update_project_id "$project" "$workdir" "$config_files")
	echo "$(docker_compose_update_script_dir)/compose_update_${safe_project}_${project_id}.sh"
}

docker_compose_update_legacy_script_file() {
	local project="$1"
	local workdir="$2"
	local safe_project safe_path
	safe_project=$(docker_compose_update_sanitize_name "$project")
	safe_path=$(docker_compose_update_sanitize_name "$workdir")
	echo "$(docker_compose_update_script_dir)/compose_update_${safe_project}_${safe_path}.sh"
}

docker_compose_update_cron_line() {
	local script_file="$1"
	local idx="${2:-1}"
	local minute hour
	minute=$(( (idx * 7) % 60 ))
	hour=$(( 3 + ((idx - 1) / 8) ))
	[ "$hour" -gt 6 ] && hour=6
	printf "%d %d * * * /bin/bash %s >> %s/cron_%s.log 2>&1" \
		"$minute" "$hour" "$script_file" "$(docker_compose_update_log_dir)" "$(basename "$script_file" .sh)"
}

docker_compose_update_status_text() {
	local script_file="$1"
	local legacy_script_file="$2"
	local project_id="$3"
	local cron_output=""
	cron_output=$(crontab -l 2>/dev/null || true)
	if [ -f "$script_file" ] && printf '%s\n' "$cron_output" | grep -Fq "$script_file"; then
		if bash -n "$script_file" 2>/dev/null && grep -Fqx "# compose-update-id: $project_id" "$script_file"; then
			echo -e "${gl_lv}已配置${gl_bai}"
		else
			echo -e "${gl_hong}脚本异常，请重新安装${gl_bai}"
		fi
	elif [ "$legacy_script_file" != "$script_file" ] && { [ -f "$legacy_script_file" ] || printf '%s\n' "$cron_output" | grep -Fq "$legacy_script_file"; }; then
		echo -e "${gl_huang}旧版任务，需重新安装${gl_bai}"
	elif [ -f "$script_file" ]; then
		echo -e "${gl_huang}脚本已存在，未加入定时${gl_bai}"
	elif printf '%s\n' "$cron_output" | grep -Fq "$script_file"; then
		echo -e "${gl_huang}定时任务存在，脚本不存在${gl_bai}"
	else
		echo -e "${gl_hong}未配置${gl_bai}"
	fi
}

docker_compose_update_show_status() {
	local idx=0 project workdir config_files script_file legacy_script_file project_id
	echo -e "${gl_kjlan}------------------------${gl_bai}"
	echo "Docker Compose 项目列表"
	echo -e "${gl_kjlan}------------------------${gl_bai}"
	while IFS=$'\t' read -r project workdir config_files; do
		[ -z "$project" ] && continue
		idx=$((idx + 1))
		project_id=$(docker_compose_update_project_id "$project" "$workdir" "$config_files")
		script_file=$(docker_compose_update_script_file "$project" "$workdir" "$config_files")
		legacy_script_file=$(docker_compose_update_legacy_script_file "$project" "$workdir")
		printf "%2d. %-24s %-42s %b\n" "$idx" "$project" "$(docker_compose_update_status_text "$script_file" "$legacy_script_file" "$project_id")" ""
		echo "    路径: $workdir"
		[ -n "$config_files" ] && echo "    配置: $config_files"
	done < <(docker_compose_update_discover_projects)
	if [ "$idx" -eq 0 ]; then
		echo -e "${gl_huang}未检测到带 com.docker.compose.* 标签的 Docker Compose 项目。${gl_bai}"
	fi
	echo -e "${gl_kjlan}------------------------${gl_bai}"
	echo "所有 Docker 容器"
	docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' 2>/dev/null || true
	docker_compose_update_show_orphans
	echo -e "${gl_kjlan}------------------------${gl_bai}"
}

docker_compose_update_get_item_by_number() {
	local target="$1"
	local idx=0 project workdir config_files
	while IFS=$'\t' read -r project workdir config_files; do
		[ -z "$project" ] && continue
		idx=$((idx + 1))
		if [ "$idx" -eq "$target" ]; then
			printf '%s\t%s\t%s\t%s\n' "$idx" "$project" "$workdir" "$config_files"
			return 0
		fi
	done < <(docker_compose_update_discover_projects)
	return 1
}

docker_compose_update_all_numbers() {
	local idx=0 project workdir config_files
	while IFS=$'\t' read -r project workdir config_files; do
		[ -z "$project" ] && continue
		idx=$((idx + 1))
		printf "%s " "$idx"
	done < <(docker_compose_update_discover_projects)
}

docker_compose_update_write_script() {
	local project="$1"
	local workdir="$2"
	local config_files="$3"
	local script_file="$4"
	local project_id="$5"
	local temp_file
	mkdir -p "$(dirname "$script_file")" "$(docker_compose_update_log_dir)" || return 1
	temp_file=$(mktemp "${script_file}.tmp.XXXXXX") || return 1
	if ! {
		cat <<'EOF'
#!/bin/bash
set -Eeuo pipefail
umask 077
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF
		printf '# compose-update-id: %s\n' "$project_id"
		printf 'COMPOSE_UPDATE_ID=%q\n' "$project_id"
		printf 'COMPOSE_PROJECT=%q\n' "$project"
		printf 'COMPOSE_PATH=%q\n' "$workdir"
		printf 'COMPOSE_CONFIG_FILES=%q\n' "$config_files"
		cat <<'EOF'
WAIT_TIMEOUT="${COMPOSE_UPDATE_WAIT_TIMEOUT:-120}"
LOCK_FILE="/run/lock/docker-compose-update-${COMPOSE_UPDATE_ID}.lock"
LOCK_DIR="${LOCK_FILE}.d"
COMPOSE_ARGS=(-p "$COMPOSE_PROJECT")
TARGET_SERVICES=()
declare -A PREVIOUS_IMAGES=()
ROLLBACK_READY=true

log() {
	printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
	log "错误: $*"
	exit 1
}

release_fallback_lock() {
	[ "${USING_FALLBACK_LOCK:-false}" = "true" ] && rmdir "$LOCK_DIR" 2>/dev/null || true
}

run_compose() {
	docker compose "${COMPOSE_ARGS[@]}" "$@"
}

restore_previous_images() {
	local image failed=0
	[ "$ROLLBACK_READY" = "true" ] || return 1
	[ "${#PREVIOUS_IMAGES[@]}" -gt 0 ] || return 1
	for image in "${!PREVIOUS_IMAGES[@]}"; do
		if ! docker image tag "${PREVIOUS_IMAGES[$image]}" "$image" >/dev/null; then
			failed=1
		fi
	done
	return "$failed"
}

start_services() {
	local recreate="${1:-false}"
	local args=(up -d --no-deps --wait --wait-timeout "$WAIT_TIMEOUT")
	[ "$recreate" = "true" ] && args+=(--force-recreate)
	[ "${#TARGET_SERVICES[@]}" -gt 0 ] && args+=("${TARGET_SERVICES[@]}")
	run_compose "${args[@]}"
}

case "$WAIT_TIMEOUT" in
	''|*[!0-9]*) fail "COMPOSE_UPDATE_WAIT_TIMEOUT 必须是正整数" ;;
	0) fail "COMPOSE_UPDATE_WAIT_TIMEOUT 必须大于 0" ;;
esac

mkdir -p /run/lock || fail "无法创建锁目录"
if command -v flock >/dev/null 2>&1; then
	exec 9>"$LOCK_FILE" || fail "无法打开锁文件"
	if ! flock -n 9; then
		log "已有更新任务正在运行，本次跳过"
		exit 0
	fi
else
	if ! mkdir "$LOCK_DIR" 2>/dev/null; then
		log "已有更新任务正在运行，本次跳过"
		exit 0
	fi
	USING_FALLBACK_LOCK=true
	trap release_fallback_lock EXIT
fi

command -v docker >/dev/null 2>&1 || fail "未找到 docker 命令"
docker compose version >/dev/null 2>&1 || fail "Docker Compose 插件不可用"
run_compose up --help 2>/dev/null | grep -q -- '--wait' || fail "Docker Compose 版本过旧，不支持健康等待"
[ -d "$COMPOSE_PATH" ] || fail "项目目录不存在: $COMPOSE_PATH"
cd "$COMPOSE_PATH" || fail "无法进入项目目录: $COMPOSE_PATH"

if [ -n "$COMPOSE_CONFIG_FILES" ]; then
	IFS=',' read -r -a config_files <<< "$COMPOSE_CONFIG_FILES"
	for config_file in "${config_files[@]}"; do
		[ -f "$config_file" ] || fail "Compose 配置不存在: $config_file"
		COMPOSE_ARGS+=(-f "$config_file")
	done
fi

running_services=$(run_compose ps --services --status running 2>/dev/null) || fail "无法读取 Compose 项目状态"
mapfile -t TARGET_SERVICES < <(printf '%s\n' "$running_services" | sed '/^[[:space:]]*$/d' | sort -u)
log "开始更新项目: $COMPOSE_PROJECT"
log "项目路径: $COMPOSE_PATH"
[ -n "$COMPOSE_CONFIG_FILES" ] && log "配置文件: $COMPOSE_CONFIG_FILES"
if [ "${#TARGET_SERVICES[@]}" -gt 0 ]; then
	log "当前运行服务: ${TARGET_SERVICES[*]}"
else
	log "未检测到运行中的服务，为保留停服状态，本次跳过"
	exit 0
fi

config_command=(config --images)
image_output=$(run_compose "${config_command[@]}" 2>/dev/null) || fail "无法解析 Compose 镜像配置"
while IFS= read -r image; do
	[ -n "$image" ] || continue
	case "$image" in *@sha256:*) continue ;; esac
	image_id=$(docker image inspect -f '{{.Id}}' "$image" 2>/dev/null || true)
	if [ -n "$image_id" ]; then
		PREVIOUS_IMAGES["$image"]="$image_id"
	else
		ROLLBACK_READY=false
	fi
done < <(printf '%s\n' "$image_output" | sort -u)

pull_command=(pull)
run_compose pull --help 2>/dev/null | grep -q -- '--ignore-buildable' && pull_command+=(--ignore-buildable)
[ "${#TARGET_SERVICES[@]}" -gt 0 ] && pull_command+=("${TARGET_SERVICES[@]}")
log "正在拉取镜像"
if ! run_compose "${pull_command[@]}"; then
	restore_previous_images || log "警告: 部分旧镜像标签恢复失败"
	fail "镜像拉取失败，现有容器保持运行"
fi

log "正在应用更新"
if ! start_services false; then
	log "更新启动或健康检查失败，开始恢复旧镜像"
	if restore_previous_images && start_services true; then
		fail "更新失败，已恢复到更新前镜像"
	fi
	fail "更新失败，自动恢复也未成功，请立即检查容器"
fi

log "更新成功"
EOF
	} > "$temp_file"; then
		rm -f "$temp_file"
		return 1
	fi
	if ! bash -n "$temp_file" || ! chmod 700 "$temp_file" || ! mv -f "$temp_file" "$script_file"; then
		rm -f "$temp_file"
		return 1
	fi
}

docker_compose_update_ensure_logrotate() {
	local config_file="/etc/logrotate.d/docker-compose-update"
	local temp_file
	temp_file=$(mktemp "${config_file}.tmp.XXXXXX") || return 1
	if ! cat > "$temp_file" <<'EOF'
/var/log/docker-compose-update/*.log {
    daily
    rotate 14
    maxsize 10M
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    create 0600 root root
}
EOF
	then
		rm -f "$temp_file"
		return 1
	fi
	chmod 644 "$temp_file" && mv -f "$temp_file" "$config_file" || {
		rm -f "$temp_file"
		return 1
	}
}

docker_compose_update_update_crontab() {
	local action="$1"
	local script_file="$2"
	local legacy_script_file="$3"
	local cron_line="${4:-}"
	local lock_file="/run/lock/linux-daimon-crontab.lock"
	local current_file current_error next_file lock_fd
	mkdir -p /run/lock || return 1
	exec {lock_fd}>"$lock_file" || return 1
	if command -v flock >/dev/null 2>&1 && ! flock "$lock_fd"; then
		exec {lock_fd}>&-
		return 1
	fi
	current_file=$(mktemp) || { exec {lock_fd}>&-; return 1; }
	current_error=$(mktemp) || { rm -f "$current_file"; exec {lock_fd}>&-; return 1; }
	next_file=$(mktemp) || { rm -f "$current_file" "$current_error"; exec {lock_fd}>&-; return 1; }
	if ! LC_ALL=C crontab -l > "$current_file" 2> "$current_error"; then
		if grep -Fqi "no crontab for" "$current_error"; then
			: > "$current_file"
		else
			rm -f "$current_file" "$current_error" "$next_file"
			exec {lock_fd}>&-
			return 1
		fi
	fi
	awk -v current="$script_file" -v legacy="$legacy_script_file" '
		index($0, current) == 0 && (legacy == current || index($0, legacy) == 0) { print }
	' "$current_file" > "$next_file"
	[ "$action" = "install" ] && printf '%s\n' "$cron_line" >> "$next_file"
	if ! crontab "$next_file"; then
		rm -f "$current_file" "$current_error" "$next_file"
		exec {lock_fd}>&-
		return 1
	fi
	rm -f "$current_file" "$current_error" "$next_file"
	exec {lock_fd}>&-
}

docker_compose_update_install_one() {
	local idx="$1"
	local project="$2"
	local workdir="$3"
	local config_files="$4"
	local script_file legacy_script_file cron_line project_id config_file
	local -a compose_config_files
	root_use
	check_crontab_installed
	if ! docker compose version >/dev/null 2>&1; then
		echo -e "${gl_hong}Docker Compose 插件不可用，无法配置自动更新。${gl_bai}"
		return 1
	fi
	if ! docker compose up --help 2>/dev/null | grep -q -- '--wait'; then
		echo -e "${gl_hong}Docker Compose 版本过旧，不支持健康等待，请先更新 Docker。${gl_bai}"
		return 1
	fi
	if [ ! -d "$workdir" ]; then
		echo -e "${gl_hong}项目目录不存在: $workdir${gl_bai}"
		return 1
	fi
	if [ -n "$config_files" ]; then
		IFS=',' read -r -a compose_config_files <<< "$config_files"
		for config_file in "${compose_config_files[@]}"; do
			if [ "${config_file#/}" = "$config_file" ]; then
				config_file="$workdir/$config_file"
			fi
			if [ ! -f "$config_file" ]; then
				echo -e "${gl_hong}Compose 配置不存在: $config_file${gl_bai}"
				return 1
			fi
		done
	fi
	project_id=$(docker_compose_update_project_id "$project" "$workdir" "$config_files")
	script_file=$(docker_compose_update_script_file "$project" "$workdir" "$config_files")
	legacy_script_file=$(docker_compose_update_legacy_script_file "$project" "$workdir")
	cron_line=$(docker_compose_update_cron_line "$script_file" "$idx")
	if ! docker_compose_update_write_script "$project" "$workdir" "$config_files" "$script_file" "$project_id"; then
		echo -e "${gl_hong}自动更新脚本写入失败: $project${gl_bai}"
		return 1
	fi
	if ! docker_compose_update_update_crontab install "$script_file" "$legacy_script_file" "$cron_line"; then
		echo -e "${gl_hong}crontab 写入失败，脚本已保留但不会定时执行。${gl_bai}"
		return 1
	fi
	[ "$legacy_script_file" != "$script_file" ] && rm -f "$legacy_script_file"
	if ! docker_compose_update_ensure_logrotate; then
		echo -e "${gl_huang}警告: 日志轮转配置失败，请检查 /etc/logrotate.d。${gl_bai}"
	fi
	echo -e "${gl_lv}已配置 Docker Compose 自动更新: $project${gl_bai}"
	echo "脚本: $script_file"
	echo "定时: $cron_line"
}

docker_compose_update_remove_one() {
	local project="$1"
	local workdir="$2"
	local config_files="$3"
	local script_file legacy_script_file
	root_use
	script_file=$(docker_compose_update_script_file "$project" "$workdir" "$config_files")
	legacy_script_file=$(docker_compose_update_legacy_script_file "$project" "$workdir")
	if ! docker_compose_update_update_crontab remove "$script_file" "$legacy_script_file"; then
		echo -e "${gl_hong}crontab 更新失败，未删除自动更新脚本。${gl_bai}"
		return 1
	fi
	if ! rm -f "$script_file" "$legacy_script_file"; then
		echo -e "${gl_hong}自动更新脚本删除失败: $project${gl_bai}"
		return 1
	fi
	echo -e "${gl_lv}已卸载 Docker Compose 自动更新: $project${gl_bai}"
}

docker_compose_update_expected_files() {
	local project workdir config_files
	while IFS=$'\t' read -r project workdir config_files; do
		[ -n "$project" ] || continue
		docker_compose_update_script_file "$project" "$workdir" "$config_files"
		docker_compose_update_legacy_script_file "$project" "$workdir"
	done < <(docker_compose_update_discover_projects)
}

docker_compose_update_cron_script_files() {
	local script_dir
	script_dir=$(docker_compose_update_script_dir)
	crontab -l 2>/dev/null | awk -v prefix="$script_dir/compose_update_" '
		{
			for (i = 1; i <= NF; i++) {
				if (index($i, prefix) == 1 && $i ~ /\.sh$/) print $i
			}
		}
	' | sort -u
}

docker_compose_update_orphan_files() {
	local file
	local -A expected
	while IFS= read -r file; do
		[ -n "$file" ] && expected["$file"]=1
	done < <(docker_compose_update_expected_files)
	{
		find "$(docker_compose_update_script_dir)" -maxdepth 1 -type f -name 'compose_update_*.sh' -print 2>/dev/null
		docker_compose_update_cron_script_files
	} | sort -u | while IFS= read -r file; do
		[ -n "$file" ] || continue
		[ -n "${expected[$file]:-}" ] || printf '%s\n' "$file"
	done
}

docker_compose_update_show_orphans() {
	local file count=0
	while IFS= read -r file; do
		[ -n "$file" ] || continue
		if [ "$count" -eq 0 ]; then
			echo -e "${gl_huang}失效或已删除项目的自动更新任务:${gl_bai}"
		fi
		count=$((count + 1))
		echo "    $file"
	done < <(docker_compose_update_orphan_files)
}

docker_compose_update_cleanup_orphans() {
	local file script_dir
	local -a orphan_files=()
	mapfile -t orphan_files < <(docker_compose_update_orphan_files)
	if [ "${#orphan_files[@]}" -eq 0 ]; then
		echo -e "${gl_lv}没有失效任务。${gl_bai}"
		return 0
	fi
	read -e -p "确认删除以上 ${#orphan_files[@]} 个失效任务？(y/N): " confirm || return 1
	if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
		echo "已取消"
		return 0
	fi
	script_dir="$(docker_compose_update_script_dir)/"
	for file in "${orphan_files[@]}"; do
		case "$file" in
			"${script_dir}"compose_update_*.sh) ;;
			*) echo -e "${gl_hong}跳过非托管路径: $file${gl_bai}"; continue ;;
		esac
		if ! docker_compose_update_update_crontab remove "$file" "$file"; then
			echo -e "${gl_hong}失效任务的 crontab 清理失败: $file${gl_bai}"
			return 1
		fi
		rm -f "$file" || return 1
	done
	echo -e "${gl_lv}失效任务已清理。${gl_bai}"
}

docker_compose_update_handle_numbers() {
	local action="$1"
	local nums="$2"
	local n item idx project workdir config_files
	for n in $nums; do
		if ! [[ "$n" =~ ^[0-9]+$ ]]; then
			echo "跳过无效编号: $n"
			continue
		fi
		if ! item=$(docker_compose_update_get_item_by_number "$n"); then
			echo "跳过无效编号: $n"
			continue
		fi
		IFS=$'\t' read -r idx project workdir config_files <<< "$item"
		if [ "$action" = "install" ]; then
			docker_compose_update_install_one "$idx" "$project" "$workdir" "$config_files"
		else
			docker_compose_update_remove_one "$project" "$workdir" "$config_files"
		fi
	done
}

docker_compose_auto_update_manager() {
	if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
		echo -e "${gl_hong}未检测到 Docker，请先安装 Docker。${gl_bai}"
		return 1
	fi
	while true; do
		clear
		echo -e "Docker Compose 自动更新"
		echo -e "脚本目录: ${gl_kjlan}$(docker_compose_update_script_dir)${gl_bai}"
		echo -e "日志目录: ${gl_kjlan}$(docker_compose_update_log_dir)${gl_bai}"
		docker_compose_update_show_status
		echo -e "${gl_kjlan}1.   ${gl_bai}安装自动更新（支持多选，输入编号，如: 1 2）"
		echo -e "${gl_kjlan}2.   ${gl_bai}卸载自动更新（支持多选，输入编号，如: 2 4）"
		echo -e "${gl_kjlan}3.   ${gl_bai}一键安装（默认全选，可自行删除编号）"
		echo -e "${gl_kjlan}4.   ${gl_bai}一键卸载（默认全选，可自行删除编号）"
		echo -e "${gl_kjlan}5.   ${gl_bai}清理失效或已删除项目的任务"
		echo -e "${gl_kjlan}0.   ${gl_bai}返回上一级菜单"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		read -e -p "请输入你的选择: " sub_choice || return 1
		case "$sub_choice" in
			1)
				read -e -p "请输入要安装自动更新的项目编号（支持多选，空格分隔）: " nums || return 1
				docker_compose_update_handle_numbers install "$nums"
				;;
			2)
				read -e -p "请输入要卸载自动更新的项目编号（支持多选，空格分隔）: " nums || return 1
				docker_compose_update_handle_numbers remove "$nums"
				;;
			3)
				local nums
				nums="$(docker_compose_update_all_numbers)"
				read -e -i "$nums" -p "请确认/修改要安装的项目编号（默认全选，空格分隔）: " nums || return 1
				docker_compose_update_handle_numbers install "$nums"
				;;
			4)
				local nums
				nums="$(docker_compose_update_all_numbers)"
				read -e -i "$nums" -p "请确认/修改要卸载的项目编号（默认全选，空格分隔）: " nums || return 1
				read -e -p "确认卸载以上编号对应自动更新？(y/N): " confirm || return 1
				if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
					docker_compose_update_handle_numbers remove "$nums"
				else
					echo "已取消"
				fi
				;;
			5) docker_compose_update_cleanup_orphans ;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}


linux_docker() {

	while true; do
	  clear
	  # send_stats "docker管理"
	  echo -e "Docker管理"
	  docker_tato
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}1.   ${gl_bai}安装更新Docker环境"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}2.   ${gl_bai}查看Docker全局状态"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}3.   ${gl_bai}Docker容器管理"
	  echo -e "${gl_kjlan}4.   ${gl_bai}Docker镜像管理"
	  echo -e "${gl_kjlan}5.   ${gl_bai}Docker网络管理"
	  echo -e "${gl_kjlan}6.   ${gl_bai}Docker卷管理"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}7.   ${gl_bai}清理无用的docker容器和镜像网络数据卷"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}8.   ${gl_bai}更换Docker源"
	  echo -e "${gl_kjlan}9.   ${gl_bai}编辑daemon.json文件"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}10.  ${gl_bai}Docker Compose 自动更新"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}11.  ${gl_bai}开启Docker-ipv6访问"
	  echo -e "${gl_kjlan}12.  ${gl_bai}关闭Docker-ipv6访问"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}19.  ${gl_bai}备份/迁移/还原Docker环境"
	  echo -e "${gl_kjlan}20.  ${gl_bai}卸载Docker环境"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "请输入你的选择: " sub_choice || return 1

	  case $sub_choice in
		  1)
			clear
			send_stats "安装docker环境"
			install_add_docker

			  ;;
		  2)
			  clear
			  local container_count=$(docker ps -a -q 2>/dev/null | wc -l)
			  local image_count=$(docker images -q 2>/dev/null | wc -l)
			  local network_count=$(docker network ls -q 2>/dev/null | wc -l)
			  local volume_count=$(docker volume ls -q 2>/dev/null | wc -l)

			  send_stats "docker全局状态"
			  echo "Docker版本"
			  docker -v
			  docker compose version

			  echo ""
			  echo -e "Docker镜像: ${gl_lv}$image_count${gl_bai} "
			  docker image ls
			  echo ""
			  echo -e "Docker容器: ${gl_lv}$container_count${gl_bai}"
			  docker ps -a
			  echo ""
			  echo -e "Docker卷: ${gl_lv}$volume_count${gl_bai}"
			  docker volume ls
			  echo ""
			  echo -e "Docker网络: ${gl_lv}$network_count${gl_bai}"
			  docker network ls
			  echo ""

			  ;;
		  3)
			  docker_ps
			  [ "$?" -eq 90 ] && continue
			  ;;
		  4)
			  docker_image
			  [ "$?" -eq 90 ] && continue
			  ;;

		  5)
			  while true; do
				  clear
				  send_stats "Docker网络管理"
				  echo "Docker网络列表"
				  echo "------------------------------------------------------------"
				  docker network ls
				  echo ""

				  echo "------------------------------------------------------------"
				  container_ids=$(docker ps -q)
				  printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"

				  for container_id in $container_ids; do
					  local container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")

					  local container_name=$(echo "$container_info" | awk '{print $1}')
					  local network_info=$(echo "$container_info" | cut -d' ' -f2-)

					  while IFS= read -r line; do
						  local network_name=$(echo "$line" | awk '{print $1}')
						  local ip_address=$(echo "$line" | awk '{print $2}')

						  printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
					  done <<< "$network_info"
				  done

				  echo ""
				  echo "网络操作"
				  echo "------------------------"
				  echo "1. 创建网络"
				  echo "2. 加入网络"
				  echo "3. 退出网络"
				  echo "4. 删除网络"
				  echo "------------------------"
				  echo "0. 返回上一级选单"
				  echo "------------------------"
				  read -e -p "请输入你的选择: " sub_choice || return 1

				  case $sub_choice in
					  1)
						  send_stats "创建网络"
						  read -e -p "设置新网络名: " dockernetwork || return 1
						  docker network create $dockernetwork
						  ;;
					  2)
						  send_stats "加入网络"
						  read -e -p "加入网络名: " dockernetwork || return 1
						  read -e -p "那些容器加入该网络（多个容器名请用空格分隔）: " dockernames || return 1

						  for dockername in $dockernames; do
							  docker network connect $dockernetwork $dockername
						  done
						  ;;
					  3)
						  send_stats "加入网络"
						  read -e -p "退出网络名: " dockernetwork || return 1
						  read -e -p "那些容器退出该网络（多个容器名请用空格分隔）: " dockernames || return 1

						  for dockername in $dockernames; do
							  docker network disconnect $dockernetwork $dockername
						  done

						  ;;

					  4)
						  send_stats "删除网络"
						  read -e -p "请输入要删除的网络名: " dockernetwork || return 1
						  docker network rm $dockernetwork
						  ;;

					  0)
						  continue 2
						  ;;
					  *)
						  break  # 跳出循环，退出菜单
						  ;;
				  esac
			  done
			  ;;

		  6)
			  while true; do
				  clear
				  send_stats "Docker卷管理"
				  echo "Docker卷列表"
				  docker volume ls
				  echo ""
				  echo "卷操作"
				  echo "------------------------"
				  echo "1. 创建新卷"
				  echo "2. 删除指定卷"
				  echo "3. 删除所有卷"
				  echo "------------------------"
				  echo "0. 返回上一级选单"
				  echo "------------------------"
				  read -e -p "请输入你的选择: " sub_choice || return 1

				  case $sub_choice in
					  1)
						  send_stats "新建卷"
						  read -e -p "设置新卷名: " dockerjuan || return 1
						  docker volume create $dockerjuan

						  ;;
					  2)
						  read -e -p "输入删除卷名（多个卷名请用空格分隔）: " dockerjuans || return 1

						  for dockerjuan in $dockerjuans; do
							  docker volume rm $dockerjuan
						  done

						  ;;

					   3)
						  send_stats "删除所有卷"
						  read -e -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定删除所有未使用的卷吗？(Y/N): ")" choice || return 1
						  case "$choice" in
							[Yy])
							  docker volume prune -f
							  ;;
							[Nn])
							  ;;
							*)
							  echo "无效的选择，请输入 Y 或 N。"
							  ;;
						  esac
						  ;;

					  0)
						  continue 2
						  ;;
					  *)
						  break  # 跳出循环，退出菜单
						  ;;
				  esac
			  done
			  ;;
		  7)
			  clear
			  send_stats "Docker清理"
			  read -e -p "$(echo -e "${gl_huang}提示: ${gl_bai}将清理无用的镜像容器网络，包括停止的容器，确定清理吗？(Y/N): ")" choice || return 1
			  case "$choice" in
				[Yy])
				  docker system prune -af --volumes
				  ;;
				[Nn])
				  ;;
				*)
				  echo "无效的选择，请输入 Y 或 N。"
				  ;;
			  esac
			  ;;
		  8)
			  clear
			  send_stats "Docker源"
			  docker_mirror_menu
			  [ "$?" -eq 90 ] && continue
			  ;;

		  9)
			  clear
			  install vim
			  mkdir -p /etc/docker && vim /etc/docker/daemon.json
			  restart docker
			  ;;


		  10)
			  docker_compose_auto_update_manager
			  continue
			  ;;



		  11)
			  clear
			  send_stats "Docker v6 开"
			  docker_ipv6_on
			  ;;

		  12)
			  clear
			  send_stats "Docker v6 关"
			  docker_ipv6_off
			  ;;

		  19)
			  docker_ssh_migration
			  continue
			  ;;


		  20)
			  clear
			  send_stats "Docker卸载"
			  read -e -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定卸载docker环境吗？(Y/N): ")" choice || return 1
			  case "$choice" in
				[Yy])
				  docker ps -a -q | xargs -r docker rm -f && docker images -q | xargs -r docker rmi && docker network prune -f && docker volume prune -f
				  remove docker docker-compose docker-ce docker-ce-cli containerd.io
				  rm -f /etc/docker/daemon.json
				  hash -r
				  ;;
				[Nn])
				  ;;
				*)
				  echo "无效的选择，请输入 Y 或 N。"
				  ;;
			  esac
			  ;;

		  0)
			  return
			  ;;
		  *)
			  echo "无效的输入!"
			  ;;
	  esac
	  break_end


	done


}



docker_tato() {

	local container_count=$(docker ps -a -q 2>/dev/null | wc -l)
	local image_count=$(docker images -q 2>/dev/null | wc -l)
	local network_count=$(docker network ls -q 2>/dev/null | wc -l)
	local volume_count=$(docker volume ls -q 2>/dev/null | wc -l)

	if command -v docker &> /dev/null; then
		echo -e "${gl_kjlan}------------------------"
		echo -e "${gl_lv}环境已经安装${gl_bai}  容器: ${gl_lv}$container_count${gl_bai}  镜像: ${gl_lv}$image_count${gl_bai}  网络: ${gl_lv}$network_count${gl_bai}  卷: ${gl_lv}$volume_count${gl_bai}"
	fi
}



ldnmp_tato() {
local cert_count=$(ls /home/web/certs/*_cert.pem 2>/dev/null | wc -l)
local output="${gl_lv}${cert_count}${gl_bai}"

local dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml 2>/dev/null | tr -d '[:space:]')
if [ -n "$dbrootpasswd" ]; then
	local db_count=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "Database|information_schema|mysql|performance_schema|sys" | wc -l)
fi

local db_output="${gl_lv}${db_count}${gl_bai}"


if command -v docker &>/dev/null; then
	if docker ps --filter "name=nginx" --filter "status=running" | grep -q nginx; then
		echo -e "${gl_huang}------------------------"
		echo -e "${gl_lv}环境已安装${gl_bai}  站点: $output  数据库: $db_output"
	fi
fi

}


fix_phpfpm_conf() {
	local container_name=$1
	docker exec "$container_name" sh -c "mkdir -p /run/$container_name && chmod 777 /run/$container_name"
	docker exec "$container_name" sh -c "sed -i '1i [global]\\ndaemonize = no' /usr/local/etc/php-fpm.d/www.conf"
	docker exec "$container_name" sh -c "sed -i '/^listen =/d' /usr/local/etc/php-fpm.d/www.conf"
	docker exec "$container_name" sh -c "echo -e '\nlisten = /run/$container_name/php-fpm.sock\nlisten.owner = www-data\nlisten.group = www-data\nlisten.mode = 0777' >> /usr/local/etc/php-fpm.d/www.conf"
	docker exec "$container_name" sh -c "rm -f /usr/local/etc/php-fpm.d/zz-docker.conf"

	find /home/web/conf.d/ -type f -name "*.conf" -exec sed -i "s#fastcgi_pass ${container_name}:9000;#fastcgi_pass unix:/run/${container_name}/php-fpm.sock;#g" {} \;

}






linux_ldnmp() {
	clear
	echo "LDNMP建站模块已从 linux-tools-daimon 个人版移除。"
	break_end
}








moltbot_menu() {
	local app_id="114"

	send_stats "clawdbot/moltbot管理"

	check_openclaw_update() {
		if ! command -v npm >/dev/null 2>&1; then
			return 1
		fi

		# 加上 --no-update-notifier，并确保错误重定向位置正确
		local_version=$(npm list -g openclaw --depth=0 --no-update-notifier 2>/dev/null | grep openclaw | awk '{print $NF}' | sed 's/^.*@//')

		if [ -z "$local_version" ]; then
			return 1
		fi

		remote_version=$(npm view openclaw version --no-update-notifier 2>/dev/null)

		if [ -z "$remote_version" ]; then
			return 1
		fi

		if [ "$local_version" != "$remote_version" ]; then
			echo "${gl_huang}检测到新版本:$remote_version${gl_bai}"
		else
			echo "${gl_lv}当前版本已是最新:$local_version${gl_bai}"
		fi
	}


	get_install_status() {
		if command -v openclaw >/dev/null 2>&1; then
			echo "${gl_lv}已安装${gl_bai}"
		else
			echo "${gl_hui}未安装${gl_bai}"
		fi
	}

	get_running_status() {		
		if pgrep -f "openclaw.*gateway" >/dev/null 2>&1; then
			echo "${gl_lv}运行中${gl_bai}"
		else
			echo "${gl_hui}未运行${gl_bai}"
		fi
	}


	show_menu() {


		clear

		local install_status=$(get_install_status)
		local running_status=$(get_running_status)
		local update_message=$(check_openclaw_update)

		echo "======================================="
		echo -e "🦞 OPENCLAW 管理工具 by KEJILION 🦞"
		echo -e "💡 终端执行 \033[1;33mk claw\033[0m 快速进入菜单"
		echo -e "$install_status $running_status $update_message"
		echo "======================================="
		echo "1.  安装"
		echo "2.  启动"
		echo "3.  停止"
		echo "--------------------"
		echo "4.  状态日志查看"
		echo "5.  换模型"
		echo "6.  API管理"
		echo "7.  机器人连接对接"
		echo "8.  插件管理（安装/删除）"
		echo "9.  技能管理（安装/删除）"
		echo "10. 编辑主配置文件"
		echo "11. 配置向导"
		echo "12. 健康检测与修复"
		echo "13. WebUI访问与设置"
		echo "14. TUI命令行对话窗口"
		echo "15. 记忆/Memory"
		echo "16. 权限管理"
		echo "17. 多智能体管理"
		echo "--------------------"
		echo "18. 备份与还原"
		echo "19. 更新"
		echo "20. 卸载"
		echo "--------------------"
		echo "0. 返回上一级选单"
		echo "--------------------"
		printf "请输入选项并回车: "
	}


	start_gateway() {
		openclaw gateway stop
		openclaw gateway start
		sleep 3
	}


	install_node_and_tools() {
		if command -v dnf &>/dev/null; then
			curl -fsSL https://rpm.nodesource.com/setup_24.x | sudo bash -
			dnf update -y
			dnf group install -y "Development Tools" "Development Libraries"
			dnf install -y cmake libatomic nodejs
		fi

		if command -v apt &>/dev/null; then
			  daimon_run_cached_script "https://deb.nodesource.com/setup_24.x" "nodesource-setup_24.x.sh"
			apt update -y
			apt install build-essential python3 libatomic1 nodejs -y
		fi
	}

	sync_openclaw_api_models() {
		local config_file
		config_file=$(openclaw_get_config_file)

		[ ! -f "$config_file" ] && return 0

		install jq curl >/dev/null 2>&1

		python3 - "$config_file" "$ENABLE_STATS" "$sh_v" <<'PY'
import copy
import json
import os
import platform
import sys
import time
import urllib.request
from datetime import datetime, timezone

path = sys.argv[1]
stats_enabled = (sys.argv[2].lower() == "true") if len(sys.argv) > 2 else True
script_version = sys.argv[3] if len(sys.argv) > 3 else ""

def send_stat(action):
    if not stats_enabled:
        return
    payload = {
        "action": action,
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
        "country": "",
        "os_info": platform.platform(),
        "cpu_arch": platform.machine(),
        "version": script_version,
    }
    try:
        req = urllib.request.Request(
            "https://api.kejilion.pro/api/log",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=3):
            pass
    except Exception:
        pass

with open(path, 'r', encoding='utf-8') as f:
    obj = json.load(f)

work = copy.deepcopy(obj)
models_cfg = work.setdefault('models', {})
providers = models_cfg.get('providers', {})
if not isinstance(providers, dict) or not providers:
    print('ℹ️ 未检测到 API providers，跳过模型同步')
    raise SystemExit(0)

agents = work.setdefault('agents', {})
defaults = agents.setdefault('defaults', {})
defaults_models_raw = defaults.get('models')
if isinstance(defaults_models_raw, dict):
    defaults_models = defaults_models_raw
elif isinstance(defaults_models_raw, list):
    defaults_models = {str(x): {} for x in defaults_models_raw if isinstance(x, str)}
else:
    defaults_models = {}
defaults['models'] = defaults_models

SUPPORTED_APIS = {'openai-completions', 'openai-responses'}

changed = False
fatal_errors = []
summary = []


def model_ref(provider_name, model_id):
    return f"{provider_name}/{model_id}"


def get_primary_ref(defaults_obj):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        return model_obj
    if isinstance(model_obj, dict):
        primary = model_obj.get('primary')
        if isinstance(primary, str):
            return primary
    return None


def set_primary_ref(defaults_obj, new_ref):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        defaults_obj['model'] = new_ref
    elif isinstance(model_obj, dict):
        model_obj['primary'] = new_ref
    else:
        defaults_obj['model'] = {'primary': new_ref}


def ref_provider(ref):
    if not isinstance(ref, str) or '/' not in ref:
        return None
    return ref.split('/', 1)[0]


def collect_available_refs(exclude_provider=None):
    refs = []
    if not isinstance(providers, dict):
        return refs
    for pname, p in providers.items():
        if exclude_provider and pname == exclude_provider:
            continue
        if not isinstance(p, dict):
            continue
        for m in p.get('models', []) or []:
            if isinstance(m, dict) and m.get('id'):
                refs.append(model_ref(pname, str(m['id'])))
    return refs


def prompt_delete_provider(name):
    prompt = f"⚠️ {name} /models 探测连续失败 3 次。是否删除该 API 供应商及其全部相关模型？[y/N]: "
    try:
        ans = input(prompt).strip().lower()
    except EOFError:
        return False
    return ans in ('y', 'yes')


def rebind_defaults_before_delete(name):
    global changed

    replacement = None

    def get_replacement():
        nonlocal replacement
        if replacement is None:
            candidates = collect_available_refs(exclude_provider=name)
            replacement = candidates[0] if candidates else None
        return replacement

    primary_ref = get_primary_ref(defaults)
    if ref_provider(primary_ref) == name:
        repl = get_replacement()
        if not repl:
            summary.append(f'❌ {name}: 默认主模型指向该 provider，但无可用替代模型，已中止删除')
            return False
        set_primary_ref(defaults, repl)
        changed = True
        summary.append(f'🔁 删除前已切换默认主模型: {primary_ref} -> {repl}')

    for fk in ('modelFallback', 'imageModelFallback'):
        val = defaults.get(fk)
        if ref_provider(val) == name:
            repl = get_replacement()
            if not repl:
                summary.append(f'❌ {name}: {fk} 指向该 provider，但无可用替代模型，已中止删除')
                return False
            defaults[fk] = repl
            changed = True
            summary.append(f'🔁 删除前已切换 {fk}: {val} -> {repl}')

    return True


def delete_provider_and_refs(name):
    global changed

    if not rebind_defaults_before_delete(name):
        return False

    removed_refs = [r for r in list(defaults_models.keys()) if r.startswith(name + '/')]
    for r in removed_refs:
        defaults_models.pop(r, None)
    if removed_refs:
        changed = True

    if name in providers:
        providers.pop(name, None)
        changed = True

    summary.append(f'🗑️ 已删除 provider {name}，并移除 defaults.models 下 {len(removed_refs)} 个模型引用')
    return True


def fetch_remote_models_with_retry(name, base_url, api_key, retries=3):
    last_error = None
    for attempt in range(1, retries + 1):
        req = urllib.request.Request(
            base_url.rstrip('/') + '/models',
            headers={
                'Authorization': f'Bearer {api_key}',
                'User-Agent': 'Mozilla/5.0',
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=12) as resp:
                payload = resp.read().decode('utf-8', 'ignore')
            data = json.loads(payload)
            return data, None, attempt
        except Exception as e:
            last_error = e
            if attempt < retries:
                time.sleep(1)
    return None, last_error, retries


for name, provider in list(providers.items()):
    if not isinstance(provider, dict):
        summary.append(f'ℹ️ 跳过 {name}: provider 结构非法')
        continue

    api = provider.get('api', '')
    base_url = provider.get('baseUrl')
    api_key = provider.get('apiKey')
    model_list = provider.get('models', [])

    if not base_url or not api_key or not isinstance(model_list, list) or not model_list:
        summary.append(f'ℹ️ 跳过 {name}: 无 baseUrl/apiKey/models')
        continue

    if api not in SUPPORTED_APIS:
        summary.append(f'🔁 {name}: 发现非法协议 {api or "(unset)"}，将重新探测')
        provider['api'] = ''
        api = ''
        changed = True

    data, err, attempts = fetch_remote_models_with_retry(name, base_url, api_key, retries=3)
    if err is not None:
        summary.append(f'⚠️ {name}: /models 探测失败，已重试 {attempts} 次 ({type(err).__name__}: {err})')
        send_stat('OpenClaw API确认介入')
        if prompt_delete_provider(name):
            deleted = delete_provider_and_refs(name)
            if deleted:
                send_stat('OpenClaw API删失败Provider-确认')
                summary.append(f'✅ {name}: 用户已确认删除该 provider 及全部相关模型引用')
        else:
            send_stat('OpenClaw API删失败Provider-拒绝')
            summary.append(f'ℹ️ {name}: 用户未确认删除，保留现有 provider 配置')
        continue

    if attempts > 1:
        summary.append(f'🔁 {name}: /models 第 {attempts} 次重试后成功')

    if not (isinstance(data, dict) and isinstance(data.get('data'), list)):
        summary.append(f'⚠️ 跳过 {name}: /models 返回结构不可识别')
        continue

    remote_ids = []
    for item in data['data']:
        if isinstance(item, dict) and item.get('id'):
            remote_ids.append(str(item['id']))
    remote_set = set(remote_ids)

    if not remote_set:
        fatal_errors.append(f'❌ {name} 上游 /models 为空，无法为该 provider 提供兜底模型')
        continue

    local_models = [m for m in model_list if isinstance(m, dict) and m.get('id')]
    local_ids = [str(m['id']) for m in local_models]
    local_set = set(local_ids)

    template = None
    for m in local_models:
        template = copy.deepcopy(m)
        break
    if template is None:
        summary.append(f'⚠️ 跳过 {name}: 本地 models 无有效模板模型')
        continue

    removed_ids = [mid for mid in local_ids if mid not in remote_set]
    added_ids = [mid for mid in remote_ids if mid not in local_set]

    kept_models = [copy.deepcopy(m) for m in local_models if str(m['id']) in remote_set]
    new_models = kept_models[:]

    for mid in added_ids:
        nm = copy.deepcopy(template)
        nm['id'] = mid
        if isinstance(nm.get('name'), str):
            nm['name'] = f'{name} / {mid}'
        new_models.append(nm)

    if not new_models:
        fatal_errors.append(f'❌ {name} 同步后无可用模型，无法保障默认模型/回退模型兜底')
        continue

    expected_refs = {model_ref(name, str(m['id'])) for m in new_models if isinstance(m, dict) and m.get('id')}
    local_refs = {model_ref(name, mid) for mid in local_ids}

    first_ref = model_ref(name, str(new_models[0]['id']))

    primary_ref = get_primary_ref(defaults)
    if isinstance(primary_ref, str) and primary_ref in (local_refs - expected_refs):
        set_primary_ref(defaults, first_ref)
        changed = True
        summary.append(f'🔁 默认模型已兜底替换: {primary_ref} -> {first_ref}')

    for fk in ('modelFallback', 'imageModelFallback'):
        val = defaults.get(fk)
        if isinstance(val, str) and val in (local_refs - expected_refs):
            defaults[fk] = first_ref
            changed = True
            summary.append(f'🔁 {fk} 已兜底替换: {val} -> {first_ref}')

    stale_refs = [r for r in list(defaults_models.keys()) if r.startswith(name + '/') and r not in expected_refs]
    for r in stale_refs:
        defaults_models.pop(r, None)
        changed = True

    for r in sorted(expected_refs):
        if r not in defaults_models:
            defaults_models[r] = {}
            changed = True

    if removed_ids or added_ids or len(local_models) != len(new_models):
        provider['models'] = new_models
        changed = True

    summary.append(f'✅ {name}: 新增 {len(added_ids)} 个，删除 {len(removed_ids)} 个，当前 {len(new_models)} 个')

    if added_ids:
        summary.append(f'➕ 新增模型({len(added_ids)}):')
        for mid in added_ids:
            summary.append(f'  + {mid}')
    if removed_ids:
        summary.append(f'➖ 删除模型({len(removed_ids)}):')
        for mid in removed_ids:
            summary.append(f'  - {mid}')


if fatal_errors:
    for line in summary:
        print(line)
    for err in fatal_errors:
        print(err)
    print('❌ 模型同步失败：存在 provider 同步后无可用模型，已中止写入')
    raise SystemExit(2)

if changed:
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(work, f, ensure_ascii=False, indent=2)
        f.write('\n')
    for line in summary:
        print(line)
    print('✅ OpenClaw API 模型一致性同步完成并已写入配置')
else:
    for line in summary:
        print(line)
    print('ℹ️ 无需同步：配置已与上游 /models 保持一致')
PY
	}



	install_moltbot() {
		echo "开始安装 OpenClaw..."
		send_stats "开始安装 OpenClaw..."
		install git jq

		install_node_and_tools

		country=$(curl -s ipinfo.io/country)
		if [[ "$country" == "CN" || "$country" == "HK" ]]; then
			npm config set registry https://registry.npmmirror.com
		fi

		git config --global url."${gh_proxy}github.com/".insteadOf ssh://git@github.com/
		git config --global url."${gh_proxy}github.com/".insteadOf git@github.com:

		npm install -g openclaw@latest
		openclaw onboard --install-daemon
		start_gateway
		add_app_id
		break_end

	}


	start_bot() {
		echo "启动 OpenClaw..."
		send_stats "启动 OpenClaw..."
		start_gateway
		break_end
	}

	stop_bot() {
		echo "停止 OpenClaw..."
		send_stats "停止 OpenClaw..."
		tmux kill-session -t gateway > /dev/null 2>&1
		openclaw gateway stop
		break_end
	}

	view_logs() {
		echo "查看 OpenClaw 状态日志"
		send_stats "查看 OpenClaw 日志"
		openclaw status
		openclaw gateway status
		openclaw logs
		break_end
	}





	# OpenClaw API 协议探测逻辑已移除：不再自动探测/判定 API 类型。
	# 说明：API 类型由用户显式配置（models.providers.<name>.api），脚本不再尝试调用 /responses 做推断。

	# 构造模型配置 JSON
	build-openclaw-provider-models-json() {
		local provider_name="$1"
		local model_ids="$2"
		local models_array="["
		local first=true

		while read -r model_id; do
			[ -z "$model_id" ] && continue
			[[ $first == false ]] && models_array+=","
			first=false

			local context_window=1048576
			local max_tokens=128000
			local input_cost=0.15
			local output_cost=0.60

			case "$model_id" in
				*opus*|*pro*|*preview*|*thinking*|*sonnet*)
					input_cost=2.00
					output_cost=12.00
					;;
				*gpt-5*|*codex*)
					input_cost=1.25
					output_cost=10.00
					;;
				*flash*|*lite*|*haiku*|*mini*|*nano*)
					input_cost=0.10
					output_cost=0.40
					;;
			esac

			models_array+=$(cat <<EOF
{
	"id": "$model_id",
	"name": "$provider_name / $model_id",
	"input": ["text", "image"],
	"contextWindow": $context_window,
	"maxTokens": $max_tokens,
	"cost": {
		"input": $input_cost,
		"output": $output_cost,
		"cacheRead": 0,
		"cacheWrite": 0
	}
}
EOF
)
		done <<< "$model_ids"

		models_array+="]"
		echo "$models_array"
	}

	# 写入 provider 与模型配置
	write-openclaw-provider-models() {
		local provider_name="$1"
		local base_url="$2"
		local api_key="$3"
		local models_array="$4"
		local config_file
		config_file=$(openclaw_get_config_file)

		# 不再自动探测/纠正 API 协议；保持用户配置为准
		DETECTED_API="openai-completions"

		[[ -f "$config_file" ]] && cp "$config_file" "${config_file}.bak.$(date +%s)"

		jq --arg prov "$provider_name" \
		   --arg url "$base_url" \
		   --arg key "$api_key" \
		   --arg api "$DETECTED_API" \
		   --argjson models "$models_array" \
		'
		.models |= (
			(. // { mode: "merge", providers: {} })
			| .mode = "merge"
			| .providers[$prov] = {
				baseUrl: $url,
				apiKey: $key,
				api: $api,
				models: $models
			}
		)
		| .agents |= (. // {})
		| .agents.defaults |= (. // {})
		| .agents.defaults.models |= (
			(if type == "object" then .
			 elif type == "array" then reduce .[] as $m ({}; if ($m|type) == "string" then .[$m] = {} else . end)
			 else {}
			 end) as $existing
			| reduce ($models[]? | .id? // empty | tostring) as $mid (
				$existing;
				if ($mid | length) > 0 then
					.["\($prov)/\($mid)"] //= {}
				else
					.
				end
			)
		)
		' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
	}

	# 核心函数：获取并添加所有模型
	add-all-models-from-provider() {
		local provider_name="$1"
		local base_url="$2"
		local api_key="$3"

		echo "🔍 正在获取 $provider_name 的所有可用模型..."

		local models_json=$(curl -s -m 10 \
			-H "Authorization: Bearer $api_key" \
			"${base_url}/models")

		if [[ -z "$models_json" ]]; then
			echo "❌ 无法获取模型列表"
			return 1
		fi

		local model_ids=$(echo "$models_json" | grep -oP '"id":\s*"\K[^"]+')

		if [[ -z "$model_ids" ]]; then
			echo "❌ 未找到任何模型"
			return 1
		fi

		local model_count=$(echo "$model_ids" | wc -l)
		echo "✅ 发现 $model_count 个模型"

		local models_array
		models_array=$(build-openclaw-provider-models-json "$provider_name" "$model_ids")

		write-openclaw-provider-models "$provider_name" "$base_url" "$api_key" "$models_array"

		if [[ $? -eq 0 ]]; then
			echo "✅ 成功添加 $model_count 个模型到 $provider_name"
			echo "📦 模型引用格式: $provider_name/<model-id>"
			return 0
		else
			echo "❌ 配置注入失败"
			return 1
		fi
	}

	# 仅添加默认模型并保留 provider
	add-default-model-only-to-provider() {
		local provider_name="$1"
		local base_url="$2"
		local api_key="$3"
		local default_model="$4"

		if [[ -z "$default_model" ]]; then
			echo "❌ 默认模型不能为空"
			return 1
		fi

		local models_array
		models_array=$(build-openclaw-provider-models-json "$provider_name" "$default_model")

		write-openclaw-provider-models "$provider_name" "$base_url" "$api_key" "$models_array"

		if [[ $? -eq 0 ]]; then
			echo "✅ 已添加 provider：$provider_name"
			echo "✅ 仅写入默认模型：$default_model"
			return 0
		else
			echo "❌ 配置注入失败"
			return 1
		fi
	}

	add-openclaw-provider-interactive() {
		send_stats "OpenClaw API添加"
		echo "=== 交互式添加 OpenClaw Provider (全量模型) ==="

		# 1. Provider 名称
		read -erp "请输入 Provider 名称 (如: deepseek): " provider_name || return 1
		while [[ -z "$provider_name" ]]; do
			echo "❌ Provider 名称不能为空"
			read -erp "请输入 Provider 名称: " provider_name || return 1
		done

		# 2. Base URL
		read -erp "请输入 Base URL (如: https://api.xxx.com/v1): " base_url || return 1
		while [[ -z "$base_url" ]]; do
			echo "❌ Base URL 不能为空"
			read -erp "请输入 Base URL: " base_url || return 1
		done
		base_url="${base_url%/}"

		# 3. API Key
		read -rsp "请输入 API Key (输入不显示): " api_key || return 1
		echo
		while [[ -z "$api_key" ]]; do
			echo "❌ API Key 不能为空"
			read -rsp "请输入 API Key: " api_key || return 1
			echo
		done

		# 4. 不再探测/判断 API 类型；协议由用户自行选择与维护

		# 5. 获取模型列表
		echo "🔍 正在获取可用模型列表..."
		models_json=$(curl -s -m 10 \
			-H "Authorization: Bearer $api_key" \
			"${base_url}/models")

		if [[ -n "$models_json" ]]; then
			available_models=$(echo "$models_json" | grep -oP '"id":\s*"\K[^"]+' | sort)

			if [[ -n "$available_models" ]]; then
				model_count=$(echo "$available_models" | wc -l)
				echo "✅ 发现 $model_count 个可用模型："
				echo "--------------------------------"
				# 全部显示，带序号
				i=1
				model_list=()
				while read -r model; do
					echo "[$i] $model"
					model_list+=("$model")
					((i++))
				done <<< "$available_models"
				echo "--------------------------------"
			fi
		fi

		# 5. 选择默认模型
		echo
		read -erp "请输入默认 Model ID (或序号，留空则使用第一个): " input_model || return 1

		if [[ -z "$input_model" && -n "$available_models" ]]; then
			default_model=$(echo "$available_models" | head -1)
			echo "🎯 使用第一个模型: $default_model"
		elif [[ "$input_model" =~ ^[0-9]+$ ]] && [ "${#model_list[@]}" -gt 0 ] && [ "$input_model" -ge 1 ] && [ "$input_model" -le "${#model_list[@]}" ]; then
			default_model="${model_list[$((input_model-1))]}"
			echo "🎯 已选择模型: $default_model"
		else
			default_model="$input_model"
		fi

		# 6. 确认信息
		echo
		echo "====== 确认信息 ======"
		echo "Provider    : $provider_name"
		echo "Base URL    : $base_url"
		echo "API Key     : ${api_key:0:8}****"
		echo "默认模型    : $default_model"
		echo "模型总数    : $model_count"
		echo "======================"

		read -erp "是否同时添加其他所有可用模型？(y/N): " confirm || return 1

		install jq
		if [[ "$confirm" =~ ^[Yy]$ ]]; then
			add-all-models-from-provider "$provider_name" "$base_url" "$api_key"
			add_result=$?
			finish_msg="✅ 完成！所有 $model_count 个模型已加载"
		else
			add-default-model-only-to-provider "$provider_name" "$base_url" "$api_key" "$default_model"
			add_result=$?
			finish_msg="✅ 完成！已保留 provider，并仅加载默认模型：$default_model"
		fi

		if [[ $add_result -eq 0 ]]; then
			echo
			echo "🔄 设置默认模型并重启网关..."
			openclaw models set "$provider_name/$default_model"
			openclaw_sync_sessions_model "$provider_name/$default_model"
			start_gateway
			echo "$finish_msg"
			echo "✅ 当前 API 协议类型: $DETECTED_API"
		fi

		break_end
	}



openclaw_api_manage_list() {
	local config_file="${HOME}/.openclaw/openclaw.json"
	send_stats "OpenClaw API列表"

	while IFS=$'\t' read -r rec_type idx name base_url model_count api_type latency_txt latency_level; do
		case "$rec_type" in
			MSG)
				echo "$idx"
				;;
			ROW)
				local latency_color="$gl_bai"
				case "$latency_level" in
					low) latency_color="$gl_lv" ;;
					medium) latency_color="$gl_huang" ;;
					high|unavailable) latency_color="$gl_hong" ;;
					unchecked) latency_color="$gl_bai" ;;
				esac

				printf '%b\n' "[$idx] ${name} | API: ${base_url} | 协议: ${api_type} | 模型数量: ${gl_huang}${model_count}${gl_bai} | 延迟/状态: ${latency_color}${latency_txt}${gl_bai}"
				;;
		esac
	done < <(python3 - "$config_file" <<-'PY'
import json
import sys
import time
import urllib.request

path = sys.argv[1]
SUPPORTED_APIS = {'openai-completions', 'openai-responses'}


def ping_models(base_url, api_key):
    req = urllib.request.Request(
        base_url.rstrip('/') + '/models',
        headers={
            'Authorization': f'Bearer {api_key}',
            'User-Agent': 'OpenClaw-API-Manage/1.0',
        },
    )
    start = time.perf_counter()
    with urllib.request.urlopen(req, timeout=4) as resp:
        resp.read(2048)
    return int((time.perf_counter() - start) * 1000)


def classify_latency(latency):
    if latency == '不可用':
        return '不可用', 'unavailable'
    if latency == '未检测':
        return '未检测', 'unchecked'
    if isinstance(latency, int):
        if latency <= 800:
            level = 'low'
        elif latency <= 2000:
            level = 'medium'
        else:
            level = 'high'
        return f'{latency}ms', level
    return str(latency), 'unchecked'


try:
    with open(path, 'r', encoding='utf-8') as f:
        obj = json.load(f)
except FileNotFoundError:
    print('MSG\tℹ️ 未找到 openclaw.json，请先完成安装/初始化。')
    raise SystemExit(0)
except Exception as e:
    print(f'MSG\t❌ 读取配置失败: {type(e).__name__}: {e}')
    raise SystemExit(0)

providers = ((obj.get('models') or {}).get('providers') or {})
if not isinstance(providers, dict) or not providers:
    print('MSG\tℹ️ 当前未配置任何 API provider。')
    raise SystemExit(0)

print('MSG\t--- 已配置 API 列表 ---')

for idx, name in enumerate(sorted(providers.keys()), start=1):
    provider = providers.get(name)
    if not isinstance(provider, dict):
        base_url = '-'
        model_count = 0
        latency_raw = '不可用'
    else:
        base_url = provider.get('baseUrl') or provider.get('url') or provider.get('endpoint') or '-'
        models = provider.get('models') if isinstance(provider.get('models'), list) else []
        model_count = sum(1 for m in models if isinstance(m, dict) and m.get('id'))
        api = provider.get('api', '')
        api_key = provider.get('apiKey')

        latency_raw = '未检测'
        if api in SUPPORTED_APIS:
            if isinstance(base_url, str) and base_url != '-' and isinstance(api_key, str) and api_key:
                try:
                    latency_raw = ping_models(base_url, api_key)
                except Exception:
                    latency_raw = '不可用'
            else:
                latency_raw = '不可用'

    latency_text, latency_level = classify_latency(latency_raw)
    api_label = api if api in SUPPORTED_APIS else '-'
    print(
        'ROW\t' + '\t'.join([
            str(idx),
            str(name),
            str(base_url),
            str(model_count),
            str(api_label),
            str(latency_text),
            str(latency_level),
        ])
    )
PY
)
}
sync-openclaw-provider-interactive() {
	local config_file="${HOME}/.openclaw/openclaw.json"
	send_stats "OpenClaw API按Provider同步"

	if [ ! -f "$config_file" ]; then
		echo "❌ 未找到配置文件: $config_file"
		break_end
		return 1
	fi

	read -erp "请输入要同步的 API 名称(provider)，直接回车同步全部: " provider_name || return 1
	if [ -z "$provider_name" ]; then
		if sync_openclaw_api_models; then
			start_gateway
		else
			echo "❌ API 模型同步失败，已中止重启网关。请检查 provider /models 返回后重试。"
			return 1
		fi
		break_end
		return 0
	fi

	install jq curl >/dev/null 2>&1

	python3 - "$config_file" "$provider_name" <<'PY2'
import copy
import json
import sys
import time
import urllib.request

path = sys.argv[1]
target = sys.argv[2]
SUPPORTED_APIS = {'openai-completions', 'openai-responses'}

with open(path, 'r', encoding='utf-8') as f:
    obj = json.load(f)

work = copy.deepcopy(obj)
models_cfg = work.setdefault('models', {})
providers = models_cfg.get('providers', {})
if not isinstance(providers, dict) or not providers:
    print('❌ 未检测到 API providers，无法同步')
    raise SystemExit(2)

provider = providers.get(target)
if not isinstance(provider, dict):
    print(f'❌ 未找到 provider: {target}')
    raise SystemExit(2)

agents = work.setdefault('agents', {})
defaults = agents.setdefault('defaults', {})
defaults_models_raw = defaults.get('models')
if isinstance(defaults_models_raw, dict):
    defaults_models = defaults_models_raw
elif isinstance(defaults_models_raw, list):
    defaults_models = {str(x): {} for x in defaults_models_raw if isinstance(x, str)}
else:
    defaults_models = {}
defaults['models'] = defaults_models


def model_ref(provider_name, model_id):
    return f"{provider_name}/{model_id}"


def get_primary_ref(defaults_obj):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        return model_obj
    if isinstance(model_obj, dict):
        primary = model_obj.get('primary')
        if isinstance(primary, str):
            return primary
    return None


def set_primary_ref(defaults_obj, new_ref):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        defaults_obj['model'] = new_ref
    elif isinstance(model_obj, dict):
        model_obj['primary'] = new_ref
    else:
        defaults_obj['model'] = {'primary': new_ref}


def fetch_remote_models_with_retry(base_url, api_key, retries=3):
    last_error = None
    for attempt in range(1, retries + 1):
        req = urllib.request.Request(
            base_url.rstrip('/') + '/models',
            headers={
                'Authorization': f'Bearer {api_key}',
                'User-Agent': 'Mozilla/5.0',
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=12) as resp:
                payload = resp.read().decode('utf-8', 'ignore')
            return json.loads(payload), None, attempt
        except Exception as e:
            last_error = e
            if attempt < retries:
                time.sleep(1)
    return None, last_error, retries


api = provider.get('api', '')
base_url = provider.get('baseUrl')
api_key = provider.get('apiKey')
model_list = provider.get('models', [])

if not base_url or not api_key or not isinstance(model_list, list) or not model_list:
    print(f'❌ provider {target} 缺少 baseUrl/apiKey/models，无法执行同步')
    raise SystemExit(3)

if api not in SUPPORTED_APIS:
    print(f'ℹ️ provider {target} 当前 api={api}，但脚本已不再探测/纠正协议；请手动设置为 openai-completions 或 openai-responses')

protocol_msg = None

data, err, attempts = fetch_remote_models_with_retry(base_url, api_key, retries=3)
if err is not None:
    print(f'❌ {target}: /models 探测失败，已重试 {attempts} 次 ({type(err).__name__}: {err})')
    raise SystemExit(4)

if not (isinstance(data, dict) and isinstance(data.get('data'), list)):
    print(f'❌ {target}: /models 返回结构不可识别')
    raise SystemExit(4)

remote_ids = []
for item in data['data']:
    if isinstance(item, dict) and item.get('id'):
        remote_ids.append(str(item['id']))
remote_set = set(remote_ids)
if not remote_set:
    print(f'❌ {target}: 上游 /models 为空，已中止同步')
    raise SystemExit(5)

local_models = [m for m in model_list if isinstance(m, dict) and m.get('id')]
local_ids = [str(m['id']) for m in local_models]
local_set = set(local_ids)

template = copy.deepcopy(local_models[0]) if local_models else None
if template is None:
    print(f'❌ {target}: 本地 models 无有效模板模型，无法补全新增模型')
    raise SystemExit(3)

removed_ids = [mid for mid in local_ids if mid not in remote_set]
added_ids = [mid for mid in remote_ids if mid not in local_set]

kept_models = [copy.deepcopy(m) for m in local_models if str(m['id']) in remote_set]
new_models = kept_models[:]
for mid in added_ids:
    nm = copy.deepcopy(template)
    nm['id'] = mid
    if isinstance(nm.get('name'), str):
        nm['name'] = f'{target} / {mid}'
    new_models.append(nm)

if not new_models:
    print(f'❌ {target}: 同步后无可用模型，已中止写入')
    raise SystemExit(5)

expected_refs = {model_ref(target, str(m['id'])) for m in new_models if isinstance(m, dict) and m.get('id')}
local_refs = {model_ref(target, mid) for mid in local_ids}
removed_refs = local_refs - expected_refs
first_ref = model_ref(target, str(new_models[0]['id']))

changed = False
primary_ref = get_primary_ref(defaults)
if isinstance(primary_ref, str) and primary_ref in removed_refs:
    set_primary_ref(defaults, first_ref)
    changed = True
    print(f'🔁 默认模型已兜底替换: {primary_ref} -> {first_ref}')

for fk in ('modelFallback', 'imageModelFallback'):
    val = defaults.get(fk)
    if isinstance(val, str) and val in removed_refs:
        defaults[fk] = first_ref
        changed = True
        print(f'🔁 {fk} 已兜底替换: {val} -> {first_ref}')

stale_refs = [r for r in list(defaults_models.keys()) if r.startswith(target + '/') and r not in expected_refs]
for r in stale_refs:
    defaults_models.pop(r, None)
    changed = True

for r in sorted(expected_refs):
    if r not in defaults_models:
        defaults_models[r] = {}
        changed = True

if removed_ids or added_ids or len(local_models) != len(new_models):
    provider['models'] = new_models
    changed = True


if changed:
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(work, f, ensure_ascii=False, indent=2)
        f.write('\n')

print(f'✅ {target}: 新增 {len(added_ids)} 个，删除 {len(removed_ids)} 个，当前 {len(new_models)} 个')

if added_ids:
    print(f'➕ 新增模型({len(added_ids)}):')
    for mid in added_ids:
        print(f'  + {mid}')
if removed_ids:
    print(f'➖ 删除模型({len(removed_ids)}):')
    for mid in removed_ids:
        print(f'  - {mid}')

if changed:
    print('✅ 指定 provider 模型一致性同步完成并已写入配置')
else:
    print('ℹ️ 无需同步：该 provider 配置已与上游 /models 保持一致')
PY2
	local rc=$?
	case "$rc" in
		0)
			echo "✅ 同步执行完成"
			start_gateway
			;;
		2)
			echo "❌ 同步失败：provider 不存在或未配置"
			;;
		3)
			echo "❌ 同步失败：provider 配置不完整或类型不支持"
			;;
		4)
			echo "❌ 同步失败：上游 /models 请求失败"
			;;
		5)
			echo "❌ 同步失败：上游模型为空或同步后无可用模型"
			;;
		*)
			echo "❌ 同步失败：请检查配置文件结构或日志输出"
			;;
	esac

	break_end
}

openclaw_detect_api_protocol_by_provider() {
	# 协议探测逻辑已移除：脚本不再自动探测/判定 API 类型。
	# 保留函数以兼容菜单调用，但不做任何改写。
	echo "ℹ️ 已关闭协议探测：请手动在 ${HOME}/.openclaw/openclaw.json 中设置 provider.api 为 openai-completions 或 openai-responses"
	return 0
}

fix-openclaw-provider-protocol-interactive() {
	local config_file="${HOME}/.openclaw/openclaw.json"
	send_stats "OpenClaw API协议切换"

	if [ ! -f "$config_file" ]; then
		echo "❌ 未找到配置文件: $config_file"
		break_end
		return 1
	fi

	read -erp "请输入要切换协议的 API 名称(provider): " provider_name || return 1
	if [ -z "$provider_name" ]; then
		echo "❌ provider 名称不能为空"
		break_end
		return 1
	fi

	echo "请选择要设置的 API 类型："
	echo "1. openai-completions"
	echo "2. openai-responses"
	read -erp "请输入你的选择 (1/2): " proto_choice || return 1

	local new_api=""
	case "$proto_choice" in
		1) new_api="openai-completions" ;;
		2) new_api="openai-responses" ;;
		*)
			echo "❌ 无效选择"
			break_end
			return 1
			;;
	esac

	install python3 >/dev/null 2>&1

	python3 - "$config_file" "$provider_name" "$new_api" <<'PY'
import copy
import json
import sys

path = sys.argv[1]
name = sys.argv[2]
new_api = sys.argv[3]

SUPPORTED_APIS = {'openai-completions', 'openai-responses'}
if new_api not in SUPPORTED_APIS:
    print('❌ 非法协议值')
    raise SystemExit(3)

with open(path, 'r', encoding='utf-8') as f:
    obj = json.load(f)

work = copy.deepcopy(obj)
providers = ((work.get('models') or {}).get('providers') or {})
if not isinstance(providers, dict) or name not in providers or not isinstance(providers.get(name), dict):
    print(f'❌ 未找到 provider: {name}')
    raise SystemExit(2)

providers[name]['api'] = new_api

with open(path, 'w', encoding='utf-8') as f:
    json.dump(work, f, ensure_ascii=False, indent=2)
    f.write('\n')

print(f'✅ 已更新 provider {name} 协议为: {new_api}')
PY
	local rc=$?
	case "$rc" in
		0)
			start_gateway
			;;
		2)
			echo "❌ 切换失败：provider 不存在或未配置"
			;;
		3)
			echo "❌ 切换失败：协议值非法"
			;;
		*)
			echo "❌ 切换失败：请检查配置文件结构或日志输出"
			;;
	esac

	break_end
}

	delete-openclaw-provider-interactive() {
		local config_file
		config_file=$(openclaw_get_config_file)
		send_stats "OpenClaw API删除入口"

		if [ ! -f "$config_file" ]; then
			echo "❌ 未找到配置文件: $config_file"
			break_end
			return 1
		fi

		read -erp "请输入要删除的 API 名称(provider): " provider_name || return 1
		if [ -z "$provider_name" ]; then
			send_stats "OpenClaw API删除取消"
			echo "❌ provider 名称不能为空"
			break_end
			return 1
		fi

		python3 - "$config_file" "$provider_name" <<'PY'
import copy
import json
import sys

path = sys.argv[1]
name = sys.argv[2]

with open(path, 'r', encoding='utf-8') as f:
    obj = json.load(f)

work = copy.deepcopy(obj)
models_cfg = work.setdefault('models', {})
providers = models_cfg.get('providers', {})
if not isinstance(providers, dict) or name not in providers:
    print(f'❌ 未找到 provider: {name}')
    raise SystemExit(2)

agents = work.setdefault('agents', {})
defaults = agents.setdefault('defaults', {})
defaults_models_raw = defaults.get('models')
if isinstance(defaults_models_raw, dict):
    defaults_models = defaults_models_raw
elif isinstance(defaults_models_raw, list):
    defaults_models = {str(x): {} for x in defaults_models_raw if isinstance(x, str)}
else:
    defaults_models = {}
defaults['models'] = defaults_models


def model_ref(provider_name, model_id):
    return f"{provider_name}/{model_id}"


def ref_provider(ref):
    if not isinstance(ref, str) or '/' not in ref:
        return None
    return ref.split('/', 1)[0]


def get_primary_ref(defaults_obj):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        return model_obj
    if isinstance(model_obj, dict):
        primary = model_obj.get('primary')
        if isinstance(primary, str):
            return primary
    return None


def set_primary_ref(defaults_obj, new_ref):
    model_obj = defaults_obj.get('model')
    if isinstance(model_obj, str):
        defaults_obj['model'] = new_ref
    elif isinstance(model_obj, dict):
        model_obj['primary'] = new_ref
    else:
        defaults_obj['model'] = {'primary': new_ref}


def collect_available_refs(exclude_provider=None):
    refs = []
    if not isinstance(providers, dict):
        return refs
    for pname, p in providers.items():
        if exclude_provider and pname == exclude_provider:
            continue
        if not isinstance(p, dict):
            continue
        for m in p.get('models', []) or []:
            if isinstance(m, dict) and m.get('id'):
                refs.append(model_ref(pname, str(m['id'])))
    return refs


replacement_candidates = collect_available_refs(exclude_provider=name)
replacement = replacement_candidates[0] if replacement_candidates else None

primary_ref = get_primary_ref(defaults)
if ref_provider(primary_ref) == name:
    if not replacement:
        print('❌ 删除中止：默认主模型指向该 provider，且无可用替代模型')
        raise SystemExit(3)
    set_primary_ref(defaults, replacement)
    print(f'🔁 默认主模型切换: {primary_ref} -> {replacement}')

for fk in ('modelFallback', 'imageModelFallback'):
    val = defaults.get(fk)
    if ref_provider(val) == name:
        if not replacement:
            print(f'❌ 删除中止：{fk} 指向该 provider，且无可用替代模型')
            raise SystemExit(3)
        defaults[fk] = replacement
        print(f'🔁 {fk} 切换: {val} -> {replacement}')

removed_refs = [r for r in list(defaults_models.keys()) if r.startswith(name + '/')]
for r in removed_refs:
    defaults_models.pop(r, None)

providers.pop(name, None)

with open(path, 'w', encoding='utf-8') as f:
    json.dump(work, f, ensure_ascii=False, indent=2)
    f.write('\n')

print(f'🗑️ 已删除 provider: {name}')
print(f'🧹 已清理 defaults.models 中 {len(removed_refs)} 个关联模型引用')
PY
		local rc=$?
		case "$rc" in
			0)
				send_stats "OpenClaw API删除确认"
				echo "✅ 删除完成"
				start_gateway
				;;
			2)
				echo "❌ 删除失败：provider 不存在"
				;;
			3)
				send_stats "OpenClaw API删除取消"
				echo "❌ 删除失败：无可用替代模型，已保持原配置"
				;;
			*)
				echo "❌ 删除失败：请检查配置文件结构或日志输出"
				;;
		esac

		break_end
	}

	openclaw_api_providers_showcase() {
		send_stats "OpenClaw API厂商推荐"

		clear
		echo ""
		echo -e "${gl_kjlan}╔════════════════════════════════════════════════════════════╗${gl_bai}"
		echo -e "${gl_kjlan}║${gl_bai}            ${gl_huang}🌟 API 厂商推荐列表${gl_bai}                          ${gl_kjlan}║${gl_bai}"
		echo -e "${gl_kjlan}║${gl_bai}            ${gl_zi}部分入口含 AFF${gl_bai}                            ${gl_kjlan}║${gl_bai}"
		echo -e "${gl_kjlan}╚════════════════════════════════════════════════════════════╝${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● DeepSeek${gl_bai}"
		echo -e "    ${gl_kjlan}https://api-docs.deepseek.com/${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● OpenRouter${gl_bai}"
		echo -e "    ${gl_kjlan}https://openrouter.ai/${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● Kimi${gl_bai}"
		echo -e "    ${gl_kjlan}https://platform.moonshot.cn/docs/guide/start-using-kimi-api${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● 超算互联网${gl_bai}"
		echo -e "    ${gl_kjlan}https://www.scnet.cn/${gl_bai}"
		echo ""
		echo -e "  ${gl_huang}● 优云智算${gl_bai} ${gl_zi}[AFF]${gl_bai}"
		echo -e "    ${gl_kjlan}https://passport.compshare.cn/register?referral_code=4mscFZXfutfFi8swMVsPuf${gl_bai}"
		echo ""
		echo -e "  ${gl_huang}● 硅基流动${gl_bai} ${gl_zi}[AFF]${gl_bai}"
		echo -e "    ${gl_kjlan}https://cloud.siliconflow.cn/i/irWVdPic${gl_bai}"
		echo ""
		echo -e "  ${gl_huang}● 智谱 GLM${gl_bai} ${gl_zi}[AFF]${gl_bai}"
		echo -e "    ${gl_kjlan}https://www.bigmodel.cn/glm-coding?ic=HYOTDOAJMR${gl_bai}"
		echo ""
		echo -e "  ${gl_huang}● PackyAPI${gl_bai} ${gl_zi}[AFF]${gl_bai}"
		echo -e "    ${gl_kjlan}https://www.packyapi.com/register?aff=wHri${gl_bai}"
		echo ""
		echo -e "  ${gl_huang}● 云雾 API${gl_bai} ${gl_zi}[AFF]${gl_bai}"
		echo -e "    ${gl_kjlan}https://yunwu.ai/register?aff=ZuyK${gl_bai}"
		echo ""
		echo -e "  ${gl_huang}● 柏拉图AI${gl_bai} ${gl_zi}[AFF]${gl_bai}"
		echo -e "    ${gl_kjlan}https://api.bltcy.ai/register?aff=TBzb114019${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● MiniMax${gl_bai}"
		echo -e "    ${gl_kjlan}https://www.minimaxi.com/${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● NVIDIA${gl_bai}"
		echo -e "    ${gl_kjlan}https://build.nvidia.com/settings/api-keys${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● Ollama${gl_bai}"
		echo -e "    ${gl_kjlan}https://ollama.com/${gl_bai}"
		echo ""
		echo -e "  ${gl_lv}● 白山云${gl_bai}"
		echo -e "    ${gl_kjlan}https://ai.baishan.com/${gl_bai}"
		echo ""
		echo -e "${gl_kjlan}────────────────────────────────────────────────────────────${gl_bai}"
		echo -e "  ${gl_zi}图例：${gl_lv}● 官方入口${gl_bai}  ${gl_huang}● AFF 推荐入口${gl_bai}"
		echo ""
		echo -e "${gl_huang}提示：复制链接到浏览器打开即可访问${gl_bai}"
		echo ""
		read -erp "按回车键返回..." dummy || return 1
	}

	openclaw_api_manage_menu() {
		send_stats "OpenClaw API入口"
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw API 管理"
			echo "======================================="
			openclaw_api_manage_list
			echo "---------------------------------------"
			echo "1. 添加API"
			echo "2. 同步API供应商模型列表"
			echo "3. 切换 API 类型（completions / responses）"
			echo "4. 删除API"
			echo "5. API 厂商推荐"
			echo "0. 退出"
			echo "---------------------------------------"
			read -erp "请输入你的选择: " api_choice || return 1

			case "$api_choice" in
				1)
					add-openclaw-provider-interactive
					;;
				2)
					sync-openclaw-provider-interactive
					;;
				3)
					fix-openclaw-provider-protocol-interactive
					;;
				4)
					delete-openclaw-provider-interactive
					;;
				5)
					openclaw_api_providers_showcase
					;;
				0)
					return 0
					;;
				*)
					echo "无效的选择，请重试。"
					sleep 1
					;;
			esac
		done
	}



	install_gum() {
	    if command -v gum >/dev/null 2>&1; then
	        return 0
	    fi

 		if command -v apt >/dev/null 2>&1; then
	        mkdir -p /etc/apt/keyrings
	        curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
	        echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | tee /etc/apt/sources.list.d/charm.list > /dev/null
	        apt update && apt install -y gum
	    elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
	        cat > /etc/yum.repos.d/charm.repo <<'REPO'
[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key
REPO
	        rpm --import https://repo.charm.sh/yum/gpg.key
	        if command -v dnf >/dev/null 2>&1; then
	            dnf install -y gum
	        else
	            yum install -y gum
	        fi
	    elif command -v zypper >/dev/null 2>&1; then
	        zypper --non-interactive refresh
	        zypper --non-interactive install gum
	    fi
	}



	change_model() {
		send_stats "换模型"

		local orange="#FF8C00"

		openclaw_probe_status_line() {
			local status_text="$1"
			local status_color_ok='[32m'
			local status_color_fail='[31m'
			local status_color_reset='[0m'
			if [ "$status_text" = "可用" ]; then
				printf "%b最小检测结果：%s%b
" "$status_color_ok" "$status_text" "$status_color_reset"
			else
				printf "%b最小检测结果：%s%b
" "$status_color_fail" "$status_text" "$status_color_reset"
			fi
		}

		openclaw_model_probe() {
			local target_model="$1"
			local probe_timeout=25
			local tmp_payload tmp_response probe_result probe_status reply_preview reply_trimmed
			local oc_config provider_name base_url api_key request_model
			local first_endpoint second_endpoint
			local first_exit first_http first_latency second_exit second_http second_latency
			local first_reply second_reply

			oc_config=$(openclaw_get_config_file)
			[ ! -f "$oc_config" ] && {
				OPENCLAW_PROBE_STATUS="ERROR"
				OPENCLAW_PROBE_MESSAGE="未找到 openclaw 配置文件"
				OPENCLAW_PROBE_LATENCY="-"
				OPENCLAW_PROBE_REPLY="-"
				return 1
			}

			provider_name="${target_model%%/*}"
			request_model="${target_model#*/}"
			base_url=$(jq -r --arg provider "$provider_name" '.models.providers[$provider].baseUrl // empty' "$oc_config" 2>/dev/null)
			api_key=$(jq -r --arg provider "$provider_name" '.models.providers[$provider].apiKey // empty' "$oc_config" 2>/dev/null)
			if [ -z "$provider_name" ] || [ -z "$base_url" ] || [ -z "$api_key" ]; then
				OPENCLAW_PROBE_STATUS="ERROR"
				OPENCLAW_PROBE_MESSAGE="未读取到 provider/baseUrl/apiKey"
				OPENCLAW_PROBE_LATENCY="-"
				OPENCLAW_PROBE_REPLY="-"
				return 1
			fi

			base_url="${base_url%/}"
			first_endpoint="/responses"
			second_endpoint="/chat/completions"

			openclaw_extract_probe_reply() {
				python3 - "$1" <<'PYTHON_EOF'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
raw = path.read_text(encoding='utf-8', errors='replace').strip()
reply = ''
if raw:
    try:
        data = json.loads(raw)
        if isinstance(data, dict):
            choices = data.get('choices') or []
            if choices and isinstance(choices[0], dict):
                message = choices[0].get('message') or {}
                if isinstance(message, dict):
                    reply = message.get('content') or ''
            if not reply:
                output = data.get('output') or []
                if isinstance(output, list):
                    texts = []
                    for item in output:
                        if not isinstance(item, dict):
                            continue
                        for content in item.get('content') or []:
                            if not isinstance(content, dict):
                                continue
                            text = content.get('text')
                            if isinstance(text, str) and text.strip():
                                texts.append(text.strip())
                        if texts:
                            break
                    if texts:
                        reply = ' '.join(texts)
            if not reply:
                for key in ('error', 'message', 'detail'):
                    value = data.get(key)
                    if isinstance(value, str) and value.strip():
                        reply = value.strip()
                        break
                    if isinstance(value, dict):
                        nested = value.get('message')
                        if isinstance(nested, str) and nested.strip():
                            reply = nested.strip()
                            break
    except Exception:
        reply = raw
reply = ' '.join(str(reply).split())
print(reply)
PYTHON_EOF
			}

			openclaw_run_probe() {
				local endpoint="$1"
				tmp_payload=$(mktemp)
				tmp_response=$(mktemp)
				if [ "$endpoint" = "/responses" ]; then
					printf '{"model":"%s","input":"hi","temperature":0,"max_output_tokens":16}' "$request_model" > "$tmp_payload"
				else
					printf '{"model":"%s","messages":[{"role":"user","content":"hi"}],"temperature":0,"max_tokens":16}' "$request_model" > "$tmp_payload"
				fi

				probe_result=$(python3 - "$base_url" "$api_key" "$tmp_payload" "$tmp_response" "$probe_timeout" "$endpoint" <<'PYTHON_EOF'
import sys
import time
import urllib.error
import urllib.request

base_url, api_key, payload_path, response_path, timeout, endpoint = sys.argv[1:7]
timeout = int(timeout)
url = base_url + endpoint
payload = open(payload_path, 'rb').read()
req = urllib.request.Request(
    url,
    data=payload,
    headers={
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {api_key}',
    },
    method='POST',
)
start = time.time()
body = b''
status = 0
exit_code = 0
try:
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        status = getattr(resp, 'status', 200)
        body = resp.read()
except urllib.error.HTTPError as e:
    status = getattr(e, 'code', 0) or 0
    body = e.read()
    exit_code = 22
except Exception as e:
    body = str(e).encode('utf-8', errors='replace')
    exit_code = 1
elapsed = int((time.time() - start) * 1000)
with open(response_path, 'wb') as f:
    f.write(body)
print(f"{exit_code}|{status}|{elapsed}")
PYTHON_EOF
)
				probe_status=$?
				reply_preview=$(openclaw_extract_probe_reply "$tmp_response")
				rm -f "$tmp_payload" "$tmp_response"
				return $probe_status
			}

			openclaw_run_probe "$first_endpoint"
			first_exit=${probe_result%%|*}
			first_http=${probe_result#*|}
			first_http=${first_http%%|*}
			first_latency=${probe_result##*|}
			first_reply="$reply_preview"

			reply_trimmed=$(printf '%s' "$first_reply" | cut -c1-120)
			[ -z "$reply_trimmed" ] && reply_trimmed="(空返回)"

			if [ "$first_exit" = "0" ] && [ "$first_http" -ge 200 ] && [ "$first_http" -lt 300 ]; then
				OPENCLAW_PROBE_STATUS="OK"
				OPENCLAW_PROBE_MESSAGE="${first_endpoint} -> HTTP ${first_http}"
				OPENCLAW_PROBE_LATENCY="${first_latency}ms"
				OPENCLAW_PROBE_REPLY="$reply_trimmed"
				return 0
			fi

			openclaw_run_probe "$second_endpoint"
			second_exit=${probe_result%%|*}
			second_http=${probe_result#*|}
			second_http=${second_http%%|*}
			second_latency=${probe_result##*|}
			second_reply="$reply_preview"

			reply_trimmed=$(printf '%s' "$second_reply" | cut -c1-120)
			[ -z "$reply_trimmed" ] && reply_trimmed="(空返回)"

			if [ "$second_exit" = "0" ] && [ "$second_http" -ge 200 ] && [ "$second_http" -lt 300 ]; then
				OPENCLAW_PROBE_STATUS="OK"
				OPENCLAW_PROBE_MESSAGE="${first_endpoint} -> HTTP ${first_http:-0}，切换 ${second_endpoint} -> HTTP ${second_http}"
				OPENCLAW_PROBE_LATENCY="${second_latency}ms"
				OPENCLAW_PROBE_REPLY="$reply_trimmed"
				return 0
			fi

			reply_trimmed=$(printf '%s' "$first_reply" | cut -c1-120)
			[ -z "$reply_trimmed" ] && reply_trimmed=$(printf '%s' "$second_reply" | cut -c1-120)
			[ -z "$reply_trimmed" ] && reply_trimmed="(空返回)"

			OPENCLAW_PROBE_STATUS="FAIL"
			OPENCLAW_PROBE_MESSAGE="${first_endpoint} -> HTTP ${first_http:-0} / exit ${first_exit:-1}；${second_endpoint} -> HTTP ${second_http:-0} / exit ${second_exit:-1}"
			OPENCLAW_PROBE_LATENCY="${first_latency:-?}ms -> ${second_latency:-?}ms"
			OPENCLAW_PROBE_REPLY="$reply_trimmed"
			return 1
		}

		clear

		while true; do
			local models_raw models_list default_model model_count selected_model confirm_switch

			# 从配置文件读取模型键（不调用 openclaw models list）
			local oc_config
			oc_config=$(openclaw_get_config_file)

			models_raw=$(jq -r '.agents.defaults.models | if type == "object" then keys[] else .[] end' "$oc_config" 2>/dev/null | sed '/^\s*$/d')
			if [ -z "$models_raw" ]; then
				echo "获取模型列表失败：配置文件中未找到 agents.defaults.models。"
				break_end
				return 1
			fi

			# 为每个模型加编号，便于快速定位（例如："(10) or-api/...:free"）
			models_list=$(echo "$models_raw" | awk '{print "(" NR ") " $0}')
			model_count=$(echo "$models_list" | sed '/^\s*$/d' | wc -l | tr -d ' ')

			# 从配置文件读取默认模型（更快）；失败再回退到 openclaw 命令
			default_model=$(jq -r '.agents.defaults.model.primary // empty' "$oc_config" 2>/dev/null)
			[ -z "$default_model" ] && default_model="(unknown)"

			clear

			install_gum
			install gum

			# 若 gum 不存在，降级为原始手动输入流程
			if ! command -v gum >/dev/null 2>&1 || ! gum --version >/dev/null 2>&1; then
				echo "--- 模型管理 ---"
				echo "当前可用模型:"
				jq -r '.agents.defaults.models | if type == "object" then keys[] else .[] end' "$oc_config" 2>/dev/null | sed '/^\s*$/d'
				echo "----------------"
				read -e -p "请输入要设置的模型名称 (例如 openrouter/openai/gpt-4o)（输入 0 退出）： " selected_model || return 1

				if [ "$selected_model" = "0" ]; then
					echo "操作已取消，正在退出..."
					break
				fi

				if [ -z "$selected_model" ]; then
					echo "错误：模型名称不能为空。请重试。"
					echo ""
					continue
				fi

				echo "正在切换模型为: $selected_model ..."
				if ! openclaw models set "$selected_model"; then
					echo "切换失败：openclaw models set 返回错误。"
					break_end
					return 1
				fi
				openclaw_sync_sessions_model "$selected_model"
				start_gateway

				break_end
				return 0
			else
				if ! command -v gum >/dev/null 2>&1 || ! gum --version >/dev/null 2>&1; then
					echo "gum 不可用，返回旧版输入模式。"
					sleep 1
					continue
				fi
				gum style --foreground "$orange" --bold "模型管理"
				gum style --foreground "$orange" "可用模型（Auth=yes）：${model_count}"
				gum style --foreground "$orange" "当前默认：${default_model}"
				echo ""
				gum style --faint "↑↓ 选择 / Enter 测试 / Esc 退出"
				echo ""

				selected_model=$(echo "$models_list" | gum filter 					--placeholder "搜索模型（如 cli-api/gpt-5.2）" 					--prompt "选择模型 > " 					--indicator "➜ " 					--prompt.foreground "$orange" 					--indicator.foreground "$orange" 					--cursor-text.foreground "$orange" 					--match.foreground "$orange" 					--header "" 					--height 35)

				if [ -z "$selected_model" ] || echo "$selected_model" | head -n 1 | grep -iqE '^(error|usage|gum:)'; then
					echo "操作已取消，正在退出..."
					break
				fi
			fi

			selected_model=$(echo "$selected_model" | sed -E 's/^\([0-9]+\)[[:space:]]+//')

			echo ""
			echo "正在检测模型: $selected_model"
			if openclaw_model_probe "$selected_model"; then
				openclaw_probe_status_line "可用"
			else
				openclaw_probe_status_line "不可用"
			fi
			echo "状态：$OPENCLAW_PROBE_MESSAGE"
			echo "延迟：$OPENCLAW_PROBE_LATENCY"
			echo "摘要：$OPENCLAW_PROBE_REPLY"
			echo ""

			printf "是否切换到该模型？[y/N，Esc 返回列表]: "
			IFS= read -rsn1 confirm_switch
			echo ""
			if [ "$confirm_switch" = $'' ]; then
				confirm_switch="no"
			else
				case "$confirm_switch" in
					[yY])
						IFS= read -rsn1 -t 5 _enter_key
						confirm_switch="yes"
						;;
					[nN]|"") confirm_switch="no" ;;
					*) confirm_switch="no" ;;
				esac
			fi

			if [ "$confirm_switch" != "yes" ]; then
				echo "已返回模型选择列表。"
				sleep 1
				continue
			fi

			echo "正在切换模型为: $selected_model ..."
			if ! openclaw models set "$selected_model"; then
				echo "切换失败：openclaw models set 返回错误。"
				break_end
				return 1
			fi
			openclaw_sync_sessions_model "$selected_model"
			start_gateway

			break_end
			done
		}


		openclaw_get_config_file() {
			local user_config="${HOME}/.openclaw/openclaw.json"
			local root_config="/root/.openclaw/openclaw.json"
			if [ -f "$user_config" ]; then
				echo "$user_config"
			elif [ "$HOME" = "/root" ] && [ -f "$root_config" ]; then
				echo "$root_config"
			else
				echo "$user_config"
			fi
		}

		openclaw_get_agents_dir() {
			local user_agents="${HOME}/.openclaw/agents"
			local root_agents="/root/.openclaw/agents"
			if [ -d "$user_agents" ]; then
				echo "$user_agents"
			elif [ "$HOME" = "/root" ] && [ -d "$root_agents" ]; then
				echo "$root_agents"
			else
				echo "$user_agents"
			fi
		}

		openclaw_sync_sessions_model() {
			local model_ref="$1"
			[ -z "$model_ref" ] && return 1

			local agents_dir
			agents_dir=$(openclaw_get_agents_dir)
			[ ! -d "$agents_dir" ] && return 0

			local provider="${model_ref%%/*}"
			local model="${model_ref#*/}"
			[ "$provider" = "$model_ref" ] && { provider=""; model="$model_ref"; }

			local count=0
			local agent_dir sessions_file backup_file

			for agent_dir in "$agents_dir"/*/; do
				[ ! -d "$agent_dir" ] && continue
				sessions_file="$agent_dir/sessions/sessions.json"
				[ ! -f "$sessions_file" ] && continue

				backup_file="${sessions_file}.bak"
				cp "$sessions_file" "$backup_file" 2>/dev/null || continue

				if command -v jq >/dev/null 2>&1; then
					local tmp_json
					tmp_json=$(mktemp)
					if [ -n "$provider" ]; then
						jq --arg model "$model" --arg provider "$provider" \
							'to_entries | map(.value.modelOverride = $model | .value.providerOverride = $provider) | from_entries' \
							"$sessions_file" > "$tmp_json" 2>/dev/null && \
							mv "$tmp_json" "$sessions_file" && \
							count=$((count + 1))
					else
						jq --arg model "$model" \
							'to_entries | map(.value.modelOverride = $model | del(.value.providerOverride)) | from_entries' \
							"$sessions_file" > "$tmp_json" 2>/dev/null && \
							mv "$tmp_json" "$sessions_file" && \
							count=$((count + 1))
					fi
				fi
			done

			[ "$count" -gt 0 ] && echo "✅ 已同步 $count 个 agent 的会话模型为 $model_ref"
			return 0
		}

		resolve_openclaw_plugin_id() {
			local raw_input="$1"
			local plugin_id="$raw_input"

			plugin_id="${plugin_id#@openclaw/}"
			if [[ "$plugin_id" == @*/* ]]; then
				plugin_id="${plugin_id##*/}"
			fi
			plugin_id="${plugin_id%%@*}"
			echo "$plugin_id"
		}

		sync_openclaw_plugin_allowlist() {
			local plugin_id="$1"
			[ -z "$plugin_id" ] && return 1

			local config_file
			config_file=$(openclaw_get_config_file)

			mkdir -p "$(dirname "$config_file")"
			if [ ! -s "$config_file" ]; then
				echo '{}' > "$config_file"
			fi

			if command -v jq >/dev/null 2>&1; then
				local tmp_json
				tmp_json=$(mktemp)
				if jq --arg pid "$plugin_id" '
					.plugins = (if (.plugins | type) == "object" then .plugins else {} end)
					| .plugins.allow = (if (.plugins.allow | type) == "array" then .plugins.allow else [] end)
					| if (.plugins.allow | index($pid)) == null then .plugins.allow += [$pid] else . end
				' "$config_file" > "$tmp_json" 2>/dev/null && mv "$tmp_json" "$config_file"; then
					echo "✅ 已同步 plugins.allow 白名单: $plugin_id"
					return 0
				fi
				rm -f "$tmp_json"
			fi

			if command -v python3 >/dev/null 2>&1; then
				if python3 - "$config_file" "$plugin_id" <<'PYTHON_EOF'
import json
import sys
from pathlib import Path

config_file = Path(sys.argv[1])
plugin_id = sys.argv[2]

try:
    data = json.loads(config_file.read_text(encoding='utf-8')) if config_file.exists() else {}
    if not isinstance(data, dict):
        data = {}
except Exception:
    data = {}

plugins = data.get('plugins')
if not isinstance(plugins, dict):
    plugins = {}

a = plugins.get('allow')
if not isinstance(a, list):
    a = []

if plugin_id not in a:
    a.append(plugin_id)

plugins['allow'] = a
data['plugins'] = plugins
config_file.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding='utf-8')
PYTHON_EOF
				then
					echo "✅ 已同步 plugins.allow 白名单: $plugin_id"
					return 0
				fi
			fi

			echo "⚠️ 已安装插件，但同步 plugins.allow 失败，请手动检查: $config_file"
			return 1
		}

		sync_openclaw_plugin_denylist() {
			local plugin_id="$1"
			[ -z "$plugin_id" ] && return 1

			local config_file
			config_file=$(openclaw_get_config_file)

			mkdir -p "$(dirname "$config_file")"
			if [ ! -s "$config_file" ]; then
				echo '{}' > "$config_file"
			fi

			if command -v jq >/dev/null 2>&1; then
				local tmp_json
				tmp_json=$(mktemp)
				if jq --arg pid "$plugin_id" '
					.plugins = (if (.plugins | type) == "object" then .plugins else {} end)
					| .plugins.allow = (if (.plugins.allow | type) == "array" then .plugins.allow else [] end)
					| .plugins.allow = (.plugins.allow | map(select(. != $pid)))
				' "$config_file" > "$tmp_json" 2>/dev/null && mv "$tmp_json" "$config_file"; then
					echo "✅ 已从 plugins.allow 移除: $plugin_id"
					return 0
				fi
				rm -f "$tmp_json"
			fi

			if command -v python3 >/dev/null 2>&1; then
				if python3 - "$config_file" "$plugin_id" <<'PYTHON_EOF'
import json
import sys
from pathlib import Path

config_file = Path(sys.argv[1])
plugin_id = sys.argv[2]

try:
    data = json.loads(config_file.read_text(encoding='utf-8')) if config_file.exists() else {}
    if not isinstance(data, dict):
        data = {}
except Exception:
    data = {}

plugins = data.get('plugins')
if not isinstance(plugins, dict):
    plugins = {}

a = plugins.get('allow')
if not isinstance(a, list):
    a = []

a = [x for x in a if x != plugin_id]
plugins['allow'] = a
data['plugins'] = plugins
config_file.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding='utf-8')
PYTHON_EOF
				then
					echo "✅ 已从 plugins.allow 移除: $plugin_id"
					return 0
				fi
			fi

			echo "⚠️ plugins.allow 移除失败，请手动检查: $config_file"
			return 1
		}






		install_plugin() {
		send_stats "插件管理"
		while true; do
			clear
			echo "========================================"
			echo "            插件管理 (安装/删除)            "
			echo "========================================"
			echo "当前插件列表:"
			openclaw plugins list
			echo "--------------------------------------------------------"
			echo "推荐的常用插件 ID (直接复制括号内的 ID 即可):"
			echo "--------------------------------------------------------"
			echo "📱 通讯渠道:"
			echo "  - [feishu]       	# 飞书/Lark 集成"
			echo "  - [telegram]     	# Telegram 机器人"
			echo "  - [slack]        	# Slack 企业通讯"
			echo "  - [msteams]      	# Microsoft Teams"
			echo "  - [discord]      	# Discord 社区管理"
			echo "  - [whatsapp]     	# WhatsApp 自动化"
			echo ""
			echo "🧠 记忆与 AI:"
			echo "  - [memory-core]  	# 基础记忆 (文件检索)"
			echo "  - [memory-lancedb]	# 增强记忆 (向量数据库)"
			echo "  - [copilot-proxy]	# Copilot 接口转发"
			echo ""
			echo "⚙️ 功能扩展:"
			echo "  - [lobster]      	# 审批流 (带人工确认)"
			echo "  - [voice-call]   	# 语音通话能力"
			echo "  - [nostr]        	# 加密隐私聊天"
			echo "--------------------------------------------------------"

			echo "1) 安装/启用插件"
			echo "2) 删除/禁用插件"
			echo "0) 返回"
			read -e -p "请选择操作：" plugin_action || return 1

			[ "$plugin_action" = "0" ] && break
			[ -z "$plugin_action" ] && continue

			read -e -p "请输入插件 ID（空格分隔，输入 0 退出）： " raw_input || return 1
			[ "$raw_input" = "0" ] && break
			[ -z "$raw_input" ] && continue

			local success_list=""
			local failed_list=""
			local skipped_list=""
			local changed=false
			local token

			for token in $raw_input; do
				local plugin_id
				local plugin_full
				plugin_id=$(resolve_openclaw_plugin_id "$token")
				plugin_full="$token"
				[ -z "$plugin_id" ] && continue

				if [ "$plugin_action" = "1" ]; then
					echo "🔍 正在检查插件状态: $plugin_id"
					local plugin_list
					plugin_list=$(openclaw plugins list 2>/dev/null)

					if echo "$plugin_list" | grep -qw "$plugin_id" && echo "$plugin_list" | grep "$plugin_id" | grep -q "disabled"; then
						echo "💡 插件 [$plugin_id] 已预装，正在激活..."
						if openclaw plugins enable "$plugin_id"; then
							sync_openclaw_plugin_allowlist "$plugin_id"
							success_list="$success_list $plugin_id"
							changed=true
						else
							failed_list="$failed_list $plugin_id"
						fi
						continue
					fi

					if [ -d "/usr/lib/node_modules/openclaw/extensions/$plugin_id" ]; then
						echo "💡 发现系统内置目录存在该插件，尝试直接启用..."
						if openclaw plugins enable "$plugin_id"; then
							sync_openclaw_plugin_allowlist "$plugin_id"
							success_list="$success_list $plugin_id"
							changed=true
						else
							failed_list="$failed_list $plugin_id"
						fi
						continue
					fi

					echo "📥 本地未发现，尝试下载安装: $plugin_full"
					rm -rf "${HOME}/.openclaw/extensions/$plugin_id"
					[ "$HOME" != "/root" ] && rm -rf "/root/.openclaw/extensions/$plugin_id"
					if openclaw plugins install "$plugin_full"; then
						echo "✅ 下载成功，正在启用..."
						if openclaw plugins enable "$plugin_id"; then
							sync_openclaw_plugin_allowlist "$plugin_id"
							success_list="$success_list $plugin_id"
							changed=true
						else
							failed_list="$failed_list $plugin_id"
						fi
					else
						echo "❌ 安装失败：$plugin_full"
						failed_list="$failed_list $plugin_id"
					fi
				else
					echo "🗑️ 正在删除/禁用插件: $plugin_id"
					openclaw plugins disable "$plugin_id" >/dev/null 2>&1
					if openclaw plugins uninstall "$plugin_id"; then
						echo "✅ 已卸载: $plugin_id"
					else
						echo "⚠️ 卸载失败，可能为预装插件，仅禁用: $plugin_id"
					fi
					sync_openclaw_plugin_denylist "$plugin_id" >/dev/null 2>&1
					success_list="$success_list $plugin_id"
					changed=true
				fi
			done

			echo ""
			echo "====== 操作汇总 ======"
			echo "✅ 成功:$success_list"
			[ -n "$failed_list" ] && echo "❌ 失败:$failed_list"
			[ -n "$skipped_list" ] && echo "⏭️ 跳过:$skipped_list"

			if [ "$changed" = true ]; then
				echo "🔄 正在重启 OpenClaw 服务以加载变更..."
				start_gateway
			fi
			break_end
		done
	}


	install_skill() {
		send_stats "技能管理"
		while true; do
			clear
			echo "========================================"
			echo "            技能管理 (安装/删除)            "
			echo "========================================"
			echo "当前已安装技能:"
			openclaw skills list
			echo "----------------------------------------"

			# 输出推荐的实用技能列表
			echo "推荐的实用技能（可直接复制名称输入）："
			echo "github             # 管理 GitHub Issues/PR/CI (gh CLI)"
			echo "notion             # 操作 Notion 页面、数据库和块"
			echo "apple-notes        # macOS 原生笔记管理 (创建/编辑/搜索)"
			echo "apple-reminders    # macOS 提醒事项管理 (待办清单)"
			echo "1password          # 自动化读取和注入 1Password 密钥"
			echo "gog                # Google Workspace (Gmail/云盘/文档) 全能助手"
			echo "things-mac         # 深度整合 Things 3 任务管理"
			echo "bluebubbles        # 通过 BlueBubbles 完美收发 iMessage"
			echo "himalaya           # 终端邮件管理 (IMAP/SMTP 强力工具)"
			echo "summarize          # 网页/播客/YouTube 视频内容一键总结"
			echo "openhue            # 控制 Philips Hue 智能灯光场景"
			echo "video-frames       # 视频抽帧与短片剪辑 (ffmpeg 驱动)"
			echo "openai-whisper     # 本地音频转文字 (离线隐私保护)"
			echo "coding-agent       # 自动运行 Claude Code/Codex 等编程助手"
			echo "----------------------------------------"

			echo "1) 安装技能"
			echo "2) 删除技能"
			echo "0) 返回"
			read -e -p "请选择操作：" skill_action || return 1

			[ "$skill_action" = "0" ] && break
			[ -z "$skill_action" ] && continue

			read -e -p "请输入技能名称（空格分隔，输入 0 退出）： " skill_input || return 1
			[ "$skill_input" = "0" ] && break
			[ -z "$skill_input" ] && continue

			local success_list=""
			local failed_list=""
			local skipped_list=""
			local changed=false
			local token

			if [ "$skill_action" = "2" ]; then
				read -e -p "二次确认：删除仅影响用户目录 ~/.openclaw/workspace/skills，确认继续？(y/N): " confirm_del || return 1
				if [[ ! "$confirm_del" =~ ^[Yy]$ ]]; then
					echo "已取消删除。"
					break_end
					continue
				fi
			fi

			for token in $skill_input; do
				local skill_name
				skill_name="$token"
				[ -z "$skill_name" ] && continue

				if [ "$skill_action" = "1" ]; then
					local skill_found=false
					if [ -d "${HOME}/.openclaw/workspace/skills/${skill_name}" ]; then
						echo "💡 技能 [$skill_name] 已在用户目录安装。"
						skill_found=true
					elif [ -d "/usr/lib/node_modules/openclaw/skills/${skill_name}" ]; then
						echo "💡 技能 [$skill_name] 已在系统目录安装。"
						skill_found=true
					fi

					if [ "$skill_found" = true ]; then
						read -e -p "技能 [$skill_name] 已安装，是否重新安装？(y/N): " reinstall || return 1
						if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
							skipped_list="$skipped_list $skill_name"
							continue
						fi
					fi

					echo "正在安装技能：$skill_name ..."
					if npx clawhub install "$skill_name" --yes --no-input 2>/dev/null || npx clawhub install "$skill_name"; then
						echo "✅ 技能 $skill_name 安装成功。"
						success_list="$success_list $skill_name"
						changed=true
					else
						echo "❌ 安装失败：$skill_name"
						failed_list="$failed_list $skill_name"
					fi
				else
					echo "🗑️ 正在删除技能: $skill_name"
					npx clawhub uninstall "$skill_name" --yes --no-input 2>/dev/null || npx clawhub uninstall "$skill_name" >/dev/null 2>&1
					if [ -d "${HOME}/.openclaw/workspace/skills/${skill_name}" ]; then
						rm -rf "${HOME}/.openclaw/workspace/skills/${skill_name}"
						echo "✅ 已删除用户技能目录: $skill_name"
						success_list="$success_list $skill_name"
						changed=true
					else
						echo "⏭️ 未发现用户技能目录: $skill_name"
						skipped_list="$skipped_list $skill_name"
					fi
				fi
			done

			echo ""
			echo "====== 操作汇总 ======"
			echo "✅ 成功:$success_list"
			[ -n "$failed_list" ] && echo "❌ 失败:$failed_list"
			[ -n "$skipped_list" ] && echo "⏭️ 跳过:$skipped_list"

			if [ "$changed" = true ]; then
				echo "🔄 正在重启 OpenClaw 服务以加载变更..."
				start_gateway
			fi
			break_end
		done
	}

openclaw_json_get_bool() {
		local expr="$1"
		local config_file
		config_file=$(openclaw_get_config_file)
		if [ ! -s "$config_file" ]; then
			echo "false"
			return
		fi
		jq -r "$expr" "$config_file" 2>/dev/null || echo "false"
	}

	openclaw_channel_has_cfg() {
		local channel="$1"
		local config_file
		config_file=$(openclaw_get_config_file)
		if [ ! -s "$config_file" ]; then
			echo "false"
			return
		fi
		jq -r --arg c "$channel" '
			(.channels[$c] // null) as $v
			| if ($v | type) != "object" then
				false
			  else
				([ $v
				   | to_entries[]
				   | select((.key == "enabled" or .key == "dmPolicy" or .key == "groupPolicy" or .key == "streaming") | not)
				   | .value
				   | select(. != null and . != "" and . != false)
				 ] | length) > 0
			  end
		' "$config_file" 2>/dev/null || echo "false"
	}

	openclaw_dir_has_files() {
		local dir="$1"
		[ -d "$dir" ] && find "$dir" -type f -print -quit 2>/dev/null | grep -q .
	}

	openclaw_plugin_local_installed() {
		local plugin="$1"
		local config_file
		config_file=$(openclaw_get_config_file)
		if [ -s "$config_file" ] && jq -e --arg p "$plugin" '.plugins.installs[$p]' "$config_file" >/dev/null 2>&1; then
			return 0
		fi

		# 兼容两种常见目录命名：
		# - ~/.openclaw/extensions/qqbot
		# - ~/.openclaw/extensions/openclaw-qqbot
		# 避免无脑 substring，优先精确匹配与 openclaw- 前缀匹配。
		[ -d "${HOME}/.openclaw/extensions/${plugin}" ] \
			|| [ -d "${HOME}/.openclaw/extensions/openclaw-${plugin}" ] \
			|| [ -d "/usr/lib/node_modules/openclaw/extensions/${plugin}" ] \
			|| [ -d "/usr/lib/node_modules/openclaw/extensions/openclaw-${plugin}" ]
	}

	openclaw_bot_status_text() {
		local enabled="$1"
		local configured="$2"
		local connected="$3"
		local abnormal="$4"
		if [ "$abnormal" = "true" ]; then
			echo "异常"
		elif [ "$enabled" != "true" ]; then
			echo "未启用"
		elif [ "$connected" = "true" ]; then
			echo "已连接"
		elif [ "$configured" = "true" ]; then
			echo "已配置"
		else
			echo "未配置"
		fi
	}

	openclaw_colorize_bot_status() {
		local status="$1"
		case "$status" in
			已连接) echo -e "${gl_lv}${status}${gl_bai}" ;;
			已配置) echo -e "${gl_huang}${status}${gl_bai}" ;;
			异常) echo -e "${gl_hong}${status}${gl_bai}" ;;
			*) echo "$status" ;;
		esac
	}

	openclaw_print_bot_status_line() {
		local label="$1"
		local status="$2"
		echo -e "- ${label}: $(openclaw_colorize_bot_status "$status")"
	}

	openclaw_show_bot_local_status_block() {
		local config_file
		config_file=$(openclaw_get_config_file)
		local json_ok="false"
		if [ -s "$config_file" ] && jq empty "$config_file" >/dev/null 2>&1; then
			json_ok="true"
		fi

		local tg_enabled tg_cfg tg_connected tg_abnormal tg_status
		tg_enabled=$(openclaw_json_get_bool '.channels.telegram.enabled // .plugins.entries.telegram.enabled // false')
		tg_cfg=$(openclaw_channel_has_cfg "telegram")
		tg_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/telegram"; then
			tg_connected="true"
		fi
		tg_abnormal="false"
		if [ "$tg_enabled" = "true" ] && [ "$json_ok" != "true" ]; then
			tg_abnormal="true"
		fi
		tg_status=$(openclaw_bot_status_text "$tg_enabled" "$tg_cfg" "$tg_connected" "$tg_abnormal")

		local feishu_enabled feishu_cfg feishu_connected feishu_abnormal feishu_status
		feishu_enabled=$(openclaw_json_get_bool '.plugins.entries.feishu.enabled // .plugins.entries["openclaw-lark"].enabled // .channels.feishu.enabled // .channels.lark.enabled // false')
		feishu_cfg=$(openclaw_channel_has_cfg "feishu")
		if [ "$feishu_cfg" != "true" ]; then
			feishu_cfg=$(openclaw_channel_has_cfg "lark")
		fi
		feishu_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/feishu" || openclaw_dir_has_files "${HOME}/.openclaw/lark" || openclaw_dir_has_files "${HOME}/.openclaw/openclaw-lark"; then
			feishu_connected="true"
		fi
		feishu_abnormal="false"
		if [ "$feishu_enabled" = "true" ] && ! openclaw_plugin_local_installed "feishu" && ! openclaw_plugin_local_installed "lark" && ! openclaw_plugin_local_installed "openclaw-lark"; then
			feishu_abnormal="true"
		fi
		if [ "$feishu_enabled" = "true" ] && [ "$json_ok" != "true" ]; then
			feishu_abnormal="true"
		fi
		if [ "$feishu_connected" != "true" ] && [ "$feishu_enabled" = "true" ] && [ "$feishu_cfg" = "true" ] && { openclaw_plugin_local_installed "feishu" || openclaw_plugin_local_installed "lark" || openclaw_plugin_local_installed "openclaw-lark"; }; then
			feishu_connected="true"
		fi
		feishu_status=$(openclaw_bot_status_text "$feishu_enabled" "$feishu_cfg" "$feishu_connected" "$feishu_abnormal")

		local wa_enabled wa_cfg wa_connected wa_abnormal wa_status
		wa_enabled=$(openclaw_json_get_bool '.plugins.entries.whatsapp.enabled // .channels.whatsapp.enabled // false')
		wa_cfg=$(openclaw_channel_has_cfg "whatsapp")
		wa_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/whatsapp"; then
			wa_connected="true"
		fi
		wa_abnormal="false"
		if [ "$wa_enabled" = "true" ] && ! openclaw_plugin_local_installed "whatsapp"; then
			wa_abnormal="true"
		fi
		if [ "$wa_enabled" = "true" ] && [ "$json_ok" != "true" ]; then
			wa_abnormal="true"
		fi
		wa_status=$(openclaw_bot_status_text "$wa_enabled" "$wa_cfg" "$wa_connected" "$wa_abnormal")

		local dc_enabled dc_cfg dc_connected dc_abnormal dc_status
		dc_enabled=$(openclaw_json_get_bool '.channels.discord.enabled // .plugins.entries.discord.enabled // false')
		dc_cfg=$(openclaw_channel_has_cfg "discord")
		dc_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/discord"; then
			dc_connected="true"
		fi
		dc_abnormal="false"
		if [ "$dc_enabled" = "true" ] && [ "$json_ok" != "true" ]; then
			dc_abnormal="true"
		fi
		dc_status=$(openclaw_bot_status_text "$dc_enabled" "$dc_cfg" "$dc_connected" "$dc_abnormal")

		local slack_enabled slack_cfg slack_connected slack_abnormal slack_status
		slack_enabled=$(openclaw_json_get_bool '.plugins.entries.slack.enabled // .channels.slack.enabled // false')
		slack_cfg=$(openclaw_channel_has_cfg "slack")
		slack_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/slack"; then
			slack_connected="true"
		fi
		slack_abnormal="false"
		if [ "$slack_enabled" = "true" ] && ! openclaw_plugin_local_installed "slack"; then
			slack_abnormal="true"
		fi
		if [ "$slack_enabled" = "true" ] && [ "$json_ok" != "true" ]; then
			slack_abnormal="true"
		fi
		slack_status=$(openclaw_bot_status_text "$slack_enabled" "$slack_cfg" "$slack_connected" "$slack_abnormal")

		local qq_enabled qq_cfg qq_connected qq_abnormal qq_status
		qq_enabled=$(openclaw_json_get_bool '.plugins.entries.qqbot.enabled // .channels.qqbot.enabled // false')
		qq_cfg=$(openclaw_channel_has_cfg "qqbot")
		qq_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/qqbot/sessions" || openclaw_dir_has_files "${HOME}/.openclaw/qqbot/data"; then
			qq_connected="true"
		fi
		qq_abnormal="false"
		if [ "$qq_enabled" = "true" ] && ! openclaw_plugin_local_installed "qqbot"; then
			qq_abnormal="true"
		fi
		if [ "$qq_enabled" = "true" ] && [ "$json_ok" != "true" ]; then
			qq_abnormal="true"
		fi
		qq_status=$(openclaw_bot_status_text "$qq_enabled" "$qq_cfg" "$qq_connected" "$qq_abnormal")

		local wx_enabled wx_cfg wx_connected wx_abnormal wx_status
		wx_enabled=$(openclaw_json_get_bool '.plugins.entries.weixin.enabled // .plugins.entries["openclaw-weixin"].enabled // .channels.weixin.enabled // .channels["openclaw-weixin"].enabled // false')
		wx_cfg=$(openclaw_channel_has_cfg "weixin")
		if [ "$wx_cfg" != "true" ]; then
			wx_cfg=$(openclaw_channel_has_cfg "openclaw-weixin")
		fi
		wx_connected="false"
		if openclaw_dir_has_files "${HOME}/.openclaw/weixin" || openclaw_dir_has_files "${HOME}/.openclaw/openclaw-weixin"; then
			wx_connected="true"
		fi
		wx_abnormal="false"
		if [ "$wx_enabled" = "true" ] && ! openclaw_plugin_local_installed "weixin" && ! openclaw_plugin_local_installed "openclaw-weixin"; then
			wx_abnormal="true"
		fi
		if [ "$wx_enabled" = "true" ] && [ "$json_ok" != "true" ]; then
			wx_abnormal="true"
		fi
		wx_status=$(openclaw_bot_status_text "$wx_enabled" "$wx_cfg" "$wx_connected" "$wx_abnormal")

		echo "本地状态（仅本机配置/缓存，不做网络探测）："
		openclaw_print_bot_status_line "Telegram" "$tg_status"
		openclaw_print_bot_status_line "飞书(Lark)" "$feishu_status"
		openclaw_print_bot_status_line "WhatsApp" "$wa_status"
		openclaw_print_bot_status_line "Discord" "$dc_status"
		openclaw_print_bot_status_line "Slack" "$slack_status"
		openclaw_print_bot_status_line "QQ Bot" "$qq_status"
		openclaw_print_bot_status_line "微信 (Weixin)" "$wx_status"
	}

	change_tg_bot_code() {
		send_stats "机器人对接"
		while true; do
			clear
			echo "========================================"
			echo "            机器人连接对接            "
			echo "========================================"
			openclaw_show_bot_local_status_block
			echo "----------------------------------------"
			echo "1. Telegram 机器人对接"
			echo "2. 飞书 (Lark) 机器人对接"
			echo "3. WhatsApp 机器人对接"
			echo "4. QQ 机器人对接"
			echo "5. 微信机器人对接"
			echo "----------------------------------------"
			echo "0. 返回上一级选单"
			echo "----------------------------------------"
			read -e -p "请输入你的选择: " bot_choice || return 1

			case $bot_choice in
				1)
					read -e -p "请输入TG机器人收到的连接码 (例如 NYA99R2F)（输入 0 退出）： " code || return 1
					if [ "$code" = "0" ]; then continue; fi
					if [ -z "$code" ]; then echo "错误：连接码不能为空。"; sleep 1; continue; fi
					openclaw pairing approve telegram "$code"
					break_end
					;;
				2)
					npx -y @larksuite/openclaw-lark install
					openclaw config set channels.feishu.streaming true
					openclaw config set channels.feishu.requireMention true --json
					break_end
					;;
				3)
					read -e -p "请输入WhatsApp收到的连接码 (例如 NYA99R2F)（输入 0 退出）： " code || return 1
					if [ "$code" = "0" ]; then continue; fi
					if [ -z "$code" ]; then echo "错误：连接码不能为空。"; sleep 1; continue; fi
					openclaw pairing approve whatsapp "$code"
					break_end
					;;
				4)
					echo "QQ 官方对接地址："
					echo "https://q.qq.com/qqbot/openclaw/login.html"
					break_end
					;;
				5)
					npx -y @tencent-weixin/openclaw-weixin-cli@latest install
					break_end
					;;
				0)
					return 0
					;;
				*)
					echo "无效的选择，请重试。"
					sleep 1
					;;
			esac
		done
	}


	openclaw_backup_root() {
		echo "${HOME}/.openclaw/backups"
	}

	openclaw_is_interactive_terminal() {
		[ -t 0 ] && [ -t 1 ]
	}

	openclaw_has_command() {
		command -v "$1" >/dev/null 2>&1
	}


	openclaw_is_safe_relpath() {
		local rel="$1"
		[ -z "$rel" ] && return 1
		[[ "$rel" = /* ]] && return 1
		[[ "$rel" == *"//"* ]] && return 1
		[[ "$rel" == *$'\n'* ]] && return 1
		[[ "$rel" == *$'\r'* ]] && return 1
		case "$rel" in
			../*|*/../*|*/..|..)
				return 1
				;;
		esac
		return 0
	}

	openclaw_restore_path_allowed() {
		local mode="$1"
		local rel="$2"
		case "$mode" in
			memory)
				case "$rel" in
					MEMORY.md|AGENTS.md|USER.md|SOUL.md|TOOLS.md|memory/*) return 0 ;;
					*) return 1 ;;
				esac
				;;
			project)
				case "$rel" in
					openclaw.json|workspace/*|extensions/*|skills/*|prompts/*|tools/*|telegram/*|feishu/*|whatsapp/*|discord/*|slack/*|qqbot/*|logs/*) return 0 ;;
					*) return 1 ;;
				esac
				;;
			*)
				return 1
				;;
		esac
	}

	openclaw_pack_backup_archive() {
		local backup_type="$1"
		local export_mode="$2"
		local payload_dir="$3"
		local output_file="$4"

		local tmp_root
		tmp_root=$(mktemp -d) || return 1
		local pack_dir="$tmp_root/package"
		mkdir -p "$pack_dir"

		cp -a "$payload_dir" "$pack_dir/payload"

		(
			cd "$pack_dir/payload" || exit 1
			find . -type f | sed 's|^\./||' | sort > "$pack_dir/manifest.files"
			: > "$pack_dir/manifest.sha256"
			while IFS= read -r f; do
				[ -z "$f" ] && continue
				sha256sum "$f" >> "$pack_dir/manifest.sha256"
			done < "$pack_dir/manifest.files"
		) || { rm -rf "$tmp_root"; return 1; }

		cat > "$pack_dir/backup.meta" <<EOF
TYPE=$backup_type
MODE=$export_mode
CREATED_AT=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
HOST=$(hostname)
EOF

		mkdir -p "$(dirname "$output_file")"
		tar -C "$pack_dir" -czf "$output_file" backup.meta manifest.files manifest.sha256 payload
		local rc=$?
		rm -rf "$tmp_root"
		return $rc
	}

	openclaw_offer_transfer_hint() {
		local file_path="$1"

		echo "可使用以下方式下载备份文件："
		echo "- 本地路径: $file_path"
		echo "- scp 示例: scp root@你的服务器:$file_path ./"
		echo "- 或使用 SFTP 客户端下载"
	}

	openclaw_prepare_import_archive() {
		local expected_type="$1"
		local archive_path="$2"
		local unpack_root="$3"

		[ ! -f "$archive_path" ] && { echo "❌ 文件不存在: $archive_path"; return 1; }
		mkdir -p "$unpack_root"
		tar -xzf "$archive_path" -C "$unpack_root" || { echo "❌ 备份包解压失败"; return 1; }

		local pkg_dir="$unpack_root/package"
		if [ -f "$unpack_root/backup.meta" ]; then
			pkg_dir="$unpack_root"
		fi

		for required in backup.meta manifest.files manifest.sha256 payload; do
			[ -e "$pkg_dir/$required" ] || { echo "❌ 备份包缺少必要文件: $required"; return 1; }
		done

		local real_type
		real_type=$(grep '^TYPE=' "$pkg_dir/backup.meta" | head -n1 | cut -d'=' -f2-)
		if [ "$real_type" != "$expected_type" ]; then
			echo "❌ 备份类型不匹配，期望: $expected_type，实际: ${real_type:-未知}"
			return 1
		fi

		(
			cd "$pkg_dir/payload" || exit 1
			sha256sum -c ../manifest.sha256 >/dev/null
		) || { echo "❌ sha256 校验失败，拒绝还原"; return 1; }

		echo "$pkg_dir"
		return 0
	}

	openclaw_get_all_agent_workspaces() {
		local config_file
		config_file=$(openclaw_get_config_file)
		if [ -f "$config_file" ]; then
			python3 - "$config_file" <<'PY'
import json, sys, os
try:
    with open(sys.argv[1]) as f: data = json.load(f)
    agents = data.get("agents", {}).get("list", [])
    results = [{"id": "main", "ws": os.path.expanduser("~/.openclaw/workspace")}]
    for a in agents:
        aid = a.get("id"); ws = a.get("workspace")
        if aid and ws and aid != "main": results.append({"id": aid, "ws": os.path.expanduser(ws)})
    print(json.dumps(results))
except: print("[]")
PY
		else
			echo '[{"id": "main", "ws": "'"${HOME}"'/.openclaw/workspace"}]'
		fi
	}

	openclaw_memory_backup_export() {
		send_stats "OpenClaw记忆全量备份"
		local backup_root=$(openclaw_backup_root)
		local ts=$(date +%Y%m%d-%H%M%S)
		local out_file="$backup_root/openclaw-memory-full-${ts}.tar.gz"
		mkdir -p "$backup_root"
		local tmp_payload=$(mktemp -d) || return 1
		local workspaces_json=$(openclaw_get_all_agent_workspaces)
		python3 -c "import json, sys, os, shutil;
workspaces = json.loads(sys.argv[1]); tmp_payload = sys.argv[2]
for item in workspaces:
    aid = item['id']; ws = item['ws']
    if not os.path.isdir(ws): continue
    target_dir = os.path.join(tmp_payload, 'agents', aid)
    os.makedirs(target_dir, exist_ok=True)
    for f in ['MEMORY.md', 'memory']:
        src = os.path.join(ws, f)
        if os.path.exists(src):
            if os.path.isfile(src): shutil.copy2(src, target_dir)
            else: shutil.copytree(src, os.path.join(target_dir, f), dirs_exist_ok=True)
" "$workspaces_json" "$tmp_payload"
		if ! find "$tmp_payload" -mindepth 1 -print -quit | grep -q .; then
			echo "❌ 未找到可备份的记忆文件"; rm -rf "$tmp_payload"; break_end; return 1
		fi
		if openclaw_pack_backup_archive "memory-full" "multi-agent" "$tmp_payload" "$out_file"; then
			echo "✅ 记忆全量备份完成 (含多智能体): $out_file"; openclaw_offer_transfer_hint "$out_file"
		else
			echo "❌ 记忆全量备份失败"
		fi
		rm -rf "$tmp_payload"; break_end
	}

	openclaw_memory_backup_import() {
		send_stats "OpenClaw记忆全量还原"
		local archive_path=$(openclaw_read_import_path "还原记忆全量 (支持多智能体)")
		[ -z "$archive_path" ] && { echo "❌ 未输入路径"; break_end; return 1; }
		local tmp_unpack=$(mktemp -d) || return 1
		local pkg_dir=$(openclaw_prepare_import_archive "memory-full" "$archive_path" "$tmp_unpack") || { rm -rf "$tmp_unpack"; break_end; return 1; }
		local workspaces_json=$(openclaw_get_all_agent_workspaces)
		python3 -c 'import json, sys, os, shutil;
workspaces = {item["id"]: item["ws"] for item in json.loads(sys.argv[1])};
payload_dir = sys.argv[2]; agents_root = os.path.join(payload_dir, "agents")
if os.path.isdir(agents_root):
    for aid in os.listdir(agents_root):
        if aid in workspaces:
            src_agent_dir = os.path.join(agents_root, aid); dest_ws = workspaces[aid]
            os.makedirs(dest_ws, exist_ok=True)
            for f in os.listdir(src_agent_dir):
                src = os.path.join(src_agent_dir, f); dest = os.path.join(dest_ws, f)
                if os.path.isfile(src): shutil.copy2(src, dest)
                else: shutil.copytree(src, dest, dirs_exist_ok=True)
            print(f"✅ 已还原智能体记忆: {aid}")' "$workspaces_json" "$pkg_dir/payload"
		rm -rf "$tmp_unpack"; echo "✅ 记忆全量还原完成"; break_end
	}


	openclaw_project_backup_export() {
		send_stats "OpenClaw项目备份"
		local config_file
		config_file=$(openclaw_get_config_file)
		local openclaw_root
		openclaw_root=$(dirname "$config_file")
		if [ ! -d "$openclaw_root" ]; then
			echo "❌ 未找到 OpenClaw 根目录: $openclaw_root"
			break_end
			return 1
		fi

		echo "备份模式："
		echo "1. 安全模式（默认，推荐）：workspace + openclaw.json + extensions/skills/prompts/tools（如存在）"
		echo "2. 完整模式（含更多状态，敏感风险更高）"
		read -e -p "请选择备份模式（默认 1）: " export_mode || return 1
		[ -z "$export_mode" ] && export_mode="1"

		local mode_label="safe"
		local tmp_payload
		tmp_payload=$(mktemp -d) || return 1

		if [ "$export_mode" = "2" ]; then
			mode_label="full"
			for d in workspace extensions skills prompts tools; do
				[ -e "$openclaw_root/$d" ] && cp -a "$openclaw_root/$d" "$tmp_payload/"
			done
			[ -f "$openclaw_root/openclaw.json" ] && cp -a "$openclaw_root/openclaw.json" "$tmp_payload/"
			for d in telegram feishu whatsapp discord slack qqbot logs; do
				[ -e "$openclaw_root/$d" ] && cp -a "$openclaw_root/$d" "$tmp_payload/"
			done
		else
			[ -d "$openclaw_root/workspace" ] && cp -a "$openclaw_root/workspace" "$tmp_payload/"
			[ -f "$openclaw_root/openclaw.json" ] && cp -a "$openclaw_root/openclaw.json" "$tmp_payload/"
			for d in extensions skills prompts tools; do
				[ -e "$openclaw_root/$d" ] && cp -a "$openclaw_root/$d" "$tmp_payload/"
			done
		fi

		if ! find "$tmp_payload" -mindepth 1 -print -quit | grep -q .; then
			echo "❌ 未找到可备份的 OpenClaw 项目内容"
			rm -rf "$tmp_payload"
			break_end
			return 1
		fi

		local backup_root
		backup_root=$(openclaw_backup_root)
		mkdir -p "$backup_root"
		local out_file="$backup_root/openclaw-project-${mode_label}-$(date +%Y%m%d-%H%M%S).tar.gz"

		if openclaw_pack_backup_archive "openclaw-project" "$mode_label" "$tmp_payload" "$out_file"; then
			echo "✅ OpenClaw 项目备份完成 (${mode_label}): $out_file"
			openclaw_offer_transfer_hint "$out_file"
		else
			echo "❌ OpenClaw 项目备份失败"
		fi

		rm -rf "$tmp_payload"
		break_end
	}

	openclaw_project_backup_import() {
		send_stats "OpenClaw项目还原"
		local config_file
		config_file=$(openclaw_get_config_file)
		local openclaw_root
		openclaw_root=$(dirname "$config_file")
		mkdir -p "$openclaw_root"

		echo "⚠️ 高风险操作：项目还原会覆盖 OpenClaw 配置与工作区内容。"
		echo "⚠️ 还原前将执行 manifest/sha256 校验、白名单恢复、gateway 停启与健康检查。"
		read -e -p "请输入确认词【我已知晓高风险并继续还原】后继续: " confirm_text || return 1
		if [ "$confirm_text" != "我已知晓高风险并继续还原" ]; then
			echo "❌ 确认词不匹配，已取消还原"
			break_end
			return 1
		fi

		local archive_path
		archive_path=$(openclaw_read_import_path "请输入 OpenClaw 项目备份包路径")
		[ -z "$archive_path" ] && { echo "❌ 未输入备份路径"; break_end; return 1; }

		local tmp_unpack
		tmp_unpack=$(mktemp -d) || return 1
		local pkg_dir
		pkg_dir=$(openclaw_prepare_import_archive "openclaw-project" "$archive_path" "$tmp_unpack") || { rm -rf "$tmp_unpack"; break_end; return 1; }
		local rollback_dir
		rollback_dir=$(mktemp -d)
		if [ -d "$openclaw_root" ] && ! tar -czf "$rollback_dir/openclaw-before-restore.tar.gz" -C "$openclaw_root" .; then
			echo "❌ 无法创建还原前备份，已中止"; rm -rf "$rollback_dir" "$tmp_unpack"; break_end; return 1
		fi

		local invalid=0
		local valid_list
		valid_list=$(mktemp)
		while IFS= read -r rel; do
			[ -z "$rel" ] && continue
			if ! openclaw_is_safe_relpath "$rel" || ! openclaw_restore_path_allowed project "$rel"; then
				echo "❌ 检测到非法或越权路径: $rel"
				invalid=1
				break
			fi
			echo "$rel" >> "$valid_list"
		done < "$pkg_dir/manifest.files"

		if [ "$invalid" -ne 0 ]; then
			rm -f "$valid_list"
			rm -rf "$tmp_unpack"
			echo "❌ 还原中止：存在不安全路径"
			break_end
			return 1
		fi


		if command -v openclaw >/dev/null 2>&1; then
			echo "⏸️ 还原前停止 OpenClaw gateway..."
			if ! openclaw gateway stop >/dev/null 2>&1; then echo "❌ gateway 停止失败，已中止还原"; rm -f "$valid_list"; rm -rf "$tmp_unpack"; break_end; return 1; fi
		fi

		while IFS= read -r rel; do
			mkdir -p "$openclaw_root/$(dirname "$rel")"
			cp -a "$pkg_dir/payload/$rel" "$openclaw_root/$rel" || { echo "❌ 还原失败: $rel"; rm -f "$valid_list"; rm -rf "$tmp_unpack"; break_end; return 1; }
		done < "$valid_list"

		if command -v openclaw >/dev/null 2>&1; then
			echo "▶️ 还原后启动 OpenClaw gateway..."
			if ! openclaw gateway start >/dev/null 2>&1; then echo "❌ gateway 启动失败，请检查还原前备份: $rollback_dir/openclaw-before-restore.tar.gz"; fi
			sleep 2
			echo "🩺 gateway 健康检查："
			openclaw gateway status || true
		fi

		rm -f "$valid_list"
		rm -rf "$tmp_unpack"
		echo "还原前备份已保留: $rollback_dir/openclaw-before-restore.tar.gz"
		echo "✅ OpenClaw 项目还原完成"
		break_end
	}

	openclaw_backup_detect_type() {
		local file_name="$1"
		if [[ "$file_name" == openclaw-memory-full-*.tar.gz ]]; then
			echo "记忆备份文件"
		elif [[ "$file_name" == openclaw-project-*.tar.gz ]]; then
			echo "项目备份文件"
		else
			echo "其他备份文件"
		fi
	}

	openclaw_backup_collect_files() {
		local backup_root
		backup_root=$(openclaw_backup_root)
		mkdir -p "$backup_root"
		mapfile -t OPENCLAW_BACKUP_FILES < <(find "$backup_root" -maxdepth 1 -type f -name '*.tar.gz' -printf '%f\n' | sort -r)
	}


	openclaw_backup_render_file_list() {
		local backup_root i file_name file_path file_type file_size file_time
		local has_memory=0 has_project=0 has_other=0
		backup_root=$(openclaw_backup_root)
		openclaw_backup_collect_files

		echo "备份目录: $backup_root"
		if [ ${#OPENCLAW_BACKUP_FILES[@]} -eq 0 ]; then
			echo "暂无备份文件"
			return 0
		fi

		for i in "${!OPENCLAW_BACKUP_FILES[@]}"; do
			file_type=$(openclaw_backup_detect_type "${OPENCLAW_BACKUP_FILES[$i]}")
			case "$file_type" in
				"记忆备份文件") has_memory=1 ;;
				"项目备份文件") has_project=1 ;;
				"其他备份文件") has_other=1 ;;
			esac
		done

		if [ "$has_memory" -eq 1 ]; then
			echo "记忆备份文件"
			for i in "${!OPENCLAW_BACKUP_FILES[@]}"; do
				file_name="${OPENCLAW_BACKUP_FILES[$i]}"
				file_type=$(openclaw_backup_detect_type "$file_name")
				[ "$file_type" != "记忆备份文件" ] && continue
				file_path="$backup_root/$file_name"
				file_size=$(ls -lh "$file_path" | awk '{print $5}')
				file_time=$(date -d "$(stat -c %y "$file_path")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y "$file_path" | awk '{print $1" "$2}')
				printf "%s | %s | %s\n" "$file_name" "$file_size" "$file_time"
			done
		fi

		if [ "$has_project" -eq 1 ]; then
			echo "项目备份文件"
			for i in "${!OPENCLAW_BACKUP_FILES[@]}"; do
				file_name="${OPENCLAW_BACKUP_FILES[$i]}"
				file_type=$(openclaw_backup_detect_type "$file_name")
				[ "$file_type" != "项目备份文件" ] && continue
				file_path="$backup_root/$file_name"
				file_size=$(ls -lh "$file_path" | awk '{print $5}')
				file_time=$(date -d "$(stat -c %y "$file_path")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y "$file_path" | awk '{print $1" "$2}')
				printf "%s | %s | %s\n" "$file_name" "$file_size" "$file_time"
			done
		fi

		if [ "$has_other" -eq 1 ]; then
			echo "其他备份文件"
			for i in "${!OPENCLAW_BACKUP_FILES[@]}"; do
				file_name="${OPENCLAW_BACKUP_FILES[$i]}"
				file_type=$(openclaw_backup_detect_type "$file_name")
				[ "$file_type" != "其他备份文件" ] && continue
				file_path="$backup_root/$file_name"
				file_size=$(ls -lh "$file_path" | awk '{print $5}')
				file_time=$(date -d "$(stat -c %y "$file_path")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y "$file_path" | awk '{print $1" "$2}')
				printf "%s | %s | %s\n" "$file_name" "$file_size" "$file_time"
			done
		fi
	}

	openclaw_backup_file_exists_in_list() {
		local target_file="$1"
		local item
		for item in "${OPENCLAW_BACKUP_FILES[@]}"; do
			[ "$item" = "$target_file" ] && return 0
		done
		return 1
	}

	openclaw_backup_delete_file() {
		send_stats "OpenClaw删除备份文件"
		local backup_root backup_root_real user_input target_file target_path target_type
		backup_root=$(openclaw_backup_root)

		openclaw_backup_render_file_list
		if [ ${#OPENCLAW_BACKUP_FILES[@]} -eq 0 ]; then
			break_end
			return 0
		fi

		read -e -p "请输入要删除的文件名或完整路径（0 取消）: " user_input || return 1
		if [ "$user_input" = "0" ]; then
			echo "已取消删除。"
			break_end
			return 0
		fi
		if [ -z "$user_input" ]; then
			echo "❌ 输入不能为空。"
			break_end
			return 1
		fi

		backup_root_real=$(realpath -m "$backup_root")
		if [[ "$user_input" == /* ]]; then
			target_path=$(realpath -m "$user_input")
			case "$target_path" in
				"$backup_root_real"/*) ;;
				*)
					echo "❌ 路径越界：仅允许删除备份根目录内的文件。"
					break_end
					return 1
					;;
			esac
			target_file=$(basename "$target_path")
		else
			target_file=$(basename -- "$user_input")
			target_path="$backup_root/$target_file"
		fi

		if [ ! -f "$target_path" ]; then
			echo "❌ 目标文件不存在: $target_path"
			break_end
			return 1
		fi

		if ! openclaw_backup_file_exists_in_list "$target_file"; then
			echo "❌ 目标文件不在当前备份列表中。"
			break_end
			return 1
		fi

		target_type=$(openclaw_backup_detect_type "$target_file")

		echo "即将删除: [$target_type] $target_path"
		read -e -p "第一次确认：输入 yes 确认继续: " confirm_step1 || return 1
		if [ "$confirm_step1" != "yes" ]; then
			echo "已取消删除。"
			break_end
			return 0
		fi
		read -e -p "二次确认：输入 DELETE 执行删除: " confirm_step2 || return 1
		if [ "$confirm_step2" != "DELETE" ]; then
			echo "已取消删除。"
			break_end
			return 0
		fi

		if rm -f -- "$target_path"; then
			echo "✅ 删除成功: $target_file"
		else
			echo "❌ 删除失败: $target_file"
		fi
		break_end
	}

	openclaw_backup_list_files() {
		openclaw_backup_render_file_list
		break_end
	}

	openclaw_memory_config_file() {
		local user_config="${HOME}/.openclaw/openclaw.json"
		local root_config="/root/.openclaw/openclaw.json"
		if [ -f "$user_config" ]; then
			echo "$user_config"
		elif [ "$HOME" = "/root" ] && [ -f "$root_config" ]; then
			echo "$root_config"
		else
			echo "$user_config"
		fi
	}

	openclaw_memory_config_get() {
		local key="$1"
		local default_value="${2:-}"
		local value
		value=$(openclaw config get "$key" 2>/dev/null | head -n 1 | sed -e 's/^"//' -e 's/"$//')
		if [ -z "$value" ] || [ "$value" = "null" ] || [ "$value" = "undefined" ]; then
			echo "$default_value"
			return 0
		fi
		echo "$value"
	}

	openclaw_memory_config_set() {
		local key="$1"
		shift
		openclaw config set "$key" "$@" >/dev/null 2>&1
	}

	openclaw_memory_config_unset() {
		local key="$1"
		openclaw config unset "$key" >/dev/null 2>&1
	}

	openclaw_memory_cleanup_legacy_keys() {
		openclaw_memory_config_unset "memory.local"
	}

	openclaw_memory_list_agents() {
		if command -v openclaw >/dev/null 2>&1; then
			local agents_json
			agents_json=$(openclaw agents list --json 2>/dev/null || true)
			if [ -n "$agents_json" ]; then
				python3 - "$agents_json" <<'PY'
import json, os, sys
raw = sys.argv[1]
try:
    data = json.loads(raw)
except Exception:
    data = None
seen = set()
results = []
if isinstance(data, list):
    for item in data:
        if not isinstance(item, dict):
            continue
        aid = item.get('id')
        if not aid or aid in seen:
            continue
        ws = item.get('workspace') or ("~/.openclaw/workspace" if aid == 'main' else f"~/.openclaw/workspace-{aid}")
        results.append((aid, os.path.expanduser(ws)))
        seen.add(aid)
if results:
    for aid, ws in results:
        print(f"{aid}\t{ws}")
    raise SystemExit(0)
raise SystemExit(1)
PY
				[ $? -eq 0 ] && return 0
			fi
		fi
		local config_path
		config_path=$(openclaw_memory_config_file)
		python3 - "$config_path" <<'PY'
import json, os, sys
config_path = sys.argv[1]
results = [("main", os.path.expanduser("~/.openclaw/workspace"))]
seen = {"main"}
try:
    if os.path.exists(config_path):
        with open(config_path, encoding='utf-8') as f:
            data = json.load(f)
        agents = data.get('agents', {}).get('list', [])
        if isinstance(agents, list):
            for item in agents:
                if not isinstance(item, dict):
                    continue
                aid = item.get('id')
                ws = item.get('workspace')
                if not aid or aid in seen:
                    continue
                if not ws:
                    ws = f"~/.openclaw/workspace-{aid}"
                results.append((aid, os.path.expanduser(ws)))
                seen.add(aid)
except Exception:
    pass
for aid, ws in results:
    print(f"{aid}\t{ws}")
PY
	}

	openclaw_memory_status_value() {
		local key="$1"
		local agent_id="${2:-}"
		if [ -n "$agent_id" ]; then
			openclaw memory status --agent "$agent_id" 2>/dev/null | awk -F': ' -v k="$key" '$1==k {print $2; exit}'
		else
			openclaw memory status 2>/dev/null | awk -F': ' -v k="$key" '$1==k {print $2; exit}'
		fi
	}

	openclaw_memory_expand_path() {
		local raw_path="$1"
		if [ -z "$raw_path" ]; then
			echo ""
			return 0
		fi
		raw_path=$(echo "$raw_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
		if [[ "$raw_path" == ~* ]]; then
			echo "${raw_path/#\~/$HOME}"
		else
			echo "$raw_path"
		fi
	}

	openclaw_memory_rebuild_index_single() {
		local agent_id="${1:-main}"
		local store_raw store_file ts backup_file
		store_raw=$(openclaw_memory_status_value "Store" "$agent_id")
		store_file=$(openclaw_memory_expand_path "$store_raw")
		if [ -z "$store_file" ] || [ ! -f "$store_file" ]; then
			echo "⚠️ [$agent_id] 未找到索引库文件，可能为空或不存在。"
			echo "   Store 原始值: ${store_raw:-<空>}"
			echo "   仍将执行重建索引。"
		else
			ts=$(date +%Y%m%d_%H%M%S)
			backup_file="${store_file}.bak.${ts}"
			if mv "$store_file" "$backup_file"; then
				echo "✅ [$agent_id] 已备份索引: $backup_file"
			else
				echo "⚠️ [$agent_id] 索引备份失败，继续重建。"
			fi
		fi
		openclaw memory index --agent "$agent_id" --force
	}

	openclaw_memory_rebuild_index_safe() {
		local agent_id="${1:-main}"
		openclaw_memory_rebuild_index_single "$agent_id"
		openclaw gateway restart
		echo "✅ 索引已重建并自动重启网关"
		echo ""
		openclaw_memory_render_status
	}

	openclaw_memory_rebuild_index_all() {
		local count=0
		local agent_lines agent_id workspace
		agent_lines=$(openclaw_memory_list_agents)
		while IFS=$'\t' read -r agent_id workspace; do
			[ -z "$agent_id" ] && continue
			openclaw_memory_rebuild_index_single "$agent_id"
			count=$((count+1))
		done <<EOF
$agent_lines
EOF
		openclaw gateway restart
		echo "✅ 索引已重建并自动重启网关"
		echo "✅ 已为 ${count} 个智能体重建索引"
		echo ""
		openclaw_memory_render_status
	}

	openclaw_memory_prepare_workspace() {
		local agent_id="${1:-main}"
		local workspace memory_dir
		workspace=$(openclaw_memory_status_value "Workspace" "$agent_id")
		if [ -z "$workspace" ]; then
			workspace="$HOME/.openclaw/workspace"
			[ "$agent_id" != "main" ] && workspace="$HOME/.openclaw/workspace-$agent_id"
		fi
		memory_dir="$workspace/memory"
		if [ ! -d "$memory_dir" ]; then
			echo "🔧 [$agent_id] 记忆目录不存在，已自动创建: $memory_dir"
			mkdir -p "$memory_dir"
		fi
		return 0
	}

	openclaw_memory_prepare_workspace_all() {
		local count=0
		local agent_lines agent_id workspace
		agent_lines=$(openclaw_memory_list_agents)
		echo "检查并准备 $(printf '%s\n' "$agent_lines" | sed '/^\s*$/d' | wc -l | tr -d ' ') 个智能体工作区"
		while IFS=$'\t' read -r agent_id workspace; do
			[ -z "$agent_id" ] && continue
			openclaw_memory_prepare_workspace "$agent_id"
			count=$((count+1))
		done <<EOF
$agent_lines
EOF
		return 0
	}

	openclaw_memory_render_status() {
		local json_output
		json_output=$(openclaw memory status --json 2>/dev/null)
		if [ -z "$json_output" ]; then
			echo "获取记忆状态失败（openclaw memory status --json 无输出）"
			return 1
		fi
		python3 - "$json_output" <<'PY'
import json, sys
raw = sys.argv[1]
try:
    data = json.loads(raw)
except Exception:
    print("获取记忆状态失败（JSON 解析错误）")
    raise SystemExit(1)
if not isinstance(data, list) or len(data) == 0:
    print("未检测到任何智能体记忆状态。")
    raise SystemExit(0)
first = True
for entry in data:
    if not isinstance(entry, dict):
        continue
    agent_id = entry.get("agentId", "?")
    s = entry.get("status", {})
    if not isinstance(s, dict):
        s = {}
    if not first:
        print("")
    first = False
    print("Agent: %s" % agent_id)
    backend = s.get("backend") or s.get("provider") or "-"
    print("  底层方案: %s" % backend)
    files = s.get("files", 0)
    chunks = s.get("chunks", 0)
    print("  已收录: %s 文件 / %s 块" % (files, chunks))
    dirty = s.get("dirty")
    dirty_str = "是" if dirty else "否"
    print("  待刷新: %s" % dirty_str)
    vec = s.get("vector", {})
    if isinstance(vec, dict) and vec.get("enabled"):
        vec_str = "就绪" if vec.get("available") else "已启用(不可用)"
    else:
        vec_str = "未启用"
    print("  向量库: %s" % vec_str)
    ws = s.get("workspaceDir") or "-"
    print("  工作区: %s" % ws)
    db = s.get("dbPath") or "-"
    print("  索引库: %s" % db)
    scan = entry.get("scan", {})
    if isinstance(scan, dict):
        issues = scan.get("issues", [])
        if issues:
            for issue in issues[:3]:
                print("  ⚠️ %s" % issue)
PY
	}

	openclaw_memory_get_backend() {
		local backend
		backend=$(openclaw_memory_config_get "memory.backend")
		if [ "$backend" = "local" ]; then
			echo "builtin"
		else
			echo "$backend"
		fi
	}

	openclaw_memory_get_local_model_path() {
		openclaw_memory_config_get "agents.defaults.memorySearch.local.modelPath"
	}

	openclaw_memory_local_model_status() {
		local model_path="$1"
		if [ -z "$model_path" ]; then
			echo "missing"
			return
		fi
		if [[ "$model_path" == hf:* ]]; then
			echo "hf"
			return
		fi
		if [ -f "$model_path" ]; then
			echo "ok"
		else
			echo "missing"
		fi
	}

	openclaw_memory_qmd_available() {
		if command -v qmd >/dev/null 2>&1; then
			echo "true"
			return
		fi
		local backend
		backend=$(openclaw_memory_config_get "memory.backend")
		if [ "$backend" = "qmd" ]; then
			echo "true"
			return
		fi
		echo "false"
	}

	openclaw_memory_probe_url() {
		local url="$1"
		if ! command -v curl >/dev/null 2>&1; then
			echo "unknown"
			return
		fi
		if [ -z "$url" ]; then
			echo "unknown"
			return
		fi
		if curl -I -m 2 -s "$url" >/dev/null 2>&1; then
			echo "ok"
		else
			echo "fail"
		fi
	}

	openclaw_memory_recommend() {
		local qmd_ok model_path model_status hf_ok mirror_ok
		qmd_ok=$(openclaw_memory_qmd_available)
		model_path=$(openclaw_memory_get_local_model_path)
		model_status=$(openclaw_memory_local_model_status "$model_path")
		hf_ok=$(openclaw_memory_probe_url "https://huggingface.co")
		mirror_ok=$(openclaw_memory_probe_url "https://hf-mirror.com")

		OPENCLAW_MEMORY_RECOMMEND_REASON=()
		if [ "$qmd_ok" = "true" ]; then
			OPENCLAW_MEMORY_RECOMMEND_REASON+=("QMD 可用")
		else
			OPENCLAW_MEMORY_RECOMMEND_REASON+=("未检测到 QMD")
		fi
		if [ -n "$model_path" ]; then
			OPENCLAW_MEMORY_RECOMMEND_REASON+=("本地模型路径: $model_path")
		else
			OPENCLAW_MEMORY_RECOMMEND_REASON+=("未配置本地模型路径")
		fi
		case "$model_status" in
			ok) OPENCLAW_MEMORY_RECOMMEND_REASON+=("本地模型文件存在") ;;
			hf) OPENCLAW_MEMORY_RECOMMEND_REASON+=("模型来自 HF 下载源（国内可能慢/失败）") ;;
			*) OPENCLAW_MEMORY_RECOMMEND_REASON+=("本地模型文件不存在或不可用") ;;
		esac
		if [ "$hf_ok" = "ok" ]; then
			OPENCLAW_MEMORY_RECOMMEND_REASON+=("huggingface.co 可访问")
		elif [ "$mirror_ok" = "ok" ]; then
			OPENCLAW_MEMORY_RECOMMEND_REASON+=("hf-mirror.com 可访问")
		else
			OPENCLAW_MEMORY_RECOMMEND_REASON+=("huggingface.co / hf-mirror.com 可能不可达（疑似国内/受限网络）")
		fi

		if [ "$qmd_ok" = "true" ]; then
			if [ "$model_status" = "ok" ]; then
				OPENCLAW_MEMORY_RECOMMEND="local"
			elif [ "$model_status" = "hf" ] && { [ "$hf_ok" = "ok" ] || [ "$mirror_ok" = "ok" ]; }; then
				OPENCLAW_MEMORY_RECOMMEND="local"
			elif [ "$model_status" = "hf" ] && [ "$hf_ok" = "fail" ] && [ "$mirror_ok" = "fail" ]; then
				OPENCLAW_MEMORY_RECOMMEND="qmd"
			else
				OPENCLAW_MEMORY_RECOMMEND="qmd"
			fi
		else
			if [ "$model_status" = "ok" ]; then
				OPENCLAW_MEMORY_RECOMMEND="local"
			else
				OPENCLAW_MEMORY_RECOMMEND="qmd"
			fi
		fi
	}


	openclaw_memory_detect_region() {
		OPENCLAW_MEMORY_COUNTRY="unknown"
		OPENCLAW_MEMORY_USE_MIRROR="false"
		if command -v curl >/dev/null 2>&1; then
			OPENCLAW_MEMORY_COUNTRY=$(curl -s -m 2 ipinfo.io/country | tr -d '
' | tr -d '
')
		fi
		case "$OPENCLAW_MEMORY_COUNTRY" in
			CN|HK)
				OPENCLAW_MEMORY_USE_MIRROR="true"
				;;
		esac
	}

	openclaw_memory_select_sources() {
		local hf_ok mirror_ok
		hf_ok=$(openclaw_memory_probe_url "https://huggingface.co")
		mirror_ok=$(openclaw_memory_probe_url "https://hf-mirror.com")
		OPENCLAW_MEMORY_HF_OK="$hf_ok"
		OPENCLAW_MEMORY_MIRROR_OK="$mirror_ok"
		if [ "$OPENCLAW_MEMORY_USE_MIRROR" = "true" ]; then
			if [ "$mirror_ok" = "ok" ]; then
				OPENCLAW_MEMORY_HF_BASE="https://hf-mirror.com"
			elif [ "$hf_ok" = "ok" ]; then
				OPENCLAW_MEMORY_HF_BASE="https://huggingface.co"
			else
				OPENCLAW_MEMORY_HF_BASE="https://hf-mirror.com"
			fi
			OPENCLAW_MEMORY_GH_PROXY="https://gh-proxy.com/https://"
		else
			if [ "$hf_ok" = "ok" ]; then
				OPENCLAW_MEMORY_HF_BASE="https://huggingface.co"
			elif [ "$mirror_ok" = "ok" ]; then
				OPENCLAW_MEMORY_HF_BASE="https://hf-mirror.com"
			else
				OPENCLAW_MEMORY_HF_BASE="https://huggingface.co"
			fi
			OPENCLAW_MEMORY_GH_PROXY="https://"
		fi
	}

	openclaw_memory_download_file() {
		local url="$1"
		local dest="$2"
		mkdir -p "$(dirname "$dest")"
		if command -v curl >/dev/null 2>&1; then
			curl -L --fail --retry 2 -o "$dest" "$url"
			return $?
		fi
		if command -v wget >/dev/null 2>&1; then
			wget -O "$dest" "$url"
			return $?
		fi
		echo "❌ 未检测到 curl 或 wget，无法下载。"
		return 1
	}

	openclaw_memory_check_sqlite() {
		if ! command -v sqlite3 >/dev/null 2>&1; then
			echo "⚠️ 未检测到 sqlite3，QMD 可能无法正常运行。"
			return 1
		fi
		local ver
		ver=$(sqlite3 --version 2>/dev/null | awk '{print $1}')
		echo "✅ sqlite3 可用: ${ver:-unknown}"
		echo "ℹ️ sqlite 扩展支持无法可靠检测，将继续。"
		return 0
	}

	openclaw_memory_ensure_bun() {
		if [ -x "$HOME/.bun/bin/bun" ]; then
			export PATH="$HOME/.bun/bin:$PATH"
		fi
		if command -v bun >/dev/null 2>&1; then
			echo "✅ bun 已存在"
			return 0
		fi
		echo "⬇️ 安装 bun..."
		if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
			daimon_run_cached_script "https://bun.sh/install" "bun-install.sh"
		else
			echo "❌ 未检测到 curl 或 wget，无法安装 bun。"
			return 1
		fi
		if [ -d "$HOME/.bun/bin" ]; then
			export PATH="$HOME/.bun/bin:$PATH"
		fi
		if command -v bun >/dev/null 2>&1; then
			echo "✅ bun 安装完成"
			return 0
		fi
		echo "❌ bun 安装失败"
		return 1
	}

	openclaw_memory_ensure_qmd() {
		local qmd_path
		qmd_path=$(command -v qmd 2>/dev/null || true)
		if [ -n "$qmd_path" ]; then
			if qmd --version >/dev/null 2>&1; then
				echo "✅ qmd 已存在且可用: $qmd_path"
				OPENCLAW_MEMORY_QMD_PATH="$qmd_path"
				return 0
			else
				echo "⚠️ qmd 命令存在但模块损坏，重新安装..."
			fi
		fi
		echo "⬇️ 通过 npm 安装 qmd: @tobilu/qmd"
		npm install -g @tobilu/qmd
		qmd_path=$(command -v qmd 2>/dev/null || true)
		if [ -z "$qmd_path" ]; then
			echo "❌ qmd 安装失败"
			return 1
		fi
		if ! qmd --version >/dev/null 2>&1; then
			echo "❌ qmd 安装后仍无法运行"
			return 1
		fi
		OPENCLAW_MEMORY_QMD_PATH="$qmd_path"
		echo "✅ qmd 安装完成: $qmd_path"
		return 0
	}

	openclaw_memory_render_auto_summary() {
		echo "---------------------------------------"
		echo "✅ 环境就绪"
		echo "方案: ${OPENCLAW_MEMORY_AUTO_SCHEME:-unknown}"
		if [ "$OPENCLAW_MEMORY_CONFIG_ONLY" = "true" ]; then
			echo "模式: 仅写配置（未安装/未下载）"
		fi
		if [ "$OPENCLAW_MEMORY_PREHEAT" = "true" ]; then
			echo "索引: 已执行"
		else
			echo "索引: 已跳过"
		fi
		if [ "$OPENCLAW_MEMORY_RESTARTED" = "true" ]; then
			echo "重启: 已执行"
		else
			echo "重启: 已跳过"
		fi
		if [ -n "$OPENCLAW_MEMORY_QMD_PATH" ]; then
			echo "qmd: $OPENCLAW_MEMORY_QMD_PATH"
		fi
		if [ -n "$OPENCLAW_MEMORY_MODEL_PATH" ]; then
			echo "模型: $OPENCLAW_MEMORY_MODEL_PATH"
		fi
		if [ -n "$OPENCLAW_MEMORY_COUNTRY" ]; then
			echo "地区: $OPENCLAW_MEMORY_COUNTRY"
		fi
		if [ -n "$OPENCLAW_MEMORY_HF_BASE" ]; then
			echo "下载源: $OPENCLAW_MEMORY_HF_BASE"
		fi
		echo "最终状态:"
		openclaw_memory_render_status
		echo "---------------------------------------"
	}

	openclaw_memory_auto_confirm() {
		local scheme_label="$1"
		OPENCLAW_MEMORY_PREHEAT="true"
		OPENCLAW_MEMORY_RESTARTED="false"
		OPENCLAW_MEMORY_CONFIG_ONLY="false"
		echo "即将执行自动部署（详细模式）"
		echo "目标方案: $scheme_label"
		echo "地区: ${OPENCLAW_MEMORY_COUNTRY:-unknown}"
		echo "镜像源探测: huggingface.co=${OPENCLAW_MEMORY_HF_OK:-unknown} hf-mirror.com=${OPENCLAW_MEMORY_MIRROR_OK:-unknown}"
		echo "下载源: ${OPENCLAW_MEMORY_HF_BASE:-unknown}"
		if [ -n "$OPENCLAW_MEMORY_EXPECT_PATH" ]; then
			echo "预计下载路径: $OPENCLAW_MEMORY_EXPECT_PATH"
		fi
		if [ -n "$OPENCLAW_MEMORY_EXPECT_SIZE" ]; then
			echo "可能流量/磁盘占用: $OPENCLAW_MEMORY_EXPECT_SIZE"
		else
			echo "可能流量/磁盘占用: 视实际情况而定"
		fi
		echo "确认后将自动安装/下载、写入配置、构建索引并重启网关"
		echo "高级选项: 输入 config 仅写配置（不安装不下载、不索引、不重启）"
		read -e -p "输入 yes 确认继续（默认 N）: " confirm_step || return 1
		case "$confirm_step" in
			yes|YES)
				OPENCLAW_MEMORY_PREHEAT="true"
				;;
			config|CONFIG)
				OPENCLAW_MEMORY_CONFIG_ONLY="true"
				OPENCLAW_MEMORY_PREHEAT="false"
				;;
			*)
				echo "已取消自动部署。"
				return 1
				;;
		esac
		if [ "$OPENCLAW_MEMORY_CONFIG_ONLY" = "true" ]; then
			echo "⚠️ 已选择仅写配置，不安装不下载"
		else
			echo "✅ 将自动构建索引并重启网关"
		fi
		return 0
	}

	openclaw_memory_auto_setup_qmd() {
		echo "🔍 检测 QMD 环境"
		openclaw_memory_cleanup_legacy_keys
		openclaw_memory_check_sqlite || true
		if [ "$OPENCLAW_MEMORY_CONFIG_ONLY" = "true" ]; then
			if command -v qmd >/dev/null 2>&1; then
				OPENCLAW_MEMORY_QMD_PATH=$(command -v qmd)
			else
				OPENCLAW_MEMORY_QMD_PATH="qmd"
			fi
		else
			openclaw_memory_ensure_qmd || return 1
		fi
		local backend
		backend=$(openclaw_memory_get_backend)
		if [ "$backend" = "qmd" ]; then
			echo "✅ memory.backend 已是 qmd"
		else
			openclaw_memory_config_set "memory.backend" "qmd"
			echo "✅ 已设置 memory.backend=qmd"
		fi
		local qmd_cmd
		qmd_cmd=$(openclaw_memory_config_get "memory.qmd.command")
		if [ -z "$qmd_cmd" ] || [[ "$qmd_cmd" != /* ]] || [ "$qmd_cmd" != "$OPENCLAW_MEMORY_QMD_PATH" ]; then
			openclaw_memory_config_set "memory.qmd.command" "$OPENCLAW_MEMORY_QMD_PATH"
			echo "✅ 已写入 memory.qmd.command: $OPENCLAW_MEMORY_QMD_PATH"
		else
			echo "✅ memory.qmd.command 已正确"
		fi
		if [ "$OPENCLAW_MEMORY_PREHEAT" = "true" ]; then
			echo "🔥 预热索引（可能下载模型）"
			openclaw_memory_prepare_workspace_all
			local preh_agent_lines preh_agent_id preh_workspace
			preh_agent_lines=$(openclaw_memory_list_agents)
			while IFS=$'\t' read -r preh_agent_id preh_workspace; do
				[ -z "$preh_agent_id" ] && continue
				openclaw memory index --agent "$preh_agent_id" --force
			done <<EOF
$preh_agent_lines
EOF
		else
			echo "⏭️ 已跳过预热"
		fi
		echo "✅ QMD 自动部署完成"
	}

	openclaw_memory_auto_setup_local() {
		echo "🔍 检测 Local 环境"
		openclaw_memory_cleanup_legacy_keys
		local backend provider
		backend=$(openclaw_memory_get_backend)
		if [ "$backend" = "builtin" ] || [ "$backend" = "local" ]; then
			echo "✅ memory.backend 已是 builtin"
		else
			openclaw_memory_config_set "memory.backend" "builtin"
			echo "✅ 已设置 memory.backend=builtin"
		fi
		provider=$(openclaw_memory_config_get "agents.defaults.memorySearch.provider")
		if [ "$provider" = "local" ]; then
			echo "✅ memorySearch.provider 已是 local"
		else
			openclaw_memory_config_set "agents.defaults.memorySearch.provider" "local"
			echo "✅ 已设置 agents.defaults.memorySearch.provider=local"
		fi

		local model_path model_status
		model_path=$(openclaw_memory_get_local_model_path)
		model_path=$(openclaw_memory_expand_path "$model_path")
		model_status=$(openclaw_memory_local_model_status "$model_path")
		if [ "$model_status" = "ok" ]; then
			echo "✅ 模型文件已存在: $model_path"
			OPENCLAW_MEMORY_MODEL_PATH="$model_path"
		else
			local model_name="embeddinggemma-300M-Q8_0.gguf"
			local model_dir="$HOME/.openclaw/models/embedding"
			local model_dest="$model_dir/$model_name"
			local model_url="${OPENCLAW_MEMORY_HF_BASE}/ggml-org/embeddinggemma-300M-GGUF/resolve/main/$model_name"
			if [ "$OPENCLAW_MEMORY_CONFIG_ONLY" = "true" ]; then
				echo "ℹ️ 仅写配置模式：跳过模型下载"
				OPENCLAW_MEMORY_MODEL_PATH="$model_dest"
			else
				if [ -f "$model_dest" ]; then
					echo "✅ 已发现默认模型文件: $model_dest"
				else
					echo "⬇️ 下载模型: $model_url"
					openclaw_memory_download_file "$model_url" "$model_dest" || return 1
					echo "✅ 模型已下载: $model_dest"
				fi
				OPENCLAW_MEMORY_MODEL_PATH="$model_dest"
			fi
			openclaw_memory_config_set "agents.defaults.memorySearch.local.modelPath" "$model_dest"
			echo "✅ 已写入模型路径"
		fi
		if [ "$OPENCLAW_MEMORY_PREHEAT" = "true" ]; then
			echo "🔥 预热索引（可能下载模型）"
			openclaw_memory_prepare_workspace_all
			local preh_agent_lines preh_agent_id preh_workspace
			preh_agent_lines=$(openclaw_memory_list_agents)
			while IFS=$'\t' read -r preh_agent_id preh_workspace; do
				[ -z "$preh_agent_id" ] && continue
				openclaw memory index --agent "$preh_agent_id" --force
			done <<EOF
$preh_agent_lines
EOF
		else
			echo "⏭️ 已跳过预热"
		fi
		echo "✅ Local 自动部署完成"
	}

	openclaw_memory_auto_setup_run() {
		local scheme="$1"
		local scheme_label
		OPENCLAW_MEMORY_QMD_PATH=""
		OPENCLAW_MEMORY_MODEL_PATH=""
		OPENCLAW_MEMORY_EXPECT_PATH=""
		OPENCLAW_MEMORY_EXPECT_SIZE=""
		openclaw_memory_detect_region
		openclaw_memory_select_sources
		if [ "$scheme" = "auto" ]; then
			openclaw_memory_recommend
			scheme="$OPENCLAW_MEMORY_RECOMMEND"
		fi
		case "$scheme" in
			qmd)
				scheme_label="QMD"
				OPENCLAW_MEMORY_EXPECT_PATH="$HOME/.bun (qmd 安装目录)"
				OPENCLAW_MEMORY_EXPECT_SIZE="约 20-50MB"
				;;
			local)
				scheme_label="Local"
				OPENCLAW_MEMORY_EXPECT_PATH="$HOME/.openclaw/models/embedding/embeddinggemma-300M-Q8_0.gguf"
				OPENCLAW_MEMORY_EXPECT_SIZE="约 350-600MB"
				;;
			*)
				echo "❌ 未知方案: $scheme"
				return 1
				;;
		esac
		OPENCLAW_MEMORY_AUTO_SCHEME="$scheme_label"
		openclaw_memory_auto_confirm "$scheme_label" || return 0
		case "$scheme" in
			qmd) openclaw_memory_auto_setup_qmd || return 1 ;;
			local) openclaw_memory_auto_setup_local || return 1 ;;
			*) return 1 ;;
		esac
		if [ "$OPENCLAW_MEMORY_CONFIG_ONLY" = "true" ]; then
			OPENCLAW_MEMORY_RESTARTED="false"
			openclaw_memory_render_auto_summary
			return 0
		fi
		echo "♻️ 重启 OpenClaw 网关"
		if declare -F start_gateway >/dev/null 2>&1; then
			start_gateway
		else
			openclaw gateway restart
		fi
		OPENCLAW_MEMORY_RESTARTED="true"
		openclaw_memory_render_auto_summary
		return 0
	}

	openclaw_memory_auto_setup_menu() {
		while true; do
			clear
			echo "======================================="
			echo "记忆方案自动部署"
			echo "======================================="
			echo "1. QMD"
			echo "2. Local"
			echo "3. Auto（自动选择）"
			echo "0. 返回上一级"
			echo "---------------------------------------"
			read -e -p "请输入你的选择: " auto_choice || return 1
			case "$auto_choice" in
				1)
					openclaw_memory_auto_setup_run "qmd"
					break_end
					;;
				2)
					openclaw_memory_auto_setup_run "local"
					break_end
					;;
				3)
					openclaw_memory_auto_setup_run "auto"
					break_end
					;;
				0)
					return 0
					;;
				*)
					echo "无效的选择，请重试。"
					sleep 1
					;;
			esac
		done
	}

	openclaw_memory_apply_scheme() {
		local scheme="$1"
		openclaw_memory_cleanup_legacy_keys
		case "$scheme" in
			qmd)
				openclaw_memory_config_set "memory.backend" "qmd"
				if [ $? -ne 0 ]; then
					echo "❌ 写入配置失败"
					return 1
				fi
				openclaw_memory_config_set "memory.qmd.command" "qmd" >/dev/null 2>&1
				;;
			local)
				openclaw_memory_config_set "memory.backend" "builtin"
				if [ $? -ne 0 ]; then
					echo "❌ 写入配置失败"
					return 1
				fi
				openclaw_memory_config_set "agents.defaults.memorySearch.provider" "local" >/dev/null 2>&1
				;;
			*)
				echo "❌ 未知方案: $scheme"
				return 1
			esac
		echo "✅ 已更新记忆方案配置"
		return 0
	}

	openclaw_memory_offer_restart() {
		echo "配置已写入，需要重启 OpenClaw 网关后生效。"
		read -e -p "是否立即重启 OpenClaw 网关？(Y/n): " restart_choice || return 1
		if [[ "$restart_choice" =~ ^[Nn]$ ]]; then
			echo "已跳过重启，可稍后执行: openclaw gateway restart"
			return 0
		fi
		if declare -F start_gateway >/dev/null 2>&1; then
			start_gateway
		else
			openclaw gateway restart
		fi
	}

	openclaw_memory_fix_index() {
		local backend include_dm
		backend=$(openclaw_memory_get_backend)
		if [ "$backend" = "qmd" ] && ! command -v qmd >/dev/null 2>&1; then
			echo "⚠️ 检测到当前方案为 QMD，但未安装 qmd 命令。"
			echo "   可切换 Local，或安装 bun + qmd 后再试。"
		fi
		include_dm=$(openclaw config get memory.qmd.includeDefaultMemory 2>/dev/null)
		echo "======================================="
		echo "索引修复诊断"
		echo "======================================="
		echo "当前 includeDefaultMemory: ${include_dm:-未设置}"
		echo ""
		if [ "$include_dm" = "false" ]; then
			echo "⚠️ 检测到 includeDefaultMemory=false"
			echo "   这会导致默认记忆文件（MEMORY.md + memory/*.md）不被索引"
			echo "   所以 Indexed 会一直显示 0/N"
			echo ""
			read -e -p "是否恢复为 true 并重建索引？(Y/n): " fix_choice || return 1
			if [[ ! "$fix_choice" =~ ^[Nn]$ ]]; then
				openclaw_memory_config_set "memory.qmd.includeDefaultMemory" true
				if [ $? -ne 0 ]; then
					echo "❌ 写入配置失败"
					break_end
					return 1
				fi
				echo "✅ 已恢复 includeDefaultMemory=true"
				openclaw_memory_rebuild_index_all
			else
				echo "已取消。"
			fi
		else
			echo "includeDefaultMemory 配置正常。"
			echo "将执行：清理旧索引 → 全量重建所有智能体索引"
			echo ""
			read -e -p "确认执行？(Y/n): " confirm_fix || return 1
			if [[ ! "$confirm_fix" =~ ^[Nn]$ ]]; then
				openclaw_memory_rebuild_index_all
			else
				echo "已取消。"
			fi
		fi
		break_end
	}

	openclaw_memory_scheme_menu() {
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw 记忆方案"
			echo "======================================="
			local backend current_label
			backend=$(openclaw_memory_get_backend)
			case "$backend" in
				qmd) current_label="QMD" ;;
				builtin|local) current_label="Local" ;;
				*) current_label="未配置" ;;
			esac
			echo "当前方案: $current_label"
			echo ""
			echo "QMD  : 轻量索引，依赖 qmd 命令（适合网络受限）"
			echo "Local: 本地向量检索，依赖 embedding 模型文件"
			echo "Auto : 自动推荐（基于可用性 + 网络探测）"
			echo "---------------------------------------"
			echo "1. 切换 QMD（自动部署/已装则跳过）"
			echo "2. 切换 Local（自动部署/已装则跳过）"
			echo "3. Auto（自动推荐并自动部署）"
			echo "0. 返回上一级"
			echo "---------------------------------------"
			read -e -p "请输入你的选择: " scheme_choice || return 1
			case "$scheme_choice" in
				1)
					openclaw_memory_auto_setup_run "qmd"
					break_end
					;;
				2)
					openclaw_memory_auto_setup_run "local"
					break_end
					;;
				3)
					openclaw_memory_auto_setup_run "auto"
					break_end
					;;
				0)
					return 0
					;;
				*)
					echo "无效的选择，请重试。"
					sleep 1
					;;
			esac
		done
	}

	openclaw_memory_file_collect() {
		OPENCLAW_MEMORY_FILES=()
		OPENCLAW_MEMORY_FILE_LABELS=()
		local agent_lines agent_id base_dir memory_dir memory_file rel
		agent_lines=$(openclaw_memory_list_agents)
		while IFS=$'\t' read -r agent_id base_dir; do
			[ -z "$agent_id" ] && continue
			memory_dir="$base_dir/memory"
			memory_file="$base_dir/MEMORY.md"
			if [ -f "$memory_file" ]; then
				OPENCLAW_MEMORY_FILES+=("$memory_file")
				OPENCLAW_MEMORY_FILE_LABELS+=("$agent_id/MEMORY.md")
			fi
			if [ -d "$memory_dir" ]; then
				while IFS= read -r file; do
					[ -f "$file" ] || continue
					rel="${file#$base_dir/}"
					OPENCLAW_MEMORY_FILES+=("$file")
					OPENCLAW_MEMORY_FILE_LABELS+=("$agent_id/$rel")
				done < <(find "$memory_dir" -type f -name '*.md' | sort)
			fi
		done <<EOF
$agent_lines
EOF
	}

	openclaw_memory_file_render_list() {
		openclaw_memory_file_collect
		if [ ${#OPENCLAW_MEMORY_FILES[@]} -eq 0 ]; then
			echo "未找到记忆文件。"
			return 0
		fi
		echo "编号 | 归属 | 大小 | 修改时间"
		echo "---------------------------------------"
		local i file rel size mtime
		for i in "${!OPENCLAW_MEMORY_FILES[@]}"; do
			file="${OPENCLAW_MEMORY_FILES[$i]}"
			rel="${OPENCLAW_MEMORY_FILE_LABELS[$i]}"
			size=$(ls -lh "$file" | awk '{print $5}')
			mtime=$(date -d "$(stat -c %y "$file")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c %y "$file" | awk '{print $1" "$2}')
			printf "%s | %s | %s | %s\\n" "$((i+1))" "$rel" "$size" "$mtime"
		done
	}

	openclaw_memory_view_file() {
		local file="$1"
		[ -f "$file" ] || {
			echo "❌ 文件不存在: $file"
			return 1
		}
		local total_lines
		total_lines=$(wc -l < "$file" 2>/dev/null || echo 0)
		local default_lines=120
		local start_line count
		echo "文件: $file"
		echo "总行数: $total_lines"
		read -e -p "请输入起始行（回车默认末尾 $default_lines 行）: " start_line || return 1
		read -e -p "请输入显示行数（回车默认 $default_lines）: " count || return 1
		[ -z "$count" ] && count=$default_lines
		if [ -z "$start_line" ]; then
			if [ "$total_lines" -le "$count" ]; then
				start_line=1
			else
				start_line=$((total_lines - count + 1))
			fi
		fi
		if ! [[ "$start_line" =~ ^[0-9]+$ ]] || ! [[ "$count" =~ ^[0-9]+$ ]]; then
			echo "❌ 请输入有效的数字。"
			return 1
		fi
		if [ "$start_line" -lt 1 ]; then
			start_line=1
		fi
		if [ "$count" -le 0 ]; then
			echo "❌ 行数必须大于 0。"
			return 1
		fi
		local end_line=$((start_line + count - 1))
		if [ "$end_line" -gt "$total_lines" ]; then
			end_line=$total_lines
		fi
		if [ "$total_lines" -eq 0 ]; then
			echo "(空文件)"
			return 0
		fi
		echo "---------------------------------------"
		sed -n "${start_line},${end_line}p" "$file"
		echo "---------------------------------------"
	}

	openclaw_memory_files_menu() {
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw 记忆文件"
			echo "======================================="
			openclaw_memory_file_render_list
			echo "---------------------------------------"
			read -e -p "请输入文件编号查看（0 返回）: " file_choice || return 1
			if [ "$file_choice" = "0" ]; then
				return 0
			fi
			if ! [[ "$file_choice" =~ ^[0-9]+$ ]]; then
				echo "无效的选择，请重试。"
				sleep 1
				continue
			fi
			openclaw_memory_file_collect
			if [ ${#OPENCLAW_MEMORY_FILES[@]} -eq 0 ]; then
				read -p "未找到记忆文件，按回车返回..."
				return 0
			fi
			local idx=$((file_choice-1))
			if [ "$idx" -lt 0 ] || [ "$idx" -ge ${#OPENCLAW_MEMORY_FILES[@]} ]; then
				echo "无效的编号，请重试。"
				sleep 1
				continue
			fi
			openclaw_memory_view_file "${OPENCLAW_MEMORY_FILES[$idx]}"
			read -p "按回车返回列表..."
			done
	}


	openclaw_memory_search_test() {
		read -e -p "输入搜索关键词: " query || return 1
		if [ -z "$query" ]; then
			echo "关键词不能为空。"
			return 1
		fi
		echo "正在搜索记忆..."
		openclaw memory search "$query" --max-results 5
	}

	openclaw_memory_deep_status() {
		echo "正在探测嵌入模型就绪状态..."
		openclaw memory status --deep
	}

	openclaw_memory_menu() {
		send_stats "OpenClaw记忆管理"
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw 记忆管理"
			echo "======================================="
			openclaw_memory_render_status
			echo "1. 更新记忆索引"
			echo "2. 查看记忆文件"
			echo "3. 索引修复（Indexed 异常）"
			echo "4. 记忆方案（QMD/Local/Auto）"
			echo "5. 搜索测试（验证索引是否工作）"
			echo "6. 深度状态探测（检查嵌入模型）"
			echo "0. 返回上一级"
			echo "---------------------------------------"
			read -e -p "请输入你的选择: " memory_choice || return 1
			case "$memory_choice" in
				1)
					echo "即将更新记忆索引。"
					read -e -p "第一次确认：输入 yes 继续: " confirm_step1 || return 1
					if [ "$confirm_step1" != "yes" ]; then
						echo "已取消。"
						break_end
						continue
					fi
				openclaw_memory_prepare_workspace_all
				read -e -p "二次确认：输入 force 使用全量（留空为增量）: " confirm_step2 || return 1
				if [ "$confirm_step2" = "force" ]; then
					echo "⚠️ 全量重建更彻底，但耗时更长。"
					echo "推荐：输入 rebuild 进行安全重建（先备份索引库）。"
					read -e -p "第三次确认：输入 rebuild 执行安全重建；直接回车继续普通 force: " confirm_step3 || return 1
					if [ "$confirm_step3" = "rebuild" ]; then
						openclaw_memory_rebuild_index_all
					else
						local fl_agent_lines fl_agent_id fl_workspace
						fl_agent_lines=$(openclaw_memory_list_agents)
						while IFS=$'\t' read -r fl_agent_id fl_workspace; do
							[ -z "$fl_agent_id" ] && continue
							openclaw memory index --agent "$fl_agent_id" --force
						done <<EOF
$fl_agent_lines
EOF
						openclaw gateway restart
						echo "✅ 已对所有智能体执行 force 重建并自动重启网关"
					fi
				else
					openclaw memory index
				fi
				break_end
					;;
				2)
					openclaw_memory_files_menu
					;;
				3)
					openclaw_memory_fix_index
					;;
				4)
					openclaw_memory_scheme_menu
					;;
				5)
					openclaw_memory_search_test
					break_end
					;;
				6)
					openclaw_memory_deep_status
					break_end
					;;
				0)
					return 0
					;;
				*)
					echo "无效的选择，请重试。"
					sleep 1
					;;
			esac
		done
	}

	openclaw_permission_config_file() {
		echo "$(openclaw_get_config_file)"
	}

	openclaw_permission_backup_file() {
		local backup_root
		backup_root=$(openclaw_backup_root)
		echo "${backup_root}/openclaw-permission-last.json"
	}

	openclaw_permission_require_openclaw() {
		if ! openclaw_has_command openclaw; then
			echo "❌ 未检测到 openclaw 命令，请先安装或初始化 OpenClaw。"
			return 1
		fi
		return 0
	}

	openclaw_permission_backup_current() {
		local config_file backup_file
		config_file=$(openclaw_permission_config_file)
		backup_file=$(openclaw_permission_backup_file)
		if [ ! -s "$config_file" ]; then
			echo "⚠️ 未找到 OpenClaw 配置文件，跳过权限备份。"
			return 1
		fi
		mkdir -p "$(dirname "$backup_file")"
		cp -f "$config_file" "$backup_file" >/dev/null 2>&1 || {
			echo "⚠️ 权限备份失败：$backup_file"
			return 1
		}
		echo "✅ 已备份当前权限配置: $backup_file"
		return 0
	}

	openclaw_permission_restore_backup() {
		local config_file backup_file
		config_file=$(openclaw_permission_config_file)
		backup_file=$(openclaw_permission_backup_file)
		if [ ! -s "$backup_file" ]; then
			echo "❌ 未找到可恢复的权限备份文件。"
			return 1
		fi
		cp -f "$backup_file" "$config_file" >/dev/null 2>&1 || {
			echo "❌ 权限恢复失败：$backup_file"
			return 1
		}
		echo "✅ 已恢复切换前权限配置"
		openclaw_permission_restart_gateway || true
		return 0
	}

	openclaw_permission_restart_gateway() {
		if ! openclaw_has_command openclaw; then
			echo "❌ 未检测到 openclaw，无法重启 OpenClaw Gateway。"
			return 1
		fi
		echo "正在重启 OpenClaw Gateway..."
		openclaw gateway restart >/dev/null 2>&1 || {
			openclaw gateway stop >/dev/null 2>&1
			openclaw gateway start >/dev/null 2>&1
		}
	}

	openclaw_permission_get_value() {
		local path="$1"
		local config_file
		config_file=$(openclaw_permission_config_file)

		if openclaw_has_command openclaw; then
			local value
			value=$(openclaw config get "$path" 2>&1 | head -n 1)
			if [ -n "$value" ]; then
				if echo "$value" | grep -qi "config path not found"; then
					echo "(unset)"
					return 0
				fi
				if [ "$value" = "null" ]; then
					echo "(unset)"
				else
					if echo "$value" | grep -q '^".*"$'; then
						value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//')
					fi
					echo "$value"
				fi
				return 0
			fi
		fi

		[ -f "$config_file" ] || { echo "(unset)"; return 0; }

		if openclaw_has_command jq; then
			local jq_value
			jq_value=$(jq -r --arg p "$path" 'getpath($p|split(".")) // "(unset)"' "$config_file" 2>/dev/null) || jq_value="(unset)"
			[ "$jq_value" = "null" ] && jq_value="(unset)"
			echo "$jq_value"
			return 0
		fi

		if openclaw_has_command python3; then
			python3 - "$config_file" "$path" <<'PY'
import json, sys
path = sys.argv[2]
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    obj = json.load(f)
cur = obj
for part in path.split('.'):
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        print('(unset)')
        raise SystemExit(0)
if isinstance(cur, bool):
    print('true' if cur else 'false')
elif cur is None:
    print('(unset)')
else:
    print(json.dumps(cur, ensure_ascii=False) if isinstance(cur, (dict, list)) else str(cur))
PY
			return 0
		fi

		echo "(unset)"
		return 0
	}

	openclaw_permission_unset_optional() {
		local key="$1"
		local probe
		if ! openclaw_has_command openclaw; then
			return 1
		fi
		if openclaw config unset "$key" >/dev/null 2>&1; then
			return 0
		fi
		probe=$(openclaw config get "$key" 2>&1 | head -n 1)
		if [ -z "$probe" ] || [ "$probe" = "null" ] || [ "$probe" = "(unset)" ] || echo "$probe" | grep -qi "config path not found"; then
			return 0
		fi
		return 1
	}

	openclaw_permission_detect_mode() {
		local config_file
		config_file=$(openclaw_permission_config_file)
		[ ! -f "$config_file" ] && { echo "未知模式"; return; }

		python3 - "$config_file" <<'PY'
import json, sys

def get_v(o, p):
    for k in p.split('.'):
        if isinstance(o, dict) and k in o:
            o = o[k]
        else:
            return "(unset)"
    return str(o).lower()

try:
    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        d = json.load(f)
    p = get_v(d, "tools.profile")
    s = get_v(d, "tools.exec.security")
    a = get_v(d, "tools.exec.ask")
    e = get_v(d, "tools.elevated.enabled")
    b = get_v(d, "commands.bash")
    ap = get_v(d, "tools.exec.applyPatch.enabled")
    w = get_v(d, "tools.exec.applyPatch.workspaceOnly")

    if p == "coding" and s == "allowlist" and a == "on-miss" and e == "false" and b == "false" and ap == "false":
        print("标准安全模式")
    elif p == "coding" and s == "allowlist" and a == "on-miss" and e == "true" and b == "true" and ap == "true" and w == "true":
        print("开发增强模式")
    elif (p == "full" or p == "(unset)") and s == "full" and a == "off" and e == "true" and b == "true" and ap == "true":
        print("完全开放模式")
    else:
        print("自定义模式")
except Exception:
    print("自定义模式")
PY
	}

		openclaw_permission_update_exec_approvals() {
		local sec="$1"
		local ask="$2"
		local fallback="$3"
		local approvals_file="$HOME/.openclaw/exec-approvals.json"

		mkdir -p "$HOME/.openclaw"

		# 生成 JSON 并通过 openclaw approvals set --stdin 写入（优先）
		# 若 CLI 不支持则回退直接写文件
		local json_payload
		json_payload=$(python3 -c '
import json, sys, os
path = sys.argv[1]
try:
    if os.path.exists(path):
        with open(path, "r") as f:
            data = json.load(f)
    else:
        data = {"version": 1, "defaults": {}}
except Exception:
    data = {"version": 1, "defaults": {}}
if "defaults" not in data:
    data["defaults"] = {}
data["defaults"]["security"] = sys.argv[2]
data["defaults"]["ask"] = sys.argv[3]
data["defaults"]["askFallback"] = sys.argv[4]
data["defaults"]["autoAllowSkills"] = True
print(json.dumps(data, indent=2))
' "$approvals_file" "$sec" "$ask" "$fallback")

		if openclaw_has_command openclaw && echo "$json_payload" | openclaw approvals set --stdin >/dev/null 2>&1; then
			return 0
		fi
		# 回退：直接写文件
		echo "$json_payload" > "$approvals_file"
	}

	openclaw_permission_render_status() {
		echo "应用层配置: ~/.openclaw/openclaw.json"
		echo "宿主机审批: ~/.openclaw/exec-approvals.json"
		echo "---------------------------------------"
		local current_profile current_sec current_ask current_elevated
		current_profile=$(openclaw config get tools.profile 2>/dev/null | head -n 1 | sed 's/^"//;s/"$//')
		current_sec=$(openclaw config get tools.exec.security 2>/dev/null | head -n 1 | sed 's/^"//;s/"$//')
		current_ask=$(openclaw config get tools.exec.ask 2>/dev/null | head -n 1 | sed 's/^"//;s/"$//')
		current_elevated=$(openclaw config get tools.elevated.enabled 2>/dev/null | head -n 1 | sed 's/^"//;s/"$//')
		# 清理空值
		[ -z "$current_profile" ] || echo "$current_profile" | grep -qi "config path not found" && current_profile=""
		[ -z "$current_sec" ] || echo "$current_sec" | grep -qi "config path not found" && current_sec=""
		[ -z "$current_ask" ] || echo "$current_ask" | grep -qi "config path not found" && current_ask=""
		[ -z "$current_elevated" ] || echo "$current_elevated" | grep -qi "config path not found" && current_elevated=""

		local current_mode="未知 / 自定义"
		if [ "$current_profile" = "full" ] && [ "$current_sec" = "full" ] && [ "$current_ask" = "off" ]; then
			current_mode="\033[1;31m完全开放模式\033[0m"
		elif [ "$current_profile" = "coding" ] && [ "$current_sec" = "allowlist" ] && [ "$current_ask" = "on-miss" ] && [ "$current_elevated" = "true" ]; then
			current_mode="\033[1;33m开发增强模式\033[0m"
		elif [ "$current_profile" = "coding" ] && [ "$current_sec" = "allowlist" ] && [ "$current_ask" = "on-miss" ] && [ "$current_elevated" != "true" ]; then
			current_mode="\033[1;32m标准安全模式\033[0m"
		elif [ -z "$current_profile" ] && [ -z "$current_sec" ]; then
			current_mode="\033[1;36m官方沙盒兜底\033[0m"
		fi
		echo -e "  当前综合安全等级: ${current_mode}"
		echo "---------------------------------------"
		echo -e "${gl_huang}[应用层 Tool Policy 状态]${gl_bai}"
		echo "  Profile (预设): ${current_profile:-(unset)}"
		echo "  Exec 限制: ${current_sec:-(unset)}"
		echo "  审批提示: ${current_ask:-(unset)}"
		echo "  提权开关: ${current_elevated:-(unset)}"

		echo -e "\n${gl_huang}[底层 Exec Approvals 状态]${gl_bai}"
		if openclaw_has_command openclaw; then
			local approvals_json
			approvals_json=$(openclaw approvals get --json 2>/dev/null)
			if [ -n "$approvals_json" ]; then
				python3 -c '
import json, sys
try:
    d = json.loads(sys.argv[1])
    defaults = d.get("file", {}).get("defaults", {})
    if not defaults:
        defaults = d.get("defaults", {})
    sec = defaults.get("security", "(unset)")
    ask = defaults.get("ask", "(unset)")
    fb = defaults.get("askFallback", "(unset)")
    auto = defaults.get("autoAllowSkills", False)
    print("  拦截策略 (Security): " + str(sec))
    print("  提示策略 (Ask): " + str(ask))
    print("  无UI兜底 (AskFallback): " + str(fb))
    print("  自动放行技能 (autoAllowSkills): " + ("on" if auto else "off"))
    exists = d.get("exists", True)
    if not exists:
        print("  (审批文件不存在，使用系统内置安全兜底)")
except Exception as e:
    print("  (解析失败: " + str(e) + ")")
' "$approvals_json"
			else
				echo "  (openclaw approvals get --json 无输出)"
			fi
		elif [ -f "$HOME/.openclaw/exec-approvals.json" ]; then
			python3 -c '
import json, os
path = os.path.expanduser("~/.openclaw/exec-approvals.json")
try:
    with open(path) as f:
        d = json.load(f).get("defaults", {})
    print("  拦截策略 (Security): " + str(d.get("security", "(unset)")))
    print("  提示策略 (Ask): " + str(d.get("ask", "(unset)")))
    print("  无UI兜底 (AskFallback): " + str(d.get("askFallback", "(unset)")))
except Exception:
    print("  (配置文件解析失败)")
'
		else
			echo "  (未配置，强制使用系统内置安全兜底策略)"
		fi
	}

	openclaw_permission_apply_standard() {
		send_stats "OpenClaw权限-标准安全模式"
		openclaw_permission_require_openclaw || return 1

		echo "正在配置应用层策略..."
		openclaw config set tools.profile coding >/dev/null 2>&1
		openclaw config set tools.exec.security allowlist >/dev/null 2>&1
		openclaw config set tools.exec.ask on-miss >/dev/null 2>&1
		openclaw config set tools.elevated.enabled false >/dev/null 2>&1
		openclaw config set tools.exec.strictInlineEval true >/dev/null 2>&1  # 拦截危险的内联代码
		openclaw config unset commands.bash >/dev/null 2>&1 # 废弃旧版参数

		echo "正在配置宿主机审批拦截..."
		openclaw_permission_update_exec_approvals "allowlist" "on-miss" "deny"

		openclaw_permission_restart_gateway
		echo -e "${gl_lv}✅ 已切换为标准安全模式 (所有危险命令将通过UI/TG请求你的审批)${gl_bai}"
	}

	openclaw_permission_apply_developer() {
		send_stats "OpenClaw权限-开发增强模式"
		openclaw_permission_require_openclaw || return 1

		echo "正在配置应用层策略..."
		openclaw config set tools.profile coding >/dev/null 2>&1
		openclaw config set tools.exec.security allowlist >/dev/null 2>&1
		openclaw config set tools.exec.ask on-miss >/dev/null 2>&1
		openclaw config set tools.elevated.enabled true >/dev/null 2>&1 # 允许智能体申请提权
		openclaw config set tools.exec.strictInlineEval false >/dev/null 2>&1

		echo "正在配置宿主机审批拦截..."
		openclaw_permission_update_exec_approvals "allowlist" "on-miss" "deny"

		openclaw_permission_restart_gateway
		echo -e "${gl_lv}✅ 已切换为开发增强模式 (允许提权，但常规危险命令依然需要审批)${gl_bai}"
	}

	openclaw_permission_apply_full() {
		send_stats "OpenClaw权限-完全开放模式"
		openclaw_permission_require_openclaw || return 1

		echo "正在配置应用层策略..."
		openclaw config set tools.profile full >/dev/null 2>&1
		openclaw config set tools.exec.security full >/dev/null 2>&1
		openclaw config set tools.exec.ask off >/dev/null 2>&1
		openclaw config set tools.elevated.enabled true >/dev/null 2>&1
		openclaw config set tools.exec.strictInlineEval false >/dev/null 2>&1

		echo "正在瓦解宿主机拦截防御..."
		# 这里的 full 和 off 将彻底绕过底层宿主机的 exec 审批系统
		openclaw_permission_update_exec_approvals "full" "off" "full"

		openclaw_permission_restart_gateway
		echo -e "${gl_lv}✅ 已切换为完全开放模式 (警告：所有宿主机命令拦截已失效，智能体具有最高权限)${gl_bai}"
	}

	openclaw_permission_restore_official_defaults() {
		send_stats "OpenClaw权限-恢复官方默认"
		openclaw_permission_require_openclaw || return 1

		echo "清理应用层强制覆盖..."
		openclaw config unset tools.profile >/dev/null 2>&1
		openclaw config unset tools.exec.security >/dev/null 2>&1
		openclaw config unset tools.exec.ask >/dev/null 2>&1
		openclaw config unset tools.elevated.enabled >/dev/null 2>&1
		openclaw config unset tools.exec.strictInlineEval >/dev/null 2>&1

		echo "清理宿主机拦截配置..."
		# 优先通过 CLI 清空审批配置，回退直接删文件
		if echo '{"version":1,"defaults":{}}' | openclaw approvals set --stdin >/dev/null 2>&1; then
			true
		else
			rm -f "$HOME/.openclaw/exec-approvals.json"
		fi

		openclaw_permission_restart_gateway
		echo -e "${gl_lv}✅ 已恢复到 OpenClaw 官方安全沙盒防御机制${gl_bai}"
	}

	openclaw_permission_run_audit() {
		echo "======================================="
		echo "运行 OpenClaw 官方安全审计与体检..."
		echo "======================================="
		openclaw security audit
		echo "---------------------------------------"
		read -e -p "是否尝试自动修复发现的安全隐患？(y/n): " fix_choice || return 1
		if [[ "$fix_choice" == "y" || "$fix_choice" == "Y" || "$fix_choice" == "yes" ]]; then
			openclaw security audit --fix
			echo -e "${gl_lv}✅ 自动修复完成。${gl_bai}"
		fi
		echo "按任意键返回..."
		read -n 1 -s
	}


	openclaw_permission_manage_allowlist() {
		while true; do
			clear
			echo "======================================="
			echo " Exec 命令白名单管理"
			echo "======================================="
			echo "当前白名单："
			local allowlist_json
			allowlist_json=$(openclaw approvals get --json 2>/dev/null)
			if [ -n "$allowlist_json" ]; then
				python3 -c '
import json, sys
try:
    d = json.loads(sys.argv[1])
    f = d.get("file", {})
    agents = f.get("agents", {})
    found = False
    for agent_id, agent_data in agents.items():
        al = agent_data.get("allowlist", [])
        if al:
            found = True
            print("  智能体 [%s]:" % agent_id)
            for item in al:
                print("    - %s" % item)
    if not found:
        print("  (空，未配置任何白名单规则)")
except Exception as e:
    print("  (解析失败: " + str(e) + ")")
' "$allowlist_json"
			else
				echo "  (无法获取)"
			fi
			echo "---------------------------------------"
			echo "1. 添加白名单规则"
			echo "2. 移除白名单规则"
			echo "0. 返回"
			echo "---------------------------------------"
			read -e -p "请选择: " al_choice || return 1
			case "$al_choice" in
				1)
					read -e -p "输入要放行的命令路径 (支持 glob，如 /usr/bin/git): " pattern || return 1
					[ -z "$pattern" ] && { echo "不能为空"; break_end; continue; }
					read -e -p "指定智能体ID (留空=所有智能体 *): " agent_id || return 1
					agent_id="${agent_id:-*}"
					openclaw approvals allowlist add --agent "$agent_id" "$pattern"
					break_end
					;;
				2)
					read -e -p "输入要移除的命令路径: " pattern || return 1
					[ -z "$pattern" ] && { echo "不能为空"; break_end; continue; }
					openclaw approvals allowlist remove "$pattern"
					break_end
					;;
				0) return 0 ;;
				*) echo "无效选择"; sleep 1 ;;
			esac
		done
	}

	openclaw_permission_menu() {
		send_stats "OpenClaw权限管理"
		while true; do
			clear
			echo "======================================="
			echo " OpenClaw 权限管理 (双层架构深度适配)"
			echo "======================================="
			openclaw_permission_render_status
			echo "---------------------------------------"
			echo -e "${gl_kjlan}1.${gl_bai} 切换为标准安全模式（日常推荐，弹卡片审批）"
			echo -e "${gl_kjlan}2.${gl_bai} 切换为开发增强模式（允许智能体申请提权）"
			echo -e "${gl_kjlan}3.${gl_bai} 切换为完全开放模式（${gl_hong}高风险！彻底解除所有宿主机拦截${gl_bai}）"
			echo -e "${gl_kjlan}4.${gl_bai} 恢复官方默认沙盒防御策略"
			echo -e "${gl_kjlan}5.${gl_bai} 运行底层安全审计与自动修复"
			echo -e "${gl_kjlan}6.${gl_bai} 管理 Exec 命令白名单"
			echo -e "${gl_kjlan}0.${gl_bai} 返回上一级"
			echo "---------------------------------------"
			read -e -p "请输入你的选择: " perm_choice || return 1
			case "$perm_choice" in
				1)
					echo "准备应用：标准安全模式"
					read -e -p "输入 yes 确认: " confirm || return 1
					if [ "$confirm" = "yes" ]; then openclaw_permission_apply_standard; else echo "已取消"; fi
					break_end
					;;
				2)
					echo "准备应用：开发增强模式"
					read -e -p "输入 yes 确认: " confirm || return 1
					if [ "$confirm" = "yes" ]; then openclaw_permission_apply_developer; else echo "已取消"; fi
					break_end
					;;
				3)
					echo -e "${gl_hong}⚠️ 完全开放模式会彻底瓦解 exec 审批并自动放行高危代码。${gl_bai}"
					read -e -p "输入 FULL 确认继续: " confirm || return 1
					if [ "$confirm" = "FULL" ]; then openclaw_permission_apply_full; else echo "已取消"; fi
					break_end
					;;
				4)
					echo "将清除所有定制覆盖，恢复 OpenClaw 刚安装时的严格沙盒状态。"
					read -e -p "输入 yes 确认: " confirm || return 1
					if [ "$confirm" = "yes" ]; then openclaw_permission_restore_official_defaults; else echo "已取消"; fi
					break_end
					;;
				5)
					openclaw_permission_run_audit
					;;
				6)
					openclaw_permission_manage_allowlist
					;;
				0)
					return 0
					;;
				*)
					echo "无效的选择，请重试。"
					sleep 1
					;;
			esac
		done
	}

	openclaw_multiagent_config_file() {
		local config_file
		config_file=$(openclaw_permission_config_file)
		if [ -s "$config_file" ]; then
			echo "$config_file"
			return 0
		fi
		openclaw config file 2>/dev/null | tail -n 1
	}

	openclaw_multiagent_default_agent() {
		local config_file
		config_file=$(openclaw_permission_config_file)
		if [ -s "$config_file" ]; then
			python3 - "$config_file" <<'PY'
import json,sys,os
path=sys.argv[1]
value="(unset)"
try:
    with open(path) as f:
        data=json.load(f)
    defaults=data.get("agents",{}).get("defaults",{}) if isinstance(data,dict) else {}
    value=defaults.get("agent") or None
    if not value:
        for item in data.get("agents",{}).get("list",[]) or []:
            if isinstance(item,dict) and (item.get("isDefault") or item.get("default")):
                value=item.get("id")
                break
    if not value:
        for item in data.get("agents",{}).get("list",[]) or []:
            if isinstance(item,dict) and item.get("id"):
                value=item.get("id")
                break
except Exception:
    value="(unset)"
print(value or "(unset)")
PY
			return 0
		fi
		local value
		value=$(openclaw config get agents.defaults.agent 2>&1 | head -n 1)
		if [ -z "$value" ] || echo "$value" | grep -qi "config path not found"; then
			value=$(openclaw agents list --json 2>/dev/null | python3 -c 'import json,sys
try:
 data=json.load(sys.stdin)
 print(next((x.get("id","(unset)") for x in data if x.get("isDefault")), "(unset)"))
except Exception:
 print("(unset)")' 2>/dev/null)
		fi
		[ -z "$value" ] && value="(unset)"
		if echo "$value" | grep -q '^".*"$'; then
			value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//')
		fi
		echo "$value"
	}

	openclaw_multiagent_require_openclaw() {
		if ! openclaw_has_command openclaw; then
			echo "❌ 未检测到 openclaw 命令，请先安装或初始化 OpenClaw。"
			return 1
		fi
		return 0
	}

	openclaw_multiagent_agents_json() {
		local result
		if openclaw_has_command openclaw; then
			result=$(openclaw agents list --json 2>/dev/null)
			if [ -n "$result" ] && python3 -c "import json,sys; json.loads(sys.argv[1])" "$result" 2>/dev/null; then
				echo "$result"
				return 0
			fi
		fi
		# 回退：从配置文件读取
		local config_file
		config_file=$(openclaw_permission_config_file)
		if [ -s "$config_file" ]; then
			python3 - "$config_file" <<'PY'
import json,sys,os
path=sys.argv[1]
try:
    with open(path) as f:
        data=json.load(f)
    agents=data.get("agents",{}).get("list",[])
    if not isinstance(agents,list):
        agents=[]
    print(json.dumps(agents, ensure_ascii=False))
except Exception:
    print("[]")
PY
			return 0
		fi
		echo '[]'
	}

	openclaw_multiagent_bindings_json() {
		local result
		if openclaw_has_command openclaw; then
			result=$(openclaw agents bindings --json 2>/dev/null)
			if [ -n "$result" ] && python3 -c "import json,sys; json.loads(sys.argv[1])" "$result" 2>/dev/null; then
				echo "$result"
				return 0
			fi
		fi
		# 回退：从配置文件读取
		local config_file
		config_file=$(openclaw_permission_config_file)
		if [ -s "$config_file" ]; then
			python3 - "$config_file" <<'PY'
import json,sys
path=sys.argv[1]
try:
    with open(path) as f:
        data=json.load(f)
    bindings=data.get("agents",{}).get("bindings",[])
    if not isinstance(bindings,list):
        bindings=[]
    results=[]
    for item in bindings:
        if not isinstance(item,dict):
            continue
        results.append({"agentId": item.get("agentId") or item.get("agent") or "?", "description": item.get("description") or "-"})
    print(json.dumps(results, ensure_ascii=False))
except Exception:
    print("[]")
PY
			return 0
		fi
		echo '[]'
	}

	openclaw_multiagent_sessions_json() {
		local result
		if openclaw_has_command openclaw; then
			result=$(openclaw sessions --json 2>/dev/null | grep -v '^\[')
			if [ -n "$result" ] && python3 -c "import json,sys; json.loads(sys.argv[1])" "$result" 2>/dev/null; then
				echo "$result"
				return 0
			fi
		fi
		# 回退：从文件系统读取
		python3 <<'PY'
import json,os
base=os.path.expanduser("~/.openclaw/agents")
sessions=[]
try:
    agent_dirs=[d for d in os.listdir(base) if os.path.isdir(os.path.join(base,d))]
except Exception:
    agent_dirs=[]
for agent_id in agent_dirs:
    path=os.path.join(base,agent_id,"sessions","sessions.json")
    if not os.path.exists(path):
        continue
    try:
        with open(path) as f:
            data=json.load(f)
    except Exception:
        continue
    if isinstance(data,dict):
        items=data.items()
    elif isinstance(data,list):
        items=[(item.get("key") or "?", item) for item in data if isinstance(item,dict)]
    else:
        continue
    for key,item in items:
        if not isinstance(item,dict):
            continue
        model=item.get("model") or "-"
        sessions.append({"agentId": agent_id, "key": key, "model": model})
print(json.dumps({"path":"(filesystem)","count":len(sessions),"sessions":sessions}, ensure_ascii=False))
PY
	}

	openclaw_multiagent_render_status() {
		local config_file default_agent
		config_file=$(openclaw_multiagent_config_file)
		default_agent=$(openclaw_multiagent_default_agent)
		echo "配置文件: ${config_file:-$(openclaw_permission_config_file)}"
		echo "默认智能体: $default_agent"
		python3 -c '
import json,sys
agents=json.loads(sys.argv[1] or "[]")
bindings=json.loads(sys.argv[2] or "[]")
sess_obj=json.loads(sys.argv[3] or "{}")
sessions=sess_obj.get("sessions",[]) if isinstance(sess_obj,dict) else []
print("已配置智能体数: %s" % len(agents))
print("路由绑定数: %s" % len(bindings))
print("会话总数: %s" % len(sessions))
print("---------------------------------------")
if not agents:
    print("当前未配置任何多智能体。")
else:
    for item in agents[:8]:
        aid = item.get("id","?")
        identity = item.get("identityName") or item.get("name") or "-"
        emoji = item.get("identityEmoji") or ""
        ws = item.get("workspace") or "-"
        model = item.get("model") or "-"
        is_default = item.get("isDefault", False)
        bcount = item.get("bindings", 0)
        default_tag = " [默认]" if is_default else ""
        print("- 智能体ID: \033[1;36m%s\033[0m%s" % (aid, default_tag))
        print("  身份名称: %s %s" % (identity, emoji))
        print("  模型: %s" % model)
        print("  工作目录: %s" % ws)
        print("  绑定数: %s" % bcount)
' "$(openclaw_multiagent_agents_json)" "$(openclaw_multiagent_bindings_json)" "$(openclaw_multiagent_sessions_json)"
	}

	openclaw_multiagent_list_agents() {
		send_stats "OpenClaw多智能体-列出Agent"
		python3 -c 'import json,sys; agents=json.loads(sys.argv[1] or "[]");
if not agents: print("暂无已配置 Agent。"); raise SystemExit(0)
for idx,item in enumerate(agents,1):
 print("%s. %s" % (idx, item.get("id","?"))); print("   workspace : %s" % item.get("workspace","-")); ident=(item.get("identityName") or "-") + ((" " + item.get("identityEmoji")) if item.get("identityEmoji") else ""); print("   identity  : %s" % ident.strip()); print("   model     : %s" % (item.get("model") or "-")); print("   bindings  : %s" % item.get("bindings",0)); print("   default   : %s" % ("yes" if item.get("isDefault") else "no"))' "$(openclaw_multiagent_agents_json)"
	}

	openclaw_multiagent_add_agent() {
		send_stats "OpenClaw多智能体-新增Agent"
		openclaw_multiagent_require_openclaw || return 1
		local agent_id workspace confirm
		read -e -p "请输入新的 Agent ID: " agent_id || return 1
		[ -z "$agent_id" ] && echo "已取消：Agent ID 不能为空。" && return 1
		read -e -p "请输入 workspace 路径（默认 ~/.openclaw/workspace-${agent_id}）: " workspace || return 1
		[ -z "$workspace" ] && workspace="~/.openclaw/workspace-${agent_id}"
		echo "将创建智能体: $agent_id"
		echo "工作目录: $workspace"
		read -e -p "输入 yes 确认继续: " confirm || return 1
		[ "$confirm" = "yes" ] || { echo "已取消"; return 1; }
		if openclaw agents add "$agent_id" --workspace "$workspace"; then
			echo "✅ 智能体创建成功: $agent_id"
			local name theme
			read -e -p "请输入智能体身份名称 (如: 代码专家): " name || return 1
			[ -z "$name" ] && name="$agent_id"
			read -e -p "请输入智能体性格主题 (如: 严谨、高效): " theme || return 1
			[ -z "$theme" ] && theme="助手"
			echo "正在配置智能体身份..."
			openclaw agents set-identity --agent "$agent_id" --name "$name" --theme "$theme"
		else
			echo "❌ 智能体创建失败"
			return 1
		fi
	}

	openclaw_multiagent_delete_agent() {
		send_stats "OpenClaw多智能体-删除Agent"
		openclaw_multiagent_require_openclaw || return 1
		local agent_id confirm
		read -e -p "请输入要删除的 Agent ID: " agent_id || return 1
		[ -z "$agent_id" ] && echo "已取消：Agent ID 不能为空。" && return 1
		echo "⚠️ 删除智能体可能影响其工作目录、路由绑定与会话路由。"
		read -e -p "输入 DELETE 确认删除 ${agent_id}: " confirm || return 1
		[ "$confirm" = "DELETE" ] || { echo "已取消"; return 1; }
		if openclaw agents delete "$agent_id"; then
			echo "✅ 智能体删除成功: $agent_id"
		else
			echo "❌ 智能体删除失败"
			return 1
		fi
	}

	openclaw_multiagent_list_bindings() {
		send_stats "OpenClaw多智能体-查看路由绑定"
		python3 -c '
import json,sys
bindings=json.loads(sys.argv[1] or "[]")
if not bindings:
    print("暂无路由绑定。")
    raise SystemExit(0)
for idx,item in enumerate(bindings,1):
    desc = item.get("description") or "-"
    print("%s. agent=%s | %s" % (idx, item.get("agentId","?"), desc))
' "$(openclaw_multiagent_bindings_json)"
	}

	openclaw_multiagent_add_binding() {
		send_stats "OpenClaw多智能体-新增路由绑定"
		openclaw_multiagent_require_openclaw || return 1
		local agent_id bind_value confirm
		read -e -p "请输入智能体 ID: " agent_id || return 1
		read -e -p "请输入路由绑定值（如 telegram:ops / discord:guild-a）: " bind_value || return 1
		{ [ -z "$agent_id" ] || [ -z "$bind_value" ]; } && echo "已取消：参数不能为空。" && return 1
		echo "将绑定智能体 [$agent_id] -> [$bind_value]"
		read -e -p "输入 yes 确认继续: " confirm || return 1
		[ "$confirm" = "yes" ] || { echo "已取消"; return 1; }
		if openclaw agents bind --agent "$agent_id" --bind "$bind_value"; then
			echo "✅ 路由绑定添加成功"
		else
			echo "❌ 路由绑定添加失败"
			return 1
		fi
	}

	openclaw_multiagent_remove_binding() {
		send_stats "OpenClaw多智能体-移除路由绑定"
		openclaw_multiagent_require_openclaw || return 1
		local agent_id bind_value confirm
		read -e -p "请输入智能体 ID: " agent_id || return 1
		read -e -p "请输入要移除的路由绑定值: " bind_value || return 1
		{ [ -z "$agent_id" ] || [ -z "$bind_value" ]; } && echo "已取消：参数不能为空。" && return 1
		echo "将移除智能体 [$agent_id] 的路由绑定 [$bind_value]"
		read -e -p "输入 yes 确认继续: " confirm || return 1
		[ "$confirm" = "yes" ] || { echo "已取消"; return 1; }
		if openclaw agents unbind --agent "$agent_id" --bind "$bind_value"; then
			echo "✅ 路由绑定移除成功"
		else
			echo "❌ 路由绑定移除失败"
			return 1
		fi
	}


	openclaw_multiagent_show_sessions() {
		send_stats "OpenClaw多智能体-会话概况"
		python3 -c '
import json,sys
sess_obj=json.loads(sys.argv[1] or "{}")
sessions=sess_obj.get("sessions",[]) if isinstance(sess_obj,dict) else []
if not sessions:
    print("暂无 session 数据。")
    raise SystemExit(0)
by_agent={}
for item in sessions:
    aid = item.get("agentId","?")
    by_agent[aid] = by_agent.get(aid, 0) + 1
print("会话汇总:")
for agent_id,count in sorted(by_agent.items()):
    print("- %s: %s" % (agent_id, count))
print("---------------------------------------")
for item in sessions[:10]:
    key = item.get("key","-")
    model = item.get("model") or "-"
    aid = item.get("agentId","?")
    tokens = ""
    it = item.get("inputTokens")
    ot = item.get("outputTokens")
    if it is not None:
        tokens = " | in=%s out=%s" % (it, ot or 0)
    print("%s | %s | %s%s" % (aid, key, model, tokens))
' "$(openclaw_multiagent_sessions_json)"
	}

	openclaw_multiagent_health_check() {
		send_stats "OpenClaw多智能体-健康检查"
		openclaw_multiagent_require_openclaw || return 1
		local config_file
		config_file=$(openclaw_multiagent_config_file)
		echo "检查配置文件: ${config_file:-$(openclaw_permission_config_file)}"
		openclaw config validate || echo "⚠️ 配置校验未通过，请检查上方输出。"
		python3 -c '
import json,sys,os
agents=json.loads(sys.argv[1] or "[]")
bindings=json.loads(sys.argv[2] or "[]")
print("---------------------------------------")
if not agents:
    print("⚠️ 未发现已配置智能体。")
else:
    for item in agents:
        ws = item.get("workspace") or ""
        aid = item.get("id","?")
        if ws and os.path.isdir(os.path.expanduser(ws)):
            state = "OK"
        elif aid == "main":
            state = "OK"
        else:
            state = "MISSING"
        model = item.get("model") or "-"
        bcount = item.get("bindings", 0)
        print("agent=%s workspace=%s model=%s bindings=%s [%s]" % (aid, ws or "-", model, bcount, state))
print("路由绑定数=%s" % len(bindings))
print("✅ 多智能体健康检查完成")
' "$(openclaw_multiagent_agents_json)" "$(openclaw_multiagent_bindings_json)"
		echo ""
		echo "运行安全审计..."
		openclaw security audit 2>/dev/null || echo "⚠️ 安全审计命令不可用"
	}


	openclaw_multiagent_set_identity() {
		openclaw_multiagent_require_openclaw || return 1
		openclaw_multiagent_list_agents
		read -e -p "输入要修改身份的智能体ID: " agent_id || return 1
		[ -z "$agent_id" ] && { echo "ID 不能为空"; return 1; }
		echo "修改选项（留空跳过）："
		read -e -p "  新名称: " new_name || return 1
		read -e -p "  新 Emoji: " new_emoji || return 1
		local cmd="openclaw agents set-identity --agent $agent_id"
		[ -n "$new_name" ] && cmd="$cmd --name $new_name"
		[ -n "$new_emoji" ] && cmd="$cmd --emoji $new_emoji"
		echo "也可以从 IDENTITY.md 自动读取身份信息。"
		read -e -p "是否从 IDENTITY.md 读取？(y/n): " from_id || return 1
		if [ "$from_id" = "y" ]; then
			cmd="openclaw agents set-identity --agent $agent_id --from-identity"
		fi
		eval "$cmd"
	}

	openclaw_multiagent_cleanup_sessions() {
		openclaw_multiagent_require_openclaw || return 1
		echo "即将清理过期/冗余会话数据..."
		read -e -p "输入 yes 确认: " confirm || return 1
		[ "$confirm" != "yes" ] && { echo "已取消"; return 0; }
		openclaw sessions cleanup
	}

	openclaw_multiagent_menu() {
		send_stats "OpenClaw多智能体管理"
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw 多智能体管理"
			echo "======================================="
			openclaw_multiagent_render_status
			echo "---------------------------------------"
			echo "1. 新增智能体"
			echo "2. 删除智能体"
			echo "3. 查看路由绑定"
			echo "4. 新增路由绑定"
			echo "5. 移除路由绑定"
			echo "6. 查看会话概况"
			echo "7. 运行多智能体健康检查"
			echo "8. 修改智能体身份（名称/Emoji）"
			echo "9. 清理过期会话"
			echo "0. 返回上一级"
			echo "---------------------------------------"
			read -e -p "请输入你的选择: " multi_choice || return 1
			case "$multi_choice" in
				1) openclaw_multiagent_add_agent; break_end ;;
				2) openclaw_multiagent_delete_agent; break_end ;;
				3) openclaw_multiagent_list_bindings; break_end ;;
				4) openclaw_multiagent_add_binding; break_end ;;
				5) openclaw_multiagent_remove_binding; break_end ;;
				6) openclaw_multiagent_show_sessions; break_end ;;
				7) openclaw_multiagent_health_check; break_end ;;
				8) openclaw_multiagent_set_identity; break_end ;;
				9) openclaw_multiagent_cleanup_sessions; break_end ;;
				0) return 0 ;;
				*) echo "无效的选择，请重试。"; sleep 1 ;;
			esac
		done
	}


openclaw_backup_restore_menu() {

		send_stats "OpenClaw备份与还原"
		while true; do
			clear
			echo "======================================="
			echo "OpenClaw 备份与还原"
			echo "======================================="
			openclaw_backup_render_file_list
			echo "---------------------------------------"
			echo "1. 备份记忆全量"
			echo "2. 还原记忆全量"
			echo "3. 备份 OpenClaw 项目（默认安全模式）"
			echo "4. 还原 OpenClaw 项目（高级/高风险）"
			echo "5. 删除备份文件"
			echo "0. 返回上一级"
			echo "---------------------------------------"
			read -e -p "请输入你的选择: " backup_choice || return 1

			case "$backup_choice" in
				1) openclaw_memory_backup_export ;;
				2) openclaw_memory_backup_import ;;
				3) openclaw_project_backup_export ;;
				4) openclaw_project_backup_import ;;
				5) openclaw_backup_delete_file ;;
				0) return 0 ;;
				*)
					echo "无效的选择，请重试。"
					sleep 1
					;;
			esac
		done
	}


	update_moltbot() {
		echo "更新 OpenClaw..."
		send_stats "更新 OpenClaw..."
		install_node_and_tools
		git config --global url."${gh_proxy}github.com/".insteadOf ssh://git@github.com/
		git config --global url."${gh_proxy}github.com/".insteadOf git@github.com:
		npm install -g openclaw@latest
		crontab -l 2>/dev/null | grep -v "s gateway" | crontab -
		start_gateway
		hash -r
		add_app_id
		echo "更新完成"
		break_end
	}


	uninstall_moltbot() {
		echo "卸载 OpenClaw..."
		send_stats "卸载 OpenClaw..."
		openclaw uninstall
		npm uninstall -g openclaw
		crontab -l 2>/dev/null | grep -v "s gateway" | crontab -
		rm -rf "$HOME/.openclaw"
		[ "$HOME" != "/root" ] && [ -d /root/.openclaw ] && echo "⚠️ 检测到 root 目录下仍存在 /root/.openclaw，如需清理请手动处理"
		hash -r
		sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
		echo "卸载完成"
		break_end
	}

	vim_openclaw_json() {
		send_stats "编辑 OpenClaw 配置文件"
		install vim
		vim "$(openclaw_get_config_file)"
		start_gateway
	}






	openclaw_find_webui_domain() {
		local conf domain_list

		domain_list=$(
			grep -R "18789" /home/web/conf.d/*.conf 2>/dev/null \
			| awk -F: '{print $1}' \
			| sort -u \
			| while read conf; do
				basename "$conf" .conf
			done
		)

		if [ -n "$domain_list" ]; then
			echo "$domain_list"
		fi
	}



	openclaw_show_webui_addr() {
		local local_ip token domains

		echo "=================================="
		echo "OpenClaw WebUI 访问地址"
		local_ip="127.0.0.1"

		token=$(
			openclaw dashboard 2>/dev/null \
			| sed -n 's/.*:18789\/#token=\([a-f0-9]\+\).*/\1/p' \
			| head -n 1
		)
		echo
		echo "本机地址："
		echo "http://${local_ip}:18789/#token=${token}"

		domains=$(openclaw_find_webui_domain)
		if [ -n "$domains" ]; then
			echo "域名地址："
			echo "$domains" | while read d; do
				echo "https://${d}/#token=${token}"
			done
		fi

		echo "=================================="
	}



	# 添加域名（调用你给的函数）
	openclaw_domain_webui() {
		add_yuming
		validate_domain_name "$yuming" || { echo "域名格式不正确"; return 1; }
		ldnmp_Proxy "$yuming" 127.0.0.1 18789

		token=$(
			openclaw dashboard 2>/dev/null \
			| sed -n 's/.*:18789\/#token=\([a-f0-9]\+\).*/\1/p' \
			| head -n 1
		)

		clear
		echo "访问地址:"
		echo "https://${yuming}/#token=$token"
		echo "先访问URL触发设备ID，然后回车下一步进行配对。"
		read
		echo -e "${gl_kjlan}正在加载设备列表……${gl_bai}"
		# 自动添加域名到 allowedOrigins
		config_file=$(openclaw_get_config_file)
		if [ -f "$config_file" ]; then
			new_origin="https://${yuming}"
			# 使用 jq 安全修改 JSON，确保结构存在且不重复添加域名
			if command -v jq >/dev/null 2>&1; then
				tmp_json=$(mktemp)
				jq 'if .gateway.controlUi == null then .gateway.controlUi = {"allowedOrigins": ["http://127.0.0.1"]} else . end | if (.gateway.controlUi.allowedOrigins | contains([$origin]) | not) then .gateway.controlUi.allowedOrigins += [$origin] else . end' --arg origin "$new_origin" "$config_file" > "$tmp_json" && mv "$tmp_json" "$config_file"
				echo -e "${gl_kjlan}已将域名 ${yuming} 加入 allowedOrigins 配置${gl_bai}"
				openclaw gateway restart >/dev/null 2>&1
			fi
		fi

		openclaw devices list

		read -e -p "请输入 Request_Key: " Request_Key || return 1

		[ -z "$Request_Key" ] && {
			echo "Request_Key 不能为空"
			return 1
		}

		openclaw devices approve "$Request_Key"

	}

	# 删除域名
	openclaw_remove_domain() {
		echo "域名格式 example.com 不带https://"
		web_del
	}

	# 主菜单
	openclaw_webui_menu() {

		send_stats "WebUI访问与设置"
		while true; do
			clear
			openclaw_show_webui_addr
			echo
			echo "1. 添加域名访问"
			echo "2. 删除域名访问"
			echo "0. 退出"
			echo
			read -e -p "请选择: " choice || return 1

			case "$choice" in
				1)
					openclaw_domain_webui
					echo
					read -p "按回车返回菜单..."
					;;
				2)
					openclaw_remove_domain
					read -p "按回车返回菜单..."
					;;
				0)
					break
					;;
				*)
					echo "无效选项"
					sleep 1
					;;
			esac
		done
	}



	# 主循环
	while true; do
		show_menu
		read choice || return 1
		case $choice in
			1) install_moltbot ;;
			2) start_bot ;;
			3) stop_bot ;;
			4) view_logs ;;
			5) change_model ;;
			6) openclaw_api_manage_menu ;;
			7) change_tg_bot_code ;;
			8) install_plugin ;;
			9) install_skill ;;
			10) vim_openclaw_json ;;
			11) send_stats "初始化配置向导"
				openclaw onboard --install-daemon
				break_end
				;;
			12) send_stats "健康检测与修复"
				openclaw doctor --fix
				break_end
				;;
			13) openclaw_webui_menu ;;
			14) send_stats "TUI命令行对话"
				openclaw tui
				break_end
			 	;;
			15) openclaw_memory_menu ;;
			16) openclaw_permission_menu ;;
			17) openclaw_multiagent_menu ;;
			18) openclaw_backup_restore_menu ;;
			19) update_moltbot ;;
			20) uninstall_moltbot ;;
			*) break ;;
		esac
	done

}






ssh_current_ports() {
	local ports
	ports=$({
		ss -tlnp 2>/dev/null | awk '/sshd/ {n=split($4,a,":"); print a[n]}'
		sshd -T 2>/dev/null | awk '$1=="port" {print $2}'
		[ -n "${SSH_CONNECTION:-}" ] && printf '%s\n' "$SSH_CONNECTION" | awk '{print $4}'
	} | awk '/^[0-9]+$/ && $1 >= 1 && $1 <= 65535 {print $1}' | sort -nu)
	[ -n "$ports" ] || { echo "无法识别 SSH 端口，未启用防火墙。" >&2; return 1; }
	printf '%s\n' "$ports"
}

ufw_allow_current_ssh() {
	local ports port
	command -v ufw >/dev/null 2>&1 || return 1
	ports=$(ssh_current_ports) || return 1
	for port in $ports "$@"; do
		validate_tcp_port "$port" && ufw allow "$port/tcp" || {
			echo "SSH 端口放行失败，未启用防火墙。" >&2
			return 1
		}
	done
}

ssh_private_key_name_valid() {
	validate_config_name "$1" || return 1
	case "$1" in authorized_keys|known_hosts|known_hosts.old|config|*.pub) return 1 ;; esac
}

ssh_config_manager() {
	local SSH_CONFIG="/etc/ssh/sshd_config"
	local DEFAULT_SSH_PORT="64400"

	ssh_config_backup() {
		[ -f "$SSH_CONFIG" ] && cp "$SSH_CONFIG" "$SSH_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
	}
	ssh_restore_backup() {
		local backup
		backup=$(ls -1t "$SSH_CONFIG".bak.* 2>/dev/null | head -n1)
		[ -n "$backup" ] && cp "$backup" "$SSH_CONFIG"
	}

	ssh_set_option() {
		local key="$1" value="$2"
		if grep -qiE "^[#[:space:]]*${key}[[:space:]]+" "$SSH_CONFIG" 2>/dev/null; then
			sed -i "s|^[#[:space:]]*${key}[[:space:]].*|${key} ${value}|I" "$SSH_CONFIG"
		else
			echo "${key} ${value}" >> "$SSH_CONFIG"
		fi
	}

	ssh_restart_safe() {
		if ! sshd -t; then
			echo -e "${gl_hong}SSH 配置语法错误，未重启 SSH。请检查 $SSH_CONFIG${gl_bai}"
			return 1
		fi
		command systemctl stop ssh.socket sshd.socket 2>/dev/null || true
		command systemctl disable ssh.socket sshd.socket 2>/dev/null || true
		if command systemctl list-unit-files 2>/dev/null | grep -q '^sshd\.service'; then
			systemctl restart sshd
		elif command systemctl list-unit-files 2>/dev/null | grep -q '^ssh\.service'; then
			systemctl restart ssh
		else
			service sshd restart 2>/dev/null || service ssh restart 2>/dev/null
		fi
	}

	ssh_auth_status() {
		local key="$1"
		sshd -T 2>/dev/null | awk -v k="$key" '$1==k{print $2; found=1} END{if(!found) print "unknown"}'
	}

	ssh_add_public_key() {
		local public_key="$1"
		if [ -z "$public_key" ]; then
			echo "未提供公钥，已取消"
			return 1
		fi
		if ! printf '%s\n' "$public_key" | ssh-keygen -lf /dev/stdin >/dev/null 2>&1; then
			echo -e "${gl_hong}公钥格式或内容无效，未写入 authorized_keys。${gl_bai}"
			return 1
		fi
		mkdir -p /root/.ssh
		chmod 700 /root/.ssh
		touch /root/.ssh/authorized_keys
		if grep -qxF "$public_key" /root/.ssh/authorized_keys 2>/dev/null; then
			echo "公钥已存在，跳过添加"
		else
			echo "$public_key" >> /root/.ssh/authorized_keys
			echo "公钥已添加"
		fi
		chmod 600 /root/.ssh/authorized_keys
	}

	ssh_key_manager() {
		mkdir -p /root/.ssh
		chmod 700 /root/.ssh
		touch /root/.ssh/authorized_keys
		chmod 600 /root/.ssh/authorized_keys
		while true; do
			clear
			echo "SSH 公钥和私钥管理"
			echo "------------------------"
			echo "当前公钥:"
			nl -ba /root/.ssh/authorized_keys 2>/dev/null || true
			echo "------------------------"
			echo "当前私钥:"
			find /root/.ssh -maxdepth 1 -type f ! -name '*.pub' ! -name 'authorized_keys' ! -name 'known_hosts' ! -name 'config' -printf '%f\n' 2>/dev/null | nl -ba || true
			echo "------------------------"
			echo -e "${gl_kjlan}1.   ${gl_bai}添加公钥"
			echo -e "${gl_kjlan}2.   ${gl_bai}删除公钥"
			echo -e "${gl_kjlan}3.   ${gl_bai}添加私钥"
			echo -e "${gl_kjlan}4.   ${gl_bai}删除私钥"
			echo -e "${gl_kjlan}0.   ${gl_bai}返回上一级菜单"
			read -e -p "请输入你的选择: " sub_choice || return 1
			case "$sub_choice" in
				1) read -e -p "请粘贴公钥: " public_key || return 1; ssh_add_public_key "$public_key" ;;
				2) read -e -p "请输入要删除的公钥行号: " line_no || return 1; [[ "$line_no" =~ ^[0-9]+$ ]] && sed -i "${line_no}d" /root/.ssh/authorized_keys ;;
				3)
					read -e -p "请输入私钥文件名（默认 id_ed25519）: " key_name || return 0
					key_name=${key_name:-id_ed25519}
					if ! ssh_private_key_name_valid "$key_name" || [ -e "/root/.ssh/$key_name" ] || [ -L "/root/.ssh/$key_name" ]; then
						echo "文件名无效或文件已存在，未覆盖任何文件。"
					else
						echo "请粘贴私钥内容，结束后按 Ctrl+D:"
						(umask 077; set -o noclobber; cat > "/root/.ssh/$key_name")
					fi
					;;
				4)
					read -e -p "请输入要删除的私钥文件名: " key_name || return 0
					if ssh_private_key_name_valid "$key_name" && [ -f "/root/.ssh/$key_name" ] && [ ! -L "/root/.ssh/$key_name" ]; then
						rm -f -- "/root/.ssh/$key_name"
					else
						echo "文件名无效或不是私钥文件，未删除。"
					fi
					;;
				0) return ;;
				*) echo "无效的输入!" ;;
			esac
			break_end
		done
	}

	while true; do
		clear
		root_use
		echo "SSH 配置"
		echo "------------------------"
		echo -e "当前 SSH 端口: ${gl_huang}$(ssh_current_ports)${gl_bai}"
		echo -e "密码登录 PasswordAuthentication: ${gl_huang}$(ssh_auth_status passwordauthentication)${gl_bai}"
		echo -e "密钥登录 PubkeyAuthentication: ${gl_huang}$(ssh_auth_status pubkeyauthentication)${gl_bai}"
		echo "------------------------"
		echo -e "${gl_kjlan}1.   ${gl_bai}修改 SSH 端口"
		echo -e "${gl_kjlan}2.   ${gl_bai}禁用/开启密码登录"
		echo -e "${gl_kjlan}3.   ${gl_bai}开启/禁用密钥登录"
		echo -e "${gl_kjlan}4.   ${gl_bai}一键配置（关闭密码登录、关闭 22、改用 $DEFAULT_SSH_PORT、开启密钥登录、配置 UFW）"
		echo -e "${gl_kjlan}5.   ${gl_bai}公钥和私钥管理"
		echo -e "${gl_kjlan}6.   ${gl_bai}修改 sshd_config 配置文件"
		echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
		read -e -p "请输入你的选择: " sub_choice || return 1
		case "$sub_choice" in
			1)
				read -e -p "请输入新 SSH 端口（默认 $DEFAULT_SSH_PORT）: " new_port || return 1
				new_port=${new_port:-$DEFAULT_SSH_PORT}
				if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
					ssh_config_backup
					if command -v ufw >/dev/null 2>&1 && ! ufw_allow_current_ssh "$new_port"; then
						break_end; continue
					fi
					ssh_set_option Port "$new_port"
					if ! ssh_restart_safe; then
						ssh_restore_backup && ssh_restart_safe
						echo "新 SSH 配置未能生效，已尝试恢复原配置。"
					fi
				else
					echo "端口不合法"
				fi
				;;
			2)
				echo "1. 禁用密码登录    2. 开启密码登录"
				read -e -p "请选择: " mode || return 1
				ssh_config_backup
				if [ "$mode" = "1" ]; then
					ssh_set_option PasswordAuthentication no
					ssh_set_option KbdInteractiveAuthentication no
					ssh_set_option ChallengeResponseAuthentication no
					ssh_set_option PermitEmptyPasswords no
				elif [ "$mode" = "2" ]; then
					ssh_set_option PasswordAuthentication yes
					ssh_set_option KbdInteractiveAuthentication yes
					ssh_set_option ChallengeResponseAuthentication yes
				fi
				ssh_restart_safe
				;;
			3)
				echo "1. 开启密钥登录    2. 禁用密钥登录"
				read -e -p "请选择: " mode || return 1
				ssh_config_backup
				if [ "$mode" = "1" ]; then
					read -e -p "请粘贴公钥（可直接回车跳过）: " public_key || return 1
					ssh_add_public_key "$public_key"
					ssh_set_option PubkeyAuthentication yes
					ssh_set_option AuthorizedKeysFile ".ssh/authorized_keys"
				elif [ "$mode" = "2" ]; then
					ssh_set_option PubkeyAuthentication no
				fi
				ssh_restart_safe
				;;
			4)
				read -e -p "请粘贴公钥: " public_key || return 1
				ssh_add_public_key "$public_key" || { break_end; continue; }
				read -e -p "请输入 SSH 端口（默认 $DEFAULT_SSH_PORT）: " new_port || return 1
				new_port=${new_port:-$DEFAULT_SSH_PORT}
				if ! validate_tcp_port "$new_port"; then echo "端口不合法"; break_end; continue; fi
				ssh_config_backup
				ssh_set_option Port "$new_port"
				ssh_set_option PubkeyAuthentication yes
				ssh_set_option AuthorizedKeysFile ".ssh/authorized_keys"
				ssh_set_option PasswordAuthentication no
				ssh_set_option KbdInteractiveAuthentication no
				ssh_set_option ChallengeResponseAuthentication no
				ssh_set_option PermitEmptyPasswords no
				ssh_set_option PermitRootLogin prohibit-password
				if ! install ufw || ! ufw_allow_current_ssh "$new_port"; then
					ssh_restore_backup
					break_end; continue
				fi
				if ssh_restart_safe && ufw --force enable; then
					[ "$new_port" = "22" ] || ufw deny 22/tcp
					ufw status
				else
					ssh_restore_backup && ssh_restart_safe
					echo "SSH 或 UFW 应用失败，已尝试恢复原 SSH 配置。"
				fi
				;;
			5) ssh_key_manager; continue ;;
			6) install vim; vim "$SSH_CONFIG"; ssh_restart_safe ;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}

ufw_manager() {
	while true; do
		clear
		echo "UFW 防火墙管理"
		echo "------------------------"
		if command -v ufw >/dev/null 2>&1; then
			ufw status | head -n 12
		else
			echo -e "当前状态: ${gl_huang}未安装${gl_bai}"
		fi
		echo "------------------------"
		echo -e "${gl_kjlan}1.   ${gl_bai}安装 UFW（apt install -y ufw，并启用）"
		echo -e "${gl_kjlan}2.   ${gl_bai}卸载 UFW（禁用后 apt purge -y ufw）"
		echo -e "${gl_kjlan}3.   ${gl_bai}开放端口（例如 80 或 80/tcp，对应 ufw allow）"
		echo -e "${gl_kjlan}4.   ${gl_bai}删除端口规则（例如 80 或 80/tcp，对应 ufw delete allow）"
		echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
		read -e -p "请输入你的选择: " sub_choice || return 1
		case "$sub_choice" in
			1)
				root_use
				if install ufw && ufw_allow_current_ssh; then
					ufw --force enable && ufw status
				fi
				;;
			2) root_use; ufw disable 2>/dev/null || true; remove ufw; rm -rf /etc/ufw /var/lib/ufw ;;
			3) root_use; read -e -p "请输入要开放的端口/协议: " port_rule || return 1; [ -n "$port_rule" ] && ufw allow "$port_rule"; ufw status numbered ;;
			4) root_use; read -e -p "请输入要删除的端口/协议: " port_rule || return 1; [ -n "$port_rule" ] && ufw delete allow "$port_rule"; ufw status numbered ;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}

fail2ban_manager() {
	local F2B_JAIL="/etc/fail2ban/jail.local"

	fail2ban_detect_ssh_ports() {
		local ports=""
		if command -v ss >/dev/null 2>&1; then
			ports=$(ss -tlnp 2>/dev/null | awk '/sshd/ {print $4}' | sed -E 's/.*:([0-9]+)$/\1/' | grep -E '^[0-9]+$' | sort -n -u | paste -sd, -)
		fi
		if [ -z "$ports" ]; then
			ports=$(sshd -T 2>/dev/null | awk '$1=="port"{print $2}' | sort -n -u | paste -sd, - 2>/dev/null)
		fi
		if [ -z "$ports" ] && [ -f /etc/ssh/sshd_config ]; then
			ports=$(grep -Ei '^[[:space:]]*Port[[:space:]]+[0-9]+' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | sort -n -u | paste -sd, -)
		fi
		echo "${ports:-22}"
	}

	fail2ban_auth_logpath() {
		if [ -f /var/log/auth.log ]; then
			echo "/var/log/auth.log"
		elif [ -f /var/log/secure ]; then
			echo "/var/log/secure"
		else
			echo "%(sshd_log)s"
		fi
	}

	fail2ban_service() {
		local action="$1"
		if [ -x /bin/systemctl ]; then
			case "$action" in
				status) /bin/systemctl --no-pager --full status fail2ban ;;
				*) /bin/systemctl "$action" fail2ban ;;
			esac
		else
			service fail2ban "$action"
		fi
	}

	fail2ban_current_sshd_port() {
		[ -f "$F2B_JAIL" ] || return 0
		awk '
			/^[[:space:]]*\[sshd\][[:space:]]*$/ {in_sshd=1; next}
			/^[[:space:]]*\[[^]]+\][[:space:]]*$/ {in_sshd=0}
			in_sshd && /^[[:space:]]*port[[:space:]]*=/ {
				sub(/^[^=]*=/, "", $0)
				gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
				print
				exit
			}
		' "$F2B_JAIL"
	}

	fail2ban_write_sshd_jail() {
		local ports="$1"
		local logpath
		local tmp
		logpath=$(fail2ban_auth_logpath)

		mkdir -p /etc/fail2ban
		if [ ! -f "$F2B_JAIL" ]; then
			cp /etc/fail2ban/jail.conf "$F2B_JAIL" 2>/dev/null || touch "$F2B_JAIL"
		fi
		cp "$F2B_JAIL" "$F2B_JAIL.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

		tmp=$(mktemp)
		awk -v port="$ports" -v logpath="$logpath" '
			function print_sshd_block() {
				print "[sshd]"
				print "enabled = true"
				print "port = " port
				print "filter = sshd"
				print "logpath = " logpath
				print "maxretry = 5"
				print "bantime = 3600"
				print "findtime = 600"
			}
			BEGIN {in_sshd=0; printed=0}
			/^[[:space:]]*\[sshd\][[:space:]]*$/ {
				if (!printed) {
					print_sshd_block()
					printed=1
				}
				in_sshd=1
				next
			}
			/^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
				if (in_sshd) in_sshd=0
				print
				next
			}
			{
				if (!in_sshd) print
			}
			END {
				if (!printed) {
					print ""
					print_sshd_block()
				}
			}
		' "$F2B_JAIL" > "$tmp" && mv "$tmp" "$F2B_JAIL"

		echo "已写入 Fail2ban sshd 配置:"
		echo "  配置文件: $F2B_JAIL"
		echo "  SSH 端口: $ports"
		echo "  日志路径: $logpath"
	}

	fail2ban_reload_checked() {
		if command -v fail2ban-client >/dev/null 2>&1; then
			if ! fail2ban-client -t; then
				echo -e "${gl_hong}Fail2ban 配置检查失败，未重启服务。${gl_bai}"
				return 1
			fi
		fi
		fail2ban_service enable 2>/dev/null || true
		fail2ban_service restart 2>/dev/null || fail2ban_service start 2>/dev/null || true
		sleep 1
		fail2ban-client status sshd 2>/dev/null || fail2ban-client status 2>/dev/null || fail2ban_service status
	}

	fail2ban_install_sshd() {
		root_use
		if command -v apt-get >/dev/null 2>&1; then
			apt-get update -y
			apt-get install -y fail2ban
		else
			install fail2ban
		fi
		fail2ban_service start 2>/dev/null || true
		fail2ban_service enable 2>/dev/null || true
		fail2ban_write_sshd_jail "$(fail2ban_detect_ssh_ports)"
		fail2ban_reload_checked
	}

	fail2ban_uninstall_all() {
		root_use
		fail2ban_service stop 2>/dev/null || true
		fail2ban_service disable 2>/dev/null || true
		remove fail2ban
		rm -rf /etc/fail2ban /var/lib/fail2ban /var/log/fail2ban.log
		echo "Fail2ban 已卸载，相关配置和状态目录已删除。"
	}

	fail2ban_check_sshd_jail() {
		root_use
		if ! command -v fail2ban-client >/dev/null 2>&1; then
			echo "未检测到 fail2ban-client，请先选择 1 安装 Fail2ban。"
			return 1
		fi
		local detected_ports
		local configured_ports
		detected_ports=$(fail2ban_detect_ssh_ports)
		configured_ports=$(fail2ban_current_sshd_port)
		echo "当前 SSH 实际端口: $detected_ports"
		echo "Fail2ban sshd 当前端口: ${configured_ports:-未配置}"
		if [ "$configured_ports" != "$detected_ports" ]; then
			echo "端口不一致，正在自动修正 Fail2ban sshd 配置..."
			fail2ban_write_sshd_jail "$detected_ports"
		else
			echo "端口一致，无需修改。"
		fi
		fail2ban_reload_checked
	}

	while true; do
		clear
		echo "Fail2ban 管理"
		echo "------------------------"
		echo -e "当前 SSH 端口: ${gl_huang}$(fail2ban_detect_ssh_ports)${gl_bai}"
		if command -v fail2ban-client >/dev/null 2>&1; then
			fail2ban-client status sshd 2>/dev/null || fail2ban-client status 2>/dev/null || echo "Fail2ban 已安装但服务未运行"
		else
			echo -e "当前状态: ${gl_huang}未安装${gl_bai}"
		fi
		echo "------------------------"
		echo -e "${gl_kjlan}1.   ${gl_bai}安装 Fail2ban（自动配置 sshd，端口按当前 SSH 检测）"
		echo -e "${gl_kjlan}2.   ${gl_bai}卸载 Fail2ban（停止服务并删除配置/状态目录）"
		echo -e "${gl_kjlan}3.   ${gl_bai}检查 sshd 配置（端口不对自动修正）"
		echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
		read -e -p "请输入你的选择: " sub_choice || return 1
		case "$sub_choice" in
			1) fail2ban_install_sshd ;;
			2) fail2ban_uninstall_all ;;
			3) fail2ban_check_sshd_jail ;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}

ssl_nginx_manager() {
	mkdir -p "$DAIMON_SCRIPT_DIR"
	cat > "$DAIMON_SCRIPT_DIR/cert_nginx.sh" <<'DAIMON_CERT_NGINX_SCRIPT'
#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

validate_domain() { [[ "$1" =~ ^([A-Za-z0-9-]+\.)+[A-Za-z]{2,63}$ ]]; }
validate_port() { [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; }
validate_name() { [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] && [ "$1" != "." ] && [ "$1" != ".." ]; }

ACME="$HOME/.acme.sh/acme.sh"
NGINX_WAS_RUNNING=false
ACME_WEBROOT="/var/www/acme-challenge"
ACME_RENEW_SCRIPT="/root/linux-daimon/cert-renew.sh"
ACME_RENEW_LOG="/var/log/acme.sh/renew.log"
ACME_RENEW_LOCK="/run/lock/daimon-acme-renew.lock"
CERT_EXISTED_BEFORE=false

install_deps() {
    if command -v apt >/dev/null 2>&1; then
        apt update -y
        apt install -y curl socat lsof dnsutils ufw openssl
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl socat lsof bind-utils ufw openssl || true
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl socat lsof bind-utils ufw openssl || true
    fi
}

install_acme() {
    if [ ! -f "$ACME" ]; then
        echo -e "${GREEN}正在安装 acme.sh...${NC}"
        install_deps
        curl https://get.acme.sh | sh -s email=asdad@163.com
        [ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc" || true
        [ -f "$HOME/.profile" ] && source "$HOME/.profile" || true
        if [ ! -f "$ACME" ]; then
            echo -e "${RED}acme.sh 安装失败${NC}"
            exit 1
        fi
        echo -e "${GREEN}acme.sh 安装成功${NC}"
    else
        echo -e "${GREEN}acme.sh 已安装${NC}"
    fi
    "$ACME" --set-default-ca --server letsencrypt >/dev/null 2>&1 || true
}

install_nginx() {
    if ! command -v nginx >/dev/null 2>&1; then
        echo -e "${YELLOW}正在安装 nginx...${NC}"
        apt update -y
        apt install -y nginx
    fi
    systemctl start nginx 2>/dev/null || true
    systemctl enable nginx 2>/dev/null || true
    echo -e "${GREEN}nginx 已安装并启动${NC}"
    nginx_domain_enable_auto_backup >/dev/null 2>&1 || true
}

ensure_ufw_80() {
    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | grep -qi "Status: active"; then
            ufw allow 80/tcp 2>/dev/null || true
            ufw allow 443/tcp 2>/dev/null || true
        fi
    fi
}

nginx_domain_write_renew_script() {
    mkdir -p "$(dirname "$ACME_RENEW_SCRIPT")" "$(dirname "$ACME_RENEW_LOG")" "$(dirname "$ACME_RENEW_LOCK")"
    cat > "$ACME_RENEW_SCRIPT" <<'EOF'
#!/bin/bash
set -u
ACME="${HOME}/.acme.sh/acme.sh"
LOG_FILE="/var/log/acme.sh/renew.log"
LOCK_DIR="/run/lock/daimon-acme-renew.lock.d"
mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$LOCK_DIR")"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
fi
trap 'rm -rf "$LOCK_DIR"' EXIT
status=0
{
    printf '[%s] acme.sh renewal started\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    if ! "$ACME" --cron --home "${HOME}/.acme.sh"; then
        status=1
        logger -t daimon-acme-renew "acme.sh renewal failed"
    fi
    if ! nginx -t; then
        status=1
        logger -t daimon-acme-renew "nginx config test failed after certificate renewal"
    elif ! systemctl reload nginx; then
        status=1
        logger -t daimon-acme-renew "nginx reload failed after certificate renewal"
    fi
    printf '[%s] acme.sh renewal finished status=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$status"
} >> "$LOG_FILE" 2>&1
exit "$status"
EOF
    chmod 700 "$ACME_RENEW_SCRIPT"
    cat > /etc/logrotate.d/daimon-acme-renew <<EOF
$ACME_RENEW_LOG {
    daily
    rotate 30
    size 10M
    missingok
    notifempty
    compress
    copytruncate
}
EOF
}

nginx_domain_ensure_renew_cron() {
    nginx_domain_write_renew_script
    nginx_domain_ensure_crontab || return 1
    local cron_line="0 3 * * * /bin/bash $ACME_RENEW_SCRIPT >> $ACME_RENEW_LOG 2>&1"
    (crontab -l 2>/dev/null | grep -vF 'acme.sh --cron' | grep -vF "$ACME_RENEW_SCRIPT" || true; echo "$cron_line") | crontab -
}

nginx_domain_config_matches() {
    local domain="$1" conf="$2"
    awk -v domain="$domain" '
        $1 == "server_name" {
            for (i=2; i<=NF; i++) {
                value=$i; gsub(/;/, "", value)
                if (value == domain) found=1
            }
        }
        END { exit(found ? 0 : 1) }
    ' "$conf"
}

nginx_domain_config_has_challenge() {
    local domain="$1" conf
    for conf in /etc/nginx/sites-available/* /etc/nginx/conf.d/*.conf; do
        [ -f "$conf" ] || continue
        nginx_domain_config_matches "$domain" "$conf" || continue
        awk '
            BEGIN { depth=0; in_server=0; listen80=0; has_location=0; bad_return=0 }
            {
                line=$0
                if (line ~ /^[[:space:]]*server[[:space:]]*\{/) in_server=1
                if (in_server && depth == 1 && line ~ /^[[:space:]]*listen[[:space:]]+((\[::\]:)?80)([[:space:];]|$)/) listen80=1
                if (in_server && depth == 1 && line ~ /location[[:space:]]+\^~[[:space:]]+\/\.well-known\/acme-challenge\//) has_location=1
                if (in_server && depth == 1 && line ~ /^[[:space:]]*return[[:space:]]+301[[:space:]]+/) bad_return=1
                opens=line; gsub(/[^\{]/, "", opens)
                closes=line; gsub(/[^\}]/, "", closes)
                depth += length(opens) - length(closes)
                if (in_server && depth == 0) {
                    if (listen80 && has_location && !bad_return) found=1
                    in_server=0; listen80=0; has_location=0; bad_return=0
                }
            }
            END { exit(found ? 0 : 1) }
        ' "$conf" && return 0
    done
    return 1
}

nginx_domain_config_exists() {
    local domain="$1" conf
    for conf in /etc/nginx/sites-available/* /etc/nginx/conf.d/*.conf; do
        [ -f "$conf" ] || continue
        nginx_domain_config_matches "$domain" "$conf" || continue
        grep -Eq 'listen[[:space:]]+((\[::\]:)?80)([[:space:];]|$)' "$conf" 2>/dev/null && return 0
    done
    return 1
}

nginx_domain_patch_challenge_file() {
    local src="$1" tmp
    tmp=$(mktemp "${src}.tmp.XXXXXX") || return 1
    awk '
        BEGIN { has_location=0; depth=0; in_server=0 }
        {
            line=$0
            lines[NR]=line
            if (line ~ /^[[:space:]]*server[[:space:]]*\{/) in_server=1
            if (line ~ /location[[:space:]]+\^~[[:space:]]+\/\.well-known\/acme-challenge\//) has_location=1
            if (in_server && depth == 1 && line ~ /^[[:space:]]*return[[:space:]]+301[[:space:]]+.*;[[:space:]]*$/) {
                indent=line
                sub(/[^[:space:]].*$/, "", indent)
                redirect=line
                sub(/^[[:space:]]*return[[:space:]]+301[[:space:]]+/, "", redirect)
                sub(/[[:space:]]*;[[:space:]]*$/, "", redirect)
                redirect_indent[NR]=indent
                redirect_value[NR]=redirect
            }
            if (in_server && depth == 1 && line ~ /^[[:space:]]*listen[[:space:]]+((\[::\]:)?80)([[:space:];]|$)/) listen80[NR]=1
            opens=line; gsub(/[^\{]/, "", opens)
            closes=line; gsub(/[^\}]/, "", closes)
            depth += length(opens) - length(closes)
            if (in_server && depth == 0) in_server=0
        }
        END {
            inserted=0
            for (i=1; i<=NR; i++) {
                if (redirect_value[i] != "") {
                    print redirect_indent[i] "if ($request_uri !~ ^/\\.well-known/acme-challenge/) {"
                    print redirect_indent[i] "    return 301 " redirect_value[i] ";"
                    print redirect_indent[i] "}"
                } else {
                    print lines[i]
                }
                if (!has_location && !inserted && listen80[i]) {
                    print "    location ^~ /.well-known/acme-challenge/ {"
                    print "        root /var/www/acme-challenge;"
                    print "        default_type text/plain;"
                    print "        try_files $uri =404;"
                    print "    }"
                    inserted=1
                }
            }
            exit((inserted || has_location) ? 0 : 1)
        }
    ' "$src" > "$tmp" || { rm -f "$tmp"; return 1; }
    mv -f "$tmp" "$src"
}

nginx_domain_ensure_challenge_route() {
    local domain="$1" conf backup patched=0 idx
    local -a patched_files backup_files
    nginx_domain_config_has_challenge "$domain" && return 0
    for conf in /etc/nginx/sites-available/*; do
        [ -f "$conf" ] || continue
        nginx_domain_config_matches "$domain" "$conf" || continue
        grep -Eq 'listen[[:space:]]+((\[::\]:)?80)([[:space:];]|$)' "$conf" 2>/dev/null || continue
        backup=$(mktemp /tmp/daimon-nginx-conf.XXXXXX) || return 1
        cp -a "$conf" "$backup" || { rm -f "$backup"; return 1; }
        if ! nginx_domain_patch_challenge_file "$conf"; then
            cp -a "$backup" "$conf"
            rm -f "$backup"
            return 1
        fi
        patched_files+=("$conf")
        backup_files+=("$backup")
        patched=1
    done
    [ "$patched" -eq 1 ] || return 1
    if nginx -t && systemctl reload nginx; then
        rm -f "${backup_files[@]}"
        return 0
    fi
    for idx in "${!patched_files[@]}"; do
        cp -a "${backup_files[$idx]}" "${patched_files[$idx]}"
    done
    rm -f "${backup_files[@]}"
    nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
    return 1
}

nginx_domain_temp_challenge_server() {
    local domain="$1" id file
    id=$(printf '%s' "$domain" | sha256sum | awk '{print substr($1,1,16)}')
    file="/etc/nginx/conf.d/daimon-acme-${id}.conf"
    mkdir -p /etc/nginx/conf.d
    cat > "$file" <<EOF
server {
    listen 80;
    server_name $domain;
    location ^~ /.well-known/acme-challenge/ {
        root $ACME_WEBROOT;
        default_type text/plain;
        try_files \$uri =404;
    }
}
EOF
    if nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1; then
        printf '%s\n' "$file"
    else
        rm -f "$file"
        return 1
    fi
}

nginx_domain_remove_temp_challenge_server() {
    local file="$1"
    [ -f "$file" ] || return 0
    rm -f "$file"
    nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
}

nginx_domain_verify_challenge() {
    local domain="$1" token token_file response
    token="daimon-acme-$RANDOM-$$-$(date +%s)"
    token_file="$ACME_WEBROOT/.well-known/acme-challenge/$token"
    mkdir -p "$(dirname "$token_file")"
    printf '%s' "$token" > "$token_file"
    for _ in $(seq 1 10); do
        response=$(curl -fsS --max-time 8 -H "Host: $domain" "http://127.0.0.1/.well-known/acme-challenge/$token" 2>/dev/null || true)
        [ "$response" = "$token" ] && { rm -f "$token_file"; return 0; }
        sleep 0.5
    done
    rm -f "$token_file"
    return 1
}

show_dns() {
    local d="$1"
    if command -v dig >/dev/null 2>&1; then
        echo -e "${YELLOW}DNS A 记录: $(dig +short "$d" A | tr '\n' ' ')${NC}"
        echo -e "${YELLOW}DNS AAAA记录: $(dig +short "$d" AAAA | tr '\n' ' ')${NC}"
    fi
}

restart_nginx_if_needed() {
    if [ "$NGINX_WAS_RUNNING" = true ]; then
        systemctl start nginx
        echo -e "${GREEN}nginx 已重新启动${NC}"
    fi
}

show_cert_list() {
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}acme.sh 已注册的证书列表：${NC}"
    "$ACME" --list 2>/dev/null || echo -e "${YELLOW}暂无已注册的证书${NC}"
    echo ""
    echo -e "${GREEN}/root/domain 下的证书文件夹：${NC}"
    [ -d "/root/domain" ] && ls -la /root/domain/ 2>/dev/null || echo -e "${YELLOW}目录为空${NC}"
    echo -e "${GREEN}=========================================${NC}"
}

show_existing_nginx_and_certs() {
    echo -e "${YELLOW}已存在的 nginx 配置：${NC}"
    local found_nginx=false
    local conf key real_path name server_name listen proxy_pass
    declare -A seen_nginx=()
    for conf in /etc/nginx/sites-enabled/* /etc/nginx/sites-available/* /etc/nginx/conf.d/*.conf; do
        [ -e "$conf" ] || continue
        real_path=$(readlink -f "$conf" 2>/dev/null || echo "$conf")
        name=$(basename "$conf")
        key="$name|$real_path"
        if [ -n "${seen_nginx[$key]:-}" ]; then
            continue
        fi
        seen_nginx[$key]=1
        found_nginx=true
        server_name=$(grep -E '^[[:space:]]*server_name[[:space:]]+' "$conf" 2>/dev/null | head -1 | sed -E 's/^[[:space:]]*server_name[[:space:]]+//; s/;[[:space:]]*$//')
        listen=$(grep -E '^[[:space:]]*listen[[:space:]]+' "$conf" 2>/dev/null | head -1 | sed -E 's/^[[:space:]]*listen[[:space:]]+//; s/;[[:space:]]*$//')
        proxy_pass=$(grep -E '^[[:space:]]*proxy_pass[[:space:]]+' "$conf" 2>/dev/null | head -1 | sed -E 's/^[[:space:]]*proxy_pass[[:space:]]+//; s/;[[:space:]]*$//')
        printf "  %-38s server_name=%s listen=%s proxy=%s\n" "$name" "${server_name:-未设置}" "${listen:-未设置}" "${proxy_pass:-无}"
    done
    [ "$found_nginx" = true ] || echo "  暂无 nginx 配置"
    echo "---"
    echo -e "${YELLOW}已存在的证书：${NC}"
    local found_cert=false
    local cert_dir cert_file domain expire_date formatted_date
    declare -A seen_cert=()
    for cert_dir in /root/domain/* /etc/letsencrypt/live/*; do
        [ -d "$cert_dir" ] || continue
        cert_file="$cert_dir/fullchain.pem"
        [ -f "$cert_file" ] || continue
        domain=$(basename "$cert_dir")
        if [ -n "${seen_cert[$domain]:-}" ]; then
            continue
        fi
        seen_cert[$domain]=1
        found_cert=true
        expire_date=$(openssl x509 -noout -enddate -in "$cert_file" 2>/dev/null | awk -F'=' '{print $2}')
        formatted_date=$(date -d "$expire_date" '+%Y-%m-%d' 2>/dev/null || echo "未知")
        printf "  %-38s 到期时间=%s 路径=%s\n" "$domain" "$formatted_date" "$cert_file"
    done
    [ "$found_cert" = true ] || echo "  暂无证书"
    echo "---"
}

nginx_domain_cert_dir_for_domain() {
    local domain="$1" conf cert_path
    for conf in /etc/nginx/sites-available/* /etc/nginx/conf.d/*.conf; do
        [ -f "$conf" ] || continue
        nginx_domain_config_matches "$domain" "$conf" || continue
        cert_path=$(awk '$1 == "ssl_certificate" { gsub(/;/, "", $2); print $2; exit }' "$conf")
        case "$cert_path" in
            /root/domain/*/fullchain.pem) dirname "$cert_path"; return 0 ;;
        esac
    done
    echo "/root/domain/$domain"
}

cleanup_nginx_and_cert() {
    local DOMAIN="$1"
    local NGINX_NAME="$2"
    local FOLDER CERT_DIR
    CERT_DIR=$(nginx_domain_cert_dir_for_domain "$DOMAIN")

    [ -n "$NGINX_NAME" ] && rm -f "/etc/nginx/sites-available/$NGINX_NAME" "/etc/nginx/sites-enabled/$NGINX_NAME"
    [ -n "$DOMAIN" ] && "$ACME" --remove -d "$DOMAIN" 2>/dev/null || true
    [ -n "$DOMAIN" ] && rm -rf "$HOME/.acme.sh/${DOMAIN}_ecc" "$HOME/.acme.sh/$DOMAIN" 2>/dev/null || true
    [ -n "$CERT_DIR" ] && rm -rf "$CERT_DIR" 2>/dev/null || true

    if command -v nginx >/dev/null 2>&1; then
        nginx -t >/dev/null 2>&1 && systemctl reload nginx 2>/dev/null || true
    fi
    echo -e "${YELLOW}已清理失败残留：nginx 配置和证书${NC}"
}

cleanup_failed_cert_request() {
    local domain="$1" nginx_name="$2"
    if [ "$CERT_EXISTED_BEFORE" = true ]; then
        [ -n "$nginx_name" ] && rm -f "/etc/nginx/sites-available/$nginx_name" "/etc/nginx/sites-enabled/$nginx_name"
        nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
        echo -e "${YELLOW}申请失败，已有证书和 acme.sh 记录已保留${NC}"
    else
        cleanup_nginx_and_cert "$domain" "$nginx_name"
    fi
}

remove_cert() {
    echo -e "${GREEN}当前已注册的证书：${NC}"
    "$ACME" --list 2>/dev/null || echo -e "${YELLOW}暂无已注册的证书${NC}"
    echo ""

    read -p "请输入要移除的域名: " REMOVE_DOMAIN
    [ -z "$REMOVE_DOMAIN" ] && echo -e "${RED}域名不能为空${NC}" && return 1

    read -p "确认移除 $REMOVE_DOMAIN？[y/n]: " CONFIRM
    [ "$CONFIRM" != "y" ] && return 0

    validate_domain "$REMOVE_DOMAIN" || { echo -e "${RED}域名格式不正确${NC}"; return 1; }

    "$ACME" --remove -d "$REMOVE_DOMAIN" 2>/dev/null || true

    local cert_dir
    cert_dir=$(nginx_domain_cert_dir_for_domain "$REMOVE_DOMAIN")
    case "$cert_dir" in /root/domain/*) [ -d "$cert_dir" ] && rm -rf "$cert_dir" ;; esac

    echo -e "${GREEN}证书移除完成！${NC}"
}

remove_nginx_config() {
    echo -e "${GREEN}当前 nginx 配置文件：${NC}"
    echo ""

    local configs=()
    local i=1
    for f in /etc/nginx/sites-available/*; do
        [ -f "$f" ] || continue
        local name=$(basename "$f")
        [ "$name" = "default" ] && continue
        configs+=("$name")
        echo "$i) $name"
        ((i++))
    done

    [ ${#configs[@]} -eq 0 ] && echo -e "${YELLOW}暂无自定义配置${NC}" && return 0

    echo ""
    read -p "请输入要删除的配置编号: " NUM

    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || [ "$NUM" -lt 1 ] || [ "$NUM" -gt ${#configs[@]} ]; then
        echo -e "${RED}无效选择${NC}"
        return 1
    fi

    local CONF_NAME="${configs[$((NUM-1))]}"
    read -p "确认删除 $CONF_NAME？[y/n]: " CONFIRM
    [ "$CONFIRM" != "y" ] && return 0

    rm -f "/etc/nginx/sites-available/$CONF_NAME"
    rm -f "/etc/nginx/sites-enabled/$CONF_NAME"

    nginx -t && systemctl reload nginx
    echo -e "${GREEN}配置 $CONF_NAME 已删除${NC}"
}

remove_nginx_and_cert() {
    echo -e "${GREEN}当前 nginx 配置文件：${NC}"
    echo ""

    local configs=()
    local i=1
    for f in /etc/nginx/sites-available/*; do
        [ -f "$f" ] || continue
        local name=$(basename "$f")
        [ "$name" = "default" ] && continue
        configs+=("$name")
        echo "$i) $name"
        ((i++))
    done

    [ ${#configs[@]} -eq 0 ] && echo -e "${YELLOW}暂无自定义配置${NC}" && return 0

    echo ""
    read -p "请输入要删除的配置编号: " NUM

    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || [ "$NUM" -lt 1 ] || [ "$NUM" -gt ${#configs[@]} ]; then
        echo -e "${RED}无效选择${NC}"
        return 1
    fi

    local CONF_NAME="${configs[$((NUM-1))]}"

    # 从配置文件中提取证书路径
    local CONF_FILE="/etc/nginx/sites-available/$CONF_NAME"
    local CERT_DIR=$(grep -oP 'ssl_certificate \K[^;]+' "$CONF_FILE" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || true)
    local DOMAIN=$(grep -oP 'server_name \K[^;]+' "$CONF_FILE" 2>/dev/null | head -1 | awk '{print $1}' || true)

    echo ""
    echo -e "${YELLOW}将删除以下内容：${NC}"
    echo "- nginx 配置: $CONF_FILE"
    [ -n "$CERT_DIR" ] && [ -d "$CERT_DIR" ] && echo "- 证书目录: $CERT_DIR"
    [ -n "$DOMAIN" ] && echo "- acme.sh 证书: $DOMAIN"
    echo ""

    read -p "确认删除？[y/n]: " CONFIRM
    [ "$CONFIRM" != "y" ] && return 0

    # 删除 nginx 配置
    rm -f "/etc/nginx/sites-available/$CONF_NAME"
    rm -f "/etc/nginx/sites-enabled/$CONF_NAME"

    # 仅允许删除受管证书目录，避免误删任意路径
    case "$CERT_DIR" in /root/domain/*|/etc/letsencrypt/live/*) [ -n "$CERT_DIR" ] && [ -d "$CERT_DIR" ] && rm -rf "$CERT_DIR" ;; esac

    # 从 acme.sh 移除证书
    [ -n "$DOMAIN" ] && "$ACME" --remove -d "$DOMAIN" 2>/dev/null || true

    nginx -t && systemctl reload nginx
    echo -e "${GREEN}nginx 配置和证书已删除${NC}"
}

create_test_page() {
    read -p "请输入测试文件名称: " TEST_NAME
    [ -z "$TEST_NAME" ] && echo -e "${RED}名称不能为空${NC}" && return 1
    read -p "请输入测试端口号: " TEST_PORT
    [ -z "$TEST_PORT" ] && echo -e "${RED}端口号不能为空${NC}" && return 1

    install_nginx

    mkdir -p "/var/www/$TEST_NAME"
    cat > "/var/www/$TEST_NAME/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$TEST_NAME 测试页面</title>
</head>
<body>
    <h1>$TEST_NAME - 端口 $TEST_PORT 测试成功！</h1>
    <p>测试名称: $TEST_NAME</p>
    <p>监听端口: $TEST_PORT</p>
</body>
</html>
EOF

    cat > "/etc/nginx/sites-available/$TEST_NAME" << EOF
server {
    listen $TEST_PORT;
    server_name localhost;
    root /var/www/$TEST_NAME;
    index index.html;
}
EOF

    ln -sf "/etc/nginx/sites-available/$TEST_NAME" /etc/nginx/sites-enabled/

    if nginx -t; then
        nginx -s reload
        echo -e "${GREEN}=========================================${NC}"
        echo -e "${GREEN}测试页面创建成功！${NC}"
        echo "网页目录: /var/www/$TEST_NAME"
        echo "配置文件: /etc/nginx/sites-available/$TEST_NAME"
        echo "访问地址: http://127.0.0.1:$TEST_PORT"
        echo ""
        echo -e "${YELLOW}测试访问:${NC}"
        curl "http://127.0.0.1:$TEST_PORT" 2>/dev/null || echo -e "${RED}访问失败${NC}"
        echo -e "${GREEN}=========================================${NC}"
    else
        echo -e "${RED}nginx 配置检测失败${NC}"
        rm -f "/etc/nginx/sites-available/$TEST_NAME"
        rm -rf "/var/www/$TEST_NAME"
        return 1
    fi
}

remove_test_page() {
    echo -e "${GREEN}当前测试页面：${NC}"
    echo ""

    local tests=()
    local i=1
    for d in /var/www/*/; do
        [ -d "$d" ] || continue
        local name=$(basename "$d")
        [ "$name" = "html" ] && continue
        [ -f "/etc/nginx/sites-available/$name" ] || continue
        tests+=("$name")
        echo "$i) $name"
        ((i++))
    done

    [ ${#tests[@]} -eq 0 ] && echo -e "${YELLOW}暂无测试页面${NC}" && return 0

    echo ""
    read -p "请输入要删除的测试页面编号: " NUM

    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || [ "$NUM" -lt 1 ] || [ "$NUM" -gt ${#tests[@]} ]; then
        echo -e "${RED}无效选择${NC}"
        return 1
    fi

    local TEST_NAME="${tests[$((NUM-1))]}"
    read -p "确认删除 $TEST_NAME？[y/n]: " CONFIRM
    [ "$CONFIRM" != "y" ] && return 0

    rm -f "/etc/nginx/sites-enabled/$TEST_NAME"
    rm -f "/etc/nginx/sites-available/$TEST_NAME"
    rm -rf "/var/www/$TEST_NAME"

    nginx -t && nginx -s reload
    echo -e "${GREEN}测试页面 $TEST_NAME 已删除${NC}"
}


nginx_domain_backup_root() {
    echo "${DAIMON_BACKUP_DIR:-/root/linux-daimon/backup}/nginx-domain"
}

nginx_domain_auto_backup_dir() {
    echo "$(nginx_domain_backup_root)/auto_latest"
}

nginx_domain_auto_backup_script() {
    echo "${DAIMON_BACKUP_SH_DIR:-/root/linux-daimon/backup-sh}/Nginx_Domain_Local_Backup.sh"
}

nginx_domain_auto_backup_cron_line() {
    echo "0 5 * * * /bin/bash $(nginx_domain_auto_backup_script) >> /var/log/rclone/cron_Nginx_Domain_Local_Backup.log 2>&1"
}

nginx_domain_has_domains() {
    find /root/domain -mindepth 2 -maxdepth 2 -type f -name fullchain.pem -size +0c -print -quit 2>/dev/null | grep -q .
}

nginx_domain_write_auto_backup_script() {
    local script_file
    script_file="$(nginx_domain_auto_backup_script)"
    mkdir -p "$(dirname "$script_file")" /var/log/rclone
    cat > "$script_file" <<'EOF'
#!/bin/bash
set -e

BACKUP_ROOT="/root/linux-daimon/backup/nginx-domain"
BACKUP_DIR="$BACKUP_ROOT/auto_latest"
TMP_DIR="${BACKUP_DIR}.tmp"
ITEM_COUNT=0

has_domain() {
    find /root/domain -mindepth 2 -maxdepth 2 -type f -name fullchain.pem -size +0c -print -quit 2>/dev/null | grep -q .
}

copy_backup_item() {
    local src="$1"
    local dst="$2"
    if [ -e "$src" ] || [ -L "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        cp -a "$src" "$dst"
        ITEM_COUNT=$((ITEM_COUNT + 1))
    fi
}

if ! has_domain; then
    rm -rf "$TMP_DIR"
    exit 0
fi

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

copy_backup_item "/etc/nginx/sites-available" "$TMP_DIR/sites-available"
copy_backup_item "/root/domain" "$TMP_DIR/domain"
if [ -d /etc/nginx/sites-enabled ]; then
    find /etc/nginx/sites-enabled -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort > "$TMP_DIR/enabled_sites.txt"
    ITEM_COUNT=$((ITEM_COUNT + 1))
fi

cat > "$TMP_DIR/manifest.txt" <<MANIFEST
backup_time=$(date '+%Y-%m-%d %H:%M:%S')
hostname=$(hostname 2>/dev/null || true)
items=$ITEM_COUNT
mode=auto_latest
paths=/etc/nginx/sites-available /root/domain enabled_sites.txt
MANIFEST

rm -rf "$BACKUP_DIR"
mv "$TMP_DIR" "$BACKUP_DIR"
EOF
    chmod +x "$script_file"
}

nginx_domain_ensure_crontab() {
    if ! command -v crontab >/dev/null 2>&1; then
        if command -v apt >/dev/null 2>&1; then
            apt update -y
            apt install -y cron
        fi
    fi
    systemctl enable cron >/dev/null 2>&1 || true
    systemctl start cron >/dev/null 2>&1 || true
    command -v crontab >/dev/null 2>&1
}

nginx_domain_enable_auto_backup() {
    local script_file cron_line
    script_file="$(nginx_domain_auto_backup_script)"
    cron_line="$(nginx_domain_auto_backup_cron_line)"
    nginx_domain_write_auto_backup_script
    nginx_domain_ensure_crontab || return 1
    (crontab -l 2>/dev/null | grep -vF "$script_file" || true; echo "$cron_line") | crontab -
}

nginx_domain_disable_auto_backup() {
    local script_file
    script_file="$(nginx_domain_auto_backup_script)"
    rm -f "$script_file"
    crontab -l 2>/dev/null | grep -vF "$script_file" | crontab - 2>/dev/null || true
    rm -rf "$(nginx_domain_auto_backup_dir).tmp"
}

nginx_domain_sync_auto_backup_state() {
    local script_file
    script_file="$(nginx_domain_auto_backup_script)"
    if [ -f "$script_file" ]; then
        /bin/bash "$script_file" >/dev/null 2>&1 || true
    fi
}

nginx_domain_auto_backup_status() {
    local script_file cron_line backup_dir cron_output
    script_file="$(nginx_domain_auto_backup_script)"
    cron_line="$(nginx_domain_auto_backup_cron_line)"
    backup_dir="$(nginx_domain_auto_backup_dir)"
    cron_output=$(crontab -l 2>/dev/null || true)
    if [ -f "$script_file" ] && echo "$cron_output" | grep -Fxq "$cron_line"; then
        if [ -d "$backup_dir" ]; then
            echo -e "${GREEN}已开启，最新备份: $backup_dir${NC}"
        else
            echo -e "${GREEN}已开启，等待生成备份${NC}"
        fi
    elif [ -f "$script_file" ] && echo "$cron_output" | grep -Fq "$script_file"; then
        echo -e "${YELLOW}已加入定时，任务行需要更新${NC}"
    else
        echo -e "${YELLOW}未开启${NC}"
    fi
}

backup_nginx_domain() {
    local script_file backup_dir
    if ! nginx_domain_has_domains; then
        echo -e "${YELLOW}未检测到域名证书，跳过备份，已有备份不会删除。${NC}"
        return 0
    fi
    nginx_domain_enable_auto_backup || return 1
    script_file="$(nginx_domain_auto_backup_script)"
    backup_dir="$(nginx_domain_auto_backup_dir)"
    /bin/bash "$script_file" || return 1
    echo -e "${GREEN}备份完成：$backup_dir${NC}"
}

restore_nginx_domain() {
    local backup_dir confirm
    backup_dir="$(nginx_domain_auto_backup_dir)"

    if [ ! -d "$backup_dir" ]; then
        echo -e "${YELLOW}暂无可恢复的自动备份：$backup_dir${NC}"
        return 0
    fi

    echo -e "${GREEN}将恢复最新备份：$backup_dir${NC}"
    [ -f "$backup_dir/manifest.txt" ] && sed 's/^/  /' "$backup_dir/manifest.txt" | head -n 5
    read -p "恢复会合并备份内容，同名文件保留本机现有版本，是否继续？[y/N]: " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "已取消"
        return 0
    fi

    install_nginx

    restore_backup_item() {
        local src="$1"
        local dst="$2"
        [ -e "$src" ] || [ -L "$src" ] || return 0
        mkdir -p "$(dirname "$dst")"
        if [ -d "$src" ] && [ ! -L "$src" ]; then
            mkdir -p "$dst"
            cp -an "$src"/. "$dst"/
        elif [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
            cp -a "$src" "$dst"
        fi
    }

    rebuild_sites_enabled_links() {
        local backup_dir="$1"
        local names=()
        local name src dst
        mkdir -p /etc/nginx/sites-enabled
        if [ -f "$backup_dir/enabled_sites.txt" ]; then
            mapfile -t names < "$backup_dir/enabled_sites.txt"
        else
            mapfile -t names < <(find /etc/nginx/sites-available -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort)
        fi
        for name in "${names[@]}"; do
            [ -n "$name" ] && [ "$name" != "." ] && [ "$name" != ".." ] || continue
            case "$name" in */*|*\\*) continue ;; esac
            [ "$name" = "default" ] && continue
            src="/etc/nginx/sites-available/$name"
            dst="/etc/nginx/sites-enabled/$name"
            [ -f "$src" ] || continue
            [ -e "$dst" ] || [ -L "$dst" ] || ln -s "$src" "$dst"
        done
    }

    restore_backup_item "$backup_dir/sites-available" "/etc/nginx/sites-available"
    restore_backup_item "$backup_dir/domain" "/root/domain"
    rebuild_sites_enabled_links "$backup_dir"

    if nginx -t; then
        systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true
        nginx_domain_sync_auto_backup_state >/dev/null 2>&1 || true
        echo -e "${GREEN}恢复完成，nginx 配置检查通过。${NC}"
    else
        echo -e "${RED}恢复完成，但 nginx -t 检查失败。${NC}"
        return 1
    fi
}

setup_cron() {
    nginx_domain_ensure_renew_cron
    echo -e "${GREEN}已配置 webroot 自动续期（每天凌晨3点）${NC}"
}

# 申请证书
issue_cert() {
    local DOMAIN="$1" temp_challenge="" existing_conf="" keylength=""
    local -a issue_args install_args

    install_acme || return 1
    show_dns "$DOMAIN"

    validate_domain "$DOMAIN" || { echo -e "${RED}域名格式不正确${NC}"; return 1; }
    CERT_DIR=$(nginx_domain_cert_dir_for_domain "$DOMAIN")
    mkdir -p "$CERT_DIR"

    CERT_EXISTED_BEFORE=false
    if "$ACME" --list 2>/dev/null | grep -Fq "$DOMAIN" || [ -s "$CERT_DIR/fullchain.pem" ]; then
        CERT_EXISTED_BEFORE=true
        echo -e "${YELLOW}检测到已有证书，将使用 webroot 强制更新，不删除旧证书...${NC}"
    fi

    ensure_ufw_80
    mkdir -p "$ACME_WEBROOT/.well-known/acme-challenge"
    if ! command -v nginx >/dev/null 2>&1 || ! systemctl is-active nginx >/dev/null 2>&1; then
        install_nginx
    fi
    if ! nginx_domain_ensure_challenge_route "$DOMAIN"; then
        if nginx_domain_config_exists "$DOMAIN"; then
            echo -e "${RED}$DOMAIN 已有 HTTP 配置，但无法安全加入 ACME challenge 路径，请检查对应 Nginx 配置${NC}"
            return 1
        fi
        if ! temp_challenge=$(nginx_domain_temp_challenge_server "$DOMAIN"); then
            echo -e "${RED}无法为 $DOMAIN 配置 ACME webroot 验证路径${NC}"
            return 1
        fi
    fi
    if ! nginx_domain_verify_challenge "$DOMAIN"; then
        echo -e "${RED}$DOMAIN 的 webroot challenge 本机验证失败，未向 CA 发起申请${NC}"
        nginx_domain_remove_temp_challenge_server "$temp_challenge"
        return 1
    fi

    issue_args=(-d "$DOMAIN" -w "$ACME_WEBROOT" --server letsencrypt --force)
    existing_conf=$(find "$HOME/.acme.sh/${DOMAIN}_ecc" "$HOME/.acme.sh/$DOMAIN" -maxdepth 1 -type f -name '*.conf' -print -quit 2>/dev/null || true)
    [ -n "$existing_conf" ] && keylength=$(nginx_domain_acme_conf_value "$existing_conf" Le_Keylength)
    [ -n "$keylength" ] && [ "$keylength" != "no" ] && issue_args+=(--keylength "$keylength")
    if ! "$ACME" --issue "${issue_args[@]}"; then
        echo -e "${RED}证书申请失败${NC}"
        nginx_domain_remove_temp_challenge_server "$temp_challenge"
        return 1
    fi

    install_args=(--fullchain-file "$CERT_DIR/fullchain.pem" --key-file "$CERT_DIR/privkey.pem" --reloadcmd "nginx -t && systemctl reload nginx" --force)
    [ -d "$HOME/.acme.sh/${DOMAIN}_ecc" ] && install_args+=(--ecc)
    if ! "$ACME" --install-cert -d "$DOMAIN" "${install_args[@]}"; then
        echo -e "${RED}证书安装失败${NC}"
        nginx_domain_remove_temp_challenge_server "$temp_challenge"
        return 1
    fi

    nginx_domain_remove_temp_challenge_server "$temp_challenge"

    if [ -s "$CERT_DIR/fullchain.pem" ] && [ -s "$CERT_DIR/privkey.pem" ]; then
        echo -e "${GREEN}=========================================${NC}"
        echo -e "${GREEN}证书申请成功！${NC}"
        echo "证书路径: $CERT_DIR"
        ls -la "$CERT_DIR"
        echo -e "${GREEN}=========================================${NC}"
        setup_cron
        nginx_domain_enable_auto_backup >/dev/null 2>&1 || true
        return 0
    else
        echo -e "${RED}证书安装失败${NC}"
        return 1
    fi
}

# 配置 nginx
config_nginx() {
    local DOMAIN="$1"
    local NGINX_NAME="$2"
    local PORT="$3"

    validate_domain "$DOMAIN" || { echo -e "${RED}域名格式不正确${NC}"; return 1; }
    validate_name "$NGINX_NAME" || { echo -e "${RED}配置名只能包含字母、数字、点、下划线和连字符${NC}"; return 1; }
    validate_port "$PORT" || { echo -e "${RED}端口号不合法${NC}"; return 1; }
    CERT_DIR="/root/domain/$DOMAIN"

    # 检查证书是否存在
    if [ ! -s "$CERT_DIR/fullchain.pem" ] || [ ! -s "$CERT_DIR/privkey.pem" ]; then
        echo -e "${RED}证书文件不存在: $CERT_DIR${NC}"
        echo -e "${RED}请先申请证书${NC}"
        return 1
    fi

    install_nginx

    NGINX_CONF="/etc/nginx/sites-available/$NGINX_NAME"

    cat > "$NGINX_CONF" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    location ^~ /.well-known/acme-challenge/ {
        root $ACME_WEBROOT;
        default_type text/plain;
        try_files \$uri =404;
    }
    if (\$request_uri !~ ^/\\.well-known/acme-challenge/) {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate $CERT_DIR/fullchain.pem;
    ssl_certificate_key $CERT_DIR/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";

        proxy_buffering off;
        client_max_body_size 50M;
    }
}
EOF

    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/

    if nginx -t; then
        systemctl reload nginx
        echo -e "${GREEN}=========================================${NC}"
        echo -e "${GREEN}nginx 配置成功！${NC}"
        echo "配置文件: $NGINX_CONF"
        echo "域名: $DOMAIN"
        echo "代理端口: $PORT"
        echo -e "${GREEN}=========================================${NC}"
        systemctl status nginx --no-pager
    else
        echo -e "${RED}nginx 配置检测失败${NC}"
        rm -f "$NGINX_CONF" "/etc/nginx/sites-enabled/$NGINX_NAME"
        return 1
    fi
}

nginx_domain_acme_conf_value() {
    local conf="$1" key="$2"
    awk -F= -v key="$key" '
        $1 == key {
            value=substr($0, index($0, "=") + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            first=substr(value, 1, 1); last=substr(value, length(value), 1)
            if ((first == "\"" && last == "\"") || (first == "\047" && last == "\047")) value=substr(value, 2, length(value) - 2)
            print value
            exit
        }
    ' "$conf"
}

nginx_domain_migrate_existing_certs() {
    local backup_root backup_dir conf domain alt keylength challenge_domain temp_challenge route_failed unsupported_alt cert_dir
    local confirm backup_confirm backup_dir=""
    local success=0 failed=0 skipped=0
    local -a alt_args issue_args install_args challenge_domains temp_challenges
    [ "$(id -u)" -eq 0 ] || { echo -e "${RED}请使用 root 运行${NC}"; return 1; }
    [ -x "$ACME" ] || { echo -e "${RED}未检测到 acme.sh，请先申请或安装证书${NC}"; return 1; }
    echo -e "${YELLOW}将备份现有配置并逐个强制重新签发可迁移证书，可能触发 CA 频率限制。${NC}"
    read -p "确认开始迁移？[y/N]: " confirm
    [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "已取消"; return 0; }
    read -p "是否创建迁移备份？[y/N]: " backup_confirm
    install_nginx
    mkdir -p "$ACME_WEBROOT/.well-known/acme-challenge"
    if [ "$backup_confirm" = "y" ] || [ "$backup_confirm" = "Y" ]; then
        backup_root="/root/linux-daimon/backup/nginx-domain"
        backup_dir="$backup_root/migration_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        cp -a /etc/nginx/sites-available "$backup_dir/" 2>/dev/null || true
        cp -a /etc/nginx/sites-enabled "$backup_dir/" 2>/dev/null || true
        cp -a /root/domain "$backup_dir/" 2>/dev/null || true
        cp -a "$HOME/.acme.sh" "$backup_dir/acme.sh" 2>/dev/null || true
        echo -e "${YELLOW}迁移备份已保存: $backup_dir${NC}"
    else
        echo -e "${YELLOW}已跳过迁移备份${NC}"
    fi

    while IFS= read -r conf; do
        domain=$(nginx_domain_acme_conf_value "$conf" Le_Domain)
        [ -n "$domain" ] || continue
        if [[ "$domain" == \** ]] || ! validate_domain "$domain"; then
            echo -e "${YELLOW}跳过不支持 webroot 的域名: $domain${NC}"
            skipped=$((skipped + 1))
            continue
        fi
        alt_args=()
        challenge_domains=("$domain")
        unsupported_alt=false
        alt=$(nginx_domain_acme_conf_value "$conf" Le_Alt)
        [ "$alt" = "no" ] && alt=""
        while IFS= read -r alt; do
            [ -n "$alt" ] || continue
            if [[ "$alt" == \** ]] || ! validate_domain "$alt"; then
                unsupported_alt=true
                break
            fi
            alt_args+=(-d "$alt")
            challenge_domains+=("$alt")
        done < <(printf '%s' "$alt" | tr ',' '\n')
        if [ "$unsupported_alt" = true ]; then
            echo -e "${YELLOW}跳过包含通配符或不支持 SAN 的证书: $domain${NC}"
            skipped=$((skipped + 1))
            continue
        fi
        keylength=$(nginx_domain_acme_conf_value "$conf" Le_Keylength)
        [ "$keylength" = "no" ] && keylength=""
        issue_args=(-d "$domain" "${alt_args[@]}" -w "$ACME_WEBROOT" --server letsencrypt --force)
        temp_challenges=()
        route_failed=false
        for challenge_domain in "${challenge_domains[@]}"; do
            if ! nginx_domain_ensure_challenge_route "$challenge_domain"; then
                if nginx_domain_config_exists "$challenge_domain"; then
                    route_failed=true
                    break
                fi
                temp_challenge=$(nginx_domain_temp_challenge_server "$challenge_domain" 2>/dev/null || true)
                [ -n "$temp_challenge" ] && temp_challenges+=("$temp_challenge") || { route_failed=true; break; }
            fi
            nginx_domain_verify_challenge "$challenge_domain" || { route_failed=true; break; }
        done
        if [ "$route_failed" = true ]; then
            for temp_challenge in "${temp_challenges[@]}"; do nginx_domain_remove_temp_challenge_server "$temp_challenge"; done
            echo -e "${RED}$domain 或其 SAN 没有可用的 ACME challenge 路径，已跳过${NC}"
            skipped=$((skipped + 1))
            continue
        fi
        [ -n "$keylength" ] && issue_args+=(--keylength "$keylength")
        echo -e "${YELLOW}正在迁移证书: $domain${NC}"
        if ! "$ACME" --issue "${issue_args[@]}"; then
            echo -e "${RED}$domain webroot 重新签发失败，保留旧证书${NC}"
            failed=$((failed + 1))
            for temp_challenge in "${temp_challenges[@]}"; do nginx_domain_remove_temp_challenge_server "$temp_challenge"; done
            continue
        fi
        cert_dir=$(nginx_domain_cert_dir_for_domain "$domain")
        mkdir -p "$cert_dir"
        install_args=(--fullchain-file "$cert_dir/fullchain.pem" --key-file "$cert_dir/privkey.pem" --reloadcmd "nginx -t && systemctl reload nginx" --force)
        [[ "$(dirname "$conf")" == *_ecc ]] && install_args+=(--ecc)
        if "$ACME" --install-cert -d "$domain" "${install_args[@]}"; then
            echo -e "${GREEN}$domain 迁移成功${NC}"
            success=$((success + 1))
        else
            echo -e "${RED}$domain 证书安装失败，保留旧证书${NC}"
            failed=$((failed + 1))
        fi
        for temp_challenge in "${temp_challenges[@]}"; do nginx_domain_remove_temp_challenge_server "$temp_challenge"; done
    done < <(find "$HOME/.acme.sh" -mindepth 2 -maxdepth 2 -type f -name '*.conf' -print 2>/dev/null | sort)
    setup_cron || true
    nginx -t && systemctl reload nginx || true
    echo -e "${GREEN}迁移完成：成功 $success，失败 $failed，跳过 $skipped${NC}"
    [ "$failed" -eq 0 ]
}

# -------------------- 主流程 --------------------

if [ "${1:-}" = "--install-renewal" ]; then
    install_acme
    setup_cron
    echo -e "${GREEN}Nginx + 域名续期脚本已安装${NC}"
    exit 0
fi

show_menu() {
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}       Nginx + 域名管理${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo -e "域名备份: $(nginx_domain_auto_backup_status)"
    echo "---"
    show_existing_nginx_and_certs
    echo "1) 申请证书 + 配置 nginx"
    echo "2) 删除 nginx 配置 + 证书"
    echo "3) 申请证书 (webroot 模式)"
    echo "4) 移除证书"
    echo "5) 查看证书列表"
    echo "6) 配置 nginx"
    echo "7) 删除 nginx 配置"
    echo "8) 创建测试页面"
    echo "9) 删除测试页面"
    echo "10) 安装 nginx"
    echo "11) 备份域名 + nginx 配置"
    echo "12) 恢复域名 + nginx 配置"
    echo "13) 迁移/修复现有证书（webroot）"
    echo "0) 返回上一级菜单"
    echo -e "${GREEN}=========================================${NC}"
}

while true; do
    show_menu
    read -p "请选择操作 [0-13]: " ACTION

    case $ACTION in
        1)
            read -p "请输入域名: " DOMAIN
            validate_domain "$DOMAIN" || { echo -e "${RED}域名格式不正确${NC}"; continue; }
            read -p "请输入 nginx 配置文件名称: " NGINX_NAME
            validate_name "$NGINX_NAME" || { echo -e "${RED}配置名不合法${NC}"; continue; }
            read -p "请输入代理端口号: " PORT
            validate_port "$PORT" || { echo -e "${RED}端口号不合法${NC}"; continue; }

            if issue_cert "$DOMAIN"; then
                restart_nginx_if_needed
                if ! config_nginx "$DOMAIN" "$NGINX_NAME" "$PORT"; then
                    cleanup_failed_cert_request "$DOMAIN" "$NGINX_NAME"
                fi
            else
                restart_nginx_if_needed
                cleanup_failed_cert_request "$DOMAIN" "$NGINX_NAME"
            fi
            ;;
        2)
            remove_nginx_and_cert
            ;;
        3)
            read -p "请输入域名: " DOMAIN
            validate_domain "$DOMAIN" || { echo -e "${RED}域名格式不正确${NC}"; continue; }
            issue_cert "$DOMAIN"
            restart_nginx_if_needed
            ;;
        4)
            remove_cert
            ;;
        5)
            show_cert_list
            ;;
        6)
            read -p "请输入域名: " DOMAIN
            validate_domain "$DOMAIN" || { echo -e "${RED}域名格式不正确${NC}"; continue; }
            read -p "请输入 nginx 配置文件名称: " NGINX_NAME
            validate_name "$NGINX_NAME" || { echo -e "${RED}配置名不合法${NC}"; continue; }
            read -p "请输入代理端口号: " PORT
            validate_port "$PORT" || { echo -e "${RED}端口号不合法${NC}"; continue; }
            config_nginx "$DOMAIN" "$NGINX_NAME" "$PORT"
            ;;
        7)
            remove_nginx_config
            ;;
        8)
            create_test_page
            ;;
        9)
            remove_test_page
            ;;
        10)
            install_nginx
            nginx -v 2>&1 || true
            systemctl status nginx --no-pager 2>/dev/null || true
            ;;
        11)
            backup_nginx_domain
            ;;
        12)
            restore_nginx_domain
            ;;
        13)
            nginx_domain_migrate_existing_certs
            ;;
        0)
            echo -e "${GREEN}返回上一级菜单${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            ;;
    esac

    echo ""
    read -p "按回车键返回主菜单..."
done
DAIMON_CERT_NGINX_SCRIPT
	chmod +x "$DAIMON_SCRIPT_DIR/cert_nginx.sh"
	if [ "${DAIMON_UPDATE_CERT_HELPER_ONLY:-0}" = "1" ]; then
		if bash "$DAIMON_SCRIPT_DIR/cert_nginx.sh" --install-renewal; then
			echo -e "${gl_lv}Nginx + 域名续期脚本已更新: $DAIMON_SCRIPT_DIR/cert_nginx.sh${gl_bai}"
			return 0
		fi
		echo -e "${gl_hong}Nginx + 域名续期脚本更新失败${gl_bai}"
		return 1
	fi
	bash "$DAIMON_SCRIPT_DIR/cert_nginx.sh"
}
common_one_click_scripts() {
	while true; do
		clear
		echo "常用的一键脚本"
		echo "------------------------"
		echo -e "${gl_kjlan}1.   ${gl_bai}NodeQuality"
		echo -e "${gl_kjlan}2.   ${gl_bai}IPQuality"
		echo -e "${gl_kjlan}3.   ${gl_bai}融合怪"
		echo -e "${gl_kjlan}4.   ${gl_bai}NetQuality"
		echo -e "${gl_kjlan}5.   ${gl_bai}RegionRestrictionCheck"
		echo -e "${gl_kjlan}6.   ${gl_bai}bench.sh"
		echo -e "${gl_kjlan}7.   ${gl_bai}YABS"
		echo -e "${gl_kjlan}8.   ${gl_bai}HardwareQuality"
		echo -e "${gl_kjlan}9.   ${gl_bai}勇哥脚本"
		echo -e "${gl_kjlan}10.  ${gl_bai}kejilion.sh 脚本"
		echo -e "${gl_kjlan}11.  ${gl_bai}sing-box安装"
		echo -e "${gl_kjlan}12.  ${gl_bai}TcpQuality"
		echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
		read -e -p "请输入你的选择: " sub_choice || return 1
		case "$sub_choice" in
			1) daimon_exec_cached_script "https://run.NodeQuality.com" "NodeQuality.sh" ;;
			2) daimon_exec_cached_script "https://IP.Check.Place" "IPQuality.sh" ;;
			3) daimon_exec_cached_script "https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh" "ecs.sh" ;;
			4) daimon_exec_cached_script "https://Net.Check.Place" "NetQuality.sh" ;;
			5) daimon_exec_cached_script "https://check.unlock.media" "RegionRestrictionCheck.sh" ;;
			6) daimon_exec_cached_script "https://bench.sh" "bench.sh" ;;
			7) daimon_exec_cached_script "https://yabs.sh" "yabs.sh" ;;
			8) daimon_download "https://Check.Place" "HardwareQuality.sh" && exec bash "$DAIMON_SCRIPT_DIR/HardwareQuality.sh" -H ;;
			9) daimon_exec_cached_script "https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/install.sh" "x-ui-yg-install.sh" ;;
			10) exec bash -c 'bash <(curl -sL kejilion.sh)' ;;
			11) daimon_exec_cached_script "https://raw.githubusercontent.com/daimon3332/sing-box-daimon/main/sb.sh" "sing-box-daimon.sh" ;;
			12) daimon_exec_cached_script "https://raw.githubusercontent.com/daimon3332/TcpQuality/main/runTcpQuality.sh" "runTcpQuality.sh" ;;
			0) return ;;
			*) echo "无效的输入!"; break_end ;;
		esac
	done
}


rclone_status_text() {
	if command -v rclone >/dev/null 2>&1; then
		rclone version 2>/dev/null | head -n 1 | awk '{print $2}'
	else
		echo "未安装"
	fi
}

rclone_prepare_config() {
	local conf_dir="/root/.config/rclone"
	local conf_file="$conf_dir/rclone.conf"
	mkdir -p "$conf_dir" && touch "$conf_file" &&
		chmod 700 "$conf_dir" && chmod 600 "$conf_file"
}

rclone_install_cn_release() (
	local work arch version archive checksum binary target staged
	case "$(uname -m)" in
		x86_64|amd64) arch=amd64 ;;
		aarch64|arm64) arch=arm64 ;;
		i?86) arch=386 ;;
		armv7*) arch=arm-v7 ;;
		armv6*) arch=arm-v6 ;;
		*) echo "不支持的 rclone 架构: $(uname -m)"; return 1 ;;
	esac
	work=$(mktemp -d) || return 1
	staged=""
	trap 'rm -rf -- "$work"; [ -z "$staged" ] || rm -f -- "$staged"' EXIT
	daimon_download_to "https://github.com/rclone/rclone/releases/latest/download/version.txt" "$work/version.txt" 30 || return 1
	read -r _ version < "$work/version.txt"
	[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "rclone 版本信息无效"; return 1; }
	archive="rclone-$version-linux-$arch.zip"
	if ! daimon_download_to "https://downloads.rclone.org/$version/SHA256SUMS" "$work/SHA256SUMS" 30; then
		daimon_download_to "https://github.com/rclone/rclone/releases/download/$version/SHA256SUMS" "$work/SHA256SUMS" 30 || return 1
	fi
	checksum=$(awk -v name="$archive" '$2 == name || $2 == "*" name {print $1}' "$work/SHA256SUMS")
	[[ "$checksum" =~ ^[a-fA-F0-9]{64}$ ]] || { echo "未找到有效的 rclone SHA256 校验值"; return 1; }
	daimon_download_to "https://github.com/rclone/rclone/releases/download/$version/$archive" "$work/$archive" 300 || return 1
	printf '%s  %s\n' "$checksum" "$work/$archive" | sha256sum -c - || return 1
	unzip -tq "$work/$archive" >/dev/null || return 1
	binary="$work/rclone"
	unzip -p "$work/$archive" "rclone-$version-linux-$arch/rclone" > "$binary" || return 1
	chmod 755 "$binary" || return 1
	[ "$("$binary" version 2>/dev/null | head -n1)" = "rclone $version" ] || return 1
	target="${DAIMON_RCLONE_BIN_DIR:-/usr/local/bin}/rclone"
	mkdir -p "$(dirname "$target")" || return 1
	staged=$(mktemp "${target}.XXXXXX") || return 1
	command install -m 755 "$binary" "$staged" && mv -f -- "$staged" "$target" || return 1
	staged=""
	"$target" version
)

rclone_install_tool() {
	root_use
	local status=0 active_bin staged
	install curl unzip || return 1
	if daimon_is_cn; then
		rclone_install_cn_release || status=$?
	else
		DAIMON_SCRIPT_TIMEOUT=600 daimon_run_cached_script "https://rclone.org/install.sh" "rclone-install.sh" || status=$?
		active_bin=$(command -v rclone 2>/dev/null || true)
		if [ "$status" -eq 0 ] && [ "$active_bin" = /usr/local/bin/rclone ]; then
			/usr/bin/rclone version >/dev/null 2>&1 || return 1
			staged=$(mktemp /usr/local/bin/rclone.XXXXXX) || return 1
			if ! command install -m 755 /usr/bin/rclone "$staged" || ! mv -f -- "$staged" "$active_bin"; then
				rm -f -- "$staged"
				return 1
			fi
		fi
		[ "$status" -eq 3 ] && status=0
	fi
	hash -r
	if [ "$status" -ne 0 ] || ! command -v rclone >/dev/null 2>&1 || ! rclone version; then
		echo -e "${gl_hong}rclone 安装失败，现有配置保持不变。${gl_bai}"
		return 1
	fi
	rclone_prepare_config || return 1
	echo -e "${gl_lv}rclone 安装完成${gl_bai}"
	echo -e "${gl_kjlan}配置文件: /root/.config/rclone/rclone.conf${gl_bai}"
}

rclone_edit_config() {
	root_use
	if ! command -v rclone >/dev/null 2>&1; then
		echo -e "${gl_huang}rclone 未安装，请先安装。${gl_bai}"
		return
	fi
	rclone_prepare_config
	vim /root/.config/rclone/rclone.conf
	chmod 600 /root/.config/rclone/rclone.conf 2>/dev/null || true
	echo -e "${gl_lv}配置文件权限已设置为 600${gl_bai}"
	echo -e "${gl_kjlan}当前远程存储:${gl_bai}"
	rclone listremotes 2>/dev/null || true
}

rclone_uninstall_tool() {
	root_use
	read -e -p "确认卸载 rclone？(y/N): " confirm || return 1
	[ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "已取消"; return; }
	if command -v apt >/dev/null 2>&1; then
		apt purge -y rclone 2>/dev/null || true
	elif command -v dnf >/dev/null 2>&1; then
		dnf remove -y rclone 2>/dev/null || true
	elif command -v yum >/dev/null 2>&1; then
		yum remove -y rclone 2>/dev/null || true
	elif command -v apk >/dev/null 2>&1; then
		apk del rclone 2>/dev/null || true
	fi
	rm -f /usr/bin/rclone /usr/local/bin/rclone 2>/dev/null || true
	read -e -p "是否同时删除 /root/.config/rclone 配置目录？(y/N): " remove_conf || return 1
	if [ "$remove_conf" = "y" ] || [ "$remove_conf" = "Y" ]; then
		rm -rf /root/.config/rclone
	fi
	echo -e "${gl_lv}rclone 卸载完成${gl_bai}"
}

rclone_restore_name_valid() {
	local name="$1"
	[ -n "$name" ] && [ "$name" != "." ] && [ "$name" != ".." ] || return 1
	case "$name" in
		*/*|*\\*) return 1 ;;
	esac
	return 0
}

rclone_lsd_names() {
	awk 'NF >= 5 {name=$5; for (i=6; i<=NF; i++) name=name" "$i; print name}' | sed '/^[[:space:]]*$/d'
}

rclone_select_remote_dir() {
	local remote="$1"
	local title="$2"
	local list_output selected_idx i
	local dirs=()
	local valid_dirs=()
	RCLONE_SELECTED_DIR=""

	echo "$title"
	echo "远程路径: $remote"
	if ! list_output=$(rclone lsd "$remote" 2>&1); then
		echo "$list_output"
		echo -e "${gl_hong}读取远程目录失败，请检查 rclone 配置和远程路径。${gl_bai}"
		return 1
	fi

	mapfile -t dirs < <(echo "$list_output" | rclone_lsd_names)
	for i in "${dirs[@]}"; do
		rclone_restore_name_valid "$i" && valid_dirs+=("$i")
	done
	if [ "${#valid_dirs[@]}" -eq 0 ]; then
		echo -e "${gl_huang}未找到可选择的子文件夹。${gl_bai}"
		return 1
	fi

	echo "------------------------"
	for ((i=0; i<${#valid_dirs[@]}; i++)); do
		printf "%2d. %s\n" "$((i+1))" "${valid_dirs[i]}"
	done
	echo "------------------------"
	read -e -p "请输入目录序号: " selected_idx || return 1
	if ! [[ "$selected_idx" =~ ^[0-9]+$ ]] || [ "$selected_idx" -lt 1 ] || [ "$selected_idx" -gt "${#valid_dirs[@]}" ]; then
		echo "无效编号"
		return 1
	fi

	RCLONE_SELECTED_DIR="${valid_dirs[$((selected_idx-1))]}"
}

rclone_select_remote_dirs_multi() {
	local remote="$1"
	local title="$2"
	local list_output selected_raw token idx i exists
	local dirs=()
	local valid_dirs=()
	local selected_dirs=()
	RCLONE_SELECTED_DIRS=()

	echo "$title"
	echo "远程路径: $remote"
	if ! list_output=$(rclone lsd "$remote" 2>&1); then
		echo "$list_output"
		echo -e "${gl_hong}读取远程目录失败，请检查 rclone 配置和远程路径。${gl_bai}"
		return 1
	fi

	mapfile -t dirs < <(echo "$list_output" | rclone_lsd_names)
	for i in "${dirs[@]}"; do
		rclone_restore_name_valid "$i" && valid_dirs+=("$i")
	done
	if [ "${#valid_dirs[@]}" -eq 0 ]; then
		echo -e "${gl_huang}未找到可选择的子文件夹。${gl_bai}"
		return 1
	fi

	echo "------------------------"
	for ((i=0; i<${#valid_dirs[@]}; i++)); do
		printf "%2d. %s\n" "$((i+1))" "${valid_dirs[i]}"
	done
	echo "------------------------"
	echo "支持输入: 1 2 3、1,2,3、all"
	read -e -p "请输入目录序号（0 返回）: " selected_raw || return 1
	[ "$selected_raw" = "0" ] && return 1
	selected_raw="${selected_raw//,/ }"

	if [[ "$selected_raw" =~ ^[Aa][Ll][Ll]$ ]]; then
		RCLONE_SELECTED_DIRS=("${valid_dirs[@]}")
		return 0
	fi

	for token in $selected_raw; do
		if ! [[ "$token" =~ ^[0-9]+$ ]] || [ "$token" -lt 1 ] || [ "$token" -gt "${#valid_dirs[@]}" ]; then
			echo -e "${gl_huang}跳过无效编号: $token${gl_bai}"
			continue
		fi
		idx=$((token - 1))
		exists=0
		for i in "${selected_dirs[@]}"; do
			[ "$i" = "${valid_dirs[idx]}" ] && exists=1 && break
		done
		[ "$exists" -eq 0 ] && selected_dirs+=("${valid_dirs[idx]}")
	done

	if [ "${#selected_dirs[@]}" -eq 0 ]; then
		echo -e "${gl_huang}未选择有效目录。${gl_bai}"
		return 1
	fi
	RCLONE_SELECTED_DIRS=("${selected_dirs[@]}")
}

rclone_restore_remote_folder() {
	root_use
	if ! command -v rclone >/dev/null 2>&1; then
		echo -e "${gl_huang}rclone 未安装，请先安装。${gl_bai}"
		return 1
	fi

	local remote_root="qq3303338052@outlook:"
	local server_dir restore_dir remote_path target_dir confirm failed
	local restore_dirs=()

	rclone_select_remote_dir "$remote_root" "请选择服务器目录" || return
	server_dir="$RCLONE_SELECTED_DIR"

	rclone_select_remote_dirs_multi "${remote_root}${server_dir}" "请选择要恢复的文件夹，可多选" || return
	restore_dirs=("${RCLONE_SELECTED_DIRS[@]}")

	echo -e "${gl_huang}即将执行:${gl_bai}"
	for restore_dir in "${restore_dirs[@]}"; do
		remote_path="${remote_root}${server_dir}/${restore_dir}"
		target_dir="/root/${restore_dir}"
		echo "rclone copy \"$remote_path\" \"$target_dir\" --progress"
	done
	read -e -p "确认恢复以上 ${#restore_dirs[@]} 个文件夹？(y/N): " confirm || return 1
	[ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "已取消"; return; }

	failed=0
	for restore_dir in "${restore_dirs[@]}"; do
		remote_path="${remote_root}${server_dir}/${restore_dir}"
		target_dir="/root/${restore_dir}"
		mkdir -p "$target_dir"
		rclone copy "$remote_path" "$target_dir" --progress || failed=1
	done
	return "$failed"
}

rclone_remote_entry_valid() {
	local name="$1"
	[ -n "$name" ] && [ "$name" != "." ] && [ "$name" != ".." ] || return 1
	case "$name" in
		*/*|*\\*) return 1 ;;
	esac
	return 0
}

rclone_remote_lsf_entries() {
	sed '/^[[:space:]]*$/d'
}

rclone_restore_remote_sites_available() {
	local remote_backup="$1"
	local remote_dir="$remote_backup/sites-available"
	local list_output entry name target failed=0 restored=0 skipped=0
	mkdir -p /etc/nginx/sites-available
	if ! list_output=$(rclone lsf "$remote_dir" 2>/dev/null); then
		echo -e "${gl_hong}远程缺少 sites-available: $remote_dir${gl_bai}"
		return 1
	fi
	while IFS= read -r entry; do
		[ -n "$entry" ] || continue
		case "$entry" in */) continue ;; esac
		name="$entry"
		rclone_remote_entry_valid "$name" || continue
		target="/etc/nginx/sites-available/$name"
		if [ -e "$target" ] || [ -L "$target" ]; then
			echo -e "${gl_huang}已存在，跳过下载: $target${gl_bai}"
			skipped=$((skipped + 1))
			continue
		fi
		echo -e "${gl_kjlan}正在下载: $remote_dir/$name${gl_bai}"
		if rclone copyto "$remote_dir/$name" "$target" --progress; then
			restored=$((restored + 1))
		else
			failed=1
		fi
	done < <(echo "$list_output" | rclone_remote_lsf_entries)
	echo -e "${gl_lv}sites-available 恢复完成：新增 $restored，跳过 $skipped${gl_bai}"
	return "$failed"
}

rclone_rebuild_sites_enabled_links() {
	local remote_backup="$1"
	local names=()
	local name src dst list_output created=0 skipped=0
	mkdir -p /etc/nginx/sites-enabled
	if [ -n "$remote_backup" ] && list_output=$(rclone cat "$remote_backup/enabled_sites.txt" 2>/dev/null); then
		mapfile -t names < <(echo "$list_output" | rclone_remote_lsf_entries)
	elif [ -n "$remote_backup" ] && list_output=$(rclone lsf "$remote_backup/sites-available" 2>/dev/null); then
		mapfile -t names < <(echo "$list_output" | rclone_remote_lsf_entries | sed 's#/$##')
	else
		mapfile -t names < <(find /etc/nginx/sites-available -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort)
	fi
	for name in "${names[@]}"; do
		rclone_remote_entry_valid "$name" || continue
		[ "$name" = "default" ] && continue
		src="/etc/nginx/sites-available/$name"
		dst="/etc/nginx/sites-enabled/$name"
		if [ -e "$dst" ] || [ -L "$dst" ]; then
			skipped=$((skipped + 1))
			continue
		fi
		ln -s "$src" "$dst" && created=$((created + 1))
	done
	echo -e "${gl_lv}sites-enabled 软链接处理完成：新增 $created，跳过 $skipped${gl_bai}"
}

rclone_restore_remote_domain() {
	local remote_backup="$1"
	local remote_dir="$remote_backup/domain"
	local list_output entry name target failed=0 restored=0 skipped=0
	mkdir -p /root/domain
	if ! list_output=$(rclone lsf "$remote_dir" 2>/dev/null); then
		echo -e "${gl_hong}远程缺少 domain: $remote_dir${gl_bai}"
		return 1
	fi
	while IFS= read -r entry; do
		[ -n "$entry" ] || continue
		case "$entry" in */) name="${entry%/}" ;; *) continue ;; esac
		rclone_remote_entry_valid "$name" || continue
		target="/root/domain/$name"
		if [ -e "$target" ] || [ -L "$target" ]; then
			echo -e "${gl_huang}已存在，跳过下载: $target${gl_bai}"
			skipped=$((skipped + 1))
			continue
		fi
		echo -e "${gl_kjlan}正在下载: $remote_dir/$name${gl_bai}"
		mkdir -p "$target"
		if rclone copy "$remote_dir/$name" "$target" --progress; then
			restored=$((restored + 1))
		else
			rm -rf "$target"
			failed=1
		fi
	done < <(echo "$list_output" | rclone_remote_lsf_entries)
	echo -e "${gl_lv}/root/domain 恢复完成：新增 $restored，跳过 $skipped${gl_bai}"
	return "$failed"
}

rclone_check_nginx_after_restore() {
	command -v nginx >/dev/null 2>&1 || { echo -e "${gl_huang}未检测到 nginx，跳过 nginx -t。${gl_bai}"; return 0; }
	if nginx -t; then
		systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true
		echo -e "${gl_lv}nginx 配置检查通过，已重载。${gl_bai}"
	else
		echo -e "${gl_hong}nginx -t 检查失败，请手动检查合并后的配置。${gl_bai}"
		return 1
	fi
}

rclone_restore_nginx_domain_remote() {
	root_use
	if ! command -v rclone >/dev/null 2>&1; then
		echo -e "${gl_huang}rclone 未安装，请先安装。${gl_bai}"
		return 1
	fi

	local remote_root="qq3303338052@outlook:"
	local server_dir remote_backup choice confirm failed

	rclone_select_remote_dir "$remote_root" "请选择包含 Nginx + 域名备份的服务器目录" || return
	server_dir="$RCLONE_SELECTED_DIR"
	remote_backup="${remote_root}${server_dir}/linux-daimon/backup/nginx-domain/auto_latest"

	echo "正在检查远程备份: $remote_backup"
	if ! rclone lsf "$remote_backup" >/dev/null 2>&1; then
		echo -e "${gl_hong}未找到远程 Nginx + 域名备份：$remote_backup${gl_bai}"
		return 1
	fi

	while true; do
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		echo "远程备份: $remote_backup"
		echo -e "${gl_kjlan}1.   ${gl_bai}恢复 sites-available"
		echo -e "${gl_kjlan}2.   ${gl_bai}重建 sites-enabled 软链接"
		echo -e "${gl_kjlan}3.   ${gl_bai}恢复域名证书 /root/domain"
		echo -e "${gl_kjlan}4.   ${gl_bai}一键恢复全部"
		echo -e "${gl_kjlan}0.   ${gl_bai}返回"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		read -e -p "请输入你的选择: " choice || return 1
		case "$choice" in
			1)
				rclone_restore_remote_sites_available "$remote_backup" && rclone_check_nginx_after_restore
				;;
			2)
				rclone_rebuild_sites_enabled_links "$remote_backup" && rclone_check_nginx_after_restore
				;;
			3)
				rclone_restore_remote_domain "$remote_backup" && rclone_check_nginx_after_restore
				;;
			4)
				read -e -p "确认一键恢复 sites-available、sites-enabled 软链接和 /root/domain？同名文件保留本机现有版本。(y/N): " confirm || return 1
				[ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "已取消"; continue; }
				failed=0
				rclone_restore_remote_sites_available "$remote_backup" || failed=1
				rclone_rebuild_sites_enabled_links "$remote_backup" || failed=1
				rclone_restore_remote_domain "$remote_backup" || failed=1
				[ "$failed" -eq 0 ] && rclone_check_nginx_after_restore
				;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
	done
}

rclone_restore_docker_compose_projects() {
	root_use
	if ! command -v docker >/dev/null 2>&1; then
		echo -e "${gl_huang}Docker 未安装，请先安装 Docker。${gl_bai}"
		return 1
	fi
	if ! docker info >/dev/null 2>&1; then
		echo -e "${gl_huang}Docker daemon 未运行，正在尝试启动...${gl_bai}"
		systemctl start docker >/dev/null 2>&1 || service docker start >/dev/null 2>&1 || true
		sleep 2
	fi
	if ! docker info >/dev/null 2>&1; then
		echo -e "${gl_hong}Docker daemon 启动失败，请手动检查 Docker 服务。${gl_bai}"
		return 1
	fi
	if ! docker compose version >/dev/null 2>&1; then
		echo -e "${gl_huang}docker compose 不可用，请先安装 Docker Compose 插件。${gl_bai}"
		return 1
	fi

	local compose_file project_dir confirm found=0
	local start_dirs=()
	local success_dirs=()
	local skipped_dirs=()
	local failed_dirs=()
	local check_failed_dirs=()

	rclone_compose_all_services_running() {
		local project_dir="$1"
		local services running service
		if ! services="$(cd "$project_dir" && docker compose config --services 2>/dev/null)"; then
			return 2
		fi
		[ -n "$services" ] || return 2
		running="$(cd "$project_dir" && docker compose ps --services --status running 2>/dev/null || true)"
		for service in $services; do
			echo "$running" | grep -Fxq "$service" || return 1
		done
		return 0
	}

	rclone_show_compose_restore_group() {
		local title="$1"
		shift
		echo -e "${gl_kjlan}${title}:${gl_bai}"
		if [ "$#" -eq 0 ]; then
			echo "  无"
			return
		fi
		printf '  %s\n' "$@"
	}

	for compose_file in /root/*/docker-compose.yml; do
		[ -f "$compose_file" ] || continue
		found=1
		project_dir="$(dirname "$compose_file")"
		if rclone_compose_all_services_running "$project_dir"; then
			skipped_dirs+=("$project_dir")
		else
			case "$?" in
				1) start_dirs+=("$project_dir") ;;
				*) check_failed_dirs+=("$project_dir") ;;
			esac
		fi
	done

	if [ "$found" -eq 0 ]; then
		echo -e "${gl_huang}未发现 /root 第一层子文件夹中的 docker-compose.yml。${gl_bai}"
		return 0
	fi

	echo -e "${gl_kjlan}------------------------${gl_bai}"
	rclone_show_compose_restore_group "将要启动" "${start_dirs[@]}"
	rclone_show_compose_restore_group "已完整运行，跳过" "${skipped_dirs[@]}"
	rclone_show_compose_restore_group "检测失败" "${check_failed_dirs[@]}"
	echo -e "${gl_kjlan}------------------------${gl_bai}"

	if [ "${#start_dirs[@]}" -eq 0 ]; then
		if [ "${#check_failed_dirs[@]}" -eq 0 ]; then
			echo -e "${gl_lv}没有需要启动的 Docker Compose 项目。${gl_bai}"
			return 0
		fi
		echo -e "${gl_hong}存在检测失败的 Docker Compose 项目，请先检查配置。${gl_bai}"
		return 1
	fi

	read -e -p "确认启动以上 ${#start_dirs[@]} 个 Docker Compose 项目？(y/N): " confirm || return 1
	[ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "已取消"; return 0; }

	for project_dir in "${start_dirs[@]}"; do
		echo -e "${gl_kjlan}正在启动: $project_dir${gl_bai}"
		if (cd "$project_dir" && docker compose up -d); then
			success_dirs+=("$project_dir")
		else
			failed_dirs+=("$project_dir")
		fi
	done

	echo -e "${gl_kjlan}------------------------${gl_bai}"
	rclone_show_compose_restore_group "启动成功" "${success_dirs[@]}"
	rclone_show_compose_restore_group "已完整运行，跳过" "${skipped_dirs[@]}"
	rclone_show_compose_restore_group "启动失败" "${failed_dirs[@]}"
	rclone_show_compose_restore_group "检测失败" "${check_failed_dirs[@]}"
	echo -e "${gl_kjlan}------------------------${gl_bai}"
	[ "${#failed_dirs[@]}" -eq 0 ] && [ "${#check_failed_dirs[@]}" -eq 0 ]
}

rclone_manager() {
	while true; do
		clear
		echo -e "rclone 配置"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		echo -e "当前版本: ${gl_huang}$(rclone_status_text)${gl_bai}"
		echo -e "配置文件: ${gl_kjlan}/root/.config/rclone/rclone.conf${gl_bai}"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		echo -e "${gl_kjlan}1.   ${gl_bai}安装 rclone（自动创建配置文件并设置权限）"
		echo -e "${gl_kjlan}2.   ${gl_bai}修改配置文件"
		echo -e "${gl_kjlan}3.   ${gl_bai}卸载 rclone"
		echo -e "${gl_kjlan}4.   ${gl_bai}恢复远程文件夹到 /root"
		echo -e "${gl_kjlan}5.   ${gl_bai}从远程恢复 Nginx + 域名"
		echo -e "${gl_kjlan}6.   ${gl_bai}Docker Compose 恢复"
		echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		read -e -p "请输入你的选择: " sub_choice || return 1
		case $sub_choice in
			1) rclone_install_tool ;;
			2) rclone_edit_config ;;
			3) rclone_uninstall_tool ;;
			4) rclone_restore_remote_folder ;;
			5) rclone_restore_nginx_domain_remote ;;
			6) rclone_restore_docker_compose_projects ;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}


bitwarden_rclone_conf_file() {
	echo "/var/lib/docker/volumes/vaultwarden-rclone-data/_data/rclone/rclone.conf"
}

bitwarden_sync_script_file() {
	echo "${DAIMON_BACKUP_SH_DIR:-/root/linux-daimon/backup-sh}/Vaultwarden_OneDrive_to_Kissska1.sh"
}

bitwarden_sync_cron_line() {
	echo "0 6 * * * /bin/bash $(bitwarden_sync_script_file) >> /var/log/rclone/cron_Vaultwarden_OneDrive_to_Kissska1.log 2>&1"
}

bitwarden_rclone_config_status() {
	local conf_file
	conf_file=$(bitwarden_rclone_conf_file)
	if [ -f "$conf_file" ] && grep -q '^\[BitwardenBackup\]' "$conf_file" 2>/dev/null; then
		echo -e "${gl_lv}已配置${gl_bai}"
	else
		echo -e "${gl_hong}未配置${gl_bai}"
	fi
}

bitwarden_sync_script_status() {
	local script_file cron_line
	script_file=$(bitwarden_sync_script_file)
	cron_line=$(bitwarden_sync_cron_line)
	if [ -f "$script_file" ] && crontab -l 2>/dev/null | grep -Fxq "$cron_line"; then
		echo -e "${gl_lv}已配置${gl_bai}"
	elif [ -f "$script_file" ]; then
		echo -e "${gl_huang}脚本已存在，定时任务未配置${gl_bai}"
	elif crontab -l 2>/dev/null | grep -Fq "$script_file"; then
		echo -e "${gl_huang}定时任务已存在，脚本不存在${gl_bai}"
	else
		echo -e "${gl_hong}未配置${gl_bai}"
	fi
}

bitwarden_check_requirements() {
	local missing=0
	if ! command -v docker >/dev/null 2>&1; then
		echo -e "${gl_hong}未检测到 docker，请先安装并启动 Docker。${gl_bai}"
		missing=1
	fi
	if ! command -v rclone >/dev/null 2>&1; then
		echo -e "${gl_hong}未检测到 rclone，请先到 rclone管理 中安装 rclone。${gl_bai}"
		missing=1
	fi
	return "$missing"
}

bitwarden_configure_rclone_conf() (
	root_use
	bitwarden_check_requirements || return 1

	local target_dir="/var/lib/docker/volumes/vaultwarden-rclone-data/_data/rclone"
	local work staged=""
	work=$(mktemp -d) || return 1
	trap 'rm -rf -- "$work"; [ -z "$staged" ] || rm -f -- "$staged"' EXIT

	echo "正在复制 rclone.conf..."
	if ! rclone copy "qq3303338052@outlook:/rclone.conf" "$work/"; then
		echo -e "${gl_hong}rclone.conf 复制失败，请检查 rclone 远程配置 qq3303338052@outlook 是否可用。${gl_bai}"
		return 1
	fi
	chmod 600 "$work/rclone.conf" || return 1
	echo "正在验证 BitwardenBackup 远程存储..."
	if ! docker run --rm \
		--mount "type=bind,source=$work/rclone.conf,target=/audit-rclone.conf,readonly" \
		ttionya/vaultwarden-backup:latest rclone --config /audit-rclone.conf \
		lsd BitwardenBackup: --contimeout 10s --timeout 30s --retries 1 --low-level-retries 1 >/dev/null 2>&1; then
		echo -e "${gl_hong}BitwardenBackup 连接验证失败，原配置保持不变。${gl_bai}"
		return 1
	fi
	mkdir -p "$target_dir" || return 1
	staged=$(mktemp "$target_dir/.rclone.conf.XXXXXX") || return 1
	command install -m 600 "$work/rclone.conf" "$staged" && mv -f -- "$staged" "$target_dir/rclone.conf" || return 1
	staged=""
	echo -e "${gl_lv}BitwardenBackup 连接验证成功，配置已更新。${gl_bai}"
)

bitwarden_backup_data() {
	root_use
	if ! command -v docker >/dev/null 2>&1; then
		echo -e "${gl_hong}未检测到 docker，请先安装 Docker。${gl_bai}"
		return 1
	fi
	if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx 'vaultwarden-backup'; then
		echo -e "${gl_hong}vaultwarden-backup 容器未运行，无法执行备份。${gl_bai}"
		echo "请先启动 vaultwarden-backup 容器后再重试。"
		return 1
	fi

	local backup_output
	echo "正在执行备份..."
	if ! backup_output=$(docker exec -i vaultwarden-backup bash /app/backup.sh 2>&1); then
		echo "$backup_output"
		echo -e "${gl_hong}备份命令执行失败，请检查容器日志和远程存储。${gl_bai}"
		return 1
	fi
	echo "$backup_output"

	if echo "$backup_output" | grep -q 'upload backup file to storage system'; then
		echo -e "${gl_lv}备份成功：已检测到 upload backup file to storage system。${gl_bai}"
	else
		echo -e "${gl_hong}备份可能失败：没有检测到 upload backup file to storage system 字段。${gl_bai}"
		return 1
	fi
}

bitwarden_restore_data() {
	root_use
	bitwarden_check_requirements || return

	local remote="qq3303338052@outlook:/BitwardenBackup"
	local list_output files selected_idx selected_file restore_dir confirm

	echo "正在读取 Bitwarden 备份列表..."
	if ! list_output=$(rclone ls "$remote" 2>&1); then
		echo "$list_output"
		echo -e "${gl_hong}读取备份列表失败，请检查 rclone 远程存储。${gl_bai}"
		return 1
	fi

	mapfile -t files < <(echo "$list_output" | awk '{print $2}' | grep -E '^backup\.[0-9]{8}\.zip$' | sort -r)
	if [ "${#files[@]}" -eq 0 ]; then
		echo -e "${gl_hong}没有找到 backup.YYYYMMDD.zip 格式的备份文件。${gl_bai}"
		return 1
	fi

	echo "可还原备份（按日期倒序，最新在最前面）："
	echo "------------------------"
	local i size
	for ((i=0; i<${#files[@]}; i++)); do
		size=$(echo "$list_output" | awk -v f="${files[i]}" '$2 == f {print $1; exit}')
		printf "%2d. %-28s %s bytes\n" "$((i+1))" "${files[i]}" "$size"
	done
	echo "------------------------"
	read -e -i "1" -p "请选择要还原的备份编号（默认 1 最新）: " selected_idx || return 1
	selected_idx="${selected_idx:-1}"
	if ! [[ "$selected_idx" =~ ^[0-9]+$ ]] || [ "$selected_idx" -lt 1 ] || [ "$selected_idx" -gt "${#files[@]}" ]; then
		echo "无效编号"
		return 1
	fi

	selected_file="${files[$((selected_idx-1))]}"
	echo -e "${gl_huang}即将还原: $selected_file${gl_bai}"
	read -e -p "还原会覆盖 vaultwarden-data 数据，确认继续？(y/N): " confirm || return 1
	[ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "已取消"; return; }

	restore_dir="$(pwd)"
	if [ ! -f "$restore_dir/$selected_file" ]; then
		echo "当前目录未找到 $selected_file，正在从远程下载到: $restore_dir"
		if ! rclone copy "$remote/$selected_file" "$restore_dir/"; then
			echo -e "${gl_hong}下载备份文件失败，已停止还原。${gl_bai}"
			return 1
		fi
	fi
	echo "执行还原命令，当前目录将挂载到 /bitwarden/restore/: $restore_dir"
	docker run --rm -it \
		--mount type=volume,source=vaultwarden-data,target=/bitwarden/data/ \
		--mount type=bind,source="$restore_dir",target=/bitwarden/restore/ \
		ttionya/vaultwarden-backup:latest restore \
		--zip-file "$selected_file"
}

bitwarden_configure_sync_script() {
	root_use
	if ! command -v rclone >/dev/null 2>&1; then
		echo -e "${gl_hong}未检测到 rclone，请先到 rclone管理 中安装 rclone。${gl_bai}"
		return 1
	fi
	check_crontab_installed
	if ! crontab_sync_remote_ready; then
		echo -e "${gl_hong}kissska1 连接检查失败，未修改同步脚本。${gl_bai}"
		return 1
	fi

	local script_dir="$DAIMON_BACKUP_SH_DIR"
	local script_file cron_line
	script_file=$(bitwarden_sync_script_file)
	cron_line=$(bitwarden_sync_cron_line)

	mkdir -p "$script_dir" /var/log/rclone
	cat > "$script_file" <<'EOF'
#!/bin/bash

# ========= 源与目标 =========
SRC_REMOTE="qq3303338052@outlook:/BitwardenBackup"
DEST_REMOTE="kissska1:/BitwardenBackup"

# ========= 日志 =========
LOG_DIR="/var/log/rclone"
LOG_FILE="$LOG_DIR/vaultwarden_backup_sync_$(date +%F).log"

mkdir -p "$LOG_DIR"

echo "===== $(date) 开始同步 Vaultwarden 备份（sync） =====" >> "$LOG_FILE"

# ========= rclone sync =========
rclone sync \
  "$SRC_REMOTE" "$DEST_REMOTE" \
  --transfers=4 \
  --checkers=8 \
  --fast-list \
  --progress \
  --log-file="$LOG_FILE" \
  --log-level INFO

echo "===== $(date) Vaultwarden 备份同步完成（sync） =====" >> "$LOG_FILE"
EOF
	chmod +x "$script_file"

    (crontab -l 2>/dev/null | grep -vF "$script_file" || true; echo "$cron_line") | crontab -

	echo -e "${gl_lv}Bitwarden 同步脚本已配置${gl_bai}"
	echo "脚本路径: $script_file"
	echo "定时任务: $cron_line"
	echo "同步日志: /var/log/rclone/vaultwarden_backup_sync_日期.log"
	echo "cron 日志: /var/log/rclone/cron_Vaultwarden_OneDrive_to_Kissska1.log"
}

bitwarden_manager() {
	crontab_sync_reconcile_legacy || true
	while true; do
		clear
		echo -e "Bitwarden管理"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		echo -e "rclone.conf 状态: $(bitwarden_rclone_config_status)"
		echo -e "同步脚本状态: $(bitwarden_sync_script_status)"
		echo -e "配置文件位置: ${gl_kjlan}$(bitwarden_rclone_conf_file)${gl_bai}"
		echo -e "同步脚本位置: ${gl_kjlan}$(bitwarden_sync_script_file)${gl_bai}"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		echo -e "${gl_kjlan}1.   ${gl_bai}配置 rclone.conf 文件"
		echo -e "${gl_kjlan}2.   ${gl_bai}数据备份"
		echo -e "${gl_kjlan}3.   ${gl_bai}数据还原"
		echo -e "${gl_kjlan}4.   ${gl_bai}配置 Bitwarden 同步脚本（OneDrive -> kissska1）"
		echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		read -e -p "请输入你的选择: " sub_choice || return 1
		case $sub_choice in
			1) bitwarden_configure_rclone_conf ;;
			2) bitwarden_backup_data ;;
			3) bitwarden_restore_data ;;
			4) bitwarden_configure_sync_script ;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}


crontab_sync_backup_dir() {
	echo "${DAIMON_BACKUP_SH_DIR:-/root/linux-daimon/backup-sh}"
}

crontab_sync_log_dir() {
	echo "/var/log/rclone"
}

crontab_sync_target_remote() {
	echo "kissska1"
}

crontab_sync_remote_ready() {
	local remote
	remote=$(crontab_sync_target_remote)
	command -v rclone >/dev/null 2>&1 || return 1
	rclone lsd "${remote}:" --max-depth 1 >/dev/null 2>&1
}

crontab_sync_legacy_script_file_by_id() {
	case "$1" in
		bitwarden) echo "$(crontab_sync_backup_dir)/Vaultwarden_OneDrive_to_Infini.sh" ;;
		via) echo "$(crontab_sync_backup_dir)/Via_Infini_to_OneDrive.sh" ;;
	esac
}

crontab_sync_script_file_by_id() {
	case "$1" in
		bitwarden) echo "$(crontab_sync_backup_dir)/Vaultwarden_OneDrive_to_Kissska1.sh" ;;
		imagebed) echo "$(crontab_sync_backup_dir)/ImageBed_CloudFlare-R2_to_OneDrive.sh" ;;
		via) echo "$(crontab_sync_backup_dir)/Via_OneDrive_to_Kissska1.sh" ;;
		nginxdomain) echo "$(crontab_sync_backup_dir)/Nginx_Domain_Local_Backup.sh" ;;
		custom) echo "$(crontab_sync_backup_dir)/$2" ;;
	esac
}

crontab_sync_cron_line_by_id() {
	local id="$1"
	local script_file="$2"
	case "$id" in
		bitwarden) echo "0 6 * * * /bin/bash $script_file >> /var/log/rclone/cron_Vaultwarden_OneDrive_to_Kissska1.log 2>&1" ;;
		imagebed) echo "0 4 * * * /bin/bash $script_file >> /var/log/rclone/cron_ImageBed_CloudFlare-R2_to_OneDrive.log 2>&1" ;;
		via) echo "30 4 * * * /bin/bash $script_file >> /var/log/rclone/cron_Via_OneDrive_to_Kissska1.log 2>&1" ;;
		nginxdomain) echo "0 5 * * * /bin/bash $script_file >> /var/log/rclone/cron_Nginx_Domain_Local_Backup.log 2>&1" ;;
		custom)
			local script_base
			script_base=$(basename "$script_file" .sh)
			echo "45 4 * * * /bin/bash $script_file >> /var/log/rclone/cron_${script_base}.log 2>&1"
			;;
	esac
}

crontab_sync_script_content_ok() {
	local id="$1"
	local script_file="$2"
	[ -f "$script_file" ] || return 1
	case "$id" in
		bitwarden)
			grep -q 'SRC_REMOTE="qq3303338052@outlook:/BitwardenBackup"' "$script_file" 2>/dev/null \
				&& grep -q 'DEST_REMOTE="kissska1:/BitwardenBackup"' "$script_file" 2>/dev/null \
				&& grep -q 'rclone sync' "$script_file" 2>/dev/null
			;;
		imagebed)
			grep -q 'qq3303338052@cloudflare:image-bed-daimon' "$script_file" 2>/dev/null \
				&& grep -q 'qq3303338052@outlook:image-bed-daimon' "$script_file" 2>/dev/null \
				&& grep -q 'rclone sync' "$script_file" 2>/dev/null
			;;
		via)
			grep -q '"qq3303338052@outlook:Via"' "$script_file" 2>/dev/null \
				&& grep -q '"kissska1:Via"' "$script_file" 2>/dev/null \
				&& grep -q 'rclone sync' "$script_file" 2>/dev/null
			;;
		nginxdomain)
			grep -q 'BACKUP_DIR="$BACKUP_ROOT/auto_latest"' "$script_file" 2>/dev/null \
				&& grep -q 'find /root/domain' "$script_file" 2>/dev/null \
				&& grep -q 'copy_backup_item "/etc/nginx/sites-available"' "$script_file" 2>/dev/null \
				&& grep -q 'mv "$TMP_DIR" "$BACKUP_DIR"' "$script_file" 2>/dev/null
			;;
		custom)
			grep -q 'SRC1="/root"' "$script_file" 2>/dev/null \
				&& grep -q 'DEST1="kissska1:$SCRIPT_NAME"' "$script_file" 2>/dev/null \
				&& grep -q 'DEST2="qq3303338052@outlook:$SCRIPT_NAME"' "$script_file" 2>/dev/null \
				&& grep -q 'rclone sync' "$script_file" 2>/dev/null
			;;
	esac
}

crontab_sync_status_text() {
	local id="$1"
	local script_file="$2"
	local cron_line="$3"
	local has_file=false
	local content_ok=false
	local has_cron=false
	local cron_output=""

	[ -f "$script_file" ] && has_file=true
	cron_output=$(crontab -l 2>/dev/null || true)
	if echo "$cron_output" | grep -Fxq "$cron_line" || echo "$cron_output" | grep -Fq "$script_file"; then
		has_cron=true
	fi
	crontab_sync_script_content_ok "$id" "$script_file" && content_ok=true

	if $has_file && $content_ok && $has_cron; then
		echo -e "${gl_lv}已安装${gl_bai}"
	elif $has_file && ! $content_ok && $has_cron; then
		echo -e "${gl_huang}已加入定时，脚本内容异常${gl_bai}"
	elif $has_file && $content_ok && ! $has_cron; then
		echo -e "${gl_huang}脚本已存在，未加入定时${gl_bai}"
	elif ! $has_file && $has_cron; then
		echo -e "${gl_huang}定时任务存在，脚本不存在${gl_bai}"
	else
		echo -e "${gl_hong}未安装${gl_bai}"
	fi
}

crontab_sync_builtin_name_by_id() {
	case "$1" in
		bitwarden) echo "bitwarden同步脚本" ;;
		imagebed) echo "图床同步脚本" ;;
		via) echo "via同步脚本" ;;
		nginxdomain) echo "域名和nginx配置备份脚本" ;;
	esac
}

crontab_sync_builtin_id_by_number() {
	case "$1" in
		1) echo "bitwarden" ;;
		2) echo "imagebed" ;;
		3) echo "via" ;;
		4) echo "nginxdomain" ;;
	esac
}

crontab_sync_custom_files() {
	local dir
	dir=$(crontab_sync_backup_dir)
	[ -d "$dir" ] || return 0
	find "$dir" -maxdepth 1 -type f -name '*.sh' \
		! -name 'Vaultwarden_OneDrive_to_Kissska1.sh' \
		! -name 'Vaultwarden_OneDrive_to_Infini.sh' \
		! -name 'ImageBed_CloudFlare-R2_to_OneDrive.sh' \
		! -name 'Via_OneDrive_to_Kissska1.sh' \
		! -name 'Via_Infini_to_OneDrive.sh' \
		! -name 'Nginx_Domain_Local_Backup.sh' \
		-printf '%f\n' 2>/dev/null | sort
}

crontab_sync_write_script() {
	local id="$1"
	local script_file="$2"
	mkdir -p "$(dirname "$script_file")" "$(crontab_sync_log_dir)"
	case "$id" in
		bitwarden)
			cat > "$script_file" <<'EOF'
#!/bin/bash

# ========= 源与目标 =========
SRC_REMOTE="qq3303338052@outlook:/BitwardenBackup"
DEST_REMOTE="kissska1:/BitwardenBackup"

# ========= 日志 =========
LOG_DIR="/var/log/rclone"
LOG_FILE="$LOG_DIR/vaultwarden_backup_sync_$(date +%F).log"

mkdir -p "$LOG_DIR"

echo "===== $(date) 开始同步 Vaultwarden 备份（sync） =====" >> "$LOG_FILE"

# ========= rclone sync =========
rclone sync \
  "$SRC_REMOTE" "$DEST_REMOTE" \
  --transfers=4 \
  --checkers=8 \
  --fast-list \
  --progress \
  --log-file="$LOG_FILE" \
  --log-level INFO

echo "===== $(date) Vaultwarden 备份同步完成（sync） =====" >> "$LOG_FILE"
EOF
			;;
		imagebed)
			cat > "$script_file" <<'EOF'
#!/bin/bash

LOG_DIR="/var/log/rclone"
LOG_FILE="$LOG_DIR/r2_to_onedrive_imagebed.log"

mkdir -p "$LOG_DIR"

rclone sync \
  qq3303338052@cloudflare:image-bed-daimon \
  qq3303338052@outlook:image-bed-daimon \
  --transfers=8 \
  --checkers=16 \
  --onedrive-chunk-size=100M \
  --progress \
  --log-file="$LOG_FILE" \
  --log-level INFO
EOF
			;;
		via)
			cat > "$script_file" <<'EOF'
#!/bin/bash

LOG_DIR="/var/log/rclone"
LOG_FILE="$LOG_DIR/outlook_to_kissska1_via.log"

mkdir -p "$LOG_DIR"

rclone sync \
  "qq3303338052@outlook:Via" \
  "kissska1:Via" \
  --transfers=8 \
  --checkers=16 \
  --progress \
  --log-file="$LOG_FILE" \
  --log-level INFO
EOF
			;;
		nginxdomain)
			cat > "$script_file" <<'EOF'
#!/bin/bash
set -e

BACKUP_ROOT="/root/linux-daimon/backup/nginx-domain"
BACKUP_DIR="$BACKUP_ROOT/auto_latest"
TMP_DIR="${BACKUP_DIR}.tmp"
ITEM_COUNT=0

has_domain() {
    find /root/domain -mindepth 2 -maxdepth 2 -type f -name fullchain.pem -size +0c -print -quit 2>/dev/null | grep -q .
}

copy_backup_item() {
    local src="$1"
    local dst="$2"
    if [ -e "$src" ] || [ -L "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        cp -a "$src" "$dst"
        ITEM_COUNT=$((ITEM_COUNT + 1))
    fi
}

if ! has_domain; then
    rm -rf "$TMP_DIR"
    exit 0
fi

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

copy_backup_item "/etc/nginx/sites-available" "$TMP_DIR/sites-available"
copy_backup_item "/root/domain" "$TMP_DIR/domain"
if [ -d /etc/nginx/sites-enabled ]; then
    find /etc/nginx/sites-enabled -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort > "$TMP_DIR/enabled_sites.txt"
    ITEM_COUNT=$((ITEM_COUNT + 1))
fi

cat > "$TMP_DIR/manifest.txt" <<MANIFEST
backup_time=$(date '+%Y-%m-%d %H:%M:%S')
hostname=$(hostname 2>/dev/null || true)
items=$ITEM_COUNT
mode=auto_latest
paths=/etc/nginx/sites-available /root/domain enabled_sites.txt
MANIFEST

rm -rf "$BACKUP_DIR"
mv "$TMP_DIR" "$BACKUP_DIR"
EOF
			;;
		custom)
			cat > "$script_file" <<'EOF'
#!/bin/bash
SRC1="/root"
# 自动获取脚本文件名（不含.sh后缀）作为目标文件夹名

SCRIPT_NAME=$(basename "$0" .sh)

DEST1="kissska1:$SCRIPT_NAME"
DEST2="qq3303338052@outlook:$SCRIPT_NAME"

LOG_DIR="/var/log/rclone"
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}_$(date +%F).log"
mkdir -p "$LOG_DIR"

echo "===== $(date) 开始备份 =====" >> "$LOG_FILE"

# Outlook
rclone sync \
  "$SRC1" "$DEST2" \
  --exclude "snap/**" \
  --exclude "/.*" \
  --transfers=4 \
  --checkers=8 \
  --fast-list \
  --progress \
  --log-file="$LOG_FILE" \
  --log-level INFO

# kissska1
rclone sync \
  "$SRC1" "$DEST1" \
  --exclude "snap/**" \
  --exclude "/.*" \
  --transfers=4 \
  --checkers=8 \
  --fast-list \
  --progress \
  --log-file="$LOG_FILE" \
  --log-level INFO

echo "===== $(date) 备份完成 =====" >> "$LOG_FILE"
EOF
			;;
	esac
	chmod +x "$script_file"
}

crontab_sync_reconcile_legacy() {
	[ "${CRONTAB_SYNC_RECONCILED:-false}" = "true" ] && return 0

	local dir current_cron bit_old via_old bit_new via_new
	local bit_old_line via_old_line bit_schedule via_schedule
	local had_bit=false had_via=false legacy_found=false custom_file
	dir=$(crontab_sync_backup_dir)
	bit_old=$(crontab_sync_legacy_script_file_by_id bitwarden)
	via_old=$(crontab_sync_legacy_script_file_by_id via)
	bit_new=$(crontab_sync_script_file_by_id bitwarden)
	via_new=$(crontab_sync_script_file_by_id via)
	current_cron=$(crontab -l 2>/dev/null || true)
	bit_old_line=$(printf '%s\n' "$current_cron" | grep -F "$bit_old" | head -n1 || true)
	via_old_line=$(printf '%s\n' "$current_cron" | grep -F "$via_old" | head -n1 || true)

	if [ -f "$bit_old" ] || [ -n "$bit_old_line" ]; then legacy_found=true; fi
	if [ -f "$via_old" ] || [ -n "$via_old_line" ]; then legacy_found=true; fi
	if [ -d "$dir" ] && grep -RIl 'Infini-cloud' "$dir"/*.sh >/dev/null 2>&1; then
		legacy_found=true
	fi
	if ! $legacy_found; then
		CRONTAB_SYNC_RECONCILED=true
		return 0
	fi

	if ! crontab_sync_remote_ready; then
		echo -e "${gl_hong}检测到旧 Infini-cloud 同步任务，但 kissska1 连接检查失败，已保留原任务。${gl_bai}"
		return 1
	fi

	mkdir -p "$dir" "$(crontab_sync_log_dir)"
	if [ -f "$bit_old" ] || [ -n "$bit_old_line" ]; then
		crontab_sync_write_script bitwarden "$bit_new"
		bash -n "$bit_new" || { rm -f "$bit_new"; return 1; }
		[ -n "$bit_old_line" ] && had_bit=true
	fi
	if [ -f "$via_old" ] || [ -n "$via_old_line" ]; then
		crontab_sync_write_script via "$via_new"
		bash -n "$via_new" || { rm -f "$via_new"; return 1; }
		[ -n "$via_old_line" ] && had_via=true
	fi

	for custom_file in "$dir"/*.sh; do
		[ -f "$custom_file" ] || continue
		case "$custom_file" in "$bit_old"|"$via_old") continue ;; esac
		if grep -q 'Infini-cloud' "$custom_file" 2>/dev/null; then
			sed -i 's/Infini-cloud/kissska1/g' "$custom_file"
			bash -n "$custom_file" || { echo -e "${gl_hong}迁移后语法检查失败: $custom_file${gl_bai}"; return 1; }
		fi
	done

	bit_schedule=$(printf '%s\n' "$bit_old_line" | awk '{print $1" "$2" "$3" "$4" "$5}')
	via_schedule=$(printf '%s\n' "$via_old_line" | awk '{print $1" "$2" "$3" "$4" "$5}')
	[ -z "$bit_schedule" ] && bit_schedule="0 6 * * *"
	[ -z "$via_schedule" ] && via_schedule="30 4 * * *"

	local cron_backup filtered_cron
	cron_backup=$(mktemp) || return 1
	printf '%s\n' "$current_cron" > "$cron_backup"
	filtered_cron=$(printf '%s\n' "$current_cron" \
		| grep -vF "$bit_old" \
		| grep -vF "$via_old" \
		| grep -vF 'Infini-cloud' || true)
	if $had_bit; then
		filtered_cron="$filtered_cron
$bit_schedule /bin/bash $bit_new >> /var/log/rclone/cron_Vaultwarden_OneDrive_to_Kissska1.log 2>&1"
	fi
	if $had_via; then
		filtered_cron="$filtered_cron
$via_schedule /bin/bash $via_new >> /var/log/rclone/cron_Via_OneDrive_to_Kissska1.log 2>&1"
	fi
	if ! printf '%s\n' "$filtered_cron" | sed '/^[[:space:]]*$/d' | crontab -; then
		crontab "$cron_backup" 2>/dev/null || true
		rm -f "$cron_backup"
		echo -e "${gl_hong}crontab 迁移失败，已恢复原任务。${gl_bai}"
		return 1
	fi
	rm -f "$cron_backup" "$bit_old" "$via_old"
	CRONTAB_SYNC_RECONCILED=true
	echo -e "${gl_lv}已将旧 Infini-cloud 同步任务迁移到 kissska1。${gl_bai}"
}

crontab_sync_install_one() {
	local id="$1"
	local script_file="$2"
	local cron_line="$3"
	root_use
	if [ "$id" != "nginxdomain" ] && ! command -v rclone >/dev/null 2>&1; then
		echo -e "${gl_hong}未检测到 rclone，请先安装 rclone。${gl_bai}"
		return 1
	fi
	case "$id" in
		bitwarden|via|custom)
			if ! crontab_sync_remote_ready; then
				echo -e "${gl_hong}kissska1 连接检查失败，未修改脚本和定时任务。${gl_bai}"
				return 1
			fi
			;;
	esac
	check_crontab_installed
	crontab_sync_write_script "$id" "$script_file"
	(crontab -l 2>/dev/null | grep -vF "$script_file"; echo "$cron_line") | crontab -
	[ "$id" = "nginxdomain" ] && /bin/bash "$script_file" >/dev/null 2>&1 || true
	echo -e "${gl_lv}已安装: $(basename "$script_file")${gl_bai}"
	echo "定时任务: $cron_line"
}

crontab_sync_remove_one() {
	local script_file="$1"
	root_use
	rm -f "$script_file"
	crontab -l 2>/dev/null | grep -vF "$script_file" | crontab - 2>/dev/null || true
	echo -e "${gl_lv}已卸载: $(basename "$script_file")${gl_bai}"
}

crontab_sync_show_status() {
	local custom_files=()
	local custom_count=0
	local file cron_line id name

	echo -e "${gl_kjlan}------------------------${gl_bai}"
	for n in 1 2 3 4; do
		id=$(crontab_sync_builtin_id_by_number "$n")
		name=$(crontab_sync_builtin_name_by_id "$id")
		file=$(crontab_sync_script_file_by_id "$id")
		cron_line=$(crontab_sync_cron_line_by_id "$id" "$file")
		printf "%2d. %-20s %-58s %b\n" "$n" "$name" "$file" "$(crontab_sync_status_text "$id" "$file" "$cron_line")"
	done

	mapfile -t custom_files < <(crontab_sync_custom_files)
	if [ "${#custom_files[@]}" -eq 0 ]; then
		echo -e "自定义脚本: ${gl_hui}无${gl_bai}"
	else
		echo "自定义脚本:"
		for file_name in "${custom_files[@]}"; do
			custom_count=$((custom_count + 1))
			file="$(crontab_sync_script_file_by_id custom "$file_name")"
			cron_line=$(crontab_sync_cron_line_by_id custom "$file")
			printf "%2d. %-20s %-58s %b\n" "$((4 + custom_count))" "${file_name%.sh}" "$file" "$(crontab_sync_status_text custom "$file" "$cron_line")"
		done
	fi
	echo -e "${gl_kjlan}------------------------${gl_bai}"
}

crontab_sync_get_item_by_number() {
	local num="$1"
	local id file cron_line
	case "$num" in
		1|2|3|4)
			id=$(crontab_sync_builtin_id_by_number "$num")
			file=$(crontab_sync_script_file_by_id "$id")
			cron_line=$(crontab_sync_cron_line_by_id "$id" "$file")
			echo "$id|$file|$cron_line"
			return 0
			;;
	esac

	local custom_index=$((num - 5))
	if [ "$custom_index" -ge 0 ]; then
		local custom_files=()
		mapfile -t custom_files < <(crontab_sync_custom_files)
		if [ "$custom_index" -lt "${#custom_files[@]}" ]; then
			file=$(crontab_sync_script_file_by_id custom "${custom_files[$custom_index]}")
			cron_line=$(crontab_sync_cron_line_by_id custom "$file")
			echo "custom|$file|$cron_line"
			return 0
		fi
	fi
	return 1
}

crontab_sync_handle_numbers() {
	local action="$1"
	local nums="$2"
	local n item id file cron_line
	for n in $nums; do
		if ! [[ "$n" =~ ^[0-9]+$ ]]; then
			echo "跳过无效编号: $n"
			continue
		fi
		if ! item=$(crontab_sync_get_item_by_number "$n"); then
			echo "跳过无效编号: $n"
			continue
		fi
		IFS='|' read -r id file cron_line <<< "$item"
		if [ "$action" = "install" ]; then
			crontab_sync_install_one "$id" "$file" "$cron_line"
		else
			crontab_sync_remove_one "$file"
		fi
	done
}

crontab_sync_all_numbers() {
	local count=4
	local custom_files=()
	mapfile -t custom_files < <(crontab_sync_custom_files)
	count=$((count + ${#custom_files[@]}))
	seq 1 "$count" | tr '\n' ' '
}

crontab_sync_create_custom() {
	root_use
	local name file cron_expr cron_line
	read -e -p "请输入自定义脚本名称（自动补全 .sh 后缀）: " name || return 1
	[ -z "$name" ] && { echo "名称不能为空"; return 1; }
	name=$(basename "$name")
	name=$(echo "$name" | sed 's/[[:space:]]/_/g; s/[^A-Za-z0-9_.-]/_/g')
	[ -z "${name//_/}" ] && { echo "名称无效"; return 1; }
	[[ "$name" == *.sh ]] || name="${name}.sh"
	file=$(crontab_sync_script_file_by_id custom "$name")
	read -e -i "45 4 * * *" -p "请输入定时规则（默认 45 4 * * *）: " cron_expr || return 1
	cron_expr="${cron_expr:-45 4 * * *}"
	cron_line="$cron_expr /bin/bash $file >> /var/log/rclone/cron_${name%.sh}.log 2>&1"

	if ! command -v rclone >/dev/null 2>&1; then
		echo -e "${gl_hong}未检测到 rclone，请先安装 rclone。${gl_bai}"
		return 1
	fi
	if ! crontab_sync_remote_ready; then
		echo -e "${gl_hong}kissska1 连接检查失败，未创建同步脚本。${gl_bai}"
		return 1
	fi
	check_crontab_installed
	crontab_sync_write_script custom "$file"
	(crontab -l 2>/dev/null | grep -vF "$file"; echo "$cron_line") | crontab -
	echo -e "${gl_lv}自定义同步脚本已创建${gl_bai}"
	echo "脚本路径: $file"
	echo "定时任务: $cron_line"
}

crontab_sync_manager() {
	crontab_sync_reconcile_legacy || true
	while true; do
		clear
		echo -e "crontab同步脚本管理"
		echo -e "脚本目录: ${gl_kjlan}$(crontab_sync_backup_dir)${gl_bai}"
		echo -e "日志目录: ${gl_kjlan}$(crontab_sync_log_dir)${gl_bai}"
		crontab_sync_show_status
		echo -e "${gl_kjlan}1.   ${gl_bai}安装脚本（支持多选，输入编号，如: 1 2）"
		echo -e "${gl_kjlan}2.   ${gl_bai}卸载脚本（支持多选，输入编号，如: 2 4）"
		echo -e "${gl_kjlan}3.   ${gl_bai}一键安装（默认全选，可自行删除编号）"
		echo -e "${gl_kjlan}4.   ${gl_bai}一键卸载（默认全选，可自行删除编号）"
		echo -e "${gl_kjlan}5.   ${gl_bai}自定义脚本"
		echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		read -e -p "请输入你的选择: " sub_choice || return 1
		case "$sub_choice" in
			1)
				read -e -p "请输入要安装的脚本编号（支持多选，空格分隔）: " nums || return 1
				crontab_sync_handle_numbers install "$nums"
				;;
			2)
				read -e -p "请输入要卸载的脚本编号（支持多选，空格分隔）: " nums || return 1
				crontab_sync_handle_numbers remove "$nums"
				;;
			3)
				local nums
				nums="$(crontab_sync_all_numbers)"
				read -e -i "$nums" -p "请确认/修改要安装的脚本编号（默认全选，空格分隔）: " nums || return 1
				crontab_sync_handle_numbers install "$nums"
				;;
			4)
				local nums
				nums="$(crontab_sync_all_numbers)"
				read -e -i "$nums" -p "请确认/修改要卸载的脚本编号（默认全选，空格分隔）: " nums || return 1
				read -e -p "确认卸载以上编号对应脚本和定时任务？(y/N): " confirm || return 1
				if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
					crontab_sync_handle_numbers remove "$nums"
				else
					echo "已取消"
				fi
				;;
			5) crontab_sync_create_custom ;;
			0) return ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}


warp_manager() {
	while true; do
		clear
		echo -e "WARP 管理"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		if command -v warp >/dev/null 2>&1; then
			echo -e "快捷命令: ${gl_lv}已安装${gl_bai} ($(command -v warp))"
		else
			echo -e "快捷命令: ${gl_huang}未检测到${gl_bai}"
		fi
		if ip link show warp >/dev/null 2>&1; then
			echo -e "WARP 网络接口: ${gl_lv}存在${gl_bai}"
		else
			echo -e "WARP 网络接口: ${gl_huang}未检测到${gl_bai}"
		fi
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		echo -e "${gl_kjlan}1.   ${gl_bai}进入 WARP 官方管理脚本"
		echo -e "${gl_kjlan}2.   ${gl_bai}彻底删除 WARP（删除 WARP 网络接口、Linux Client 和 WireProxy）"
		echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		read -e -p "请输入你的选择: " sub_choice || return 1
		case $sub_choice in
			1)
				clear
				send_stats "warp管理"
				install wget curl
				daimon_run_cached_script "https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh" "warp-menu.sh"
				;;
			2)
				clear
				echo -e "${gl_hong}警告：此操作会永久关闭并彻底删除 WARP 网络接口、WARP Linux Client 和 WireProxy。${gl_bai}"
				read -e -p "确认彻底删除 WARP？(y/N): " confirm || return 1
				if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
					send_stats "彻底删除warp"
					install wget curl
					daimon_run_cached_script "https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh" "warp-menu.sh" u
				else
					echo "已取消"
				fi
				;;
			0)
				return
				;;
			*)
				echo "无效的输入!"
				;;
		esac
		break_end
	done
}




kejilion_update() {
	root_use
	clear
	echo "linux-tools-daimon 脚本更新"
	echo "------------------------"

	local tmp_file rollback_file keep_permission="false" keep_canshu="" keep_stats="" cert_helper_choice="1"
	tmp_file=$(mktemp /tmp/daimon_tmp.XXXXXX) || { echo -e "${gl_hong}创建临时文件失败${gl_bai}"; break_end; return 1; }
	rollback_file=$(mktemp /tmp/daimon_rollback.XXXXXX) || rollback_file=""

	if ! daimon_download_update_file "$tmp_file"; then
		rm -f "$tmp_file" "$rollback_file"
		echo -e "${gl_hong}更新失败：主地址和 GitHub 备用地址都不可用，已停止覆盖本地脚本${gl_bai}"
		break_end
		return 1
	fi

	if grep -q '^permission_granted="true"' /usr/local/bin/d "$DAIMON_LOCAL_SCRIPT" "$DAIMON_OLD_LOCAL_SCRIPT" >/dev/null 2>&1; then
		keep_permission="true"
	fi
	keep_canshu=$(grep -h '^canshu=' /usr/local/bin/d "$DAIMON_LOCAL_SCRIPT" "$DAIMON_OLD_LOCAL_SCRIPT" 2>/dev/null | tail -n 1 || true)
	keep_stats=$(grep -h '^ENABLE_STATS=' /usr/local/bin/d "$DAIMON_LOCAL_SCRIPT" "$DAIMON_OLD_LOCAL_SCRIPT" 2>/dev/null | tail -n 1 || true)

	read -e -p "更新 Nginx + 域名续期脚本？(1=仅主脚本，2=同时更新，0=取消): " cert_helper_choice || {
		rm -f "$tmp_file" "$rollback_file"
		return 1
	}
	case "$cert_helper_choice" in
		2) : > "$DAIMON_CERT_HELPER_MARKER" ;;
		1|"") rm -f "$DAIMON_CERT_HELPER_MARKER" 2>/dev/null || true ;;
		0|*)
			rm -f "$tmp_file" "$rollback_file"
			echo "已取消更新"
			break_end
			return 0
			;;
	esac

	[ -n "$rollback_file" ] && [ -f "$DAIMON_LOCAL_SCRIPT" ] && cp -f "$DAIMON_LOCAL_SCRIPT" "$rollback_file" 2>/dev/null || true
	chmod +x "$tmp_file"
	if ! mv -f "$tmp_file" "$DAIMON_LOCAL_SCRIPT"; then
		rm -f "$tmp_file" "$rollback_file" "$DAIMON_CERT_HELPER_MARKER"
		echo -e "${gl_hong}更新失败：无法写入 $DAIMON_LOCAL_SCRIPT${gl_bai}"
		break_end
		return 1
	fi
	if ! daimon_install_script_file "$DAIMON_LOCAL_SCRIPT" /usr/local/bin/d; then
		echo -e "${gl_hong}更新失败：无法写入 /usr/local/bin/d${gl_bai}"
		[ -n "$rollback_file" ] && [ -f "$rollback_file" ] && cp -f "$rollback_file" "$DAIMON_LOCAL_SCRIPT" 2>/dev/null || true
		rm -f "$rollback_file" "$DAIMON_CERT_HELPER_MARKER" 2>/dev/null || true
		break_end
		return 1
	fi
	chmod +x "$DAIMON_LOCAL_SCRIPT" /usr/local/bin/d
	ln -sf /usr/local/bin/d /usr/bin/d 2>/dev/null || true
	rm -f "$DAIMON_OLD_LOCAL_SCRIPT" 2>/dev/null || true

	if [ "$keep_permission" = "true" ]; then
		sed -i 's/^permission_granted="false"/permission_granted="true"/' "$DAIMON_LOCAL_SCRIPT" /usr/local/bin/d 2>/dev/null || true
	fi
	if [ -n "$keep_canshu" ]; then
		sed -i "s/^canshu=.*/$keep_canshu/" "$DAIMON_LOCAL_SCRIPT" /usr/local/bin/d 2>/dev/null || true
	fi
	if [ -n "$keep_stats" ]; then
		sed -i "s/^ENABLE_STATS=.*/$keep_stats/" "$DAIMON_LOCAL_SCRIPT" /usr/local/bin/d 2>/dev/null || true
	fi

	rm -f "$rollback_file" 2>/dev/null || true
	echo -e "${gl_lv}linux-tools-daimon 已更新${gl_bai}"
	echo "快捷命令: d"
	echo "当前进程仍是旧脚本，按任意键后将自动进入新版界面..."
	read -n 1 -s -r -p ""
	echo ""
	clear
	exec /usr/local/bin/d
}







kejilion_sh() {
crontab_sync_reconcile_legacy || true
if [ -f "$DAIMON_CERT_HELPER_MARKER" ]; then
	 rm -f "$DAIMON_CERT_HELPER_MARKER"
	 DAIMON_UPDATE_CERT_HELPER_ONLY=1 ssl_nginx_manager
fi
while true; do
clear
echo -e "${gl_kjlan}"
echo "╔╦╗╔═╗╦╔╦╗╔═╗╔╗╔"
echo " ║║╠═╣║║║║║ ║║║║"
echo "═╩╝╩ ╩╩╩ ╩╚═╝╝╚╝"
echo -e "linux-tools-daimon v$sh_v"
echo -e "命令行输入${gl_huang}d${gl_kjlan}可快速启动脚本${gl_bai}"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}1.   ${gl_bai}系统信息查询"
echo -e "${gl_kjlan}2.   ${gl_bai}系统更新"
echo -e "${gl_kjlan}3.   ${gl_bai}系统清理"
echo -e "${gl_kjlan}4.   ${gl_bai}一键配置"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}5.   ${gl_bai}系统工具"
echo -e "${gl_kjlan}6.   ${gl_bai}第三方工具"
echo -e "${gl_kjlan}7.   ${gl_bai}编程工具"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}8.   ${gl_bai}Docker管理"
echo -e "${gl_kjlan}9.   ${gl_bai}SSH管理"
echo -e "${gl_kjlan}10.  ${gl_bai}UFW管理"
echo -e "${gl_kjlan}11.  ${gl_bai}Nginx + 域名管理"
echo -e "${gl_kjlan}12.  ${gl_bai}fail2ban管理"
echo -e "${gl_kjlan}13.  ${gl_bai}BBR管理"
echo -e "${gl_kjlan}14.  ${gl_bai}WARP管理"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}15.  ${gl_bai}rclone管理"
echo -e "${gl_kjlan}16.  ${gl_bai}Bitwarden管理"
echo -e "${gl_kjlan}17.  ${gl_bai}crontab同步脚本管理"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}18.  ${gl_bai}常用的一键脚本"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}00.  ${gl_bai}脚本更新"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}0.   ${gl_bai}退出脚本"
echo -e "${gl_kjlan}------------------------${gl_bai}"
read -e -p "请输入你的选择: " choice || return 0
pause_after=true
case $choice in
  1) linux_info ;;
  2) clear ; send_stats "系统更新" ; linux_update ;;
  3) clear ; send_stats "系统清理" ; linux_clean ;;
  4) one_click_config_manager; pause_after=false ;;
  5) linux_Settings; pause_after=false ;;
  6) linux_tools thirdparty; pause_after=false ;;
  7) linux_tools programming; pause_after=false ;;
  8) linux_docker; pause_after=false ;;
  9) ssh_config_manager; pause_after=false ;;
  10) ufw_manager; pause_after=false ;;
  11) ssl_nginx_manager; pause_after=false ;;
  12) fail2ban_manager; pause_after=false ;;
  13) linux_bbr; pause_after=false ;;
  14) warp_manager; pause_after=false ;;
  15) rclone_manager; pause_after=false ;;
  16) bitwarden_manager; pause_after=false ;;
  17) crontab_sync_manager; pause_after=false ;;
  18) common_one_click_scripts; pause_after=false ;;
  00) kejilion_update; pause_after=false ;;
  0) clear ; exit ;;
  *) echo "无效的输入!" ;;
esac
	[ "$pause_after" = "true" ] && break_end
done
}




k_info() {
send_stats "d命令参考用例"
echo "-------------------"
echo "以下是 d 命令参考用例："
echo "启动脚本            d"
echo "安装软件包          d install vim wget | d add vim wget | d 安装 vim wget"
echo "卸载软件包          d remove vim wget | d del vim wget | d uninstall vim wget | d 卸载 vim wget"
echo "更新系统            d update | d 更新"
echo "清理系统垃圾        d clean | d 清理"
echo "bbr控制面板         d bbr3 | d bbrv3"
echo "设置虚拟内存        d swap 2048"
echo "设置虚拟时区        d time Asia/Shanghai | d 时区 Asia/Shanghai"
echo "Docker管理面板      d docker"
echo "fail2ban管理        d fail2ban | d f2b"
echo "rclone管理          d rclone | d rc"
echo "Bitwarden管理       d bitwarden | d bw"
echo "crontab同步脚本管理 d cronsync | d syncscripts"
echo "显示系统信息        d info"
echo "ROOT密钥管理        d sshkey"
}





if [ "$#" -eq 0 ]; then
	# 如果没有参数，运行交互式逻辑
	kejilion_sh
else
	# 如果有参数，执行相应函数
	case $1 in
		install|add|安装)
			shift
			send_stats "安装软件"
			install "$@"
			;;
		remove|del|uninstall|卸载)
			shift
			send_stats "卸载软件"
			remove "$@"
			;;
		update|更新)
			linux_update
			;;
		clean|清理)
			linux_clean
			;;
		bbr3|bbrv3)
			bbrv3
			;;
		nhyh|内核优化)
			Kernel_optimize
			;;
		trash|hsz|回收站)
			linux_trash
			;;
		backup|bf|备份)
			linux_backup
			;;
		ssh|远程连接)
			ssh_manager
			;;

		rsync|远程同步)
			rsync_manager
			;;

		rsync_run)
			shift
			send_stats "定时rsync同步"
			run_task "$@"
			;;

		disk|硬盘管理)
			disk_manager
			;;

		wp|wordpress)
			echo "LDNMP建站模块已移除"
			;;
		fd|rp|反代)
			echo "LDNMP反代模块已移除"
			;;

		loadbalance|负载均衡)
			echo "LDNMP负载均衡模块已移除"
			;;


		stream|L4负载均衡)
			echo "LDNMP四层转发模块已移除"
			;;

		swap)
			shift
			send_stats "快速设置虚拟内存"
			add_swap "$@"
			;;

		time|时区)
			shift
			send_stats "快速设置时区"
			set_timedate "$@"
			;;


		iptables_open)
			iptables_open
			;;

		frps)
			frps_panel
			;;

		frpc)
			frpc_panel
			;;


		打开端口|dkdk)
			shift
			open_port "$@"
			;;

		关闭端口|gbdk)
			shift
			close_port "$@"
			;;

		放行IP|fxip)
			shift
			allow_ip "$@"
			;;

		阻止IP|zzip)
			shift
			block_ip "$@"
			;;

		防火墙|fhq)
			iptables_panel
			;;

		命令收藏夹|fav)
			linux_fav
			;;

		status|状态)
			shift
			send_stats "软件状态查看"
			status "$@"
			;;
		start|启动)
			shift
			send_stats "软件启动"
			start "$@"
			;;
		stop|停止)
			shift
			send_stats "软件暂停"
			stop "$@"
			;;
		restart|重启)
			shift
			send_stats "软件重启"
			restart "$@"
			;;

		enable|autostart|开机启动)
			shift
			send_stats "软件开机自启"
			enable "$@"
			;;

		ssl)
			shift
			if [ "$1" = "ps" ]; then
				send_stats "查看证书状态"
				ssl_ps
			elif [ -z "$1" ]; then
				add_ssl
				send_stats "快速申请证书"
			elif [ -n "$1" ]; then
				add_ssl "$1"
				send_stats "快速申请证书"
			else
				k_info
			fi
			;;

		docker)
			shift
			case $1 in
				install|安装)
					send_stats "快捷安装docker"
					install_docker
					;;
				ps|容器)
					send_stats "快捷容器管理"
					docker_ps
					;;
				img|镜像)
					send_stats "快捷镜像管理"
					docker_image
					;;
				*)
					linux_docker
					;;
			esac
			;;

		web)
			echo "LDNMP站点管理模块已移除"
			;;



		claw|oc|OpenClaw)
			moltbot_menu
			;;

		info)
			linux_info
			;;

		fail2ban|f2b)
			fail2ban_manager
			;;

		rclone|rc)
			rclone_manager
			;;

		bitwarden|bw)
			bitwarden_manager
			;;

		cronsync|syncscripts|cron-sync)
			crontab_sync_manager
			;;


		sshkey)

			shift
			case "$1" in
				"" )
					# sshkey → 交互菜单
					send_stats "SSHKey 交互菜单"
					sshkey_panel
					;;
				github )
					shift
					send_stats "从 GitHub 导入 SSH 公钥"
					fetch_github_ssh_keys "$1"
					;;
				http://*|https://* )
					send_stats "从 URL 导入 SSH 公钥"
					fetch_remote_ssh_keys "$1"
					;;
				ssh-rsa*|ssh-ed25519*|ssh-ecdsa* )
					send_stats "公钥直接导入"
					import_sshkey "$1"
					;;
				* )
					echo "错误：未知参数 '$1'"
					echo "用法："
					echo "  k sshkey                  进入交互菜单"
					echo "  k sshkey \"<pubkey>\"     直接导入 SSH 公钥"
					echo "  k sshkey <url>            从 URL 导入 SSH 公钥"
					echo "  k sshkey github <user>    从 GitHub 导入 SSH 公钥"
					;;
			esac

			;;
		*)
			k_info
			;;
	esac
fi
