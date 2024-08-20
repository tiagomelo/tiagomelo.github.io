---
layout: post
title:  "Golang: benchmarking made easy"
date:   2021-05-05 13:26:01 -0300
categories: go benchmark tests
---
![Golang: benchmarking made easy](/assets/images/2021-05-05-5f92c664-5beb-40ad-ad86-344b581c3d84/2021-05-05-banner.png)

Benchmarking your application is often a good idea when it comes for fine tuning its performance.

The [Golang](https://golang.org/) [testing](http://golang.org/pkg/testing/) package contains a benchmarking facility that can be used to examine the performance of your [Golang](https://golang.org/) code. In this article we'll see how to write simple benchmark tests that are able to provide us good insights about a given algorithmic solution.

## The good old Fibonacci number calculation

[Fibonacci number](https://en.wikipedia.org/wiki/Fibonacci_number) is a classic numerical series where each subsequent number is the sum of the previous two numbers: 1 1 2 3 5 8 13...

Let's explore two different implementations: recursive and sequential. We'll write both unit and benchmark tests for each approach and then we'll be able to compare them.

### Recursive approach

When you look at the [Fibonacci algorithm](https://en.wikipedia.org/wiki/Fibonacci_number), it seems to be very straightforward to implement in nearly any programming language. And probably the first approach to solve it is to use [recursion](https://en.wikipedia.org/wiki/Recursion_(computer_science)):

```
package fibo

func RecursiveFibonacci(n uint) uint {
    if n <= 1 {
        return n
    }
    return RecursiveFibonacci(n-1) + RecursiveFibonacci(n-2)

}

```

Each iteration in the series discards the previous results and then re-calculates the intermediate steps for each subsequent iteration.

Let's add some unit tests:

```
package fibo

import "testing"

func TestRecursiveFibonacci(t *testing.T) {
    data := []struct {
        n    uint
        want uint
    }{
        {0, 0},
        {1, 1},
        {2, 1},
        {3, 2},
        {4, 3},
        {5, 5},
        {6, 8},
        {10, 55},
        {42, 267914296},
    }
    for _, d := range data {
        if got := RecursiveFibonacci(d.n); got != d.want {
            t.Errorf("got: %d, want: %d", got, d.want)
        }
    }
}

```

It works:

```
tiago:~/develop/go/fibonacci/fibo$ go test -run TestRecursiveFibonacci
PASS
ok  	bitbucket.org/tiagoharris/fibonacci/fibo	1.875s

```

### Sequential approach

This alternative implementation removes the recursion and instead uses a simple for loop and a couple of variables. If you think about it, the algorithm is nothing but a sum of N numbers. We start from 0 and 1 and we will start adding subsequent sums:

```
package fibo

func SequentialFibonacci(n uint) uint {
    if n <= 1 {
        return uint(n)
    }
    var n2, n1 uint = 0, 1
    for i := uint(2); i < n; i++ {
        n2, n1 = n1, n1+n2
    }
    return n2 + n1
}

```

Let's add some unit tests:

```
func TestSequentialFibonacci(t *testing.T) {
    data := []struct {
        n    uint
        want uint
    }{
        {0, 0},
        {1, 1},
        {2, 1},
        {3, 2},
        {4, 3},
        {5, 5},
        {6, 8},
        {10, 55},
        {42, 267914296},
    }
    for _, d := range data {
        if got := SequentialFibonacci(d.n); got != d.want {
            t.Errorf("got: %d, want: %d", got, d.want)
        }
    }
}

```

It also works:

```
tiago:~/develop/go/fibonacci/fibo$ go test -run TestSequentialFibonacci
PASS
ok  	bitbucket.org/tiagoharris/fibonacci/fibo	0.631s

```

Notice that we’ve got a considerable performance improvement here; 0.631s versus 1.875s.

## Benchmarking

In order to measure performance, we could measure execution time and display it with some print statements, of course. But [Golang](http://golang.org) offers a very sophisticated tooling for benchmarking, and it's fairly simple to use.

Writing a benchmark is very similar to writing a test as they share the infrastructure from the testing package. Some of the key differences are:

- Benchmark functions start with ' _Benchmark_', not ' _Test_';
- Benchmark functions are run several times by the testing package. The value of 'b.N' will increase each time until the benchmark runner is satisfied with the stability of the benchmark;
- Each benchmark must execute the code under test b.N times. Thus, a 'for' loop will be present in every benchmark function.

Our final _fibo\_test.go_ file will contain both unit and benchmark tests:

```
package fibo

import (
    "testing"
)

func BenchmarkTestRecursiveFibonacci_10(b *testing.B) {
    for i := 0; i < b.N; i++ {
        RecursiveFibonacci(10)
    }
}

func BenchmarkTestRecursiveFibonacci_20(b *testing.B) {
    for i := 0; i < b.N; i++ {
        RecursiveFibonacci(20)
    }
}

func BenchmarkTestSequentialFibonacci_10(b *testing.B) {
    for i := 0; i < b.N; i++ {
        SequentialFibonacci(10)
    }
}

func BenchmarkTestSequentialFibonacci_20(b *testing.B) {
    for i := 0; i < b.N; i++ {
        SequentialFibonacci(20)
    }
}

func TestRecursiveFibonacci(t *testing.T) {
    data := []struct {
        n    uint
        want uint
    }{
        {0, 0},
        {1, 1},
        {2, 1},
        {3, 2},
        {4, 3},
        {5, 5},
        {6, 8},
        {10, 55},
        {42, 267914296},
    }
    for _, d := range data {
        if got := RecursiveFibonacci(d.n); got != d.want {
            t.Errorf("got: %d, want: %d", got, d.want)
        }
    }
}

func TestSequentialFibonacci(t *testing.T) {
    data := []struct {
        n    uint
        want uint
    }{
        {0, 0},
        {1, 1},
        {2, 1},
        {3, 2},
        {4, 3},
        {5, 5},
        {6, 8},
        {10, 55},
        {42, 267914296},
    }
    for _, d := range data {
        if got := SequentialFibonacci(d.n); got != d.want {
            t.Errorf("got: %d, want: %d", got, d.want)
        }
    }
}

```

We'll benchmark both recursive and sequential approaches by calculating the sequence for 10 and 20.

With benchmark tests in place, all we need to do is to invoke it via "go test -bench=.". By default, it runs using all the CPUs available. You can change like this: "go test -cpu=4 -bench=.".

My machine has 8 CPUs, as we can see by running [htop](https://htop.dev/):

![No alt text provided for this image](/assets/images/2021-05-05-5f92c664-5beb-40ad-ad86-344b581c3d84/1620223757682.png)

Lets run it:

```
tiago:~/develop/go/fibonacci/fibo$ go test -bench=.
goos: darwin
goarch: amd64
pkg: bitbucket.org/tiagoharris/fibonacci/fibo
cpu: Intel(R) Core(TM) i7-7820HQ CPU @ 2.90GHz
BenchmarkTestRecursiveFibonacci_10-8      3534949        335.2 ns/op
BenchmarkTestRecursiveFibonacci_20-8        28592      41587 ns/op
BenchmarkTestSequentialFibonacci_10-8    372993714          3.221 ns/op
BenchmarkTestSequentialFibonacci_20-8    193414836          6.175 ns/op
PASS
ok   bitbucket.org/tiagoharris/fibonacci/fibo 8.406s

```

The output format is:

```
Benchmark<test-name>-<number-of-cpus> number of executions speed of each operation

```

Now we can have a better idea of how the sequential approach is way more efficient than the recursive one:

- **BenchmarkTestRecursiveFibonacci10-8** was executed 3,534.949 times with a speed of 335.2 ns/op, while **BenchmarkTestSequentialFibonacci10-8** was executed 372,993.714 times with a speed of 3.221 ns/op;
- **BenchmarkTestRecursiveFibonacci20-8** was executed 28,592 times with a speed of 41730 ns/op, while **BenchmarkTestSequentialFibonacci20-8** was executed 193,414.836 times with a speed of 6.175 ns/op.

### Plotting graphics

I'm a huge fan of [gnuplot](http://www.gnuplot.info/). I've even written an [article](https://www.linkedin.com/pulse/bash-how-plot-line-graph-gnuplot-5-from-file-json-lines-tiago-melo/) showing how it can be useful.

This is the [gnuplot](http://www.gnuplot.info/) file that will be used to plot a [box graphic](http://gnuplot.sourceforge.net/docs_4.2/node241.html):

```
##
# gnuplot script to generate a performance graphic.
#
# it expects the following parameters:
#
# file_path - path to the file from which the data will be read
# graphic_file_name - the graphic file name to be saved
# y_label - the desired label for y axis
# y_range_min - minimum range for values in y axis
# y_range_max - maximum range for values in y axis
# column_1 - the first column to be used in plot command
# column_2 - the second column to be used in plot command
#
# Author: Tiago Melo (tiagoharris@gmail.com)
##

# graphic will be saved as 800x600 png image file
set terminal png

# allows grid lines to be drawn on the plot
set grid

# setting the graphic file name to be saved
set output graphic_file_name

# the graphic's main title
set title "performance comparison"

# since the input file is a CSV file, we need to tell gnuplot that data fields are separated by comma
set datafile separator ","

# disable key box
set key off

# label for y axis
set ylabel y_label

# range for values in y axis
set yrange[y_range_min:y_range_max]

# to avoid displaying large numbers in exponential format
set format y "%.0f"

# vertical label for x values
set xtics rotate

# set boxplots
set style fill solid
set boxwidth 0.5

# plot graphic for each line of input file
plot for [i=0:*] file_path every ::i::i using column_1:column_2:xtic(2) with boxes

```

This is the _benchmark_ target in our [Makefile](https://en.wikipedia.org/wiki/Make_(software)) that runs the benchmark tests and plot graphics for both number of operations and speed of each operation, so we can easily compare them:

```
benchmark:
    @ cd fibo ; \
    go test -bench=. | tee ../graphic/out.dat ; \
    awk '/Benchmark/{count ++; gsub(/BenchmarkTest/,""); printf("%d,%s,%s,%s\n",count,$$1,$$2,$$3)}' ../graphic/out.dat > ../graphic/final.dat ; \
    gnuplot -e "file_path='../graphic/final.dat'" -e "graphic_file_name='../graphic/operations.png'" -e "y_label='number of operations'" -e "y_range_min='000000000''" -e "y_range_max='400000000'" -e "column_1=1" -e "column_2=3" ../graphic/performance.gp ; \
    gnuplot -e "file_path='../graphic/final.dat'" -e "graphic_file_name='../graphic/time_operations.png'" -e "y_label='each operation in nanoseconds'" -e "y_range_min='000''" -e "y_range_max='45000'" -e "column_1=1" -e "column_2=4" ../graphic/performance.gp ; \
    rm -f ../graphic/out.dat ../graphic/final.dat ; \

echo "'graphic/operations.png' and 'graphic/time_operations.png' graphics were generated."

```

First, runs the benchmark tests using a [pipe](https://en.wikipedia.org/wiki/Pipeline_(Unix)) with [tee](https://en.wikipedia.org/wiki/Tee_(command)) command, which makes it possible to both display the output in the terminal & save it to a file.

Then, we use [awk](https://en.wikipedia.org/wiki/AWK) command to parse our file into a [CSV](https://en.wikipedia.org/wiki/Comma-separated_values) format that will be used to plot the graphics. It looks like this:

```
1,RecursiveFibonacci10-8,3521120,341.8
2,RecursiveFibonacci20-8,3524374,342.7
3,SequentialFibonacci10-8,366928228,3.278
4,SequentialFibonacci20-8,365811716,3.302

```

Next, we call [gnuplot](http://www.gnuplot.info/) two times: 1) generate graphic for number of executions 2) generate graphic for speed of each operation.

Let's run it:

```
tiago:~/develop/go/fibonacci$ make benchmark

goos: darwin

goarch: amd64

pkg: bitbucket.org/tiagoharris/fibonacci/fibo

cpu: Intel(R) Core(TM) i7-7820HQ CPU @ 2.90GHz

BenchmarkTestRecursiveFibonacci10-8    	 3521120	       341.8 ns/op

BenchmarkTestRecursiveFibonacci20-8    	 3524374	       342.7 ns/op

BenchmarkTestSequentialFibonacci10-8   	366928228	         3.278 ns/op

BenchmarkTestSequentialFibonacci20-8   	365811716	         3.302 ns/op

PASS

ok  	bitbucket.org/tiagoharris/fibonacci/fibo	8.519s

'graphic/operations.png' and 'graphic/time_operations.png' graphics were generated.

```

Awesome.

**Number of operations:**

![No alt text provided for this image](/assets/images/2021-05-05-5f92c664-5beb-40ad-ad86-344b581c3d84/1620463994125.png)

**Speed of each operation:**

![No alt text provided for this image](/assets/images/2021-05-05-5f92c664-5beb-40ad-ad86-344b581c3d84/1620464031301.png)

Pretty cool, isn't it?

## Bonus: calculation of large Fibonacci numbers

The first idea that comes to my mind would be to use 128-bit integer variable. Unfortunately, Go does not have one (yet). But even then, there is one of the [Fibonacci](https://en.wikipedia.org/wiki/Fibonacci) numbers that will not fit into 128-bit integer and we would need 256-bit integer and so on. Fortunately, Go has a package called [math/big](https://golang.org/pkg/math/big/) and its [Int](https://golang.org/pkg/math/big/#Int) type that will be very handy in this implementation:

```
func SequentialFibonacciBig(n uint) *big.Int {
    if n <= 1 {
        return big.NewInt(int64(n))
    }

    var n2, n1 = big.NewInt(0), big.NewInt(1)

    for i := uint(1); i < n; i++ {
        n2.Add(n2, n1)
        n1, n2 = n2, n1
    }

    return n1
}

```

To test it, here's our _main.go_ that accepts the desired number as a parameter:

```
package main

import (
    "flag"
    "fmt"

    "bitbucket.org/tiagoharris/fibonacci/fibo"
)

func main() {
    var n uint64
    flag.Uint64Var(&n, "n", 0, "n")
    flag.Parse()

    fmt.Printf("%d: %d\n", n, fibo.SequentialFibonacciBig(uint(n)))
}

```

And here's our target in [Makefile](https://en.wikipedia.org/wiki/Make_(software)) to run it:

```
## build: build app's binary
build:
    @ go build -a -installsuffix cgo -o main .

## run: run the app
run: build
    @ if [ -z "$(N)" ]; then echo >&2 please set the number via the variable N; exit 2; fi
    @ ./main -n $(N)

```

Let's run it for, say, 200:

```
tiago:~/develop/go/fibonacci$ make run N=200

200: 280571172992510140037611932413038677189525

```

## Conclusion

In this article we learned how to use [Golang](https://golang.org/) [testing](http://golang.org/pkg/testing/) benchmark utility and how to use [gnuplot](http://www.gnuplot.info/) to plot graphics for a better comparison.

## Download the source

Here: [https://bitbucket.org/tiagoharris/fibonacci/src/master/](https://bitbucket.org/tiagoharris/fibonacci/src/master/)