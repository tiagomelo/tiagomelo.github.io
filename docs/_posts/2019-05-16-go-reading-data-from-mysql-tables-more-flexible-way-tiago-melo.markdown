---
layout: post
title:  "Go: reading data from MySQL tables in a more flexible way"
date:   2019-05-16 13:26:01 -0300
categories: go mysql
---
![Go: reading data from MySQL tables in a more flexible way](/assets/images/2019-05-16-e3187e8a-1fcb-494a-ae2b-6074ebcbba68/2019-05-16-banner.png)

[In a previous article](https://www.linkedin.com/pulse/go-exporting-millions-records-from-mysql-table-csv-file-tiago-melo/), we read data from a given [MySQL](https://dev.mysql.com/) table and exported it to a [CSV file](https://pt.wikipedia.org/wiki/Comma-separated_values). In this article, I'll show a more generic approach to do it.

## Introduction

What if we wanted to write a [Go](https://golang.org/) script that takes a table name as an argument and export its data to a [CSV file](https://pt.wikipedia.org/wiki/Comma-separated_values)?

Let's recap how I did it on the [previous article](https://www.linkedin.com/pulse/go-exporting-millions-records-from-mysql-table-csv-file-tiago-melo/), focusing on the data retrieval from the [MySQL](https://dev.mysql.com/) table:

```
func main() {
	// these are the variables that will hold the data for each row in the table
	var (
		id           int
		name         string
		email        string
		phone_number string
		birth_date   time.Time
	)


	db, err := sql.Open("mysql", "root:@/spring_batch_example?parseTime=true")

	defer db.Close()

	checkError("Error getting a handle to the database", err)

	err = db.Ping()

	checkError("Error establishing a connection to the database", err)

	rows, err := db.Query("SELECT * FROM user")

	defer rows.Close()

	checkError("Error creating the query", err)

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

}

```

The interesting part to note is that in this particular example I'm creating some variables to hold the columns that I want to read from the table:

```
err := rows.Scan(&id, &name, &email, &phone_number, &birth_date)

```

Although it works well, it's a solution tailored to a _specific_ _table_. Let's see a more generic approach.

## The tables

Suppose we have a database called _csv\_example_ with two tables, _user_ and _book:_

```
CREATE TABLE  `user` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(50) NOT NULL,
  `email` varchar(50) NOT NULL,

  PRIMARY KEY  (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE  `book` (
  `id` int(11) NOT NULL auto_increment,
  `title` varchar(50) NOT NULL,
  `isbn` varchar(50) NOT NULL,

  PRIMARY KEY  (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

INSERT INTO user (name,email) VALUES ('Bruce Dickinson', 'bruce@ironmaiden.com');
INSERT INTO user (name,email) VALUES ('Steve Harris', 'steve@ironmaiden.com');
INSERT INTO user (name,email) VALUES ('Dave Murray', 'dave@ironmaiden.com');
INSERT INTO user (name,email) VALUES ('Janick Gers', 'janick@ironmaiden.com');
INSERT INTO user (name,email) VALUES ('Adrian Smith', 'adrian@ironmaiden.com');
INSERT INTO user (name,email) VALUES ('Nicko Mcbrain', 'nicko@ironmaiden.com');

INSERT INTO book (title,isbn) VALUES ('Book 1', 'ISBN1');
INSERT INTO book (title,isbn) VALUES ('Book 2', 'ISBN2');
INSERT INTO book (title,isbn) VALUES ('Book 3', 'ISBN3');
INSERT INTO book (title,isbn) VALUES ('Book 4', 'ISBN4');

```

## The code

This is our [Go](https://golang.org/) script. I've commented on the interesting parts so we can understand what's going on:

```
//  This Go script exports a given MySQL table data to a CSV file.
//
//  author: Tiago Melo (tiagoharris@gmail.com)

package main

import (
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
	"log"
	"fmt"
	"strings"
	"encoding/csv"
	"os"
	"path/filepath"
)

// helper function to handle errors
func checkError(message string, err error) {
	if err != nil {
		log.Fatal(message, err)
	}
}

// reads all records from a table
// returns a bidimensional array with the data read
func getLinesFromTable(tableName string) [][]string {
	// this is the slice that will be appended with rows from the table
	lines := make([][]string, 0)

	// sql.Open does not return a connection. It just returns a handle to the database.
	db, err := sql.Open("mysql", "root:@/csv_example")

	// A defer statement pushes a function call onto a list.
	// The list of saved calls is executed after the surrounding function returns.
	// Defer is commonly used to simplify functions that perform various clean-up actions.
	defer db.Close()

	checkError("Error getting a handle to the database", err)

	// Now it's time to validate the Data Source Name (DSN) to check if the connection
	// can be correctly established.
	err = db.Ping()

	checkError("Error establishing a connection to the database", err)

	rows, err := db.Query("SELECT * FROM " + tableName)

	defer rows.Close()

	checkError("Error creating the query", err)

	// Get column names
	columns, err := rows.Columns()
	if err != nil {
		checkError("Error getting columns from table", err)
	}

	// Make a slice for the values
	values := make([]sql.RawBytes, len(columns))

	// rows.Scan wants '[]interface{}' as an argument, so we must copy the
	// references into such a slice
	// See http://code.google.com/p/go-wiki/wiki/InterfaceSlice for details
	scanArgs := make([]interface{}, len(values))
	for i := range values {
		scanArgs[i] = &values[i]
	}

	// now let's loop through the table lines and append them to the slice declared above
	for rows.Next() {
		// read the row on the table
		// each column value will be stored in the slice
		err = rows.Scan(scanArgs...)

		checkError("Error scanning rows from table", err)

		var value string
		var line [] string

		for _, col := range values {
			// Here we can check if the value is nil (NULL value)
			if col == nil {
				value = "NULL"
			} else {
				value = string(col)
				line = append(line, value)
			}
		}

		lines = append(lines, line)
	}

	checkError("Error scanning rows from table", rows.Err())

	return lines
}

// writes all data from a bidimensional array into a csv file
// returns the absolute path of the written file
func writeLinesFromTableName(lines * [][]string, tableName string) string {
	fileName := tableName + ".csv"

	file, err := os.Create(fileName)

	defer file.Close()

	checkError("Error creating the file", err)

	writer := csv.NewWriter(file)
	defer writer.Flush()

	for _, value := range *lines {
		err := writer.Write(value)

		checkError("Error writing line to the file", err)
	}

	filePath, err := filepath.Abs(filepath.Dir(file.Name()))

	checkError("Error getting file path", err)

	filePath += "/" + fileName

	return filePath
}

func exportFromTable(tableName string) {
	fmt.Printf("\nExporting data from table \"%s\" ...", tableName)

	lines := getLinesFromTable(tableName)
	filePath := writeLinesFromTableName(&lines, tableName)

	fmt.Println("\nGenerated file:", filePath)
}

func main() {
	var tableName string

	fmt.Println("Enter the desired table name: ")

	fmt.Scan(&tableName)

	switch strings.ToLower(tableName) {
	case "user":
		exportFromTable(tableName)
	case "book":
		exportFromTable(tableName)
	default:
		fmt.Println("no such table:", tableName)
	}
}

```

This is the most interesting part for us:

```
// Get column names
columns, err := rows.Columns()
if err != nil {
	checkError("Error getting columns from table", err)
}

// Make a slice for the values
values := make([]sql.RawBytes, len(columns))

// rows.Scan wants '[]interface{}' as an argument, so we must copy the
// references into such a slice
// See http://code.google.com/p/go-wiki/wiki/InterfaceSlice for details
scanArgs := make([]interface{}, len(values))
for i := range values {
	scanArgs[i] = &values[i]
}

// now let's loop through the table lines and append them to the slice declared above
for rows.Next() {
	// read the row on the table
	// each column value will be stored in the slice
	err = rows.Scan(scanArgs...)

    // ommited
}

```

Taking the _user_ table as an example, let's dig in:

1. get all the column names from the table - store them in an array called _columns -_ in this case, it will be: \[id, name, email\]
2. create a [slice](https://tour.golang.org/moretypes/7) called _values_ with the same size of _columns_ to hold the corresponding column values - it's type is [sql.RawBytes](https://golang.org/pkg/database/sql/#RawBytes)
3. create another [slice](https://tour.golang.org/moretypes/7) called _scanArgs_ of type [interface{}](https://tour.golang.org/methods/14) and initialize it with references of the _values_ [slice](https://tour.golang.org/moretypes/7)
4. pass _scanArgs_ to [rows.Scan](https://golang.org/pkg/database/sql/#Row.Scan) with '...', since it's a [variadic function](https://gobyexample.com/variadic-functions)

## It's show time!

Let's run it.

First, let's export data from _user_ table:

![No alt text provided for this image](/assets/images/2019-05-16-e3187e8a-1fcb-494a-ae2b-6074ebcbba68/1558028925186.png)

This is the _user.csv_ file:

```
1,Bruce Dickinson,bruce@ironmaiden.com
2,Steve Harris,steve@ironmaiden.com
3,Dave Murray,dave@ironmaiden.com
4,Janick Gers,janick@ironmaiden.com
5,Adrian Smith,adrian@ironmaiden.com
6,Nicko Mcbrain,nicko@ironmaiden.com

```

Now let's export data from _book_ table:

![No alt text provided for this image](/assets/images/2019-05-16-e3187e8a-1fcb-494a-ae2b-6074ebcbba68/1558029132741.png)

This is the _book.csv_ file:

```
1,Book 1,ISBN1
2,Book 2,ISBN2
3,Book 3,ISBN3
4,Book 4,ISBN4

```

Pretty cool, isn't it?

## Conclusion

Through this simple example, we learned how to read data from a given [MySQL](https://dev.mysql.com/) in a more flexible way, without having to specify all it's fields to a [rows.Scan](https://golang.org/pkg/database/sql/#Row.Scan) call. We did it querying up the table's columns and creating auxiliary [slices](https://tour.golang.org/moretypes/7) to hold the data.

## Download the source

Here: [https://bitbucket.org/tiagoharris/exporting-to-csv-with-go-generic/src/master/](https://bitbucket.org/tiagoharris/exporting-to-csv-with-go-generic/src/master/)