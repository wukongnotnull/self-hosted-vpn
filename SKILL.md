---
name: self-hosted-vpn
description: 在用户要自建 VPN、国内直连或分流、按域名规则分流、给设备发订阅时使用。也在提到 OpenVPN Access Server、OpenVPN Connect、net_gateway、3x-ui、Xray、Hysteria2、VLESS、Reality、Clash Verge、Clash Meta、小火箭时使用。用户还没指定方案时，先给出 OpenVPN Access Server 和 3x-ui 两种选择。
---

# 自建 VPN

只复用下面两种已验证的方案。不要改成 WireGuard 或系统自带 VPN。

用户还没指定用哪一种时，先把这两种摆出来，等用户选，不要替他定成 OpenVPN Access Server。已经在用其中一种时，沿用那一种，除非用户要换。

已有部署的 IP、证书、订阅链接、面板账号和网段清单属于那一次部署。新机器重新取，不要从旧仓库或手册抄进技能。

| | OpenVPN Access Server | 3x-ui |
| --- | --- | --- |
| 适合 | 一份客户端，用户名密码连接 | 按域名规则分流，或每人一条订阅（含手机） |
| 软件 | OpenVPN Connect | Xray + Clash Verge Rev / Clash Meta for Android / 小火箭 |
| 分流 | 服务器推送大陆网段，命中后走家里宽带 | 客户端规则：大陆 IP 和大陆域名直连，其余走节点 |

两种可以装在不同机器上，互不替代。用户选定之后，只按对应章节做。

## 怎么选

问用户要哪一种，并用这两句说明差别：

1. **OpenVPN Access Server**：装 OpenVPN Connect，用用户名和密码连接。海外走服务器，大陆网段由服务器推送后直连。分流看 IP，不看域名。
2. **3x-ui**：管理员发订阅链接，电脑用 Clash Verge Rev，安卓用 Clash Meta，iPhone 用小火箭。大陆 IP 和大陆域名直连，其余走节点。日常节点是 Hysteria2。

## OpenVPN Access Server

- 服务端：OpenVPN Access Server。管理后台 `https://<服务器>:943/admin`，用户从 `https://<服务器>:943/` 下载 User-locked Profile。
- 客户端：OpenVPN Connect。不要用系统「VPN」设置页手填。
- 传输：优先 UDP 1194；家宽拦截 UDP 时走 TCP 443。
- 全隧道保持打开。后台 **Should client Internet traffic be routed through the VPN?** 必须是 **Yes**。关掉之后海外流量也不会进 VPN。
- 分流按 **IP 网段**，不按域名。

安装包和许可证以 OpenVPN 官方 Access Server 文档为准。不要凭记忆写安装命令。装完后用下面的规则收口。

### 分流写在哪里

国内直连只写在：

**Configuration → Advanced VPN → Server Config Directives**

```
push "route <网络> <掩码> net_gateway"
```

保存后点 **Update Running Server**。客户端断开再连，推送才会生效。

不要写这些位置：

- `.ovpn` 里的 `route`。OpenVPN Connect 3.8（核心 3.11）会丢掉这些行。重新从门户下载也会冲掉手改的文件。
- **Client Config Directives**。这里的内容会进下载的 `.ovpn`，然后被客户端丢掉。

`block-ipv6` 放在同一处服务器指令里，避免 IPv6 绕过 IPv4 分流。

### 怎么选网段

在 **VPN 出口**上解析目标域名。客户端的 DNS 走服务器，看到的 A 记录是出口视角，不是家里宽带的视角。

1. 只收录中国大陆地址。同一站点的香港、新加坡、美国 CDN 留在 VPN 上。
2. 每条 `push` 前注释站点名和日期。CDN 会变，清单不是永久名单。
3. 固定国内 IP 的站（自有源站）用来验收。百度、淘宝、知乎经常解析到名单外的海外节点，它们走 VPN 是预期结果。

某次部署的网段文件只说明写法，不能原样贴到下一台服务器。

### DNS

继续用服务器原来的解析器。不要把 `223.5.5.5` 或其他国内 DNS 推成客户端默认 DNS。

已经失败过一次：把 `223.5.5.5` 推到第一位后，Google 被解析到错误地址并超时，随后撤回。

可以另推两条主机路由，只表示「允许直连查这两台」，不表示改默认 DNS：

```
push "route 223.5.5.5 255.255.255.255 net_gateway"
push "route 119.29.29.29 255.255.255.255 net_gateway"
```

### 验收

先关掉 Clash 和其他 TUN。然后看两个信号，缺一不可：

1. 打开 `https://ip.sb`，出口是这台 VPS 的公网 IP。
2. 找一个 A 记录落在已推送网段里的国内站，查路由应走物理网卡网关，不走 `utun`。

百度变慢、解析到香港，不能当成分流失效。网关和服务器公网 IP 通常禁 ping，不要用 ping 服务器来判断隧道。

## 3x-ui

分流在客户端，不是服务器推送路由。这不是全隧道。

- 面板：3x-ui。管理页是明文 HTTP，不要写成 `https://`。订阅用面板自带端口（这套是 `2096`）。
- 协议进程：Xray。同一用户两条节点。日常用 Hysteria2（UDP）。备用是 VLESS + Reality（TCP）。
- 电脑和安卓内核是 mihomo，装在 Clash Verge Rev、Clash Meta for Android 里。iPhone 用小火箭，不是 mihomo，导入同一用户的订阅。
- 装 Clash Verge Rev，不是已经停更的旧版 Clash Verge。Mac 选带 `aarch64` 的包（Apple 芯片），Windows 选 `x64-setup.exe`。关于页版本应是 2.5 以上。

