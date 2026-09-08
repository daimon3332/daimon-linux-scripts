# linux-tools-daimon 命令教程

本文按脚本菜单整理每个选项背后的核心命令。说明以 Ubuntu 为例，只列关键命令，不展开 if/else、循环、颜色输出等交互细节。

## 运行与目录

```bash
bash <(curl -fsSL https://daimon-linux-scripts.333186.xyz/linux-toolbox.sh)
```
解释：在线拉取并运行主脚本。

```bash
d
```
解释：已安装快捷命令后，直接启动工具箱。

```bash
mkdir -p /root/linux-daimon/daimon
```
解释：创建第三方脚本缓存目录。

## 一级菜单默认展示

### 交互与备份约定

- Nginx/域名菜单统一使用宿主机 Nginx + acme.sh webroot；挑战目录为 `/var/www/acme-challenge`，证书目录为 `/root/domain/<完整域名>`，证书续期会自动 reload Nginx。
- 申请证书不会杀死未知进程，若 80 端口被占用会提示处理；域名、配置名、端口输入非法时停留在当前菜单。
- SSH/UFW 操作会先放行现有 sshd 端口；一键 SSH 配置必须粘贴有效公钥。
- OpenClaw 项目还原前自动生成回滚包；Docker 备份删除需确认，备份目录仅接受 `/tmp/docker_backup_*`。

进入主菜单主要是 `echo/read/case` 交互，不会主动修改系统。主菜单选项为：

1. 系统信息查询
2. 系统更新
3. 系统清理
4. 一键配置
---
5. 系统工具
6. 第三方工具
7. 编程工具
---
8. Docker管理
9. SSH管理
10. UFW管理
11. Nginx + 域名管理
12. fail2ban管理
13. BBR管理
14. WARP管理
---
15. rclone管理
16. Bitwarden管理
17. crontab同步脚本管理
---
18. 常用的一键脚本
00. 脚本更新
0. 退出脚本

脚本更新：

```bash
curl -fsSL --connect-timeout 10 --max-time 60 --retry 2 -o /tmp/daimon_tmp.xxxxxx https://daimon-linux-scripts.333186.xyz/linux-toolbox.sh
head -1 /tmp/daimon_tmp.xxxxxx | grep -q '^#!/bin/bash'
grep -q 'DAIMON_NAME="linux-tools-daimon"' /tmp/daimon_tmp.xxxxxx
cp -f /root/linux-daimon/linux-toolbox.sh /root/linux-daimon/linux-toolbox.sh.bak.$(date +%Y%m%d%H%M%S)
mv -f /tmp/daimon_tmp.xxxxxx /root/linux-daimon/linux-toolbox.sh
cp -f /root/linux-daimon/linux-toolbox.sh /usr/local/bin/d
chmod +x /root/linux-daimon/linux-toolbox.sh /usr/local/bin/d
ln -sf /usr/local/bin/d /usr/bin/d
```
解释：从固定地址下载 `linux-toolbox.sh`，校验脚本首行和 daimon 标识，更新本地脚本与快捷命令，并保留首次同意状态、IPv6 参数和统计开关。替换前会选择“仅主脚本”或“同时更新 Nginx + 域名续期脚本”；选择同步时，新进程会原子重建 `/root/linux-daimon/daimon/cert_nginx.sh`，并非交互安装新的续期包装脚本和 cron。更新成功后会 `exec /usr/local/bin/d` 重新进入新版脚本，避免继续显示旧进程缓存的菜单。

## 1. 系统信息查询

默认展示：主机名、系统版本、内核、CPU、内存、Swap、硬盘、流量、网络算法、运营商、IPv4、IPv6、DNS、位置、时间、时区、本地语言、运行时长，以及 SSH、UFW、Docker、Nginx、Fail2ban、rclone、Bitwarden 状态。

```bash
curl -s https://ipinfo.io/ip
curl -s --max-time 1 https://v6.ipinfo.io/ip
ip route get 8.8.8.8 | grep -oP 'src \K[^ ]+'
```
解释：查询公网 IPv4、公网 IPv6、本机默认出口内网 IP。

```bash
lscpu
nproc
cat /proc/cpuinfo
```
解释：查看 CPU 型号、核心数、频率等信息。

```bash
free -b
free -m
df -h
```
解释：查看内存、Swap、硬盘占用。

```bash
curl -s ipinfo.io
uptime
awk '/^nameserver/{print $2}' /etc/resolv.conf
uname -m
uname -n
uname -r
```
解释：查看 IP 地理位置、负载、DNS、架构、主机名、内核。

```bash
sysctl -n net.ipv4.tcp_congestion_control
sysctl -n net.core.default_qdisc
date "+%Y-%m-%d %I:%M %p"
cat /proc/uptime
ss -t | wc -l
ss -u | wc -l
```
解释：查看 TCP 算法、队列算法、时间、运行时长、TCP/UDP 连接数。

```bash
sshd -T
ufw status
docker --version
docker ps
nginx -v
fail2ban-client status
rclone version
grep '^\[BitwardenBackup\]' /var/lib/docker/volumes/vaultwarden-rclone-data/_data/rclone/rclone.conf
```
解释：系统信息查询会额外检测 SSH 端口、密码/密钥登录状态、UFW 是否安装和是否开启、时区和语言、Docker daemon 可用性、Nginx、Fail2ban、rclone 版本，以及 Bitwarden/vaultwarden 相关容器和 vaultwarden-backup 使用的 rclone 配置状态。

## 2. 系统更新

```bash
DEBIAN_FRONTEND=noninteractive dpkg --configure -a
DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt update -y
DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a APT_LISTCHANGES_FRONTEND=none apt full-upgrade -y
```
解释：修复 apt/dpkg 状态，更新软件源并升级系统软件包。锁占用、dpkg 修复或索引更新失败时停止，不强杀进程或删除锁。

## 3. 系统清理

```bash
DEBIAN_FRONTEND=noninteractive dpkg --configure -a
apt autoremove --purge -y
apt clean -y
apt autoclean -y
journalctl --rotate
journalctl --vacuum-size=500M
```
解释：修复包管理器状态，清理无用依赖和包缓存，按已有 500M 上限清理 journal。步骤失败即停止；不清空共享 `/tmp`、`/var/log`，不按 1 秒保留期删除日志。没有 journalctl 时跳过日志清理，opkg 没有统一的安全缓存清理入口时跳过。

## 4. 一键配置

默认展示 1-10 号快捷配置项，用来把常用初始化动作集中到一个菜单。直接回车等同于选择 `1. 配置全部`，执行前会预填 `2 3 4 5 6 7 8 9 10`，用户可以自行删除不想执行的编号。

### 4.1 配置全部

```bash
read -e -i "2 3 4 5 6 7 8 9 10" -p "请确认/修改要执行的配置编号（默认全选，空格分隔）: " nums
```
解释：默认选择全部配置项，执行前允许删减编号；最终按输入的编号逐项执行。

### 4.2 系统更新

```bash
linux_update
```
解释：执行脚本内系统更新流程，Ubuntu 下核心是 `apt update` 和 `apt full-upgrade -y`。

### 4.3 系统清理

```bash
linux_clean
```
解释：执行脚本内系统清理流程，清理无用依赖、缓存和 journal 日志。

### 4.4 设置虚拟内存 1G

```bash
add_swap 1024
```
解释：创建或重建 `/swapfile`，大小为 1024MB，并写入 `/etc/fstab`。

### 4.5 优化 DNS 地址

```bash
country=$(curl -s --max-time 5 https://ipinfo.io | grep -oE '"country"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | cut -d'"' -f4)
if [ "$country" = "CN" ]; then
  # 国内 DNS
  dns1_ipv4="223.5.5.5"
  dns2_ipv4="119.29.29.29"
  dns1_ipv6="2400:3200::1"
  dns2_ipv6="2402:4e00::"
else
  # 国外和香港 DNS
  dns1_ipv4="1.1.1.1"
  dns2_ipv4="8.8.8.8"
  dns1_ipv6="2606:4700:4700::1111"
  dns2_ipv6="2001:4860:4860::8888"
fi
set_dns
```
解释：一键配置里不再进入 DNS 交互菜单，而是根据 `ipinfo.io` 的 `country` 字段自动判断；`CN` 使用国内 DNS，其他地区包括 `HK` 使用国外 DNS。

### 4.6 开启 BBR 加速（BBR + FQ）

```bash
modprobe tcp_bbr
cat > /etc/sysctl.d/99-daimon-bbr-fq.conf <<EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
sysctl -p /etc/sysctl.d/99-daimon-bbr-fq.conf
```
解释：使用内核自带 BBR，队列算法使用 FQ，并写入持久化配置。

### 4.7 安装 Docker

```bash
curl -s --max-time 8 ipinfo.io
bash /root/linux-daimon/daimon/install-docker-auto.sh 1   # 中国大陆：阿里云，失败切清华/官方
bash /root/linux-daimon/daimon/install-docker-auto.sh 2   # 国外和香港：Docker 官方源
```
解释：根据 `ipinfo.io` 的 `country` 字段判断；`CN` 使用国内镜像源，其他地区包括香港使用 Docker 官方源。

