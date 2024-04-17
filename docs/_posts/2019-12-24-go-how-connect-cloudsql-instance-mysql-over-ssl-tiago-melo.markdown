---
layout: post
title:  "Go: how to connect to a CloudSQL instance (MySQL) over SSL"
date:   2019-12-24 13:26:01 -0300
categories: go cloudsql mysql ssl
---
![Go: how to connect to a CloudSQL instance (MySQL) over SSL](/assets/images/2019-12-24-cfacf19e-1d43-48b8-820e-d4165f7a5c17/2019-12-24-banner.png)

If you read my [previous article](https://www.linkedin.com/pulse/tale-data-migration-moving-195m-records-from-aws-gcp-using-tiago-melo/), you've noticed that I connect to a [CloudSQL](https://cloud.google.com/sql/) instance (running [MySQL](https://www.linkedin.com/redir/general-malware-page?url=https%3A%2F%2Fwww%2emysql%2ecom%2F)) to load some [CSV](https://pt.wikipedia.org/wiki/Comma-separated_values) files into tables.

What if that instance, in particular, is configured to accept only secure connections ( [SSL](https://en.wikipedia.org/wiki/SSL))?

![No alt text provided for this image](/assets/images/2019-12-24-cfacf19e-1d43-48b8-820e-d4165f7a5c17/1577201313919.png)

We could connect to it using the MySQL client, after configuring [cloud\_sql\_proxy](https://cloud.google.com/sql/docs/mysql/sql-proxy), like this:

```
mysql -u <USER> -p -D <DATABASE> -h <HOST> --ssl-ca=<PATH/TO/server-ca.pem> --ssl-cert=<PATH/TO/client-cert.pem> --ssl-key=<PATH/TO/client-key.pem>

```

In this article, we'll see how to do the same in a [Go](https://golang.org/) script.

## The code

This is our file structure:

![No alt text provided for this image](/assets/images/2019-12-24-cfacf19e-1d43-48b8-820e-d4165f7a5c17/1577202572133.png)

- _ssl\_client\_certs:_ here we store the three _.pem_ files needed to connect over [SSL](https://en.wikipedia.org/wiki/SSL): _server-ca.pem_, _client-cert.pem_ and _client-key.pem;_
- _ping\_database.json_: this is the configuration file used in order to avoid hardcoded values in our source code;
- _ping\_database.go_: this is the [Go](https://golang.org/) script that will connect to our [CloudSQL](https://cloud.google.com/sql/) instance and try to [ping](https://en.wikipedia.org/wiki/Ping_(networking_utility)) it.

### Configuration file

_ping\_database.json_:

```
{
  "db": {
    "user": "<USER>",
    "pass": "<PASSWORD>",
    "schema": "<SCHEMA>",
    "port": "<PORT>",
    "host": "<HOST>",
    "timeout": "5s",
    "certs": {
      "clientCert": "<PATH/TO/client-cert.pem>",
      "clientKey": "<PATH/TO/client-key.pem",
      "serverCa": "<PATH/TO/server-ca.pem",
      "serverName": "<PROJECT>:<INSTANCE_NAME>"
    }
  }
}

```

### Go script

_ping\_database.go_:

```
/*
	This script shows how to connect to a CloudSQL instance over SSL.

	It reads json configuration filed named 'ping_database.json'.

	author: Tiago Melo (tiagoharris@gmail.com)
*/
package main

import (
	"crypto/tls"
	"crypto/x509"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/go-sql-driver/mysql"
	"io/ioutil"
	"os"
)

type Certs struct {
	ClientCert string `json: "clientCert"`
	ClientKey  string `json: "clientKey"`
	ServerCa   string `json: "serverCa"`
	ServerName string `json: "serverName"`
}

type Db struct {
	User    string `json: "user"`
	Pass    string `json: "pass"`
	Schema  string `json: "schema"`
	Port    string `json: "port"`
	Host    string `json: "host"`
	Timeout string `json: "timeout"`
	Certs   Certs  `json: "certs"`
}

type Config struct {
	Db Db `json: "db"`
}

var config = Config{}
var configJsonFileName = "ping_database.json"

func checkError(message string, err error) {
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v %v\n", message, err)
		os.Exit(1)
	}
}

func readConfiguration() {
	file, err := ioutil.ReadFile(configJsonFileName)

	checkError(fmt.Sprintf("Error reading file %s: ", configJsonFileName), err)

	err = json.Unmarshal([]byte(file), &config)

	checkError(fmt.Sprintf("File %s is not a valid JSON: ", configJsonFileName), err)
}

// To connect to a MySQL instance over SSL, three files are required:
// server-ca.pem, client-cert.pem and client-key.pem
//
// This function creates a TLS config under the name of 'custom'
func setupTLSConfig() {
	rootCertPool := x509.NewCertPool()
	pem, err := ioutil.ReadFile(config.Db.Certs.ServerCa)
	if err != nil {
		checkError(fmt.Sprintf("Failed to append PEM file %s: ", config.Db.Certs.ServerCa), err)
	}
	if ok := rootCertPool.AppendCertsFromPEM(pem); !ok {
		checkError(fmt.Sprintf("Failed to append PEM file %s: ", config.Db.Certs.ServerCa), errors.New("call to 'rootCertPool.AppendCertsFromPEM' failed"))
	}
	clientCert := make([]tls.Certificate, 0, 1)
	certs, err := tls.LoadX509KeyPair(config.Db.Certs.ClientCert, config.Db.Certs.ClientKey)
	if err != nil {
		checkError(fmt.Sprintf("Failed to load key par %s and %s: ", config.Db.Certs.ClientCert, config.Db.Certs.ClientKey), err)
	}
	clientCert = append(clientCert, certs)
	mysql.RegisterTLSConfig("custom", &tls.Config{
		RootCAs:      rootCertPool,
		Certificates: clientCert,
		ServerName:   config.Db.Certs.ServerName,
	})
}

func ping() {
	setupTLSConfig()

	fmt.Printf("Pinging database host %s... ", config.Db.Host)

	// Here we pass the TLS config created ('custom') and a timeout
	db, err := sql.Open("mysql", fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?tls=custom&timeout=%s", config.Db.User, config.Db.Pass, config.Db.Host, config.Db.Port, config.Db.Schema, config.Db.Timeout))

	defer db.Close()

	checkError("Error getting a handle to the database:", err)

	// Once that we get the handle, let's try to ping the database
	err = db.Ping()

	checkError("Error establishing a connection to the database:", err)

	fmt.Println("ok!")
}

func main() {
	readConfiguration()
	ping()
}

```

## Running it

In order to successfully connect to the CloudSQL instance, remember to:

1) get _server-ca.pem_, _client-cert.pem_ and _client-key.pem_ for the desired instance

![No alt text provided for this image](/assets/images/2019-12-24-cfacf19e-1d43-48b8-820e-d4165f7a5c17/1577203635138.png)

2) authorize your IP address:

![No alt text provided for this image](/assets/images/2019-12-24-cfacf19e-1d43-48b8-820e-d4165f7a5c17/1577203800982.png)

With everything in place, you should be able to ping the database:

```
$ go run ping_database.go

Pinging database host <DATABASE_HOST>... ok!

```

## Download the source

Here: [https://bitbucket.org/tiagoharris/cloudsql\_mysql\_ssl\_tutorial/src/master/](https://bitbucket.org/tiagoharris/cloudsql_mysql_ssl_tutorial/src/master/)
