---
layout: post
title:  "Building multi-platform Docker images on Apple Silicon with QEMU"
date:   2024-10-09 13:18:58 -0000
categories: docker qemu apple sillicon
---

![banner](/assets/images/2024-10-09-dokcer-multiplatform-image-build/banner.png)

Building Docker images for multiple architectures, such as `amd64` and `arm64`, can be a challenge, especially when running on an Apple Silicon (M1/M2/M3) machine. However, with [Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/) and [QEMU](https://www.qemu.org/), it's possible to create multi-platform images without much hassle. In this article, I’ll walk through how I resolved this challenge using my project [go-grpc-bin](https://github.com/tiagomelo/go-grpc-bin) as an example.

You can find more details about `go-grpc-bin` in [my previous blog post](https://tiagomelo.info/go/grpc/2024/08/28/go-grpc-bin.html) or in [Docker Hub](https://hub.docker.com/repository/docker/tiagoharris/go-grpc-bin/general).

# what is QEMU?

[QEMU](https://www.qemu.org/) (Quick Emulator) is a powerful open-source emulator that enables Docker to build and run containers for architectures different from the host machine. For example, if you're running Docker on an Apple Silicon Mac (`arm64`), [QEMU](https://www.qemu.org/) allows you to build Docker images for the `amd64` architecture (used by Intel and AMD processors).

It provides dynamic translation of CPU instructions, enabling you to emulate the `amd64` architecture on an `arm64` machine. This makes it possible to create cross-platform [Docker](https://www.docker.com) images using [Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/), ensuring that your containers can run on a wider range of platforms.

In the context of this project, [QEMU](https://www.qemu.org/) was essential for allowing me to build the [`go-grpc-bin`](https://github.com/tiagomelo/go-grpc-bin) project for both `amd64` and `arm64` architectures from my Apple Silicon machine, without needing a separate `x86` machine.

## how does QEMU work with Docker Buildx?

[Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/) automatically uses [QEMU](https://www.qemu.org/) when building for architectures that differ from the host. When you use the `--platform` flag with Buildx (for example, `--platform linux/amd64,linux/arm64`), [Docker](https://www.docker.com) routes the build process through [QEMU](https://www.qemu.org/), translating instructions as needed for the target architecture.

This seamless integration allows developers to create multi-platform images with a single build command, ensuring broader compatibility for containerized applications.

# the problem

While attempting to build a multi-platform Docker image using Docker Buildx on my Apple Silicon machine, I encountered an error:

```
rosetta error: Rosetta is only intended to run on Apple Silicon with a macOS host using Virtualization.framework with Rosetta mode enabled
```

The error occurred when trying to build the image for the `amd64` architecture. [Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/) couldn't handle the architecture mismatch, and Rosetta, which enables Intel (x86) applications to run on Apple Silicon, wasn’t configured for the build process.

# the solution

Here’s how I resolved the issue using [Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/), with a special focus on [QEMU](https://www.qemu.org/) to handle cross-platform builds.

## step 1: install Rosetta

Since I was on an Apple Silicon Mac, I needed to make sure Rosetta 2 was installed. This is Apple's compatibility layer that allows running amd64 binaries on `arm64` systems.

You can install [Rosetta 2](https://support.apple.com/en-us/102527) with the following command:

```
softwareupdate --install-rosetta
```

## step 2: ensure Buildx is initialized

Before building for multiple architectures, make sure [Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/) is initialized with proper platform support. Run the following commands:

```
docker buildx create --use
docker buildx inspect --bootstrap
```

Ensure that `linux/amd64` and `linux/arm64` are listed under `Platforms` in the output:

```
$ docker buildx inspect --bootstrap
[+] Building 1.8s (1/1) FINISHED                                                                                                                                            
 => [internal] booting buildkit                                                                                                                                        1.8s
 => => pulling image moby/buildkit:buildx-stable-1                                                                                                                     1.6s
 => => creating container buildx_buildkit_gallant_carson0                                                                                                              0.2s
Name:          gallant_carson
Driver:        docker-container
Last Activity: 2024-10-09 13:00:41 +0000 UTC

Nodes:
Name:                  gallant_carson0
Endpoint:              desktop-linux
Status:                running
BuildKit daemon flags: --allow-insecure-entitlement=network.host
BuildKit version:      v0.16.0
Platforms:             linux/arm64, linux/amd64, linux/amd64/v2, linux/riscv64, linux/ppc64le, linux/s390x, linux/386, linux/mips64le, linux/mips64, linux/arm/v7, linux/arm/v6

...
```

## step 3: build and push multi-platform image

With [Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/) and [QEMU](https://www.qemu.org/) working properly, the final step was to build and push the [Docker](https://www.docker.com) image for multiple architectures:

```
docker buildx build --platform linux/amd64,linux/arm64 -t tiagoharris/go-grpc-bin:latest --push .
```

This command builds the image for both platforms and pushes it to [Docker Hub](https://hub.docker.com). Now, the image is available for use on both amd64 and arm64 machines, making it highly flexible for deployments on different hardware architectures:

![docker hub](/assets/images/2024-10-09-dokcer-multiplatform-image-build/dockerhub.png)

# conclusion

With just a few steps, you can easily build and push multi-platform Docker images from an Apple Silicon machine using [Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/) and [QEMU](https://www.qemu.org/). This setup allows you to create images compatible with both amd64 (Intel/AMD) and arm64 (Apple Silicon) systems, ensuring your applications can be deployed on a wider range of environments.

By leveraging the power of [Docker Buildx](https://docs.docker.com/reference/cli/docker/buildx/) and [QEMU](https://www.qemu.org/), cross-platform development becomes much simpler, especially when working with cloud-native applications or microservices that need to run on various architectures.