### 4.8 系统网络自适应优化

```bash
sysctl -e -p /etc/sysctl.d/99-network-optimize.conf
```
解释：执行内置自定义网络优化，不下载第三方脚本，不换内核，只写入并应用 sysctl 参数。

### 4.9 安装第三方工具

```bash
linux_tools thirdparty-install-all
```
解释：调用第三方工具分类的全部安装逻辑，安装 vim、cpcat、starship、bat、btop、tree、ripgrep、fd、fzf、ble.sh、yazi、fastfetch、ncdu、NextTrace、iperf3 等工具。

### 4.10 修改时区和本地语言

```bash
timedatectl set-timezone Asia/Shanghai
locale-gen
echo "LANG=en_US.UTF-8" > /etc/default/locale
```
解释：一键设置系统时区为中国/上海时区，本地语言为 `en_US.UTF-8`。

## 5. 系统工具

进入“系统工具”默认展示 1-20 号子选项，本身不修改系统。

### 5.1 设置脚本启动快捷键

```bash
find /usr/local/bin/ -type l -exec bash -c 'test "$(readlink -f {})" = "/usr/local/bin/d" && rm -f {}' \;
ln -sf /usr/local/bin/d /usr/local/bin/自定义快捷键
ln -sf /usr/local/bin/d /usr/bin/自定义快捷键
```
解释：清理旧快捷链接并创建新的快捷命令。

### 5.2 更换系统软件包镜像源

```bash
bash <(curl -sSL https://linuxmirrors.cn/main.sh)
```
解释：运行 linuxmirrors 脚本更换系统软件源。

### 5.3 优化 DNS 地址

默认展示：

```bash
cat /etc/resolv.conf
```
解释：显示当前 DNS 配置。

国外 DNS：

```bash
cp -L /etc/resolv.conf /etc/resolv.conf.daimon.bak
chattr -i /etc/resolv.conf
cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 2606:4700:4700::1111
nameserver 2001:4860:4860::8888
EOF
chattr +i /etc/resolv.conf
```
解释：写入 Cloudflare/Google DNS。

国内 DNS：

```bash
cp -L /etc/resolv.conf /etc/resolv.conf.daimon.bak
chattr -i /etc/resolv.conf
cat > /etc/resolv.conf <<EOF
nameserver 223.5.5.5
nameserver 119.29.29.29
nameserver 2400:3200::1
nameserver 2402:4e00::
EOF
chattr +i /etc/resolv.conf
```
解释：写入国内常用 DNS。

手动编辑：

```bash
apt install -y vim
cp -L /etc/resolv.conf /etc/resolv.conf.daimon.bak
chattr -i /etc/resolv.conf
vim /etc/resolv.conf
chattr +i /etc/resolv.conf
```
解释：用 vim 手动编辑 DNS。

恢复之前的 DNS 配置：

```bash
chattr -i /etc/resolv.conf
cat /etc/resolv.conf.daimon.bak > /etc/resolv.conf
```
解释：恢复脚本第一次修改 DNS 前备份的配置。如果没有备份，则写入 Ubuntu/systemd-resolved 常见本地 DNS：

```bash
cat > /etc/resolv.conf <<EOF
nameserver 127.0.0.53
options edns0 trust-ad
search .
EOF
```

### 5.4 切换优先 IPv4/IPv6

默认展示：

```bash
grep -Eq '^\s*precedence\s+::ffff:0:0/96\s+100\s*$' /etc/gai.conf
```
解释：判断当前是否 IPv4 优先。

```bash
echo 'precedence ::ffff:0:0/96 100' >> /etc/gai.conf
```
解释：设置 IPv4 优先。

```bash
rm -f /etc/gai.conf
```
解释：恢复默认 IPv6 优先。

```bash
bash /root/linux-daimon/daimon/jhb-v6.sh
```
解释：运行 IPv6 修复工具，来源 `https://jhb.ovh/jb/v6.sh`。

### 5.5 修改虚拟内存大小

默认展示：

```bash
free -m
```
解释：显示当前 Swap。

```bash
d swap 2048
```
解释：先验证大小和 `/root/linux-daimon/.swapfile-managed` inode 标记，再暂存新文件。停用失败不覆盖旧文件，新文件启用失败尝试恢复原文件及启用状态。已有但未标记的 `/swapfile` 不接管，不擦除其他 swap 文件或分区。

删除虚拟内存：

```bash
delete_swap
```
解释：菜单调用 `delete_swap`，只删除 inode 与归属标记一致的 `/swapfile`。`swapoff` 失败时不删文件、不改 fstab；其他 swap 保持不变。

### 5.6 用户管理

默认展示：

```bash
cat /etc/passwd
groups 用户名
sudo -n -lU 用户名
```
解释：列出用户、用户组、sudo 状态。

创建普通用户：

```bash
useradd -m -s /bin/bash 用户名
passwd 用户名
mkdir -p /home/用户名/.ssh
chmod 700 /home/用户名/.ssh
echo "公钥" >> /home/用户名/.ssh/authorized_keys
chmod 600 /home/用户名/.ssh/authorized_keys
chown -R 用户名:用户名 /home/用户名/.ssh
```
解释：创建普通用户并导入 SSH 公钥。

创建高级用户：

```bash
useradd -m -s /bin/bash 用户名
apt install -y sudo
usermod -aG sudo 用户名
cat > /etc/sudoers.d/用户名 <<EOF
用户名 ALL=(ALL:ALL) NOPASSWD:ALL
EOF
chmod 440 /etc/sudoers.d/用户名
visudo -cf /etc/sudoers.d/用户名
```
解释：创建用户并授予免密 sudo 权限。

赋予最高权限：

```bash
cat > /etc/sudoers.d/用户名 <<EOF
用户名 ALL=(ALL:ALL) NOPASSWD:ALL
EOF
chmod 440 /etc/sudoers.d/用户名
```
解释：写入 sudo 授权。

取消最高权限：

```bash
rm -f /etc/sudoers.d/用户名
sed -i "/^用户名\s*ALL=(ALL)/d" /etc/sudoers
```
解释：删除 sudo 授权。

删除账号：

```bash
userdel -r 用户名
```
解释：删除用户和家目录。

### 5.7 系统时区调整

默认展示：

```bash
timedatectl
```
解释：显示当前系统时间与时区。

```bash
timedatectl set-timezone Asia/Shanghai
timedatectl set-timezone Asia/Hong_Kong
timedatectl set-timezone Asia/Tokyo
timedatectl set-timezone Asia/Seoul
timedatectl set-timezone Asia/Singapore
timedatectl set-timezone Asia/Kolkata
timedatectl set-timezone Asia/Dubai
timedatectl set-timezone Australia/Sydney
timedatectl set-timezone Asia/Bangkok
timedatectl set-timezone Europe/London
timedatectl set-timezone Europe/Paris
timedatectl set-timezone Europe/Berlin
timedatectl set-timezone Europe/Moscow
timedatectl set-timezone Europe/Amsterdam
timedatectl set-timezone Europe/Madrid
timedatectl set-timezone America/Los_Angeles
timedatectl set-timezone America/New_York
timedatectl set-timezone America/Vancouver
timedatectl set-timezone America/Mexico_City
timedatectl set-timezone America/Sao_Paulo
timedatectl set-timezone America/Argentina/Buenos_Aires
timedatectl set-timezone UTC
```
解释：切换到对应时区。

### 5.8 修改主机名

```bash
hostname
echo "新主机名" > /etc/hostname
hostnamectl set-hostname "新主机名"
sed -i "s/127.0.0.1 .*/127.0.0.1       新主机名 localhost localhost.localdomain/g" /etc/hosts
sed -i "s/^::1 .*/::1             新主机名 localhost localhost.localdomain ipv6-localhost ipv6-loopback/g" /etc/hosts
```
解释：显示并修改主机名，同步 hosts。

### 5.9 本机 hosts 解析

```bash
cat /etc/hosts
echo "110.25.5.33 example.com" >> /etc/hosts
sed -i "/关键字/d" /etc/hosts
```
解释：查看、添加、删除 hosts 解析。

### 5.10 系统变量管理工具

```bash
printenv
echo "$PATH" | tr ':' '\n' | nl -ba
grep -E '^(export )?[A-Za-z_][A-Za-z0-9_]*=' ~/.bashrc ~/.profile /etc/environment
cat ~/.bashrc
cat ~/.profile
vim ~/.bashrc
vim ~/.profile
source ~/.bashrc
source ~/.profile
```
解释：查看、编辑、重新加载环境变量。

### 5.11 github镜像源

默认展示：

```bash
cat /root/linux-daimon/daimon/github_proxy_sources.txt
```
解释：显示当前镜像源列表。

```bash
echo "https://ghproxy.net" >> /root/linux-daimon/daimon/github_proxy_sources.txt
sed -i "编号d" /root/linux-daimon/daimon/github_proxy_sources.txt
curl -L --connect-timeout 4 --max-time 12 --retry 0 -o /tmp/daimon_proxy_test_xxx -w "%{http_code} %{time_total} %{speed_download} %{size_download}" -s "镜像后的测试URL"
rm -f /tmp/daimon_proxy_test_xxx
```
解释：添加、删除、测速 GitHub 镜像源，测速文件会删除。

