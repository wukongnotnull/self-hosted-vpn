# self-hosted-vpn

Cursor Agent Skill：按已验证的 OpenVPN Access Server 模式搭建或调整自建 VPN。

默认全隧道走海外出口。中国大陆网段只在 Access Server 的 Server Config Directives 里用 `push "route … net_gateway"` 直连。DNS 留在 VPN 服务器上。

## 安装

用 [skills](https://www.npmjs.com/package/skills) 安装：

```bash
npx skills add wukongnotnull/self-hosted-vpn -a cursor -g -y
```

`-a cursor` 装到 Cursor，`-g` 装到用户目录，当前项目和其他项目都能用。只装进当前仓库时去掉 `-g`。

`SKILL.md` 是技能正文。`reference.md` 是验收命令和已经否定的做法。
