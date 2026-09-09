# linux-tools-daimon 编码规范

本文记录 `linux-tools-daimon` 后续维护时必须遵守的编码要求、已遇到的困难以及对应解决方案。修改脚本前应先阅读本文，避免重复踩坑。

## 1. 总原则

- 修改前先查看当前实现，不要凭记忆改。
- 用户明确要求只改某个点时，只改该点，不做无关重构。
- 新增功能必须放到对应菜单分类，不要混入不相关菜单。
- 功能完成后至少执行 `bash -n linux-toolbox.sh`。
- 文档修改后至少执行 `git diff --check`。
- 不要因为某条命令执行过就提示成功，必须验证实际结果。
- 系统信息查询只能做只读检测，不允许安装软件、启动服务或修改配置。

## 2. 菜单结构

- 一级菜单、二级菜单、三级菜单编号必须保持稳定。
- 新增功能优先放入已有分类，不要随意改变用户已经习惯的菜单位置。
- `0` 只能返回上一级菜单，不能触发 `break_end`。
- 纯返回、取消、退出不应该再提示“按任意键继续”。
- 执行真实操作后可以使用 `break_end`。
- 菜单组之间可以使用 `------------------------` 作为分隔符。
- 管理类菜单应放在一起，例如 UFW、SSL/Nginx、fail2ban、BBR、WARP、rclone、Bitwarden、crontab 同步脚本。

## 3. README 和 COMMANDS

- `README.md` 按一级菜单和二级菜单顺序组织。
- `COMMANDS.md` 按菜单顺序说明每个选项背后的核心命令。
- README 中的第三方工具和编程工具必须用表格写清楚编号、名称、作用。
- README 中必须维护“第三方脚本引用”表，列出脚本会下载后执行、`source`、`exec bash` 或通过管道执行的外部脚本/安装器。
- 普通 API、软件源、配置文件、Docker 镜像源和二进制文件不放入“第三方脚本引用”表。
- 文档要写清楚流程、命令、作用和风险点，避免只有概念描述。

## 4. 国内 / 国外机器判断

- 统一通过 `ipinfo.io` 的 `country` 字段判断地区。
- `CN` 视为国内机器。
- `HK` 不视为国内机器，默认走国外逻辑。
- DNS、Docker、GitHub 下载、starship 安装等逻辑都要遵守该规则。
- 一键配置中的 DNS 不能再让用户交互选择，必须根据国家自动选择。
- 国内 DNS 固定使用 `223.5.5.5` 和 `119.29.29.29`。

## 5. GitHub 代理策略

- 国内机器访问 `raw.githubusercontent.com` 和 `github.com` 时必须优先尝试代理。
- 当前代理顺序为 `gh-proxy.com`、`ghproxy.net`、`testingcf.jsdelivr.net`、`ghfast.top`。
- 普通 GitHub raw 文件优先使用 `daimon_download_to`。
- 不能只代理外层脚本，还要考虑第三方安装脚本内部二次访问 GitHub 的情况。
- starship 是特殊案例，国内机器不能走 `starship.rs/install.sh`，因为它内部会下载 GitHub release。

## 6. 第三方脚本下载

- 需要落地保存的第三方脚本默认缓存到 `/root/linux-daimon/daimon`。
- 优先使用 `daimon_run_cached_script` 或 `daimon_exec_cached_script`。
- 常用一键脚本适合使用 `exec bash`，避免输出被主菜单覆盖。
- 下载失败必须停止当前功能，不能继续提示成功。
- 下载后执行前要 `chmod +x`，除非脚本明确通过 `bash 脚本路径` 执行。
- starship 这类临时 tarball 可以使用 `/tmp/starship.tar.gz`，安装完成后必须清理。

## 7. 安装成功判断

- 安装工具后必须检查实际命令是否存在。
- 例如 starship 必须检查 `command -v starship`。
- rclone、Docker、fail2ban、WARP 等服务类功能要检查命令、服务、容器或关键配置。
- 如果安装失败，不能继续写入 `.bashrc` 初始化配置。
- 如果已经存在错误初始化配置，失败时要尽量清理，避免用户再次登录时报错。

## 8. `.bashrc` 修改规范

- 不要在安装过程中反复 `source ~/.bashrc`。
- 修改 `.bashrc` 后优先在安装结束统一 `exec bash`。
- 所有写入 `.bashrc` 的配置块必须有明确起止标记。
- 重复安装前要先删除旧配置块。
- 卸载时必须删除对应配置块。
- 不要模糊删除用户自己的内容。
- `bat` 复杂配置写入 `~/.bat.sh`，`.bashrc` 只负责 source。
- `ble.sh` source 块必须放在 `.bashrc` 末尾。
- `fzf` 配置不能使用 `return` 中断整个 `.bashrc`。

## 9. Shell 范围

- 当前主要目标是 Ubuntu + Bash。
- 之前已经兼容 Zsh 或其他发行版的代码可以保留。
- 后续新增功能不强制兼容 Zsh。
- 后续新增功能不优先考虑非 Ubuntu 系统，除非明确需要。

## 10. 第三方工具管理