### 5.12 查看 ssh 的 ip

```bash
echo "$SSH_CONNECTION" | awk '{print $1,$2}'
echo "$SSH_CLIENT" | awk '{print $1,$2}'
who | awk -F'[()]' '/\(/ {print $2}' | awk '{print $1}' | sort -u
ss -Htnp | awk '$1=="ESTAB" && $0 ~ /(sshd|ssh)/ {print $5}'
```
解释：查看当前 SSH 来源 IP、登录会话来源 IP、已建立 SSH 连接 IP。

### 5.13 网卡管理工具

默认展示：

```bash
ls /sys/class/net
cat /sys/class/net/网卡/operstate
ip -4 addr show 网卡
cat /sys/class/net/网卡/address
```
解释：列出网卡、状态、IPv4、MAC。

```bash
ip link set 网卡 up
ip link set 网卡 down
ip addr show 网卡
ip route
```
解释：启用网卡、禁用网卡、查看详情、查看路由。

### 5.14 journalctl日志管理

```bash
cp /etc/systemd/journald.conf /etc/systemd/journald.conf.bak.$(date +%Y%m%d%H%M%S)
cat > /etc/systemd/journald.conf <<EOF
[Journal]
SystemMaxUse=500M
SystemKeepFree=1G
SystemMaxFileSize=50M
MaxRetentionSec=1month
EOF
systemctl restart systemd-journald
```
解释：配置 journal 自动清理并重启 journald。

```bash
journalctl --disk-usage
journalctl -u nginx.service -n 200 --no-pager
journalctl --vacuum-time=7d
journalctl --vacuum-size=500M
```
解释：查看日志占用、服务日志、按时间清理、按大小清理。

### 5.15 系统网络自适应优化

默认展示：

```bash
sysctl -n net.ipv4.tcp_congestion_control
sysctl -n net.core.default_qdisc
[ -f /etc/sysctl.d/99-daimon-network-optimize.conf ]
tc qdisc show
```
解释：显示当前拥塞算法、队列算法、是否已安装自定义优化配置。

应用自定义网络优化：

```bash
cat > /etc/sysctl.d/99-daimon-bbr-fq.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
cat > /etc/sysctl.d/99-daimon-network-optimize.conf <<EOF
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.core.netdev_max_backlog=300000
net.ipv4.tcp_rmem=4096 131072 134217728
net.ipv4.tcp_wmem=4096 131072 134217728
fs.file-max=2097152
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_max_syn_backlog=262144
net.core.somaxconn=65535
net.ipv4.ip_local_port_range=1024 65535
vm.swappiness=10
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_limit_output_bytes=4194304
net.ipv4.tcp_mtu_probing=1
EOF
sysctl -p /etc/sysctl.d/99-daimon-bbr-fq.conf
sysctl -p /etc/sysctl.d/99-daimon-network-optimize.conf
```
解释：实际入口为 `daimon_network_apply_custom_optimize`，BBR/FQ 写入 `/etc/sysctl.d/99-daimon-bbr-fq.conf`，其他参数写入 `/etc/sysctl.d/99-daimon-network-optimize.conf`。应用前检查实际默认路由队列为 `fq` 或 `mq+fq`，不覆盖其他队列；失败恢复两个配置文件和逐项保存的运行态参数，回滚不完整时保留快照。已删除内核中无实际作用的 `tcp_low_latency`。

查看优化状态：

```bash
sysctl net.core.default_qdisc net.ipv4.tcp_congestion_control
modinfo tcp_bbr 2>/dev/null | grep -E '^(filename|version|description):'
```
解释：查看当前网络内核参数、BBR 模块信息和优化配置状态。

清除自定义网络优化：

```bash
rm -f /etc/sysctl.d/99-daimon-network-optimize.conf /etc/sysctl.d/99-network-optimize.conf
sysctl --system
```
解释：删除本脚本写入的网络优化配置。脚本也会顺手清理旧版本遗留的 qdisc 服务文件；部分运行态参数需要重启后完全恢复系统默认值。

### 5.16 禁用 IPv6

```bash
cat > /etc/sysctl.d/99-daimon-ipv6.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sysctl -p /etc/sysctl.d/99-daimon-ipv6.conf
for f in /proc/sys/net/ipv6/conf/*/disable_ipv6; do echo 1 > "$f"; done
ip -6 addr show scope global
```
解释：通过 sysctl 配置禁用 IPv6，并同步当前所有网卡的 IPv6 状态。

### 5.17 开启 IPv6

```bash
cat > /etc/sysctl.d/99-daimon-ipv6.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
EOF
sysctl -p /etc/sysctl.d/99-daimon-ipv6.conf
for f in /proc/sys/net/ipv6/conf/*/disable_ipv6; do echo 0 > "$f"; done
ip -6 addr show scope global
```
解释：通过 sysctl 配置开启 IPv6，并同步当前所有网卡的 IPv6 状态。

### 5.18 设置本地语言

```bash
apt install -y locales
sed -i 's/^[[:space:]]*#\?[[:space:]]*en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/default/locale
```
解释：设置本地语言。菜单中 `1` 是 `en_US.UTF-8`，`2` 是 `zh_CN.UTF-8`，并包含中文繁体、日文、韩文、德文、法文、西班牙文、俄文等常用 UTF-8 locale。

### 5.19 Docker 镜像源测速

默认镜像源：

```bash
https://hub.333186.xyz
https://docker.m.daocloud.io
https://docker.1ms.run
https://docker.registry.cyou
```

测速命令核心：

```bash
timeout 100s docker pull 镜像源域名/library/python:3.12-slim
docker image inspect -f '{{.Size}}' 镜像源域名/library/python:3.12-slim
docker image rm -f 镜像源域名/library/python:3.12-slim
docker image prune -f
```
解释：支持测速默认镜像源、第三方镜像源、第三方+默认镜像源；三种模式都会询问是否加入官方镜像源 `https://registry-1.docker.io`。默认超时时间 100 秒，默认测速 1 轮。每次测速前后会删除测试镜像引用并清理 dangling 镜像，避免后续镜像源直接复用测试残留导致结果异常偏快；如果本机原本已有相同镜像层缓存，测速仍可能偏快。

### 5.20 卸载 daimon 脚本

```bash
rm -f /usr/local/bin/d /usr/bin/d ~/daimon.sh
```
解释：删除脚本和快捷命令，不影响其他已安装服务。

## 6. 第三方工具

第三方工具默认展示每个工具编号、说明、是否已安装，当前顺序为：

1. vim
2. cpcat
3. Ctrl+D
4. starship
5. bat
6. btop
7. tree
8. ripgrep
9. fd
10. fzf
11. ble.sh
12. yazi
13. fastfetch
14. ncdu
15. NextTrace
16. iperf3

```bash
command -v 工具名
grep -qxF 'export EDITOR=vim' ~/.bashrc
grep -q '^# ========== cpcat clipboard setup ==========$' ~/.bashrc
grep -q '^# ==================== Ctrl+D 改为删除下一个单词 ====================$' ~/.bashrc
command -v starship
command -v batcat || command -v bat
command -v btop
command -v tree
command -v rg
command -v fd || command -v fdfind
test -x /root/linux-daimon/tools/fzf/bin/fzf
grep -q '^# ========== fzf 核心配置 ==========$' ~/.bashrc
test -f ~/.local/share/blesh/ble.sh
grep -q '^# ========== ble.sh setup ==========$' ~/.bashrc
command -v yazi
command -v fastfetch
command -v ncdu
command -v nexttrace
command -v iperf3
```
解释：判断第三方工具是否存在。

菜单操作：

```bash
apt install -y 工具名
apt purge -y 工具名
read -e -i "1 2 3 ... 最后编号" -p "请确认/修改要安装或卸载的工具编号: " nums
```
解释：安装/卸载当前分类中选择的工具，支持多选；“全部安装 / 全部卸载”会先预填当前分类的全部编号，执行前可手动删除不需要的编号。

第三方工具安装核心命令：

