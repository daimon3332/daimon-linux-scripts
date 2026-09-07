# linux-tools-daimon

`linux-tools-daimon` 是个人自用的 Linux 服务器脚本工具箱，中文交互，快捷命令为 `d`。

本项目基于 `kejilion/sh` 二开定制，保留常用服务器管理能力，并增加 SSH、UFW、rclone、Bitwarden、crontab 同步脚本、SSL/Nginx、fail2ban、WARP、GitHub 镜像源测速、journalctl 日志管理、第三方工具和编程工具管理等功能。

## 编码规范

后续修改脚本前，请先阅读 [CODING_GUIDELINES.md](./CODING_GUIDELINES.md)。该文件记录本脚本维护过程中已经确定的菜单规则、国内/国外分流、GitHub 代理、`.bashrc` 写入、安装校验、卸载清理、文档同步和常见踩坑处理方式。

## 一键运行

```bash
bash <(curl -fsSL https://daimon-linux-scripts.333186.xyz/linux-toolbox.sh)
```

## 快捷命令

首次运行后可使用：

```bash
d
```

之后在服务器命令行输入 `d` 即可打开工具箱。

更新使用主菜单 `00`；不是 `d update`（后者升级系统软件包）。更新会校验 Bash 语法并原子替换快捷命令，启动不会再采用当前目录中的同名旧脚本。交互输入结束时取消当前操作，不按默认选项继续执行。

## 主菜单顺序

| 序号 | 一级菜单 | 作用 |
|---:|---|---|
| 1 | 系统信息查询 | 查看系统、CPU、内存、硬盘、网络、DNS、IP、SSH、UFW、Docker、Nginx、Fail2ban、rclone、Bitwarden 等信息 |
| 2 | 系统更新 | 更新软件源并升级系统软件包 |
| 3 | 系统清理 | 清理软件包缓存、无用依赖及限额 journal 日志 |
| 4 | 一键配置 | 快速执行系统更新、清理、Swap、DNS、BBR、Docker、网络优化、第三方工具安装、时区和本地语言配置 |
| 5 | 系统工具 | 管理快捷键、软件源、DNS、Swap、用户、时区、本地语言、主机名、hosts、网卡、日志、IPv6、Docker 镜像源测速等 |
| 6 | 第三方工具 | 安装/卸载 vim、cpcat、starship、bat、btop、yazi、NextTrace、iperf3 等常用工具 |
| 7 | 编程工具 | 安装/卸载 Python、Node.js、Bun、uv、git、ClaudeCode、Codex 等开发工具 |
| 8 | Docker管理 | 安装、卸载、状态查看、镜像源、容器、镜像、网络、卷、Compose、备份迁移等 |
| 9 | SSH管理 | 修改 SSH 端口、密码登录、密钥登录、公钥私钥和 sshd_config |
| 10 | UFW管理 | 安装/卸载 UFW、开放端口、删除端口规则 |
| 11 | Nginx + 域名管理 | 安装 Nginx、申请证书、删除证书、配置 Nginx、备份/恢复域名和 Nginx 配置 |
| 12 | fail2ban管理 | 安装/卸载 fail2ban，并自动配置 sshd 防护 |
| 13 | BBR管理 | 进入 BBR / 网络加速管理脚本 |
| 14 | WARP管理 | 进入 WARP 管理脚本或彻底删除 WARP |
| 15 | rclone管理 | 安装 rclone、修改配置文件、卸载 rclone |
| 16 | Bitwarden管理 | 配置 vaultwarden-backup 的 rclone.conf、执行备份和还原 |
| 17 | crontab同步脚本管理 | 管理 Bitwarden、图床、Via、域名和 Nginx 配置备份、自定义同步脚本 |
| 18 | 常用的一键脚本 | 运行 NodeQuality、IPQuality、YABS、kejilion.sh 等脚本 |

## 主要内容

### Nginx 与域名管理（统一流程）

- 菜单 11 使用宿主机 Nginx + acme.sh，证书按完整域名隔离在 `/root/domain/<完整域名>`，不再按首段共享目录。
- 证书申请和续期统一使用 `/var/www/acme-challenge` webroot，Nginx 不会因证书操作被停止，也不会强制 `kill -9` 其他服务。
- 证书安装包含 Nginx reload hook；续期包装脚本写入 `/var/log/acme.sh/renew.log`，失败会写入系统日志。
- 删除操作仅清理反代配置和证书，不会删除站点数据库；自动备份位于 `/root/linux-daimon/backup/nginx-domain`。