日常节点是 Hysteria2。手册或界面里若仍写着日常选 Reality，以丢包线路上的实测为准：Reality 留作备用。

### 节点

| | Hysteria2 | VLESS + Reality |
| --- | --- | --- |
| 端口 | 单独的 UDP。这套用过 `8444` | 单独的 TCP。这套用过 `8443`。不要放 `443`：该端口上若还有别的 TLS，从家里连过去时 Reality 认证会失败 |
| 参数 | SNI `www.bing.com`，ALPN `h3`，证书自签 | 流控 `xtls-rprx-vision`，伪装站点 `www.cloudflare.com`。客户端握手要带 `X25519MLKEM768`，否则延迟一直 Timeout |
| 证书 | Clash 订阅里带 `skip-cert-verify: true`。小火箭链接不带这个参数，要在节点里手动打开「允许不安全」 | 认证对不上时，服务器不把流量接进代理，客户端表现为连不上 |

防火墙要放行：面板 TCP、订阅 TCP、Reality 的 TCP、Hysteria2 的 UDP。UDP 单独一条，协议选 UDP。

### 规则

订阅里大陆规则在前，末尾才是代理：

```
GEOIP,CN,DIRECT
GEOSITE,CN,DIRECT
MATCH,PROXY
```

小火箭默认配置末尾是 `GEOIP,CN,DIRECT` 然后 `FINAL,PROXY`。`FINAL` 必须在最后。

客户端模式选 **规则**。右上角选「全局」或「直连」时，大陆规则不生效。小火箭底部 **全局路由** 选 **配置**；选「代理」会全部走节点，选「直连」则规则不生效。

一个用户两张二维码。用上面「订阅信息」，选项卡停在 **标准**。不要用 Happ 加密链接，也不要用下面那张只有一条 VLESS 的码（没有分流）。

### 丢包线路

家宽到服务器丢包大约两成、往返大约 160–200 ms 时，绿色延迟只量一条短请求，不能用来判断视频卡不卡。用固定大小下载看字节每秒，例如 `https://speed.cloudflare.com/__down?bytes=30000000`，并确认出口仍是这台服务器的公网 IP。MB/s × 8 = Mbps。

按这个顺序做，不要先改客户端：

1. 延迟正常但视频转圈：先测下载。TCP 节点在 cubic 下会掉到几十 KB/s。
2. 只给 TCP 开 BBR（`fq` + `bbr`）。Hysteria2 不走这条。BBR 后 Reality 仍可能只有几百 KB/s，不够日常视频。
3. 日常改走 Hysteria2，并放行它的 UDP。
4. 加大 UDP 收发缓冲，避免服务器丢掉一串 UDP 包。
5. 在 3x-ui 里把 Hysteria2 入站的上下行都填成固定速率（这套填过 `50`），打开忽略客户端带宽（`ignoreClientBandwidth`），然后 `systemctl restart x-ui`。面板保存后，运行中的 `/usr/local/x-ui/bin/config.json` 可能还是旧值，重启后再核对这三项。订阅里不必写 `up`/`down`。

填的 `50` 不是实测上限。这套在忽略客户端带宽之后，30MB 下载到过大约 14–17 MB/s。

重启 x-ui 之前，先退出客户端或把节点改成直连。虚拟网卡开着且当前节点就是这条 UDP 时，SSH 也在隧道里，服务一重启连接会被掐断。

sysctl 形状见 [reference.md](reference.md)。

网页仍可能慢：每个新连接的 TLS 来回消不掉。下载速度上去不等于首页立刻快。

### 导入和开关

打开管理页或导入订阅之前，完全退出 Clash Verge，包括菜单栏图标。虚拟网卡开着时，访问面板和订阅会被拐进还没配好的节点。

电脑：首页节点选 Hysteria2，不要选 DIRECT，模式选规则。系统代理只覆盖会读系统代理的软件；整台电脑走规则时开虚拟网卡。节点延迟变绿之后再开虚拟网卡。要打开管理页时先关虚拟网卡。

iPhone：给 Hysteria2 打开「允许不安全」。SNI 应是 `www.bing.com`，ALPN 应是 `h3`。小火箭对这条 UDP 节点测延迟经常是空白，以 `ip.sb` 和页面能否打开为准。不要用 Reality 当日常节点：连通性测试可以是两百多毫秒，网页却传不动。

### 验收

1. 规则模式，节点是 Hysteria2，系统代理或虚拟网卡已开。`https://ip.sb` 是这台服务器的公网 IP。
2. 落在大陆 IP 或大陆域名上的站不进节点。

`ip.sb` 仍是家里宽带：节点停在 DIRECT，或模式成了直连，或两个开关都没开。百度变慢，多半是解析到了香港或海外，不能单独当成规则坏了。

## 交给用户的手册

手册只写用户侧。

OpenVPN Access Server：服务器地址、UDP 1194 / TCP 443、用 OpenVPN Connect 导入 User-locked Profile、分流看 IP 不看域名、用 `ip.sb` 和一个固定国内站验收。

3x-ui：订阅链接、客户端是 Clash Verge Rev / Clash Meta / 小火箭、日常节点是 Hysteria2、模式用规则（小火箭全局路由用配置）、小火箭要给 Hysteria2 开「允许不安全」、用 `ip.sb` 验收。

不要写管理员密码，不要把含私钥的 `.ovpn`、订阅链接或面板账号放进仓库、技能或群。OpenVPN 改分流后告诉用户断开再连，不必重下配置。3x-ui 在面板里改节点后，让用户刷新订阅。