```bash
apt install -y vim
echo 'export EDITOR=vim' >> ~/.bashrc
echo 'export VISUAL=vim' >> ~/.bashrc
cat >> ~/.bashrc <<'EOF'
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
cat >> ~/.bashrc <<'EOF'
# ==================== Ctrl+D 改为删除下一个单词 ====================
bind '"\C-d": kill-word'
# ==================== end Ctrl+D 改为删除下一个单词 ====================
EOF
source ~/.bashrc
# 国外机器：
curl -sS https://starship.rs/install.sh | sh -s -- -y
# 国内机器：
cd /tmp
curl -L --retry 5 -o starship.tar.gz https://gh-proxy.com/https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz
tar -xzf starship.tar.gz
install -m 755 starship /usr/local/bin/starship
cat >> ~/.bashrc <<'EOF'
# ========== starship prompt setup ==========
eval "$(starship init bash)"
# ========== end starship prompt setup ==========
EOF
cat >> ~/.zshrc <<'EOF'
# ========== starship prompt setup ==========
eval "$(starship init zsh)"
# ========== end starship prompt setup ==========
EOF
mkdir -p ~/.config
vim ~/.config/starship.toml
apt install -y bat btop
cat > ~/.bat.sh <<'EOF'
# 写入 bauto、blog、byaml、bjson、bhttp、raw 以及 docker/ping/systemctl/git 等查看类命令包装函数
EOF
cat >> ~/.bashrc <<'EOF'
# ========== bat 终端着色增强 ==========
if [ -f ~/.bat.sh ]; then
    source ~/.bat.sh
fi
EOF
apt install -y tree ripgrep fd-find ncdu
apt install -y iperf3
curl -sS https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg
echo "deb https://debian.griffo.io/apt $(lsb_release -sc 2>/dev/null) main" | tee /etc/apt/sources.list.d/debian.griffo.io.list >/dev/null
apt update -y
apt install -y yazi
add-apt-repository -y ppa:zhangsongcui3371/fastfetch
apt update -y
apt install -y fastfetch
install -d -m 0755 /etc/apt/keyrings
curl -fsSL -o /tmp/nexttrace-archive-keyring.gpg https://github.com/nxtrace/nexttrace-debs/releases/latest/download/nexttrace-archive-keyring.gpg
install -m 0644 /tmp/nexttrace-archive-keyring.gpg /etc/apt/keyrings/nexttrace.gpg
rm -f /tmp/nexttrace-archive-keyring.gpg
printf '%s\n' 'Types: deb' 'URIs: https://github.com/nxtrace/nexttrace-debs/releases/latest/download/' 'Suites: ./' 'Signed-By: /etc/apt/keyrings/nexttrace.gpg' | tee /etc/apt/sources.list.d/nexttrace.sources >/dev/null
apt update -y
apt install -y nexttrace
echo "alias fd='fdfind'" >> ~/.bashrc
git clone --depth 1 https://github.com/junegunn/fzf.git /root/linux-daimon/tools/fzf
/root/linux-daimon/tools/fzf/install --key-bindings --completion --no-update-rc
cat >> ~/.bashrc <<'EOF'
# ========== fzf 核心配置 ==========
[ -d "/root/linux-daimon/tools/fzf/bin" ] && export PATH="/root/linux-daimon/tools/fzf/bin:$PATH"
if command -v fzf >/dev/null 2>&1; then
  if command -v fdfind >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fdfind --type f --strip-cwd-prefix --hidden --follow --exclude .git'
  elif command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
  fi
  # 省略：bat/batcat 预览、Ctrl+T、Alt+C 配置
fi
# ========== end fzf 核心配置 ==========
EOF
git clone --recursive https://github.com/akinomyoga/ble.sh.git ~/ble.sh
cd ~/ble.sh
apt update -y && apt install -y make
make install
cat >> ~/.bashrc <<'EOF'
# ========== ble.sh setup ==========
[ -f ~/.local/share/blesh/ble.sh ] && source ~/.local/share/blesh/ble.sh
# ========== end ble.sh setup ==========
EOF
cat > ~/.blerc <<'EOF'
# 自动补全
bleopt complete_auto_complete=1
# history 自动补全
bleopt complete_auto_history=1
# 使用fzf的快捷键
if command -v fzf >/dev/null 2>&1 || [ -x "/root/linux-daimon/tools/fzf/bin/fzf" ]; then
   ble-import -d integration/fzf-key-bindings
 fi
EOF
exec bash
```
解释：安装第三方常用工具；安装过程中不再直接 `source ~/.bashrc`，避免 ble.sh 重复加载导致 TTY 异常，安装完成后统一 `exec bash` 重新进入命令行；vim 会同时设置 `EDITOR=vim` 和 `VISUAL=vim`；cpcat、Ctrl+D、starship、bat 通过写入 `~/.bashrc` 或配置文件完成；btop、tree、ripgrep、fd、ncdu、iperf3 使用 apt 安装；yazi 通过 `debian.griffo.io` apt 源安装；fastfetch 在 Ubuntu 下先添加 `ppa:zhangsongcui3371/fastfetch` 再安装；NextTrace 通过官方 apt 源安装；Ubuntu 上 fd 对应包名通常是 fd-find，脚本会在 `~/.bashrc` 中补充 `alias fd='fdfind'`；fzf 使用 git clone 安装到 `/root/linux-daimon/tools/fzf`，并在缺少 fd/bat/tree 时自动安装依赖；fzf 配置会自动兼容 `fd/fdfind`、`bat/batcat`，没有 bat 时回退到 `sed`，没有 tree 时回退到 `ls`；ble.sh 会写入 `~/.bashrc` 和 `~/.blerc`，并自动清理旧的重复 `source ~/.local/share/blesh/ble.sh`，保证 ble.sh 配置块位于 `.bashrc` 末尾。

特殊卸载：

```bash
sed -i '/^export EDITOR=vim$/d;/^export VISUAL=vim$/d' ~/.bashrc
# 删除 ~/.bashrc 中 cpcat clipboard setup 配置块
# 删除 ~/.bashrc 中 Ctrl+D 改为删除下一个单词配置块
# 删除 ~/.bashrc / ~/.zshrc 中 starship prompt setup 配置块
rm -f ~/.config/starship.toml /root/linux-daimon/daimon/starship-install.sh /usr/local/bin/starship /usr/bin/starship ~/.local/bin/starship ~/.cargo/bin/starship
rm -f ~/.bat.sh
# 删除 ~/.bashrc 中 fzf 核心配置块
rm -rf /root/linux-daimon/tools/fzf
# 删除 ~/.bashrc 中 ble.sh setup 配置块
rm -rf ~/ble.sh ~/.local/share/blesh ~/.blerc
rm -rf ~/.config/btop ~/.config/yazi ~/.local/share/yazi ~/.cache/yazi ~/.config/fastfetch
rm -f /etc/apt/sources.list.d/debian.griffo.io.list /etc/apt/trusted.gpg.d/debian.griffo.io.gpg
rm -f /etc/apt/keyrings/nexttrace.gpg /etc/apt/sources.list.d/nexttrace.sources
add-apt-repository --remove -y ppa:zhangsongcui3371/fastfetch
apt purge -y vim bat batcat btop tree ripgrep fd-find fzf yazi fastfetch ncdu nexttrace iperf3
sed -i "/^alias fd='fdfind'$/d;/^alias fd=fdfind$/d;/^alias fd=\"fdfind\"$/d" ~/.bashrc
```
解释：卸载第三方工具第 1-16 项的 apt 包、git clone 目录、apt 源和脚本写入的配置。

## 7. 编程工具

编程工具默认展示每个工具编号、说明、是否已安装，当前顺序为：

1. python
2. npm
3. nodejs
4. bun
5. uv
6. git
7. ClaudeCode
8. Codex

```bash
command -v python3.12
python --version | grep '^Python 3\.12\.'
command -v npm
command -v node
command -v bun
command -v uv
command -v git
command -v claude
command -v codex
```
解释：判断编程工具是否存在。

菜单操作：

```bash
apt install -y 工具名
apt purge -y 工具名
read -e -i "1 2 3 ... 最后编号" -p "请确认/修改要安装或卸载的工具编号: " nums
```
解释：安装/卸载当前分类中选择的工具，支持多选；“全部安装 / 全部卸载”会先预填当前分类的全部编号，执行前可手动删除不需要的编号。

编程工具安装核心命令：

```bash
apt update -y
apt install -y python3.12 python3.12-venv python3.12-dev python3-pip
# 如果当前软件源没有 python3.12：
apt install -y software-properties-common
add-apt-repository -y ppa:deadsnakes/ppa
apt update -y
apt install -y python3.12 python3.12-venv python3.12-dev python3-pip
update-alternatives --install /usr/local/bin/python daimon-python /usr/bin/python3.12 312
update-alternatives --set daimon-python /usr/bin/python3.12
python3.12 --version
python --version

# npm / nodejs：国外使用官方 nvm，国内使用 nvm-cn，然后安装 LTS
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash
bash -c "$(curl -fsSL https://gitee.com/RubyMetric/nvm-cn/raw/main/install.sh)"
. ~/.nvm/nvm.sh
nvm install --lts
nvm alias default lts/*

apt install -y git
bash /root/linux-daimon/daimon/bun-install.sh
bash /root/linux-daimon/daimon/uv-install.sh

# ClaudeCode：国外官方脚本，国内 npm 镜像源
curl -fsSL https://claude.ai/install.sh | bash
npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com
claude update
claude --version

# Codex：不区分国内国外
npm install -g @openai/codex@latest
codex --version
```
解释：安装 Python 3.12、Node/npm、Bun、uv、Git、ClaudeCode、Codex。Python 默认安装 3.12、venv、dev 包和 pip；软件源没有 Python 3.12 时添加 `ppa:deadsnakes/ppa` 后重试；脚本只将 `python` 指向 `/usr/bin/python3.12`，不强改系统 `python3`，避免影响系统组件。npm/nodejs 统一通过 nvm 安装 LTS；ClaudeCode 按 CN/非 CN 分流；Codex 不分流；ClaudeCode 写入 `~/.claude/settings.json`，Codex 写入 `~/.codex/config.toml`。

## 8. Docker 管理

进入 Docker 管理默认展示：

