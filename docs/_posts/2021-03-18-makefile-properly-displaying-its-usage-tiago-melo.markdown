---
layout: post
title:  "Makefile: properly displaying its usage"
date:   2021-03-18 13:26:01 -0300
categories: makefile
---
![Makefile: properly displaying its usage](/assets/images/2021-03-18-2b891bc4-66eb-4b72-bb49-2f8cb4cce367/2021-03-18-banner.png)

[Makefile](https://en.wikipedia.org/wiki/Makefile) is an awesome tool and I use it a lot, mainly in [Golang](https://golang.org/) projects. In this quick article we'll see how to display a useful help message with all targets that are available to be called.

## Motivation

If you're using [Makefile](https://en.wikipedia.org/wiki/Makefile) as your build tool to your project, chances are that you have several targets in there. Wouldn't it be nice to properly document its usage, so a new developer coming to your project knows what are the available targets and what are they're used for?

## Example

In real life, I have several targets in a [Makefile](https://en.wikipedia.org/wiki/Makefile) for a bunch of things in [Golang](https://golang.org/) projects:

- detecting any suspicious, abnormal, or useless code in the application;
- formatting the source code;
- setting up the local database;
- running [database migrations](https://www.linkedin.com/pulse/go-database-migrations-made-easy-example-using-mysql-tiago-melo/);
- building the app's binary;
- running the app;
- and so on.

So suppose this simple "hello world" app:

```
package main

import "fmt"

func main() {
	fmt.Println("Hey there!")
}

```

And this is the [Makefile](https://en.wikipedia.org/wiki/Makefile) we'll use to execute it:

```
.PHONY: help build run

## help: show this help message
help:
	@ echo "Usage: make [target]\n"
	@ sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

## go-vet: runs go vet ./...
go-vet:
	@ go vet ./...

## go-fmt: runs go fmt ./...
go-fmt:
	@ go fmt ./...

## build: builds the app's binary
build: go-vet go-fmt
	@ go build main.go

## run: runs the app
run: build

    @ ./main

```

Let's see what _help_ target does:

```
tiago:~/make-help-example$ make help

Usage: make [target]

  help     show this help message

  go-vet   runs go vet ./...

  go-fmt   runs go fmt ./...

  build    builds the app's binary

  run      runs the app

```

Pretty cool, isn't it? Now that we know what are the targets and what are they used for, let's run the app:

```
tiago:~/make-help-example$ make run

Hey there!

```

### Explaining it

For each target, just above it, we write a string that contains both target name and what it's used for:

```
## <target_name>: brief explanation of what it does

```

Next, as we can see [here](https://ftp.gnu.org/old-gnu/Manuals/make-3.80/html_node/make_17.html), the variable MAKEFILE\_LIST contains the list of Makefiles currently loaded or included. In our case, it contains all the content of our [Makefile](https://en.wikipedia.org/wiki/Makefile). Then, we'll use both [sed](https://en.wikipedia.org/wiki/Sed) and [column](https://man7.org/linux/man-pages/man1/column.1.html) to format the strings:

```
@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

```

1. using [sed](https://en.wikipedia.org/wiki/Sed) to remove '##' characters;
2. using [column](https://man7.org/linux/man-pages/man1/column.1.html) to remove ":" and format a table;
3. using [sed](https://en.wikipedia.org/wiki/Sed) again to ident the targets with one space.

## **Conclusion**

In this quick article we saw how we can use tools like [sed](https://en.wikipedia.org/wiki/Sed) and [column](https://man7.org/linux/man-pages/man1/column.1.html) to build a help for our [Makefile](https://en.wikipedia.org/wiki/Makefile).
