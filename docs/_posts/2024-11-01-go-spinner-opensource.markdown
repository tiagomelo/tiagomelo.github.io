---
layout: post
title:  "Open source project: go-spinner"
date:   2024-11-01 13:08:50 -0000
categories: opensource golang
image: "/assets/images/2024-11-01-go-spinner-opensource/banner.png"
---

![banner](/assets/images/2024-11-01-go-spinner-opensource/banner.png)

_check out my other open source projects [here](https://tiagomelo.info/opensource/)_

# go-spinner

[https://github.com/tiagomelo/go-spinner](https://github.com/tiagomelo/go-spinner)

`go-spinner` is a simple and customizable spinner component for CLI applications written in Go. It provides a visual indicator for long-running tasks, making your command-line tools more user-friendly.

## features

- customizable spinner character sets
- support for different output writers (e.g., `os.Stdout`, `os.Stderr`, `bytes.Buffer`)
- easy to integrate and use
- option to disable spinner for non-terminal outputs

## usage

### using the default configuration

```
package main

import (
	"fmt"
	"time"

	"github.com/tiagomelo/go-spinner"
)

func main() {
	sp := spinner.New("executing task 1...")
	sp.Start()
	time.Sleep(3 * time.Second)
	sp.Stop()
	sp = spinner.New("executing task 2...")
	sp.Start()
	time.Sleep(3 * time.Second)
	sp.Stop()
	fmt.Println("done")
}
```

output:

![default params](/assets/images/2024-11-01-go-spinner-opensource/defaultParams.gif)

### customizing it

```
func main() {
	sp := spinner.New("executing task 1...",
		spinner.WithClassicCharset(),
		spinner.WithConcludedChar("◆"),
		spinner.WithFrameRate(100*time.Millisecond),
	)
	sp.Start()
	time.Sleep(3 * time.Second)
	sp.Stop()

	sp = spinner.New("executing task 2...",
		spinner.WithCirclesCharset(),
		spinner.WithConcludedChar("★"),
		spinner.WithFrameRate(200*time.Millisecond),
	)
	sp.Start()
	time.Sleep(3 * time.Second)
	sp.Stop()

	// in this one we'll capture the output
	// to demonstrate the WithWriter option.
	// notice that in this case we're using a buffer,
	// so no animation will be displayed.
	var buf bytes.Buffer
	sp = spinner.New("executing task 3...",
		spinner.WithArrowsCharset(),
		spinner.WithConcludedChar("➜"),
		spinner.WithFrameRate(120*time.Millisecond),
		spinner.WithWriter(&buf),
	)
	sp.Start()
	time.Sleep(3 * time.Second)
	sp.Stop()
	fmt.Println("captured output for task 3:", buf.String())

	fmt.Println("done")
}
```

output:

![with params](/assets/images/2024-11-01-go-spinner-opensource/withParams.gif)

## available options

- `WithCharset`: sets the charset option for a spinner
- `WithClassicCharset`: sets the spinner to use the classic charset, `"|", "/", "-", "\\"` 
- `WithArrowsCharset`: sets the spinner to use the arrows charset, `"←", "↖", "↑", "↗", "→", "↘", "↓", "↙"` 
- `WithCirclesCharset`: sets the spinner to use the circles charset, `"◐", "◓", "◑", "◒"` 
- `WithBlocksCharset`: sets the spinner to use the blocks charset, `"▖", "▘", "▝", "▗"` 
- `WithConcludedChar`: sets the concludedChar option for a spinner 
- `WithFrameRate`: sets the frame rate option for a spinner
- `WithWriter`: sets the writer option for a spinner

## running unit tests

```
make test
```

## running linter

```
make linter
```