```bash
docker ps -a -q | wc -l
docker images -q | wc -l
docker network ls -q | wc -l
docker volume ls -q | wc -l
```
解释：统计容器、镜像、网络、卷数量。

### 8.1 安装更新 Docker 环境

```bash
bash /root/linux-daimon/daimon/linuxmirrors-docker.sh --source mirrors.huaweicloud.com/docker-ce --source-registry docker.1ms.run --protocol http --use-intranet-source false --install-latest true --close-firewall false --ignore-backup-tips
apt install -y docker docker-compose
systemctl enable docker
systemctl start docker
systemctl restart docker
```
解释：优先通过 linuxmirrors 安装 Docker，失败时用包管理器兜底安装。

### 8.2 查看 Docker 全局状态

```bash
docker -v
docker compose version
docker image ls
docker ps -a
docker volume ls
docker network ls
```
解释：查看 Docker 版本、镜像、容器、卷、网络。

### 8.3 Docker 容器管理

默认展示：

```bash
docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
```
解释：显示容器列表。

```bash
docker run ...
docker start 容器名
docker stop 容器名
docker rm -f 容器名
docker restart 容器名
docker start $(docker ps -a -q)
docker stop $(docker ps -q)
docker rm -f $(docker ps -a -q)
docker restart $(docker ps -q)
```
解释：创建容器、启动/停止/删除/重启指定容器或全部容器。

```bash
docker exec -it 容器名 /bin/sh
docker logs 容器名
docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' 容器ID
docker stats --no-stream
```
解释：进入容器、查看日志、查看容器网络、查看资源占用。

```bash
docker port 容器名
iptables -I INPUT -p tcp --dport 端口 -j ACCEPT
iptables -I INPUT -p udp --dport 端口 -j ACCEPT
iptables -I INPUT -p tcp --dport 端口 -j DROP
iptables -I INPUT -p udp --dport 端口 -j DROP
```
解释：读取容器映射端口，并开放或关闭端口访问。

### 8.4 Docker 镜像管理

默认展示：

```bash
docker image ls
```
解释：显示镜像列表。

```bash
docker pull 镜像名
docker rmi -f 镜像名
docker rmi -f $(docker images -q)
```
解释：获取/更新镜像、删除指定镜像、删除全部镜像。

### 8.5 Docker 网络管理

默认展示：

```bash
docker network ls
docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' 容器ID
```
解释：显示 Docker 网络和容器 IP。

```bash
docker network create 网络名
docker network connect 网络名 容器名
docker network disconnect 网络名 容器名
docker network rm 网络名
```
解释：创建网络、加入网络、退出网络、删除网络。

### 8.6 Docker 卷管理

默认展示：

```bash
docker volume ls
```
解释：显示 Docker 卷。

```bash
docker volume create 卷名
docker volume rm 卷名
docker volume prune -f
```
解释：创建卷、删除指定卷、清理未使用卷。

### 8.7 清理无用 Docker 数据

```bash
docker system prune -af --volumes
```
解释：清理停止容器、无用镜像、网络、卷。

### 8.8 更换 Docker 源

默认回车写入 4 个镜像源：

```json
{
  "registry-mirrors": [
    "https://hub.333186.xyz",
    "https://docker.m.daocloud.io",
    "https://docker.1ms.run",
    "https://docker.registry.cyou"
  ]
}
```

```bash
mkdir -p /etc/docker
cat > /etc/docker/daemon.json
systemctl restart docker
```
解释：写入 Docker daemon 镜像源并重启 Docker。

### 8.9 编辑 daemon.json 文件

```bash
mkdir -p /etc/docker
vim /etc/docker/daemon.json
systemctl restart docker
```
解释：手动编辑 Docker daemon 配置并重启。

### 8.10 Docker Compose 自动更新

默认展示：

```bash
docker ps -a --format '{{.Names}}'
docker inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}|{{ index .Config.Labels "com.docker.compose.project.working_dir" }}|{{ index .Config.Labels "com.docker.compose.project.config_files" }}' 容器名
crontab -l
```
解释：自动扫描所有 Docker 容器，读取项目名、工作目录和完整 Compose 配置文件列表，按实际 Compose 项目去重展示；同时检查生成脚本的语法、任务标识和 crontab。旧版脚本会显示“需重新安装”，已删除项目残留的脚本或 cron 会单独列出。

安装自动更新：

```bash
mkdir -p /root/linux-daimon/docker-compose-update /var/log/docker-compose-update
docker compose -p 项目名 -f /项目路径/docker-compose.yml pull --ignore-buildable 运行服务...
docker compose -p 项目名 -f /项目路径/docker-compose.yml up -d --no-deps --wait --wait-timeout 120 运行服务...
```
解释：以上命令由脚本自动生成，不需要手工执行。任务文件名使用项目名和项目身份哈希，避免路径清理后的同名覆盖；项目名和全部 `-f` 配置会被保留。执行时使用独立锁并读取当前运行服务；没有运行服务时跳过，避免重新启动用户主动停止的项目。任务先保存旧镜像 ID，再拉取和启动，不会预先停止容器。拉取失败时保持现有容器运行；启动或健康检查失败且旧镜像完整可用时自动恢复，并以非零状态退出。定时任务按项目编号错开执行，日志由 `/etc/logrotate.d/docker-compose-update` 每天轮转，保留 14 份，单文件上限 10 MB。

卸载自动更新：

```bash
rm -f /root/linux-daimon/docker-compose-update/compose_update_项目名_项目哈希.sh
crontab -l 2>/dev/null | grep -vF "/root/linux-daimon/docker-compose-update/compose_update_项目名_项目哈希.sh" | crontab -
```
解释：菜单卸载会先原子更新 crontab，再删除新版和对应旧版脚本；“清理失效任务”用于删除已经无法从 Docker 标签发现的项目残留任务。

### 8.11 开启 Docker IPv6 访问

```bash
jq '. + {ipv6: true, "fixed-cidr-v6": "2001:db8:1::/64"}' /etc/docker/daemon.json > /etc/docker/daemon.json.tmp
mv /etc/docker/daemon.json.tmp /etc/docker/daemon.json
systemctl restart docker
```
解释：启用 Docker IPv6 配置。

### 8.12 关闭 Docker IPv6 访问

```bash
jq 'del(.["fixed-cidr-v6"]) | .ipv6 = false' /etc/docker/daemon.json > /etc/docker/daemon.json.tmp
mv /etc/docker/daemon.json.tmp /etc/docker/daemon.json
systemctl restart docker
```
解释：关闭 Docker IPv6 配置。

### 8.19 备份/迁移/还原 Docker 环境

默认展示：

```bash
ls -1dt /tmp/docker_backup_* 2>/dev/null
```
解释：显示已有备份。

```bash
docker ps --format '{{.Names}}'
docker inspect 容器名 > /tmp/docker_backup_时间/容器名_inspect.json
tar -czf /tmp/docker_backup_时间/compose_project_项目名.tar.gz -C compose目录 .
tar -czpf /tmp/docker_backup_时间/容器名_卷名.tar.gz -C / 卷路径
```
解释：备份容器 inspect、compose 目录、挂载卷。

```bash
tar -czf /tmp/docker_backup_xxx.tar.gz /tmp/docker_backup_xxx
scp -P SSH端口 -o StrictHostKeyChecking=no -r /tmp/docker_backup_xxx.tar.gz 用户@目标IP:/tmp/
```
解释：迁移备份到目标服务器。

```bash
tar -xzf compose_project_项目名.tar.gz -C 原目录
cd 原目录 && docker compose down && docker compose up -d
docker run -d --name 容器名 -p 主机端口:容器端口 -v 主机路径:容器路径 -e 环境变量 镜像
```
解释：还原 compose 项目或普通容器。

```bash
rm -rf /tmp/docker_backup_时间
```
解释：删除备份目录。

### 8.20 卸载 Docker 环境

```bash
docker ps -a -q | xargs -r docker rm -f
docker images -q | xargs -r docker rmi
docker network prune -f
docker volume prune -f
apt purge -y docker docker-compose docker-ce docker-ce-cli containerd.io
rm -f /etc/docker/daemon.json
```
解释：删除 Docker 数据并卸载 Docker。

## 9. SSH 管理

进入 SSH 配置默认展示：

```bash
ss -tlnp | awk '/sshd/ {print $4}'
sshd -T | awk '$1 == "passwordauthentication" {print $2}'
sshd -T | awk '$1 == "pubkeyauthentication" {print $2}'
```
解释：显示当前 SSH 端口、密码登录状态、密钥登录状态。

### 9.1 修改 SSH 端口

```bash
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)
sed -i 's|^[#[:space:]]*Port[[:space:]].*|Port 64400|' /etc/ssh/sshd_config
sshd -t
systemctl stop ssh.socket sshd.socket
systemctl disable ssh.socket sshd.socket
systemctl restart sshd || systemctl restart ssh
ufw allow 64400/tcp
```
解释：备份配置、修改端口、校验配置、重启 SSH、放行新端口。

### 9.2 禁用/开启密码登录