- 第三方工具必须支持安装和彻底卸载。
- apt 安装的工具卸载时使用 `apt purge -y`。
- 有配置文件的工具卸载时必须删除配置文件。
- 依赖其他工具的配置必须有备用方案。
- fzf 没有 bat 时回退到 `sed`。
- fzf 没有 tree 时回退到 `ls`。
- “全部安装 / 全部卸载”不能直接执行全部，必须预填所有编号，让用户可删减。
- 安装完成后统一 `exec bash` 重新进入 shell。

## 11. starship 规则

- 国外机器使用 `curl -sS https://starship.rs/install.sh | sh -s -- -y`。
- 国内机器使用 `https://gh-proxy.com/https://github.com/starship/starship/releases/latest/download/starship-<arch>-unknown-linux-musl.tar.gz`。
- 国内机器不要走官方安装脚本。
- 安装成功后才写入 `eval "$(starship init bash)"`。
- 安装失败时必须清理 `.bashrc` 中的 starship 初始化配置。

## 12. ble.sh 规则

- 安装 ble.sh 后必须写入 `~/.blerc`。
- `~/.blerc` 必须包含自动补全、history 自动补全和 fzf 快捷键判断。
- 只有检测到 fzf 时才执行 `ble-import -d integration/fzf-key-bindings`。
- `.bashrc` 里不能重复出现多个 `source ~/.local/share/blesh/ble.sh`。
- `ble.sh` 配置块必须位于 `.bashrc` 末尾。

## 13. Docker 规则

- Docker 安装根据国家选择源。
- `CN` 使用国内镜像源。
- 非 `CN` 和 `HK` 使用 Docker 官方源。
- Docker Compose 自动更新要扫描容器 label，按 Compose 项目去重。
- 自动更新脚本要写入固定目录。
- crontab 自动更新任务不能全部放在同一时间。

## 14. DNS 规则

- 一键配置中的 DNS 优化必须自动判断。
- `CN` 使用国内 DNS。
- 非 `CN` 包括 `HK` 使用国外 DNS。
- 一键配置中的时区和本地语言固定为 `Asia/Shanghai` 和 `en_US.UTF-8`。
- DNS 管理菜单中要保留恢复原配置选项。
- 修改 DNS 前应展示当前配置。

## 15. 更新逻辑

- 脚本更新成功后不能继续停留在旧进程菜单。
- 更新成功后应重新进入新版脚本。
- 更新失败时要尝试 GitHub 仓库 fallback。
- 国内机器 fallback 使用 `gh-proxy.com/raw.githubusercontent.com/...`。
- 用户已明确不需要更新成功后的备份逻辑。

## 16. SSH / UFW / fail2ban

- 修改 SSH 配置时要避免锁死当前连接。
- SSH 端口不能写死，必须检测当前 sshd 实际端口。
- fail2ban 的 sshd jail 端口必须跟随当前 SSH 端口。
- UFW 管理名称统一为“UFW管理”。
- SSH 管理名称统一为“SSH管理”。
- fail2ban 安装后要启动并设置开机自启。
- fail2ban 卸载时要删除配置目录和状态目录。

## 17. WARP / rclone / Bitwarden / crontab

- WARP 管理必须提供彻底删除选项。
- rclone 管理、Bitwarden 管理、crontab 同步脚本管理属于一组。
- Bitwarden 配置 rclone.conf 后必须验证 `[BitwardenBackup]`。
- Bitwarden 备份必须检测 `upload backup file to storage system`。
- Bitwarden 还原前要列出远程备份文件，最新的排最前。
- crontab 同步脚本统一放到 `/root/linux-daimon/backup-sh`。
- crontab 同步脚本日志统一放到 `/var/log/rclone`。
- 自定义脚本名要自动补全 `.sh` 后缀。
- 不得在普通操作前自动创建持久化 `.bak`、迁移备份或还原前备份；仅保留用户主动触发的备份流程和必要的短生命周期临时文件。

## 18. SSL / Nginx

- SSL/Nginx 管理使用用户指定脚本内容，不再使用旧实现。
- SSL/Nginx 二级菜单顶部要显示已有 Nginx 配置。
- Nginx 配置下方用分隔符显示已有证书。
- 子脚本必须有 `0` 返回选项。
- 证书申请、证书删除、Nginx 配置、测试页管理要分开。

## 19. 常见困难

- 第三方脚本内部可能再次下载 GitHub 资源，外层代理不一定生效。
- `.bashrc` 中多个工具会互相影响，尤其 starship、fzf、ble.sh、bat。
- 菜单层级多，`0` 返回逻辑容易误触 `break_end`。
- Windows PowerShell 读取 UTF-8 文件时可能显示乱码，但文件本身不一定损坏。
- 国内机器访问 GitHub 不稳定，需要多代理 fallback。
- apt 安装可能弹出 needrestart 或配置文件交互，一键配置要避免阻塞。
- 已安装工具和已配置状态不是一回事，必须分别检测。
- `.bashrc` 写坏会导致用户每次登录都报错，必须做失败保护。

## 20. 当前解决方案

- 用统一下载函数处理 GitHub 代理。
- 用配置块标记处理重复安装和卸载清理。
- 用安装后检测避免假成功。
- 用 `exec bash` 替代频繁 `source ~/.bashrc`。
- 用 `country=CN` 分流国内外逻辑。
- 用 README 和 COMMANDS 固化菜单顺序、命令来源和第三方脚本来源。
- 用 `bash -n` 和 `git diff --check` 作为最低检查线。
