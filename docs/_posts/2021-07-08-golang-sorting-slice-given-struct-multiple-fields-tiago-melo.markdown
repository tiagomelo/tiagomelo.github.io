---
layout: post
title:  "Golang: sorting a slice of a given struct by multiple fields"
date:   2021-07-08 13:26:01 -0300
categories: go sorting
---
![Golang: sorting a slice of a given struct by multiple fields](/assets/images/2021-07-08-fdbf3afb-5612-43e6-a588-0b8d5aaf56da/2021-07-08-banner.jpeg)

Sorting problems are often presented to candidates in code challenges. Usually the first attempt is to rollup your own sorting algorithm. But some companies want to evaluate your knowledge in a given programming language, encouraging you to use a built-in solution.

In this article I'll present a sorting challenge and walk you through my proposed solution.

## The problem

Imagine that you have a [CSV](https://en.wikipedia.org/wiki/Comma-separated_values?trk=article-ssr-frontend-pulse_little-text-block) file where each line is comprised of:

- name of the product
- sold quantity
- sold price

Like this:

```
"Selfie Stick,98,29"
"iPhone Case,90,15"
"Fire TV Stick,48,49"
"Wyze Cam,48,25"
"Water Filter,56,49"
"Blue Light Blocking Glasses,90,16"
"Ice Maker,47,119"
"Video Doorbell,47,199"
"AA Batteries,64,12"
"Disinfecting Wipes,37,12"
"Baseball Cards,73,16"
"Winter Gloves,32,112"
"Microphone,44,22"
"Pet Kennel,5,24"
"Jenga Classic Game,100,7"
"Ink Cartridges,88,45"
"Instant Pot,98,59"
"Hoze Nozzle,74,26"
"Gift Card,45,25"
"Keyboard,82,19"

```

You are requested to sort this product list, ranked from most popular and cheapest first to least popular and most expensive. If products are equally popular, sort by price (lower is better).

It means that, for example, "Wyze Cam", that sold 48 units for 25 dollars each must be ranked before of "Fire TV Stick", that sold 48 units as well, but for 49 dollars each.

To avoind dealing with I/O, The input will be provided in a hardcoded array, simulating [CSV](https://en.wikipedia.org/wiki/Comma-separated_values?trk=article-ssr-frontend-pulse_little-text-block) lines.

## Solution

Basically we need to:

- sort products by popularity (number of sold units)
- handle products with same popularity (same number of sold units); in that case, we want to sort by the lowest price.

Here's our directory structure:

![No alt text provided for this image](/assets/images/2021-07-08-fdbf3afb-5612-43e6-a588-0b8d5aaf56da/1625759860438.png)

item.go:

```
package item

import (
    "errors"
    "strconv"
    "strings"
)

// Item represents a sold item
type Item struct {
    Name         string
    SoldQuantity int
    SoldPrice    int
}

// BuildItemSlice builds a Item slice from a string array
// that simulates csv lines.
func BuildItemSlice(items_ []string) ([]Item, error) {
    var items []Item

    for _, v := range items_ {
        var item Item
        line := strings.Split(v, ",")

        if len(line) < 3 {
            return items, errors.New("missing attributes")
        }

        item.Name = line[0]

        if sq, err := strconv.Atoi(line[1]); err != nil {
            return items, err
        } else {
            item.SoldQuantity = sq
        }

        if sp, err := strconv.Atoi(line[2]); err != nil {
            return items, err
        } else {
            item.SoldPrice = sp
        }

        items = append(items, item)
    }
    return items, nil
}

```

The 'BuildItemSlice' function is a helper one that builds an array of strings into our custom struct 'Item'.

sorter.go:

```
package sorter

import (
    "sort"

    "bitbucket.org/tiagoharris/golang-sort-example/item"
)

// SortByPopularity sorts a slice of items by popularity.
// If products are equally popular, it sorts by the lowest price.
func SortByPopularity(items []item.Item) {

    sort.Slice(items, func(i, j int) bool {
        var sortedBySoldQuantity, sortedByLowerPrice bool

        // sort by sold quantity
        sortedBySoldQuantity = items[i].SoldQuantity > items[j].SoldQuantity

        // sort by lowest sold price
        if items[i].SoldQuantity == items[j].SoldQuantity {
            sortedByLowerPrice = items[i].SoldPrice < items[j].SoldPrice
            return sortedByLowerPrice
        }
        return sortedBySoldQuantity
    })
}

```

Here we're using the [sort.Slice function](https://pkg.go.dev/sort?utm_source=godoc#Slice&trk=article-ssr-frontend-pulse_little-text-block) that was introduced in [Golang](http://golang.org?trk=article-ssr-frontend-pulse_little-text-block) 1.8.

![No alt text provided for this image](/assets/images/2021-07-08-fdbf3afb-5612-43e6-a588-0b8d5aaf56da/1625760441360.png)

It takes an interface and a 'less' function as arguments. A 'less' function reports whether x\[i\] should be ordered before x\[j\]; and, according to our criteria,

- x\[i\] should be ordered before x\[j\] if it is more popular (sold quantity)
- x\[i\] should be ordered before x\[j\] if it is has the same popularity (sold quantity) and lower price (sold price)

main.go:

```
/*
Product Sorting
Write a program that sorts a list of comma-separated products, ranked from most popular and cheapest first to least popular and most expensive. For example "Selfie Stick,98,29", means that we sold 98 Selfie Stick at 29 dollars each. All numbers are integers. The input will be provided in a hardcoded array. No file I/O is needed.

The product are ranked in the following order:

By most popular
If products are equally popular, sort by price (lower is better)

Author: Tiago Melo (tiagoharris@gmail.com)
*/
package main

import (
    "fmt"

    "bitbucket.org/tiagoharris/golang-sort-example/item"
    "bitbucket.org/tiagoharris/golang-sort-example/sorter"
)

func main() {
    input := []string{
        "Selfie Stick,98,29",
        "iPhone Case,90,15",
        "Fire TV Stick,48,49",
        "Wyze Cam,48,25",
        "Water Filter,56,49",
        "Blue Light Blocking Glasses,90,16",
        "Ice Maker,47,119",
        "Video Doorbell,47,199",
        "AA Batteries,64,12",
        "Disinfecting Wipes,37,12",
        "Baseball Cards,73,16",
        "Winter Gloves,32,112",
        "Microphone,44,22",
        "Pet Kennel,5,24",
        "Jenga Classic Game,100,7",
        "Ink Cartridges,88,45",
        "Instant Pot,98,59",
        "Hoze Nozzle,74,26",
        "Gift Card,45,25",
        "Keyboard,82,19",
    }

    if output, err := run(input); err != nil {
        panic(err)
    } else {
        for _, v := range output {
            fmt.Printf("%s,%d,%d\n", v.Name, v.SoldQuantity, v.SoldPrice)
        }
    }
}

func run(input []string) ([]item.Item, error) {
    var items []item.Item

    items, err := item.BuildItemSlice(input)
    if err != nil {
        return items, err
    }

    sorter.SortByPopularity(items)
    return items, nil
}

```

## Running it

Here's the input as well the desired output:

![No alt text provided for this image](/assets/images/2021-07-08-fdbf3afb-5612-43e6-a588-0b8d5aaf56da/1625761183317.png)

Take a moment to check it. As you can see, products in 'output' are indeed ordered by popularity, and the ones with same popularity are ordered by lowest price first.

```
tiagomelo:~/develop/go/sort$ make run

Jenga Classic Game,100,7
Selfie Stick,98,29
Instant Pot,98,59
iPhone Case,90,15
Blue Light Blocking Glasses,90,16
Ink Cartridges,88,45
Keyboard,82,19
Hoze Nozzle,74,26
Baseball Cards,73,16
AA Batteries,64,12
Water Filter,56,49
Wyze Cam,48,25
Fire TV Stick,48,49
Ice Maker,47,119
Video Doorbell,47,199
Gift Card,45,25
Microphone,44,22
Disinfecting Wipes,37,12
Winter Gloves,32,112
Pet Kennel,5,24
```

Cool, isn't it?

## Unit tests

`item_test.go`

We need to test 'BuildItemSlice' function to be sure of its behavior:

{% raw %}
```
package item_test

import (
    "errors"
    "testing"

    "bitbucket.org/tiagoharris/golang-sort-example/item"
    "github.com/google/go-cmp/cmp"
)

func TestBuildItemSlice(t *testing.T) {
    tests := []struct {
        name          string
        items         []string
        expectedItems []item.Item
        expectedError error
    }{
        {
            name:          "happy path",
            items:         []string{"product 1,1,2", "product 2,4,5"},
            expectedItems: []item.Item{{"product 1", 1, 2}, {"product 2", 4, 5}},
        },
        {
            name:          "missing attributes",
            items:         []string{"product name"},
            expectedError: errors.New("missing attributes"),
        },
        {
            name:          "invalid sold quantity",
            items:         []string{"product name,invalid_qty,3"},
            expectedError: errors.New("strconv.Atoi: parsing \"invalid_qty\": invalid syntax"),
        },
        {
            name:          "invalid sold price",
            items:         []string{"product name,3,invalid_price"},
            expectedError: errors.New("strconv.Atoi: parsing \"invalid_price\": invalid syntax"),
        },
    }
    for _, test := range tests {
        t.Run(test.name, func(t *testing.T) {
            items, err := item.BuildItemSlice(test.items)
            if test.expectedError == nil {
                if err != nil {
                    t.Fatalf("expected err to be nil, got %v", err)
                }
            } else if err == nil {
                t.Fatal("expected err to be not nil")
            }
            if err != nil {
                if test.expectedError.Error() != err.Error() {
                    t.Fatalf("expected err to be '%v', got '%v'", test.expectedError.Error(), err.Error())
                }
            }
            if diff := cmp.Diff(test.expectedItems, items); diff != "" {
                t.Fatalf("(-want, +got)\n%s", diff)
            }
        })
    }
}

```
{% endraw %}

`sorter_test.go`

Finally, we are testing our sorting algorithm itself:

```
package sorter_test

import (
    "testing"

    "bitbucket.org/tiagoharris/golang-sort-example/item"
    "bitbucket.org/tiagoharris/golang-sort-example/sorter"
    "github.com/google/go-cmp/cmp"
)

func TestSortByPopularity(t *testing.T) {
    input := []string{
        "Selfie Stick,98,29",
        "iPhone Case,90,15",
        "Fire TV Stick,48,49",
        "Wyze Cam,48,25",
        "Water Filter,56,49",
        "Blue Light Blocking Glasses,90,16",
        "Ice Maker,47,119",
        "Video Doorbell,47,199",
        "AA Batteries,64,12",
        "Disinfecting Wipes,37,12",
        "Baseball Cards,73,16",
        "Winter Gloves,32,112",
        "Microphone,44,22",
        "Pet Kennel,5,24",
        "Jenga Classic Game,100,7",
        "Ink Cartridges,88,45",
        "Instant Pot,98,59",
        "Hoze Nozzle,74,26",
        "Gift Card,45,25",
        "Keyboard,82,19",
    }

    expectedOutput := []string{
        "Jenga Classic Game,100,7",
        "Selfie Stick,98,29",
        "Instant Pot,98,59",
        "iPhone Case,90,15",
        "Blue Light Blocking Glasses,90,16",
        "Ink Cartridges,88,45",
        "Keyboard,82,19",
        "Hoze Nozzle,74,26",
        "Baseball Cards,73,16",
        "AA Batteries,64,12",
        "Water Filter,56,49",
        "Wyze Cam,48,25",
        "Fire TV Stick,48,49",
        "Ice Maker,47,119",
        "Video Doorbell,47,199",
        "Gift Card,45,25",
        "Microphone,44,22",
        "Disinfecting Wipes,37,12",
        "Winter Gloves,32,112",
        "Pet Kennel,5,24",
    }

    inputItems, _ := item.BuildItemSlice(input)
    expectedOutputItems, _ := item.BuildItemSlice(expectedOutput)

    sorter.SortByPopularity(inputItems)

    if diff := cmp.Diff(expectedOutputItems, inputItems); diff != "" {
        t.Fatalf("(-want, +got)\n%s", diff)
    }
}

```

## Testing it

```

tiagomelo:~/develop/go/sort$ make test

?   	bitbucket.org/tiagoharris/golang-sort-example	[no test files]

=== RUN   TestBuildItemSlice

=== RUN   TestBuildItemSlice/happy_path

=== RUN   TestBuildItemSlice/missing_attributes

=== RUN   TestBuildItemSlice/invalid_sold_quantity

=== RUN   TestBuildItemSlice/invalid_sold_price

--- PASS: TestBuildItemSlice (0.00s)

    --- PASS: TestBuildItemSlice/happy_path (0.00s)

    --- PASS: TestBuildItemSlice/missing_attributes (0.00s)

    --- PASS: TestBuildItemSlice/invalid_sold_quantity (0.00s)

    --- PASS: TestBuildItemSlice/invalid_sold_price (0.00s)

PASS

ok  	bitbucket.org/tiagoharris/golang-sort-example/item	1.802s

=== RUN   TestSortByPopularity

--- PASS: TestSortByPopularity (0.00s)

PASS

ok  	bitbucket.org/tiagoharris/golang-sort-example/sorter	1.565s

```

## Meet go-cmp package

The [go-cmp](https://github.com/google/go-cmp?trk=article-ssr-frontend-pulse_little-text-block) package is my preferred solution for checking equality. It can check virtually everything: structs, arrays, maps, and so on.

You might have noticed that I'm making a diff in unit tests like this:

```
if diff := cmp.Diff(test.expectedItems, items); diff != "" {
     t.Fatalf("(-want, +got)\n%s", diff)
}

```

I'll mess up with a test input:

{% raw %}
```
{
    name:          "happy path",
    items:         []string{"product 1,1,2", "product 2,4,5"},
    expectedItems: []item.Item{{"alien product", 3, 2}, {"product 2", 4, 5}},
},

```
{% endraw %}

Running the test, it will show the differences:

```
tiagomelo:~/develop/go/sort$ make test

?   	bitbucket.org/tiagoharris/golang-sort-example	[no test files]

=== RUN   TestBuildItemSlice

=== RUN   TestBuildItemSlice/happy_path

    item_test.go:55: (-want, +got)

          []item.Item{

          	{

        - 		Name:         "alien product",

        + 		Name:         "product 1",

        - 		SoldQuantity: 3,

        + 		SoldQuantity: 1,

          		SoldPrice:    2,

          	},

          	{Name: "product 2", SoldQuantity: 4, SoldPrice: 5},

          }

```

## Download the source

Here: [https://bitbucket.org/tiagoharris/golang-sort-example/](https://bitbucket.org/tiagoharris/golang-sort-example/?trk=article-ssr-frontend-pulse_little-text-block)