```bash
sed -i 's|^[#[:space:]]*PasswordAuthentication[[:space:]].*|PasswordAuthentication no|' /etc/ssh/sshd_config
sed -i 's|^[#[:space:]]*KbdInteractiveAuthentication[[:space:]].*|KbdInteractiveAuthentication no|' /etc/ssh/sshd_config
sed -i 's|^[#[:space:]]*ChallengeResponseAuthentication[[:space:]].*|ChallengeResponseAuthentication no|' /etc/ssh/sshd_config
sed -i 's|^[#[:space:]]*PermitEmptyPasswords[[:space:]].*|PermitEmptyPasswords no|' /etc/ssh/sshd_config
sshd -t && systemctl restart sshd
```
解释：关闭密码和交互式认证。

```bash
sed -i 's|^[#[:space:]]*PasswordAuthentication[[:space:]].*|PasswordAuthentication yes|' /etc/ssh/sshd_config
sed -i 's|^[#[:space:]]*KbdInteractiveAuthentication[[:space:]].*|KbdInteractiveAuthentication yes|' /etc/ssh/sshd_config
sed -i 's|^[#[:space:]]*ChallengeResponseAuthentication[[:space:]].*|ChallengeResponseAuthentication yes|' /etc/ssh/sshd_config
sshd -t && systemctl restart sshd
```
解释：开启密码登录。

### 9.3 开启/禁用密钥登录

```bash
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "你的公钥" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
sed -i 's|^[#[:space:]]*PubkeyAuthentication[[:space:]].*|PubkeyAuthentication yes|' /etc/ssh/sshd_config
sed -i 's|^[#[:space:]]*AuthorizedKeysFile[[:space:]].*|AuthorizedKeysFile .ssh/authorized_keys|' /etc/ssh/sshd_config
sshd -t && systemctl restart sshd
```
解释：写入公钥并开启密钥登录。

```bash
sed -i 's|^[#[:space:]]*PubkeyAuthentication[[:space:]].*|PubkeyAuthentication no|' /etc/ssh/sshd_config
sshd -t && systemctl restart sshd
```
解释：禁用密钥登录。

### 9.4 一键配置

```bash
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "你的公钥" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
sed -i 's|^[#[:space:]]*Port[[:space:]].*|Port 64400|' /etc/ssh/sshd_config
sed -i 's|^[#[:space:]]*PubkeyAuthentication[[:space:]].*|PubkeyAuthentication yes|' /etc/ssh/sshd_config
sed -i 's|^[#[:space:]]*AuthorizedKeysFile[[:space:]].*|AuthorizedKeysFile .ssh/authorized_keys|' /etc/ssh/sshd_config
sed -i 's|^[#[:space:]]*PasswordAuthentication[[:space:]].*|PasswordAuthentication no|' /etc/ssh/sshd_config
sed -i 's|^[#[:space:]]*PermitRootLogin[[:space:]].*|PermitRootLogin prohibit-password|' /etc/ssh/sshd_config
sshd -t && systemctl restart sshd
apt install -y ufw
ufw allow 64400/tcp
yes | ufw delete allow 22/tcp
ufw deny 22/tcp
ufw --force enable
ufw reload
```
解释：端口改为 64400、关闭密码、开启密钥、root 只允许密钥、UFW 放行新端口并关闭 22。

### 9.5 公钥和私钥管理

默认展示：

```bash
nl -ba /root/.ssh/authorized_keys
find /root/.ssh -maxdepth 1 -type f ! -name '*.pub' ! -name 'authorized_keys' ! -name 'known_hosts' ! -name 'config' -printf '%f\n' | nl -ba
```
解释：显示公钥和私钥文件。

```bash
echo "你的公钥" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
sed -i '行号d' /root/.ssh/authorized_keys
cat > /root/.ssh/id_ed25519
chmod 600 /root/.ssh/id_ed25519
rm -f /root/.ssh/私钥文件名
```
解释：添加公钥、删除公钥、添加私钥、删除私钥。

### 9.6 修改 sshd_config 配置文件

```bash
vim /etc/ssh/sshd_config
sshd -t && systemctl restart sshd
```
解释：手动编辑 SSH 服务端配置，并校验重启。

## 10. UFW 管理

默认展示：

```bash
ufw status | head -n 12
```
解释：显示 UFW 当前状态。

```bash
apt install -y ufw
ufw --force enable
ufw status
```
解释：安装并启用 UFW。

```bash
ufw disable
apt purge -y ufw
```
解释：禁用并卸载 UFW。

```bash
ufw allow 80
ufw allow 80/tcp
ufw status numbered
```
解释：开放端口。

```bash
ufw delete allow 80
ufw delete allow 80/tcp
ufw status numbered
```
解释：删除端口 allow 规则。

## 11. Nginx + 域名管理

进入菜单前会确保 acme.sh：

```bash
apt install -y curl socat lsof dnsutils ufw openssl nginx
(set -o pipefail; curl -fsSL --connect-timeout 10 --max-time 300 https://get.acme.sh | sh -s email=asdad@163.com)
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
```
解释：安装依赖、安装 acme.sh，并设置默认 CA。依赖、下载、安装或 CA 配置失败均停止；不会执行用户的 shell 初始化文件。仅进入或返回 Nginx 菜单不会安装依赖。

默认菜单：1 申请证书+配置 nginx；2 删除 nginx 配置+证书；3 申请证书；4 移除证书；5 查看证书列表；6 配置 nginx；7 删除 nginx 配置；8 创建测试页面；9 删除测试页面；10 安装 nginx；11 备份域名+nginx 配置；12 恢复域名+nginx 配置；13 迁移/修复现有证书（webroot）。进入菜单只显示域名备份脚本是否开启；安装 Nginx、申请证书或配置 Nginx 时会自动开启本地单份备份脚本。

申请证书（webroot 模式，不停止 Nginx）：

```bash
dig +short example.com A
dig +short example.com AAAA
ufw allow 80/tcp
ufw allow 443/tcp
mkdir -p /var/www/acme-challenge/.well-known/acme-challenge
~/.acme.sh/acme.sh --issue -d example.com -w /var/www/acme-challenge --server letsencrypt --force
~/.acme.sh/acme.sh --install-cert -d example.com --fullchain-file /root/domain/example/fullchain.pem --key-file /root/domain/example/privkey.pem --reloadcmd "nginx -t && systemctl reload nginx" --force
```
解释：检查 DNS、确保 Nginx 的 `/.well-known/acme-challenge/` 指向 webroot、申请并安装证书；不会停止 Nginx 或杀死端口占用进程。

自动续期：

```bash
(crontab -l 2>/dev/null | grep -vF 'acme.sh --cron' | grep -vF '/root/linux-daimon/cert-renew.sh' ; echo "0 3 * * * /bin/bash /root/linux-daimon/cert-renew.sh >> /var/log/acme.sh/renew.log 2>&1") | crontab -
```
解释：每天凌晨 3 点执行带锁的 webroot 续期包装脚本，日志保留在 `/var/log/acme.sh/renew.log`；失败会记录到系统日志并返回非零状态。

迁移现有证书时，脚本先备份 `/root/.acme.sh`、`/root/domain` 和 Nginx 站点配置，再为每个域名加入并实际验证 challenge 路径。重新签发成功后仍安装到当前 Nginx 正在读取的证书目录，不会因为历史目录使用域名前缀而切换到错误路径；通配符、无效域名或无法安全修改的自定义配置会跳过。

配置 Nginx：

```bash
apt install -y nginx
systemctl start nginx
systemctl enable nginx
systemctl is-active --quiet nginx
cat > /etc/nginx/sites-available/配置名
ln -sf /etc/nginx/sites-available/配置名 /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```
解释：生成 Nginx 配置并重载。HTTP 配置会先放行 `/.well-known/acme-challenge/` 到 `/var/www/acme-challenge`，再跳转 HTTPS；HTTPS 配置包括 `listen 443 ssl http2`、`ssl_certificate`、`proxy_pass http://127.0.0.1:端口`。申请证书 + 配置 nginx 如果失败，会自动删除本次生成的证书目录、acme 记录和 nginx 配置。

删除 nginx 配置 + 证书：

```bash
rm -f /etc/nginx/sites-available/配置名 /etc/nginx/sites-enabled/配置名
rm -rf /root/domain/example
~/.acme.sh/acme.sh --remove -d example.com
nginx -t && systemctl reload nginx
```
解释：删除站点配置、证书目录和 acme 记录。

查看/移除证书：

```bash
~/.acme.sh/acme.sh --list
ls -la /root/domain/
~/.acme.sh/acme.sh --remove -d example.com
rm -rf /root/domain/example
```
解释：查看证书列表或移除指定证书。

测试页面：

```bash
mkdir -p /var/www/测试名
cat > /var/www/测试名/index.html
cat > /etc/nginx/sites-available/测试名
ln -sf /etc/nginx/sites-available/测试名 /etc/nginx/sites-enabled/
nginx -t && nginx -s reload
curl http://127.0.0.1:端口
rm -f /etc/nginx/sites-enabled/测试名 /etc/nginx/sites-available/测试名
rm -rf /var/www/测试名
nginx -t && nginx -s reload
```
解释：先校验测试名称和端口，拒绝已有目录、已有配置及符号链接目标。创建成功后写入 `.daimon-test-page` 归属标记；删除前再次核对标记和真实路径，仅删除本脚本的测试目录，未标记的历史页面和业务目录不会自动删除。启动、重载或文件操作失败不报告成功。

