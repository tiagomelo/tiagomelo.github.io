---
layout: post
title:  "Quarkus: database migrations with Liquibase and local environment setup"
date:   2024-03-11 13:26:01 -0300
categories: java quarkus liquibase migrations
---
![Quarkus: database migrations with Liquibase and local environment setup](/assets/images/2024-03-11-1eb57ce5-084e-459c-b022-ceda272ff399/2024-03-11-banner.jpeg)

I've been using [Spring Boot](https://spring.io/projects/spring-boot?trk=article-ssr-frontend-pulse_little-text-block) for many years now. It is usually my choice when it comes for [Java](https://java.com?trk=article-ssr-frontend-pulse_little-text-block) development due to its mission to ease our lives.

Some of my articles on it:

- [Java: centralized logging with Spring Boot, Elasticsearch, Logstash and Kibana](https://www.linkedin.com/pulse/java-centralized-logging-spring-boot-elasticsearch-logstash-melo?trk=article-ssr-frontend-pulse_little-text-block)
- [Java: database versioning with Liquibase](https://www.linkedin.com/pulse/java-database-versioning-liquibase-tiago-melo?trk=article-ssr-frontend-pulse_little-text-block)
- [Spring Boot: asynchronous processing with @Async annotation](https://www.linkedin.com/pulse/spring-boot-asynchronous-processing-async-annotation-tiago-melo?trk=article-ssr-frontend-pulse_little-text-block)
- [Spring Boot Batch: exporting millions of records from a MySQL table to a CSV file without eating all your memory](https://www.linkedin.com/pulse/spring-boot-batch-exporting-millions-records-from-mysql-tiago-melo?trk=article-ssr-frontend-pulse_little-text-block)
- [Java: an appointment scheduler with Spring Boot, MySQL and Quartz](https://www.linkedin.com/pulse/java-appointment-scheduler-spring-boot-mysql-quartz-tiago-melo?trk=article-ssr-frontend-pulse_little-text-block)
- [Spring Boot: an example of a CRUD RESTful API with global exception handling](https://www.linkedin.com/pulse/spring-boot-example-crud-restful-api-global-exception-tiago-melo?trk=article-ssr-frontend-pulse_little-text-block)

Then I've heard about [Quarkus](http://quarkus.io?trk=article-ssr-frontend-pulse_little-text-block). Being released in 2019, it promises to revolutionize [Java](https://java.com?trk=article-ssr-frontend-pulse_little-text-block) development by offering a framework optimized for cloud-native environments, enabling both imperative and reactive programming with fast startup times and low memory footprint.

I'm planning to revisit some of the aforementined articles to show how to do the equivalent with [Quarkus.](http://quarkus.io/?trk=article-ssr-frontend-pulse_little-text-block)

In this short article we'll see how to integrate [Liquibase](https://liquibase.com?trk=article-ssr-frontend-pulse_little-text-block) with [Quarkus](http://quarkus.io/?trk=article-ssr-frontend-pulse_little-text-block) for database migrations.

## Starting the project

As mentioned [here](https://quarkus.io/guides/getting-started?trk=article-ssr-frontend-pulse_little-text-block), you can start your application using [Quarkus](http://quarkus.io/?trk=article-ssr-frontend-pulse_little-text-block) CLI. But in the same way [Spring Boot](https://spring.io/projects/spring-boot?trk=article-ssr-frontend-pulse_little-text-block) does with its [Spring Initializr](https://start.spring.io/?trk=article-ssr-frontend-pulse_little-text-block), [Quarkus](http://quarkus.io/?trk=article-ssr-frontend-pulse_little-text-block) also offers a helpful starter website: [https://code.quarkus.io/](https://code.quarkus.io/?trk=article-ssr-frontend-pulse_little-text-block).

![No alt text provided for this image](/assets/images/2024-03-11-1eb57ce5-084e-459c-b022-ceda272ff399/1710163299982.png)

We'll use three extensions:

- quarkus-jdbc-postgresql;
- quarkus-liquibase;
- quarkus-config-yaml: this one makes it possible to use yaml instead of properties files.

They'll be properly added to pom.xml (if you chose to use Maven).

The majority of Quarkus extenstions provide a starter code option to get you rolling, but I'm not going to use it in this example.

## Liquibase configuration

It is pretty much similar to what I've showed in [this article](https://www.linkedin.com/pulse/java-database-versioning-liquibase-tiago-melo?trk=article-ssr-frontend-pulse_little-text-block):

src/main/resources/db/liquibase-changelog.yml

```
databaseChangeLog:
-  includeAll:
      path: db/changelog/
```

This is to point the exact location of migration files. I rather have separate migration files instead of having everything defined into a single yaml file as some tutorials and documentations around the web suggests.

src/main/resources/db/changelog/0001\_create\_book\_table.yml

```
databaseChangeLog:
-  changeSet:
      author: Tiago Melo
      id: creates_book_table
      changes:
      -  createTable:
            tableName: book
            columns:
            -  column:
                  name: id
                  type: BIGINT
                  autoIncrement: true
                  constraints:
                     primaryKey: true
            -  column:
                  name: title
                  type: VARCHAR(255)
                  constraints:
                     nullable: false
            -  column:
                  name: author
                  type: VARCHAR(255)
                  constraints:
                     nullable: false
            -  column:
                  name: pages
                  type: INTEGER
                  constraints:
                     nullable: false

      -  addUniqueConstraint:
            columnNames: title, author
            constraintName: book_title_author_unique
            tableName: book
```

This is the migration file itself.

### Application configuration

This is the fun part. Per the [official documentation](https://pt.quarkus.io/guides/config-reference#default-profiles?trk=article-ssr-frontend-pulse_little-text-block),

![No alt text provided for this image](/assets/images/2024-03-11-1eb57ce5-084e-459c-b022-ceda272ff399/1710165618283.png)

[Quarkus](http://quarkus.io?trk=article-ssr-frontend-pulse_little-text-block) offers a way to quick bootstrap your application without any further configuration for development purposes, leveraging the "[convention over configuration](https://en.wikipedia.org/wiki/Convention_over_configuration?trk=article-ssr-frontend-pulse_little-text-block)" paradigm. Which means that we don't need to configure [Postgres](https://www.postgresql.org/?trk=article-ssr-frontend-pulse_little-text-block) (which is the db in our example) at all if we want to spin up the application and toy with it. The framework will provision the [Docker](https://docker.com?trk=article-ssr-frontend-pulse_little-text-block) containers that are needed, and as soon as you stop the application, they'll be gone along with their respectives volumes.

### Dev mode configuration

src/main/resources/application.yml

```
quarkus:
   liquibase:
      migrate-at-start: true
      change-log: db/liquibase-changelog.yml
```

And this is it. No [Postgres](https://www.postgresql.org/?trk=article-ssr-frontend-pulse_little-text-block) at all. We're just telling the framework that we want to run database migrations at app's start and we're pointing out the exact location for our changelog yaml.

### "local" mode configuration

While the aforementined dev mode is cool and useful, you lose all your data everytime you shutdown the application, as I'll show in the next section. The dev mode is to get you up and running quickly, without having to configure your dependencies, just to see how the app works and stuff. But most of the time, at least the way I'm used to develop my apps, I do want to have a local database, not recreating it everytime I start the app.

That's where [custom profiles](https://pt.quarkus.io/guides/config-reference#custom-profiles?trk=article-ssr-frontend-pulse_little-text-block) comes to play.

Since we're using yaml files instead of properties files, the way you create a custom profile is as simple as adding a suffix to the application.yaml file:

```
application-<custom_profile_id>.yaml
```

As said before, the framework uses [Docker](https://docker.com/?trk=article-ssr-frontend-pulse_little-text-block) to provision the containers needed by the app. What I want to do is to have a custom profile named local where I can access the database anytime I want and don't lose its data. To achieve that, we'll use [docker-compose](https://docs.docker.com/compose/?trk=article-ssr-frontend-pulse_little-text-block) and a custom application yaml file.

docker-compose.yaml, located at app's project root:

```
version: '3.8'
services:
   book_psql_db:
      image: postgres
      container_name: books_db
      restart: always
      env_file:
      - .env-local
      ports:
      - 50994:5432
      volumes:
      - book_psql_db_data:/var/lib/postgresql/data
volumes:
   book_psql_db_data:

```

.env-local, located at app's project root:

```
POSTGRES_USER=booksuser
POSTGRES_PASSWORD=uDkeuRMJB4R2bPNVqjhA
POSTGRES_DB=books
POSTGRES_HOST=localhost:5432
```

## Running the application

### Dev mode

```
$ quarkus dev

...

2024-03-11 11:20:11,932 INFO  [liq.util] (Quarkus Main Thread) UPDATE SUMMARY
2024-03-11 11:20:11,932 INFO  [liq.util] (Quarkus Main Thread) Run:                          1
2024-03-11 11:20:11,932 INFO  [liq.util] (Quarkus Main Thread) Previously run:               0
2024-03-11 11:20:11,932 INFO  [liq.util] (Quarkus Main Thread) Filtered out:                 0
2024-03-11 11:20:11,932 INFO  [liq.util] (Quarkus Main Thread) -------------------------------
2024-03-11 11:20:11,932 INFO  [liq.util] (Quarkus Main Thread) Total change sets:            1
2024-03-11 11:20:11,932 INFO  [liq.util] (Quarkus Main Thread) Update summary generated
2024-03-11 11:20:11,933 INFO  [liq.command] (Quarkus Main Thread) Update command completed successfully.
Liquibase: Update has been successful. Rows affected: 1

```

It ran the migration and created the books table.

```
$ docker ps

CONTAINER ID   IMAGE                       COMMAND                  CREATED          STATUS             PORTS                     NAMES
a5f4ff73e90b   postgres:14                 "docker-entrypoint.s…"   45 seconds ago   Up 44 seconds      0.0.0.0:55069->5432/tcp   nice_lamarr
086e449a38b4   testcontainers/ryuk:0.6.0   "/bin/ryuk"              45 seconds ago   Up 44 seconds      0.0.0.0:55067->8080/tcp   testcontainers-ryuk-5485a092-8da2-42ad-846d-1d68d84eb1a9
```

We see that it created two containers, and one of them is for the database.

As mentioned [here](https://pt.quarkus.io/guides/databases-dev-services#connect-to-database-run-as-a-dev-service?trk=article-ssr-frontend-pulse_little-text-block), the framework created the database and defined the credentials for us - quarkus for both username and password.

Let's access it:

```
$ docker exec -it nice_lamarr /bin/bash

psql -U quarkus

root@a5f4ff73e90b:/# psql -U quarkus
psql (14.11 (Debian 14.11-1.pgdg120+2))
Type "help" for help.

quarkus=# \dt
                List of relations
 Schema |         Name          | Type  |  Owner
--------+-----------------------+-------+---------
 public | books                 | table | quarkus
 public | databasechangelog     | table | quarkus
 public | databasechangeloglock | table | quarkus
(3 rows)

quarkus=# insert into books (title, author, pages) values ('some title', 'some author', 100);
INSERT 0 1
```

So far, so good. But if we stop the application, those containers will be destroyed along with their volumes:

```
$ docker ps

CONTAINER ID   IMAGE      COMMAND                  CREATED        STATUS             PORTS                     NAMES
```

And if you spin up the app again,

```
$ quarkus dev

...

2024-03-11 11:28:02,824 INFO  [liq.util] (Quarkus Main Thread) UPDATE SUMMARY
2024-03-11 11:28:02,825 INFO  [liq.util] (Quarkus Main Thread) Run:                          1
2024-03-11 11:28:02,825 INFO  [liq.util] (Quarkus Main Thread) Previously run:               0
2024-03-11 11:28:02,825 INFO  [liq.util] (Quarkus Main Thread) Filtered out:                 0
2024-03-11 11:28:02,825 INFO  [liq.util] (Quarkus Main Thread) -------------------------------
2024-03-11 11:28:02,825 INFO  [liq.util] (Quarkus Main Thread) Total change sets:            1
2024-03-11 11:28:02,825 INFO  [liq.util] (Quarkus Main Thread) Update summary generated
2024-03-11 11:28:02,826 INFO  [liq.command] (Quarkus Main Thread) Update command completed successfully.
Liquibase: Update has been successful. Rows affected: 1

```

You'll see that the database was created and initialized again, meaning that you've lost your data:

```
$ docker exec -it stupefied_kowalevski /bin/bash

root@f66b85a98828:/# psql -U quarkus
psql (14.11 (Debian 14.11-1.pgdg120+2))
Type "help" for help.

quarkus=# select * from books;
 id | title | author | pages
----+-------+--------+-------
(0 rows)
```

### 'local' profile

As we can see [here](https://access.redhat.com/documentation/pt-br/red_hat_build_of_quarkus/1.3/html/configuring_your_quarkus_applications/proc-using-configuration-profiles_quarkus-configuration-guide?trk=article-ssr-frontend-pulse_little-text-block), there are two ways of selecting the desired profile you want:

![No alt text provided for this image](/assets/images/2024-03-11-1eb57ce5-084e-459c-b022-ceda272ff399/1710167610869.png)

We'll use the first approach.

First, let's launch our database:

```
$ docker-compose up -d books_psql_db
```

Then, let's use our local profile to launch the app:

```
$ quarkus dev -Dquarkus.profile=local

...

2024-03-11 11:35:27,635 INFO  [liq.util] (Quarkus Main Thread) UPDATE SUMMARY
2024-03-11 11:35:27,635 INFO  [liq.util] (Quarkus Main Thread) Run:                          1
2024-03-11 11:35:27,635 INFO  [liq.util] (Quarkus Main Thread) Previously run:               0
2024-03-11 11:35:27,635 INFO  [liq.util] (Quarkus Main Thread) Filtered out:                 0
2024-03-11 11:35:27,635 INFO  [liq.util] (Quarkus Main Thread) -------------------------------
2024-03-11 11:35:27,635 INFO  [liq.util] (Quarkus Main Thread) Total change sets:            1
2024-03-11 11:35:27,636 INFO  [liq.util] (Quarkus Main Thread) Update summary generated
2024-03-11 11:35:27,637 INFO  [liq.command] (Quarkus Main Thread) Update command completed successfully.
Liquibase: Update has been successful. Rows affected: 1

```

We see that the migration was done.

```
$ docker ps
CONTAINER ID   IMAGE      COMMAND                  CREATED         STATUS         PORTS                     NAMES
4ab39ad0e263   postgres   "docker-entrypoint.s…"   2 minutes ago   Up 2 minutes   0.0.0.0:50994->5432/tcp   books_db
```

Now let's access the database:

```
$ docker exec -it books_db /bin/bash

root@4ab39ad0e263:/# psql -U booksuser -d books -W
Password:

books=# \dt
                 List of relations
 Schema |         Name          | Type  |   Owner
--------+-----------------------+-------+-----------
 public | books                 | table | booksuser
 public | databasechangelog     | table | booksuser
 public | databasechangeloglock | table | booksuser
(3 rows)

books=# insert into books (title, author, pages) values ('some title', 'some author', 100);
INSERT 0 1
```

This time we use the username and password defined in our .env-local file.

Now you can stop the app and run it again,

```
$ quarkus dev -Dquarkus.profile=local

...

2024-03-11 11:39:49,096 INFO  [liq.util] (Quarkus Main Thread) UPDATE SUMMARY
2024-03-11 11:39:49,097 INFO  [liq.util] (Quarkus Main Thread) Run:                          0
2024-03-11 11:39:49,097 INFO  [liq.util] (Quarkus Main Thread) Previously run:               1
2024-03-11 11:39:49,097 INFO  [liq.util] (Quarkus Main Thread) Filtered out:                 0
2024-03-11 11:39:49,097 INFO  [liq.util] (Quarkus Main Thread) -------------------------------
2024-03-11 11:39:49,097 INFO  [liq.util] (Quarkus Main Thread) Total change sets:            1
```

And we'll see that the framework shows you that a previous migration was already ran and the database is up to date.

```
$ docker exec -it books_db /bin/bash
root@4ab39ad0e263:/# psql -U booksuser -d books -W
Password:
psql (16.2 (Debian 16.2-1.pgdg120+2))
Type "help" for help.

books=# select * from books;
 id |   title    |   author    | pages
----+------------+-------------+-------
  1 | some title | some author |   100
(1 row)

```

There you go. Our database is intact.

### Conclusion

[Quarkus](http://quarkus.io/?trk=article-ssr-frontend-pulse_little-text-block) is a relatively new framework that seems to be a good choice for building microservices, rest apis, real-data analysis tools (it supports seamsly integation with [Kafka](https://kafka.apache.org/?trk=article-ssr-frontend-pulse_little-text-block) and other solutions) and etc.

For what I see, it helps a lot with the initial setup and the source code itself, making it easier to develop java apps with minimum hassle. I'm enjoying it.

I'll work on my previous [Spring Boot](https://spring.io/projects/spring-boot?trk=article-ssr-frontend-pulse_little-text-block) articles to bring them to [Quarkus](http://quarkus.io/?trk=article-ssr-frontend-pulse_little-text-block) and let's see.

## Download the source

Here: [https://github.com/tiagomelo/quarkus-with-liquibase](https://github.com/tiagomelo/quarkus-with-liquibase?trk=article-ssr-frontend-pulse_little-text-block)