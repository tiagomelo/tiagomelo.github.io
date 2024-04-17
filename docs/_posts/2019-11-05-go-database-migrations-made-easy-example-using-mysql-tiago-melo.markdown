---
layout: post
title:  "Go: database migrations made easy - an example using MySQL"
date:   2019-11-05 13:26:01 -0300
categories: go migrations mysql
---
![Go: database migrations made easy - an example using MySQL](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/2019-11-05-banner.png)

In my [article](https://www.linkedin.com/pulse/java-database-versioning-liquibase-tiago-melo/) about database migrations, I've shown how database migrations are done on [Ruby On Rails](https://rubyonrails.org/) and brought it to the [Java](https://www.java.com/) world. It's time to see how it works in [Go](https://golang.org/).

## Meet Migrate

I've been actively developing applications using [Go](https://golang.org/), and I needed to find a good solution for database migrations.

[Migrate](https://github.com/golang-migrate/migrate) is a robust and simple tool to use for that. It can be used as [CLI](https://github.com/golang-migrate/migrate#cli-usage) or as [library](https://github.com/golang-migrate/migrate#use-in-your-go-project)

In this article, we'll focus on [CLI](https://github.com/golang-migrate/migrate#cli-usage) usage.

### Main commands

We'll explore each of the following [CLI commands](https://github.com/golang-migrate/migrate/tree/master/cmd/migrate):

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572872382038.png)

### Migration files

A single logical migration is represented as two separate migration files, one to migrate "up" to the specified version from the previous version, and a second to migrate back "down" to the previous version.

The ordering and direction of the migration files are determined by the filenames used for them. The _migrate_ command expects the filenames of migrations to have the format:

```
{version}_{title}.up.{extension}
{version}_{title}.down.{extension}

```

The _title_ of each migration is unused and is only for readability. Similarly, the extension of the migration files is not checked by the library and should be an appropriate format for the database in use (.sql for SQL variants, for instance).

Versions of migrations may be represented as any 64-bit unsigned integer. All migrations are applied upward in order of increasing version number, and downward by decreasing version number.

Common versioning schemes include incrementing integers:

```
1_initialize_schema.down.sql
1_initialize_schema.up.sql
2_add_table.down.sql
2_add_table.up.sql

...

```

Or timestamps at an appropriate resolution:

```
1500360784_initialize_schema.down.sql
1500360784_initialize_schema.up.sql
1500445949_add_table.down.sql
1500445949_add_table.up.sql

...

```

But any scheme resulting in distinct, incrementing integers as versions is valid.

## The domain model

This is our initial domain model that will be evolved during this article:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572819554276.png)

The ' _Library_' table has a [One To Many](https://en.wikipedia.org/wiki/One-to-many_(data_model)) relationship with ' _Book_' table.

## The Go application

This is our final directory structure:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572960994439.png)

