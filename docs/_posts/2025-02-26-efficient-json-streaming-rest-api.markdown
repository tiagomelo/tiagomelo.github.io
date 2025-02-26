---
layout: post
title:  "Efficient JSON Processing: Streaming vs. Full Loading in Go"
date:   2025-02-26 14:30:09 -0000
categories: golang rest api streaming
image: "/assets/images/2025-02-26-efficient-json-streaming-rest-api/banner.png"
---

![banner](/assets/images/2025-02-26-efficient-json-streaming-rest-api/banner.png)

Handling **large JSON payloads** efficiently is crucial in API development. In this article, I compare two approaches for upserting **airports data** into a [SQLite](https://www.sqlite.org/) database:

1. **Full JSON Loading** – Reads the entire JSON array into memory before processing.
2. **Optimized JSON Streaming** – Processes JSON **incrementally**, reducing memory usage.

Using **1 million airport records**, I benchmark both approaches and demonstrate why **JSON streaming is the better choice** for large payloads.

---

## Why JSON Streaming?

Streaming JSON means **reading and processing data piece by piece**, instead of loading everything into memory at once. This is **critical for large datasets** to avoid excessive memory consumption or out-of-memory (OOM) crashes.

### 🔍 How Streaming Works

1. **Read the JSON start token (`[` for an array)**.
2. **Iterate through each airport entry**, processing one at a time.
3. **Insert each entry into the database immediately**.
4. **Read the closing token (`]`)** and finalize the operation.

This **incremental parsing** avoids storing the entire JSON object in memory.

---

## The Two Approaches Compared

### Full JSON Loading – The Naive Approach

`handlers/v1/airports/nonstreaming.go`:

```go
// HandleNonStreamingUpsert handles the upsert of airports by reading the entire JSON array into memory.
func (h *handlers) HandleNonStreamingUpsert(w http.ResponseWriter, r *http.Request) {
	// read full request body into memory.
	body, err := ioReadAll(r.Body)
	if err != nil {
		web.RespondWithError(w, http.StatusBadRequest, "failed to read request body")
		return
	}
	var airportsToBeUpserted []UpsertAirportRequest
	if err := jsonUnmarshal(body, &airportsToBeUpserted); err != nil {
		web.RespondWithError(w, http.StatusBadRequest, "invalid JSON format")
		return
	}
	for _, request := range airportsToBeUpserted {
		if err := validate.Check(request); err != nil {
			web.RespondWithError(w, http.StatusBadRequest, err.Error())
			return
		}
		if err := upsertAirport(r.Context(), h.db, request.ToAirport()); err != nil {
			web.RespondWithError(w, http.StatusInternalServerError, errors.Wrap(err, "error upserting airport").Error())
			return
		}
	}
	web.Respond(w, http.StatusOK, UpsertAirportResponse{Message: "airports upserted"})

	// manually trigger garbage collection to free up memory.
	runtime.GC()
	debug.FreeOSMemory()
}
```

#### Problems with Full JSON Loading:
- **High memory consumption**: Loads all records into RAM at once.
- **Slow processing**: No database insertion until the entire file is read.
- **Risk of OOM crashes**: Large datasets can **exceed available memory**.

---

### Optimized JSON Streaming – The Efficient Approach

`handlers/v1/airports/airports.go`:

```go
// HandleUpsert handles the upsert of airports in a streaming fashion.
func (h *handlers) HandleUpsert(w http.ResponseWriter, r *http.Request) {
	ctr := newHttpResponseController(w)
	bufReader := bufio.NewReaderSize(r.Body, maxBufferedReaderSize)
	dec := json.NewDecoder(bufReader)
	// check for opening '['.
	if err := h.readExpectedToken(dec, json.Delim('[')); err != nil {
		web.RespondWithError(w, http.StatusBadRequest, "invalid JSON: expected '[' at start")
		return
	}
	// process each airport in the JSON object.
	if herr := h.processAirports(r.Context(), dec); herr != nil {
		web.RespondWithError(w, herr.code, herr.Error())
		return
	}
	// check for closing ']'.
	if err := h.readExpectedToken(dec, json.Delim(']')); err != nil {
		web.RespondWithError(w, http.StatusBadRequest, "invalid JSON: expected ']' at end")
		return
	}
	// flush response and finalize.
	if err := ctr.Flush(); err != nil {
		web.RespondWithError(w, http.StatusInternalServerError, err.Error())
		return
	}
	web.RespondAfterFlush(w, UpsertAirportResponse{Message: "airports upserted"})
}
```

- `newHttpResponseController(w)` creates a response controller that provides additional control over how the response is sent to the client.
- This can be useful when working with **streaming responses**, as it allows explicit **flushing** of data to the client without waiting for the request to complete.
- In this specific case, it ensures that partial responses (if needed) can be flushed early, improving responsiveness when processing large payloads.

#### Benefits of JSON Streaming:
- **Low memory usage**: Only keeps **one record at a time** in memory.
- **Faster execution**: Database insertion starts **immediately**.
- **Scalable**: Handles **millions of records without OOM crashes**.

---

## Benchmarking: Memory Usage & Performance

Benchmark utilities are under `benchmark` folder.

To compare these approaches, I:
1. **Generated a large JSON file** with **1 million airport records**.
2. **Ran the API for both methods**.
3. **Measured memory consumption** over time.

### Generating 1M Airport Records
```sh
$ ./json_gen.sh 1000000 big_airports.json
Generating 1000000 airports in big_airports.json...
Generation completed. File saved as big_airports.json
```

### Running the API Server
```sh
$ make run PORT=4444
{"time":"2025-02-23T15:22:37.01061-03:00","level":"INFO","msg":"API listening on :4444"}
```

### 📡 Sending the API Request
```sh
$ curl -v "http://localhost:4444/api/v1/airports" -H "Content-Type: application/json" --data-binary @big_airports.json
```

---

### **Full JSON Loading (High Memory Usage)**

![whole-json](/assets/images/2025-02-26-efficient-json-streaming-rest-api/mem_whole_json.png)

- **Memory spikes above 500MB**.
- **High risk of OOM crashes**.

### **Optimized Streaming (Low Memory Usage)**

![json-streaming](/assets/images/2025-02-26-efficient-json-streaming-rest-api/mem_json_streaming.png)

- **Memory stays under 18MB**.
- **Scales efficiently with large JSON payloads**.

---

## Final Thoughts: JSON Streaming Wins!

1. **Avoid Full JSON Loading** – It **consumes too much memory** and **delays processing**.
2. **Use JSON Streaming** – **Minimizes memory usage**, speeds up processing, and scales **to millions of records**.

For large-scale applications, **JSON streaming should be your default approach** to handling massive payloads efficiently.

---

## References & Further Reading

- [Go `encoding/json` Package](https://pkg.go.dev/encoding/json)
- [GitHub Repository](https://github.com/tiagomelo/go-airports-service)
