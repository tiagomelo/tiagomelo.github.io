---
layout: post
title:  "Quick tip: how to rollback insert migrations with Liquibase (Java)"
date:   2024-10-02 14:50:20 -0000
categories: java liquibase
---

![banner](/assets/images/2024-10-02-java-liquibase-rollback-insert-migration/banner.png)

As I've explained in [previous](https://tiagomelo.info/java/quarkus/liquibase/migrations/2024/03/11/quarkus-database-migrations-liquibase-local-environment-tiago-melo-5cp0f.html) [posts](https://tiagomelo.info/java/springboot/liquibase/2019/03/07/java-database-versioning-liquibase-tiago-melo.html), I use [Liquibase](https://www.liquibase.com/) for dealing with database migrations.

This is a quick tip about how to rollback insertion migrations.

# sample domain

Suppose these tables:

![tables](/assets/images/2024-10-02-java-liquibase-rollback-insert-migration/tables.png)

For demonstration purposes, it makes sense to seed `inventory` table, which means to insert some initial data when creating tables.

We could do it manually:

```
-- Insert sample records into the inventory table
INSERT INTO inventory (product_id, stock, last_updated) VALUES 
(1, 100, CURRENT_TIMESTAMP),
(2, 50, CURRENT_TIMESTAMP),
(3, 200, CURRENT_TIMESTAMP),
(4, 75, CURRENT_TIMESTAMP),
(5, 120, CURRENT_TIMESTAMP),
(6, 30, CURRENT_TIMESTAMP),
(7, 250, CURRENT_TIMESTAMP),
(8, 60, CURRENT_TIMESTAMP),
(9, 90, CURRENT_TIMESTAMP),
(10, 500, CURRENT_TIMESTAMP);
```

