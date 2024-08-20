---
layout: post
title:  "Harnessing the Power of eBPF: Blocking IPs with Go and XDP, the easy way"
date:   2024-08-12 13:12:09 -0000
categories: golang ebpf
image: "/assets/images/2024-08-12-golang-ebpf-drop-packets-from-ip/banner.png"
---

![banner](/assets/images/2024-08-12-golang-ebpf-drop-packets-from-ip/banner.png)

## Introduction

In recent years, [eBPF (extended Berkeley Packet Filter)](https://ebpf.io/) has emerged as a powerful technology for network monitoring, security enforcement, and performance optimization. Originally designed for packet filtering, [eBPF](https://ebpf.io/) has evolved into a versatile tool that allows developers to run sandboxed programs in the [Linux kernel](https://en.wikipedia.org/wiki/Linux_kernel) without changing kernel source code or loading kernel modules. This capability opens up a world of possibilities, from tracking system calls to implementing advanced networking features.

This article explores the strengths of [eBPF](https://ebpf.io/), particularly in networking, by walking through an example project that demonstrates how to block network packets from a specific IP address using eBPF, written in [C](https://en.wikipedia.org/wiki/C_(programming_language)), and a [Go](https://go.dev/) application that manages the [eBPF](https://ebpf.io/) program. By the end of this article, you will understand the basics of [eBPF](https://ebpf.io/), how to integrate it with [Go](https://go.dev/), and how to test the solution using a simple HTTP server.

Make sure you checkout [the getting started page](https://ebpf-go.dev/guides/getting-started/) from ebpf.io so you familiarize yourself.

## What is eBPF?

[eBPF](https://ebpf.io/) is a virtual machine within the [Linux kernel](https://en.wikipedia.org/wiki/Linux_kernel) that allows the execution of bytecode at various hooks in the kernel, enabling custom behaviors for packet filtering, system call tracing, and more. Programs written in [eBPF](https://ebpf.io/) can be loaded into the kernel and attached to various hooks, such as network interfaces or system events. Due to its performance and flexibility, eBPF is widely used in high-performance networking tools, security products, and observability solutions.

Key strengths of [eBPF](https://ebpf.io/) include:

1. High Performance: [eBPF](https://ebpf.io/) programs run in the kernel, close to the hardware, enabling high-speed packet processing and low-latency operations.

2. Safety: [eBPF](https://ebpf.io/) programs are verified before execution, ensuring they won't crash the system or misbehave. The verifier checks the code for safety properties, such as bounded loops and valid memory access.

3. Flexibility: Developers can dynamically load and update [eBPF](https://ebpf.io/) programs, making it easier to deploy and manage custom features without kernel recompilation.

4. Observability and Security: [eBPF](https://ebpf.io/) is ideal for monitoring system events, network traffic, and enforcing security policies at the kernel level.

## Example Project: Blocking IPs with eBPF and Go

### Project Overview

The project demonstrates how to use [eBPF](https://ebpf.io/) to block network packets from a specific IP address. It consists of an [eBPF](https://ebpf.io/) program written in [C](https://en.wikipedia.org/wiki/C_(programming_language)) that filters incoming packets, and a [Go](https://go.dev/) application that loads the [eBPF](https://ebpf.io/) program, configures the IP to block, and attaches the program to a network interface.

#### eBPF Program (drop.c)

The [eBPF](https://ebpf.io/) program is responsible for inspecting incoming packets at the network interface level. It checks the source IP address of each packet and drops packets that match a specified IP.

I didn't program in [C](https://en.wikipedia.org/wiki/C_(programming_language)) for several years by now, so definitely it was a good exercise. I've commented out the code to help everyone (including me) understand what we are doing here.

```
//go:build ignore

// Copyright (c) 2024 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.

#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/in.h>
#include <bpf/bpf_helpers.h>

// Define a BPF map to store the blocked IP address
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY); // Map type is an array
    __uint(max_entries, 1);           // Only one entry in the map
    __type(key, __u32);               // Key type is a 32-bit unsigned integer
    __type(value, __u32);             // Value type is a 32-bit unsigned integer
} blocked_ip_map SEC(".maps");        // Place the map in the ".maps" section

// Define the XDP program
SEC("xdp")
int xdp_drop_ip(struct xdp_md *ctx) {
    // Pointers to the start and end of the packet data
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;
    struct ethhdr *eth = data; // Ethernet header
    struct iphdr *ip;          // IP header
    __u32 key = 0;             // Key to access the blocked IP map
    __u32 *blocked_ip;         // Pointer to the blocked IP address

    // Check if the packet is an Ethernet packet and if the Ethernet header is complete
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS; // Pass the packet if the Ethernet header is incomplete

    // Check if the packet is an IP packet
    if (eth->h_proto != __constant_htons(ETH_P_IP))
        return XDP_PASS; // Pass the packet if it is not an IP packet

    ip = (struct iphdr *)(eth + 1); // Point to the IP header

    // Check if the packet is a complete IP packet
    if ((void *)(ip + 1) > data_end)
        return XDP_PASS; // Pass the packet if the IP header is incomplete

    // Read the blocked IP address from the map
    blocked_ip = bpf_map_lookup_elem(&blocked_ip_map, &key);
    if (!blocked_ip) {
        bpf_printk("Blocked IP not found in map\n");
        return XDP_PASS; // Pass the packet if the blocked IP is not found in the map
    }

    // Convert the blocked IP address to network byte order
    __u32 blocked_ip_network_order = __constant_htonl(*blocked_ip);

    // Drop the packet if it matches the blocked IP address
    if (ip->saddr == blocked_ip_network_order) {
        // Extract each byte of the IP address for logging
        unsigned char *ip_bytes = (unsigned char *)&ip->saddr;
        bpf_printk("Dropping packet from IP: %d.%d.%d.%d\n",
                   ip_bytes[0], ip_bytes[1], ip_bytes[2], ip_bytes[3]);
        return XDP_DROP; // Drop the packet
    }

    return XDP_PASS; // Pass the packet if it does not match the blocked IP address
}

// Define the license for the eBPF program
char LICENSE[] SEC("license") = "GPL";
```

This program reads the blocked IP address from a [BPF map](https://ebpf-docs.dylanreimerink.nl/linux/concepts/maps/) and compares it against the source IP of incoming packets. If a match is found, the packet is dropped.

The reason of `//go:build ignore`, per [ebpf.io](https://ebpf-go.dev/guides/getting-started/#ebpf-c-program), is as follows:

> When putting C files alongside Go files, they need to be excluded by a Go build tag, otherwise go build will complain with C source files not allowed when not using cgo or SWIG. The Go toolchain can safely ignore our eBPF C files.

#### Generating Go Bindings: Understanding `gen.go`

The project includes a file named gen.go, which plays a crucial role in generating the [Go](https://go.dev/) bindings for the [eBPF](https://ebpf.io/) program. This file contains a special go:generate directive that automates the process of converting the [eBPF](https://ebpf.io/) [C](https://en.wikipedia.org/wiki/C_(programming_language)) code into a format that can be used in [Go](https://go.dev/).

```
// Copyright (c) 2024 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.

package main

//go:generate go run github.com/cilium/ebpf/cmd/bpf2go drop drop.c
```

**Breaking Down the `go:generate` Directive**

- `go:generate`: This directive tells the [Go](https://go.dev/) toolchain to run the specified command whenever go generate is executed. It is a powerful feature in [Go](https://go.dev/) that automates code generation tasks.

- `go run github.com/cilium/ebpf/cmd/bpf2go drop drop.c`: This command uses the bpf2go tool provided by the Cilium eBPF library to generate [Go](https://go.dev/) code from the [eBPF](https://ebpf.io/) program defined in drop.c.

    - `bpf2go drop drop.c`: The bpf2go tool takes the [eBPF](https://ebpf.io/) program (drop.c) and generates two files:
        - `drop_bpfel.go`: Contains the [Go](https://go.dev/) bindings for the [eBPF](https://ebpf.io/) program for little-endian architectures.
        - `drop_bpfeb.go`: Contains the [Go](https://go.dev/) bindings for the [eBPF](https://ebpf.io/) program for big-endian architectures.

These generated files include the [Go](https://go.dev/) definitions of the [BPF map](https://ebpf-docs.dylanreimerink.nl/linux/concepts/maps/), the [XDP](https://en.wikipedia.org/wiki/Express_Data_Path) program, and functions to interact with the [BPF map](https://ebpf-docs.dylanreimerink.nl/linux/concepts/maps/). This process simplifies the integration of [eBPF](https://ebpf.io/) programs into [Go](https://go.dev/) applications by providing native Go types and methods to manage and interact with the [eBPF](https://ebpf.io/) program.

#### Go Application (main.go)

The [Go](https://go.dev/) application handles loading the [eBPF](https://ebpf.io/) program, setting the blocked IP address, and attaching the [eBPF](https://ebpf.io/) program to a network interface.

```
package main

import (
	"encoding/binary"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"

	"github.com/cilium/ebpf/link"
)

func ipToUint32(ip string) (uint32, error) {
	parsedIP := net.ParseIP(ip)
	if parsedIP == nil {
		return 0, fmt.Errorf("invalid IP address: %s", ip)
	}
	ipv4 := parsedIP.To4()
	if ipv4 == nil {
		return 0, fmt.Errorf("not an IPv4 address: %s", ip)
	}
	return binary.BigEndian.Uint32(ipv4), nil
}

func main() {
	// Load the eBPF objects from the generated code
	var objs dropObjects
	if err := loadDropObjects(&objs, nil); err != nil {
		log.Fatalf("loading objects: %v", err)
	}
	defer objs.Close()

	// Get the IP address to block from the command line arguments
	if len(os.Args) < 2 {
		log.Fatalf("usage: %s <blocked-ip> [interface]", os.Args[0])
	}
	blockedIP := os.Args[1]
	blockedIPUint32, err := ipToUint32(blockedIP)
	if err != nil {
		log.Fatalf("invalid IP address: %v", err)
	}

	fmt.Printf("Blocking IP: %s (0x%x)\n", blockedIP, blockedIPUint32)

	// Write the blocked IP address to the BPF map
	key := uint32(0)
	if err := objs.BlockedIpMap.Put(key, blockedIPUint32); err != nil {
		log.Fatalf("writing to BPF map: %v", err)
	}

	// Find the network interface to attach the program to
	ifaceName := "eth0"
	if len(os.Args) > 2 {
		ifaceName = os.Args[2]
	}

	// Get the network interface by name
	iface, err := net.InterfaceByName(ifaceName)
	if err != nil {
		log.Fatalf("getting interface %s: %v", ifaceName, err)
	}

	// Attach the XDP program to the network interface
	link, err := link.AttachXDP(link.XDPOptions{
		Program:   objs.XdpDropIp,
		Interface: iface.Index,
	})
	if err != nil {
		log.Fatalf("attaching XDP program to interface %s: %v", ifaceName, err)
	}
	defer link.Close()

	fmt.Printf("Attached XDP program to interface %s\n", ifaceName)

	// Wait for a signal (e.g., Ctrl+C) to exit
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	<-sig

	fmt.Println("Detaching XDP program and exiting")
}

```

In this application, the `ipToUint32` function converts a human-readable IP address into the format required by the [eBPF](https://ebpf.io/) program. The blocked IP is then stored in the [BPF map](https://ebpf-docs.dylanreimerink.nl/linux/concepts/maps/), and the [XDP](https://en.wikipedia.org/wiki/Express_Data_Path) program is attached to the specified network interface.

### Building and Running

These are the steps:

1. Build the eBPF program using  and generate the necessary [Go](https://go.dev/) bindings.
2. Compile the [Go](https://go.dev/) application.
3. Run the application, specifying the IP to block and the network interface.

In our `Makefile` we have:

```
.PHONY: generate
## generate: generate the eBPF code
generate:
	@ go generate

.PHONY: build
## build: build the application
build:
	@ go build -o ebpfdrop

.PHONY: run
## run: run the application
run: generate build
	@ if [ -z "$(BLOCKED_IP)" ]; then echo >&2 please set blocked ip via the variable BLOCKED_IP; exit 2; fi
	@ sudo ./ebpfdrop $(BLOCKED_IP) $(INTERFACE)
```

So let's call `run` target:

```
make run BLOCKED_IP=<ip> INTERFACE=<iface>
```

If we ommit interface, `eth0` will be the default value.

![running](/assets/images/2024-08-12-golang-ebpf-drop-packets-from-ip/running.png)

### Testing it

To test the eBPF program, we can either:

- Ping the Blocked IP: Attempt to send packets from the blocked IP and observe that they are dropped.
- Use a Simple HTTP Server: The included server.go file runs a simple HTTP server on port 8080. By accessing this server from different IP addresses, you can verify whether packets from the blocked IP are dropped.

**Ping**

![unable to ping](/assets/images/2024-08-12-golang-ebpf-drop-packets-from-ip/unableToPing.png)

**Calling the HTTP server**

```
go run server/server.go 
```

Then let's try to call it:

![unable to call http server](/assets/images/2024-08-12-golang-ebpf-drop-packets-from-ip/unableToCalHttpServer.png)

### Observing the Results

After running the [eBPF](https://ebpf.io/) program, you can trace its execution and view logs of dropped packets using bpftool. This tool is essential for debugging and verifying that your [eBPF](https://ebpf.io/) program behaves as expected.

To trace the [eBPF](https://ebpf.io/) program and see real-time logs, use the following command:

```
sudo bpftool prog tracelog pipe
```

For which we have a correspondent target in our `Makefile`:

```
.PHONY: trace-pipe
## trace-pipe: trace the eBPF program
trace-pipe:
	@ sudo bpftool prog tracelog pipe
```

This command will display log messages generated by your [eBPF](https://ebpf.io/) program, such as when a packet is dropped due to a blocked IP. This is particularly useful for confirming that your IP blocking logic is functioning correctly.

If you haven't installed bpftool yet, you can usually do so via your package manager:

```
sudo apt-get install bpftool   # On Debian-based systems
sudo dnf install bpftool       # On Fedora-based systems
```

Using `bpftool` with the `tracelog` command allows you to observe the program's behavior in real-time, providing valuable insights during development and testing.

Here's the output when the other machine was trying to ping the machine running the [eBPF](https://ebpf.io/) program:

![blocking ping](/assets/images/2024-08-12-golang-ebpf-drop-packets-from-ip/blockingPing.png)

And here's the output when the other machine was trying to call the HTTP server in the machine running the [eBPF](https://ebpf.io/) program:

![blocking http server call](/assets/images/2024-08-12-golang-ebpf-drop-packets-from-ip/blockingHttpCall.png)

### Allowing packets from IP

With our [eBPF](https://ebpf.io/) program stopped, we see that we can both:

1. ping

![able to ping](/assets/images/2024-08-12-golang-ebpf-drop-packets-from-ip/ableToPing.png)

2. call HTTP server

![able to ping](/assets/images/2024-08-12-golang-ebpf-drop-packets-from-ip/ableToCallHttpServer.png)

### Dinamically dropping and allowing packets from IP

The beauty of this solution is that we can extend the kernel's behavior dinamically.

Here's the output when the [eBPF](https://ebpf.io/) program was running, then stopped, then running it again:

![canCannot](/assets/images/2024-08-12-golang-ebpf-drop-packets-from-ip/canCannot.png)

## Conclusion

In this article, we've explored the power and versatility of [eBPF](https://ebpf.io/) and XDP—two cutting-edge technologies in the Linux kernel that provide unparalleled capabilities for network processing, security, and observability. Through our example project, we've demonstrated how these tools can be used to efficiently block network traffic from a specified IP address, showcasing the practical applications of [eBPF](https://ebpf.io/) and [XDP](https://en.wikipedia.org/wiki/Express_Data_Path) in real-world scenarios.

By combining the low-latency packet processing of [XDP](https://en.wikipedia.org/wiki/Express_Data_Path) with the flexibility and safety of [eBPF](https://ebpf.io/), developers can create high-performance networking solutions that operate directly within the kernel, close to the data path. This proximity allows for fine-grained control over network traffic, enabling use cases such as DDoS mitigation, load balancing, and custom packet filtering, all without compromising system stability or requiring kernel modifications.

The example project not only illustrates the technical implementation of blocking packets from a given IP but also highlights the broader potential of [eBPF](https://ebpf.io/) and [XDP](https://en.wikipedia.org/wiki/Express_Data_Path) in modern network engineering. Whether you're looking to enhance network security, improve application performance, or develop new networking features, [eBPF](https://ebpf.io/) and [XDP](https://en.wikipedia.org/wiki/Express_Data_Path) provide a robust foundation for building powerful, efficient, and scalable solutions.

As you continue to explore the capabilities of [eBPF](https://ebpf.io/) and [XDP](https://en.wikipedia.org/wiki/Express_Data_Path), remember that these technologies represent just the beginning of what's possible in kernel-level programming. The Linux community and ecosystem continue to innovate, expanding the reach of [eBPF](https://ebpf.io/) and [XDP](https://en.wikipedia.org/wiki/Express_Data_Path) into new domains and enabling even more sophisticated and high-performance applications.

## Download the source

Here: [https://github.com/tiagomelo/ebpf-drop-packets-from-ip](https://github.com/tiagomelo/ebpf-drop-packets-from-ip)