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

## 3x-ui：Hysteria2 的 IPv4 UDP 回程丢失

先和坏大包区分：

| 信号 | 坏大包 | IPv4 UDP 回程丢失 |
| --- | --- | --- |
| 服务器收到客户端请求 | 是 | 是 |
| 服务器发出回应 | 是 | 是 |
| 几十字节 UDP echo 能回客户端 | 能 | 不能 |
| `UdpInCsumErrors` | 大包传输时上涨 | 保持不变 |
| 修法 | 限制 IPv4 包长和路径 MTU 探测 | 换可用回程；双方支持时让 Hysteria2 单独走 IPv6 |

服务器开启 IPv6 后先核对，不要立刻改订阅：

```bash
ip -6 -brief address show scope global
ip -6 route show default
ss -lunp | grep ':8444'
```

云防火墙另加一条：来源为全部 IPv6 地址，协议 UDP，端口为 Hysteria2 端口。默认生成的 IPv6 规则通常只有 TCP `22`、`80`、`443`、远程桌面和 ICMPv6，不包含 UDP `8444`。云平台可能要重启实例才能开启 IPv6；操作前切到 Reality，并确认 IPv4 不会改变。

先用临时 UDP echo 验证几十字节的 IPv6 请求和回应都能到。客户端若开着 TUN，绑定物理网卡或物理 IPv6；服务器抓包应看到家里的全局 IPv6，不是代理出口。确认回程后，Clash Verge 增强脚本只覆盖 Hysteria2：

```javascript
function main(config, profileName) {
  for (const proxy of config.proxies || []) {
    if (proxy && proxy.type === "hysteria2") {
      proxy.server = "<服务器IPv6>";
    }
  }
  return config;
}
```

YAML 的 `server` 值直接写 IPv6，不加方括号。重新加载正在运行的核心，不能只保存脚本。验收时同时抓服务器：

```bash
tcpdump -ni eth0 'ip6 and udp port 8444'
nstat -az UdpInCsumErrors UdpInErrors
```

客户端延迟要成功，`AUTO` 要选中 Hysteria2，固定大小下载要完成，`ip.sb` 要显示服务器出口，坏包计数不能上涨。订阅若仍发布 IPv4，脚本只对挂载了它的 Clash 客户端生效；手机和其他电脑仍需单独改，或给 Hysteria2 发布独立 IPv6 地址。

不要因为 IPv6 UDP 载荷达到 1441 字节就照搬 IPv4 的长度丢弃规则。IPv6 路由器不做中间分片；先以双向抓包、实际传输和错误计数判断。

## 3x-ui：错误日志和连接记录

Xray 错误日志写在面板设置 `xrayTemplateConfig` 的 `log` 里，不要只改运行中的 `config.json`。`error` 用文件名 `error.log`，面板会把它放到 `/var/log/x-ui/error.log`。访问日志保持 `none`。

```json
"log": {
  "access": "none",
  "dnsLog": false,
  "error": "error.log",
  "loglevel": "warning",
  "maskAddress": ""
}
```

连接记录只看打到本机 Reality TCP 和 Hysteria2 UDP 的流。先安装 `conntrack`，并在 `/etc/sysctl.d/99-conn-log.conf` 里打开计数：

```
net.netfilter.nf_conntrack_acct=1
```

用 `conntrack -E -o timestamp,extended -e NEW,UPDATE,DESTROY` 跟着事件。只留下原始方向的目标地址属于这台服务器、目标端口是这两个入站的流。服务器自己出去访问伪装站点的 `443` 丢掉。握手完成写 `event=up`。流销毁时写 `event=down`，并带 `result`、`state`、`duration_s`。TCP 从未进入 `ESTABLISHED` 时结果是 `handshake_timeout`。UDP 从未变成双向时结果是 `no_reply`。其余是 `closed`。UDP 结束时附上这段时间 `UdpInCsumErrors` 的增量，字段名 `host_udp_csum_delta`。

Hysteria2 改走 IPv6 后，记录程序要同时读取 IPv6 conntrack，并把服务器全局 IPv6 当成本机地址。只记录 IPv4 时，`conn.log` 没有该会话不表示请求没有到达服务器。

一行的形状：

```
2026-10-29T11:42:34+08:00 proto=tcp port=443 src=<客户端> sport=<端口> event=up state=ESTABLISHED
2026-10-29T11:42:42+08:00 proto=tcp port=443 src=<客户端> sport=<端口> event=down result=handshake_timeout state=SYN_RECV duration_s=8.0
```

服务做成开机自启，进程退出就拉起来。日志按天轮转，保留 30 天，用 `copytruncate`。

```
[Service]
ExecStart=/usr/local/sbin/vpn-conn-log
Restart=always
RestartSec=2
```

## 3x-ui 误判

