# self-hosted-vpn

Cursor Agent Skill：按已验证的 OpenVPN Access Server 模式搭建或调整自建 VPN。

默认全隧道走海外出口。中国大陆网段只在 Access Server 的 Server Config Directives 里用 `push "route … net_gateway"` 直连。DNS 留在 VPN 服务器上。

## 安装

放到 Cursor 个人技能目录，保留这个目录名：

```bash
git clone https://github.com/wukongnotnull/self-hosted-vpn.git ~/.cursor/skills/self-hosted-vpn
```

`SKILL.md` 是技能正文。`reference.md` 是验收命令和已经否定的做法。
