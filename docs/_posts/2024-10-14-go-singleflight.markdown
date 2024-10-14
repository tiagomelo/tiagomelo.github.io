---
layout: post
title:  "Eliminating Redundant Requests in Go with Singleflight"
date:   2024-10-14 08:40:28 -0000
categories: go singleflight
---

![banner](/assets/images/2024-10-13-go-singleflight/banner.png)

In high-concurrency systems, redundant operations can lead to performance bottlenecks, increased latency, and unnecessary load on resources like databases or external APIs. [Go's](https://go.dev) [`singleflight`](https://pkg.go.dev/golang.org/x/sync/singleflight) package provides an elegant solution by ensuring that only one execution of a given operation is in progress at any time, regardless of how many concurrent requests are made for it.

In this article, we'll dive deep into the [`singleflight`](https://pkg.go.dev/golang.org/x/sync/singleflight) package, understand how it works, implement a realistic scenario, and discuss how it complements caching mechanisms.

## Understanding Singleflight

The `singleflight` package, found in the extended Go library (`golang.org/x/sync/singleflight`), is designed to suppress duplicate function calls with the same key. When multiple goroutines invoke the same function concurrently, [`singleflight`](https://pkg.go.dev/golang.org/x/sync/singleflight) ensures that only one execution proceeds. The other goroutines wait for the result and receive the same value when it's ready.

**Key Features:**

- **Deduplication of In-Flight Requests:** Prevents redundant executions of the same operation.
- **Result Sharing:** Distributes the outcome of a single execution to all waiting goroutines.
- **Concurrency Control:** Helps manage load on external resources by limiting duplicate access.

## How Singleflight Works

The following image illustrates how [`singleflight`](https://pkg.go.dev/golang.org/x/sync/singleflight) works in practice:

![single flight](/assets/images/2024-10-13-go-singleflight/singleFlight.png)

1. Multiple clients request the same resource (e.g., "find resource A").
2. Instead of each request hitting the database, [`singleflight`](https://pkg.go.dev/golang.org/x/sync/singleflight) consolidates the requests and only allows one to proceed.
3. The result of the database query is shared across all waiting requests.

## A Realistic Scenario: User Profile Service

Imagine a web application where users can view their profiles. The profile data is fetched from a database. Under normal load, fetching profiles is straightforward. However, during peak times or events (e.g., a promotion), multiple requests for the same profile might occur simultaneously.

### The Challenge

- **Redundant Database Queries:** Without control, each request triggers a separate database call.
- **Increased Load and Latency:** The database becomes overwhelmed, leading to slower response times.
- **Inefficient Resource Utilization:** Wastes computational resources on duplicate work.

### Implementing Singleflight

By integrating [`singleflight`](https://pkg.go.dev/golang.org/x/sync/singleflight), we can ensure that only one database query is made for a particular user profile, regardless of how many concurrent requests are made.

### Sample Code Implementation

Let's implement this scenario in Go.

```go

package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"sync"
	"time"

	"golang.org/x/sync/singleflight"
)

var (
	sfGroup singleflight.Group
	cache   = make(map[string]string)
	mu      sync.Mutex
)

// Simulated database call
func fetchFromDB(userID string) string {
	log.Printf("Fetching from DB for user: %s\n", userID)        // Log actual DB call
	time.Sleep(time.Duration(rand.Intn(500)) * time.Millisecond) // Simulate slow DB call
	return fmt.Sprintf("Profile data for user: %s", userID)
}

// Cached fetch with singleflight to avoid redundant database hits
func fetchUserProfile(ctx context.Context, userID string) (string, error) {
	mu.Lock()
	if profile, ok := cache[userID]; ok {
		mu.Unlock()
		return profile, nil
	}
	mu.Unlock()

	result, err, _ := sfGroup.Do(userID, func() (interface{}, error) {
		profile := fetchFromDB(userID)
		mu.Lock()
		cache[userID] = profile // Cache the result
		mu.Unlock()
		return profile, nil
	})

	if err != nil {
		return "", err
	}
	return result.(string), nil
}

func main() {
	ctx := context.Background()
	userID := "1234"

	// Simulate concurrent requests
	var wg sync.WaitGroup
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			profile, err := fetchUserProfile(ctx, userID)
			if err != nil {
				log.Println("Error fetching profile:", err)
				return
			}
			log.Println("Fetched profile:", profile)
		}()
	}

	wg.Wait()
}

```

### Running the Code

When you run the program, you should see output similar to:

```
$ go run main.go
2024/10/13 17:56:08 Fetching from DB for user: 1234
2024/10/13 17:56:08 Fetched profile: Profile data for user: 1234
2024/10/13 17:56:08 Fetched profile: Profile data for user: 1234
2024/10/13 17:56:08 Fetched profile: Profile data for user: 1234
2024/10/13 17:56:08 Fetched profile: Profile data for user: 1234
2024/10/13 17:56:08 Fetched profile: Profile data for user: 1234
2024/10/13 17:56:08 Fetched profile: Profile data for user: 1234
2024/10/13 17:56:08 Fetched profile: Profile data for user: 1234
2024/10/13 17:56:08 Fetched profile: Profile data for user: 1234
2024/10/13 17:56:08 Fetched profile: Profile data for user: 1234
2024/10/13 17:56:08 Fetched profile: Profile data for user: 1234
```

Notably, the log entry `Fetching from DB for user: 1234` appears only once, even though there are 10 concurrent requests. This demonstrates that [`singleflight`](https://pkg.go.dev/golang.org/x/sync/singleflight) effectively consolidated the database calls into a single execution.

## Deep Dive into Singleflight

### How Does It Work?

- **Key-Based Execution:** Each call to `sfGroup.Do` with the same key (e.g., `userID`) is managed.
- **First Caller Proceeds:** The first goroutine initiates the execution.
- **Subsequent Callers Wait:** Other goroutines with the same key wait for the result.
- **Result Distribution:** Once the execution completes, all waiting goroutines receive the result.

### Benefits

- **Efficiency:** Reduces redundant work and resource consumption.
- **Performance:** Minimizes latency caused by multiple identical operations.
- **Scalability:** Helps maintain performance under high load.

## Singleflight vs Cache

While both [`singleflight`](https://pkg.go.dev/golang.org/x/sync/singleflight) and caching aim to optimize performance, they address different challenges.

### Singleflight

- **Purpose:** Prevents concurrent execution of identical operations.
- **Scope:** Operates during the execution window of a function.
- **Usage Scenario:** Ideal for scenarios where cache misses can cause a surge in identical requests (cache stampede).

### Cache

- **Purpose:** Stores results to avoid re-executing operations over time.
- **Scope:** Persistent storage until invalidation or expiration.
- **Usage Scenario:** Reduces load by serving frequently requested data without recalculating or refetching.

## Complementary Tools

In our implementation, we use both:

- **Cache Check First:** Quickly returns cached data if available.
- **Singleflight During Cache Misses:** Ensures only one fetch occurs when the data isn't cached.

This combination optimizes performance by reducing database load and preventing redundant fetches during cache misses.

## Conclusion

Go's [`singleflight`](https://pkg.go.dev/golang.org/x/sync/singleflight) package is a powerful tool for optimizing high-concurrency applications. By preventing redundant operations, it enhances performance and resource utilization. When combined with caching, it offers a comprehensive strategy to handle both repeated and concurrent identical requests efficiently.

---

**Note:** The `singleflight` package is not part of Go's standard library. You need to import it using:

```go
import "golang.org/x/sync/singleflight"
```

This package is maintained by the [Go](https://go.dev) team and can be found in the extended [Go](https://go.dev) libraries.
