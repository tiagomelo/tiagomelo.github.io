---
layout: post
title:  "Go: managing database migrations in Postgres with Docker"
date:   2024-08-22 18:40:13 -0000
categories: go golang migrations psql
image: "/assets/images/2024-08-22-go-docker-psql-migrations/banner.png"
---

![banner](/assets/images/2024-08-22-go-docker-psql-migrations/banner.png)

## introduction

It is no secret that I always use [golang-migrate](https://github.com/golang-migrate/migrate) for managing database migrations in my [Go](https://go.dev) projects:

- [Golang: A RESTful api running in Kubernetes + MariaDB + database migrations](https://www.linkedin.com/pulse/golang-restful-api-running-kubernetes-mariadb-database-tiago-melo/)
- [Golang: a RESTful API using temporal table with MariaDB](https://tiagomelo.info/go/mariadb/temporaltables/2023/04/06/golang-restful-api-using-temporal-table-mariadb-tiago-melo.html)

Now it is time to dedicate a post covering how to manage database migrations using [Docker](https://docker.com).

In this example, we'll use [PostgreSQL](https://www.postgresql.org/) dockerized instance via - [docker-compose](https://docs.docker.com/compose/).

## motivation

[golang-migrate](https://github.com/golang-migrate/migrate) is an excellent tool. You can install it at the OS level, but I prefer to [dockerize it](https://github.com/golang-migrate/migrate?tab=readme-ov-file#docker-usage). This can ease the life among developers of a given project.

## sample domain

![erd](/assets/images/2024-08-22-go-docker-psql-migrations/erd.png)

## the project

**.env**:

```
POSTGRES_USER=postgres
POSTGRES_PASSWORD=x63Qd7qb
POSTGRES_DB=migrations_tutorial
POSTGRES_HOST=localhost:5432
POSTGRES_DATABASE_CONTAINER_NAME=psql_migrations_db
POSTGRES_DATABASE_CONTAINER_NETWORK_NAME=go-docker-psql-migrations_psqldb-network
```

by using [go-project-config](https://tiagomelo.info/opensource/golang/2024/05/02/goprojconfig-opensource.html), an open source tool of mine, we'll generate the config files to use it in our application:

```
$ goprojconfig -p config -e .env
created: config/config.go
created: config/config_test.go
```

`go-docker-psql-migrations_psqldb-network` is the generated network name by Docker. We'll use it when invoking `migrate` via Docker.

**docker-compose.yaml**:

```
services:
  psql_migrations_db:
    image: postgres
    container_name: ${POSTGRES_DATABASE_CONTAINER_NAME}
    restart: always
    env_file:
      - .env
    ports:
      - "5432:5432"
    volumes:
      - psql_migrations_db_data:/var/lib/postgresql/data
    networks:
      - psqldb-network

networks:
  psqldb-network:
    driver: bridge

volumes:
  psql_migrations_db_data:
```

`psqldb-network` is the network name that will be created when invoking `docker-compose`, and it can be access via the name `go-docker-psql-migrations_psqldb-network`.

**main.go**:

we have a simple app that displays all existing tables along with their column names:

```
// Copyright (c) 2024 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.

package main

import (
	"fmt"
	"os"

	"github.com/pkg/errors"
	"github.com/tiagomelo/go-docker-psql-migrations/config"
	"github.com/tiagomelo/go-docker-psql-migrations/db"
)

func main() {
	cfg, err := config.Read()
	if err != nil {
		fmt.Println(errors.Wrap(err, "reading config"))
		os.Exit(1)
	}
	db, err := db.Connect(cfg.PostgresUser, cfg.PostgresPassword, cfg.PostgresHost, cfg.PostgresDb)
	if err != nil {
		fmt.Println(errors.Wrap(err, "connecting to db"))
		os.Exit(1)
	}
	query := `
        SELECT
            table_name,
            column_name
        FROM
            information_schema.columns
        WHERE
            table_schema = 'public'
        ORDER BY
            table_name,
            ordinal_position;
    `
	rows, err := db.Query(query)
	if err != nil {
		fmt.Println(errors.Wrap(err, "executing query"))
		os.Exit(1)
	}
	defer rows.Close()
	fmt.Println("+----------------------+--------------------+")
	fmt.Println("| Table Name           | Column Name        |")
	fmt.Println("+----------------------+--------------------+")
	var tableName, columnName string
	for rows.Next() {
		err := rows.Scan(&tableName, &columnName)
		if err != nil {
			fmt.Println(errors.Wrap(err, "scanning query results"))
			os.Exit(1)
		}
		fmt.Printf("| %-20s | %-18s |\n", tableName, columnName)
	}
	fmt.Println("+----------------+--------------------------+")
	if err = rows.Err(); err != nil {
		fmt.Println(errors.Wrap(err, "looping through returned rows"))
		os.Exit(1)
	}
}

```

**Makefile**

```
include .env
export

# ==============================================================================
# Useful variables

# Version - this is optionally used on goto command
V?=

# Number of migrations - this is optionally used on up and down commands
N?=

# PSQL domain source name string
PSQL_DSN ?= $(POSTGRES_USER):$(POSTGRES_PASSWORD)@$(POSTGRES_HOST)/$(POSTGRES_DB)

.PHONY: help
## help: shows this help message
help:
	@ echo "Usage: make [target]\n"
	@ sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

# ==============================================================================
# DB

.PHONY: start-psql
## start-psql: starts psql instance
start-psql:
	@ docker-compose up -d
	@ echo "Waiting for Postgres to start..."
	@ until docker exec $(POSTGRES_DATABASE_CONTAINER_NAME) psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)  -c "SELECT 1;" >/dev/null 2>&1; do \
		echo "Postgres not ready, sleeping for 5 seconds..."; \
		sleep 5; \
	done
	@ echo "Postgres is up and running."

.PHONY: stop-psql
## stop-psql: stops psql instance
stop-psql:
	@ docker-compose down

.PHONY: psql-console
## psql-console: opens psql terminal
psql-console: export PGPASSWORD=$(POSTGRES_PASSWORD)
psql-console:
	@ docker exec -it $(POSTGRES_DATABASE_CONTAINER_NAME) psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

# ==============================================================================
# DB migrations

.PHONY: create-migration
## create-migration: creates a migration file
create-migration:
	@ if [ -z "$(NAME)" ]; then echo >&2 "please set the name of the migration via the variable NAME"; exit 2; fi
	@ docker run --rm -v `pwd`/db/migrations:/migrations migrate/migrate create -ext sql -dir /migrations -seq $(NAME)

.PHONY: migrate-up
## migrate-up: runs migrations up to N version (optional)
migrate-up: start-psql
	@ docker run --rm --network $(POSTGRES_DATABASE_CONTAINER_NETWORK_NAME) -v `pwd`/db/migrations:/migrations migrate/migrate -database 'postgres://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@$(POSTGRES_DATABASE_CONTAINER_NAME):5432/$(POSTGRES_DB)?sslmode=disable' -path /migrations up $(N)

.PHONY: migrate-down
## migrate-down: runs migrations down to N version (optional)
migrate-down:
	@ if [ -z "$(N)" ]; then \
		docker run --rm --network $(POSTGRES_DATABASE_CONTAINER_NETWORK_NAME) -v `pwd`/db/migrations:/migrations migrate/migrate -database 'postgres://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@$(POSTGRES_DATABASE_CONTAINER_NAME):5432/$(POSTGRES_DB)?sslmode=disable' -path /migrations down -all; \
	else \
		docker run --rm --network $(POSTGRES_DATABASE_CONTAINER_NETWORK_NAME) -v `pwd`/db/migrations:/migrations migrate/migrate -database 'postgres://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@$(POSTGRES_DATABASE_CONTAINER_NAME):5432/$(POSTGRES_DB)?sslmode=disable' -path /migrations down $(N); \
	fi

.PHONY: migrate-version
## migrate-version: shows current migration version number
migrate-version:
	@ docker run --rm --network $(POSTGRES_DATABASE_CONTAINER_NETWORK_NAME) -v `pwd`/db/migrations:/migrations migrate/migrate -database 'postgres://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@$(POSTGRES_DATABASE_CONTAINER_NAME):5432/$(POSTGRES_DB)?sslmode=disable' -path /migrations version

.PHONY: migrate-force-version
## migrate-force-version: forces migrations to version V
migrate-force-version:
	@ if [ -z "$(V)" ]; then echo >&2 please set version via variable V; exit 2; fi
	@ docker run --rm --network $(POSTGRES_DATABASE_CONTAINER_NETWORK_NAME) -v `pwd`/db/migrations:/migrations migrate/migrate -database 'postgres://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@$(POSTGRES_DATABASE_CONTAINER_NAME):5432/$(POSTGRES_DB)?sslmode=disable' -path /migrations force $(V)

# ==============================================================================
# Unit tests

.PHONY: test
## test: run unit tests
test:
	@ go test -v ./... -count=1

# ==============================================================================
# App execution

.PHONY: run
## run: runs the app
run: migrate-up
	@ go run cmd/main.go

```

I've found a pretty cool tool called [makefile-graph](https://github.com/dnaeon/makefile-graph), which generates a graph representing the relationships between targets.

![graph](/assets/images/2024-08-22-go-docker-psql-migrations/graph.png)

## running it

first, we need to understand how to invoke `migrate` via docker.

this is the general sintax:

```
docker run --rm -v <migration_id>:/migrations migrate/migrate <command>
```

Explanation:

- `$(pwd)/db/migrations`: This expands to the absolute path of your db/migrations directory, based on your current working directory.
- `/migrations`: This is the target directory inside the Docker container where the db/migrations directory will be mounted.

### invoking our program

by issuing `make run`, it will:

1. start [PostgreSQL](https://www.postgresql.org/) dockerized instance via - [docker-compose](https://docs.docker.com/compose/);
2. wait for [PostgreSQL](https://www.postgresql.org/) to be active and ready to accept connections;
3. apply database migrations;
4. run `cmd/main.go`.

sample output when running it for the first time:

```
$ make run
[+] Running 3/3
 ✔ Network go-docker-psql-migrations_psqldb-network            Created                                                                                                 0.0s 
 ✔ Volume "go-docker-psql-migrations_psql_migrations_db_data"  Created                                                                                                 0.0s 
 ✔ Container psql_migrations_db                                Started                                                                                                 0.1s 
Waiting for Postgres to start...
Postgres not ready, sleeping for 5 seconds...
Postgres is up and running.
1/u create_users_table (4.0425ms)
2/u create_posts_table (9.23ms)
3/u create_comments_table (12.234ms)
4/u add_status_to_posts_table (14.9955ms)
+----------------------+--------------------+
| Table Name           | Column Name        |
+----------------------+--------------------+
| comments             | id                 |
| comments             | post_id            |
| comments             | user_id            |
| comments             | comment            |
| comments             | created_at         |
| posts                | id                 |
| posts                | user_id            |
| posts                | title              |
| posts                | content            |
| posts                | created_at         |
| posts                | status             |
| schema_migrations    | version            |
| schema_migrations    | dirty              |
| users                | id                 |
| users                | username           |
| users                | email              |
| users                | created_at         |
+----------------+--------------------------+
```

### adding a new migration

let's add a `status` column to the `posts` table:

```
$ make create-migration NAME=add_status_to_posts_table
/migrations/000004_add_status_to_posts_table.up.sql
/migrations/000004_add_status_to_posts_table.down.sql
```

our `000004_add_status_to_posts_table.up.sql` migration is:

```
ALTER TABLE posts
ADD COLUMN status VARCHAR(20) DEFAULT 'draft';
```

while our `000004_add_status_to_posts_table.down` migration is:

```
ALTER TABLE posts
DROP COLUMN status;
```

then, let's run it again:

```
$ make run
[+] Running 1/0
 ✔ Container psql_migrations_db  Running                                                                                                                               0.0s 
Waiting for Postgres to start...
Postgres is up and running.
4/u add_status_to_posts_table (3.515458ms)
+----------------------+--------------------+
| Table Name           | Column Name        |
+----------------------+--------------------+
| comments             | id                 |
| comments             | post_id            |
| comments             | user_id            |
| comments             | comment            |
| comments             | created_at         |
| posts                | id                 |
| posts                | user_id            |
| posts                | title              |
| posts                | content            |
| posts                | created_at         |
| posts                | status             |
| schema_migrations    | version            |
| schema_migrations    | dirty              |
| users                | id                 |
| users                | username           |
| users                | email              |
| users                | created_at         |
+----------------+--------------------------+
```

## available Makefile targets

```
$ make help
Usage: make [target]

  help                    shows this help message
  start-psql              starts psql instance
  stop-psql               stops psql instance
  psql-console            opens psql terminal
  create-migration        creates a migration file
  migrate-up              runs migrations up to N version (optional)
  migrate-down            runs migrations down to N version (optional)
  migrate-version         shows current migration version number
  migrate-force-version   forces migrations to version V
  test                    run unit tests
  run                     runs the app

```

## download the source

Here: [https://github.com/tiagomelo/go-docker-psql-migrations](https://github.com/tiagomelo/go-docker-psql-migrations)