### SSH 与 UFW

- 启用 UFW 前自动放行当前 sshd 监听端口和新端口；一键 SSH 配置要求有效公钥，空输入会中止。
- 修改 sshd 配置会先执行语法检查，重启失败时恢复最近备份。

### OpenClaw 与 Docker 备份

- OpenClaw 还原支持路径检查、校验和验证，并在覆盖前保留回滚包。
- Docker 迁移菜单使用独立函数命名，避免覆盖系统备份菜单；备份目录权限为 700，删除需要确认。

### 系统信息查询

- 展示主机名、系统版本、内核、CPU、内存、Swap、硬盘、流量、拥塞算法、队列算法、运营商、IPv4、IPv6、DNS、位置、时间、时区、本地语言、运行时长，以及 SSH、UFW、Docker、Nginx、Fail2ban、rclone、Bitwarden 状态。

### 系统更新

- 尝试修复 dpkg 中断；锁被占用或修复失败时停止，不强杀进程或删除锁文件。
- 执行系统软件包更新和升级。

### 系统清理

- 清理无用依赖、软件包缓存，按原有 500M 上限清理 journal；任一步失败即停止。
- 不清空共享 `/tmp`、`/var/log`，不按 1 秒保留期删除日志；无安全清理入口的 opkg 跳过。

### 一键配置

| 序号 | 选项 | 作用 |
|---:|---|---|
| 1 | 配置全部 | 默认回车也是此项，预填 `2 3 4 5 6 7 8 9 10`，用户可自行删减编号 |
| 2 | 系统更新 | 执行系统更新 |
| 3 | 系统清理 | 执行系统清理 |
| 4 | 设置虚拟内存 1G | 创建/重建 1G Swap |
| 5 | 优化 DNS 地址 | 根据 `ipinfo.io` 的 `country` 字段自动选择 DNS；`CN` 使用国内 DNS，其他地区包括香港使用国外 DNS |
| 6 | 开启 BBR 加速（BBR + FQ） | 当前内核支持 BBR 时设置并验证 BBR + FQ；不自动安装或更换内核 |
| 7 | 安装 Docker | 根据 `ipinfo.io` 的 `country` 字段自动选择国内镜像或 Docker 官方源 |
| 8 | 应用自定义网络优化 | 使用内置参数优化网络；当前内核不支持 BBR 时停止操作，不写入无效配置 |
| 9 | 安装第三方工具 | 默认预填全部第三方工具编号，用户可修改 |
| 10 | 修改时区和本地语言 | 设置时区为 `Asia/Shanghai`，本地语言为 `en_US.UTF-8` |

### 系统工具

| 序号 | 选项 | 作用 |
|---:|---|---|
| 1 | 设置脚本启动快捷键 | 设置 `d` 或自定义快捷命令 |
| 2 | 更换系统软件包镜像源 | 运行 `bash <(curl -sSL https://linuxmirrors.cn/main.sh)` |
| 3 | 优化 DNS 地址 | 配置国外/国内 DNS、手动编辑或恢复原配置 |
| 4 | 切换优先 ipv4/ipv6 | 修改 `/etc/gai.conf`，切换 IPv4/IPv6 优先级 |
| 5 | 修改虚拟内存大小 | 预设 1G、2G、4G，支持自定义 Swap 大小，也支持删除 `/swapfile` |
| 6 | 用户管理 | 创建普通用户/高级用户、赋予/取消 sudo 权限、删除用户 |
| 7 | 系统时区调整 | 切换亚洲、欧洲、美洲和 UTC 常用时区 |
| 8 | 修改主机名 | 修改 hostname 和 hosts 中的本机名 |
| 9 | 本机 host 解析 | 添加或删除 `/etc/hosts` 解析记录 |
| 10 | 系统变量管理工具 | 查看、添加、修改、删除环境变量 |
| 11 | github镜像源 | 显示镜像源、添加、删除、测速 |
| 12 | 查看ssh的ip | 查看当前 SSH 连接 IP 和所有 SSH 连接地址 |
| 13 | 网卡管理工具 | 查看、启用、禁用网卡和查看网卡详细信息 |
| 14 | journalctl日志管理 | 配置日志自动清理、查看占用、查看服务日志、按时间/大小清理 |
| 15 | 系统网络自适应优化 | 检测当前内核的 BBR 能力，严格应用并验证 BBR/FQ 和自适应 sysctl 参数；不支持时可转到 BBR 管理安装内核 |
| 16 | 禁用IPv6 | 写入 sysctl 配置禁用 IPv6 |
| 17 | 开启IPv6 | 写入 sysctl 配置开启 IPv6 |
| 18 | 设置本地语言 | 支持 `en_US.UTF-8`、中文简体和其他常用 UTF-8 locale |
| 19 | Docker镜像源测速 | 测速默认镜像源、第三方镜像源或两者组合，可选择加入官方镜像源 |
| 20 | 卸载daimon脚本 | 删除 daimon 本地脚本和快捷命令 |

