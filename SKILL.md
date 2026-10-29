---
name: self-hosted-vpn
description: 在用户要自建 VPN、国内直连或分流、按域名规则分流、给设备发订阅时使用。也在提到 OpenVPN Access Server、OpenVPN Connect、net_gateway、3x-ui、Xray、Hysteria2、VLESS、Reality、Clash Verge、Clash Meta、小火箭时使用。Hysteria2 下载正常但上传慢、或上传越传越慢时也使用。Hysteria2 隔一段时间变成 Error 或 Timeout、而 Reality 仍然正常时也使用。Reality 延迟是 Error 或 Timeout、而 Hysteria2 仍然正常时也使用。用户要服务器记下客户端的 Error 或 Timeout、以便事后排查时也使用。用户还没指定方案时，先给出 OpenVPN Access Server 和 3x-ui 两种选择。
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
| 端口 | 单独的 UDP。这套用过 `8444` | 单独的 TCP。这套先用过 `8443`，后来改到 `443`。`443` 上若还有别的 TLS，从家里连过去时 Reality 认证会失败。`443` 空着、而专用端口的握手回包回不到家里时，可以改到 `443`。不要改到订阅端口上 |
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
5. 在 3x-ui 里把 Hysteria2 入站的上下行都填成固定速率（这套填过 `50`），打开忽略客户端带宽（`ignoreClientBandwidth`），然后 `systemctl restart x-ui`。面板保存后，运行中的 `/usr/local/x-ui/bin/config.json` 可能还是旧值，重启后再核对这三项。这只固定服务器发往客户端的速率，也就是下载。

填的 `50` 不是下载实测上限。这套在忽略客户端带宽之后，30MB 下载到过大约 14–17 MB/s。

### 上传

下载已经固定速率、上传仍慢，而且 30MB 比 10MB 更慢：客户端 Hysteria2 没有 `up`，发送走 BBR。`ignoreClientBandwidth` 不会把客户端改成固定速率。

在客户端节点写 `up`。Clash 刷新订阅会冲掉手改的节点，所以写进 Clash Verge 的增强脚本。小火箭不读这份脚本，要在节点里单独填上传速率。

脚本只改 `type` 为 `hysteria2` 的节点。下面的 `50 Mbps` 是这一套留下的值，下一台机器用自己测出来的数：

```javascript
function main(config, profileName) {
  for (const proxy of config.proxies || []) {
    if (proxy && proxy.type === "hysteria2") {
      proxy.up = "50 Mbps";
    }
  }
  return config;
}
```

字符串要带单位。mihomo 把没有单位的数字当成 Mbps。

改完在 Clash Verge 里重新加载这份订阅，让正在跑的核心读到 `up`。只改脚本、核心仍是旧配置时，测速不会变。这一步不用重启 x-ui。

测上传向 `https://speed.cloudflare.com/__up` 发 POST。10MB 是 10000000 字节，30MB 是 30000000 字节。前后都看 `https://ip.sb`，必须仍是这台服务器。`speed_upload` 是字节每秒：除以 1000000 得 MB/s，再乘 8 得 Mbps。用 30MB 判断有没有越传越慢，不用单次 10MB 的尖峰。

`up` 先设在当时 30MB 速率附近，再往上加一档。30MB 的有效速率还在涨，就再抬。30MB 持平或变慢，退回上一档。

这一套没写 `up` 时，10MB 大约 2 Mbps，30MB 低于 1 Mbps。写成 `50 Mbps` 后，10MB 和 30MB 都大约 27 Mbps。`80 Mbps` 有过一次 10MB 到 49 Mbps，30MB 复测更慢。`150 Mbps` 的 10MB 回到二十多 Mbps。留下 `50 Mbps`。

第 5 步要重启 x-ui 时，先退出客户端或把节点改成直连。虚拟网卡开着且当前节点就是这条 UDP 时，SSH 也在隧道里，服务一重启连接会被掐断。改客户端 `up` 不用做这一步。

