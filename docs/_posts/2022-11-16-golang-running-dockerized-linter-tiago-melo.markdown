---
layout: post
title:  "Golang: running a dockerized linter"
date:   2022-11-16 13:26:01 -0300
categories: go docker linter
---
![Golang: running a dockerized linter](/assets/images/2022-11-16-7c042d55-5c7f-45a4-8c48-564ba80c1593/2022-11-16-banner.jpeg)

Let's begin this article with [Wikipedia's definition for Linter](https://en.wikipedia.org/wiki/Lint_(software)?trk=article-ssr-frontend-pulse_little-text-block):

> Lint, or a linter, is a [static code analysis](https://en.wikipedia.org/wiki/Static_program_analysis?trk=article-ssr-frontend-pulse_little-text-block) tool used to flag programming errors, [bugs](https://en.wikipedia.org/wiki/Software_bug?trk=article-ssr-frontend-pulse_little-text-block), stylistic errors and suspicious constructs.

It is always a good idea to continuously submit your source code to a [Linter](https://en.wikipedia.org/wiki/Lint_(software)?trk=article-ssr-frontend-pulse_little-text-block). With that in mind, I'll show how we can use a [dockerized](http://docker.com?trk=article-ssr-frontend-pulse_little-text-block) one.

## Meet golangci-lint

[golangci-lint](https://github.com/golangci/golangci-lint?trk=article-ssr-frontend-pulse_little-text-block) is a fast Go linters runner. It runs linters in parallel, uses caching, supports yaml config, has integrations with all major IDE and has dozens of linters included.

It's often used both on local development and on [CI/CD systems](https://en.wikipedia.org/wiki/CI/CD?trk=article-ssr-frontend-pulse_little-text-block).

## Sample project

As you can see [here](https://golangci-lint.run/usage/linters/?trk=article-ssr-frontend-pulse_little-text-block), there are several supported [linters](https://en.wikipedia.org/wiki/Lint_(software)?trk=article-ssr-frontend-pulse_little-text-block). Some of them are enabled by default, while others can be enabled as you whish.

In this example we'll use:

- [asciicheck](https://github.com/tdakkota/asciicheck?trk=article-ssr-frontend-pulse_little-text-block)
- [godot](https://github.com/tetafro/godot?trk=article-ssr-frontend-pulse_little-text-block)
- [cyclop](https://github.com/bkielbasa/cyclop?trk=article-ssr-frontend-pulse_little-text-block)
- [gomnd](https://github.com/tommy-muehle/go-mnd?trk=article-ssr-frontend-pulse_little-text-block)

### Configuration

Following the [configuration instructions](https://golangci-lint.run/usage/configuration/?trk=article-ssr-frontend-pulse_little-text-block), here's our .golangci.yml:

```
linters:
  enable:
    - asciicheck
    - godot
    - cyclop
    - gomnd

linters-settings:
  cyclop:
    max-complexity: 5
```

### Some "bad" code

We have two packages: "packageone" and "packagetwo", both violating the [linters](https://en.wikipedia.org/wiki/Lint_(software)?trk=article-ssr-frontend-pulse_little-text-block) we enabled in our configuration:

packageone/packageone.go

{% raw %}
```
package packageone

import "fmt"

// NonAsciiIdentifier does nothing useful
func NonAsciiIdentifier() {
    你好 := 1
    fmt.Println(你好)
}
```
{% endraw %}

It violates:

- asciicheck
- godot

packagetwo/packagetwo.go

{% raw %}
```

package packagetwo

func uselessFunc() {

}

// ComplexFunction has a considerable high cyclomatic complexity
func ComplexFunction(a, b, c int) bool {
    var valid bool
    if a == b {
        if b > 2 {
            uselessFunc()
        } else if a == 2 {
            uselessFunc()
        } else {
            uselessFunc()
        }
    } else if b == c {
        for b == c {
            uselessFunc()
            b++
        }
    } else if c == a {
        for i := 0; i < 10; i++ {
            uselessFunc()
        }
    } else {
        switch a {
        case 7:
            uselessFunc()
        case 10:
            uselessFunc()
        case 13:
            uselessFunc()
        case 14:
            uselessFunc()
        default:
            uselessFunc()
        }
    }

    return valid
}
```
{% endraw %}

It violates:

- godot
- cyclop
- gomnd

### Running it

Here's our [Makefile](https://en.wikipedia.org/wiki/Make_(software)?trk=article-ssr-frontend-pulse_little-text-block) that enables us to run the dockerized linter for a single package or for all packages at once:

```

SHELL := /bin/bash

.PHONY: help
## help: shows this help message
help:
    @ echo "Usage: make [target]"
    @ sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

.PHONY: lint
## lint: runs linter for a given directory
lint:
    @ if [ -z "$(PACKAGE)" ]; then echo >&2 please set directory via variable PACKAGE; exit 2; fi
    @ docker run  --rm -v "`pwd`:/workspace:cached" -w "/workspace/$(PACKAGE)" golangci/golangci-lint:latest golangci-lint run

.PHONY: lint-all
## lint-all: runs linter for all packages
lint-all:
    @ docker run  --rm -v "`pwd`:/workspace:cached" -w "/workspace/." golangci/golangci-lint:latest golangci-lint run
```

Let's run it only for package "packagetwo":

{% raw %}
```

$ make lint PACKAGE=packagetwo

packagetwo.go:7:65: Comment should end in a period (godot)
// ComplexFunction has a considerable high cyclomatic complexity
                                                                ^
packagetwo.go:8:1: calculated cyclomatic complexity for function ComplexFunction is 13, max is 5 (cyclop)
func ComplexFunction(a, b, c int) bool {
^
packagetwo.go:29:8: mnd: Magic number: 7, in <case> detected (gomnd)
        case 7:
             ^
packagetwo.go:31:8: mnd: Magic number: 10, in <case> detected (gomnd)
        case 10:
             ^
packagetwo.go:33:8: mnd: Magic number: 13, in <case> detected (gomnd)
        case 13:
             ^
packagetwo.go:35:8: mnd: Magic number: 14, in <case> detected (gomnd)
        case 14:
             ^
packagetwo.go:11:10: mnd: Magic number: 2, in <condition> detected (gomnd)
        if b > 2 {
               ^
packagetwo.go:13:18: mnd: Magic number: 2, in <condition> detected (gomnd)
        } else if a == 2 {
                       ^
make: *** [lint] Error 1
```
{% endraw %}

Now for all packages:

{% raw %}
```

$ make lint-all

packagetwo/packagetwo.go:7:65: Comment should end in a period (godot)
// ComplexFunction has a considerable high cyclomatic complexity
                                                                ^
packageone/packageone.go:5:42: Comment should end in a period (godot)
// NonAsciiIdentifier does nothing useful
                                         ^
packageone/packageone.go:7:2: identifier "你好" contain non-ASCII character: U+4F60 '你' (asciicheck)
    你好 := 1
    ^
packagetwo/packagetwo.go:8:1: calculated cyclomatic complexity for function ComplexFunction is 13, max is 5 (cyclop)
func ComplexFunction(a, b, c int) bool {
^
packagetwo/packagetwo.go:29:8: mnd: Magic number: 7, in <case> detected (gomnd)
        case 7:
             ^
packagetwo/packagetwo.go:31:8: mnd: Magic number: 10, in <case> detected (gomnd)
        case 10:
             ^
packagetwo/packagetwo.go:33:8: mnd: Magic number: 13, in <case> detected (gomnd)
        case 13:
             ^
packagetwo/packagetwo.go:35:8: mnd: Magic number: 14, in <case> detected (gomnd)
        case 14:
             ^
packagetwo/packagetwo.go:11:10: mnd: Magic number: 2, in <condition> detected (gomnd)
        if b > 2 {
               ^
packagetwo/packagetwo.go:13:18: mnd: Magic number: 2, in <condition> detected (gomnd)
        } else if a == 2 {
                       ^
make: *** [lint-all] Error 1
```
{% endraw %}

Sweet.

## Download the source

Here: [https://bitbucket.org/tiagoharris/golangci-lint-example](https://bitbucket.org/tiagoharris/golangci-lint-example?trk=article-ssr-frontend-pulse_little-text-block)