| 看到的现象 | 实际含义 |
| --- | --- |
| 订阅导入失败，或管理页 `ERR_EMPTY_RESPONSE` | 先完全退出 Clash。虚拟网卡会把访问面板的流量拐进尚未配好的节点 |
| 管理页 `ERR_SSL_PROTOCOL_ERROR` | 地址用 `http://`。这个面板没有 TLS |
| 管理页超时 | 防火墙没放行面板 TCP、订阅 TCP、Reality TCP 或 Hysteria2 UDP。UDP 要单独放行 |
| Reality 延迟 Timeout，端口是 `443`，而这台机器的 `443` 上还有别的 TLS | 换到专用 TCP 端口。两个 TLS 叠在同一个 `443` 上时，Reality 认证会失败 |
| Reality 一直 Error 或 Timeout，Hysteria2 正常，密钥和 `X25519MLKEM768` 都对 | 看 TCP 握手。服务器收到 SYN 并发出 SYN-ACK，客户端却没有 ACK：这个端口的回程回不到家里。换一个从家里握得成、且没有别的 TLS 的端口。这一套因此把 Reality 从 `8443` 改到空着的 `443` |
| 本机 `nc` 连 Reality 端口显示成功，路由却走 `utun` | 这是 Clash 收下了连接。用物理网卡地址当源地址再试 |
| 客户端 Error 或 Timeout 的那一秒，`conn.log` 没有记录 | 这次尝试没有到达服务器 |
| `conn.log` 有 `event=up`，`error.log` 仍是空的，客户端仍是 Error | 传输层是通的。Reality 认证失败时 Xray 常常不写日志 |
| Hysteria2 延迟 Timeout | UDP 没放行，或小火箭没开「允许不安全」 |
| Hysteria2 一阵好一阵 Error 或 Timeout，Reality 同时正常 | 满尺寸 UDP 包在路上被切开后拼错。看服务器 `UdpInCsumErrors` 是否只在大包上涨。修在服务器，丢掉超长的入站 UDP |
| Hysteria2 一直 Timeout，Reality 正常；服务器收发都能看到，几十字节 IPv4 UDP 回包也回不到客户端，坏包计数不涨 | IPv4 UDP 回程丢失。端口、密码和 MTU 不是原因；双方有公网 IPv6 时让 Hysteria2 单独走 IPv6 |
| 延迟是绿色的，`ip.sb` 仍是家里宽带 | 模式不是规则，或节点停在 DIRECT，或系统代理和虚拟网卡都没开 |
| 延迟正常，视频卡或网页打不开 | 还在用 Reality。切到 Hysteria2。短请求延迟不代表带宽 |
| 下载已经很快，上传仍慢，30MB 比 10MB 更慢 | 客户端 Hysteria2 没有 `up`，上传在走 BBR。服务器忽略客户端带宽只影响下载 |
| 只有浏览器走代理 | 开的是系统代理。整台电脑改开虚拟网卡 |
| 扫了下面那张 VLESS 码 | 只有一条节点，没有大陆直连规则 |

## 3x-ui 已经否定的做法

- 把 Reality 放在 `443`，而这台机器的 `443` 上还有别的 TLS。
- `443` 空着、专用端口的握手回包又回不到家里时，仍坚持留在那个专用端口。
- 为了端口握得成，把 Reality 改到订阅端口上。
- 开着虚拟网卡，用本机 `nc` 成功判断 Reality 端口是通的。
- Reality 一直 Error 时，不看握手回程，先改密钥或 `X25519MLKEM768`。
- 为了排查客户端 Error，打开 Xray 访问日志。那份日志记目标网站，记不到没握完的连接。
- 只改运行中的 `config.json` 来打开错误日志。重启 x-ui 时，面板按 `xrayTemplateConfig` 重写这份文件。
- 用一分钟一次的计数器当作每一次客户端 Error 或 Timeout 的记录。单次测速经常够不到阈值，也看不出是哪一条连接。
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
- 几十字节 IPv4 UDP 回包也丢、`UdpInCsumErrors` 不涨时，仍反复改 Hysteria2 密码、端口、带宽或 MTU。
- 只改当前运行配置里的 Hysteria2 IPv6 地址，不写增强脚本；刷新订阅后又回到坏掉的 IPv4。
- 一台 Clash 客户端通过增强脚本恢复后，就声称同一订阅的手机和其他电脑都已恢复。
- 未验证 IPv6 是否有同类问题，就把 IPv4 的长度丢弃规则照搬到 `ip6tables`。
- 把超长 UDP 的丢弃阈值降到 QUIC 初始包以下。这一套降到 1300 时，握手一起被丢。
- 对服务器发出的 Hysteria2 UDP 做长度丢弃。握手回应被丢，节点连不上。发出方向关掉路径 MTU 探测。
- 只丢掉超长的入站包，不限制服务器发出的包。下载方向仍是满尺寸，线路差时会掉到每秒几 KB。
