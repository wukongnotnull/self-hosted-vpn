# 自建 VPN 参考

## 服务器指令形状

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

## 已经否定的做法

- 把国内 DNS 设成客户端第一解析器。
- 在客户端配置或 `.ovpn` 里写 `route … net_gateway` 来做分流。
- 用系统 VPN 配置页代替 OpenVPN Connect。
- 把上一台机器的网段清单原样贴到新出口。
