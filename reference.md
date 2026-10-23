# 自建 VPN 参考

OpenVPN Access Server 看下面这一节。3x-ui 看订阅客户端这一节。

## OpenVPN Access Server：服务器指令形状

写在 Server Config Directives。下面是形状，不是可复制的生产清单：

```
block-ipv6
push "route 223.5.5.5 255.255.255.255 net_gateway"
push "route 119.29.29.29 255.255.255.255 net_gateway"
# 2026-09-21 示例站点，仅大陆地址
push "route 118.25.83.0 255.255.255.0 net_gateway"
```

保存后 **Update Running Server**。客户端断开再连。

## 验收命令（macOS）

出口：

```bash
curl -4 -sS https://ip.sb
```

某地址走哪张网卡：

```bash
route -n get 118.25.83.245
```

物理网卡（常见 `en0`）且网关是家里路由器：直连。接口是 `utun*`：仍在隧道里。

数一数经家里网关的路由时，除国内网段外，通常还有一条到 VPN 服务器本身。

## 误判

| 看到的现象 | 实际含义 |
| --- | --- |
| `ip.sb` 不是 VPS | 没连上，或另一套 TUN 在抢默认路由 |
| 百度、淘宝慢，解析在香港 | DNS 在出口上选了海外 CDN，网段规则没覆盖这个 IP |
| 固定国内源站走 `en0`，百度走 `utun` | 分流在工作 |
| 改了 `.ovpn` 再重下配置 | 手写 `route` 被冲掉，而且 Connect 本来也会忽略它们 |
| 全隧道开关被改成 No | 海外也不走 VPN |

## OpenVPN Access Server 已经否定的做法

- 把国内 DNS 设成客户端第一解析器。
- 在客户端配置或 `.ovpn` 里写 `route … net_gateway` 来做分流。
- 用系统 VPN 配置页代替 OpenVPN Connect。
- 把上一台机器的网段清单原样贴到新出口。

## 3x-ui：内核参数形状

只在丢包线路上、并且已经确认瓶颈是发送速率之后再写。BBR 只影响 TCP 的 Reality，不影响 Hysteria2。

`/etc/sysctl.d/99-bbr.conf`：

```
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
```

`/etc/sysctl.d/98-udp-tune.conf`。最大收发缓冲 32MB，默认 4MB：

```
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.core.rmem_default = 4194304
net.core.wmem_default = 4194304
net.core.netdev_max_backlog = 16384
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
```

Hysteria2 入站：`up` 和 `down` 都是 `50`，`ignoreClientBandwidth` 打开。保存后执行 `systemctl restart x-ui`，再核对 `/usr/local/x-ui/bin/config.json` 里这三项。重启前退出客户端。服务器这两项管的是发往客户端的速率。

客户端上传写在 Hysteria2 节点的 `up`，例如 `50 Mbps`。没写时走 BBR。Clash 把这一行放进订阅的增强脚本，刷新后还在。加载订阅后核心才生效。小火箭要在节点里另填。

Hysteria2 一阵好一阵断、坏包只出现在大包上时，入站和发出两个方向都要限制。下面的 `8444` 和 `1400` 是这一套留下的值。下一台机器先抓包：入站丢弃阈值要高于 QUIC 初始包（这一套大约 1308），低于路上把包切开的大小（这一套大约 1460）。

入站用防火墙。发出方向写进 Hysteria2 入站的 `streamSettings`，然后重启 x-ui，再核对 `config.json`：

```json
"finalmask": { "quicParams": { "disablePathMTUDiscovery": true } }
```

关掉探测后，这一套服务器发出的 UDP 载荷停在 1280。不要对发出方向做长度丢弃。

```
iptables -C INPUT -m comment --comment hy2-mtu-cap -j DROP 2>/dev/null || \
iptables -I INPUT 1 -p udp --dport 8444 -m length --length 1401:65535 \
  -m comment --comment hy2-mtu-cap -j DROP
```

`/etc/systemd/system/hy2-mtu-cap.service`，然后 `systemctl daemon-reload` 和 `systemctl enable --now hy2-mtu-cap.service`：

