---
layout: post
title:  "Go: Handling JSON in MySQL"
date:   2021-01-11 13:26:01 -0300
categories: go mysql json
---
![Go: Handling JSON in MySQL](/assets/images/2021-01-11-0fbfe62b-8d26-4bb7-bf58-ee3443f64f45/2021-01-11-banner.jpeg)

In this article, we'll see how to read/write [JSON](https://www.json.org/) data from/into a [MySQL](https://www.mysql.com/) table.

## Motivation

Sometimes you can find yourself in a situation where you'd like to use a hybrid approach: what if you could structure some parts of your database and leave others to be flexible?

Suppose we want to track the actions taken on a given website. We'll create a table called "events" to hold that information:

![No alt text provided for this image](/assets/images/2021-01-11-0fbfe62b-8d26-4bb7-bf58-ee3443f64f45/1610296547706.png)

- **id**: PK that uniquely identifies the event;
- **name**: event's name;
- **properties**: event's properties;
- **browser**: specification of the browser that visitors use to browse the website.

The [JSON](https://www.json.org/) datatype was introduced in [MySQL](https://www.mysql.com/) 5.7. This is the [DDL](https://en.wikipedia.org/wiki/Data_definition_language) for our table:

```
CREATE TABLE events(
  id int auto_increment primary key,
  name varchar(255),
  properties json,
  browser json
);

```

If we were to manually insert records, we could do it like this:

```
INSERT INTO events(event_name, properties, browser)
VALUES (
  'pageview',
   '{ "page": "/" }',
   '{ "name": "Safari", "os": "Mac", "resolution": { "x": 1920, "y": 1080 } }'
),
('pageview',
  '{ "page": "/contact" }',
  '{ "name": "Firefox", "os": "Windows", "resolution": { "x": 2560, "y": 1600 } }'
),
(
  'pageview',
  '{ "page": "/products" }',
  '{ "name": "Safari", "os": "Mac", "resolution": { "x": 1920, "y": 1080 } }'
),
(
  'purchase',
  '{ "amount": 200 }',
  '{ "name": "Firefox", "os": "Windows", "resolution": { "x": 1600, "y": 900 } }'
),
(
  'purchase',
  '{ "amount": 150 }',
  '{ "name": "Firefox", "os": "Windows", "resolution": { "x": 1280, "y": 800 } }'
),
(
  'purchase',
  '{ "amount": 500 }',
  '{ "name": "Chrome", "os": "Windows", "resolution": { "x": 1680, "y": 1050 } }'
);

```

To pull values out of the [JSON](https://www.json.org/) columns, we use the column [path operator](https://dev.mysql.com/doc/refman/5.7/en/json-search-functions.html#operator_json-column-path) ( [->](https://dev.mysql.com/doc/refman/5.7/en/json-search-functions.html#operator_json-column-path)). Let's play with browser's name:

```
SELECT id, browser->'$.name' browser
FROM events;

```

This query returns the following output:

```
+----+-----------+
| id | browser   |
+----+-----------+
|  1 | "Safari"  |
|  2 | "Firefox" |
|  3 | "Safari"  |
|  4 | "Firefox" |
|  5 | "Firefox" |
|  6 | "Chrome"  |
+----+-----------+
6 rows in set (0.00 sec)

```

Notice that data in the browser column is surrounded by quote marks. To remove the quote marks, we use the [inline path operator](https://dev.mysql.com/doc/refman/5.7/en/json-search-functions.html#operator_json-inline-path) ( [->>](https://dev.mysql.com/doc/refman/5.7/en/json-search-functions.html#operator_json-inline-path)) like this:

```
SELECT id, browser->>'$.name' browser
FROM events;

```

As we can see in the following output, the quote marks were removed:

```
+----+---------+
| id | browser |
+----+---------+
|  1 | Safari  |
|  2 | Firefox |
|  3 | Safari  |
|  4 | Firefox |
|  5 | Firefox |
|  6 | Chrome  |
+----+---------+
6 rows in set (0.00 sec)

```

As you've imagined, we can use the path operator like any other field type. For example, to get the browser usage, we can use the following statement:

```
SELECT browser->>'$.name' browser, count(browser)
FROM events
GROUP BY browser->>'$.name';

```

The output of the query is as follows:

```
+---------+----------------+
| browser | count(browser) |
+---------+----------------+
| Safari  |              2 |
| Firefox |              3 |
| Chrome  |              1 |
+---------+----------------+
3 rows in set (0.02 sec)

```

## The code

Now let's see how we can work with these [JSON](https://www.json.org/) fields in [Go](https://golang.org/), step by step.

First, let's define the struct we'll use to represent a record in "events" table:

```
type (
	StringInterfaceMap map[string]interface{}
	Event              struct {
		Id         int                `json:"id"`
		Name       string             `json:"name"`
		Properties StringInterfaceMap `json:"properties"`
		Browser    StringInterfaceMap `json:"browser"`
	}
)

```

Notice that in our "Event" struct, we defined both "Properties" and "Browser" as our [named type](https://golang.org/ref/spec#Type_identity) "StringInferfaceMap", which is map of string keys that can store pretty much any kind of information (int, string, other structs, and so on).

Next, let's create some variables to hold the SQL queries we'll use:

```
var (
	insertEventQuery = `INSERT INTO events(name, properties, browser) values (?, ?, ?)`
	selectEventByIdQuery = `SELECT * FROM events WHERE id = ?`
)

```

Now, the interesting part: how do we do to read the JSON columns? how do we persist them?

You're right: we need a way of customizing the way that "properties" and "browser" JSON columns are read and written. We could write some helper functions to do the work, but it wouldn't be a clean approach. What if we could use interfaces to come up with a cleaner design?

### The read operation

[Go](https://golang.org/) provides the [Scanner](https://golang.org/pkg/database/sql/#Scanner) interface to do the data type conversion while scanning.

The signature of the [Scanner](https://golang.org/pkg/database/sql/#Scanner) interface returns an error and not the converted value:

```
type Scanner interface {
  Scan(src interface{}) error
}

```

Thus, the implementor of this interface should have a [pointer receiver](https://tour.golang.org/methods/4) which will mutate its value upon successful conversion.

When implementing this interface, we need to convert the [uint8](https://golang.org/pkg/builtin/#uint8) slice into a [byte](https://golang.org/pkg/builtin/#byte) slice first, then we call [json.Unmarshal()](https://golang.org/pkg/encoding/json/#Unmarshal) so we can convert it in map\[string\]interface{}. If the conversion is successful, we need to assign the converted value to the receiver "StringInterfaceMap". Here's our full implementation:

```
func (m *StringInterfaceMap) Scan(src interface{}) error {
	var source []byte
	_m := make(map[string]interface{})

	switch src.(type) {
	case []uint8:
		source = []byte(src.([]uint8))
	case nil:
		return nil
	default:
		return errors.New("incompatible type for StringInterfaceMap")
	}
	err := json.Unmarshal(source, &_m)
	if err != nil {
		return err
	}
	*m = StringInterfaceMap(_m)
	return nil
}

```

Note that we are handling "null" values as well, as both columns are nullable. If that's the case, it will be translated as an empty map.

### **The write operation**

Like the [Scanner](https://golang.org/pkg/database/sql/#Scanner) interface, [Go](https://golang.org/) provides the [Valuer](https://golang.org/pkg/database/sql/driver/#Valuer) interface that we need to implement to do the type conversion. We first check if the map is empty; if it's the case, it will insert "null" into the respective column. Otherwise, it will call [json.Marshal()](https://golang.org/pkg/encoding/json/#Marshal) and do the appropriate conversion:

```
func (m StringInterfaceMap) Value() (driver.Value, error) {
	if len(m) == 0 {
		return nil, nil
	}
	j, err := json.Marshal(m)
	if err != nil {
		return nil, err
	}
	return driver.Value([]byte(j)), nil
}

```

This is the full source code:

```
package main

import (
	"database/sql"
	"database/sql/driver"
	"encoding/json"
	"errors"
	"fmt"

	_ "github.com/go-sql-driver/mysql"
)

type (
	StringInterfaceMap map[string]interface{}
	Event              struct {
		Id         int                `json:"id"`
		Name       string             `json:"name"`
		Properties StringInterfaceMap `json:"properties"`
		Browser    StringInterfaceMap `json:"browser"`
	}
)

var (
	insertEventQuery     = `INSERT INTO events(name, properties, browser) values (?, ?, ?)`
	selectEventByIdQuery = `SELECT * FROM events WHERE id = ?`
)

func (m StringInterfaceMap) Value() (driver.Value, error) {
	if len(m) == 0 {
		return nil, nil
	}
	j, err := json.Marshal(m)
	if err != nil {
		return nil, err
	}
	return driver.Value([]byte(j)), nil
}

func (m *StringInterfaceMap) Scan(src interface{}) error {
	var source []byte
	_m := make(map[string]interface{})

	switch src.(type) {
	case []uint8:
		source = []byte(src.([]uint8))
	case nil:
		return nil
	default:
		return errors.New("incompatible type for StringInterfaceMap")
	}
	err := json.Unmarshal(source, &_m)
	if err != nil {
		return err
	}
	*m = StringInterfaceMap(_m)
	return nil
}

func insertEvent(db *sql.DB, event Event) (int64, error) {
	res, err := db.Exec(insertEventQuery, event.Name, event.Properties, event.Browser)
	if err != nil {
		return 0, err
	}
	lid, err := res.LastInsertId()
	if err != nil {
		return 0, err
	}
	return lid, nil
}

func selectEventById(db *sql.DB, id int64, event *Event) error {
	row := db.QueryRow(selectEventByIdQuery, id)
	err := row.Scan(&event.Id, &event.Name, &event.Properties, &event.Browser)
	if err != nil {
		return err
	}
	return nil
}

func getDNSString(dbName, dbUser, dbPassword, conn string) string {
	return fmt.Sprintf("%s:%s@tcp(%s)/%s?parseTime=true&timeout=60s&readTimeout=60s",
		dbUser,
		dbPassword,
		conn,
		dbName)
}

func buildPropertiesData() map[string]interface{} {
	return map[string]interface{}{
		"page": "/",
	}
}

func buildBrowserData() map[string]interface{} {
	return map[string]interface{}{
		"name": "Safari",
		"os":   "Mac",
		"resolution": struct {
			X int `json:"x"`
			Y int `json:"y"`
		}{1920, 1080},
	}
}

func main() {
	dns := getDNSString("tutorial", "root", "tutorial", "localhost:3310")
	db, err := sql.Open("mysql", dns)
	if err != nil {
		panic(err)
	}
	err = db.Ping()
	if err != nil {
		panic(err)
	}
	defer db.Close()

	event := Event{
		Name:       "pageview",
		Properties: buildPropertiesData(),
		Browser:    buildBrowserData(),
	}

	insertedId, err := insertEvent(db, event)
	if err != nil {
		panic(err)
	}

	firstEvent := Event{}
	err = selectEventById(db, insertedId, &firstEvent)
	if err != nil {
		panic(err)
	}

	fmt.Println("\nEvent fields:\n")

	fmt.Println("Id:         ", firstEvent.Id)
	fmt.Println("Name:       ", firstEvent.Name)
	fmt.Println("Properties: ", firstEvent.Properties)
	fmt.Println("Browser:    ", firstEvent.Browser)

	fmt.Println("\nJSON representation:\n")

	j, err := json.Marshal(firstEvent)
	if err != nil {
		panic(err)
	}
	fmt.Println(string(j))
}

```

## **Running it**

If you've read my article about [database migrations in Go](https://www.linkedin.com/pulse/go-database-migrations-made-easy-example-using-mysql-tiago-melo/), you'll be familiar with the way I'm setting our [MySQL](https://www.mysql.com/) database, through [Docker Compose](https://docs.docker.com/compose/) and [golang-migrate](https://github.com/golang-migrate/migrate) tools.

To run it, let's issue "make run":

```
tiago:~/develop/go/articles/mysql-with-json$ make run

Setting up local MySQL...

Creating volume "mysql-with-json_db-data" with local driver

Creating db ... done

MySQL not ready, sleeping for 5 secs...

MySQL not ready, sleeping for 5 secs...

MySQL not ready, sleeping for 5 secs...

... MySQL is up and running!

Running migrations...

1/u events (42.932122ms)

Event fields:

Id:          1

Name:        pageview

Properties:  map[page:/]

Browser:     map[name:Safari os:Mac resolution:map[x:1920 y:1080]]

JSON representation:

{"id":1,"name":"pageview","properties":{"page":"/"},"browser {"name":"Safari","os":"Mac","resolution":{"x":1920,"y":1080}}}

```

- invoked docker-compose to setup our MySQL container;
- waited for it to be ready, and then migrated the database;
- inserted a sample event in "events" table;
- used the returned id from the inserted event to query it up;
- then we did the output for both fields and for the struct's [JSON](https://www.json.org/) representation.

Now let's check our table:

```
tiago:~/develop/go/articles/mysql-with-json$ docker ps

CONTAINER ID   IMAGE       COMMAND                  CREATED              STATUS              PORTS                                         NAMES

288d45771919   mysql:5.7   "docker-entrypoint.s…"   About a minute ago   Up About a minute   3310/tcp, 33060/tcp, 0.0.0.0:3310->3306/tcp   db

tiago:~/develop/go/articles/mysql-with-json$ docker exec -it db /bin/bash

root@288d45771919:/# mysql -uroot -p -D tutorial

Enter password:

Reading table information for completion of table and column names

You can turn off this feature to get a quicker startup with -A

Welcome to the MySQL monitor.  Commands end with ; or \g.

Your MySQL connection id is 6

Server version: 5.7.32 MySQL Community Server (GPL)

Copyright (c) 2000, 2020, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its

affiliates. Other names may be trademarks of their respective

owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> select * from events;

+----+----------+---------------+-----------------------------------------------------------------------+

| id | name     | properties    | browser                                                               |

+----+----------+---------------+-----------------------------------------------------------------------+

|  1 | pageview | {"page": "/"} | {"os": "Mac", "name": "Safari", "resolution": {"x": 1920, "y": 1080}} |

+----+----------+---------------+-----------------------------------------------------------------------+

1 row in set (0.00 sec)

```

- connected to our [MySQL](https://www.mysql.com/) container;
- used its mysql client to connect to the database;
- queried the table.

Pretty cool!

## **Running it in MySQL 5.6**

Since [MySQL](https://www.mysql.com/) 5.6 does not recognize the "json" datatype, all you need to do is to use the "text" type and it will work:

```
CREATE TABLE events(
  id int auto_increment primary key,
  name varchar(255),
  properties text,
  browser text
);

```

## Conclusion

In this article we saw how we can leverage the use of interfaces in [Go](https://golang.org/) so complex operations like reading/writing [JSON](https://www.json.org/) to a [MySQL](https://www.mysql.com/) table doesn't pollute our code.

## **Download the source**

Here: [https://bitbucket.org/tiagoharris/mysql-with-json](https://bitbucket.org/tiagoharris/mysql-with-json)