sysctl 形状见 [reference.md](reference.md)。

### 一阵好一阵断

Hysteria2 隔一段时间延迟变成 Error 或 Timeout，同一时刻 Reality 仍正常：先看服务器是不是在收坏掉的大包。不要先改客户端，也不要先改家里的路由器。

在服务器上抓发往 Hysteria2 那个 UDP 端口的包，并看 `nstat -az UdpInCsumErrors`。这一套的现象是：UDP 载荷 1441 字节（IP 总长 1469）里大约三成校验和已经坏了，600 字节以下的包一个都不坏。Mac 上抓到的同样大包，校验和是好的，所以包是出了电脑之后、进服务器之前坏的。路上有一跳按大约 1460 字节把包切开，分片的 IP 编号全是 0，拼回去时把不同包的尾巴接在一起。上传越多，同时在路上的包越多，越容易拼错，于是一阵好一阵断。TCP 的 Reality 几乎没有这种错误。

Xray 没有一项配置能告诉客户端「包不要超过这么大」。mihomo 的 `udp-mtu` 只切被代理转发的 UDP 数据，不管 QUIC 包本身，默认已经是 1197。在 macOS 上，内核用的 sing-quic 会强制打开路径 MTU 探测，配置文件里关不掉。

两边都要限制，只限制一边不够。客户端发来的大包，在服务器上丢掉超长的入站 UDP。服务器自己发出的包，在 Hysteria2 入站的 `streamSettings.finalmask.quicParams` 里打开 `disablePathMTUDiscovery`。Xray 没有「最大包长」这一项，关掉探测之后发出的包停在初始大小。这一套入站阈值是 IP 总长 1400：高于 QUIC 初始包（大约 1308），低于会被切开的 1460。客户端随后停在 UDP 载荷大约 1371。服务器发出的包停在 UDP 载荷 1280。入站规则做成开机自动加上。形状见 [reference.md](reference.md)。

改完要 `systemctl restart x-ui`，再核对运行中的 `config.json` 里这两处都在。面板如果按自己的结构重写 `stream_settings`，确认 `finalmask` 还在。

改的时候如果 SSH 正走这条 UDP，先把客户端切到 Reality。虚拟网卡开着时，到服务器的 SSH 也在隧道里。

改完传一截数据，`UdpInCsumErrors` 不涨，延迟测试能过，并且服务器发出的包不再出现 1441 字节。只限制入站时，上传正常，下载仍会在线路差的时候掉到每秒几 KB，因为服务器还在发 1441 字节。这一套两边都限制之后，20MB 下载大约 38 Mbps，10MB 上传大约 31 Mbps。只限制入站时下载曾经到过 30–42 Mbps，上传大约 27 Mbps；限制之前坏包大约 29%。

不要做这些：

- 把阈值降到初始包以下。这一套丢过超过 1300 的入站包，握手一起被丢，节点完全连不上。
- 用防火墙丢服务器发出去的大包。握手的回应一起被丢，节点连不上。发出方向用 `disablePathMTUDiscovery`，不要用长度丢弃。
- 改电脑网卡的 MTU，或只给服务器地址加一条小 MTU 的路由。路由上的 MTU 限制不住这条 UDP。网卡 MTU 改小之后，电脑自己把大包切开，到服务器照样拼错。
- 换一个关掉路径 MTU 探测的 mihomo。只对这一台电脑有效，Clash Verge 更新内核会把它盖掉。

网页仍可能慢：每个新连接的 TLS 来回消不掉。下载速度上去不等于首页立刻快。

### Reality 一直 Error

Hysteria2 延迟正常，Reality 一直是 Error 或 Timeout：先看 TCP 握手回不回得来，不要先改密钥或 `X25519MLKEM768`。密钥和 `X25519MLKEM768` 对不上时，服务器同样不接进代理，客户端也是连不上；两种要分开。

