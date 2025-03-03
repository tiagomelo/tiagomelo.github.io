---
layout: post
title:  "Real-Time Flight Tracking in Go with Redis and JSON Streaming"
date:   2025-03-03 12:24:02 -0000
categories: golang rest api streaming
image: "/assets/images/2025-03-03-realtime-flight-tracking-go-redis/banner.png"
---

![banner](/assets/images/2025-03-03-realtime-flight-tracking-go-redis/banner.png)

In my previous article, **["Efficient JSON Streaming in a REST API"](https://tiagomelo.info/golang/rest/api/streaming/2025/02/26/efficient-json-streaming-rest-api.html)**, I demonstrated how a client can efficiently **stream JSON data to a server**, reducing memory overhead for large payloads.

In this article, we're flipping the scenario—this time, the **server** is the one streaming data to the client. We'll build a **real-time flight tracking service** in Go, using:
- The [**OpenSky API**](https://opensky-network.org/) for live flight data.
- **[Redis](https://redis.io/) Pub/Sub** for real-time message distribution.
- **Chunked HTTP responses** to stream JSON objects as they arrive.

This approach enables clients to receive **continuous flight updates** without polling, making it ideal for real-time applications.

---

## Understanding JSON streaming
[JSON Streaming](https://en.wikipedia.org/wiki/JSON_streaming) is a technique for handling large datasets **incrementally**, instead of loading an entire JSON document at once.

In traditional APIs:
- A client makes a request.
- The server processes everything.
- The entire JSON response is sent **only after** processing completes.

With **streaming**, the server **sends partial JSON objects** as soon as they are available. This reduces memory usage and improves performance for **real-time applications**.

---

## Why real-time streaming?

Polling APIs for frequent updates is inefficient. Instead:
- We use **Redis Pub/Sub** to distribute flight status updates.
- Clients receive new data **instantly** when a message is published.
- JSON is **streamed in chunks** over an open HTTP connection.

---

## How it works

1. The **Redis publisher** fetches live flight data from the **OpenSky API**.
2. The publisher **pushes** the data to a **Redis Pub/Sub** topic.
3. The API **subscribes to Redis** and streams new flight updates as they arrive.
4. Clients remain connected to **receive real-time updates**.

![diagram](/assets/images/2025-03-03-realtime-flight-tracking-go-redis/diagram.png)

---

## Building the Redis publisher

Our **Redis Publisher** fetches flight data and publishes it in **JSON format** to a Redis **Pub/Sub** channel.

### Publisher Code

```go
// Copyright (c) 2025 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.

package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/pkg/errors"
	"github.com/tiagomelo/go-flight-tracker-service/config"
	"github.com/tiagomelo/go-flight-tracker-service/opensky"
	"github.com/tiagomelo/go-flight-tracker-service/redis"
)

func run(log *slog.Logger) error {
	ctx := context.Background()
	defer log.InfoContext(ctx, "completed")

	log.InfoContext(ctx, "initializing redis-publisher")

	// =========================================================================
	// configuration Reading.

	cfg, err := config.Read()
	if err != nil {
		return errors.Wrap(err, "reading configuration")
	}

	// =========================================================================
	// Redis Client.

	redisClient := redis.NewClient(cfg.RedisAddress, cfg.RedisPassword, cfg.RedisDb)
	defer redisClient.Close()

	// =========================================================================
	// OpenSky Client.

	openSkyClient := opensky.NewClient(cfg.OpenSkyUsername, cfg.OpenSkyPassword, time.Duration(cfg.OpenSkyHttpTimeoutInSeconds)*time.Second)

	// channel to listen for OS shutdown signals.
	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

	// channel for errors.
	fetchingErrors := make(chan error, 1)
	redisPublishingErrors := make(chan error, 1)

	// start OpenSky fetching in a loop.
	go func() {
		ticker := time.NewTicker(time.Duration(cfg.RedisPublishIntervalInSeconds) * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-shutdown:
				log.InfoContext(ctx, "Shutdown signal received. Stopping publisher.")
				return
			case <-ticker.C:
				log.InfoContext(ctx, "publishing data")
				data, err := openSkyClient.AllStatesWithinBrazil(ctx)
				if err != nil {
					fetchingErrors <- err
					return
				}
				err = redisClient.Publish(ctx, cfg.RedisTopic, data)
				if err != nil {
					redisPublishingErrors <- err
					return
				}
			}
		}
	}()

	// blocking main waiting for shutdown or errors.
	select {
	case err := <-fetchingErrors:
		return errors.Wrap(err, "fetching error")
	case err := <-redisPublishingErrors:
		return errors.Wrap(err, "publishing error")
	case sig := <-shutdown:
		log.InfoContext(ctx, fmt.Sprintf("Starting shutdown: %v", sig))
		if err := redisClient.Close(); err != nil {
			return err
		}
	}

	return nil
}

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	if err := run(log); err != nil {
		log.Error("error", slog.Any("err", err))
		os.Exit(1)
	}
}

```

This **publishes** flight data every few seconds.

---

## Implementing the streaming API

Our API **subscribes to Redis** and streams data **as it arrives**.

### Streaming response handler

```go
// Copyright (c) 2025 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.

package flights

import (
	"context"
	"encoding/json"
	"log"
	"log/slog"
	"net/http"

	redisV9 "github.com/redis/go-redis/v9"
	"github.com/tiagomelo/go-flight-tracker-service/cast"
	"github.com/tiagomelo/go-flight-tracker-service/redis"
)

// redisPubSub is an interface that abstracts the redis.PubSub type.
type redisPubSub interface {
	Channel(opts ...redisV9.ChannelOption) <-chan *redisV9.Message
	Close() error
}

// for ease of unit testing.
var (
	jsonUnmarshal  = json.Unmarshal
	redisSubscribe = func(ctx context.Context, redisClient *redis.Client, channel string) redisPubSub {
		return redisClient.Subscribe(ctx, channel)
	}
)

// handlers is a collection of HTTP handlers for the flights service.
type handlers struct {
	redisClient *redis.Client
	redisTopic  string
	log         *slog.Logger
}

// NewHandlers returns a new handlers instance.
func NewHandlers(redisClient *redis.Client, redisTopic string, log *slog.Logger) *handlers {
	return &handlers{
		redisClient: redisClient,
		redisTopic:  redisTopic,
		log:         log,
	}
}

// FlightStatus represents the status of a flight.
type FlightStatus struct {
	Icao24       string  `json:"icao24"`
	Callsign     string  `json:"callsign"`
	TimePosition int     `json:"time_position"`
	Longitude    float64 `json:"longitude"`
	Latitude     float64 `json:"latitude"`
	BaroAltitude float64 `json:"baro_altitude"`
	OnGround     bool    `json:"on_ground"`
	Velocity     float64 `json:"velocity"`
	TrueTrack    float64 `json:"true_track"`
	VerticalRate float64 `json:"vertical_rate"`
}

// HandleStream handles the /v1/flights/stream endpoint.
func (h *handlers) HandleStream(w http.ResponseWriter, r *http.Request) {
	pubsub := redisSubscribe(r.Context(), h.redisClient, h.redisTopic)
	defer pubsub.Close()
	ch := pubsub.Channel()
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Transfer-Encoding", "chunked")
	for msg := range ch {
		var response struct {
			Time   int64           `json:"time"`
			States [][]interface{} `json:"states"`
		}
		if err := jsonUnmarshal([]byte(msg.Payload), &response); err != nil {
			log.Println("Error decoding JSON:", err)
			continue
		}
		for _, state := range response.States {
			if len(state) < 11 {
				continue
			}
			flight := FlightStatus{
				Icao24:       cast.SafeCast(state[0], ""),
				Callsign:     cast.SafeCast(state[1], ""),
				TimePosition: cast.SafeCast(state[3], 0),
				Longitude:    cast.SafeCast(state[5], 0.0),
				Latitude:     cast.SafeCast(state[6], 0.0),
				BaroAltitude: cast.SafeCast(state[7], 0.0),
				OnGround:     cast.SafeCast(state[8], false),
				Velocity:     cast.SafeCast(state[9], 0.0),
				TrueTrack:    cast.SafeCast(state[10], 0.0),
				VerticalRate: cast.SafeCast(state[11], 0.0),
			}
			json.NewEncoder(w).Encode(flight)
			w.(http.Flusher).Flush()
		}
	}
}

```

## Running it

1. Update `.env` with your authentication information

```bash
OPEN_SKY_USERNAME=<username>
OPEN_SKY_PASSWORD=<password>
```

2. Run the server

```bash
make run PORT=4444
```

3. Run the redis-publisher,

```bash
make publisher
```

4. Use **cURL** to test streaming behavior:

```bash
$ curl -v http://localhost:4444/api/v1/flights/stream
```

Expected output:
```json
{"icao24":"aa9300","callsign":"UAL148","time_position":1740963273,"longitude":-46.2588,"latitude":-22.9282,"baro_altitude":6217.92,"on_ground":false,"velocity":203,"true_track":306.55,"vertical_rate":6.83}
{"icao24":"e4943f","callsign":"GLO1630","time_position":1740963273,"longitude":-46.6558,"latitude":-22.7621,"baro_altitude":6720.84,"on_ground":false,"velocity":228.7,"true_track":291.37,"vertical_rate":7.15}
...
```

---

## Final Thoughts

- In my [**previous article**](https://tiagomelo.info/golang/rest/api/streaming/2025/02/26/efficient-json-streaming-rest-api.html), I showed how **clients** can stream JSON to a server.  
- In **this article**, I demonstrated how a **server** can stream JSON **to clients**.  
- With **JSON streaming**, we achieved **efficient real-time updates** with **low latency**.  

---

## References & Further Reading

1. **Previous Article: Efficient JSON Streaming in REST APIs**  
   - [Efficient JSON Streaming in REST APIs](https://tiagomelo.info/golang/rest/api/streaming/2025/02/26/efficient-json-streaming-rest-api.html)  
   - *This article covered how a client can stream a JSON payload to a server efficiently. In contrast, the current article demonstrates the opposite—how a server can stream JSON to a client in real time.*

2. **JSON Streaming Concepts**  
   - [JSON Streaming (Wikipedia)](https://en.wikipedia.org/wiki/JSON_streaming)  
   - *A great overview of JSON streaming, its use cases, and different techniques for handling large data streams efficiently.*

3. **OpenSky Network API**  
   - [OpenSky Network API Documentation](https://openskynetwork.github.io/opensky-api/index.html)  
   - *Learn more about the OpenSky API, the data it provides, and how it can be used for real-time flight tracking.*

4. **Redis Pub/Sub**  
   - [Redis Pub/Sub Documentation](https://redis.io/docs/manual/pubsub/)  
   - *Detailed guide on how Redis Pub/Sub works and why it’s useful for real-time messaging systems.*

5. **Golang net/http Streaming**  
   - [Official Go Documentation - net/http](https://pkg.go.dev/net/http)  
   - *Deep dive into Go’s `http.ResponseWriter` and how to efficiently stream responses with `Flush()`.*

6. **Alternatives to HTTP Streaming**  
   - [Server-Sent Events (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events)  
   - [WebSockets in Go](https://www.gorillatoolkit.org/pkg/websocket)  
   - *For real-time communication beyond HTTP streaming, WebSockets or SSEs (Server-Sent Events) could be alternatives.*

7. **GitHub Repository**
    - https://github.com/tiagomelo/go-flight-tracker-service