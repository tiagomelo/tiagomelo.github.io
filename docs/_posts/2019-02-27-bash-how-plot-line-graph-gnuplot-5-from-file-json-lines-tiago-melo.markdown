---
layout: post
title:  "Bash: how to plot a line graph in Gnuplot 5 from a file with JSON lines"
date:   2019-02-27 13:26:01 -0300
categories: bash gnuplot json
---
![Bash: how to plot a line graph in Gnuplot 5 from a file with JSON lines](/assets/images/2019-02-27-40bae51c-7ae4-469c-a5e5-efca9880a881/2019-02-27-banner.jpeg)

Have you ever needed to plot a graph from a data file? Let's do it.

## Introduction

Sometimes in my career I had to plot graphs whether for application performance studies or to present business-related metrics to stakeholders, for example. And when I needed to do it for the very first time I was introduced to [Gnuplot](http://www.gnuplot.info/).

[Gnuplot](http://www.gnuplot.info/) is a free, command-driven, interactive, function and data plotting program, providing a relatively simple environment to make simple 2D plots.

In this article we'll see how to plot a line graph from a file that contains [JSON](https://www.json.org/) lines using a [bash](https://www.gnu.org/software/bash/) script.

## Context

You may encounter two different types of [JSON](https://www.json.org/) files in the wild: files with one large [JSON](https://www.json.org/) object, and so-called “ [JSON](https://www.json.org/) lines” files, which have multiple, separate [JSON](https://www.json.org/) objects each on one single line, not wrapped by '\[\]'

So, suppose that your company runs a batch program to process offers in a daily basis. After every execution, it writes useful metrics to a log file called 'metrics.log' like this:

```
{"executionTime":"2019-02-25T09:55:15.347+0000","insertedOffers":202,"updatedOffers":392,"deletedOffers":84}
{"executionTime":"2019-02-25T10:32:20.347+0000","insertedOffers":154,"updatedOffers":295,"deletedOffers":59}
{"executionTime":"2019-02-25T12:13:40.347+0000","insertedOffers":352,"updatedOffers":110,"deletedOffers":231}
{"executionTime":"2019-02-25T13:40:01.347+0000","insertedOffers":95,"updatedOffers":214,"deletedOffers":131}
{"executionTime":"2019-02-25T15:10:42.347+0000","insertedOffers":189,"updatedOffers":341,"deletedOffers":143}
{"executionTime":"2019-02-25T16:39:11.347+0000","insertedOffers":302,"updatedOffers":93,"deletedOffers":102}
{"executionTime":"2019-02-25T18:23:58.347+0000","insertedOffers":132,"updatedOffers":292,"deletedOffers":39}

```

Every line in the log is a [JSON](https://www.json.org/) object.

It would be nice to use this data to plot a graph, wouldn't it?

In order to accomplish this, let's convert these [JSON](https://www.json.org/) lines to a [CSV](https://pt.wikipedia.org/wiki/Comma-separated_values) file. Then we'll tell [Gnuplot](http://www.gnuplot.info/) to plot a graph from this file.

## Meet jq

Among several bash command line tools for converting [JSON](https://www.json.org/) to [CSV](https://pt.wikipedia.org/wiki/Comma-separated_values), [jq](https://stedolan.github.io/jq/) is one of the most popular and powerful.

Let's see how to convert our 'metrics.log' to a [CSV](https://pt.wikipedia.org/wiki/Comma-separated_values) file:

```
$ cat metrics.log | jq -r 'to_entries|map(.value)|@csv' | tr -d '"' > generated.csv

```

Here we are reading 'metrics.log', getting only the values of each key and invoking '@csv' function. Then we use the [tr command](https://en.wikipedia.org/wiki/Tr_(Unix)) to remove double-quotes so [Gnuplot](http://www.gnuplot.info/) can read the datetime values correctly. This is the resulting [CSV](https://pt.wikipedia.org/wiki/Comma-separated_values) file:

```
2019-02-25T09:55:15.347+0000,202,392,84
2019-02-25T10:32:20.347+0000,154,295,59
2019-02-25T12:13:40.347+0000,352,110,231
2019-02-25T13:40:01.347+0000,95,214,131
2019-02-25T15:10:42.347+0000,189,341,143
2019-02-25T16:39:11.347+0000,302,93,102
2019-02-25T18:23:58.347+0000,132,292,39

```

## The Gnuplot script

We'll invoke [Gnuplot](http://www.gnuplot.info/) with this script. I've used [ColorHexa](https://www.colorhexa.com/) to get the color hexadecimal codes.

```
##
# gnuplot script to generate a graphic.
#
# it expects two parameters:
#
# csv_file_path - path to the file from which the data will be read
# graphic_file_name - the graphic file name to be saved
#
# Author: Tiago Melo (tiagoharris@gmail.com)
##

# graphic will be saved as 800x600 png image file
set terminal png size 800,600

# setting the graphic file name to be saved
set output graphic_file_name

# allows grid lines to be drawn on the plot
set grid

# since the input file is a CSV file, we need to tell gnuplot that data fields are separated by comma
set datafile separator ","

# tells gnuplot that the values in X axis are date/time
set xdata time

# tells gnuplot the datetime format of the data present in the input file
# all datetime values are in ISO 8601 format. For example: "2019-02-25T09:55:15.347+0000"
set timefmt "%Y-%m-%dT%H:%M:%SZ"

# the graphic's main title
# we're appending the current date to it, in GMT-3 timezone
set title "Offer Metrics - ".strftime("%Y-%m-%d", time(0)-(3*3600))

# draws a box around the legends that we'll use...
set key box

# ... and place it in the upper right corner
set key right

# in the next three lines we are defining the style of the lines, where:
#
# lc - linecolor
# lt - linetype
# lw - linewidth
# pt - pointtype
# pt - pointinterval
# ps - pointsize
set style line 1 lc rgb '#4bd648' lt 1 lw 2 pt 7 pi -1 ps 1.5
set style line 2 lc rgb '#127ef3' lt 1 lw 2 pt 7 pi -1 ps 1.5
set style line 3 lc rgb '#e5532e' lt 1 lw 2 pt 7 pi -1 ps 1.5

# this is the command to actually generate the graphic file.
# the sintax is:
#
# plot <datafile> using <entry_in_file:entry_in_file> title <desired_title> with <plotting_style> ls <line_style>
#
# a line in the datefile has the following format, for example:
#
# 2019-02-25T09:55:15.347+0000,202,392,84
#
# the entry # 1 is a timestamp
# the entry # 2 is the number of new offers
# the entry # 3 is the number of updated offers
# the entry # 4 is the number of deleted offers
#
plot \
csv_file_path using 1:2 title 'New offers' with linespoints ls 1, \
csv_file_path using 1:3 title 'Updated offers' with linespoints ls 2, \
csv_file_path using 1:4 title 'Deleted offers' with linespoints ls 3
```

## The bash script

Now let's put it all together in a bash script that will generate the [CSV](https://pt.wikipedia.org/wiki/Comma-separated_values) file from our 'metrics.log' file and invoke [Gnuplot](http://www.gnuplot.info/) to plot the line graph using the generated file:

```
#!/usr/bin/env bash

##
# bash script that parses a JSON file to CSV (using jq) and plots a graphic (using gnuplot).
#
# Author: Tiago Melo (tiagoharris@gmail.com)
##

LOG_FILE="./metrics.log"
CSV_FILE="./generated.csv"
GNUPLOT_SCRIPT_FILE="./gnuplot_script.gp"
GNUPLOT_GRAPHIC_FILE="./offer_metrics.png"

function generateCsvFile {
  cat $LOG_FILE | jq -r 'to_entries|map(.value)|@csv' | tr -d '"' > $CSV_FILE
}

function generateGraphic {
  gnuplot -e "csv_file_path='$CSV_FILE'" -e "graphic_file_name='$GNUPLOT_GRAPHIC_FILE'" $GNUPLOT_SCRIPT_FILE
}

generateCsvFile
generateGraphic
exit

```

## It's show time!

Let's run it:

```
$ ./generate_offer_metrics.sh

```

Now open 'offer\_metrics.png' file:

![No alt text provided for this image](/assets/images/2019-02-27-40bae51c-7ae4-469c-a5e5-efca9880a881/1551242246173.png)

Pretty cool, isn't it?

## Conclusion

Through this simple example we learnt how to plot a line graph from a file with [JSON](https://www.json.org/) lines using Gnuplot. We saw:

- How to parse [JSON](https://www.json.org/) to [CSV](https://pt.wikipedia.org/wiki/Comma-separated_values);
- The basic instructions to generate a line graph in [Gnuplot](http://www.gnuplot.info/);
- How to invoke [Gnuplot](http://www.gnuplot.info/) passing command line arguments.

## Download the files

Here: [https://bitbucket.org/tiagoharris/bash-json-gnuplot-example/src/master/](https://bitbucket.org/tiagoharris/bash-json-gnuplot-example/src/master/)