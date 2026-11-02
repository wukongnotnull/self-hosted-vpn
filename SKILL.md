---
name: self-hosted-vpn
description: 部署或排查两种已验证的自建 VPN：OpenVPN Access Server，或 3x-ui/Xray + Hysteria2 + VLESS Reality。用于大陆直连分流、订阅、Clash Verge/Meta/小火箭、UDP Timeout、Reality Error、慢速和连接记录。不要用于一般 VPN 产品比较、无关的 Xray 配置，或要求改成 WireGuard 的任务。
---

# 自建 VPN

只支持两种架构：

1. **OpenVPN Access Server**：用户名密码连接；海外流量走服务器，大陆 IP 网段由服务器推送后直连。
2. **3x-ui**：订阅分发；大陆 IP 和大陆域名直连，其余走节点；Hysteria2 日常使用，VLESS + Reality 备用。

不要擅自改成 WireGuard、系统 VPN 或第三套协议。用户未选方案时，只解释差别并等待选择。

## 安全边界

- 默认使用 SSH 密钥、普通用户和按需 `sudo`。不要让用户把 root 密码、私钥、订阅令牌或面板密码贴进聊天。
- 首次 SSH 必须核对主机指纹。不要用 `StrictHostKeyChecking=no` 绕过。
- 管理面默认只监听本机、通过 SSH 隧道访问，或由云防火墙限制到管理员来源。不要把明文 HTTP 面板直接暴露给全网。
- 任何修改先记录当前状态和回滚命令。重启、改防火墙、改端口、改数据库或覆盖配置前必须明确确认。
- 一次只做一个可逆变更，立即验收；失败就回滚，不叠加猜测性修复。
- Hysteria2 自签证书需要客户端跳过校验时，只对该节点生效，并说明中间人风险。不要全局关闭 TLS 校验。
- 不把某次部署的 IP、端口、证书、账号、密钥、速率或 MTU 当作下一次部署的默认值。

## 执行状态机

### 1. 明确目标

用户还没选方案时，问：

- **OpenVPN Access Server**：OpenVPN Connect，用户名密码；按 IP 分流。
- **3x-ui**：订阅；Clash Verge Rev / Clash Meta / 小火箭；按 IP 和域名分流。

用户已在使用其中一种时沿用，不主动迁移。

### 2. 盘点环境

变更前收集并脱敏记录：

- 服务器提供商、系统与版本、CPU 架构、当前用户和 sudo 能力。
- IPv4/IPv6 地址与默认路由；云防火墙和系统防火墙。
- 已占用端口、现有 Web/TLS 服务、面板和代理服务状态。
- 客户端系统、客户端版本、TUN/系统代理状态及是否存在另一套 VPN。
- 恢复入口：独立 SSH 路径、控制台/VNC、快照或配置备份。

优先运行 `scripts/preflight.sh`。环境不在已验证矩阵、缺少恢复入口或信息互相矛盾时停止，不猜。

### 3. 选择路径

- OpenVPN 部署与分流：读 [references/openvpn.md](references/openvpn.md)。
- 3x-ui 部署、订阅和客户端：读 [references/3xui.md](references/3xui.md)。
- Hysteria2 慢、Error、Timeout：读 [references/hy2-diagnostics.md](references/hy2-diagnostics.md)。
- Reality Error、Timeout 或慢：读 [references/reality-diagnostics.md](references/reality-diagnostics.md)。
- 事后记录连接失败：读 [references/connection-logging.md](references/connection-logging.md)。
- 已验证但不可复制的实测数据：读 [references/case-studies.md](references/case-studies.md)。

不要一次加载所有参考文件。只读当前分支需要的文件。

### 4. 只读预检

先形成证据，再提出修改：

- 服务是否运行、监听协议是否正确。
- 云防火墙和系统防火墙是否按 TCP/UDP 分开允许。
- 客户端请求是否到达服务器，服务器回应是否离开。
- 问题是认证、单向回程、大包损坏、TUN 抢路由，还是吞吐限制。
- 当前配置是否来自面板数据库、模板、运行时文件或客户端增强脚本。

诊断脚本只读并输出人类摘要与 JSON。报告默认脱敏。没有证据时不要把客户端 `Error` 归因于密码、MTU 或防火墙。

### 5. 提案与确认

执行前向用户说明：

- 要改什么、为什么。
- 预计中断和风险。
- 备份位置与回滚命令。
- 验收信号。

用户确认后才执行。若 SSH 正走即将重启的节点，先切到不受影响的备用路径。

### 6. 单步实施

- 面板管理的配置写回面板或数据库支持的接口，不只改运行时文件。
- 客户端刷新会覆盖的值写入增强脚本，不只改下载的 YAML。
- 防火墙规则同时考虑云侧和系统侧，并按地址族区分 IPv4/IPv6。
- 每一步保留前态，失败立即回滚。

### 7. 验收

不能只看绿色延迟。至少验证：

1. 目标节点真实被选中，出口是目标服务器。
2. 大陆流量按所选方案直连。
3. 固定大小下载完成；涉及上传时使用 30MB 以上样本。
4. 服务重启后配置仍在，订阅刷新后客户端覆盖仍在。
5. 错误计数、日志和抓包与预期一致。
6. 备用节点和恢复入口仍可用。

优先运行 `scripts/acceptance.sh`。不满足任一关键条件就标记未完成。

## 故障入口

| 现象 | 先查 |
| --- | --- |
| Hysteria2 一直 Timeout，Reality 正常 | UDP 是否到达；小包回应是否能回客户端；证书跳过是否仅对该节点启用 |
| Hysteria2 一阵好一阵断 | `UdpInCsumErrors` 是否只随大包上涨；不要先改密码 |
| Hysteria2 下载快、上传越传越慢 | 客户端是否缺少固定 `up`；用 30MB 测试 |
| Reality 一直 Error，Hysteria2 正常 | TCP 三次握手回程、端口占用、Reality 参数 |
| 延迟绿色但网页或视频卡 | 固定大小传输、真实出口和当前节点 |
| `ip.sb` 仍是家宽 | 模式、节点选择、系统代理/TUN |
| 管理页或订阅打不开 | 完全退出未配置好的 TUN；核对 HTTP/HTTPS 和云防火墙 |

## 交付

- 只给用户必要的客户端说明，不交付管理员密码或私钥。
- 写明已验证版本、日期、支持范围和未验证项。
- OpenVPN 变更后让客户端断开重连；3x-ui 变更后让客户端刷新订阅并重新加载核心。
- 最终报告包含：改动、证据、验收结果、回滚方式和仍存在的限制。