备份/恢复域名和 Nginx 配置：

```bash
mkdir -p /root/linux-daimon/backup/nginx-domain
find /root/domain -mindepth 2 -maxdepth 2 -type f -name fullchain.pem -size +0c -print -quit | grep -q . || exit 0
rm -rf /root/linux-daimon/backup/nginx-domain/auto_latest.tmp
mkdir -p /root/linux-daimon/backup/nginx-domain/auto_latest.tmp
cp -a /etc/nginx/sites-available /root/linux-daimon/backup/nginx-domain/auto_latest.tmp/
cp -a /root/domain /root/linux-daimon/backup/nginx-domain/auto_latest.tmp/
find /etc/nginx/sites-enabled -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort > /root/linux-daimon/backup/nginx-domain/auto_latest.tmp/enabled_sites.txt
rm -rf /root/linux-daimon/backup/nginx-domain/auto_latest
mv /root/linux-daimon/backup/nginx-domain/auto_latest.tmp /root/linux-daimon/backup/nginx-domain/auto_latest
```
解释：手动备份和自动备份都只保留 `/root/linux-daimon/backup/nginx-domain/auto_latest` 这一份；备份只保存 `sites-available`、`/root/domain` 和 enabled 站点名称。恢复时合并 `sites-available` 与 `/root/domain`，再重建 `sites-enabled` 软链接，同名文件保留本机现有版本，恢复后执行 `nginx -t` 并重载 nginx。只有检测到 `/root/domain/*/fullchain.pem` 时才刷新备份；无域名时跳过备份并保留已有 `auto_latest`。

## 12. fail2ban 管理

进入 fail2ban 管理默认展示：当前 SSH 实际端口、`fail2ban-client status sshd` 或服务状态。

安装并自动配置 sshd：

```bash
apt-get update -y
apt-get install -y fail2ban
systemctl start fail2ban
systemctl enable fail2ban
ss -tlnp | awk '/sshd/ {print $4}'
sshd -T | awk '$1=="port"{print $2}'
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.bak.$(date +%Y%m%d%H%M%S)
```
解释：安装 Fail2ban、启动并设置开机自启；SSH 端口不是写死 64400，而是优先从当前 sshd 监听端口读取，失败时再读 `sshd -T` 和 `/etc/ssh/sshd_config`，最后默认 22。

写入 `/etc/fail2ban/jail.local` 的 sshd 核心配置：

```ini
[sshd]
enabled = true
port = 当前SSH端口
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
findtime = 600
```
解释：脚本会重写 `jail.local` 里的 `[sshd]` 段；Ubuntu 默认日志使用 `/var/log/auth.log`，如果不存在会尝试 `/var/log/secure` 或 Fail2ban 默认 `%(sshd_log)s`。

配置检查和重载：

```bash
fail2ban-client -t
systemctl restart fail2ban
fail2ban-client status sshd
```
解释：校验 Fail2ban 配置，重启服务并查看 sshd jail 状态。

卸载 Fail2ban：

```bash
systemctl stop fail2ban
systemctl disable fail2ban
apt purge -y fail2ban
rm -rf /etc/fail2ban /var/lib/fail2ban /var/log/fail2ban.log
```
解释：停止服务、取消开机自启、卸载软件包并删除配置与状态目录。

检查 sshd 配置：

```bash
sshd -T | awk '$1=="port"{print $2}'
ss -tlnp | awk '/sshd/ {print $4}'
awk '/^\[sshd\]/{flag=1;next}/^\[/{flag=0}flag && /^port[[:space:]]*=/{print}' /etc/fail2ban/jail.local
fail2ban-client -t
systemctl restart fail2ban
```
解释：对比当前 SSH 实际端口和 Fail2ban `[sshd]` 的 `port`；如果不一致，自动把 Fail2ban sshd 端口修正为当前 SSH 端口。

## 13. BBR 管理

```bash
apt install -y wget curl
mkdir -p /root/linux-daimon/daimon
curl -fsSL https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcpx.sh -o /root/linux-daimon/daimon/tcpx.sh
chmod +x /root/linux-daimon/daimon/tcpx.sh
bash /root/linux-daimon/daimon/tcpx.sh
```
解释：下载并运行 `tcpx.sh`，进入 BBR/加速管理菜单。

## 14. WARP 管理

进入 WARP 管理默认展示：是否存在 `warp` 快捷命令、是否存在 `warp` 网络接口。

进入 WARP 官方管理脚本：

```bash
apt install -y wget curl
bash /root/linux-daimon/daimon/warp-menu.sh
```
解释：下载并运行 fscarmen WARP 菜单脚本，来源 `https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh`。

彻底删除 WARP：

```bash
apt install -y wget curl
bash /root/linux-daimon/daimon/warp-menu.sh u
```
解释：调用 fscarmen 脚本的 `warp u` 逻辑，永久关闭并删除 WARP 网络接口、WARP Linux Client 和 WireProxy。

## 15. rclone 管理

进入 rclone 管理默认展示：

```bash
rclone --version
ls -l /root/.config/rclone/rclone.conf
```
解释：显示版本、配置路径及各 remote 的名称、类型、读取验证状态。使用隔离配置副本测试正常 OAuth 刷新，区分认证失败与网络／权限不确定，不输出凭据。每个 remote 检测最多 25 秒；需要 Python 3。

安装 rclone：

```bash
rclone_install_tool
```
解释：菜单调用 `rclone_install_tool`。CN 使用 GitHub 代理下载官方版本化 ZIP，并验证 SHA256、压缩包、架构和运行版本后原子安装；非 CN 使用带 600 秒执行上限的官方安装器，退出码 3 表示已是最新版。已有 `/usr/local/bin/rclone` 遮蔽官方 `/usr/bin/rclone` 时同步新程序。失败不创建配置、不报成功，已有配置内容保持不变。

修改配置文件：

```bash
mkdir -p /root/.config/rclone
touch /root/.config/rclone/rclone.conf
chmod 600 /root/.config/rclone/rclone.conf
vim /root/.config/rclone/rclone.conf
```
解释：用 vim 编辑 rclone 配置。

卸载 rclone：

```bash
apt purge -y rclone
rm -f /usr/bin/rclone /usr/local/bin/rclone
```
解释：删除 rclone 可执行文件；脚本会询问是否同时删除 `/root/.config/rclone` 配置目录。

恢复远程文件夹到 `/root`：

```bash
rclone_restore_remote_folder
```
解释：先选择通过验证的 remote 和服务器，再多选子目录，支持 `1 2 3`、`1,2,3`、`all` 及十进制 `08`。目录名使用 JSON 解析，保留连续空格。检查真实目标路径、Docker 活跃挂载和暂存空间；下载到独立目录并通过 `rclone check --download` 比较内容，再按用户选择保留或覆盖同名文件，替换失败回滚。根层文件、隐藏配置缺项、外部 binds、volumes、系统 cron 以及原 UID/GID 需单独核对。

Docker Compose 恢复：

```bash
rclone_restore_docker_compose_projects
# Approved project startup uses:
docker compose up -d --no-recreate --no-build --pull missing --wait --wait-timeout 120
```
解释：扫描 `/root` 及最多三级子目录的 `compose.yaml`、`compose.yml`、`docker-compose.yaml`、`docker-compose.yml`，排除隐藏、数据、备份和审计目录。现有项目从容器 labels 复用名称及多配置文件参数；歧义或文件缺失时停止。缺少 bind source、named volume 或代理错误会阻止启动；不会静默创建空数据卷。状态查询失败不会变成启动操作，已运行但 unhealthy 的服务单独报错；有效的已完成初始化依赖不要求持续运行。启动有 120 秒健康等待，无 healthcheck 只能确认运行状态。代理通过实际容器网络命名空间验证 TCP，不打印 URL 凭据；必要 UFW 规则按实际网段和端口单独确认。不会修改业务 YAML、安装 Mihomo、切换 DNS 或自动安装迁移来的 cron。

从远程恢复 Nginx + 域名：

```bash
rclone_restore_nginx_domain_remote
```
解释：从所选 remote 的服务器目录读取 `linux-daimon/backup/nginx-domain/auto_latest`，下载和内容验证后才应用。支持保留或替换同名文件，已有证书目录也会补齐缺失文件，并检查有效期和私钥配对。没有 `enabled_sites.txt` 时拒绝猜测启用列表。缺少 include、模块或其他文件会在 `nginx -t` 阶段失败并回滚，失败不会覆盖源备份；本地恢复共用同一逻辑。Nginx/openssl 缺失时通过 apt 安装；UFW 已启用才开放 80/443，不强制启用 UFW。服务启动、重载、状态或自启配置失败均报告失败。证书续期环境和云安全组仍需核对。

命令行入口：

```bash
d rclone
d rc
```
解释：直接进入 rclone 管理菜单。

## 16. Bitwarden 管理

进入 Bitwarden 管理默认展示：