But it would be nice to delegate that to [Liquibase](https://www.liquibase.com/).

# migration files

1. `1_create_inventory_table.yml`

```
databaseChangeLog:
  - changeSet:
      author: "tiago"
      id: "creates_inventory_table"
      changes:
        - createTable:
            tableName: "inventory"
            columns:
              - column:
                  name: "product_id"
                  type: "INT"
                  constraints:
                    primaryKey: "true"
              - column:
                  name: "stock"
                  type: "INT"
                  constraints:
                    nullable: "false"
              - column:
                  name: "last_updated"
                  type: "TIMESTAMP"
                  defaultValueComputed: "CURRENT_TIMESTAMP"

```

2. `2_seed_inventory_table.yml`

```
databaseChangeLog:
  - changeSet:
      author: tiago
      id: "seeds_inventory_table"
      changes:
        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 1
              - column:
                  name: stock
                  valueNumeric: 100
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 2
              - column:
                  name: stock
                  valueNumeric: 50
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 3
              - column:
                  name: stock
                  valueNumeric: 200
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 4
              - column:
                  name: stock
                  valueNumeric: 75
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 5
              - column:
                  name: stock
                  valueNumeric: 120
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 6
              - column:
                  name: stock
                  valueNumeric: 30
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 7
              - column:
                  name: stock
                  valueNumeric: 250
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 8
              - column:
                  name: stock
                  valueNumeric: 60
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 9
              - column:
                  name: stock
                  valueNumeric: 90
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 10
              - column:
                  name: stock
                  valueNumeric: 500
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

```

3. `3_create_orders_table.yml`

```
databaseChangeLog:
  - changeSet:
      author: "tiago"
      id: "creates_orders_table"
      changes:
        - createTable:
            tableName: "orders"
            columns:
              - column:
                  name: "id"
                  type: "BIGINT"
                  autoIncrement: "true"
                  constraints:
                    primaryKey: "true"
              - column:
                  name: "order_id"
                  type: "UUID"
                  constraints:
                    nullable: "false"
                    unique: "true"
              - column:
                  name: "product_id"
                  type: "INT"
                  constraints:
                    nullable: "false"
              - column:
                  name: "quantity"
                  type: "INT"
                  constraints:
                    nullable: "false"
              - column:
                  name: "status"
                  type: "VARCHAR(50)"
                  constraints:
                    nullable: "false"
              - column:
                  name: "processed_at"
                  type: "TIMESTAMP"
                  defaultValueComputed: "CURRENT_TIMESTAMP"
        - addForeignKeyConstraint:
            baseTableName: "orders"
            baseColumnNames: "product_id"
            referencedTableName: "inventory"
            referencedColumnNames: "product_id"
            constraintName: "fk_orders_inventory"

```

# running the migrations

Supposing we're using [Maven](https://maven.apache.org/), we have the dependency for [Liquibase](https://www.liquibase.com/) and [Postgres](https://www.postgresql.org/), which is the database used in this example:

```
<dependency>
    <groupId>org.liquibase</groupId>
    <artifactId>liquibase-core</artifactId>
</dependency>

<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
    <scope>runtime</scope>
</dependency>
```

and the [Liquibase](https://www.liquibase.com/) plugin:

```
<!-- https://mvnrepository.com/artifact/org.liquibase/liquibase-maven-plugin -->
<dependency>
    <groupId>org.liquibase</groupId>
    <artifactId>liquibase-maven-plugin</artifactId>
    <version>4.29.2</version>
</dependency>
```

and the `build` section:

```
<build>
    <plugins>
        <plugin>
            <groupId>org.liquibase</groupId>
            <artifactId>liquibase-maven-plugin</artifactId>
            <configuration>
                <propertyFile>src/main/resources/liquibase.yml</propertyFile>
            </configuration>
        </plugin>
    </plugins>
</build>
```

So when we run it, 

```
$ mvn liquibase:update -Dliquibase.changeLogFile=db/liquibase-changelog.yml
...

[INFO] ####################################################
##   _     _             _ _                      ##
##  | |   (_)           (_) |                     ##
##  | |    _  __ _ _   _ _| |__   __ _ ___  ___   ##
##  | |   | |/ _` | | | | | '_ \ / _` / __|/ _ \  ##
##  | |___| | (_| | |_| | | |_) | (_| \__ \  __/  ##
##  \_____/_|\__, |\__,_|_|_.__/ \__,_|___/\___|  ##
##              | |                               ##
##              |_|                               ##
##                                                ## 
##  Get documentation at docs.liquibase.com       ##
##  Get certified courses at learn.liquibase.com  ## 
##                                                ##
####################################################
Starting Liquibase at 12:27:34 (version 4.29.2 #3683 built at 2024-08-29 16:45+0000)
[INFO] Set default schema name to public
[INFO] Parsing Liquibase Properties File src/main/resources/liquibase.yml for changeLog parameters
[INFO] Executing on Database: jdbc:postgresql://localhost:5432/orders
[WARNING] Potentially ignored key(s) in property file src/main/resources/liquibase.yml
 - 'outputChangeLogFile'
[INFO] Reading resource: db/changelog/1_create_inventory_table.yml
[INFO] Reading resource: db/changelog/2_seed_inventory_table.yml
[INFO] Reading resource: db/changelog/3_create_orders_table.yml
[INFO] Reading from databasechangelog
[INFO] Successfully acquired change log lock
[INFO] Using deploymentId: 7882854711
[INFO] Reading from databasechangelog
[INFO] Running Changeset: db/changelog/1_create_inventory_table.yml::creates_inventory_table::tiago
[INFO] Table inventory created
[INFO] ChangeSet db/changelog/1_create_inventory_table.yml::creates_inventory_table::tiago ran successfully in 7ms
[INFO] Running Changeset: db/changelog/2_seed_inventory_table.yml::seeds_inventory_table::tiago
[INFO] New row inserted into inventory
[INFO] New row inserted into inventory
[INFO] New row inserted into inventory
[INFO] New row inserted into inventory
[INFO] New row inserted into inventory
[INFO] New row inserted into inventory
[INFO] New row inserted into inventory
[INFO] New row inserted into inventory
[INFO] New row inserted into inventory
[INFO] New row inserted into inventory
[INFO] ChangeSet db/changelog/2_seed_inventory_table.yml::seeds_inventory_table::tiago ran successfully in 5ms
[INFO] Running Changeset: db/changelog/3_create_orders_table.yml::creates_orders_table::tiago
[INFO] Table orders created
[INFO] Foreign key constraint added to orders (product_id)
[INFO] ChangeSet db/changelog/3_create_orders_table.yml::creates_orders_table::tiago ran successfully in 10ms

UPDATE SUMMARY
Run:                          3
Previously run:               0
Filtered out:                 0
-------------------------------
Total change sets:            3

[INFO] UPDATE SUMMARY
[INFO] Run:                          3
[INFO] Previously run:               0
[INFO] Filtered out:                 0
[INFO] -------------------------------
[INFO] Total change sets:            3
[INFO] Update summary generated
[INFO] Update command completed successfully.
[INFO] Liquibase: Update has been successful. Rows affected: 13
[INFO] Successfully released change log lock
[INFO] Command execution complete
[INFO] ------------------------------------------------------------------------
[INFO] 
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  1.039 s
[INFO] Finished at: 2024-10-02T12:27:34-03:00
[INFO] ------------------------------------------------------------------------
```

Nice. We can see that tables were created and `inventory` table was properly seeded:

```
$ psql -U postgres orders
psql (16.4 (Homebrew))
Type "help" for help.

orders=# \dt
                 List of relations
 Schema |         Name          | Type  |  Owner   
--------+-----------------------+-------+----------
 public | databasechangelog     | table | postgres
 public | databasechangeloglock | table | postgres
 public | inventory             | table | postgres
 public | orders                | table | postgres
(4 rows)

orders=# select * from inventory;
 product_id | stock |        last_updated        
------------+-------+----------------------------
          1 |   100 | 2024-10-02 12:27:34.742224
          2 |    50 | 2024-10-02 12:27:34.742224
          3 |   200 | 2024-10-02 12:27:34.742224
          4 |    75 | 2024-10-02 12:27:34.742224
          5 |   120 | 2024-10-02 12:27:34.742224
          6 |    30 | 2024-10-02 12:27:34.742224
          7 |   250 | 2024-10-02 12:27:34.742224
          8 |    60 | 2024-10-02 12:27:34.742224
          9 |    90 | 2024-10-02 12:27:34.742224
         10 |   500 | 2024-10-02 12:27:34.742224
(10 rows)

```

# rolling back migrations

Now, what if we need to rollback our changes?

```
$ mvn liquibase:rollback -Dliquibase.rollbackCount=3 -Dliquibase.changeLogFile=db/liquibase-changelog.yml
...

[INFO] ####################################################
##   _     _             _ _                      ##
##  | |   (_)           (_) |                     ##
##  | |    _  __ _ _   _ _| |__   __ _ ___  ___   ##
##  | |   | |/ _` | | | | | '_ \ / _` / __|/ _ \  ##
##  | |___| | (_| | |_| | | |_) | (_| \__ \  __/  ##
##  \_____/_|\__, |\__,_|_|_.__/ \__,_|___/\___|  ##
##              | |                               ##
##              |_|                               ##
##                                                ## 
##  Get documentation at docs.liquibase.com       ##
##  Get certified courses at learn.liquibase.com  ## 
##                                                ##
####################################################
Starting Liquibase at 12:30:16 (version 4.29.2 #3683 built at 2024-08-29 16:45+0000)
[INFO] Set default schema name to public
[INFO] Parsing Liquibase Properties File src/main/resources/liquibase.yml for changeLog parameters
[INFO] Executing on Database: jdbc:postgresql://localhost:5432/orders
[WARNING] Potentially ignored key(s) in property file src/main/resources/liquibase.yml
 - 'outputChangeLogFile'
[INFO] Reading resource: db/changelog/1_create_inventory_table.yml
[INFO] Reading resource: db/changelog/2_seed_inventory_table.yml
[INFO] Reading resource: db/changelog/3_create_orders_table.yml
[INFO] Reading from databasechangelog
[INFO] Successfully acquired change log lock
[INFO] Reading from databasechangelog
[INFO] Rolling Back Changeset: db/changelog/2_seed_inventory_table.yml::seeds_inventory_table::tiago
[INFO] rollbackCount command encountered an exception.
[INFO] Successfully released change log lock
[INFO] Logging exception.
[INFO] ERROR: Exception Details
[INFO] ERROR: Exception Primary Class:  RollbackImpossibleException
[INFO] ERROR: Exception Primary Reason:  No inverse to liquibase.change.core.InsertDataChange created
[INFO] ERROR: Exception Primary Source:  4.29.2
[INFO] Command execution complete
[INFO] ------------------------------------------------------------------------
[INFO] BUILD FAILURE
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  0.985 s
[INFO] Finished at: 2024-10-02T12:30:17-03:00
[INFO] ------------------------------------------------------------------------
[ERROR] Failed to execute goal org.liquibase:liquibase-maven-plugin:4.27.0:rollback (default-cli) on project kafka-exactly-once-semantics: 
[ERROR] Error setting up or running Liquibase:
[ERROR] liquibase.exception.LiquibaseException: liquibase.exception.RollbackFailedException: liquibase.exception.RollbackImpossibleException: No inverse to liquibase.change.core.InsertDataChange created
[ERROR] -> [Help 1]
[ERROR] 
[ERROR] To see the full stack trace of the errors, re-run Maven with the -e switch.
[ERROR] Re-run Maven using the -X switch to enable full debug logging.
[ERROR] 
[ERROR] For more information about the errors and possible solutions, please read the following articles:
[ERROR] [Help 1] http://cwiki.apache.org/confluence/display/MAVEN/MojoExecutionException
```

We see the error `liquibase.exception.LiquibaseException: liquibase.exception.RollbackFailedException: liquibase.exception.RollbackImpossibleException: No inverse to liquibase.change.core.InsertDataChange created`. 

It occurs because [Liquibase](https://www.liquibase.com/) does not automatically know how to roll back insert operations. To enable rollback support, we need to provide explicit rollback instructions in the change set.

# adding rollback instruction to the seed migration

`2_seed_inventory_table.yml`:

```
databaseChangeLog:
  - changeSet:
      author: tiago
      id: "seeds_inventory_table"
      changes:
        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 1
              - column:
                  name: stock
                  valueNumeric: 100
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 2
              - column:
                  name: stock
                  valueNumeric: 50
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 3
              - column:
                  name: stock
                  valueNumeric: 200
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 4
              - column:
                  name: stock
                  valueNumeric: 75
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 5
              - column:
                  name: stock
                  valueNumeric: 120
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 6
              - column:
                  name: stock
                  valueNumeric: 30
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 7
              - column:
                  name: stock
                  valueNumeric: 250
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 8
              - column:
                  name: stock
                  valueNumeric: 60
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 9
              - column:
                  name: stock
                  valueNumeric: 90
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

        - insert:
            tableName: inventory
            columns:
              - column:
                  name: product_id
                  valueNumeric: 10
              - column:
                  name: stock
                  valueNumeric: 500
              - column:
                  name: last_updated
                  valueComputed: CURRENT_TIMESTAMP

      rollback:
        - delete:
            tableName: inventory

```

Now we have a `rollback` instruction, where we want to delete all contents from `inventory` table. Of course, you can add a `WHERE` clause to be more specific, like this:

```
rollback:
    - delete:
        tableName: inventory
        where: product_id IN (1, 2) 
```

Now we can issue the rollback command again and it will work:

```
$ mvn liquibase:rollback -Dliquibase.rollbackCount=3 -Dliquibase.changeLogFile=db/liquibase-changelog.yml
...

[INFO] ####################################################
##   _     _             _ _                      ##
##  | |   (_)           (_) |                     ##
##  | |    _  __ _ _   _ _| |__   __ _ ___  ___   ##
##  | |   | |/ _` | | | | | '_ \ / _` / __|/ _ \  ##
##  | |___| | (_| | |_| | | |_) | (_| \__ \  __/  ##
##  \_____/_|\__, |\__,_|_|_.__/ \__,_|___/\___|  ##
##              | |                               ##
##              |_|                               ##
##                                                ## 
##  Get documentation at docs.liquibase.com       ##
##  Get certified courses at learn.liquibase.com  ## 
##                                                ##
####################################################
Starting Liquibase at 12:34:34 (version 4.29.2 #3683 built at 2024-08-29 16:45+0000)
[INFO] Set default schema name to public
[INFO] Parsing Liquibase Properties File src/main/resources/liquibase.yml for changeLog parameters
[INFO] Executing on Database: jdbc:postgresql://localhost:5432/orders
[WARNING] Potentially ignored key(s) in property file src/main/resources/liquibase.yml
 - 'outputChangeLogFile'
[INFO] Reading resource: db/changelog/1_create_inventory_table.yml
[INFO] Reading resource: db/changelog/2_seed_inventory_table.yml
[INFO] Reading resource: db/changelog/3_create_orders_table.yml
[INFO] Reading from databasechangelog
[INFO] Successfully acquired change log lock
[INFO] Reading from databasechangelog
[INFO] Rolling Back Changeset: db/changelog/2_seed_inventory_table.yml::seeds_inventory_table::tiago
[INFO] Rolling Back Changeset: db/changelog/1_create_inventory_table.yml::creates_inventory_table::tiago
[INFO] Rollback command completed successfully.
[INFO] Successfully released change log lock
[INFO] Command execution complete
[INFO] ------------------------------------------------------------------------
[INFO] 
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  1.007 s
[INFO] Finished at: 2024-10-02T12:34:35-03:00
[INFO] ------------------------------------------------------------------------
```

And that's it. We can check in [Postgres](https://www.postgresql.org/) that all tables are gone:

```
$ psql -U postgres orders
psql (16.4 (Homebrew))
Type "help" for help.

orders=# \dt
                 List of relations
 Schema |         Name          | Type  |  Owner   
--------+-----------------------+-------+----------
 public | databasechangelog     | table | postgres
 public | databasechangeloglock | table | postgres
(2 rows)
```