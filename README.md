# self-hosted-vpn

Agent Skill：按已验证的 OpenVPN Access Server 模式搭建或调整自建 VPN。

默认全隧道走海外出口。中国大陆网段只在 Access Server 的 Server Config Directives 里用 `push "route … net_gateway"` 直连。DNS 留在 VPN 服务器上。

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

`SKILL.md` 是技能正文。`reference.md` 是验收命令和已经否定的做法。
