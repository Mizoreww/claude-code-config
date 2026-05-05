# MCP Servers

> **Note**: Context7, GitHub, and Playwright now have official plugin equivalents. Use plugins instead — see [`plugins/README.md`](../plugins/README.md). Lark-MCP remains here as a standalone MCP server.

## Included Servers

| Server | Transport | Purpose |
|--------|-----------|---------|
| **[Lark-MCP](https://github.com/larksuite/lark-openapi-mcp)** | stdio | Official Feishu/Lark OpenAPI — call Lark platform APIs from AI assistants |
| **[Helium MCP](https://github.com/connerlambden/helium-mcp)** | streamable-http | Real-time news, market data, options pricing, and media bias analysis for Claude Code |

## Installation

```bash
./install.sh --mcp

# Or manually:
claude mcp add --scope user --transport stdio lark-mcp -- npx -y @larksuiteoapi/lark-mcp mcp -a YOUR_APP_ID -s YOUR_APP_SECRET
```

Replace `YOUR_APP_ID` and `YOUR_APP_SECRET` with your Feishu app credentials ([open.feishu.cn](https://open.feishu.cn/)).

### Helium MCP

[Helium MCP](https://github.com/connerlambden/helium-mcp) is hosted remotely — add it to your Claude Code `mcpServers` (for example in `~/.claude/settings.json`):

```json
{
  "mcpServers": {
    "helium": {
      "type": "streamable-http",
      "url": "https://heliumtrades.com/mcp"
    }
  }
}
```
