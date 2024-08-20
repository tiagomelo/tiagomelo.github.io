---
layout: post
title:  "Java: centralized logging with Spring Boot, Elasticsearch, Logstash and Kibana"
date:   2019-03-18 13:26:01 -0300
categories: java springboot elasticsearch logstash kibana
---
![Java: centralized logging with Spring Boot, Elasticsearch, Logstash and Kibana](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/2019-03-18-banner.png)

Logging is a crucial aspect of an application. And when we're dealing with a distributed environment, like [microservice architecture](https://en.wikipedia.org/wiki/Microservices) or having multiple instances running with the help of a [load balancer](https://en.wikipedia.org/wiki/Load_balancing_(computing)), centralized logging becomes a necessity.

In this article, we’ll see how to enable centralized logging in a typical [Spring Boot](https://spring.io/projects/spring-boot) with the [ELK stack](https://www.elastic.co/elk-stack), which is comprised of [Elasticsearch](https://www.elastic.co/), [Logstash](https://www.elastic.co/products/logstash) and [Kibana](https://www.elastic.co/products/kibana).

## Meet the ELK stack

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552867928885.png)

In a nutshell, this is how centralized logging works:

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552857764803.png)

The application will store logs into a log file. [Logstash](https://www.elastic.co/products/logstash) will read and parse the log file and ship log entries to an [Elasticsearch](https://www.elastic.co/) instance. Finally, we will use [Kibana](https://www.elastic.co/products/kibana) ( [Elasticsearch](https://www.elastic.co/) web frontend) to search and analyze the logs.

We'll use a [CRUD RESTful API](https://www.linkedin.com/pulse/spring-boot-example-crud-restful-api-global-exception-tiago-melo) from a previous post as the application.

To achieve this, we need to put several pieces together. Let's begin.

### Install Elasticsearch

Just follow the official instructions: [https://www.elastic.co/downloads/elasticsearch](https://www.elastic.co/downloads/elasticsearch)

After that, let's check if it's running:

```
curl -XGET http://localhost:9200

```

You should see an output similar to this:

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552858869172.png)

### Install Logstash

Just follow the official instructions: [https://www.elastic.co/downloads/logstash](https://www.elastic.co/downloads/logstash)

### Install Kibana

Finally, the last piece. Just follow the official instructions: [https://www.elastic.co/products/kibana](https://www.elastic.co/products/kibana)

Point your browser to [http://localhost:5601](http://localhost:5601/) (if Kibana page shows up, we’re good — we’ll configure it later).

### Configure Spring Boot

To have [Logstash](https://www.elastic.co/products/logstash) to ship logs to [Elasticsearch](https://www.elastic.co/), we need to configure our application to store logs into a file. All we need to do is to configure the log file name in ' _src/main/resources/application.yml_':

```
logging:
  file: application.log

```

And the log file will be automatically rotated on a daily basis.

### Configure Logstash to Understand Spring Boot’s Log File Format

Now comes the tricky part. We need to create [Logstash](https://www.elastic.co/products/logstash) config file.

Typical [Logstash](https://www.elastic.co/products/logstash) config file consists of three main sections: _input_, _filter_ and _output_:

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552867983343.png)

Each section contains plugins that do relevant part of the processing (such as file input plugin that reads log events from a file or [Elasticsearch](https://www.elastic.co/) output plugin which sends log events to [Elasticsearch](https://www.elastic.co/)).

We'll create a file called _'logstash.conf'_ that will be used in [Logstash](https://www.elastic.co/products/logstash) initialization that will be showed soon. It will be placed under _'src/main/resources'_ directory.

Let's dig in each section.

**Input section**

It defines from where [Logstash](https://www.elastic.co/products/logstash) will read input data.

This is the _input_ section:

```
input {
  file {
    type => "java"
    path => "/home/tiago/desenv/java/crud-exceptionhandling-example/application.log"
    codec => multiline {
      pattern => "^%{YEAR}-%{MONTHNUM}-%{MONTHDAY} %{TIME}.*"
      negate => "true"
      what => "previous"
    }
  }
}

```

Explanation:

1) We're using _file_ plugin

2) _type_ is set to _java_ \- it's just an additional piece of metadata in case you will use multiple types of log files in the future

3) _path_ is the absolute path to the log file. It must be absolute - [Logstash](https://www.elastic.co/products/logstash) is picky about this

4) We're using _multiline_ _codec_, which means that multiple lines may correspond to a single log event

5) In order to detect lines that should logically be grouped with a previous line we use a detection pattern:

5.1) _pattern_ =\> _"^%{YEAR}-%{MONTHNUM}-%{MONTHDAY} %{TIME}.\*"_: Each new log event needs to start with date

5.2) _negate => "true"_: if it doesn't start with a date...

5.3) _what => "previous"_ → ...then it should be grouped with a previous line.

_File_ input plugin, as configured, will tail the log file (e.g. only read new entries at the end of the file). Therefore, when testing, in order for Logstash to read something you will need to generate new log entries.

**Filter section**

It contains plugins that perform intermediary processing on a log event. In our case, event will either be a single log line or multiline log event grouped according to the rules described above.

In the filter section we will do:

- Tag a log event if it contains a stacktrace. This will be useful when searching for exceptions later on
- Parse out (or _grok_, in [Logstash](https://www.elastic.co/products/logstash) terminology) timestamp, log level, pid, thread, class name (logger actually) and log message
- Specified timestamp field and format - [Kibana](https://www.elastic.co/products/kibana) will use that later for time-based searches

This is the _filter_ section:

```
filter {
  #If log line contains tab character followed by 'at' then we will tag that entry as stacktraceif [message] =~ "\tat" {
    grok {
      match => ["message", "^(\tat)"]
      add_tag => ["stacktrace"]
    }
  }

  #Grokking Spring Boot's default log format
  grok {
    match => [ "message",
               "(?<timestamp>%{YEAR}-%{MONTHNUM}-%{MONTHDAY} %{TIME})  %{LOGLEVEL:level} %{NUMBER:pid} --- \[(?<thread>[A-Za-z0-9-]+)\] [A-Za-z0-9.]*\.(?<class>[A-Za-z0-9#_]+)\s*:\s+(?<logmessage>.*)",
               "message",
               "(?<timestamp>%{YEAR}-%{MONTHNUM}-%{MONTHDAY} %{TIME})  %{LOGLEVEL:level} %{NUMBER:pid} --- .+? :\s+(?<logmessage>.*)"
             ]
  }

  #Parsing out timestamps which are in timestamp field thanks to previous grok section
  date {
    match => [ "timestamp" , "yyyy-MM-dd HH:mm:ss.SSS" ]
  }
}

```

Explanation:

1) _if \[message\] =~ "\\tat"_: if message contains _tab_ character followed by _at_ then...

2) ... use _grok_ plugin to tag stacktraces:

- _match => \["message", "^(\\tat)"\]:_ when _message_ matches beginning of the line followed by _tab_ followed by _at_ then...
- _add\_tag => \["stacktrace"\]_: ... tag the event with stacktrace tag

3) Use _grok_ plugin for regular [Spring Boot](https://spring.io/projects/spring-boot) log message parsing:

- First pattern extracts timestamp, level, pid, thread, class name (this is actually logger name) and the log message.
- Unfortunately, some log messages don't have logger name that resembles a class name (for example, Tomcat logs) hence the second pattern that will skip the logger/class field and parse out timestamp, level, pid, thread and the log message.

4) Use _date_ plugin to parse and set the event date:

- _match => \[ "timestamp" , "yyyy-MM-dd HH:mm:ss.SSS" \]_: timestamp field (grokked earlier) contains the timestamp in the specified format

**Output section**

It contains output plugins that send event data to a particular destination. Outputs are the final stage in the event pipeline. We will be sending our log events to stdout (console output, for debugging) and to [Elasticsearch](https://www.elastic.co/).

This is the _output_ section:

```
output {
  # Print each event to stdout, useful for debugging. Should be commented out in production.# Enabling 'rubydebug' codec on the stdout output will make logstash# pretty-print the entire event as something similar to a JSON representation.
  stdout {
    codec => rubydebug
  }

  # Sending properly parsed log events to elasticsearch
  elasticsearch {
    hosts=>["localhost:9200"]
    index=>"logstash-%{+YYYY.MM.dd}"
  }
}

```

Explanation:

1) We are using multiple outputs: _stdout_ and _elasticsearch_.

2) _stdout { ... }:_ stdout plugin prints log events to standard output (console)

- _codec => rubydebug:_ pretty print events using JSON-like format

3) _elasticsearch { ... }: elasticsearch_ plugin sends log events to [Elasticsearch](https://www.elastic.co/) server.

- _hosts => \["localhost:9200"\]:_ hostname where [Elasticsearch](https://www.elastic.co/) is located - in our case, localhost
- _index=>"logstash-%{+YYYY.MM.dd}"_: the [index](https://www.elastic.co/blog/what-is-an-elasticsearch-index) in [Elasticsearch](https://www.elastic.co/) for which the data will be streamed to. You can name it with your application's name if you want.

**Putting it all together**

Finally, the three parts - _input_, _filter_ and _output_ \- need to be copy-pasted together and saved into _logstash.conf_ config file. Once the config file is in place and [Elasticsearch](https://www.elastic.co/) is running, we can run [Logstash](https://www.elastic.co/products/logstash):

```
$ /path/to/logstash/bin/logstash -f src/main/resources/logstash.conf

```

If everything went well, [Logstash](https://www.elastic.co/products/logstash) is now shipping log events to [Elasticsearch](https://www.elastic.co/). It may take a while before presenting an output like this:

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552871324805.png)

Notice these lines:

```
[INFO ] 2019-03-17 17:44:18.226 [[main]-pipeline-manager] elasticsearch - New Elasticsearch output {:class=>"LogStash::Outputs::ElasticSearch", :hosts=>["//localhost:9200"]}
[INFO ] 2019-03-17 17:44:18.249 [Ruby-0-Thread-5: :1] elasticsearch - Using mapping template from {:path=>nil}
[INFO ] 2019-03-17 17:44:18.271 [Ruby-0-Thread-5: :1] elasticsearch - Attempting to install template {:manage_template=>{"template"=>"logstash-*", "version"=>60001, "settings"=>{"index.refresh_interval"=>"5s"}, "mappings"=>{"_default_"=>{"dynamic_templates"=>[{"message_field"=>{"path_match"=>"message", "match_mapping_type"=>"string", "mapping"=>{"type"=>"text", "norms"=>false}}}, {"string_fields"=>{"match"=>"*", "match_mapping_type"=>"string", "mapping"=>{"type"=>"text", "norms"=>false, "fields"=>{"keyword"=>{"type"=>"keyword", "ignore_above"=>256}}}}}], "properties"=>{"@timestamp"=>{"type"=>"date"}, "@version"=>{"type"=>"keyword"}, "geoip"=>{"dynamic"=>true, "properties"=>{"ip"=>{"type"=>"ip"}, "location"=>{"type"=>"geo_point"}, "latitude"=>{"type"=>"half_float"}, "longitude"=>{"type"=>"half_float"}}}}}}}}
[INFO ] 2019-03-17 17:44:18.585 [[main]-pipeline-manager] file - No sincedb_path set, generating one based on the "path" setting {:sincedb_path=>"/usr/share/logstash/data/plugins/inputs/file/.sincedb_97bb92ea0ae35e33de7cca814bc912c7", :path=>["/home/tiago/desenv/java/crud-exceptionhandling-example/application.log"]}

```

Seems that an index called ' _logstash-\*'_ was created and the log file ' _/home/tiago/desenv/java/crud-exceptionhandling-example/application.log'_ was correctly located.

Let's check if the index was really created at [Elasticsearch](https://www.elastic.co/) by this command:

```
~$ curl -X GET "localhost:9200/_cat/indices?v"

```

And this is the output. It was created as expected:

```
health status index               uuid                   pri rep docs.count docs.deleted store.size pri.store.size
yellow open   logstash-2019.03.17 ReyKaZpgRq659xiNXWcUiw   5   1         77            0    234.5kb        234.5kb
green  open   .kibana_1           o-dbTdTZTu-MGR3ECzPteg   1   0          4            0     19.7kb         19.7kb

```

### Configure Kibana

Let's open [Kibana](https://www.elastic.co/products/kibana) UI at [http://localhost:5601](http://localhost:5601/). Click on _'Management':_

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552872388417.png)

Now click on _'Index Patterns'_ under _'Kibana'_:

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552872529940.png)

And here we put the name of the index that was created in [Elasticsearch](https://www.elastic.co/): ' _logstash-\*'._ Then, hit 'Next step':

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552872996991.png)

Now we choose _'@timestamp'_ as the field to filter data by time and then hit _'Create index pattern'_:

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552872937808.png)

## It's show time!

Let's launch the application and perform some operations in order to generate some data. Then we'll check them later using the [Kibana](https://www.elastic.co/products/kibana) UI.

Fire up the server:

```
$ mvn spring-boot:run

```

So, as mentioned earlier, our app is a [CRUD RESTful API](https://www.linkedin.com/pulse/spring-boot-example-crud-restful-api-global-exception-tiago-melo) from a previous article.

Let's call the endpoint that lists all students. In the controller we have:

```
private static final Logger LOGGER = LoggerFactory.getLogger(StudentController.class);

/**
 * Get all students
 *
 * @return the list of students
 */
@GetMapping("/students")
public List<StudentDTO> getAllStudents() {
  List<Student> students = service.findAll();

  LOGGER.info(String.format("getAllStudents() returned %s records", students.size()));

  return students.stream().map(student -> convertToDTO(student)).collect(Collectors.toList());
}

```

Let's call it:

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552873622767.png)

In the server's log we have:

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552875833020.png)

And if we take a look at what's going on with [Logstash](https://www.elastic.co/products/logstash), we see that it was captured:

```
{
          "path" => "/home/tiago/desenv/java/crud-exceptionhandling-example/application.log",
          "host" => "tiagomelo",
           "pid" => "22174",
         "class" => "StudentController",
       "message" => "2019-03-17 23:14:58.197  INFO 22174 --- [http-nio-8080-exec-1] com.tiago.controller.StudentController   : getAllStudents() returned 6 records",
      "@version" => "1",
    "@timestamp" => 2019-03-18T02:14:58.197Z,
    "logmessage" => "getAllStudents() returned 6 records",
          "type" => "java",
         "level" => "INFO",
     "timestamp" => "2019-03-17 23:14:58.197",
        "thread" => "http-nio-8080-exec-1"
}

```

Now let's perform an action that will log an error. We can do it by trying to delete an inexisting student, for example. This is our exception handler:

```
private static final Logger LOGGER = LoggerFactory.getLogger(ExceptionHandlingController.class);

/**
 * This exception is thrown when a resource is not found
 *
 * @param ex
 * @return {@link ExceptionResponse}
 */
@ExceptionHandler(ResourceNotFoundException.class)
public ResponseEntity<ExceptionResponse> resourceNotFound(ResourceNotFoundException ex) {
  ExceptionResponse response = new ExceptionResponse();
  response.setErrorCode("Not Found");
  response.setErrorMessage(ex.getMessage());

  LOGGER.error(String.format("ResourceNotFoundException: %s", ex.getMessage()));

  return new ResponseEntity<ExceptionResponse>(response, HttpStatus.NOT_FOUND);
}

```

Let's call it:

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552874328547.png)

