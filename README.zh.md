# cloudflare-dns-skill

[English](README.md)

通过 REST API 管理 Cloudflare DNS 记录 — 记录增删改查、代理设置、Zone 导出、DNS 验证，以及 Kubernetes External-DNS 集成。

| 功能 | 说明 |
|------|------|
| 记录 CRUD | 创建、列出、删除 A 和 CNAME 记录 |
| Zone 管理 | 列出 Zone、导出 BIND 格式 |
| DNS 验证 | 通过 dig/nslookup 验证解析 |
| 代理控制 | 开关 Cloudflare 代理 |
| K8s 集成 | External-DNS 配置与故障排除 |
| Azure 集成 | Cloudflare 作为 Azure 应用的权威 DNS |

## 安装

### 通过 skills.sh（推荐）

```bash
npx skills add psylch/cloudflare-dns-skill -g -y
```

### 通过 Plugin Marketplace

```
/plugin marketplace add psylch/cloudflare-dns-skill
/plugin install cloudflare-dns@psylch-cloudflare-dns-skill
```

### 手动安装

```bash
git clone https://github.com/psylch/cloudflare-dns-skill.git
# 将 skills/cloudflare-dns/ 复制到你的 skills 目录
```

安装后需重启 Claude Code。

## 前置条件

- **Cloudflare API Token**，需 `Zone:Read` + `DNS:Edit` 权限
- 已安装 `curl` 和 `jq`
- 可选：`dig` 或 `nslookup`（DNS 验证）
- 可选：`kubectl`（Kubernetes External-DNS 功能）

## 配置

在环境变量或 `.env` 文件中设置凭据：

```bash
export CF_API_TOKEN="your-token-here"
export CF_ZONE_ID="your-zone-id"  # 可选默认 zone
```

## 使用方式

- "列出我的 Cloudflare DNS 记录"
- "为 api.example.com 添加一条指向 1.2.3.4 的 A 记录"
- "删除 old.example.com 的 CNAME 记录"
- "导出我的 DNS zone"
- "检查 External-DNS 是否正常同步"

## 许可证

MIT