Swap 只调整带本脚本 inode 归属标记的 `/swapfile`；未标记的已有文件、其他 swap 文件及物理分区保持不变。大小须为 1-1048576 MiB 整数；停用失败不覆盖原文件，新文件启用失败尝试恢复原文件和启用状态。

自定义快捷键不能覆盖已有系统命令。用户权限修改与删除仅接受合法的普通账号（UID 至少 1000，排除 nobody）；删除账号及主目录需要再次输入用户名确认。

#### 系统网络自适应优化参数

现代发行版内核通常已经包含标准 BBR，此时直接加载模块并启用，无需安装新内核。BBR/FQ 配置写入 `/etc/sysctl.d/99-daimon-bbr-fq.conf`，其他网络参数写入 `/etc/sysctl.d/99-daimon-network-optimize.conf`；清除自定义网络优化时保留 BBR/FQ。当前内核不支持 BBR 时不会写入配置或显示成功，可选择进入主菜单 13 安装兼容内核。其他 sysctl 文件定义不同值时只报告覆盖风险，不自动修改用户配置。

应用前还要求默认路由网卡的实际队列为 `fq` 或 `mq` 加全部 `fq` 叶队列；缺少 `tc`、没有默认路由或队列不符时停止，不自动覆盖已有队列。失败会恢复并核对配置文件和运行态参数；回滚不完整时保留快照并明确报错。参数不保证所有线路都变快，2026-09-07 的两机对比未显示 tcpfit 稳定全面胜出，因此保留现有方案，详见 [审计记录](AUDIT.md)。

| 参数 | 参数的含义 | 调优的参数值 | 调优之后的效果 |
|---|---|---|---|
| `net.core.default_qdisc` | 默认网络队列调度算法 | `fq` | 配合 BBR 做公平队列调度，降低排队延迟 |
| `net.ipv4.tcp_congestion_control` | TCP 拥塞控制算法 | `bbr` | 使用 BBR 提升高延迟、高带宽链路吞吐 |
| `net.core.rmem_max` | Socket 最大接收缓冲区 | `134217728` | 提高大带宽链路接收能力 |
| `net.core.wmem_max` | Socket 最大发送缓冲区 | `134217728` | 提高大带宽链路发送能力 |
| `net.core.netdev_max_backlog` | 网卡收包队列长度 | `300000` | 缓解高并发或突发流量下的丢包 |
| `net.ipv4.tcp_rmem` | TCP 接收缓冲区最小值、默认值、最大值 | `4096 131072 134217728` | 让 TCP 接收窗口可随链路质量扩大 |
| `net.ipv4.tcp_wmem` | TCP 发送缓冲区最小值、默认值、最大值 | `4096 131072 134217728` | 让 TCP 发送窗口可随链路质量扩大 |
| `fs.file-max` | 系统最大文件句柄数 | `2097152` | 提升大量连接和文件打开场景的容量 |
| `net.ipv4.tcp_tw_reuse` | TIME_WAIT 连接复用 | `1` | 减少短连接过多时的端口占用 |
| `net.ipv4.tcp_fastopen` | TCP Fast Open | `3` | 客户端和服务端均启用 TFO，减少握手延迟 |
| `net.ipv4.tcp_window_scaling` | TCP 窗口缩放 | `1` | 支持更大的 TCP 窗口，提高长肥链路吞吐 |
| `net.ipv4.tcp_max_syn_backlog` | SYN 半连接队列长度 | `262144` | 提升高并发建连承载能力 |
| `net.core.somaxconn` | Socket listen 队列上限 | `65535` | 提升服务端连接排队能力 |
| `net.ipv4.ip_local_port_range` | 本地临时端口范围 | `1024 65535` | 扩大主动连接可用端口范围 |
| `vm.swappiness` | Swap 使用倾向 | `10` | 降低系统主动使用 Swap 的概率 |
| `net.ipv4.tcp_slow_start_after_idle` | 空闲后重新慢启动 | `0` | 避免连接空闲后吞吐重新爬升过慢 |
| `net.ipv4.tcp_limit_output_bytes` | TCP 单连接排队输出上限 | `4194304` | 限制过量排队，兼顾吞吐和延迟 |
| `net.ipv4.tcp_mtu_probing` | TCP MTU 探测 | `1` | 遇到 PMTU 黑洞时自动探测，减少传输异常 |

