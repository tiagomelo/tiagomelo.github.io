---
layout: post
title:  "Building an MCP Server in Go from scratch"
date:   2026-04-10 08:06:11 -0000
categories: golang mcp
image: "/assets/images/2026-04-09-go-mcp-server/banner.png"
---

![banner](/assets/images/2026-04-09-go-mcp-server/banner.png)

## Introduction

The [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) is an open standard that defines how AI applications (like [Claude](https://claude.ai)) communicate with external tools and data sources. Think of it as a USB port for AI: a universal interface that lets any compliant client talk to any compliant server.

In this article, we'll build an MCP server in [Go](https://go.dev/) from scratch -- no third-party MCP libraries, just the standard library and the MCP specification. By the end, you'll understand how the protocol works at the wire level and have a working server with three example tools.

## What is MCP?

MCP follows a client-server architecture where:

- **MCP Clients** are AI applications (Claude Desktop, Claude Code, IDE extensions) that need to access external capabilities.
- **MCP Servers** expose those capabilities as **tools** -- functions that the AI can discover and invoke.

The transport layer is [JSON-RPC 2.0](https://www.jsonrpc.org/specification) over **stdio** (standard input/output). The client spawns the server as a child process, sends JSON-RPC requests to its stdin, and reads JSON-RPC responses from its stdout.

![mcp diagram](/assets/images/2026-04-09-go-mcp-server/diagram1.png)

## JSON-RPC 2.0: the transport layer

Before diving into MCP specifics, let's understand the transport. JSON-RPC 2.0 defines two types of messages:

**Requests** have an `id` and expect a response:

```json
{"jsonrpc": "2.0", "id": 1, "method": "ping"}
```

**Notifications** have no `id` and expect no response:

```json
{"jsonrpc": "2.0", "method": "notifications/initialized"}
```

**Responses** echo back the request `id` and carry either a `result` or an `error`:

```json
{"jsonrpc": "2.0", "id": 1, "result": {}}
```

Error codes are standardized by the JSON-RPC spec:

| Code   | Meaning          |
|--------|------------------|
| -32700 | Parse error      |
| -32600 | Invalid request  |
| -32601 | Method not found |
| -32602 | Invalid params   |
| -32603 | Internal error   |

Since the transport is stdio, each JSON-RPC message must be a **single line** -- no pretty-printing, no line breaks within a message.

## The MCP initialization handshake

Before a client can use any tools, it must complete a handshake:

![mcp sequence diagram](/assets/images/2026-04-09-go-mcp-server/diagram2.png)

1. The client sends an `initialize` **request** with its protocol version and capabilities.
2. The server responds with its own protocol version, capabilities, and instructions.
3. The client sends a `notifications/initialized` **notification** (no `id`, no response expected).
4. Only after step 3 does the server accept `tools/list` and `tools/call` requests.

This handshake ensures both sides agree on the protocol version and know each other's capabilities before any work begins.

## Project structure

```
go-mcp-server/
├── cmd/
│   └── main.go            # Entry point, signal handling, graceful shutdown
├── jsonrpc/
│   └── jsonrpc.go          # JSON-RPC 2.0 types and error codes
├── server/
│   ├── server.go           # MCP server: request routing, handlers, tool registry
│   └── server_test.go      # Integration tests
├── tools/
│   ├── hello.go            # hello_world tool
│   ├── health.go           # health_check tool
│   ├── percentiles.go      # latency_percentiles tool
│   ├── http.go             # HTTP abstractions (for testability)
│   └── tools.go            # Tool registration (wires definitions to handlers)
├── Makefile
├── go.mod
└── go.sum
```

## Implementation

### JSON-RPC types

We start with the wire format. The `jsonrpc` package defines the request, response, and error types that map directly to the JSON-RPC 2.0 spec:

```go
// jsonrpc/jsonrpc.go

package jsonrpc

import "encoding/json"

// Request represents a JSON-RPC request object.
type Request struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      any             `json:"id,omitempty"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

// Response represents a JSON-RPC response object.
type Response struct {
	JSONRPC string `json:"jsonrpc"`
	ID      any    `json:"id,omitempty"`
	Result  any    `json:"result,omitempty"`
	Error   *Error `json:"error,omitempty"`
}

// Error represents a JSON-RPC error object.
type Error struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

// Predefined error codes for JSON-RPC 2.0.
// https://www.jsonrpc.org/specification#error_object
const (
	ParseError     = -32700
	InvalidRequest = -32600
	MethodNotFound = -32601
	InvalidParams  = -32602
	InternalError  = -32603
)
```

A few things to note:
- `ID` is `any` because JSON-RPC allows string or numeric IDs, and notifications have no ID at all (`omitempty` handles that).
- `Params` is `json.RawMessage` so we can defer parsing until we know which method was called.
- The error codes are defined by the [JSON-RPC 2.0 specification](https://www.jsonrpc.org/specification#error_object), not MCP. MCP inherits them since it uses JSON-RPC as its transport.

### The server

The `server` package is the heart of the project. Let's walk through it in sections.

#### Types and constructor

```go
// server/server.go

const ProtocolVersion = "2025-06-18"

// ToolDefinition defines a tool that can be called by the client.
type ToolDefinition struct {
	Name        string         `json:"name"`
	Description string         `json:"description,omitempty"`
	InputSchema map[string]any `json:"inputSchema"`
}

// ToolHandler is a function that implements the logic of a tool.
type ToolHandler func(ctx context.Context, arguments json.RawMessage) (any, error)

// Server implements the MCP protocol over JSON-RPC 2.0.
type Server struct {
	in  io.Reader
	out io.Writer

	mu          sync.RWMutex
	tools       map[string]ToolHandler
	definitions map[string]ToolDefinition
	initialized bool
	handlers    map[string]func(context.Context, jsonrpc.Request) error
	logger      *slog.Logger
}
```

The server reads from `in` and writes to `out`. In production these are `os.Stdin` and `os.Stdout`, but accepting `io.Reader`/`io.Writer` makes the server fully testable without real I/O.

The constructor wires up the method dispatch table:

```go
func New(in io.Reader, out io.Writer, logger *slog.Logger) *Server {
	s := &Server{
		in:          in,
		out:         out,
		tools:       make(map[string]ToolHandler),
		definitions: make(map[string]ToolDefinition),
		logger:      logger,
	}

	s.handlers = map[string]func(context.Context, jsonrpc.Request) error{
		"initialize":                s.handleInitialize,
		"notifications/initialized": s.handleInitializedNotification,
		"ping":                      s.handlePing,
		"tools/list":                s.handleToolsList,
		"tools/call":                s.handleToolsCall,
	}

	return s
}
```

#### Tool registration

Tools can be registered at any time before or after initialization:

```go
func (s *Server) RegisterTool(def ToolDefinition, handler ToolHandler) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.definitions[def.Name] = def
	s.tools[def.Name] = handler
}
```

#### The main loop

The `Run` method reads JSON-RPC messages line by line. Since `bufio.Scanner.Scan()` is a blocking call that doesn't respect context cancellation, we push it into a goroutine and use channels so the main loop can `select` on both incoming lines and `ctx.Done()`:

```go
func (s *Server) Run(ctx context.Context) error {
	s.logger.Info("mcp server started", slog.String("protocolVersion", ProtocolVersion))
	defer s.logger.Info("mcp server stopped")

	scanner := bufio.NewScanner(s.in)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)

	// scanCh delivers lines from stdin so we can select on ctx.Done().
	scanCh := make(chan []byte)
	scanErr := make(chan error, 1)
	go func() {
		defer close(scanCh)
		for scanner.Scan() {
			line := make([]byte, len(scanner.Bytes()))
			copy(line, scanner.Bytes())
			scanCh <- line
		}
		scanErr <- scanner.Err()
	}()

	for {
		var line []byte
		select {
		case <-ctx.Done():
			return ctx.Err()
		case l, ok := <-scanCh:
			if !ok {
				if err := <-scanErr; err != nil {
					return fmt.Errorf("reading input: %w", err)
				}
				return nil
			}
			line = l
		}

		if len(line) == 0 {
			continue
		}

		// ... parse JSON, validate version, dispatch to handler
	}
}
```

Without the goroutine + channel approach, a `Ctrl+C` signal would cancel the context, but the loop would remain blocked on `scanner.Scan()` until new input arrived -- making the server unable to shut down cleanly.

Each incoming line goes through three stages:

1. **Parse**: unmarshal JSON. If it fails, send a `ParseError` response.
2. **Validate**: check that `jsonrpc` is `"2.0"`. If not, send an `InvalidRequest` response.
3. **Dispatch**: route to the appropriate handler based on the `method` field.

The dispatch also handles the `errNotInitialized` sentinel: when a request arrives before the handshake is complete, the error response has already been written to the client -- we just `continue` to the next message instead of killing the server:

```go
if err := s.handleRequest(ctx, req); err != nil {
    if errors.Is(err, errNotInitialized) {
        continue
    }
    return errors.WithMessage(err, "failed to handle request")
}
```

#### Request dispatch

```go
func (s *Server) handleRequest(ctx context.Context, req jsonrpc.Request) error {
	handler, ok := s.handlers[req.Method]
	if ok {
		return handler(ctx, req)
	}

	// Unknown notification (no ID) -- silently ignore per the spec.
	if req.ID == nil {
		s.logger.Debug("ignoring unknown notification", slog.String("method", req.Method))
		return nil
	}

	// Unknown method with an ID -- respond with MethodNotFound.
	return s.writeResponse(jsonrpc.Response{
		JSONRPC: "2.0",
		ID:      req.ID,
		Error: &jsonrpc.Error{
			Code:    jsonrpc.MethodNotFound,
			Message: fmt.Sprintf("method not found: %s", req.Method),
		},
	})
}
```

Per the JSON-RPC spec, unknown **notifications** (no `id`) are silently ignored, while unknown **requests** (with an `id`) get a `MethodNotFound` error response.

#### Initialization handlers

The `initialize` handler responds with the server's protocol version, capabilities, and instructions:

```go
func (s *Server) handleInitialize(ctx context.Context, req jsonrpc.Request) error {
	s.logger.Info("initialize request received", slog.Any("id", req.ID))

	type initializeParams struct {
		ProtocolVersion string         `json:"protocolVersion"`
		Capabilities    map[string]any `json:"capabilities"`
		ClientInfo      map[string]any `json:"clientInfo"`
	}

	var params initializeParams
	if len(req.Params) > 0 {
		if err := json.Unmarshal(req.Params, &params); err != nil {
			return s.writeResponse(jsonrpc.Response{
				JSONRPC: "2.0",
				ID:      req.ID,
				Error: &jsonrpc.Error{
					Code:    jsonrpc.InvalidParams,
					Message: fmt.Sprintf("invalid initialize params: %v", err),
				},
			})
		}
	}

	return s.writeResponse(jsonrpc.Response{
		JSONRPC: "2.0",
		ID:      req.ID,
		Result: map[string]any{
			"protocolVersion": ProtocolVersion,
			"capabilities": map[string]any{
				"tools": map[string]any{
					"listChanged": false,
				},
			},
			"serverInfo": map[string]any{
				"name":    "go-mcp-server",
				"version": "0.1.0",
			},
			"instructions": "This educational MCP server provides hello_world, health_check, and latency_percentiles tools.",
		},
	})
}
```

The `notifications/initialized` handler flips the `initialized` flag:

```go
func (s *Server) handleInitializedNotification(ctx context.Context, req jsonrpc.Request) error {
	s.mu.Lock()
	s.initialized = true
	s.mu.Unlock()
	s.logger.Info("initialized notification received")
	return nil
}
```

#### The initialization guard

Any handler that requires initialization calls `requireInitialized` first. If the server hasn't been initialized, it writes an error response to the client and returns a sentinel error:

```go
var errNotInitialized = errors.New("server not initialized")

func (s *Server) requireInitialized(req jsonrpc.Request) error {
	s.mu.RLock()
	initialized := s.initialized
	s.mu.RUnlock()

	if initialized {
		return nil
	}

	if err := s.writeResponse(jsonrpc.Response{
		JSONRPC: "2.0",
		ID:      req.ID,
		Error: &jsonrpc.Error{
			Code:    jsonrpc.InvalidRequest,
			Message: "server has not received notifications/initialized yet",
		},
	}); err != nil {
		return err
	}

	return errNotInitialized
}
```

Returning `errNotInitialized` instead of `nil` is critical. Without the sentinel, the callers would check `if err != nil`, see `nil`, and **fall through to execute the handler anyway** -- sending a second response for the same request.

#### Tool listing

`handleToolsList` returns all registered tools sorted alphabetically:

```go
func (s *Server) handleToolsList(ctx context.Context, req jsonrpc.Request) error {
	if err := s.requireInitialized(req); err != nil {
		return err
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	defs := make([]ToolDefinition, 0, len(s.definitions))
	for _, def := range s.definitions {
		defs = append(defs, def)
	}

	sort.Slice(defs, func(i, j int) bool {
		return defs[i].Name < defs[j].Name
	})

	return s.writeResponse(jsonrpc.Response{
		JSONRPC: "2.0",
		ID:      req.ID,
		Result: map[string]any{
			"tools": defs,
		},
	})
}
```

#### Tool invocation

`handleToolsCall` looks up the tool by name, runs it with a 10-second timeout, and returns either the result or an error:

```go
func (s *Server) handleToolsCall(ctx context.Context, req jsonrpc.Request) error {
	if err := s.requireInitialized(req); err != nil {
		return err
	}

	type callParams struct {
		Name      string          `json:"name"`
		Arguments json.RawMessage `json:"arguments"`
	}

	var params callParams
	if err := json.Unmarshal(req.Params, &params); err != nil {
		return s.writeResponse(jsonrpc.Response{
			JSONRPC: "2.0",
			ID:      req.ID,
			Error: &jsonrpc.Error{
				Code:    jsonrpc.InvalidParams,
				Message: fmt.Sprintf("invalid tools/call params: %v", err),
			},
		})
	}

	s.mu.RLock()
	handler, ok := s.tools[params.Name]
	s.mu.RUnlock()

	if !ok {
		return s.writeResponse(jsonrpc.Response{
			JSONRPC: "2.0",
			ID:      req.ID,
			Error: &jsonrpc.Error{
				Code:    jsonrpc.InvalidParams,
				Message: fmt.Sprintf("unknown tool: %s", params.Name),
			},
		})
	}

	callCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	result, err := handler(callCtx, params.Arguments)
	if err != nil {
		return s.writeResponse(jsonrpc.Response{
			JSONRPC: "2.0",
			ID:      req.ID,
			Result: map[string]any{
				"content": []map[string]any{
					{"type": "text", "text": err.Error()},
				},
				"isError": true,
			},
		})
	}

	pretty, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		return errors.WithMessage(err, "failed to indent json response")
	}

	return s.writeResponse(jsonrpc.Response{
		JSONRPC: "2.0",
		ID:      req.ID,
		Result: map[string]any{
			"content": []map[string]any{
				{"type": "text", "text": string(pretty)},
			},
			"structuredContent": result,
			"isError":           false,
		},
	})
}
```

Note that tool errors are **not** JSON-RPC errors. Per the MCP spec, a tool that fails returns a successful JSON-RPC response with `isError: true` in the result. JSON-RPC errors are reserved for protocol-level problems (bad params, unknown method, etc.).

The following diagram illustrates the full request flow for a `tools/call`:

![mcp flow](/assets/images/2026-04-09-go-mcp-server/diagram3.png)

### The tools

Each tool is a plain Go function. The `tools` package defines three examples.

#### hello_world

A simple greeter:

```go
// tools/hello.go

type HelloArgs struct {
	Name string `json:"name"`
}

type HelloResult struct {
	Message string `json:"message"`
}

func Hello(args HelloArgs) (HelloResult, error) {
	name := strings.TrimSpace(args.Name)
	if name == "" {
		name = "world"
	}

	return HelloResult{
		Message: fmt.Sprintf("Hello, %s", name),
	}, nil
}
```

#### health_check

Performs an HTTP `GET` and returns the status code and latency:

```go
// tools/health.go

type HealthCheckArgs struct {
	URL       string `json:"url"`
	TimeoutMS int    `json:"timeout_ms,omitempty"`
}

type HealthCheckResult struct {
	URL        string `json:"url"`
	StatusCode int    `json:"status_code"`
	LatencyMS  int64  `json:"latency_ms"`
	OK         bool   `json:"ok"`
}

func HealthCheck(ctx context.Context, args HealthCheckArgs) (HealthCheckResult, error) {
	if args.URL == "" {
		return HealthCheckResult{}, errors.New("url is required")
	}

	timeout := 3 * time.Second
	if args.TimeoutMS > 0 {
		timeout = time.Duration(args.TimeoutMS) * time.Millisecond
	}

	client := newHTTPClient(timeout)

	req, err := requestBuilderProvider.NewRequestWithContext(ctx, http.MethodGet, args.URL, nil)
	if err != nil {
		return HealthCheckResult{}, errors.WithMessage(err, "failed to create request")
	}

	start := time.Now()
	resp, err := client.Do(req)
	if err != nil {
		return HealthCheckResult{}, errors.WithMessage(err, "failed to perform request")
	}
	defer func() {
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
	}()

	latency := time.Since(start).Milliseconds()

	return HealthCheckResult{
		URL:        args.URL,
		StatusCode: resp.StatusCode,
		LatencyMS:  latency,
		OK:         resp.StatusCode >= 200 && resp.StatusCode < 300,
	}, nil
}
```

Notice that we drain the response body before closing it. This ensures the underlying TCP connection can be reused by the HTTP client's connection pool. Calling `resp.Body.Close()` alone doesn't guarantee connection reuse if the body wasn't fully read.

The HTTP client and request builder are abstracted behind interfaces for testability:

```go
// tools/http.go

type requestBuilder interface {
	NewRequestWithContext(ctx context.Context, method string, url string, body io.Reader) (*http.Request, error)
}

var requestBuilderProvider requestBuilder = &defaultRequestBuilderProvider{}

type httpClient interface {
	Do(req *http.Request) (*http.Response, error)
}

type httpClientFactory func(timeout time.Duration) httpClient

var newHTTPClient httpClientFactory = func(timeout time.Duration) httpClient {
	return &http.Client{Timeout: timeout}
}
```

The factory pattern for `httpClient` lets us inject different timeouts per request while still being mockable in tests.

#### latency_percentiles

Computes statistical percentiles for a list of numeric values:

```go
// tools/percentiles.go

type PercentilesArgs struct {
	Values []float64 `json:"values"`
}

type PercentilesResult struct {
	Count int     `json:"count"`
	Min   float64 `json:"min"`
	P50   float64 `json:"p50"`
	P95   float64 `json:"p95"`
	P99   float64 `json:"p99"`
	Max   float64 `json:"max"`
	Avg   float64 `json:"avg"`
}

func Percentiles(args PercentilesArgs) (PercentilesResult, error) {
	if len(args.Values) == 0 {
		return PercentilesResult{}, errors.New("values must not be empty")
	}

	values := make([]float64, len(args.Values))
	copy(values, args.Values)
	sort.Float64s(values)

	var sum float64
	for _, v := range values {
		sum += v
	}

	return PercentilesResult{
		Count: len(values),
		Min:   values[0],
		P50:   percentile(values, 50),
		P95:   percentile(values, 95),
		P99:   percentile(values, 99),
		Max:   values[len(values)-1],
		Avg:   sum / float64(len(values)),
	}, nil
}
```

Note that we copy the input slice before sorting to avoid mutating the caller's data.

#### Wiring it all together

The `RegisterDefaultTools` function connects tool definitions (name, description, input schema) to their handlers:

```go
// tools/tools.go

func RegisterDefaultTools(s *server.Server) {
	s.RegisterTool(
		server.ToolDefinition{
			Name:        "hello_world",
			Description: "Generate a greeting message for a given name. Use this when the user asks to greet someone, say hello, or produce a simple greeting.",
			InputSchema: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"name": map[string]any{
						"type":        "string",
						"description": "Optional name to greet.",
					},
				},
			},
		},
		func(ctx context.Context, raw json.RawMessage) (any, error) {
			var args HelloArgs
			if len(raw) > 0 {
				if err := json.Unmarshal(raw, &args); err != nil {
					return nil, fmt.Errorf("decoding arguments: %w", err)
				}
			}
			return Hello(args)
		},
	)

	// ... health_check and latency_percentiles follow the same pattern
}
```

The `InputSchema` follows [JSON Schema](https://json-schema.org/) format, which is how MCP clients know what arguments each tool expects.

### Entry point and graceful shutdown

```go
// cmd/main.go

