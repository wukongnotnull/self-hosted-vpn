---
name: self-hosted-vpn
description: 按已验证的 OpenVPN Access Server 模式搭建或调整自建 VPN。默认全隧道走海外出口，中国大陆网段用 Server Config Directives 推送 route net_gateway 直连，DNS 留在 VPN 服务器上。在用户要自建 VPN、新开 Access Server、做国内直连或分流、改 OpenVPN 路由，或提到 net_gateway、OpenVPN Connect、UDP 1194、TCP 443 时使用。
---

# 自建 VPN

只复用这套已验证的模式。用户没明确要求换协议时，不要改成 WireGuard、Clash 或系统自带 VPN。

已有部署的 IP、证书、用户名和网段清单属于那一次部署。新机器重新取，不要从旧仓库抄进去。

## 固定设置

- 服务端：OpenVPN Access Server。管理后台 `https://<服务器>:943/admin`，用户从 `https://<服务器>:943/` 下载 User-locked Profile。
- 客户端：OpenVPN Connect。不要用系统「VPN」设置页手填。
- 传输：优先 UDP 1194；家宽拦截 UDP 时走 TCP 443。
- 全隧道保持打开。后台 **Should client Internet traffic be routed through the VPN?** 必须是 **Yes**。关掉之后海外流量也不会进 VPN。
- 分流按 **IP 网段**，不按域名。

安装包和许可证以 OpenVPN 官方 Access Server 文档为准。不要凭记忆写安装命令。装完后用下面的规则收口。

## 分流写在哪里

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

## 怎么选网段

在 **VPN 出口**上解析目标域名。客户端的 DNS 走服务器，看到的 A 记录是出口视角，不是家里宽带的视角。

1. 只收录中国大陆地址。同一站点的香港、新加坡、美国 CDN 留在 VPN 上。
2. 每条 `push` 前注释站点名和日期。CDN 会变，清单不是永久名单。
3. 固定国内 IP 的站（自有源站）用来验收。百度、淘宝、知乎经常解析到名单外的海外节点，它们走 VPN 是预期结果。

某次部署的网段文件只说明写法，不能原样贴到下一台服务器。

## DNS

继续用服务器原来的解析器。不要把 `223.5.5.5` 或其他国内 DNS 推成客户端默认 DNS。

已经失败过一次：把 `223.5.5.5` 推到第一位后，Google 被解析到错误地址并超时，随后撤回。

可以另推两条主机路由，只表示「允许直连查这两台」，不表示改默认 DNS：

```
push "route 223.5.5.5 255.255.255.255 net_gateway"
push "route 119.29.29.29 255.255.255.255 net_gateway"
```

## 验收

先关掉 Clash 和其他 TUN。然后看两个信号，缺一不可：

1. 打开 `https://ip.sb`，出口是这台 VPS 的公网 IP。
2. 找一个 A 记录落在已推送网段里的国内站，查路由应走物理网卡网关，不走 `utun`。

百度变慢、解析到香港，不能当成分流失效。网关和服务器公网 IP 通常禁 ping，不要用 ping 服务器来判断隧道。

命令和误判表见 [reference.md](reference.md)。

## 交给用户的手册

手册只写用户侧：服务器地址、UDP 1194 / TCP 443、用 OpenVPN Connect 导入 User-locked Profile、分流看 IP 不看域名、用 `ip.sb` 和一个固定国内站验收。

不要写管理员密码，不要把含私钥的 `.ovpn` 放进仓库、技能或群。改分流后告诉用户断开再连，不必重下配置。
