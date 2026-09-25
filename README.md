# self-hosted-vpn

Agent Skill：提供两种已验证的自建 VPN，等用户选择。

**OpenVPN Access Server**。默认全隧道走海外出口。中国大陆网段只在 Server Config Directives 里用 `push "route … net_gateway"` 直连。DNS 留在 VPN 服务器上。

**3x-ui**（Xray）订阅。日常节点是 Hysteria2，备用是 VLESS + Reality。客户端用规则：大陆 IP 和大陆域名直连，其余走节点。适合按域名分流，或给手机单独发订阅。

## 安装

用 [skills](https://www.npmjs.com/package/skills) 安装：

装到 [skills CLI 支持的全部 agent](https://github.com/vercel-labs/skills#supported-agents)，并放到用户目录：

```bash
npx skills add wukongnotnull/self-hosted-vpn --all -g
```

只装某一个时，把 agent 名传给 `-a`。例如 Claude Code：

```bash
npx skills add wukongnotnull/self-hosted-vpn -g -a claude-code -y
```

Cursor 用 `cursor`，Codex 用 `codex`，Gemini CLI 用 `gemini-cli`。去掉 `-g` 则只装进当前项目。

`SKILL.md` 是技能正文。`reference.md` 是两种方案的验收命令、内核参数形状和已经否定的做法。