### 第三方工具

- 支持按编号安装、按编号卸载、全部安装、全部卸载。
- “全部安装 / 全部卸载”会预填当前分类全部编号，执行前可以手动删除不需要的编号。
- 带配置的工具卸载时会同步删除脚本写入的配置。

| 序号 | 名称 | 工具的作用 |
|---:|---|---|
| 1 | vim | 文本编辑器，并设置 `EDITOR=vim`、`VISUAL=vim` |
| 2 | cpcat | 通过 OSC 52 快速复制文件内容到本地剪贴板 |
| 3 | Ctrl+D | 将 Bash 中的 `Ctrl+D` 绑定为删除下一个单词 |
| 4 | starship | 终端提示符美化 |
| 5 | bat | 终端输出高亮增强，提供 `bauto`、`blog`、`byaml`、`raw` 等命令 |
| 6 | btop | 现代化系统资源监控工具 |
| 7 | tree | 以树形结构查看目录 |
| 8 | ripgrep | 快速文本搜索工具，命令为 `rg` |
| 9 | fd | 快速文件查找工具，Ubuntu 下通过 `fd-find` 安装并配置 `fd` 别名 |
| 10 | fzf | 命令行模糊搜索工具，使用 git clone 安装 |
| 11 | ble.sh | Bash 行编辑增强、自动补全和历史补全 |
| 12 | yazi | 现代终端文件管理器，通过 `debian.griffo.io` apt 源安装 |
| 13 | fastfetch | 系统概览信息展示工具 |
| 14 | ncdu | 交互式磁盘占用分析工具 |
| 15 | NextTrace | 可视化路由追踪工具，通过官方 apt 源安装 |
| 16 | iperf3 | 网络性能测试工具 |

### 编程工具

- 支持按编号安装、按编号卸载、全部安装、全部卸载。
- “全部安装 / 全部卸载”会预填当前分类全部编号，执行前可以手动删除不需要的编号。

| 序号 | 名称 | 工具的作用 |
|---:|---|---|
| 1 | python | 默认安装 Python 3.12、pip 和 venv，并将 `python` 指向 Python 3.12 |
| 2 | npm | 通过 nvm 安装 Node.js LTS 后提供 npm；CN 使用 nvm-cn，非 CN 使用官方 nvm |
| 3 | nodejs | 通过 nvm 安装最新 LTS 版本 Node.js |
| 4 | bun | Bun JavaScript 运行时和包管理器 |
| 5 | uv | Python 包管理和项目管理工具 |
| 6 | git | 版本控制工具 |
| 7 | ClaudeCode | Claude Code 命令行工具；CN 使用 npm 镜像源，非 CN 使用官方安装脚本，并写入 `~/.claude/settings.json` |
| 8 | Codex | Codex 命令行工具；统一通过 `npm install -g @openai/codex@latest` 安装，并写入 `~/.codex/config.toml` |

### Docker管理

