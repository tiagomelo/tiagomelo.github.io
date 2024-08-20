---
layout: post
title:  "MongoDB and docker-compose: how to setup custom user and password automatically"
date:   2023-05-03 13:26:01 -0300
categories: go mysql
---
![MongoDB and docker-compose: how to setup custom user and password automatically](/assets/images/2023-05-08-3deeb1a8-e116-46bc-8dfa-921936f63284/2023-05-08-banner.jpeg)

[MongoDB](http://mongodb.com?trk=article-ssr-frontend-pulse_little-text-block) is a widely used [NoSQL](https://en.wikipedia.org/wiki/NoSQL?trk=article-ssr-frontend-pulse_little-text-block) database management system that offers several features such as scalability, high performance, and flexibility. However, one important aspect that users need to keep in mind when setting up [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) is that the authentication feature is not enabled by default. This means that when you create a new container for [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) using [docker-compose](https://docs.docker.com/compose/?trk=article-ssr-frontend-pulse_little-text-block), you will need to enable authentication manually to ensure that only authorized users have access to the database.

But the whole point of setting up external dependencies using tools like [docker-compose](https://docs.docker.com/compose/?trk=article-ssr-frontend-pulse_little-text-block) is to automate everything as much as possible to save precious time.

In this quick article we'll see how to enable authentication and create custom user/pass automatically via [docker-compose](https://docs.docker.com/compose/?trk=article-ssr-frontend-pulse_little-text-block).

## Sample project

I'll show a sample project written in [Go](http://go.dev?trk=article-ssr-frontend-pulse_little-text-block) that

- use [docker-compose](https://docs.docker.com/compose/?trk=article-ssr-frontend-pulse_little-text-block) to provision a [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) instance;
- use a [Javascript](https://en.wikipedia.org/wiki/JavaScript?trk=article-ssr-frontend-pulse_little-text-block) to create the custom user and password for a given database;
- connect to [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) instance using the above credentials.

### docker-compose.yaml

```
version: "3.9"
services:
  mongodb:
    container_name: mongodb-sample
    image: mongo:latest
    restart: always
    ports:
      - "27017:27017"
    volumes:
      - mongodb-data:/data/db
      - ./db/mongo-init.js:/docker-entrypoint-initdb.d/mongo-init.js
    env_file:
      - .env
    command: [--auth]
volumes:
  mongodb-data:

```

In a [Docker Compose](https://docs.docker.com/compose/?trk=article-ssr-frontend-pulse_little-text-block) file, the command key is used to specify the command that should be run inside the container when it starts up. For a [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) container, one common use of the command key is to enable authentication by passing the --auth option to the mongod process.

When the --auth option is passed to the mongod process, it enables authentication for the [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) instance. This means that users will need to provide valid credentials (username and password) to access the database. Without authentication, anyone with access to the [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) instance could potentially access, modify, or delete sensitive data, which could lead to serious security breaches.

We're copying db/mongo-init.js file to the container by running \- ./db/mongo-init.js:/docker-entrypoint-initdb.d/mongo-init.js.

### MongoDB javascript user/pass creation file

db/mongo-init.js

```
db = db.getSiblingDB('sample_db')

db.createUser({
    user: 'some_user',
    pwd: 'random_pass',
    roles: [
      {
        role: 'dbOwner',
      db: 'sample_db',
    },
  ],
});

```

### Makefile

```
SHELL = /bin/bash

DOCKER_MONGODB=docker exec -it mongodb-sample mongosh -u $(ADMIN_USER) -p $(ADMIN_PASSWORD) --authenticationDatabase admin
DOCKER_MONGODB_WITH_CUSTOM_CREDS=docker exec -it mongodb-sample mongosh -u $(DB_USER) -p $(DB_PASS) --authenticationDatabase $(DB_NAME)

.PHONY: help
## help: shows this help message
help:
    @ echo "Usage: make [target]"
    @ sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

.PHONY: setup-db
## setup-db: sets up MongoDB
setup-db: export ADMIN_USER=admin
setup-db: export ADMIN_PASSWORD=f3MdBEcz
setup-db:
    @ echo "Setting up MongoDB..."
    @ docker-compose up -d mongodb
    @ until $(DOCKER_MONGODB) --eval 'db.getUsers()' >/dev/null 2>&1 && exit 0; do \
      >&2 echo "MongoDB not ready, sleeping for 5 secs..."; \
      sleep 5 ; \
    done
    @ echo "... MongoDB is up and running!"

.PHONY: mongodb-console
## mongodb-console: opens MongoDB console
mongodb-console: export DB_USER=some_user
mongodb-console: export DB_PASS=random_pass
mongodb-console: export DB_NAME=sample_db
mongodb-console:
    @ ${DOCKER_MONGODB_WITH_CUSTOM_CREDS}

.PHONY: run
## run: runs the application
run: setup-db
    @ go run cmd/main.go

.PHONY: cleanup
## cleanup: removes MongoDB and associated volumes
cleanup:
    @ docker-compose down
    @ docker volume rm $$(docker volume ls -q)

.PHONY: test
## test: runs unit tests
test:
    @ go test -v ./...

```

The setup-db targetwhich is invoked by run target keeps trying to connect to [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) so the main [Go](http://go.dev?trk=article-ssr-frontend-pulse_little-text-block) program can safely try to connect to it.

### Connecting to MongoDB

.env

```
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=f3MdBEcz
MONGODB_DATABASE=sample_db
MONGODB_USER=some_user
MONGODB_PASSWORD=random_pass
MONGODB_HOST_NAME=localhost
MONGODB_PORT=27017
```

config/config.go

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package config

import (
    "github.com/joho/godotenv"
    "github.com/kelseyhightower/envconfig"
    "github.com/pkg/errors"
)

// Config holds all configuration needed by this app.
type Config struct {
    MongoDbUser     string `envconfig:"MONGODB_USER"`
    MongoDbPassword string `envconfig:"MONGODB_PASSWORD"`
    MongoDbDatabase string `envconfig:"MONGODB_DATABASE"`
    MongoDbHostName string `envconfig:"MONGODB_HOST_NAME"`
    MongoDbPort     int    `envconfig:"MONGODB_PORT"`
}

var (
    godotenvLoad     = godotenv.Load
    envconfigProcess = envconfig.Process
)

func ReadConfig() (*Config, error) {
    if err := godotenvLoad(); err != nil {
        return nil, errors.Wrap(err, "loading env vars")
    }
    config := new(Config)
    if err := envconfigProcess("", config); err != nil {
        return nil, errors.Wrap(err, "processing env vars")
    }
    return config, nil
}

```

db/mongodb.go

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package db

import (
    "context"
    "fmt"

    "github.com/pkg/errors"
    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

type MongoDb struct {
    database string
    client   *mongo.Client
}

// For ease of unit testing.
var (
    connect = func(ctx context.Context, client *mongo.Client) error {
        return client.Connect(ctx)
    }
    ping = func(ctx context.Context, client *mongo.Client) error {
        return client.Ping(ctx, nil)
    }
)

// ConnectToMongoDb connects to a running MongoDB instance.
func ConnectToMongoDb(ctx context.Context, user, pass, host, database string, port int) (*MongoDb, error) {
    client, err := mongo.NewClient(options.Client().ApplyURI(
        uri(user, pass, host, database, port),
    ))
    if err != nil {
        return nil, errors.Wrap(err, "failed to create MongoDB client")
    }
    err = connect(ctx, client)
    if err != nil {
        return nil, errors.Wrap(err, "failed to connect to MongoDB server")
    }
    err = ping(ctx, client)
    if err != nil {
        return nil, errors.Wrap(err, "failed to ping MongoDB server")
    }
    return &MongoDb{
        database: database,
        client:   client,
    }, nil
}

// uri generates uri string for connecting to MongoDB.
func uri(user, pass, host, database string, port int) string {
    const format = "mongodb://%s:%s@%s:%d/%s"
    return fmt.Sprintf(format, user, pass, host, port, database)
}

```

cmd/main.go

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package main

import (
    "context"
    "fmt"
    "os"

    "github.com/pkg/errors"
    "github.com/tiagomelo/docker-mongodb-custom-user-pass/config"
    "github.com/tiagomelo/docker-mongodb-custom-user-pass/db"
)

func run() error {
    ctx := context.Background()
    config, err := config.ReadConfig()
    if err != nil {
        return errors.Wrap(err, "reading config")
    }
    _, err = db.ConnectToMongoDb(ctx,
        config.MongoDbUser,
        config.MongoDbPassword,
        config.MongoDbHostName,
        config.MongoDbDatabase,
        config.MongoDbPort,
    )
    if err != nil {
        return errors.Wrap(err, "connecting to MongoDB")
    }
    fmt.Println("successfully connected to MongoDB.")
    return nil
}

func main() {
    if err := run(); err != nil {
        fmt.Println(err)
        os.Exit(1)
    }
}

```

### Running it

```
$ make run

Setting up MongoDB..

[+] Running 3/3

 ⠿ Network docker-mongodb-custom-user-pass_default        Created                                                                                      0.0s

 ⠿ Volume "docker-mongodb-custom-user-pass_mongodb-data"  Created                                                                                      0.0s

 ⠿ Container mongodb-sample                               Started                                                                                      0.3s

MongoDB not ready, sleeping for 5 secs...

... MongoDB is up and running!

successfully connected to MongoDB..
```

The "successfully connected to MongoDB." message states that we were able to connect to it.

### MongoDB shell access

```
$ make mongodb-console

Current Mongosh Log ID:	645955b82bcce4a09d59bda3
Connecting to:		mongodb://<credentials>@127.0.0.1:27017/?directConnection=true&serverSelectionTimeoutMS=2000&authSource=sample_db&appName=mongosh+1.8.2
Using MongoDB:		6.0.5
Using Mongosh:		1.8.2

For mongosh info see: https://docs.mongodb.com/mongodb-shell/

test> use sample_db
switched to db sample_db
sample_db>
```

## Download the source

Here: [https://github.com/tiagomelo/docker-mongodb-custom-user-pass](https://github.com/tiagomelo/docker-mongodb-custom-user-pass?trk=article-ssr-frontend-pulse_little-text-block)