---
layout: post
title:  "Open source project: go-grpc-bin"
date:   2024-08-28 14:59:15 -0000
categories: go grpc
image: "/assets/images/2024-08-28-go-grpc-bin/banner.png"
---

![banner](/assets/images/2024-08-28-go-grpc-bin/banner.png)

Github repo: [https://github.com/tiagomelo/go-grpc-bin](https://github.com/tiagomelo/go-grpc-bin)

Docker official image: [https://hub.docker.com/r/tiagoharris/go-grpc-bin](https://hub.docker.com/r/tiagoharris/go-grpc-bin)

_check out my other open source projects [here](https://tiagomelo.info/opensource/)_

# go-grpc-bin

A [gRPC](https://grpc.io) server written in [Go](https://go.dev) that provides a set of utilities that are useful for testing and experimenting with [gRPC](https://grpc.io), such as echoing messages, simulating errors, and streaming responses.

Official [Docker](https://docker.com) image: [https://hub.docker.com/r/tiagoharris/go-grpc-bin](https://hub.docker.com/r/tiagoharris/go-grpc-bin)

## available gRPC Services

- **Echo:**  
  Returns the received message back to the client.

- **GetMetadata:**  
  Retrieves the metadata (headers) from the incoming context and returns it.

- **StatusCode:**  
  Simulates returning a specific status code. If the status code is an error, it returns an error with that code.

- **StreamingEcho:**  
  Sends multiple responses back to the client, simulating a server-side streaming RPC.

- **BidirectionalEcho:**  
  Allows both the client and server to send messages in a bidirectional streaming RPC.

- **DelayedResponse:**  
  Simulates a delay before returning the response.

- **Upload:**  
  Receives a stream of binary data and simulates an upload operation.

- **Download:**  
  Sends a stream of binary data back to the client, simulating a file download.

- **SimulateError:**  
  Simulates an error based on the request.

- **Mirror:**  
  Echoes back the received message and metadata.

- **Transform:**  
  Processes the input string according to a specified transformation type (e.g., reversing the string).

- **CompressionTest:**  
  Simulates compression by compressing the data using gzip before returning it.

## running the server

### docker

```
docker run --rm -p <PORT>:<PORT> tiagoharris/go-grpc-bin -p <PORT>
```

### locally

```
make run PORT=<PORT>
```

## example gRPC requests

### using [grpcurl](https://github.com/fullstorydev/grpcurl)

- **Echo:**  
```
$ grpcurl -plaintext -d '{"message": "Hello, gRPC!"}' <SERVER_HOST>:<SERVER_PORT> grpcbin.GRPCBin/Echo
{
  "message": "Hello, gRPC!"
}
```

- **GetMetadata:**  
```
$ grpcurl -plaintext -H "custom-header: value" -d '{}' <SERVER_HOST>:<SERVER_PORT> grpcbin.GRPCBin/GetMetadata
{
  "metadata": {
    ":authority": "<SERVER_HOST>:<SERVER_PORT>",
    "content-type": "application/grpc",
    "custom-header": "value",
    "grpc-accept-encoding": "gzip",
    "user-agent": "grpcurl/1.9.1 grpc-go/1.61.0"
  }
}
```

- **StatusCode:**  

```
$ grpcurl -plaintext -d '{"code": 3}' <SERVER_HOST>:<SERVER_PORT> grpcbin.GRPCBin/StatusCode
ERROR:
  Code: InvalidArgument
  Message: Simulated error
```

- **StreamingEcho:**  

```
$ grpcurl -plaintext -d '{"message": "Hello, Streaming!"}' <SERVER_HOST>:<SERVER_PORT> grpcbin.GRPCBin/StreamingEcho
{
  "message": "0: Hello, Streaming!"
}
{
  "message": "1: Hello, Streaming!"
}
{
  "message": "2: Hello, Streaming!"
}
{
  "message": "3: Hello, Streaming!"
}
{
  "message": "4: Hello, Streaming!"
}
```

- **BidirectionalEcho:**  

```
$ grpcurl -plaintext -d @ <SERVER_HOST>:<SERVER_PORT> grpcbin.GRPCBin/BidirectionalEcho
{ "message": "message one" }    
{
  "message": "message one"
}
{ "message": "message two" }        
{
  "message": "message two"
}
{ "message": "message three" }
{
  "message": "message three"
}
```

- **DelayedResponse:**  

```
$ time grpcurl -plaintext -d '{"message": "Wait for it...", "delaySeconds": "5"}' <SERVER_HOST>:<SERVER_PORT> grpcbin.GRPCBin/DelayedResponse
{
  "message": "Wait for it..."
}

real	0m5.029s
user	0m0.013s
sys	0m0.011s
```

- **Upload:**  

```
$ grpcurl -plaintext -d '{"data": "Q2h1bmsgMQ=="}' -d '{"data": "Q2h1bmsgMg=="}' -d '{"data": "Q2h1bmsgMw=="}' <SERVER_HOST>:<SERVER_PORT> grpcbin.GRPCBin/Upload
{
  "message": "Upload completed"
}
```

- **Download:**  

```
$ time grpcurl -plaintext -d '{"filename": "example.txt"}' <SERVER_HOST>:<SERVER_PORT> grpcbin.GRPCBin/Download
{
  "data": "VGhpcyA="
}
{
  "data": "aXMgc28="
}
{
  "data": "bWUgdGU="
}
{
  "data": "c3QgZGE="
}
{
  "data": "dGEgZm8="
}
{
  "data": "ciBkb3c="
}
{
  "data": "bmxvYWQ="
}
{
  "data": "Lg=="
}

real	0m4.040s
user	0m0.016s
sys	0m0.016s
```

- **SimulateError:**  

```
$ grpcurl -plaintext -d '{"code": 13, "message": "Simulated internal error"}' <SERVER_HOST>:<SERVER_PORT> grpcbin.GRPCBin/SimulateError
ERROR:
  Code: Internal
  Message: Simulated internal error
```

- **Mirror:**  

```
$ grpcurl -plaintext -H "custom-header: value" -d '{"message": "Echo this back!"}' <SERVER_HOST>:<SERVER_PORT> grpcbin.GRPCBin/Mirror
{
  "message": "Echo this back!",
  "metadata": {
    ":authority": "<SERVER_HOST>:<SERVER_PORT>",
    "content-type": "application/grpc",
    "custom-header": "value",
    "grpc-accept-encoding": "gzip",
    "user-agent": "grpcurl/1.9.1 grpc-go/1.61.0"
  }
}
```

- **Transform:**  

```
$ grpcurl -plaintext -d '{"input": "reverse this", "transformation_type": "reverse"}' <SERVER_HOST>:<SERVER_PORT> grpcbin.GRPCBin/Transform
{
  "output": "siht esrever"
}
```

- **CompressionTest:**  

```
$ grpcurl -plaintext -d '{"data": "Compress this data"}' <SERVER_HOST>:<SERVER_PORT> grpcbin.GRPCBin/CompressionTest
{
  "compressedData": "H4sIAAAAAAAA/3LOzy0oSi0uVijJyCxWSEksSQQEAAD//5A1G6cSAAAA"
}
```

### using custom [Go](https://go.dev) client

- **Echo:**  

```
$ go run examples/echo/echo.go --serverHost=localhost:4444
echo response: Hello, gRPC!
```

- **GetMetadata:**  

```
$ go run examples/get_metadata/get_metadata.go --serverHost=localhost:4444
metadata response: map[:authority:localhost:4444 content-type:application/grpc test-key:test-value user-agent:grpc-go/1.65.0]
```

- **StatusCode:**  

```
$ go run examples/status_code/status_code.go --serverHost=localhost:4444
StatusCode response: Simulated error
```

- **StreamingEcho:**  

```
$ go run examples/streaming_echo/streaming_echo.go --serverHost=localhost:4444
StreamingEcho response: 0: Hello, Streaming!
StreamingEcho response: 1: Hello, Streaming!
StreamingEcho response: 2: Hello, Streaming!
StreamingEcho response: 3: Hello, Streaming!
StreamingEcho response: 4: Hello, Streaming!
```

- **BidirectionalEcho:**  

```
$ go run examples/bidirectional_echo/bidirectional_echo.go --serverHost=localhost:4444
BidirectionalEcho response: First message
BidirectionalEcho response: Second message
BidirectionalEcho response: Third message
```

- **DelayedResponse:**  

```
$ time go run examples/delayed_response/delayed_response.go --serverHost=localhost:4444
DelayedResponse: Delayed Hello!

real	0m3.804s
user	0m0.383s
sys	0m0.367s
```

- **Upload:**

```
$ time go run examples/upload/upload.go --serverHost=localhost:4444
Upload reply: Upload completed

real	0m3.097s
user	0m0.359s
sys	0m0.396s
```

- **Download:**  

```
$ time go run examples/download/download.go --serverHost=localhost:4444
Downloaded file data: This is some test data for download.

real	0m4.656s
user	0m0.381s
sys	0m0.325s
```

- **SimulateError:**  

```
$ go run examples/simulate_error/simulate_error.go --serverHost=localhost:4444
SimulateError: Simulated internal server error
```

- **Mirror:**  

```
$ go run examples/mirror/mirror.go --serverHost=localhost:4444
Mirror response: Hello, Mirror!
Mirror metadata: map[:authority:localhost:4444 content-type:application/grpc key:value user-agent:grpc-go/1.65.0]
```

- **Transform:**  

```
$ go run examples/transform/transform.go --serverHost=localhost:4444
Transform response: !mrofsnarT ,olleH
```

- **CompressionTest:**  

```
$ go run examples/compression/compression.go --serverHost=localhost:4444
Uncompressed data: Hello, Compression!
```

## unit tests

```
make test
```

## coverage

```
make coverage
```

## contributing

contributions are welcome! Feel free to open issues or submit pull requests.