In the server's log we have:

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552876092847.png)

And if we take a look at what's going on with Logstash, we see that it was captured:

```
{
          "path" => "/home/tiago/desenv/java/crud-exceptionhandling-example/application.log",
          "host" => "tiagomelo-zoom",
           "pid" => "22174",
         "class" => "ExceptionHandlerExceptionResolver",
       "message" => "2019-03-17 23:20:03.729  WARN 22174 --- [http-nio-8080-exec-3] .m.m.a.ExceptionHandlerExceptionResolver : Resolved [com.tiago.exception.ResourceNotFoundException: Student not found with id: '323']",
      "@version" => "1",
    "@timestamp" => 2019-03-18T02:20:03.729Z,
    "logmessage" => "Resolved [com.tiago.exception.ResourceNotFoundException: Student not found with id: '323']",
          "type" => "java",
         "level" => "WARN",
     "timestamp" => "2019-03-17 23:20:03.729",
        "thread" => "http-nio-8080-exec-3"
}

```

We've performed two actions: listed all students and tried to delete an inexisting one. Now it's time to visualize them in [Kibana](https://www.elastic.co/products/kibana) UI at [http://localhost:5601](http://localhost:5601/).

This is the log of the first operation performed, listing all students:

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552877797443.png)

And this is the log of the second operation performed, deleting an inexisting student:

![No alt text provided for this image](/assets/images/2019-03-18-3819cad8-f2f9-4fcf-86cd-f03b481be70c/1552877859190.png)

## Conclusion

Through this simple example, we learned how we can integrate a [Spring Boot](https://spring.io/projects/spring-boot) application with [ELK stack](https://www.elastic.co/elk-stack) in order to have centralized logging.

## Download the source

Here: [https://bitbucket.org/tiagoharris/crud-exceptionhandling-example/src/master/](https://bitbucket.org/tiagoharris/crud-exceptionhandling-example/src/master/)