| 序号 | 选项 | 作用 |
|---:|---|---|
| 1 | 安装更新 Docker 环境 | 安装或更新 Docker |
| 2 | 查看 Docker 全局状态 | 查看 Docker 服务和版本状态 |
| 3 | Docker 容器管理 | 管理容器 |
| 4 | Docker 镜像管理 | 管理镜像 |
| 5 | Docker 网络管理 | 管理 Docker 网络 |
| 6 | Docker 卷管理 | 管理 Docker volume |
| 7 | Docker 清理 | 清理无用 Docker 资源 |
| 8 | 更换 Docker 源 | 配置默认 Docker 镜像源：`hub.333186.xyz`、`docker.m.daocloud.io`、`docker.1ms.run`、`docker.registry.cyou` |
| 9 | 编辑 daemon.json 文件 | 编辑 Docker daemon 配置 |
| 10 | Docker Compose 自动更新 | 保留项目名和配置文件，定时拉取并健康检查；失败自动恢复旧镜像 |
| 11 | 开启 Docker IPv6 访问 | 写入 Docker IPv6 配置 |
| 12 | 关闭 Docker IPv6 访问 | 关闭 Docker IPv6 配置 |
| 19 | 备份/迁移/还原 Docker 环境 | 备份、迁移和还原 Docker 项目 |
| 20 | 卸载 Docker 环境 | 卸载 Docker |

Compose 自动更新不会预先执行 `docker compose down`。每个任务使用独立锁，先拉取镜像，再通过原项目名、完整配置文件列表和当前运行服务执行 `up -d --no-deps --wait`；没有运行服务的项目会跳过，同项目中已停止的服务或依赖也不会被启动。拉取失败时现有容器保持运行，启动或健康检查失败且旧镜像完整可用时自动恢复。菜单可识别旧版脚本、损坏脚本以及项目删除后遗留的任务，并提供重新安装和清理入口。日志每天轮转，最多保留 14 份且单文件不超过 10 MB。

### SSH管理

| 序号 | 选项 | 作用 |
|---:|---|---|
| 1 | 修改 SSH 端口 | 修改 sshd 监听端口 |
| 2 | 禁用 / 开启密码登录 | 控制 `PasswordAuthentication` |
| 3 | 开启 / 禁用密钥登录 | 控制 `PubkeyAuthentication`，开启时可粘贴公钥 |
| 4 | 一键配置 | 一键改端口、关密码、开密钥、配置防火墙 |
| 5 | 公钥和私钥管理 | 添加/删除公钥，添加/删除私钥 |
| 6 | 修改 sshd_config 配置文件 | 直接修改 SSH 配置文件 |

### UFW管理

| 序号 | 选项 | 作用 |
|---:|---|---|
| 1 | 安装 UFW | 安装并启用 UFW |
| 2 | 卸载 UFW | 禁用并彻底卸载 UFW |
| 3 | 开放端口 | 用户输入 `80` 执行 `ufw allow 80`，输入 `80/tcp` 执行 `ufw allow 80/tcp` |
| 4 | 删除端口规则 | 用户输入 `80` 执行 `ufw delete allow 80`，输入 `80/tcp` 执行 `ufw delete allow 80/tcp` |
| 0 | 返回主菜单 | 返回上一级菜单 |

### Nginx + 域名管理

| 序号 | 选项 | 作用 |
|---:|---|---|
| 1 | 申请证书 + 配置 nginx | 申请证书并生成 Nginx 配置；失败时自动清理证书和 Nginx 配置 |
| 2 | 删除 nginx 配置 + 证书 | 删除站点配置和证书 |
| 3 | 申请证书 | 只申请证书 |
| 4 | 移除证书 | 删除证书 |
| 5 | 查看证书列表 | 查看已申请证书 |
| 6 | 配置 nginx | 只生成 Nginx 配置 |
| 7 | 删除 nginx 配置 | 删除 Nginx 配置 |
| 8 | 创建测试页面 | 校验名称和端口，不覆盖已有目录或配置 |
| 9 | 删除测试页面 | 仅删除带本脚本归属标记的测试目录，保留未标记的旧目录 |
| 10 | 安装 nginx | 安装、启动并设置 Nginx 开机自启 |
| 11 | 备份域名 + nginx 配置 | 替换最新本地备份 `/root/linux-daimon/backup/nginx-domain/auto_latest` |
| 12 | 恢复域名 + nginx 配置 | 从 `/root/linux-daimon/backup/nginx-domain/auto_latest` 合并恢复 `sites-available` 和 `/root/domain`，并重建 `sites-enabled` 软链接；同名文件保留本机版本 |
| 13 | 迁移/修复现有证书 | 将 acme.sh 证书迁移到 webroot 模式并保留当前 Nginx 证书路径；可选择是否创建迁移备份，逐域名报告成功、失败和跳过 |

