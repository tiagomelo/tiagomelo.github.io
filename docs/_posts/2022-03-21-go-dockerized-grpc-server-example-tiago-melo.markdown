---
layout: post
title:  "Go: a dockerized gRPC server example"
date:   2022-03-21 13:26:01 -0300
categories: go docker grpc
---
![Go: a dockerized gRPC server example](/assets/images/2022-03-21-524c455f-acee-4f62-8d6e-c7dd597bf896/2022-03-21-banner.png)

It's not new to anyone that [Docker](https://www.docker.com/?trk=article-ssr-frontend-pulse_little-text-block) has changed the way we ship software. The primary goal of using [Docker](https://www.docker.com/?trk=article-ssr-frontend-pulse_little-text-block) is containerization, and that is to have a consistent environment for your application and does not depend on the host machine where it runs.

Also, [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) is becoming a popular architectural choice for writing services. You can check this [quick start](https://grpc.io/docs/languages/go/quickstart/?trk=article-ssr-frontend-pulse_little-text-block) to get a glance of how to implement a [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) service in [Golang](http://golang.org?trk=article-ssr-frontend-pulse_little-text-block).

In this article we'll see how to write and run a [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) service with [Docker](https://www.docker.com/?trk=article-ssr-frontend-pulse_little-text-block). We'll also cover a lot of cool and useful things, like:

- How to compile [.proto](https://developers.google.com/protocol-buffers/docs/proto3?trk=article-ssr-frontend-pulse_little-text-block) files without the burden of installing [protoc](https://grpc.io/docs/protoc-installation/?trk=article-ssr-frontend-pulse_little-text-block) locally;
- How we can easily use [environment variables](https://en.wikipedia.org/wiki/Environment_variable?trk=article-ssr-frontend-pulse_little-text-block) for parameterizing our application;
- How to write a [multistage build](https://docs.docker.com/develop/develop-images/multistage-build/?trk=article-ssr-frontend-pulse_little-text-block) so we end up with a small, optmized [Docker](https://www.docker.com/?trk=article-ssr-frontend-pulse_little-text-block) image;
- How to easily invoke the [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) service without having to manually write a [Golang](http://golang.org/?trk=article-ssr-frontend-pulse_little-text-block) client for it.

Let's go!

## The proposed application

We'll write a [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) service that is used to retrieve a number of random poetries. In order to achieve that, we'll use [PoetryDB](https://poetrydb.org/index.html?trk=article-ssr-frontend-pulse_little-text-block), an awesome free API for internet poets.

We can see a simple [sequence diagram](https://en.wikipedia.org/wiki/Sequence_diagram?trk=article-ssr-frontend-pulse_little-text-block) to show how it will work:

![No alt text provided for this image](/assets/images/2022-03-21-524c455f-acee-4f62-8d6e-c7dd597bf896/1647864546728.png)

### Protobuf

Here's our [.proto](https://developers.google.com/protocol-buffers/docs/proto3?trk=article-ssr-frontend-pulse_little-text-block) file where we define the service, 'poetry.proto':

```
syntax = "proto3"

package proto;
option go_package = "bitbucket.org/tiagoharris/docker-grpc-service-tutorial/proto/poetry";

message Poetry {
    string title = 1;
    string author = 2;
    repeated string lines = 3;
    int32 linecount = 4;
}

message RandomPoetriesRequest {
    int32 number_of_poetries = 1;
}

message PoetryList {
    repeated Poetry list = 1;
}

service ProtobufService {
    rpc RandomPoetries(RandomPoetriesRequest) returns (PoetryList);
}
```

Now we need to compile it in order to have:

- Code for populating, serializing, and retrieving 'RandomPoetriesRequest' and 'PoetryList' message types;
- Generated client and server code.

We compile it using [protoc](https://grpc.io/docs/protoc-installation/?trk=article-ssr-frontend-pulse_little-text-block). Generally we would need to install it, but a better idea would be to use a [Docker](https://www.docker.com/?trk=article-ssr-frontend-pulse_little-text-block) image that has [protoc](https://grpc.io/docs/protoc-installation/?trk=article-ssr-frontend-pulse_little-text-block) installed, pretty much similar to what we do when we want to use [MySQL](https://dev.mysql.com/?trk=article-ssr-frontend-pulse_little-text-block) for example; instead of installing it, we could use a [Docker](https://www.docker.com/?trk=article-ssr-frontend-pulse_little-text-block) image for it.

And [docker-protoc](https://github.com/namely/docker-protoc?trk=article-ssr-frontend-pulse_little-text-block) is exactly what we need.

Here's our Makefile target that we use to invoke it so we compile the [.proto](https://developers.google.com/protocol-buffers/docs/proto3?trk=article-ssr-frontend-pulse_little-text-block) file:

```

.PHONY: proto
## proto: compiles .proto files
proto:
    @ docker run -v $(PWD):/defs namely/protoc-all -f proto/poetry.proto -l
go -o . --go-source-relative

```

The '--go-source-relative' option is to keep the generated 'poetry.pb.go' file at the same folder of our [.proto](https://developers.google.com/protocol-buffers/docs/proto3?trk=article-ssr-frontend-pulse_little-text-block) file 'poetry.proto'.

When you call it for the first time, it will download 'namely/protoc-all:latest' [Docker](https://www.docker.com/?trk=article-ssr-frontend-pulse_little-text-block) image and then will compile our [.proto](https://developers.google.com/protocol-buffers/docs/proto3?trk=article-ssr-frontend-pulse_little-text-block) file:

```

 $ make proto
Unable to find image 'namely/protoc-all:latest' locally
latest: Pulling from namely/protoc-all
72a69066d2fe: Pull complete
92b40fad93be: Pull complete
6c681a0a5896: Pull complete
ebc1d0ae2fce: Pull complete
8419d9b6e1d6: Pull complete
bea3673d63cb: Pull complete
c4795970891a: Pull complete
a07bfba13570: Pull complete
390910a84268: Pull complete
3b0c06e97c77: Pull complete
02fad91bea96: Pull complete
784aa2673488: Pull complete
c5446e8648ec: Pull complete
f3170de720de: Pull complete
dbd0d73172b5: Pull complete
3516e04721f7: Pull complete
b91f69a87fb4: Pull complete
37490bcef5e6: Pull complete
fd5de9fd6a61: Pull complete
35f2a04b2c22: Pull complete
075200f557a8: Pull complete
017c387ae8e9: Pull complete
Digest: sha256:5406210e1dc68ffe4f36fa1ee98214bb50614d3a44428bf33ffca427079dd3d2
Status: Downloaded newer image for namely/protoc-all:latest

```

### Reading environment variables

Before implementing our [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) service, let's make an engineering decision about parameterizing the application. A good idea would be to parameterize the base [URL](https://en.wikipedia.org/wiki/URL?trk=article-ssr-frontend-pulse_little-text-block) for [PoetryDB](https://poetrydb.org/index.html?trk=article-ssr-frontend-pulse_little-text-block), as well as how many seconds we want to wait until an HTTP timeout occur. So how can we achieve that in a safe, clean way?

Using [environment variables](https://en.wikipedia.org/wiki/Environment_variable?trk=article-ssr-frontend-pulse_little-text-block) is a common technique, right? A good solution would be:

- Defining the variables in some sort of file;
- Reading this file and exporting those values as [environment variables](https://en.wikipedia.org/wiki/Environment_variable?trk=article-ssr-frontend-pulse_little-text-block);
- Get those [environment variables](https://en.wikipedia.org/wiki/Environment_variable?trk=article-ssr-frontend-pulse_little-text-block) into a [struct](https://go.dev/tour/moretypes/2?trk=article-ssr-frontend-pulse_little-text-block) so we can easily use them.

Godotenv

[Godotenv](https://github.com/joho/godotenv?trk=article-ssr-frontend-pulse_little-text-block)is a [Golang](http://golang.org/?trk=article-ssr-frontend-pulse_little-text-block) package that solves the two bullet points defined above. We define our variables in an '.env' file and then we invoke it to export all those values as [environment variables](https://en.wikipedia.org/wiki/Environment_variable?trk=article-ssr-frontend-pulse_little-text-block).

Here's our 'config.env' file:

```

POETRYDB_BASE_URL=https://poetrydb.org
POETRYDB_HTTP_TIMEOUT=10

```

Envconfig

[Envconfig](https://github.com/kelseyhightower/envconfig?trk=article-ssr-frontend-pulse_little-text-block) is a [Golang](http://golang.org/?trk=article-ssr-frontend-pulse_little-text-block) package that solves the last bullet point: it encapsulates [environment variables](https://en.wikipedia.org/wiki/Environment_variable?trk=article-ssr-frontend-pulse_little-text-block) that are correctly exported into a [struct](https://go.dev/tour/moretypes/2?trk=article-ssr-frontend-pulse_little-text-block).

Here's 'configreader/config\_reader.go', which we use to get a configuration [struct](https://go.dev/tour/moretypes/2?trk=article-ssr-frontend-pulse_little-text-block) fulfilled with [environment variables](https://en.wikipedia.org/wiki/Environment_variable?trk=article-ssr-frontend-pulse_little-text-block):

```

// Copyright (c) 2022 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.

package configreader

import (
    "github.com/joho/godotenv"
    "github.com/kelseyhightower/envconfig"
    "github.com/pkg/errors"
)

// These global variables makes it easy
// to mock these dependencies
// in unit tests.
var (
    godotenvLoad     = godotenv.Load
    envconfigProcess = envconfig.Process
)

// GoDotEnv is an interface that defines
// the functions we use from godotenv package.
// It enables mocking this dependency in unit testing.
type GoDotEnv interface {
    Load(filenames ...string) (err error)
}

// EnvConfig is an interface that defines
// the functions we use from envconfig package.
// It enables mocking this dependency in unit testing.
type EnvConfig interface {
    Process(prefix string, spec interface{}) error
}

// Config holds configuration data.
type Config struct {
    PoetrydbBaseUrl     string `envconfig:"POETRYDB_BASE_URL" required:"true"`
    PoetrydbHttpTimeout int    `envconfig:"POETRYDB_HTTP_TIMEOUT" required:"true"`
}

// ReadEnv reads envionment variables into Config struct.
func ReadEnv() (*Config, error) {
    err := godotenvLoad("configreader/config.env")
    if err != nil {
        return nil, errors.Wrap(err, "reading .env file")
    }
    var config Config
    err = envconfigProcess("", &config)
    if err != nil {
        return nil, errors.Wrap(err, "processing env vars")
    }
    return &config, nil
}


```

### gRPC service implementation

Now that we compiled our [.proto](https://developers.google.com/protocol-buffers/docs/proto3?trk=article-ssr-frontend-pulse_little-text-block) file 'poetry.proto', we'll write a [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) server that implements the service defined in 'poetry.pb.go':

```

// Copyright (c) 2022 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.

package server

import (
    "context"
    "encoding/json"
    "fmt"
    "net"

    "bitbucket.org/tiagoharris/docker-grpc-service-tutorial/configreader"
    "bitbucket.org/tiagoharris/docker-grpc-service-tutorial/poetrydb"
    poetry "bitbucket.org/tiagoharris/docker-grpc-service-tutorial/proto"
    "github.com/pkg/errors"
    "google.golang.org/grpc"
    "google.golang.org/grpc/reflection"
    "google.golang.org/protobuf/encoding/protojson"
)

// These global variables makes it easy
// to mock these dependencies
// in unit tests.
var (
    netListen           = net.Listen
    configreaderReadEnv = configreader.ReadEnv
    jsonMarshal         = json.Marshal
    protojsonUnmarshal  = protojson.Unmarshal
)

// Server defines the available operations for gRPC server.
type Server interface {
    // Serve is called for serving requests.
    Serve() error
    // GracefulStop is called for stopping the server.
    GracefulStop()
    // RandomPoetries returns a random list of poetries.
    RandomPoetries(ctx context.Context, in *poetry.RandomPoetriesRequest) (*poetry.PoetryList, error)
}

// server implements Server.
type server struct {
    listener   net.Listener
    grpcServer *grpc.Server
    poetryDb   poetrydb.PoetryDb
}

func (s *server) Serve() error {
    return s.grpcServer.Serve(s.listener)
}

func (s *server) GracefulStop() {
    s.grpcServer.GracefulStop()
}

// NewServer creates a new gRPC server.
func NewServer(port int) (Server, error) {
    server := new(server)
    listener, err := netListen("tcp", fmt.Sprintf(":%d", port))
    if err != nil {
        return server, errors.Wrap(err, "tcp listening")
    }
    server.listener = listener
    config, err := configreaderReadEnv()
    if err != nil {
        return server, errors.Wrap(err, "reading env vars")
    }
    server.poetryDb = poetrydb.NewPoetryDb(config.PoetrydbBaseUrl, config.PoetrydbHttpTimeout)
    server.grpcServer = grpc.NewServer()
    poetry.RegisterProtobufServiceServer(server.grpcServer, server)
    reflection.Register(server.grpcServer)
    return server, nil
}

func (s *server) RandomPoetries(ctx context.Context, in *poetry.RandomPoetriesRequest) (*poetry.PoetryList, error) {
    pbPoetryList := new(poetry.PoetryList)
    poetryList, err := s.poetryDb.Random(int(in.NumberOfPoetries))
    if err != nil {
        return pbPoetryList, errors.Wrap(err, "requesting random poetry")
    }
    json, err := jsonMarshal(poetryList)
    if err != nil {
        return pbPoetryList, errors.Wrap(err, "marshalling json")
    }
    err = protojsonUnmarshal(json, pbPoetryList)
    if err != nil {
        return pbPoetryList, errors.Wrap(err, "unmarshalling proto")
    }
    return pbPoetryList, nil
}


```

### Running it

Here's the related targets in [Makefile](https://en.wikipedia.org/wiki/Make_(software)?trk=article-ssr-frontend-pulse_little-text-block) to run the server:

```

.PHONY: build
## build: builds server's binary
build:
    @ go build -a -installsuffix cgo -o main .

.PHONY: run
## run: runs the server
run: build
    @ ./main

```

So let's run the server:

```

$ make run
GRPC SERVER : 2022/03/21 10:07:14.846821 main.go:19: main: Initializing GRPC server
GRPC SERVER : 2022/03/21 10:07:14.847286 main.go:32: main: GRPC server listening on port 4040


```

### Invoking the gRPC service

Now the cool part: what if we wanted a nice, clean tool like [Postman](https://www.postman.com/?trk=article-ssr-frontend-pulse_little-text-block) (used to test [REST](https://en.wikipedia.org/wiki/Representational_state_transfer?trk=article-ssr-frontend-pulse_little-text-block) APIs) to makes it easy to call [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) services?

[Bloomrpc](https://github.com/bloomrpc/bloomrpc?trk=article-ssr-frontend-pulse_little-text-block) is here to help. You just browse your [.proto](https://developers.google.com/protocol-buffers/docs/proto3?trk=article-ssr-frontend-pulse_little-text-block) files and you'll be ready to invoke it:

![No alt text provided for this image](/assets/images/2022-03-21-524c455f-acee-4f62-8d6e-c7dd597bf896/1647868276536.png)

And here you go. We've asked one random poetry, and now we can appreciate it.

### Time to Dockerize it!

Now that our app is working, let's bake a [Docker](https://www.docker.com/?trk=article-ssr-frontend-pulse_little-text-block) image for it.

Here's our [Dockerfile](https://docs.docker.com/engine/reference/builder/?trk=article-ssr-frontend-pulse_little-text-block):

```

FROM golang:alpine

# Install git and ca-certificates (needed to be able to call HTTPS)
RUN apk --update add ca-certificates git

# Move to working directory /app
WORKDIR /app

# Copy the code into the container
COPY . .

# Download dependencies using go mod
RUN go mod download

# Build the application's binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o main .

# Command to run the application when starting the container
CMD ["/app/main"]


```

Notice:

- we're installing git because [Golang](http://golang.org?trk=article-ssr-frontend-pulse_little-text-block) tooling uses it, otherwise we would get an error "go: missing Git command. See https://golang.org/s/gogetcmd";
- we're installing 'ca-certificates' because [PoetryDB](https://poetrydb.org/index.html?trk=article-ssr-frontend-pulse_little-text-block) uses [HTTPS](https://en.wikipedia.org/wiki/HTTPS?trk=article-ssr-frontend-pulse_little-text-block), otherwise we would get an error "certificate signed by unknown authority".

Building the image

Now let's build it. Here's the [Makefile](https://en.wikipedia.org/wiki/Make_(software)?trk=article-ssr-frontend-pulse_little-text-block) target:

```

.PHONY: build-docker-image
## build-docker-image: builds the docker image
build-docker-image:
    @ docker build . -t docker-grpc-service-tutorial

```

Invoking it:

```

$ make build-docker-image
Sending build context to Docker daemon  13.71MB
Step 1/7 : FROM golang:alpine
 ---> 0e3b02146c47
Step 2/7 : RUN apk --update add ca-certificates git
 ---> Using cache
 ---> c326d9aa8cfc
Step 3/7 : WORKDIR /app
 ---> Using cache
 ---> 6c485ff6b69d
Step 4/7 : COPY . .
 ---> 9af131a39537
Step 5/7 : RUN go mod download
 ---> Running in a644255b6578
Removing intermediate container a644255b6578
 ---> 3b43ba797d11
Step 6/7 : RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o main .
 ---> Running in 01b6ce6172a9
Removing intermediate container 01b6ce6172a9
 ---> b1eaebffb306
Step 7/7 : CMD ["/app/main"]
 ---> Running in e0ed88e2a687
Removing intermediate container e0ed88e2a687
 ---> edb7869f01a6
Successfully built edb7869f01a6
Successfully tagged docker-grpc-service-tutorial:latest

Use 'docker scan' to run Snyk tests against images to find vulnerabilities and learn how to fix them

```

Running it as a Docker container

Here's the [Makefile](https://en.wikipedia.org/wiki/Make_(software)?trk=article-ssr-frontend-pulse_little-text-block) target:

```

.PHONY: build-docker-image
## build-docker-image: builds the docker image
build-docker-image:
    @ docker build . -t docker-grpc-service-tutorial

.PHONY: run-docker
## run-docker: runs the server as a Docker container
run-docker: build-docker-image
    @ docker run -p 4040:4040 docker-grpc-service-tutorial
```

Invoking it:

```

 $ make run-docker
Sending build context to Docker daemon  13.71MB
Step 1/7 : FROM golang:alpine
 ---> 0e3b02146c47
Step 2/7 : RUN apk --update add ca-certificates git
 ---> Using cache
 ---> c326d9aa8cfc
Step 3/7 : WORKDIR /app
 ---> Using cache
 ---> 6c485ff6b69d
Step 4/7 : COPY . .
 ---> 95f88bbbc63e
Step 5/7 : RUN go mod download
 ---> Running in 227656a7a691
Removing intermediate container 227656a7a691
 ---> b6765354b254
Step 6/7 : RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o main .
 ---> Running in a8e881248c52
Removing intermediate container a8e881248c52
 ---> a05de0412553
Step 7/7 : CMD ["/app/main"]
 ---> Running in e0009bc99088
Removing intermediate container e0009bc99088
 ---> 351069eab03d
Successfully built 351069eab03d
Successfully tagged docker-grpc-service-tutorial:latest

Use 'docker scan' to run Snyk tests against images to find vulnerabilities and learn how to fix them
GRPC SERVER : 2022/03/21 13:30:18.404250 main.go:19: main: Initializing GRPC server
GRPC SERVER : 2022/03/21 13:30:18.404646 main.go:32: main: GRPC server listening on port 4040

```

And then you can invoke the service via [Bloomrpc](https://github.com/bloomrpc/bloomrpc?trk=article-ssr-frontend-pulse_little-text-block) like we did before.

Multistage build

One of [Docker](https://www.docker.com/?trk=article-ssr-frontend-pulse_little-text-block)'s best practice is keeping the image size small, by having only the binary file then we make our image even smaller from the previous one. To achieve this we will use a technique called [multistage build](https://docs.docker.com/develop/develop-images/multistage-build/?trk=article-ssr-frontend-pulse_little-text-block) which means we will build our image with multiple steps.

Here's our [Dockerfile](https://docs.docker.com/engine/reference/builder/?trk=article-ssr-frontend-pulse_little-text-block).multistage:

```

FROM golang:alpine AS builder

# Install git and ca-certificates (needed to be able to call HTTPS)
RUN apk --update add ca-certificates git

# Move to working directory /app
WORKDIR /app

# Copy the code into the container
COPY . .

# Download dependencies using go mod
RUN go mod download

# Build the application's binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o main .

# Build a smaller image that will only contain the application's binary
FROM scratch

# Move to working directory /app
WORKDIR /app

# Copy certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

# Copy application's binary
COPY --from=builder /app .

# Command to run the application when starting the container
CMD ["./main"]


```

Here are the [Makefile](https://en.wikipedia.org/wiki/Make_(software)?trk=article-ssr-frontend-pulse_little-text-block) targets:

```

.PHONY: build-docker-image-multistage
## build-docker-image-multistage: builds a smaller docker image
build-docker-image-multistage:
    @ docker build -f Dockerfile.multistage  . -t docker-grpc-service-tutorial

.PHONY: run-docker-multistage
## run-docker-multistage: runs the server as a Docker container, using the smaller image
run-docker-multistage: build-docker-image-multistage
    @ docker run -p 4040:4040 docker-grpc-service-tutorial

```

Notice that we can name [Dockerfile](https://docs.docker.com/engine/reference/builder/?trk=article-ssr-frontend-pulse_little-text-block) whatever we want it, as long as we speficy if via '-f' flag.

Invoking it:

```

$ make run-docker-multistage
Sending build context to Docker daemon  13.71MB
Step 1/11 : FROM golang:alpine AS builder
 ---> 0e3b02146c47
Step 2/11 : RUN apk --update add ca-certificates git
 ---> Using cache
 ---> c326d9aa8cfc
Step 3/11 : WORKDIR /app
 ---> Using cache
 ---> 6c485ff6b69d
Step 4/11 : COPY . .
 ---> 8be509098958
Step 5/11 : RUN go mod download
 ---> Running in 776490901c8e
Removing intermediate container 776490901c8e
 ---> ec0d94130a65
Step 6/11 : RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o main .
 ---> Running in fa2e87f052ad
Removing intermediate container fa2e87f052ad
 ---> 57680526aaa1
Step 7/11 : FROM scratch
 --->
Step 8/11 : WORKDIR /app
 ---> Running in 0cc6905bb002
Removing intermediate container 0cc6905bb002
 ---> e41a9cb16982
Step 9/11 : COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
 ---> 8429312feec5
Step 10/11 : COPY --from=builder /app .
 ---> 3d1c20349d38
Step 11/11 : CMD ["./main"]
 ---> Running in a4a88a400a96
Removing intermediate container a4a88a400a96
 ---> 0d27b2b85769
Successfully built 0d27b2b85769
Successfully tagged docker-grpc-service-tutorial:latest

Use 'docker scan' to run Snyk tests against images to find vulnerabilities and learn how to fix them
GRPC SERVER : 2022/03/21 13:37:50.456686 main.go:19: main: Initializing GRPC server
GRPC SERVER : 2022/03/21 13:37:50.457085 main.go:32: main: GRPC server listening on port 4040


```

And then you can invoke the service via [Bloomrpc](https://github.com/bloomrpc/bloomrpc?trk=article-ssr-frontend-pulse_little-text-block) like we did before.

## Conclusion

In this article we've covered a lot of nice things when building a [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) service in [Golang](http://golang.org?trk=article-ssr-frontend-pulse_little-text-block) from scratch:

- How to read [environment variables](https://en.wikipedia.org/wiki/Environment_variable?trk=article-ssr-frontend-pulse_little-text-block) into a [struct](https://go.dev/tour/moretypes/2?trk=article-ssr-frontend-pulse_little-text-block) so we can easily use them;
- How to delegate to an external [Docker](https://www.docker.com/?trk=article-ssr-frontend-pulse_little-text-block) image to compile our [.proto](https://developers.google.com/protocol-buffers/docs/proto3?trk=article-ssr-frontend-pulse_little-text-block) files;
- How to easily invoke [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) service via [Bloomrpc](https://github.com/bloomrpc/bloomrpc?trk=article-ssr-frontend-pulse_little-text-block);
- How to create a [Docker](https://www.docker.com/?trk=article-ssr-frontend-pulse_little-text-block) image using [multistage build](https://docs.docker.com/develop/develop-images/multistage-build/?trk=article-ssr-frontend-pulse_little-text-block).

## Download the source

Here: [https://bitbucket.org/tiagoharris/docker-grpc-service-tutorial/src/master/](https://bitbucket.org/tiagoharris/docker-grpc-service-tutorial/src/master/?trk=article-ssr-frontend-pulse_little-text-block)