虚拟网卡开着时，到服务器地址的路由会走 `utun`，网关是 `198.18.0.1`。这时本机 `nc` 显示连上，只说明 Clash 收下了这个连接。要看端口本身，用物理网卡的地址当源地址去连，例如 `nc -s <物理网卡地址> -G 5`。SSH 同样绑这个地址，服务器上的 `SSH_CLIENT` 应是家里的公网地址。绑不上、`SSH_CLIENT` 仍是服务器自己时，这条 SSH 还在隧道里。

在服务器上抓 Reality 那个 TCP 端口。家里发来的 SYN 到了，服务器发出 SYN-ACK，客户端却一直重传 SYN、没有 ACK：回程被丢掉，不是认证失败。这一套的 `8443` 就是这样；同一时刻订阅端口 `2096` 和空着的 `443` 握得成。`2053`、`2083`、`2087` 这一组也握不成。

换端口之前先在服务器上临时监听，仍用物理网卡源地址从家里试。握得成、而且上面没有别的 TLS 的端口才能用来放 Reality。订阅端口握得成也不能占用。这一套把 Reality 从 `8443` 改到空着的 `443` 之后，延迟测试大约 163 ms。

端口写在面板的入站上，再 `systemctl restart x-ui`，核对运行中的 `config.json`。只改 `config.json` 会被面板用数据库里的入站盖掉。Reality 正是坏的那条时，不要为了重启先把客户端切到 Reality。SSH 绑物理网卡地址，重启掐断 UDP 之后仍能连回去。改完让客户端刷新订阅。只改本机已经导入的配置，下次刷新还会变回旧端口。

### 连接记录

要事后查客户端的 Error 或 Timeout，记客户端和服务器之间的连接，不要开 Xray 访问日志。访问日志记的是进了代理之后的目标网站，而且握手没完成的连接不会出现在里面。

面板默认把 Xray 访问日志设成 `none`，错误日志路径是空的，级别是 `warning`。`/var/log/x-ui/3xui.log` 只有面板和 Xray 的启动。握手没完成时，Xray 一行都不会写。Reality 认证失败也常常不写。

两份日志：

- `/var/log/x-ui/error.log`：Xray 自己打出的 warning 和 error。写在面板设置的 `xrayTemplateConfig` 里，`error` 用 `error.log`，级别保持 `warning`。面板会把这个文件名放到 `/var/log/x-ui/`。改完重启 x-ui，再看运行中的 `config.json`。只改 `config.json`，下次重启会被模板盖掉。
- `/var/log/x-ui/conn.log`：每一条打到 Reality 的 TCP 和 Hysteria2 的 UDP、且目标地址是这台服务器自己的连接。出去访问伪装站点的 `443` 不要记。需要安装 `conntrack`，并打开 `net.netfilter.nf_conntrack_acct`。形状见 [reference.md](reference.md)。

`conn.log` 里用结果分辨原因：

- `event=up`：握手完成。
- `event=down result=closed`：这条连接结束，带 `duration_s`。UDP 结束时还有 `host_udp_csum_delta`，是这段时间整台机器新增的坏 UDP 包，不是这一条流单独的数。
- `event=down result=handshake_timeout`：TCP 请求到了服务器，握手没完成。客户端这时会显示 Error 或 Timeout。
- `event=down result=no_reply`：UDP 没有形成双向通信。

拿客户端报错的时间去对。有 `handshake_timeout` 或 `no_reply`，就是这次没连上。有 `up` 而客户端仍是 Error，再看同一时刻的 `error.log`。那个时间没有任何记录，说明这次尝试没有到达服务器。

同一家里出口的公网地址相同，Clash Verge 和小火箭只能靠客户端端口区分，日志里没有软件名字。已经保持着的 Hysteria2 会话不会为每次测速另写一行，会话中断或新开时才记。客户端界面上的 Error 原文不会传到服务器。

不要用一分钟一次的计数器代替这份连接记录。计数器看不出会话，单次测速超时也经常够不到阈值。

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