进入 Nginx + 域名管理时只显示域名备份脚本是否开启；安装 Nginx、申请证书或配置 Nginx 时会自动开启每天 05:00 的本地备份脚本。证书续期任务为每天 03:00 的 `/root/linux-daimon/cert-renew.sh`，日志位于 `/var/log/acme.sh/renew.log`。脚本运行时检测 `/root/domain/*/fullchain.pem`，有域名才刷新 `auto_latest`，无域名则跳过且保留已有备份。恢复时合并备份内容，同名冲突以本机现有文件为准。主脚本更新时可选择是否同步 Nginx + 域名续期脚本。

### fail2ban管理

| 序号 | 选项 | 作用 |
|---:|---|---|
| 1 | 安装 Fail2ban | 自动检测当前 SSH 端口并配置 sshd 防护 |
| 2 | 卸载 Fail2ban | 停止服务并删除配置/状态目录 |
| 3 | 检查 sshd 配置 | 检查 jail 中的 sshd 端口，不一致则自动修正 |
| 0 | 返回主菜单 | 返回上一级菜单 |

### BBR管理

- 每次进入时优先下载并校验最新版 `tcpx.sh`，更新失败才使用已通过语法校验的本地缓存。
- `tcpx.sh` 提供官方稳定/最新/Cloud、BBR、BBRplus、XanMod 和 Zen 等内核安装选项。安装内核需要用户明确选择，不会因进入菜单而自动执行。

### WARP管理

| 序号 | 选项 | 作用 |
|---:|---|---|
| 1 | 进入 WARP 官方管理脚本 | 运行 WARP 管理脚本 |
| 2 | 彻底删除 WARP | 删除 WARP 网络接口、Linux Client 和 WireProxy |

### rclone管理

通过 `ipinfo.io` 判断地区：`CN` 优先用 GitHub 代理获取官方版本化发行包，校验 SHA256、ZIP 和实际可执行版本后原子安装；`HK`、其他地区及未知地区使用官方安装器。所有下载设有超时和失败回退，失败不会创建配置或提示成功。成功安装保留已有配置内容，只设置必要权限。

| 序号 | 选项 | 作用 |
|---:|---|---|
| 1 | 安装 rclone | 安装 rclone |
| 2 | 修改配置文件 | 打开 rclone 配置 |
| 3 | 卸载 rclone | 卸载 rclone |
| 4 | 恢复远程文件夹到 /root | 一级服务器目录单选，二级子文件夹支持多选，恢复到 `/root/子文件夹名` |
| 5 | 从远程恢复 Nginx + 域名 | 选择服务器目录后，恢复 `sites-available`、重建 `sites-enabled` 软链接并恢复 `/root/domain`；同名文件保留本机版本 |
| 6 | Docker Compose 恢复 | 扫描 `/root/*/docker-compose.yml`，确认后启动未完整运行的 Compose 项目，已完整运行则跳过 |

### Bitwarden管理

| 序号 | 选项 | 作用 |
|---:|---|---|
| 1 | 配置 rclone.conf 文件 | 暂存下载，通过容器实际连接 `BitwardenBackup:`；成功后原子更新配置，失败保留原配置，不打印 token |
| 2 | 数据备份 | 对运行中的 `vaultwarden-backup` 容器执行 `/app/backup.sh`；退出码和上传成功字段必须同时满足 |
| 3 | 数据还原 | 展示 `qq3303338052@outlook:/BitwardenBackup` 下的备份文件，按日期倒序选择后执行 restore |
| 4 | 配置 Bitwarden 同步脚本 | 写入 `/root/linux-daimon/backup-sh/Vaultwarden_OneDrive_to_Kissska1.sh`，并添加每天 06:00 同步到 `kissska1` 的 crontab |
| 0 | 返回主菜单 | 返回上一级菜单 |

### crontab同步脚本管理

内置脚本编号：

| 序号 | 名称 | 作用 |
|---:|---|---|
| 1 | Bitwarden 同步脚本 | 每天 06:00 从 `qq3303338052@outlook` 同步 Bitwarden 备份到 `kissska1` |
| 2 | 图床同步脚本 | 每天 04:00 同步图床数据 |
| 3 | Via 同步脚本 | 每天 04:30 从 `qq3303338052@outlook:Via` 同步到 `kissska1:Via` |
| 4 | 域名和nginx配置备份脚本 | 每天 05:00 本地备份到 `/root/linux-daimon/backup/nginx-domain/auto_latest`，只保留 1 份，不使用 rclone |