func run(ctx context.Context, logger *slog.Logger) error {
	mcpServer := server.New(os.Stdin, os.Stdout, logger)
	tools.RegisterDefaultTools(mcpServer)

	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	serverErrors := make(chan error, 1)

	go func() {
		serverErrors <- mcpServer.Run(ctx)
	}()

	select {
	case err := <-serverErrors:
		return errors.WithMessage(err, "MCP server error")
	case sig := <-shutdown:
		logger.Info("shutdown signal received", slog.String("signal", sig.String()))
		cancel()
		return nil
	}
}
```

The `select` between `serverErrors` and `shutdown` is key. Without it, a `Ctrl+C` signal would be captured by the channel but never read, making the server unable to stop.

## Testing it manually

Start the server:

```bash
make run
```

This runs `cat | go run cmd/main.go`, keeping stdin open so you can type messages interactively.

**Step 1: Initialize**

Paste this line and press Enter:

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"manual-test","version":"0.1.0"}}}
```

You'll get back the server capabilities.

**Step 2: Confirm initialization**

```json
{"jsonrpc":"2.0","method":"notifications/initialized"}
```

No response (it's a notification).

**Step 3: List tools**

```json
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
```

**Step 4: Call a tool**

```json
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"hello_world","arguments":{"name":"Tiago"}}}
```

```json
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"health_check","arguments":{"url":"https://httpbin.org/get","timeout_ms":5000}}}
```

```json
{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"latency_percentiles","arguments":{"values":[12.5,45.3,67.8,23.1,89.4,34.6,56.7,78.9,11.2,99.0]}}}
```

Remember: each message must be on a **single line**. The server reads input line by line with `bufio.Scanner`, so a line break in the middle of a JSON message will cause a parse error.

Press `Ctrl+C` to stop the server.

## Integration tests

Since the server accepts `io.Reader`/`io.Writer`, we can test the full request/response flow without real stdio. We feed JSON-RPC messages through a `strings.Reader` and capture output in a `bytes.Buffer`:

```go
// server/server_test.go

func TestRun_ToolsCall_Success(t *testing.T) {
	input := initHandshake() +
		`{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"echo","arguments":{"msg":"hi"}}}` + "\n"
	out := &bytes.Buffer{}
	s := New(strings.NewReader(input), out, discardLogger())
	registerEchoTool(s)

	err := s.Run(context.Background())
	require.NoError(t, err)

	responses := parseResponses(t, out)
	require.Len(t, responses, 2) // initialize + tools/call

	callResp := responses[1]
	require.Nil(t, callResp.Error)
	require.Equal(t, float64(3), callResp.ID)

	result := resultMap(t, callResp)
	require.Equal(t, false, result["isError"])
}
```