To ease the setup, I'm going to use [docker-compose](https://docs.docker.com/compose/) to launch our [MySQL](https://www.linkedin.com/redir/general-malware-page?url=https%3A%2F%2Fwww%2emysql%2ecom%2F) instance. I'm also using [Adminer](https://www.adminer.org/), which is a lightweight database management tool.

```
version: '3'
services:
  db:
    image: mysql:5.7
    restart: always
    container_name: mysql_database
    ports:
      - "5432:3306"
    volumes:
      - data:/var/lib/mysql
    environment:
      - MYSQL_USER=tutorial
      - MYSQL_PASSWORD=tutorialpasswd
      - MYSQL_ROOT_PASSWORD=Mysql2019!
      - MYSQL_DATABASE=migrations_tutorial
      - MYSQL_HOST_NAME=mysql_db
    networks:
      - app-network

  adminer:
    image: adminer
    container_name: adminer
    ports:
      - 8080:8080
    networks:
      - app-network

volumes:
  data:
    driver: local

networks:
  app-network:
    driver: bridge

```

If you are new to [Docker](https://www.docker.com/) and/or [docker-compose](https://docs.docker.com/compose/), whenever you want to use an image, you can visit [Docker Hub](https://hub.docker.com) to check for available images.

Some details:

- **db**: I'm using [_mysql:5.7_](https://hub.docker.com/_/mysql) image. This container name is set to 'mysql\_database', I'm exposing port 5432 to clients and it will be reachable by other containers by joining a custom network named 'app-network'.
- **adminer**: I'm using [adminer](https://hub.docker.com/_/adminer) image. This container name is set to 'adminer', I'm exposing port 8080 to clients and it will be reachable by other containers by joining a custom network named 'app-network'.
- **networks**: I'm creating a custom network called 'app-network' of type ' [bridge](https://www.docker.com/blog/understanding-docker-networking-drivers-use-cases/)'.

This is our [Go](https://golang.org/) script that connects to the database and displays all tables with their columns. It'll be used to show the effects of migrations:

```
//  This Go script displays all tables in a given database
//  along with their respective columns.
//
//  author: Tiago Melo (tiagoharris@gmail.com)

package main

import (
	"database/sql"
	"fmt"
	_ "github.com/go-sql-driver/mysql"
	"log"
	"strings"
)

// helper function to handle errors
func checkError(message string, err error) {
	if err != nil {
		log.Fatal(message, err)
	}
}

func showTablesWithColumns() {
	// sql.Open does not return a connection. It just returns a handle to the database.
	// In a real world scenario, those db credentials could be environment variables and we could use a package like github.com/kelseyhightower/envconfig to read them.
	db, err := sql.Open("mysql", "root@tcp(127.0.0.1:5432)/migrations_tutorial")

	// A defer statement pushes a function call onto a list.
	// The list of saved calls is executed after the surrounding function returns.
	// Defer is commonly used to simplify functions that perform various clean-up actions.
	defer db.Close()

	checkError("Error getting a handle to the database", err)

	// Now it's time to validate the Data Source Name (DSN) to check if the connection
	// can be correctly established.
	err = db.Ping()

	checkError("Error establishing a connection to the database", err)

	showTablesQuery, err := db.Query("SHOW TABLES")

	defer showTablesQuery.Close()

	checkError("Error creating the query", err)

	for showTablesQuery.Next() {
		var tableName string

		// Get table name
		err = showTablesQuery.Scan(&tableName)

		checkError("Error querying tables", err)

		selectQuery, err := db.Query(fmt.Sprintf("SELECT * FROM %s", tableName))

		defer selectQuery.Close()

		checkError("Error creating the query", err)

		// Get column names from the given table
		columns, err := selectQuery.Columns()
		if err != nil {
			checkError(fmt.Sprintf("Error getting columns from table %s", tableName), err)
		}

		fmt.Printf("table name: %s -- columns: %v\n", tableName, strings.Join(columns, ", "))
	}
}

func main() {
	showTablesWithColumns()
}

```

When it comes to [Go](https://golang.org/) development, a common tool to use is our good old friend [Make](https://en.wikipedia.org/wiki/Make_(software)). This is the [Makefile](https://en.wikipedia.org/wiki/Makefile) that I've written to facilitate issuing migration commands:

```
# Author: Tiago Melo (tiagoharris@gmail.com)

# Version - this is optionally used on goto command
V?=

# Number of migrations - this is optionally used on up and down commands
N?=

# In a real world scenario, these environment variables
# would be injected by your build tool, like Drone for example (https://drone.io/)
MYSQL_USER ?= tutorial
MYSQL_PASSWORD ?= tutorialpasswd
MYSQL_HOST ?= 127.0.0.1
MYSQL_DATABASE ?= migrations_tutorial
MYSQL_PORT ?= 5432

MYSQL_DSN ?= $(MYSQL_USER):$(MYSQL_PASSWORD)@tcp($(MYSQL_HOST):$(MYSQL_PORT))/$(MYSQL_DATABASE)

local-db:
	@ docker-compose up -d

	@ until mysql --host=$(MYSQL_HOST) --port=$(MYSQL_PORT) --user=$(MYSQL_USER) -p$(MYSQL_PASSWORD) --protocol=tcp -e 'SELECT 1' >/dev/null 2>&1 && exit 0; do \
	  >&2 echo "MySQL is unavailable - sleeping"; \
	  sleep 5 ; \
	done

	@ echo "MySQL is up and running!"

migrate-setup:
	@if [ -z "$$(which migrate)" ]; then echo "Installing migrate command..."; go install -tags 'mysql' github.com/golang-migrate/migrate/v4/cmd/migrate; fi

migrate-up: migrate-setup
	@ migrate -database 'mysql://$(MYSQL_DSN)?multiStatements=true' -path migrations up $(N)

migrate-down: migrate-setup
	@ migrate -database 'mysql://$(MYSQL_DSN)?multiStatements=true' -path migrations down $(N)

migrate-to-version: migrate-setup
	@ migrate -database 'mysql://$(MYSQL_DSN)?multiStatements=true' -path migrations goto $(V)

drop-db: migrate-setup
	@ migrate -database 'mysql://$(MYSQL_DSN)?multiStatements=true' -path migrations drop

force-version: migrate-setup
	@ migrate -database 'mysql://$(MYSQL_DSN)?multiStatements=true' -path migrations force $(V)

migration-version: migrate-setup
	@ migrate -database 'mysql://$(MYSQL_DSN)?multiStatements=true' -path migrations version

build:
	@ go build inspect_database.go

run: build
	@ ./inspect_database

```

## It's showtime!

Let's first set up our database:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572960655495.png)

The _local-db_ target invokes _docker-compose up -d_ command and waits for [MySQL](https://www.linkedin.com/redir/general-malware-page?url=https%3A%2F%2Fwww%2emysql%2ecom%2F) to be ready to accept connections.

Now let's check if the containers were successfully created:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572960813893.png)

Ok. And then we check that the volume 'data' was created as well:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572960901197.png)

And then, if we run the app, since we don't have any tables, there's no output:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572961156102.png)

### Create Library and Book tables

Let's write the migrations and put them under _migrations_ folder.

_0001\_create\_library\_table.up.sql_

```
CREATE TABLE IF NOT EXISTS `library` (
	id INTEGER PRIMARY KEY AUTO_INCREMENT,
	name VARCHAR(100) NOT NULL UNIQUE
);

```

_0001\_create\_library\_table.down.sql_

```
DROP TABLE IF EXISTS `library`;

```

_0002\_create\_book\_table.up.sql_

```
CREATE TABLE IF NOT EXISTS `book` (
	id INTEGER PRIMARY KEY AUTO_INCREMENT,
	title VARCHAR(100) NOT NULL UNIQUE,
	library_id INTEGER,
	FOREIGN KEY(library_id) REFERENCES library(id)
);

```

_0002\_create\_book\_table.down.sql_

```
DROP TABLE IF EXISTS `book`;

```

Now it's time to run the pending migrations:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572965626618.png)

Cool. Let's run the app:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572965689886.png)

The _schema\_migrations_ table is created by [Migrate](https://github.com/golang-migrate/migrate) tool to keep track of migrations. We'll see it in a minute.

Another way to check the recently created tables is through [Adminer](https://www.adminer.org/). Just point your browser to localhost:8080 and use the credentials defined in _docker-compose.yaml_:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572965990587.png)

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572966007377.png)

### Add columns to 'Book' table

Now let's add two columns: _isbn_ and _publisher_, by adding the corresponding 'up' and 'down' migration files into _migrations_ folder.

_0003\_add\_isbn\_and\_publisher\_to\_book.up.sql_

```
BEGIN;

ALTER TABLE `book`

ADD COLUMN `isbn` varchar(13) NOT NULL,
ADD COLUMN `publisher` varchar(20) NOT NULL;

COMMIT;

```

_0003\_add\_isbn\_and\_publisher\_to\_book.down.sql_

```
BEGIN;

ALTER TABLE `book` DROP COLUMN `isbn`;
ALTER TABLE `book` DROP COLUMN `publisher`;

COMMIT;

```

Note that this time we are using BEGIN and COMMIT to make those changes into a single transaction.

Let's run the pending migrations:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572966327214.png)

Now we should see the new columns when running the app:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572966374804.png)

You could check that through [Adminer](https://www.adminer.org/) if you want.

### Drop 'publisher' column on 'Book' table

What if 'publisher' column is not necessary anymore? Add the migration files into _migrations_ folder.

_0004\_drop\_publisher\_on\_book.up.sql_

```
ALTER TABLE `book` DROP COLUMN `publisher`;

```

_0004\_drop\_publisher\_on\_book.down.sql_

```
ALTER TABLE `book` ADD COLUMN `publisher` varchar(20) NOT NULL;

```

Let's run the pending migrations:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572966606312.png)

Now we should see that 'publisher' is not on 'Book' table anymore when running the app:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572966674269.png)

## Playing around

Now that we have all of the tables in place with the desired changes, it's time to know some other options that we have.

Given that we have **4 migrations** (each one with the corresponding 'up' and 'down' files), let's see how _schema\_migrations_ table looks like. Let's connect to our [MySQL](https://www.linkedin.com/redir/general-malware-page?url=https%3A%2F%2Fwww%2emysql%2ecom%2F) [Docker](https://www.docker.com/) container:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572967000884.png)

### Print current migration version

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572967116286.png)

### Dropping the database

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572967214624.png)

### Applying N up migrations

Since we dropped the database above, let's just create 'Library' and 'Book' tables. This can be accomplished by passing N=2:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572967400577.png)

### Applying N down migrations

Let's rollback migration #2 which creates 'Book' table. To do this, let's pass N=1:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572967529722.png)

### Migrate to a given version

Right now we have only 'Library' table. What if we want to jump up to migration #3? Just pass V=3:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572967760933.png)

### Force a given version

This command sets the desired version but does not run the migration. This is useful when dealing with legacy databases.

For example: suppose that 'Library' and 'Book' tables already exist, and you want to use [Migrate](https://github.com/golang-migrate/migrate) from now on. Let's drop the database and create the tables manually:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572968559599.png)

Ok. Now we want to tell to [Migrate](https://github.com/golang-migrate/migrate) that the database is currently on version #2 (with 'Library' and 'Book' tables in place, but 'Book' does not have 'isbn' and 'publisher' columns):

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572968240079.png)

Let's check the migration version - it will read from _schema\_migrations_ table:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572968702731.png)

Now, if we ask to run all pending migrations, since we forced it to version #2, only migration files #3 and #4 will run:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572968788499.png)

Now let's check the tables by running the app:

![No alt text provided for this image](/assets/images/2019-11-05-41fcf0f8-7d0c-494a-87f9-89f30deb1c0f/1572968854312.png)

Cool, isn't it?

## Conclusion

Versioning database changes is as important as versioning source code, and tools like [Migrate](https://github.com/golang-migrate/migrate) makes it possible to do it in a safe and manageable way.

Through this simple example, we learned how we can easily evolve a database in a [Go](https://golang.org/) application.

## Download the source

Here: [https://bitbucket.org/tiagoharris/migrations\_tutorial/src/master/](https://bitbucket.org/tiagoharris/migrations_tutorial/src/master/)