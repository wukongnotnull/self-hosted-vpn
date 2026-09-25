<div align="center">

# 自建 VPN

<br>

> **两种已验证方案，等你选** <br>

[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-blueviolet)](https://claude.ai/code)
[![Skills](https://img.shields.io/badge/skills.sh-Compatible-green)](https://skills.sh)

<br>

**OpenVPN Access Server**，一份客户端，用户名密码连接。<br>
**3x-ui**，订阅链接，按域名分流，手机也能单独导入。

<br>

Agent 不会替你定成某一种。还没指定时，先把这两种摆出来。

---

**快捷导航**

[使用演示](#使用演示) | [快速安装](#快速安装) | [两种方案](#两种方案) | [仓库结构](#仓库结构) | [关于我](#关于我)

<br>

</div>

---

## 使用演示

还没选定方案时，Agent 先问你要哪一种：

```
用户      ❯ 帮我搭一套自建 VPN

skill     ❯ 两种已验证方案，选一个：

            1. OpenVPN Access Server
               OpenVPN Connect，用户名和密码
               海外走服务器，大陆网段由服务器推送后直连
               分流看 IP，不看域名

            2. 3x-ui
               订阅链接
               电脑 Clash Verge Rev，安卓 Clash Meta，iPhone 小火箭
               大陆 IP 和大陆域名直连，其余走节点
               日常节点是 Hysteria2
```

已经在用其中一种时，沿用那一种，除非你要换。

---

## 快速安装

### 技术人员

同一份 `SKILL.md` 可在 Claude Code、Cursor、Codex、Gemini CLI 等宿主上跑。差别只是发现目录。

```bash
npx skills add wukongnotnull/self-hosted-vpn --all -g
```

只装某一个时，把 agent 名传给 `-a`。例如 Claude Code：

```bash
npx skills add wukongnotnull/self-hosted-vpn -g -a claude-code -y
```

Cursor 用 `cursor`，Codex 用 `codex`，Gemini CLI 用 `gemini-cli`。去掉 `-g` 则只装进当前项目。

装好后重启或重新扫描 Agent。

安装完成后，在 Agent 的对话框中说：

```markdown
> 帮我搭一套自建 VPN
> 用 OpenVPN Access Server
> 用 3x-ui，给手机发订阅
```

### 文科生（对话式）

不需要记命令，直接把下面这段话复制给 Agent：

```
帮我安装这个 skill：https://github.com/wukongnotnull/self-hosted-vpn
```

安装完成后，用自然语言告诉它你想要什么：

```markdown
> 帮我搭一套自建 VPN
> 我要 OpenVPN，用用户名密码连
> 我要订阅，手机和电脑分开导入
```

---

## 两种方案

两种可以装在不同机器上，互不替代。选定之后，Agent 只按对应章节做。

| | OpenVPN Access Server | 3x-ui |
| --- | --- | --- |
| 适合 | 一份客户端，用户名密码连接 | 按域名规则分流，或每人一条订阅（含手机） |
| 客户端 | OpenVPN Connect | Clash Verge Rev / Clash Meta for Android / 小火箭 |
| 分流 | 服务器推送大陆网段，命中后走家里宽带 | 客户端规则：大陆 IP 和大陆域名直连，其余走节点 |
| 日常出口 | 全隧道走这台服务器 | Hysteria2；VLESS + Reality 只作备用 |

### OpenVPN Access Server

默认全隧道走海外出口。中国大陆网段只写在 Access Server 的 **Server Config Directives** 里，用 `push "route … net_gateway"` 直连。DNS 留在 VPN 服务器上。

- 管理后台 `https://<服务器>:943/admin`，用户从 `https://<服务器>:943/` 下载配置。
- 传输优先 UDP 1194；家宽拦截 UDP 时走 TCP 443。
- 全隧道必须保持打开。关掉之后海外流量也不会进 VPN。
- 不要在 `.ovpn` 里手写 `route`。OpenVPN Connect 会丢掉这些行。

验收：`https://ip.sb` 是这台服务器的公网 IP；落在已推送网段里的国内站走家里宽带。

### 3x-ui

分流在客户端，不是服务器推送路由。面板是 3x-ui，协议进程是 Xray。管理员发订阅链接，不必把面板账号给出去。

- 电脑用 Clash Verge Rev，安卓用 Clash Meta for Android，iPhone 用小火箭。
- 模式用 **规则**。小火箭的全局路由用 **配置**。
- 订阅里大陆规则在前：`GEOIP,CN,DIRECT`、`GEOSITE,CN,DIRECT`，末尾才是代理。
- 日常节点是 Hysteria2（UDP）。备用是 VLESS + Reality（TCP）。
- 小火箭要给 Hysteria2 打开「允许不安全」。
- 管理页是明文 HTTP，不要写成 `https://`。打开管理页之前先退出 Clash。

验收：规则模式、节点是 Hysteria2 时，`https://ip.sb` 是这台服务器的公网 IP。百度变慢，多半是解析到了香港或海外，不能单独当成规则坏了。

细节、误判和已经否定的做法在 [reference.md](reference.md)。`SKILL.md` 是给 Agent 的正文。

---

## 仓库结构

```
self-hosted-vpn/
├── SKILL.md        # 两种方案的正文（各宿主共用）
├── reference.md    # 验收命令、内核参数形状、已经否定的做法
└── README.md
```

---

## 关于我

**悟空非空也** — AI之道创始人，独立开发者，Up主。

| 平台         | 链接                                                                         |
| ------------ | ---------------------------------------------------------------------------- |
| 🌐  官网      | [AI之道官网](https://waytoai.cn)                                                |
| 𝕏  Twitter   | [悟空非空也](https://x.com/wukongnotnull)                                   |
| 📺  B站       | [悟空非空也](https://space.bilibili.com/456634391)                              |
| ▶️  YouTube   | [悟空非空也](https://www.youtube.com/@wukongnotnull)                        |
| 📕  小红书    | [悟空非空也](https://www.xiaohongshu.com/user/profile/5ca89c2f000000001100952b) |
| 💬  公众号    | 微信搜「悟空非空也」或扫码关注 ↓                                            |

<img src="https://github.com/wukongnotnull/pangu-distill/raw/main/images/wechat-qrcode.jpg" alt="公众号二维码" width="360">

---

<div align="center">

© [悟空非空也](https://github.com/wukongnotnull)

</div>
