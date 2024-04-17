---
layout: post
title:  "Go: exporting millions of records from a MySQL table to a CSV file - a comparison with a typical Java solution"
date:   2019-04-22 13:26:01 -0300
categories: go mysql
---
![Go: exporting millions of records from a MySQL table to a CSV file - a comparison with a typical Java solution](/assets/images/2019-04-22-2494642c-3f18-4d8a-bb68-1c56174bea1d/2019-04-22-banner.png)

[In a previous post](https://www.linkedin.com/pulse/spring-boot-batch-exporting-millions-records-from-mysql-tiago-melo/), I've shown how to export all table rows to a [CSV file](https://pt.wikipedia.org/wiki/Comma-separated_values) in [Java](https://www.java.com), using [MySQL](https://dev.mysql.com/), [Spring Boot](https://spring.io/projects/spring-boot) and [Spring Batch](https://spring.io/projects/spring-batch). This time I'll do the same using [Go](https://golang.org/).

## Introduction

I'm studying [Go](https://golang.org/) due to a new professional challenge in my career, and I'm really enjoying it.

Two of the most interesting premises of [Go](https://golang.org/) are simplicity and performance. Their authors wanted a high-performance programming language that was easy to program, unlike [C](https://en.wikipedia.org/wiki/C_(programming_language)) and [C++](https://en.wikipedia.org/wiki/C%2B%2B), which are more complex to tame.

In this article, I'll show how to export 10 million records of a [MySQL](https://dev.mysql.com/) table to a [CSV file](https://pt.wikipedia.org/wiki/Comma-separated_values) using [Go](https://golang.org/). We'll measure the time elapsed as well as CPU usage and memory consumption, in contrast to the [Java](https://www.java.com/) solution presented in my [previous post](https://www.linkedin.com/pulse/spring-boot-batch-exporting-millions-records-from-mysql-tiago-melo/).

## The code

This is our [Go](https://golang.org/) script. I've commented on the interesting parts so we can understand what's going on:

```
//  This Go script exports a MySQL table to a CSV file.
//
//  author: Tiago Melo (tiagoharris@gmail.com)

package main

import (
	"database/sql"
	"encoding/csv"
	_ "github.com/go-sql-driver/mysql"
	"log"
	"os"
	"strconv"
	"time"
)

func checkError(message string, err error) {
	if err != nil {
		log.Fatal(message, err)
	}
}

func main() {
	// these are the variables that will hold the data for each row in the table
	var (
		id           int
		name         string
		email        string
		phone_number string
		birth_date   time.Time
	)

	// sql.Open does not return a connection. It just returns a handle to the database.
	// passing 'parseTime=true' means that any DATE field on the table will be automatically
	// mapped to 'time.Time'.
	db, err := sql.Open("mysql", "root:@/spring_batch_example?parseTime=true")

	// A defer statement pushes a function call onto a list.
	// The list of saved calls is executed after the surrounding function returns.
	// Defer is commonly used to simplify functions that perform various clean-up actions.
	defer db.Close()

	checkError("Error getting a handle to the database", err)

	// Now it's time to validate the Data Source Name (DSN) to check if the connection
	// can be correctly established.
	err = db.Ping()

	checkError("Error establishing a connection to the database", err)

	rows, err := db.Query("SELECT * FROM user")

	defer rows.Close()

	checkError("Error creating the query", err)

	file, err := os.Create("result.csv")

	defer file.Close()

	checkError("Error creating the file", err)

	writer := csv.NewWriter(file)
	defer writer.Flush()

	// this is the slice that will be appended with rows from the table
	s := make([][]string, 0)

	// now let's loop through the table lines and append them to the slice declared above
	for rows.Next() {
		// read the row on the table; it has five fields, and here we are
		// assigning them to the variables declared above
		err := rows.Scan(&id, &name, &email, &phone_number, &birth_date)

		checkError("Error reading rows from the table", err)

		// appending the row data to the slice
		s = append(s, []string{strconv.Itoa(id), name, email, phone_number, birth_date.String()})
	}

	err = rows.Err()

	checkError("Error reading rows from the table", err)

	// now we loop through the slice and write the lines to CSV file
	for _, value := range s {
		err := writer.Write(value)

		checkError("Error writing line to the file", err)
	}
}

```

## It's show time!

Let's run it. We'll measure the time elapsed using the [time command](https://en.wikipedia.org/wiki/Time_(Unix)):

![No alt text provided for this image](/assets/images/2019-04-22-2494642c-3f18-4d8a-bb68-1c56174bea1d/1555816326590.png)

Wow. It took just **23 seconds** approximately. In contrast to [my Java solution](https://www.linkedin.com/pulse/spring-boot-batch-exporting-millions-records-from-mysql-tiago-melo/) which took **54 seconds** to do the same thing, we have a considerable gain of performance here.

This is an excerpt of the generated [CSV file](https://pt.wikipedia.org/wiki/Comma-separated_values):

```
...
1,name 1,email@email.com,99999999,1984-01-01 00:00:00 +0000 UTC
2,name 2,email@email.com,99999999,1984-01-01 00:00:00 +0000 UTC
3,name 3,email@email.com,99999999,1984-01-01 00:00:00 +0000 UTC
...

```

## Measuring CPU and memory usage

Now let's check the script's performance. I'm using [dstat](https://linux.die.net/man/1/dstat):

![No alt text provided for this image](/assets/images/2019-04-22-2494642c-3f18-4d8a-bb68-1c56174bea1d/1555785813884.png)

So, I've started [dstat](https://linux.die.net/man/1/dstat) a few seconds before the program execution and stopped it a few seconds after. A CSV file was generated; I've used this data to plot the graphs.

### CPU usage

![No alt text provided for this image](/assets/images/2019-04-22-2494642c-3f18-4d8a-bb68-1c56174bea1d/1555785946818.png)

### Memory consumption

![No alt text provided for this image](/assets/images/2019-04-22-2494642c-3f18-4d8a-bb68-1c56174bea1d/1555785976894.png)

Not bad, isn't it?

## TODO

One thing that I have to try a little bit more is about date manipulation in [Go](https://golang.org/). You see, I have a [DATE](https://dev.mysql.com/doc/refman/5.6/en/datetime.html) field on the [MySQL](https://dev.mysql.com/) table and, as we saw at the beginning, I've mapped it to [time.Time](https://golang.org/pkg/time/). So, I do not want time information, only the date - I'm still looking at how to do it.

## Download the source code

Here: [https://bitbucket.org/tiagoharris/exporting-to-csv-with-go/src/master/](https://bitbucket.org/tiagoharris/exporting-to-csv-with-go/src/master/)