新版脚本启动或进入本菜单时，会先验证 `kissska1`，再自动删除旧 Infini-cloud 任务和脚本，保留原执行时间并生成对应的 kissska1 同步任务。

| 序号 | 选项 | 作用 |
|---:|---|---|
| 1 | 安装脚本 | 支持多选安装 Bitwarden、图床、Via、域名和 Nginx 配置备份或已有自定义脚本 |
| 2 | 卸载脚本 | 支持多选删除脚本文件和对应 crontab |
| 3 | 一键安装 | 默认预填所有脚本编号，用户可自行删除编号 |
| 4 | 一键卸载 | 默认预填所有脚本编号，用户可自行删除编号 |
| 5 | 自定义脚本 | 输入脚本名称，自动补全 `.sh`，写入通用 `/root` 备份模板 |
| 0 | 返回主菜单 | 返回上一级菜单 |


### 常用的一键脚本

| 序号 | 名称 | 命令 |
|---:|---|---|
| 1 | NodeQuality | `bash <(curl -sL https://run.NodeQuality.com)` |
| 2 | IPQuality | `bash <(curl -Ls https://IP.Check.Place)` |
| 3 | 融合怪 | `curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh` |
| 4 | NetQuality | `bash <(curl -Ls https://Net.Check.Place)` |
| 5 | RegionRestrictionCheck | `bash <(curl -L -s check.unlock.media)` |
| 6 | bench.sh | `wget -qO- bench.sh | bash` |
| 7 | YABS | `curl -sL https://yabs.sh | bash` |
| 8 | HardwareQuality | `bash <(curl -Ls https://Check.Place) -H` |
| 9 | 勇哥脚本 | 进入脚本后运行 |
| 10 | kejilion.sh | `bash <(curl -sL kejilion.sh)` |
| 11 | sing-box安装 | `bash <(curl -fsSL https://raw.githubusercontent.com/daimon3332/sing-box-daimon/main/sb.sh)` |
| 12 | TcpQuality | `bash <(curl -fsSL https://raw.githubusercontent.com/daimon3332/TcpQuality/main/runTcpQuality.sh)` |

## 第三方脚本引用

以下只列本脚本会下载后执行、`source`、`exec bash` 或通过管道执行的第三方脚本/安装器；普通 API、软件源、配置文件、Docker 镜像源和二进制文件不列入此表。