For error paths, we use custom `io.Writer` and `io.Reader` implementations:

```go
// errWriter always returns an error on Write.
type errWriter struct{}

func (w *errWriter) Write(p []byte) (int, error) {
	return 0, errors.New("write error")
}

func TestRun_WriteError_ParseError(t *testing.T) {
	input := "not json\n"
	s := New(strings.NewReader(input), &errWriter{}, discardLogger())

	err := s.Run(context.Background())
	require.Error(t, err)
	require.Contains(t, err.Error(), "failed to unmarshal request")
}
```

For context cancellation, we use `io.Pipe` so the scanner blocks waiting for input, then cancel the context from a goroutine:

```go
func TestRun_ContextCanceled(t *testing.T) {
	r, w := io.Pipe()
	defer w.Close()
	out := &bytes.Buffer{}
	ctx, cancel := context.WithCancel(context.Background())

	s := New(r, out, discardLogger())

	done := make(chan error, 1)
	go func() {
		done <- s.Run(ctx)
	}()

	cancel()

	err := <-done
	require.ErrorIs(t, err, context.Canceled)
}
```

### Running the tests

```bash
make test
```

For coverage:

```bash
make coverage
```

## Conclusion

We've built a working MCP server from scratch in Go, covering:

- **JSON-RPC 2.0** as the wire protocol
- **MCP initialization handshake** (initialize -> initialized notification -> ready)
- **Tool registration and invocation** with JSON Schema input definitions
- **Graceful shutdown** with signal handling and context cancellation
- **Integration tests** that achieve 99%+ coverage by testing through the public stdio interface

The full source code is available on [GitHub](https://github.com/tiagomelo/go-mcp-server).