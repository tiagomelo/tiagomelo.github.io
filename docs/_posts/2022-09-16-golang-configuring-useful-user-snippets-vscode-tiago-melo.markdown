---
layout: post
title:  "Golang: configuring useful user snippets in VSCode"
date:   2022-09-16 13:26:01 -0300
categories: go vscode
---
![Golang: configuring useful user snippets in VSCode](/assets/images/2022-09-16-e08e94e2-b72a-4b4e-9080-21fbc46b458d/2022-09-16-banner.jpeg)

[VSCode](http:// Visual Studio Code - Code Editing. Redefinedhttps://code.visualstudio.com?trk=article-ssr-frontend-pulse_little-text-block) is my favorite IDE nowadays: simple, lightweight and versatile.

In this article I'll show how we can configure some useful user snippets in [VSCode](http:// Visual Studio Code - Code Editing. Redefinedhttps://code.visualstudio.com?trk=article-ssr-frontend-pulse_little-text-block) to make our life easier.

## Table driven tests snippet

Since I read this [Dave Cheney's article](https://dave.cheney.net/2019/05/07/prefer-table-driven-tests?trk=article-ssr-frontend-pulse_little-text-block), table driven tests has become my favorite way for writing tests in [Golang](http://golang.org?trk=article-ssr-frontend-pulse_little-text-block).

Here's an example for calculating [Fibonnaci](https://en.wikipedia.org/wiki/Fibonacci?trk=article-ssr-frontend-pulse_little-text-block) number:

{% raw %}
```
func TestRecursiveFibonacci(t *testing.T) {
    testCases := []struct {
        name string
        n    uint
        want uint
    }{
        {
            name: "zero",
            n:    0,
            want: 0,
        },
        {
            name: "one",
            n:    1,
            want: 1,
        },
        {
            name: "two",
            n:    2,
            want: 1,
        },
        {
            name: "three",
            n:    3,
            want: 2,
        },
    }
    for _, tc := range testCases {
        t.Run(tc.name, func(t *testing.T) {
            if got := RecursiveFibonacci(tc.n); got != tc.want {
                t.Errorf("got: %d, want: %d", got, tc.want)
            }
        })
    }
}
```
{% endraw %}

This is the output:

```

=== RUN   TestRecursiveFibonacci
=== RUN   TestRecursiveFibonacci/zero
=== RUN   TestRecursiveFibonacci/one
=== RUN   TestRecursiveFibonacci/two
=== RUN   TestRecursiveFibonacci/three
--- PASS: TestRecursiveFibonacci (0.00s)
    --- PASS: TestRecursiveFibonacci/zero (0.00s)
    --- PASS: TestRecursiveFibonacci/one (0.00s)
    --- PASS: TestRecursiveFibonacci/two (0.00s)
    --- PASS: TestRecursiveFibonacci/three (0.00s)
PASS
ok      bitbucket.org/tiagoharris/fibonacci/fibo    0.715s

```

It can be a bit boring writing this test structure everytime. That's where a predefined user snippets comes to help.

### Configuring a user code snippet in VSCode

Open up [VSCode](http://%20visual%20studio%20code%20-%20code%20editing.%20redefinedhttps//code.visualstudio.com?trk=article-ssr-frontend-pulse_little-text-block). If you're using macOS, hit command + shift + p and start typing "snippet":

![No alt text provided for this image](/assets/images/2022-09-16-e08e94e2-b72a-4b4e-9080-21fbc46b458d/1663359629031.png)

After pressing ENTER, type "go" and select "go.json":

![No alt text provided for this image](/assets/images/2022-09-16-e08e94e2-b72a-4b4e-9080-21fbc46b458d/1663359726224.png)

Then, ENTER again and it will open "go.json":

![No alt text provided for this image](/assets/images/2022-09-16-e08e94e2-b72a-4b4e-9080-21fbc46b458d/1663359810167.png)

Here's where we'll define a snippet for generating the table driven test basic structure:

{% raw %}
```
"Table driven test": {
        "prefix": "tabletest",
        "body": [
          "func Test${1:YourFunc}(t *testing.T) {",
          "\ttestCases := []struct{",
          "\t\tname string",
          "\t}{",
          "\t\t{",
          "\t\t\tname: \"happy path\",",
          "\t\t},",
          "\t}",
          "\tfor _, tc := range testCases {",
          "\t\tt.Run(tc.name, func(t *testing.T) {",
          "\t\t})",
          "\t}",
          "}"
        ],
        "description": "Create basic structure for a table driven test"
 }
```
{% endraw %}

- "Table driven test": a descritive name for our snippet;
- "prefix": how can we invoke this snippet. In our case, everytime we type "tabletest" in any golang file (\*.go), the structure will be written into it;
- "body": the snippet itself. I'm using '\\t' for tabbing. If you want to enter a new line, just type in '\\n';
- "func Test${1:YourFunc}(t \*testing.T) {": here I'm using "${1:YourFunc}" so the cursor will be positioned around "YourFunc";
- "description": a friendly description about this snippet.

### Invoking it

![No alt text provided for this image](/assets/images/2022-09-16-e08e94e2-b72a-4b4e-9080-21fbc46b458d/1663360353026.png)

When start typing "table", [VSCode](http://%20visual%20studio%20code%20-%20code%20editing.%20redefinedhttps//code.visualstudio.com?trk=article-ssr-frontend-pulse_little-text-block) will suggest our snippet. Press ENTER:

![No alt text provided for this image](/assets/images/2022-09-16-e08e94e2-b72a-4b4e-9080-21fbc46b458d/1663360443288.png)

Notice that the cursor is around "YourFunc", so you can type your test name right away.

## Main function snippet

Here's another snippet that I find useful: it defines a basic structure for a file with a main function:

{% raw %}
```
"Main Func": {
        "prefix": "mf",
        "body": [
          "package main\n",
          "import (",
          "\t\"fmt\"",
          "\t\"os\"",
          ")\n",
          "func run() error {",
          "\treturn nil",
          "}\n",
          "func main() {",
          "\tif err := run(); err != nil {",
          "\t\tfmt.Println(err)",
          "\t\tos.Exit(1)",
          "\t}",
          "}",
        ],
        "description": "Create basic structure for a script with main function"
}

```
{% endraw %}

### Invoking it

![No alt text provided for this image](/assets/images/2022-09-16-e08e94e2-b72a-4b4e-9080-21fbc46b458d/1663360685467.png)

Press "ENTER":

![No alt text provided for this image](/assets/images/2022-09-16-e08e94e2-b72a-4b4e-9080-21fbc46b458d/1663360739861.png)

Then a basic structure for a file with a main function will be written.

Our final "go.json" is the following:

{% raw %}
```
{
    "Table driven test": {
        "prefix": "tabletest",
        "body": [
          "func Test${1:YourFunc}(t *testing.T) {",
          "\ttestCases := []struct{",
          "\t\tname string",
          "\t}{",
          "\t\t{",
          "\t\t\tname: \"happy path\",",
          "\t\t},",
          "\t}",
          "\tfor _, tc := range testCases {",
          "\t\tt.Run(tc.name, func(t *testing.T) {",
          "\t\t})",
          "\t}",
          "}"
        ],
        "description": "Create basic structure for a table driven test"
    },
    "Main Func": {
        "prefix": "mf",
        "body": [
          "package main\n",
          "import (",
          "\t\"fmt\"",
          "\t\"os\"",
          ")\n",
          "func run() error {",
          "\treturn nil",
          "}\n",
          "func main() {",
          "\tif err := run(); err != nil {",
          "\t\tfmt.Println(err)",
          "\t\tos.Exit(1)",
          "\t}",
          "}",
        ],
        "description": "Create basic structure for a script with main function"
    }
}

```
{% endraw %}

Cool, isn't it?