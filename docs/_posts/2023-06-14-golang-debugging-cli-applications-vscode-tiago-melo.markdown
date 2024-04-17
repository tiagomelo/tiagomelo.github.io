---
layout: post
title:  "Golang: debugging CLI applications in VSCode"
date:   2023-06-14 13:26:01 -0300
categories: go vscode debug
---
![Golang: debugging CLI applications in VSCode](/assets/images/2023-06-14-4c053177-31f1-4b87-b2c8-d7a44dda2644/2023-06-14-banner.jpeg)

[VSCode](https://code.visualstudio.com/?trk=article-ssr-frontend-pulse_little-text-block), also known as Visual Studio Code, is a highly versatile and feature-rich code editor that has won the hearts of developers worldwide. With its clean and intuitive interface, it provides a delightful coding experience, making it a top choice for many professionals and enthusiasts alike.

[In a previous article of mine](https://www.linkedin.com/pulse/golang-configuring-useful-user-snippets-vscode-tiago-melo?trk=article-ssr-frontend-pulse_little-text-block) we saw how to configure useful user snippets. Now I want to explore its debugging capabilities.

In this short article we'll see how to debug a [CLI](https://en.wikipedia.org/wiki/Command-line_interface?trk=article-ssr-frontend-pulse_little-text-block) app written in [Golang](http://go.dev?trk=article-ssr-frontend-pulse_little-text-block).

## Sample CLI

Here's our very simple app which takes command line arguments:

cmd/main.go

```
package main

import (
    "fmt"
    "os"

    "github.com/jessevdk/go-flags"
)

var opts struct {
    Name  string `short:"n" long:"name" description:"name" required:"true"`
    Age   int    `short:"a" long:"age" description:"age" required:"true"`
    Email string `short:"e" long:"email" description:"email" required:"true"`
}

func run(args []string) {
    flags.ParseArgs(&opts, args)
    fmt.Printf("opts.Name: %v\n", opts.Name)
    fmt.Printf("opts.Age: %v\n", opts.Age)
    fmt.Printf("opts.Email: %v\n", opts.Email)
}

func main() {
    run(os.Args)
}

```

Once again, like I did [in this article about Golang, Kafka and MongoDB real time data processing](https://www.linkedin.com/pulse/real-time-data-processing-easily-10-million-messages-golang-melo?trk=article-ssr-frontend-pulse_little-text-block), I'm using [github.com/jessevdk/go-flags](https://github.com/jessevdk/go-flags?trk=article-ssr-frontend-pulse_little-text-block) instead of the core [flag](https://pkg.go.dev/flag?trk=article-ssr-frontend-pulse_little-text-block) package, since it has several advantages.

To run it, we do:

```
$ go run cmd/main.go --name Tiago --age 39 --email tiago@email.com
Name: Tiago
Age: 39
Email: tiago@email.com

```

Nice. Of course, we're not doing anything useful in this simple app. But what if we have a complex [CLI](https://en.wikipedia.org/wiki/Command-line_interface?trk=article-ssr-frontend-pulse_little-text-block) app and need to debug it?

## Debugging it

In [VSCode](https://code.visualstudio.com/?trk=article-ssr-frontend-pulse_little-text-block), click on "Run and Debug" and then "create a launch.json file":

![No alt text provided for this image](/assets/images/2023-06-14-4c053177-31f1-4b87-b2c8-d7a44dda2644/1686747846402.png)

Next, select "Go: Launch Package" option and hit enter:

![No alt text provided for this image](/assets/images/2023-06-14-4c053177-31f1-4b87-b2c8-d7a44dda2644/1686747931208.png)

Then, we'll replace the sample JSON with this one:

```
{
    // Use IntelliSense to learn about possible attributes.
    // Hover to view descriptions of existing attributes.
    // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Launch Package",
            "type": "go",
            "request": "launch",
            "mode": "auto",
            "program": "cmd/main.go",
            "args": [
                "--name",
                "Tiago",
                "--age",
                "39",
                "--email",
                "tiago@email.com"
            ]
        }
    ]
}
```

- program is the path to the file that contains the \`main\` function
- args is the string array where you pass the desired command line arguments

When you save it, the "Run and Debug" view will look like this:

![No alt text provided for this image](/assets/images/2023-06-14-4c053177-31f1-4b87-b2c8-d7a44dda2644/1686748194242.png)

Now let's come back to our \`cmd/main.go\` file and put a break point:

![No alt text provided for this image](/assets/images/2023-06-14-4c053177-31f1-4b87-b2c8-d7a44dda2644/1686748268173.png)

Similarly to other [IDEs](https://en.wikipedia.org/wiki/Integrated_development_environment?trk=article-ssr-frontend-pulse_little-text-block), you put a break point by double clicking on the left side of the line number.

Now, back to "Run and Debug" view, just click on the green play icon:

![No alt text provided for this image](/assets/images/2023-06-14-4c053177-31f1-4b87-b2c8-d7a44dda2644/1686748461325.png)

Then the debug little toolbar will be displayed enabling us to continue, step over, step into, step out, restart and stop the debugging session. We'll see the output in "debug console".
