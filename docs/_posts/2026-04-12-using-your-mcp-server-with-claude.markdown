---
layout: post
title:  "How to use your custom MCP server with Claude Desktop"
date:   2026-04-23 08:52:17 -0000
categories: golang mcp claude
image: "/assets/images/2026-04-12-using-your-mcp-server-with-claude/banner.png"
---

![banner](/assets/images/2026-04-12-using-your-mcp-server-with-claude/banner.png)

As a follow-up to my previous post, ["Building an MCP Server in Go from scratch"](https://tiagomelo.info/golang/mcp/2026/04/10/go-mcp-server.html), it’s time to actually *use* that server with a real client.

In this post, we’ll integrate a custom MCP server with [Claude Desktop](https://claude.ai) and see the full flow in action: from natural language prompts to JSON-RPC calls over stdio.

## Configuring Claude desktop

We’ll use the MCP server introduced in the previous article: [https://github.com/tiagomelo/go-mcp-server](https://github.com/tiagomelo/go-mcp-server).

First, build the binary:

```bash
make build
```

Next, register it in Claude Desktop.

On macOS, edit:

```bash
~/Library/Application Support/Claude/claude_desktop_config.json
```

Add:

```json
{
  "mcpServers": {
    "go-mcp-server": {
      "command": "/Users/tiago/go/go-mcp-server/bin/mcp-server"
    }
  }
}
```

**Important notes:**

* Use an **absolute path**
* `~` will NOT work
* The binary must be executable

After saving, **restart Claude Desktop completely**.

---

## Understanding what happens

When Claude starts, it:

1. Launches your binary
2. Communicates via **stdin/stdout**
3. Uses **JSON-RPC 2.0**
4. Follows the MCP lifecycle:

   * `initialize`
   * `notifications/initialized`
   * `tools/list`
   * `tools/call`

This is the key idea:

> Claude is the MCP client. Your Go program is the MCP server.

---

## Inspecting logs

Claude logs are extremely useful when debugging:

```bash
tail -f ~/Library/Logs/Claude/main.log
```

When Claude Desktop starts, it automatically attempts to connect to the configured MCP servers:

```bash
2026-04-12 12:53:22 [info] MCP Server connection requested for: go-mcp-server
2026-04-12 12:53:22 [info] Running initial blocklist check triggered by ConnectToServer
2026-04-12 12:53:22 [info] Launching MCP Server: go-mcp-server
2026-04-12 12:53:22 [info] MCP Server connection requested for: mcp-registry
2026-04-12 12:53:22 [info] MCP Server connection requested for: Claude in Chrome
```

You can also inspect the server-specific logs:

```bash
tail -f ~/Library/Logs/Claude/mcp-server-go-mcp-server.log
```

---

## Tool usage in practice

Now the fun part: using tools.

---

## `hello_world`

Prompt:

```text
Use the greeting tool to say hello to Tiago
```

Behind the scenes, Claude sends:

```bash
2026-04-12T15:56:28.704Z [go-mcp-server] [info] Message from client: {"method":"tools/call","params":{"name":"hello_world","arguments":{"name":"Tiago"}},"jsonrpc":"2.0","id":2} { metadata: undefined }
```

Your server logs:

```bash
time=2026-04-12T12:56:28.705-03:00 level=INFO msg="tool call started" id=2 tool=hello_world
time=2026-04-12T12:56:28.706-03:00 level=INFO msg="tool call succeeded" id=2 tool=hello_world
```

And responds:

```bash
2026-04-12T15:56:28.706Z [go-mcp-server] [info] Message from server: {"jsonrpc":"2.0","id":2,"result":{"content":[{"text":"{\n  \"message\": \"Hello, Tiago\"\n}","type":"text"}],"isError":false,"structuredContent":{"message":"Hello, Tiago"}}} { metadata: undefined }
```

![hello_world prompt](/assets/images/2026-04-12-using-your-mcp-server-with-claude/hello_world1.png)

![hello_world response](/assets/images/2026-04-12-using-your-mcp-server-with-claude/hello_world2.png)

---

## `health_check`

Prompt:

```text
Can you check if this API endpoint is working? https://tiagomelo.info
```

Claude decides to call:

```bash
2026-04-12T16:00:59.474Z [go-mcp-server] [info] Message from client: {"method":"tools/call","params":{"name":"health_check","arguments":{"url":"https://tiagomelo.info"}},"jsonrpc":"2.0","id":3} { metadata: undefined }
```

Server logs:

```bash
time=2026-04-12T13:00:59.474-03:00 level=INFO msg="tool call started" id=3 tool=health_check
time=2026-04-12T13:00:59.887-03:00 level=INFO msg="tool call succeeded" id=3 tool=health_check
```

Response:

```bash
2026-04-12T16:00:59.888Z [go-mcp-server] [info] Message from server: {"jsonrpc":"2.0","id":3,"result":{"content":[{"text":"{\n  \"url\": \"https://tiagomelo.info\",\n  \"status_code\": 200,\n  \"latency_ms\": 412,\n  \"ok\": true\n}","type":"text"}],"isError":false,"structuredContent":{"url":"https://tiagomelo.info","status_code":200,"latency_ms":412,"ok":true}}} { metadata: undefined }
```

![health_check prompt](/assets/images/2026-04-12-using-your-mcp-server-with-claude/health_check1.png)

![health_check response](/assets/images/2026-04-12-using-your-mcp-server-with-claude/health_check2.png)

---

## `latency_percentiles`

Prompt:

```text
Calculate latency percentiles for these values: 10, 20, 30, 100, 200
```

Claude calls:

```bash
2026-04-12T16:03:03.504Z [go-mcp-server] [info] Message from client: {"method":"tools/call","params":{"name":"latency_percentiles","arguments":{"values":[10,20,30,100,200]}},"jsonrpc":"2.0","id":4} { metadata: undefined }
```

Server logs:

```bash
time=2026-04-12T13:03:03.505-03:00 level=INFO msg="tool call started" id=4 tool=latency_percentiles
time=2026-04-12T13:03:03.505-03:00 level=INFO msg="tool call succeeded" id=4 tool=latency_percentiles
```

Response:

```bash
2026-04-12T16:03:03.505Z [go-mcp-server] [info] Message from server: {"jsonrpc":"2.0","id":4,"result":{"content":[{"text":"{\n  \"count\": 5,\n  \"min\": 10,\n  \"p50\": 30,\n  \"p95\": 179.99999999999997,\n  \"p99\": 196,\n  \"max\": 200,\n  \"avg\": 72\n}","type":"text"}],"isError":false,"structuredContent":{"count":5,"min":10,"p50":30,"p95":179.99999999999997,"p99":196,"max":200,"avg":72}}} { metadata: undefined }
```

![percentiles prompt](/assets/images/2026-04-12-using-your-mcp-server-with-claude/percentiles1.png)

![percentiles response](/assets/images/2026-04-12-using-your-mcp-server-with-claude/percentiles2.png)

---

## Key takeaway: prompts don’t call tools

One of the most important concepts:

> You don’t call tools directly. You describe intent, and the model decides.

This means:

Good:

```text
Check if https://tiagomelo.info is up
```

Bad:

```text
Call tools/call with health_check
```

Tool descriptions are what guide this decision.

---

## Tool description matters (a lot)

A good description should:

1. Explain what the tool does
2. Explain when to use it

Example:

```go
Description: "Check the health of a URL by performing an HTTP GET request. Use this when the user asks if a website or API is up, reachable, or responding correctly."
```

This is what makes Claude choose your tool instead of answering from general knowledge.

---

## Important constraints

When building MCP servers:

### 1. stdout must be clean

* Only JSON-RPC messages
* No logs
* No debug prints

### 2. logs must go to stderr

Otherwise Claude will crash with:

```text
Unexpected token 'p' ... not valid JSON
```

### 3. tool names must be valid

Claude currently enforces:

```text
^[a-zA-Z0-9_-]{1,64}$
```

So this is invalid:

```text
postgres.query
```

Use:

```text
postgres_query
```

---

## Debugging tips

If things don’t work:

1. Check logs:

   ```bash
   tail -f ~/Library/Logs/Claude/*.log
   ```

2. Run your server manually

3. Verify:

   * no stdout pollution
   * valid JSON
   * correct tool names

---

## Final thoughts

At this point, you now have:

* A working MCP server in Go
* Integrated with Claude Desktop
* Tools being called automatically
* Full visibility via logs

This is the foundation for building:

* internal tooling
* developer assistants
* production integrations
* AI-powered backends

---

## Closing insight

> MCP is not magic.
> It’s just a local process speaking JSON-RPC over stdio.

And once you understand that, you can build anything on top of it.