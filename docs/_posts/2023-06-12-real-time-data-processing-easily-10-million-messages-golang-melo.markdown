---
layout: post
title:  "Real time data processing: easily processing 10 million messages with Golang, Kafka and MongoDB"
date:   2023-06-12 13:26:01 -0300
categories: go kafka mongodb realtime
---
![Real time data processing: easily processing 10 million messages with Golang, Kafka and MongoDB](/assets/images/2023-06-12-d91183ef-d837-45ca-8696-61d3a7cba8d8/2023-06-12-banner.jpeg)

Having used [Kafka](https://kafka.apache.org/?trk=article-ssr-frontend-pulse_little-text-block) for some years now, I have gained experience with its topics/subscribers model. It's an open-source distributed event streaming platform known for its high-throughput, fault-tolerant, and scalable nature. It is designed to handle large volumes of real-time data efficiently and reliably, making it a popular choice for building robust data pipelines and streaming applications.

[MongoDB](https://www.mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) is an excellent complement to [Kafka](https://kafka.apache.org/?trk=article-ssr-frontend-pulse_little-text-block) for real-time data processing. Its flexible document model easily handles diverse data formats, while its scalability accommodates high data ingestion rates. [MongoDB's](https://www.mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) indexing, querying, and replica set features enable efficient access and fault tolerance. Integrating [MongoDB](https://www.mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) with [Kafka](https://kafka.apache.org/?trk=article-ssr-frontend-pulse_little-text-block) empowers organizations to build scalable, real-time data pipelines for modern applications.

In this article we'll see an example of real time data processing using [Go](http://go.dev?trk=article-ssr-frontend-pulse_little-text-block).

## The proposed application

Suppose that every transaction is published to a [Kafka](https://kafka.apache.org/?trk=article-ssr-frontend-pulse_little-text-block) topic. Every transaction amount greater than 10k is considered as suspicious and we want to save it into [MongoDB](https://www.mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) for further analysis.

The message that is published to the topic looks like this [json](https://en.wikipedia.org/wiki/JSON?trk=article-ssr-frontend-pulse_little-text-block):

```
{
  "transaction_id": 4508561159,
  "account_number": 395402066,
  "transaction_type": "withdrawal",
  "transaction_amount": 2718.79,
  "transaction_time": "2023-06-11T16:34:46.150535-03:00",
  "location": "Jacksonville, FL"
}
```

Here's the general architecture:

![No alt text provided for this image](/assets/images/2023-06-12-d91183ef-d837-45ca-8696-61d3a7cba8d8/1686571867295.png)

### A word on Golang's goroutines

If you know [Go](http://go.dev?trk=article-ssr-frontend-pulse_little-text-block), up to this point you may have thought of using [goroutines](https://go.dev/tour/concurrency/1?trk=article-ssr-frontend-pulse_little-text-block) for consuming messages [concurrently](https://en.wikipedia.org/wiki/Concurrent_computing?trk=article-ssr-frontend-pulse_little-text-block). And you guessed it right: we'll use them.

Here's the worker pool abstraction that we'll use for several different tasks in the system:

task/task.go

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package task

import (
    "context"
    "sync"
)

// Worker must be implemented by types that want to use
// the run pool.
type Worker interface {
    Work(ctx context.Context)
}

// Task provides a pool of goroutines that can execute any Worker
// tasks that are submitted.
type Task struct {
    ctx  context.Context
    work chan Worker
    wg   sync.WaitGroup
}

// New creates a new work pool.
func New(ctx context.Context, maxGoroutines int) *Task {
    t := Task{

        // Using an unbuffered channel because we want the
        // guarantee of knowing the work being submitted is
        // actually being worked on after the call to Run returns.
        work: make(chan Worker),
        ctx:  ctx,
    }

    // The goroutines are the pool. So we could add code
    // to change the size of the pool later on.

    t.wg.Add(maxGoroutines)
    for i := 0; i < maxGoroutines; i++ {
        go func() {
            for w := range t.work {
                w.Work(ctx)
            }
            t.wg.Done()
        }()
    }

    return &t
}

// Shutdown waits for all the goroutines to shutdown.
func (t *Task) Shutdown() {
    close(t.work)
    t.wg.Wait()
}

// Do submits work to the pool.
func (t *Task) Do(w Worker) {
    t.work <- w
}

```

The Task struct represents the pool of goroutines that can execute tasks submitted by implementing the Worker interface. The Worker interface defines a single function, Work(ctx context.Context), which represents the work to be done by each task.

The New function initializes a new worker pool by creating a Task instance. It takes the maximum number of goroutines as a parameter and sets up a channel (work) to receive and distribute the tasks. The channel is unbuffered to ensure that the work is being actively processed after the call to Run returns. The specified maxGoroutines value determines the number of goroutines in the pool. Each goroutine listens to the work channel, executes the received tasks by calling their Work function, and terminates when the channel is closed.

The Shutdown function gracefully shuts down the worker pool by closing the work channel and waiting for all the goroutines to finish their tasks using the sync.WaitGroup.

The Do function is used to submit tasks to the worker pool. It adds the given worker (w) to the work channel, allowing a goroutine from the pool to pick it up and process the task asynchronously.

Overall, this worker pool abstraction provides a way to manage a fixed pool of goroutines that can efficiently execute various tasks concurrently, improving the overall performance and resource utilization.

## The Kafka producer

It accepts a text file containing a financial transaction json in each line. The goal here is to make the producer to read the given file, line by line, and publish each line to the [Kafka](https://kafka.apache.org/?trk=article-ssr-frontend-pulse_little-text-block) topic.

producer/producer.go

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package main

import (
    "bufio"
    "fmt"
    "log"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/confluentinc/confluent-kafka-go/kafka"
    "github.com/jessevdk/go-flags"
    "github.com/pkg/errors"
    "github.com/tiagomelo/realtime-data-kafka/config"
    "github.com/tiagomelo/realtime-data-kafka/screen"
    "github.com/tiagomelo/realtime-data-kafka/stats"
)

const bootstrapServersKey = "bootstrap.servers"

func stringPrt(s string) *string {
    return &s
}

func run(log *log.Logger, cfg *config.Config, transactionsFile string) error {
    log.Println("main: Initializing Kafka producer")
    defer log.Println("main: Completed")
    producer, err := kafka.NewProducer(&kafka.ConfigMap{
        bootstrapServersKey: cfg.KafkaBrokerHost,
    })
    if err != nil {
        return errors.Wrap(err, "creating producer")
    }
    defer producer.Close()
    file, err := os.Open(transactionsFile)
    if err != nil {
        return errors.Wrapf(err, "opening file %s", transactionsFile)
    }
    defer file.Close()

    // Make a channel to listen for an interrupt or terminate signal from the OS.
    // Use a buffered channel because the signal package requires it.
    shutdown := make(chan os.Signal, 1)
    signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

    // Make a channel to listen for errors coming from the listener. Use a
    // buffered channel so the goroutine can exit if we don't collect this error.
    serverErrors := make(chan error, 1)

    stats := &stats.KafkaProducerStats{}
    screen, err := screen.NewKafkaProducerScreen(stats)
    if err != nil {
        return errors.New("starting screen")
    }

    start := time.Now()

    go func() {
        for {
            time.Sleep(time.Second * time.Duration(1))
            stats.UpdateElapsedTime(time.Since(start))
            screen.UpdateContent(false)
        }
    }()

    deliveryChan := make(chan kafka.Event)
    scanner := bufio.NewScanner(file)

    go func() {
        for scanner.Scan() {
            line := scanner.Text()
            if err := producer.Produce(&kafka.Message{
                TopicPartition: kafka.TopicPartition{Topic: stringPrt(cfg.KafkaTopic), Partition: kafka.PartitionAny},
                Value:          []byte(line),
            }, deliveryChan); err != nil {
                log.Printf("%v when publishing to kafka topic %s", err, cfg.KafkaTopic)
            }
            stats.IncrTotalPublishedMessages()
            delivery := <-deliveryChan
            m := delivery.(*kafka.Message)
            if m.TopicPartition.Error != nil {
                stats.IncrTotalFailedMessageDeliveries()
            }
        }
        if err := scanner.Err(); err != nil {
            errors.Wrapf(err, "reading file %s", transactionsFile)
        }
    }()

    // Wait for any error or interrupt signal.
    select {
    case err := <-serverErrors:
        return err
    case sig := <-shutdown:
        screen.UpdateContent(true)
        log.Printf("run: %v: Start shutdown", sig)
        return nil
    }
}

var opts struct {
    File string `short:"f" long:"file" description:"input file" required:"true"`
}

func main() {
    const (
        envFile     = ".env"
        logFileName = "logs/producer.txt"
    )
    flags.ParseArgs(&opts, os.Args)
    logFile, err := os.OpenFile(logFileName, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
    if err != nil {
        fmt.Printf(`opening log file "%s": %v`, logFileName, err)
    }
    log := log.New(logFile, "KAFKA PRODUCER : ", log.LstdFlags|log.Lmicroseconds|log.Lshortfile)
    cfg, err := config.Read(envFile)
    if err != nil {
        log.Println(errors.Wrap(err, "reading config"))
        fmt.Println(errors.Wrap(err, "reading config"))
        os.Exit(1)
    }
    if err := run(log, cfg, opts.File); err != nil {
        log.Println(err)
        fmt.Println(err)
        os.Exit(1)
    }
}

```

Key takeaways:

- I'm using [github.com/confluentinc/confluent-kafka-go](https://github.com/confluentinc/confluent-kafka-go?trk=article-ssr-frontend-pulse_little-text-block) as the [Kafka](https://kafka.apache.org/?trk=article-ssr-frontend-pulse_little-text-block) client
- We have a delivery channel that we can check whether the message was published or not
- [github.com/pterm/pterm](http://github.com/pterm/pterm?trk=article-ssr-frontend-pulse_little-text-block) is being used to beautify the console output. Make sure you check screen/screen.go to learn what it does.

## The Kafka consumer

consumer/consumer.go

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package main

import (
    "context"
    "fmt"
    "log"
    "os"
    "os/signal"
    "runtime"
    "syscall"
    "time"

    "github.com/confluentinc/confluent-kafka-go/kafka"
    "github.com/pkg/errors"
    "github.com/tiagomelo/realtime-data-kafka/config"
    "github.com/tiagomelo/realtime-data-kafka/mongodb"
    "github.com/tiagomelo/realtime-data-kafka/screen"
    "github.com/tiagomelo/realtime-data-kafka/stats"
    "github.com/tiagomelo/realtime-data-kafka/task"
    kafkaWorker "github.com/tiagomelo/realtime-data-kafka/task/worker/kafka"
)

// Useful constants.
const (
    bootstrapServersKey   = "bootstrap.servers"
    groupIdKey            = "group.id"
    autoOffsetResetKey    = "auto.offset.reset"
    autoOffsetReset       = "earliest"
    enablePartitionEofKey = "enable.partition.eof"
)

func run(log *log.Logger) error {
    const envFile = ".env"
    log.Println("main: Initializing Kafka consumer")
    defer log.Println("main: Completed")
    ctx := context.Background()

    cfg, err := config.Read(envFile)
    if err != nil {
        return errors.Wrap(err, "reading config")
    }

    consumer, err := kafka.NewConsumer(&kafka.ConfigMap{
        bootstrapServersKey:   cfg.KafkaBrokerHost,
        groupIdKey:            cfg.KafkaGroupId,
        autoOffsetResetKey:    autoOffsetReset,
        enablePartitionEofKey: false,
    })
    if err != nil {
        return errors.Wrapf(err, "connecting to broker %s", cfg.KafkaBrokerHost)
    }

    if err := consumer.SubscribeTopics([]string{cfg.KafkaTopic}, nil); err != nil {
        return errors.Wrapf(err, "subscribing to topic %s", cfg.KafkaTopic)
    }

    db, err := mongodb.Connect(ctx, cfg.MongodbHostName, cfg.MongodbDatabase, cfg.MongodbPort)
    if err != nil {
        return errors.Wrapf(err, "connecting to mongodb")
    }

    // Make a channel to listen for an interrupt or terminate signal from the OS.
    // Use a buffered channel because the signal package requires it.
    shutdown := make(chan os.Signal, 1)
    signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

    // Make a channel to listen for errors coming from the listener. Use a
    // buffered channel so the goroutine can exit if we don't collect this error.
    serverErrors := make(chan error, 1)

    maxGoRoutines := runtime.GOMAXPROCS(0)
    pool := task.New(ctx, maxGoRoutines)

    stats := &stats.KafkaConsumerStats{}
    screen, err := screen.NewKafkaConsumerScreen(stats)
    if err != nil {
        return errors.New("starting screen")
    }

    start := time.Now()

    go func() {
        defer close(shutdown)
        defer close(serverErrors)
        for {
            select {
            case <-shutdown:
                log.Printf("run: Start shutdown")
                if err := consumer.Close(); err != nil {
                    serverErrors <- errors.Wrap(err, "closing Kafka consumer")
                }
                return
            default:
                msg, err := consumer.ReadMessage(-1)
                if err != nil {
                    serverErrors <- err
                } else {
                    kw := &kafkaWorker.Worker{Msg: msg, Stats: stats, Db: db, Log: log}
                    pool.Do(kw)
                }
            }
        }
    }()

    go func() {
        for {
            time.Sleep(time.Second * time.Duration(1))
            stats.UpdateElapsedTime(time.Since(start))
            screen.UpdateContent(false)
        }
    }()

    // Wait for any error or interrupt signal.
    select {
    case err := <-serverErrors:
        return err
    case sig := <-shutdown:
        screen.UpdateContent(true)
        log.Printf("run: %v: Start shutdown", sig)
        // Asking listener to shutdown and shed load.
        if err := consumer.Close(); err != nil {
            return errors.Wrap(err, "closing Kafka consumer")
        }
        return nil
    }
}

func main() {
    const logFileName = "logs/consumer.txt"
    logFile, err := os.OpenFile(logFileName, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
    if err != nil {
        fmt.Printf(`opening log file "%s": %v`, logFileName, err)
    }
    log := log.New(logFile, "KAFKA CONSUMER : ", log.LstdFlags|log.Lmicroseconds|log.Lshortfile)
    if err := run(log); err != nil {
        fmt.Println(err)
        os.Exit(1)
    }
}

```

Key takeaways:

- We're using a worker pool to process the messages
- [github.com/pterm/pterm](http://github.com/pterm/pterm?trk=article-ssr-frontend-pulse_little-text-block) is being used to beautify the console output as well.

To handle the financial transaction data, we have transaction/transaction.go:

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package transaction

import (
    "encoding/json"
    "time"

    "github.com/pkg/errors"
)

// Transaction represents a transaction message.
type Transaction struct {
    TransactionID     int       `json:"transaction_id"`
    AccountNumber     int       `json:"account_number"`
    TransactionType   string    `json:"transaction_type"`
    TransactionAmount float32   `json:"transaction_amount"`
    TransactionTime   time.Time `json:"transaction_time"`
    Location          string    `json:"location"`
}

// New creates a new Transaction from the raw JSON transaction data.
func New(rawTransaction string) (*Transaction, error) {
    t := new(Transaction)
    if err := json.Unmarshal([]byte(rawTransaction), &t); err != nil {
        return nil, errors.Wrap(err, "unmarshalling transaction")
    }
    return t, nil
}

// IsSuspicious checks if the transaction amount is suspicious.
func (t *Transaction) IsSuspicious() bool {
    const suspiciousAmount = float32(10_000)
    return t.TransactionAmount > suspiciousAmount
}

```

And here's the worker that we're using to handle the received financial transaction data:

task/worker/kafka/kafka.go

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package kafka

import (
    "context"
    "fmt"
    "log"

    "github.com/confluentinc/confluent-kafka-go/kafka"
    "github.com/tiagomelo/realtime-data-kafka/mongodb"
    "github.com/tiagomelo/realtime-data-kafka/mongodb/suspicioustransaction"
    "github.com/tiagomelo/realtime-data-kafka/mongodb/suspicioustransaction/models"
    "github.com/tiagomelo/realtime-data-kafka/stats"
    "github.com/tiagomelo/realtime-data-kafka/transaction"
)

// For ease of unit testing.
var (
    printToLog = func(log *log.Logger, v ...any) {
        log.Println(v...)
    }
    stInsert = func(ctx context.Context, db *mongodb.MongoDb, sp *models.SuspiciousTransaction) error {
        return suspicioustransaction.Insert(ctx, db, sp)
    }
)

// Worker represents a Kafka consumer worker.
type Worker struct {
    Msg   *kafka.Message
    Stats *stats.KafkaConsumerStats
    Db    *mongodb.MongoDb
    Log   *log.Logger
}

// insertSuspiciousTransaction inserts a suspicious transaction into MongoDB.
func (c *Worker) insertSuspiciousTransaction(ctx context.Context, sp *transaction.Transaction) error {
    spDb := &models.SuspiciousTransaction{
        TransactionId:     sp.TransactionID,
        AccountNumber:     sp.AccountNumber,
        TransactionType:   sp.TransactionType,
        TransactionAmount: sp.TransactionAmount,
        TransactionTime:   sp.TransactionTime,
        Location:          sp.Location,
    }
    return stInsert(ctx, c.Db, spDb)
}

// Work processes the Kafka message and performs the necessary operations.
func (c *Worker) Work(ctx context.Context) {
    c.Stats.IncrTotalTransactions()
    transaction, err := transaction.New(string(c.Msg.Value))
    if err != nil {
        c.Stats.IncrTotalUnmarshallingMsgErrors()
        printToLog(c.Log, fmt.Errorf("checking if transaction is suspicious: %v", err))
        return
    }
    if transaction.IsSuspicious() {
        c.Stats.IncrTotalSuspiciousTransactions()
        printToLog(c.Log, "suspicious transaction: %+v\n", transaction)
        if err := c.insertSuspiciousTransaction(ctx, transaction); err != nil {
            c.Stats.IncrTotalInsertSuspiciousTransactionErrors()
            printToLog(c.Log, "error when inserting suspicious transaction in mongodb %+v: %v\n", transaction, err)
        }
    }
}

```

The errors are just logged, as we don't want our worker to stop in that case. Also, the financial transaction data is persisted to [MongoDB](https://www.mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) if it is suspicious. Make sure you check mongodb folder to understand it.

## Generating sample financial transactions

Here's a random data generator:

randomdata/random\_data.go

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package randomdata

import (
    "fmt"
    "math/rand"
    "strconv"
    "time"
)

// locations is a slice of pre-defined locations for generating random transaction locations.
var locations = []string{
    "New York, NY",
    "Los Angeles, CA",
    "Chicago, IL",
    "Houston, TX",
    "Phoenix, AZ",
    "Philadelphia, PA",
    "San Antonio, TX",
    "San Diego, CA",
    "Dallas, TX",
    "San Jose, CA",
    "Austin, TX",
    "Jacksonville, FL",
    "Fort Worth, TX",
    "Columbus, OH",
    "Charlotte, NC",
    "San Francisco, CA",
    "Indianapolis, IN",
    "Seattle, WA",
    "Denver, CO",
    "Washington, DC",
}

// TransactionID generates a random transaction ID.
func TransactionID() int {
    seed := time.Now().UnixNano()
    r := rand.New(rand.NewSource(seed))
    r.Seed(time.Now().UnixNano())
    return r.Intn(9999999999-1111111111+1) + 1111111111
}

// AccountNumber generates a random account number.
func AccountNumber() int {
    seed := time.Now().UnixNano()
    r := rand.New(rand.NewSource(seed))
    r.Seed(time.Now().UnixNano())
    return r.Intn(999999999-111111111+1) + 111111111
}

// TransactionAmount generates a random transaction amount between the specified minimum and maximum amounts.
func TransactionAmount(minAmount, maxAmount float32) float32 {
    seed := time.Now().UnixNano()
    r := rand.New(rand.NewSource(seed))
    randomAmount := r.Float32()*(maxAmount-minAmount) + minAmount
    formattedAmount, _ := strconv.ParseFloat(fmt.Sprintf("%.2f", randomAmount), 32)
    return float32(formattedAmount)
}

// TransactionTime generates a random transaction time within the last 24 hours.
func TransactionTime() time.Time {
    seed := time.Now().UnixNano()
    r := rand.New(rand.NewSource(seed))
    randomDuration := time.Duration(r.Intn(86400)) * time.Second
    randomTime := time.Now().Add(-randomDuration)
    return randomTime
}

// Location generates a random transaction location from the pre-defined locations.
func Location() string {
    seed := time.Now().UnixNano()
    r := rand.New(rand.NewSource(seed))
    return locations[r.Intn(len(locations))]
}

```

Now suppose we want to generate a file with 1000 lines. We have a worker for that, to speed it up:

task/worker/randomtransaction/randomtransaction.go

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package randomtransaction

import (
    "context"
    "encoding/json"
    "log"
    "os"

    "github.com/tiagomelo/realtime-data-kafka/randomdata"
    "github.com/tiagomelo/realtime-data-kafka/transaction"
)

// For ease of unit testing.
var (
    openFile        = os.OpenFile
    jsonMarshal     = json.Marshal
    fileWriteString = func(file *os.File, s string) (n int, err error) {
        return file.WriteString(s)
    }
    printToLog = func(log *log.Logger, v ...any) {
        log.Println(v...)
    }
)

// Worker generates random transaction data.
type Worker struct {
    FilePath  string
    MinAmount float32
    MaxAmount float32
    Log       *log.Logger
}

// Work generates a random transaction and writes it to a file.
func (w *Worker) Work(ctx context.Context) {
    t := generateRandomTransaction(w.MinAmount, w.MaxAmount)
    file, err := openFile(w.FilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
    if err != nil {
        printToLog(w.Log, "error opening file:", err)
        return
    }
    defer file.Close()
    jsonData, err := jsonMarshal(t)
    if err != nil {
        printToLog(w.Log, "error marshalling json:", err)
        return
    }
    _, err = fileWriteString(file, string(jsonData)+"\n")
    if err != nil {
        printToLog(w.Log, "error writing to file:", err)
    }
}

// generateRandomTransaction generates a random transaction with the given minimum and maximum amounts.
func generateRandomTransaction(minAmount, maxAmount float32) *transaction.Transaction {
    const withdrawal = "withdrawal"
    t := &transaction.Transaction{
        TransactionID:     randomdata.TransactionID(),
        AccountNumber:     randomdata.AccountNumber(),
        TransactionType:   withdrawal,
        TransactionAmount: randomdata.TransactionAmount(minAmount, maxAmount),
        TransactionTime:   randomdata.TransactionTime(),
        Location:          randomdata.Location(),
    }
    return t
}

```

And here's a CLI that we have to be able to generate the file:

jsongenerator/jsongenerator.go

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package main

import (
    "context"
    "math/rand"
    "os"
    "runtime"

    "github.com/jessevdk/go-flags"
    "github.com/tiagomelo/realtime-data-kafka/task"
    "github.com/tiagomelo/realtime-data-kafka/task/worker/randomtransaction"
)

// opts holds the command-line options.
var opts struct {
    LowerLimitMinValue float32 `long:"llmin" description:"Lower limit min value" required:"true"`
    LowerLimitMaxValue float32 `long:"llmax" description:"Lower limit max value" required:"true"`
    UpperLimitMinValue float32 `long:"ulmin" description:"Upper limit min value" required:"true"`
    UpperLimitMaxValue float32 `long:"ulmax" description:"Upper limit max value" required:"true"`
    Percentage         float32 `short:"p" long:"percentage" description:"Percentage for lower limit" required:"true"`
    TotalLines         int     `short:"t" long:"totallines" description:"Total lines" required:"true"`
    File               string  `short:"f" long:"file" description:"Output file" required:"true"`
}

func run(args []string) error {
    flags.ParseArgs(&opts, args)
    ctx := context.Background()
    maxGoRoutines := runtime.GOMAXPROCS(0)
    pool := task.New(ctx, maxGoRoutines)
    lowerLimit := float32(opts.TotalLines) * opts.Percentage
    remaining := float32(opts.TotalLines) - lowerLimit
    workers := make([]task.Worker, opts.TotalLines)
    for i := 0; i < int(lowerLimit); i++ {
        workers[i] = &randomtransaction.Worker{FilePath: opts.File, MinAmount: opts.LowerLimitMinValue, MaxAmount: opts.LowerLimitMaxValue}
    }
    for i := int(remaining); i < opts.TotalLines; i++ {
        workers[i] = &randomtransaction.Worker{FilePath: opts.File, MinAmount: opts.UpperLimitMinValue, MaxAmount: opts.UpperLimitMaxValue}
    }
    rand.Shuffle(len(workers), func(i, j int) { workers[i], workers[j] = workers[j], workers[i] })
    for _, w := range workers {
        pool.Do(w)
    }
    pool.Shutdown()
    return nil
}

func main() {
    run(os.Args)
}

```

One thing that is worth to mention is that I'm using [github.com/jessevdk/go-flags](https://github.com/jessevdk/go-flags?trk=article-ssr-frontend-pulse_little-text-block) instead of the core [flag](https://pkg.go.dev/flag?trk=article-ssr-frontend-pulse_little-text-block) package. It makes it easy to parse all provided flags into a struct, offering a lot more of extra functionalities as well.

Also, as you may have noticed, the logic here is to be able to determine a given percentage of the total lines to have a certain transaction amount.

Here's the target in our [Makefile](https://en.wikipedia.org/wiki/Make_(software)?trk=article-ssr-frontend-pulse_little-text-block) to generate the file:

```
# ==============================================================================
# Sample data generation

.PHONY: sample-data
## sample-data: generates sample data
sample-data:
    @ if [ -z "$(TOTAL)" ]; then echo >&2 please set total via the variable TOTAL; exit 2; fi
    @ if [ -z "$(FILE_NAME)" ]; then echo >&2 please set file name via the variable FILE_NAME; exit 2; fi
    @ rm -f "${SAMPLE_DATA_FOLDER}/${FILE_NAME}"
    @ echo "generating file ${SAMPLE_DATA_FOLDER}/${FILE_NAME}..."
    @ go run jsongenerator/jsongenerator.go --llmin 10000 --llmax 30000 --ulmin 100 --ulmax 3000 -t=$(TOTAL) -p=0.7 -f="${SAMPLE_DATA_FOLDER}/${FILE_NAME}"
    @ echo "file ${SAMPLE_DATA_FOLDER}/${FILE_NAME} was generated."

```

The flags are:

- llmin: the lower limit minimum value
- llmax: the lower limit maximum value
- ulmin: the upper limit minimum value
- ulmax: the upper limit maximum value
- t: total number of lines
- p: the desired percentage
- f: the output file

Let's invoke it:

```
$ make sample-data TOTAL=1000 FILE_NAME=onethousand.txt
generating file sampledata/onethousand.txt..file
sampledata/onethousand.txt was generated..
```

File is then saved to \`sampledata\` folder.

## Running it all

To run the [Kafka](https://kafka.apache.org/?trk=article-ssr-frontend-pulse_little-text-block) server, we need to start [ZooKeeper](https://zookeeper.apache.org/?trk=article-ssr-frontend-pulse_little-text-block) first as [Kafka](https://kafka.apache.org/?trk=article-ssr-frontend-pulse_little-text-block) depends on it for distributed coordination and configuration management.

Open up a terminal tab and start [ZooKeeper](https://zookeeper.apache.org/?trk=article-ssr-frontend-pulse_little-text-block):

```
$ make zookeeper
```

Next, in another tab, start [Kafka](https://kafka.apache.org/?trk=article-ssr-frontend-pulse_little-text-block) server:

```
$ make kafka
```

In another tab, run the [Kafka](https://kafka.apache.org/?trk=article-ssr-frontend-pulse_little-text-block) producer:

```
$ make producer FILE_NAME=sampledata/onethousand.txt
```

Here's the output:

![No alt text provided for this image](/assets/images/2023-06-12-d91183ef-d837-45ca-8696-61d3a7cba8d8/1686575535925.png)

Now let's run the consumer in another tab:

```
$ make consumer
```

The output:

![No alt text provided for this image](/assets/images/2023-06-12-d91183ef-d837-45ca-8696-61d3a7cba8d8/1686575601800.png)

As we can see, we generated a file with 1000 random financial transactions, 30% of which with amounts greater than 10K (1000 \* 0.3 = 300), and those 300 suspicious transactions were inserted into [MongoDB](https://www.mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block). Let's check it:

```
$ mongosh
Current Mongosh Log ID:	64871a56356a0638d1869007
Connecting to:		mongodb://127.0.0.1:27017/?directConnection=true&serverSelectionTimeoutMS=2000&appName=mongosh+1.9.0
Using MongoDB:		6.0.6
Using Mongosh:		1.9.0

For mongosh info see: https://docs.mongodb.com/mongodb-shell/

------
   The server generated these startup warnings when booting
   2023-06-07T08:45:03.255-03:00: Access control is not enabled for the database. Read and write access to data and configuration is unrestricted
------

test> use fraud;
switched to db fraud
fraud> db.suspicious_transactions.countDocuments();
300
```

Excellent. Now how about pushing 10 million messages to that topic? How well does the consumer perform?

## It's time to rock: testing it with 10M messages

This test was performed in a Macbook Pro 16' with M1 chip and 16GB of ram.

The fastest way we can publish 10M messages to a [Kafka](https://kafka.apache.org/?trk=article-ssr-frontend-pulse_little-text-block) topic is by using the [console producer (kafka-console-producer)](https://kafka.apache.org/quickstart?trk=article-ssr-frontend-pulse_little-text-block) that comes with Kafka's installation. It is incredibly fast!

The target in our Makefile for invoking it:

```
.PHONY: kafka-consumer-publish
## kafka-consumer-publish: Kafka's tool to read data from standard input and publish it to Kafka
kafka-consumer-publish:
    @ if [ -z "$(FILE_NAME)" ]; then echo >&2 please set file name via the variable FILE_NAME; exit 2; fi
    @ cat $(FILE_NAME) | kafka-console-producer --topic $(KAFKA_TOPIC) --bootstrap-server $(KAFKA_BROKER_HOST)

```

Now, supposing we already generated the file with 10M lines, with 30% of them as suspicious, let's invoke it:

```
$ time make kafka-consumer-publish FILE_NAME=sampledata/tenmillion.txt

real	0m12.833s
user	0m14.339s
sys	0m4.473s

```

Wow. 13 seconds to publish 10 million messages.

Now let's run the consumer... will it be fast enough to process all this data?

```
$ make consumer
```

The output:

![No alt text provided for this image](/assets/images/2023-06-12-d91183ef-d837-45ca-8696-61d3a7cba8d8/1686576574029.png)

That was fast. 1m38s to:

- analyse the message
- marshal it into a transaction struct
- check if it is suspicious, which is, check if the amount is greater than 10K
- persist it to the database if it is suspicious

Now let's check [MongoDB](https://www.mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block):

```
$ mongosh
Current Mongosh Log ID:	64871e25658763d4f7c01349
Connecting to:		mongodb://127.0.0.1:27017/?directConnection=true&serverSelectionTimeoutMS=2000&appName=mongosh+1.9.0
Using MongoDB:		6.0.6
Using Mongosh:		1.9.0

For mongosh info see: https://docs.mongodb.com/mongodb-shell/

------
   The server generated these startup warnings when booting
   2023-06-07T08:45:03.255-03:00: Access control is not enabled for the database. Read and write access to data and configuration is unrestricted
------

test> use fraud;
switched to db fraud
fraud> db.suspicious_transactions.countDocuments();
3000000

```

That's perfect. 30% of 10 million is 3 million, so we have 3 million suspicious transactions saved to the database.

## Additional available Makefile targets

```
$ make help
Usage: make [target]
  help                     shows this help message
  zookeeper                starts zookeeper
  kafka                    starts kafka
  kafka-consumer-publish   Kafka's tool to read data from standard input and publish it to Kafka
  clear-kafka-messages     cleans all pending messages from Kafka
  producer                 starts producer
  consumer                 starts consumer
  test                     runs tests
  coverage                 run unit tests and generate coverage report in html format
  sample-data              generates sample data

```

## Conclusion

Real time data analysis plays a key role in some domains, like the financial one. In this scenario we explored a naive approach for considering a transaction as suspicious by simply check the amount value. In a real scenario probably you'd want to add additional checks and even use some Artificial Inteligence solution.

We saw how we can use goroutines for concurrent processing and how MongoDB is faster than a transactional DB in this scenario, where we have a high ingestion rate.

As bonuses, we've covered:

- Goroutine worker pool abstraction
- How to beautify CLI console output
- How to read CLI command flags in a more flexible way

## Download the source

Here: [https://github.com/tiagomelo/realtime-data-kafka](https://github.com/tiagomelo/realtime-data-kafka?trk=article-ssr-frontend-pulse_little-text-block)