| 分类 | 名称 | 来源 | 用途 |
|---|---|---|---|
| 系统工具 | linuxmirrors 软件源脚本 | `https://linuxmirrors.cn/main.sh` | 更换系统软件包镜像源 |
| 系统工具 | cmdbox 命令收藏夹脚本 | `https://raw.githubusercontent.com/byJoey/cmdbox/refs/heads/main/install.sh` | 安装命令收藏夹 |
| Docker | linuxmirrors Docker 安装脚本 | `https://linuxmirrors.cn/docker.sh` | 安装 Docker、配置 Docker CE 源和镜像源 |
| 系统工具 | jhb IPv6 修复脚本 | `https://jhb.ovh/jb/v6.sh` | IPv6 修复 |
| BBR 管理 | kejilion 网络自适应优化脚本 | `https://raw.githubusercontent.com/kejilion/sh/refs/heads/main/network-optimize.sh` | Linux 内核调优管理中的自动调优/还原 |
| BBR 管理 | Linux-NetSpeed | `https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcpx.sh` | BBR / 网络加速管理 |
| BBR 管理 | jhb BBRv3 ARM 脚本 | `https://jhb.ovh/jb/bbrv3arm.sh` | ARM 环境 BBRv3 相关处理 |
| WARP 管理 | fscarmen WARP 菜单脚本 | `https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh` | WARP 安装、管理和彻底删除 |
| rclone 管理（非 CN） | rclone 官方安装脚本 | `https://rclone.org/install.sh` | 安装 rclone；CN 直接下载并校验官方发行包 |
| SSL/Nginx | acme.sh 官方安装脚本 | `https://get.acme.sh` | 安装 acme.sh，用于申请和续期证书 |
| LDNMP/网站管理 | 内置 certbot webroot 续期脚本 | `/root/linux-daimon/daimon/auto_cert_renewal.sh` | 仅续期正在运行且已配置 challenge 路径的 Docker Nginx 站点 |
| Cloudflare | kejilion CF Under Attack 脚本 | `https://raw.githubusercontent.com/kejilion/sh/main/CF-Under-Attack.sh` | Cloudflare 防护模式相关操作 |
| 第三方工具 | starship 官方安装脚本 | `https://starship.rs/install.sh` | 国外机器安装 starship |
| 第三方工具 | fzf 源码仓库 | `https://github.com/junegunn/fzf.git` | git clone 安装 fzf |
| 第三方工具 | ble.sh 源码仓库 | `https://github.com/akinomyoga/ble.sh.git` | git clone 安装 ble.sh |
| 编程工具 | Bun 官方安装脚本 | `https://bun.sh/install` | 安装 Bun |
| 编程工具 | uv 官方安装脚本 | `https://astral.sh/uv/install.sh` | 安装 uv |
| 编程工具 | NodeSource Debian/Ubuntu 安装脚本 | `https://deb.nodesource.com/setup_24.x` | 配置 Node.js apt 源 |
| 编程工具 | NodeSource RHEL/Fedora 安装脚本 | `https://rpm.nodesource.com/setup_24.x` | 配置 Node.js rpm 源 |
| 常用一键脚本 | NodeQuality | `https://run.NodeQuality.com` | 网络质量测试 |
| 常用一键脚本 | IPQuality | `https://IP.Check.Place` | IP 质量、纯净度和流媒体检测 |
| 常用一键脚本 | 融合怪 | `https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh` | 综合性能测评 |
| 常用一键脚本 | NetQuality | `https://Net.Check.Place` | 网络质量、回程和延迟检测 |
| 常用一键脚本 | RegionRestrictionCheck | `https://check.unlock.media` | 流媒体解锁检测 |
| 常用一键脚本 | bench.sh | `https://bench.sh` | 基础性能、I/O、网络测速 |
| 常用一键脚本 | YABS | `https://yabs.sh` | 综合性能测试 |
| 常用一键脚本 | HardwareQuality | `https://Check.Place` | 硬件质量检测 |
| 常用一键脚本 | 勇哥 x-ui-yg | `https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/install.sh` | x-ui-yg 管理脚本 |
| 常用一键脚本 | kejilion.sh | `https://kejilion.sh` | kejilion 一键脚本 |
| 常用一键脚本 | sing-box-daimon | `https://raw.githubusercontent.com/daimon3332/sing-box-daimon/main/sb.sh` | sing-box 安装与管理脚本 |
| 常用一键脚本 | TcpQuality | `https://raw.githubusercontent.com/daimon3332/TcpQuality/main/runTcpQuality.sh` | TCP SYN 重传检测 |

国内机器访问 `raw.githubusercontent.com` / `github.com` 相关脚本时，脚本会优先尝试 GitHub 代理地址，例如 `https://gh-proxy.com/`、`https://ghproxy.net/`、`https://testingcf.jsdelivr.net/gh/`、`https://ghfast.top/`。

## 目录约定

脚本运行过程中的 daimon 自有文件默认放到 `/root/linux-daimon`：

| 路径 | 用途 |
|---|---|
| `/root/linux-daimon/linux-toolbox.sh` | 本地脚本 |
| `/root/linux-daimon/daimon` | 第三方脚本缓存 |
| `/root/linux-daimon/backup` | 本地备份 |
| `/root/linux-daimon/backup-sh` | crontab 同步脚本 |
| `/root/linux-daimon/docker-compose-update` | Docker Compose 自动更新脚本 |
| `/root/linux-daimon/tools/fzf` | fzf clone 目录 |

域名证书目录保持 `/root/domain`，不迁移到 `/root/linux-daimon`。


## 风险提示

本脚本会修改系统配置、SSH、UFW、Docker、Nginx、SSL 证书、Swap、软件源等内容。请只在自己拥有管理权限的服务器上使用，并提前备份重要数据。

## 开源协议

本项目基于 MIT License 开源，详见 [LICENSE](./LICENSE)。

## 致谢

- 上游项目：<https://github.com/kejilion/sh>
- 本项目仓库：<https://github.com/daimon3332/linux-tools-daimon>