```bash
bitwarden_rclone_config_status
```
解释：通过 Docker 实际挂载查找配置，对备份容器指定的 remote 和目录做读取验证；不再把配置节存在当作凭据有效。

配置 rclone.conf 文件：

```bash
bitwarden_configure_rclone_conf
```
解释：从主机配置选择有效 remote，保留目标的其他 remote 及必要依赖。使用本机已有备份镜像、`--entrypoint rclone` 直接验证，避免镜像入口吞掉错误；候选配置可在隔离目录正常刷新 token。验证成功后注册所需 named volume，再原子更新实际挂载中的配置；检测期间原文件被其他进程更新则停止，不覆盖并发刷新。不会下载云端整份旧配置、拉取新镜像或输出 token。

数据备份：

```bash
docker ps --format '{{.Names}}' | grep -qx vaultwarden-backup
docker exec -i vaultwarden-backup bash /app/backup.sh
```
解释：要求 `vaultwarden-backup` 容器已启动；备份命令退出码为 0 且输出包含 `upload backup file to storage system` 才算成功。

数据还原：

```bash
bitwarden_restore_data
```
解释：要求本机普通 local named volume 已存在，使用者已停止。自动读取备份容器的 remote、目录及数据卷，失效时可选有效 remote。备份按日期倒序列出，始终重新下载至私有目录并验证内容，不信任当前目录同名 ZIP。检查压缩及解压空间；密码隐藏输入，使用无网络、只读根文件系统的临时容器解密，再以 Python 标准库验证 SQLite 完整性、必要表和 tar 路径，拒绝路径穿越、符号链接及歧义文件。确认后替换数据，失败保留或恢复原卷；还原后容器保持停止，由用户启动并验证登录。仅支持 SQLite；外部数据库使用对应原生恢复工具，不改为 `./data`。

配置 Bitwarden 同步脚本：

```bash
mkdir -p /root/linux-daimon/backup-sh /var/log/rclone
cat > /root/linux-daimon/backup-sh/Vaultwarden_OneDrive_to_Kissska1.sh <<'EOF'
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
chmod +x /root/linux-daimon/backup-sh/Vaultwarden_OneDrive_to_Kissska1.sh
(crontab -l 2>/dev/null | grep -vF "/root/linux-daimon/backup-sh/Vaultwarden_OneDrive_to_Kissska1.sh"; echo "0 6 * * * /bin/bash /root/linux-daimon/backup-sh/Vaultwarden_OneDrive_to_Kissska1.sh >> /var/log/rclone/cron_Vaultwarden_OneDrive_to_Kissska1.log 2>&1") | crontab -
```
解释：脚本会自动检测同步脚本和 crontab 是否已配置；配置后每天 06:00 使用 `rclone sync` 从 `qq3303338052@outlook:/BitwardenBackup` 同步到 `kissska1:/BitwardenBackup`。

## 17. crontab 同步脚本管理

默认展示：

```bash
ls -1 /root/linux-daimon/backup-sh/*.sh 2>/dev/null
crontab -l
```
解释：显示内置脚本和自定义脚本的安装状态；状态会同时检查脚本文件、脚本内容关键字段和 crontab 里的精确任务行。启动新版脚本或进入本菜单时，会在确认 `kissska1` 可访问后自动迁移旧 Infini-cloud 脚本和任务，并保留原执行时间。内置脚本第 4 项是本地域名和 Nginx 配置备份，不使用 rclone。

内置脚本目录：

```bash
mkdir -p /root/linux-daimon/backup-sh /var/log/rclone
```
解释：所有同步脚本都放在 `/root/linux-daimon/backup-sh`，日志默认放在 `/var/log/rclone`。

安装/卸载脚本：

```bash
crontab -l 2>/dev/null | grep -vF "/root/linux-daimon/backup-sh/脚本名.sh" | crontab -
cat > /root/linux-daimon/backup-sh/脚本名.sh
chmod +x /root/linux-daimon/backup-sh/脚本名.sh
(crontab -l 2>/dev/null | grep -vF "/root/linux-daimon/backup-sh/脚本名.sh"; echo "错开的时间 /bin/bash /root/linux-daimon/backup-sh/脚本名.sh >> /var/log/rclone/cron_脚本名.log 2>&1") | crontab -
```
解释：安装时写入脚本并添加定时任务；卸载时删除脚本文件，并删除 crontab 中包含该脚本路径的任务行。

Bitwarden 同步脚本：

```bash
0 6 * * * /bin/bash /root/linux-daimon/backup-sh/Vaultwarden_OneDrive_to_Kissska1.sh >> /var/log/rclone/cron_Vaultwarden_OneDrive_to_Kissska1.log 2>&1
```
解释：每天 06:00 同步 `qq3303338052@outlook:/BitwardenBackup` 到 `kissska1:/BitwardenBackup`。

图床同步脚本：

```bash
0 4 * * * /bin/bash /root/linux-daimon/backup-sh/ImageBed_CloudFlare-R2_to_OneDrive.sh >> /var/log/rclone/cron_ImageBed_CloudFlare-R2_to_OneDrive.log 2>&1
```
解释：每天 04:00 同步 `qq3303338052@cloudflare:image-bed-daimon` 到 `qq3303338052@outlook:image-bed-daimon`。

Via 同步脚本：

```bash
30 4 * * * /bin/bash /root/linux-daimon/backup-sh/Via_OneDrive_to_Kissska1.sh >> /var/log/rclone/cron_Via_OneDrive_to_Kissska1.log 2>&1
```
解释：每天 04:30 同步 `qq3303338052@outlook:Via` 到 `kissska1:Via`。

域名和 nginx 配置备份脚本：

```bash
0 5 * * * /bin/bash /root/linux-daimon/backup-sh/Nginx_Domain_Local_Backup.sh >> /var/log/rclone/cron_Nginx_Domain_Local_Backup.log 2>&1
```
解释：每天 05:00 在服务器本地备份 `sites-available`、enabled 站点名称和 `/root/domain` 到 `/root/linux-daimon/backup/nginx-domain/auto_latest`；每次覆盖旧备份，只保留 1 份，不使用 rclone。未检测到 `/root/domain/*/fullchain.pem` 时跳过备份并保留已有 `auto_latest`。

自定义脚本：

```bash
cat > /root/linux-daimon/backup-sh/自定义名称.sh
45 4 * * * /bin/bash /root/linux-daimon/backup-sh/自定义名称.sh >> /var/log/rclone/cron_自定义名称.log 2>&1
```
解释：脚本名称会自动补全 `.sh` 后缀；脚本内使用文件名作为远端目录名，把 `/root` 同步到 `kissska1:脚本名` 和 `qq3303338052@outlook:脚本名`，并排除 `/root` 第一层隐藏文件/目录和 `snap/**`，子目录里的 `.env` 等隐藏文件会同步。

## 18. 常用的一键脚本

这些脚本会先退出当前脚本，再运行目标脚本，避免输出被主菜单覆盖。

```bash
bash /root/linux-daimon/daimon/NodeQuality.sh
```
解释：NodeQuality 网络质量测试，来源 `https://run.NodeQuality.com`。

```bash
bash /root/linux-daimon/daimon/IPQuality.sh
bash /root/linux-daimon/daimon/IPQuality.sh -i eth0
bash /root/linux-daimon/daimon/IPQuality.sh -x socks5://username:password@socksproxy:port
```
解释：IPQuality IP 纯净度和流媒体解锁检测，来源 `https://IP.Check.Place`。

```bash
bash /root/linux-daimon/daimon/ecs.sh
```
解释：融合怪综合测评，来源 `https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh`。

```bash
bash /root/linux-daimon/daimon/NetQuality.sh
```
解释：NetQuality 三网回程路由和延迟，来源 `https://Net.Check.Place`。

```bash
bash /root/linux-daimon/daimon/RegionRestrictionCheck.sh
```
解释：RegionRestrictionCheck 流媒体解锁测试，来源 `https://check.unlock.media`。

```bash
bash /root/linux-daimon/daimon/bench.sh
```
解释：bench.sh 系统信息、I/O、网络测速，来源 `https://bench.sh`。

```bash
bash /root/linux-daimon/daimon/yabs.sh
```
解释：YABS 综合性能测试，来源 `https://yabs.sh`。

```bash
bash /root/linux-daimon/daimon/HardwareQuality.sh -H
```
解释：HardwareQuality 硬件质量检测，来源 `https://Check.Place`。

```bash
bash /root/linux-daimon/daimon/x-ui-yg-install.sh
```
解释：勇哥 x-ui-yg 脚本，来源 `https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/install.sh`。

```bash
bash <(curl -sL kejilion.sh)
```
解释：运行 kejilion.sh 一键脚本。

```bash
bash /root/linux-daimon/daimon/sing-box-daimon.sh
```
解释：sing-box 安装与管理脚本，来源 `https://raw.githubusercontent.com/daimon3332/sing-box-daimon/main/sb.sh`。

```bash
bash /root/linux-daimon/daimon/runTcpQuality.sh
```
解释：TcpQuality TCP SYN 重传检测，来源 `https://raw.githubusercontent.com/daimon3332/TcpQuality/main/runTcpQuality.sh`。