```
[Unit]
Description=Drop oversized inbound Hysteria2 UDP packets
After=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'iptables -C INPUT -m comment --comment hy2-mtu-cap -j DROP 2>/dev/null || iptables -I INPUT 1 -p udp --dport 8444 -m length --length 1401:65535 -m comment --comment hy2-mtu-cap -j DROP'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

改规则时客户端先切到 Reality。虚拟网卡开着时，SSH 也在隧道里。验收看 `nstat -az UdpInCsumErrors` 在传输期间不涨，再用延迟测试和固定大小的下载、上传看速率。

上传测速：

```bash
curl -4 -o /dev/null -w "time:%{time_total} upload_Bps:%{speed_upload} bytes:%{size_upload}\n" \
  -X POST --data-binary @/tmp/up10.bin \
  https://speed.cloudflare.com/__up
```

10MB 文件是 10000000 字节，30MB 是 30000000 字节。出口用 `curl -4 -sS https://ip.sb` 核对。

## 3x-ui 误判

| 看到的现象 | 实际含义 |
| --- | --- |
| 订阅导入失败，或管理页 `ERR_EMPTY_RESPONSE` | 先完全退出 Clash。虚拟网卡会把访问面板的流量拐进尚未配好的节点 |
| 管理页 `ERR_SSL_PROTOCOL_ERROR` | 地址用 `http://`。这个面板没有 TLS |
| 管理页超时 | 防火墙没放行面板 TCP、订阅 TCP、Reality TCP 或 Hysteria2 UDP。UDP 要单独放行 |
| Reality 延迟 Timeout，端口是 `443` | 换到专用 TCP 端口。`443` 上还有别的 TLS 时，Reality 认证会失败 |
| Hysteria2 延迟 Timeout | UDP 没放行，或小火箭没开「允许不安全」 |
| Hysteria2 一阵好一阵 Error 或 Timeout，Reality 同时正常 | 满尺寸 UDP 包在路上被切开后拼错。看服务器 `UdpInCsumErrors` 是否只在大包上涨。修在服务器，丢掉超长的入站 UDP |
| 延迟是绿色的，`ip.sb` 仍是家里宽带 | 模式不是规则，或节点停在 DIRECT，或系统代理和虚拟网卡都没开 |
| 延迟正常，视频卡或网页打不开 | 还在用 Reality。切到 Hysteria2。短请求延迟不代表带宽 |
| 下载已经很快，上传仍慢，30MB 比 10MB 更慢 | 客户端 Hysteria2 没有 `up`，上传在走 BBR。服务器忽略客户端带宽只影响下载 |
| 只有浏览器走代理 | 开的是系统代理。整台电脑改开虚拟网卡 |
| 扫了下面那张 VLESS 码 | 只有一条节点，没有大陆直连规则 |

## 3x-ui 已经否定的做法

- 把 Reality 放在 `443`，而这台机器的 `443` 上还有别的 TLS。
- 用 Reality 当日常节点硬扛两成左右的丢包。
- 用绿色延迟代替固定大小下载来判断视频卡不卡。
- 只在面板里保存 Hysteria2 的 `up` / `down` / `ignoreClientBandwidth`，不重启 x-ui 就当它已经生效。
- 以为忽略客户端带宽就覆盖了上传，于是客户端不写 `up`。没写 `up` 时上传走 BBR。
- 只改下载到的订阅或 `.yaml`，不写进增强脚本。刷新会把 `up` 冲掉。
- 用一次 10MB 的尖峰决定 `up`。以 30MB 的有效速率为准，持平或变慢就退回上一档。
- 为了改客户端 `up` 去重启 x-ui。
- 虚拟网卡还开着、当前节点就是要重启的那条时，直接 `systemctl restart x-ui`。
- 把订阅链接、面板路径或管理员密码写进技能。
- 用 mihomo 的 `udp-mtu` 去缩小 Hysteria2 的 QUIC 包。它只切被代理的 UDP 数据，默认已经是 1197。
- 在 macOS 上指望配置文件关掉 Hysteria2 的路径 MTU 探测。sing-quic 在 darwin 上会强制打开。
- 换一个关掉探测的 mihomo 内核来躲过大包。只对这一台电脑有效，Clash Verge 更新会盖掉。
- 用网卡 MTU 或到服务器的主机路由 MTU 去限制这条 UDP。路由限制不住；网卡改小后电脑自己分片，到服务器照样拼错。
- 把超长 UDP 的丢弃阈值降到 QUIC 初始包以下。这一套降到 1300 时，握手一起被丢。
- 对服务器发出的 Hysteria2 UDP 做长度丢弃。握手回应被丢，节点连不上。发出方向关掉路径 MTU 探测。
- 只丢掉超长的入站包，不限制服务器发出的包。下载方向仍是满尺寸，线路差时会掉到每秒几 KB。
