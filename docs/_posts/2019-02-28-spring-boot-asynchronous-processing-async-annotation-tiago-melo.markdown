---
layout: post
title:  "Spring Boot: asynchronous processing with @Async annotation"
date:   2019-02-28 13:26:01 -0300
categories: java springboot asynchronous
---
![Spring Boot: asynchronous processing with @Async annotation](/assets/images/2019-02-28-10d30bca-f9d5-40a3-a033-4b8bc1105543/2019-02-28-banner.jpeg)

If you are following my recent articles about [Spring Boot](https://spring.io/projects/spring-boot) ( [here](https://www.linkedin.com/pulse/spring-boot-example-crud-restful-api-global-exception-tiago-melo/), [here](https://www.linkedin.com/pulse/java-appointment-scheduler-spring-boot-mysql-quartz-tiago-melo/) and [here](https://www.linkedin.com/pulse/spring-boot-batch-exporting-millions-records-from-mysql-tiago-melo/)), you should have noticed that it simplifies application development a lot. In this article we'll cover how the framework supports asynchronous processing.

## Introduction

When it comes to scaling services, one good approach is to implement asynchronous processing. And we can achieve that in [Spring Boot](https://spring.io/projects/spring-boot) by creating asynchronous methods, annotating them with [@Async](https://docs.spring.io/spring/docs/current/javadoc-api/org/springframework/scheduling/annotation/Async.html).

Annotating a method of a bean with [@Async](https://docs.spring.io/spring/docs/current/javadoc-api/org/springframework/scheduling/annotation/Async.html) will make it execute in a separate thread, so the caller will not have to wait for the completion of the called method.

## The test project

Suppose a [RESTful API](https://en.wikipedia.org/wiki/Representational_state_transfer) to calculate exchange quotation from Dollar to [Real](https://pt.wikipedia.org/wiki/Real_(moeda)). It exposes an endpoint that takes the desired amount of dollars to be quoted in various exchange companies, so the user can decide where to buy it.

To achieve that, our API will make [REST](https://en.wikipedia.org/wiki/Representational_state_transfer) calls to the exchange companies in order to get the quotations, and then the endpoint will aggregate all the quotations in the final response to the user.

Since every exchange company has different response times, it would be nice to run those [REST](https://en.wikipedia.org/wiki/Representational_state_transfer) calls in parallel, so we can optimize the general response time.

Interesting things that we'll see in this test project:

- how to enable asynchronous processing;
- how to create asynchronous methods;
- how to create bean classes that reads from _application.yml_ configuration file;
- how to make [REST](https://en.wikipedia.org/wiki/Representational_state_transfer) calls using [RestTemplate](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/client/RestTemplate.html).

Let's do it.

## Creating the project

[Spring Initializr](http://start.spring.io/) is our start point:

![No alt text provided for this image](/assets/images/2019-02-28-10d30bca-f9d5-40a3-a033-4b8bc1105543/1551368180666.png)

We've choose the following dependency:

- [Web](https://docs.spring.io/spring-boot/docs/current/reference/html/using-boot-build-systems.html#spring-boot-starter-web): Starter for building web, including RESTful, applications using Spring MVC. Uses Tomcat as the default embedded container.

## The classes

First, let's see the configuration that enables asynchronous processing. This is our configuration class:

```
package com.tiago.configuration;

import java.util.concurrent.Executor;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.web.client.RestTemplate;

/**
 * Configuration class that makes possible to inject the beans listed here.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Configuration
@EnableAsync
public class AsyncMethodsExampleApplicationConfiguration {

  @Bean(name = "asyncExecutor")
  public Executor asyncExecutor() {
      ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
      executor.setCorePoolSize(3);
      executor.setMaxPoolSize(3);
      executor.setQueueCapacity(100);
      executor.setThreadNamePrefix("AsynchThread-");
      executor.initialize();
      return executor;
  }

  @Bean
  public RestTemplate restTemplate() {
      return new RestTemplate();
  }
}

```

In order to enable asynchronous processing in our [Spring Boot](https://spring.io/projects/spring-boot) application, we use [@EnableAsync](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/scheduling/annotation/EnableAsync.html) annotation.

We set up our [ThreadPoolTaskExecutor](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/scheduling/concurrent/ThreadPoolTaskExecutor.html) as a bean named 'asyncExecutor' that will be referenced with the asynchronous methods that we will see later. Our threadpool will have the size of 3, and we are naming his threads by 'AsynchThread' so we can see on the server log.

Then we register [RestTemplate](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/client/RestTemplate.html) as a bean, so we can use it in our service class.

Now let's see our ' _application.yml_' file:

```
company:
  one:
    name: Company One
    url: http://localhost:8080/api/companyOne/getQuotation?value={value}
    quotation: 3.73

  two:
    name: Company Two
    url: http://localhost:8080/api/companyTwo/getQuotation?value={value}
    quotation: 3.70

  three:
    name: Company Three
    url: http://localhost:8080/api/companyThree/getQuotation?value={value}
    quotation: 3.75

```

So we have three fictitious exchange companies, with their respective URLs and quotations. For the sake of test, we are pointing to another controller from our API to emulate it.

How can we read those properties?

Simple. We could define a bean class representing each company, reading their properties accordingly.

Company One's properties:

```
package com.tiago.configuration;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * Company One's properties.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Component
@ConfigurationProperties(prefix="company.one")
public class CompanyOneProperties {

  private String name;

  private String url;

  private Double quotation;

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  public String getUrl() {
    return url;
  }

  public void setUrl(String url) {
    this.url = url;
  }

  public Double getQuotation() {
    return quotation;
  }

  public void setQuotation(Double quotation) {
    this.quotation = quotation;
  }
}


```

Company Two's properties:

```
package com.tiago.configuration;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * Company Two's properties.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Component
@ConfigurationProperties(prefix="company.two")
public class CompanyTwoProperties {

  private String name;

  private String url;

  private Double quotation;

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  public String getUrl() {
    return url;
  }

  public void setUrl(String url) {
    this.url = url;
  }

  public Double getQuotation() {
    return quotation;
  }

  public void setQuotation(Double quotation) {
    this.quotation = quotation;
  }
}


```

Company Three's properties:

```
package com.tiago.configuration;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * Company Three's properties.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Component
@ConfigurationProperties(prefix="company.three")
public class CompanyThreeProperties {

  private String name;

  private String url;

  private Double quotation;

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  public String getUrl() {
    return url;
  }

  public void setUrl(String url) {
    this.url = url;
  }

  public Double getQuotation() {
    return quotation;
  }

  public void setQuotation(Double quotation) {
    this.quotation = quotation;
  }
}

```

By using [@ConfigurationProperties](https://docs.spring.io/spring-boot/docs/current/api/org/springframework/boot/context/properties/ConfigurationProperties.html) we can map the desired set of properties. And as long as our bean classes have the same properties names from the ones defined in ' _application.yml_' file, they will be set through reflection.

This is our ' _DollarExchangeQuotationController_' that the user calls to get quotations:

```
package com.tiago.controller;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.tiago.payload.ExchangeQuotationResponse;
import com.tiago.service.ExchangeQuotationService;

/**
 * Restful controller responsible for getting exchange quotations.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@RestController
@RequestMapping("/dollar")
public class DollarExchangeQuotationController {

  private static Logger LOGGER = LoggerFactory.getLogger(DollarExchangeQuotationController.class);

  @Autowired
  ExchangeQuotationService service;

  /**
   * Get exchange quotations from a given amount of dollars.
   *
   * @param value
   * @return a list of {@link ExchangeQuotationResponse}
   * @throws InterruptedException
   * @throws ExecutionException
   */
  @GetMapping("/exchangeQuotationsInBRL")
  public List<ExchangeQuotationResponse> getExchangeQuotations(
      @RequestParam(value = "value") Double value) throws InterruptedException, ExecutionException {

    List<ExchangeQuotationResponse> exchangeQuotationResponses = new ArrayList<ExchangeQuotationResponse>();

    LOGGER.info("GET \"/exchangeQuotations\" starting");

    CompletableFuture<ExchangeQuotationResponse> quotationFromCompanyOne = service.getExchangeQuotationFromCompanyOne(value);
    CompletableFuture<ExchangeQuotationResponse> quotationFromCompanyTwo = service.getExchangeQuotationFromCompanyTwo(value);
    CompletableFuture<ExchangeQuotationResponse> quotationFromCompanyThree = service.getExchangeQuotationFromCompanyThree(value);

    // Wait until they are all done
    CompletableFuture.allOf(quotationFromCompanyOne, quotationFromCompanyTwo, quotationFromCompanyThree).join();

    exchangeQuotationResponses.add(quotationFromCompanyOne.get());
    exchangeQuotationResponses.add(quotationFromCompanyTwo.get());
    exchangeQuotationResponses.add(quotationFromCompanyThree.get());

    LOGGER.info("GET \"/exchangeQuotations\" finished");

    return exchangeQuotationResponses;
  }
}


```

It calls asynchronous methods in our service class that returns [CompletableFuture](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/CompletableFuture.html) objects. By calling _CompletableFutures.allOf()_ we are firing them simultaneously and each call will run in a separated thread. When all threads are finished, we build the final response with all exchange quotations.

This is our interface ' _ExchangeQuotationService_':

```
package com.tiago.service;

import java.util.concurrent.CompletableFuture;

/**
 * Service class used to get exchange quotations from different companies.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
import com.tiago.payload.ExchangeQuotationResponse;

/**
 * Service class to emulate exchange quotations.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
public interface ExchangeQuotationService {

  /**
   * Emulates quotation calculation for a exchange company.
   *
   * @param value
   * @return {@link ExchangeQuotationResponse}
   */
  CompletableFuture<ExchangeQuotationResponse> getExchangeQuotationFromCompanyOne(Double value);

  /**
   * Emulates quotation calculation for a exchange company.
   *
   * @param value
   * @return {@link ExchangeQuotationResponse}
   */
  CompletableFuture<ExchangeQuotationResponse> getExchangeQuotationFromCompanyTwo(Double value);

  /**
   * Emulates quotation calculation for a exchange company.
   *
   * @param value
   * @return {@link ExchangeQuotationResponse}
   */
  CompletableFuture<ExchangeQuotationResponse> getExchangeQuotationFromCompanyThree(Double value);
}

```

And its implementation class:

```
package com.tiago.service.impl;

import java.util.concurrent.CompletableFuture;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import com.tiago.configuration.CompanyOneProperties;
import com.tiago.configuration.CompanyThreeProperties;
import com.tiago.configuration.CompanyTwoProperties;
import com.tiago.payload.ExchangeQuotationResponse;
import com.tiago.service.ExchangeQuotationService;

/**
 * Implementation of {@link ExchangeQuotationService} interface.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Service
public class ExchangeQuotationServiceImpl implements ExchangeQuotationService {

  private static Logger LOGGER = LoggerFactory.getLogger(ExchangeQuotationService.class);

  @Autowired
  private RestTemplate restTemplate;

  @Autowired
  private CompanyOneProperties companyOneProperties;

  @Autowired
  private CompanyTwoProperties companyTwoProperties;

  @Autowired
  private CompanyThreeProperties companyThreeProperties;

  /* (non-Javadoc)
   * @see com.tiago.service.ExchangeQuotationService#getExchangeQuotationFromCompanyOne(java.lang.Double)
   */
  @Override
  @Async("asyncExecutor")
  public CompletableFuture<ExchangeQuotationResponse> getExchangeQuotationFromCompanyOne(Double value) {
    LOGGER.info("getExchangeQuotationFromCompanyOne() starting");

    Double quotation = restTemplate.getForObject(companyOneProperties.getUrl(), Double.class, value);

    LOGGER.info("getExchangeQuotationFromCompanyOne() finished");

    return CompletableFuture.completedFuture(buildExchangeQuotationResponse(companyOneProperties.getName(), value, quotation));
  }

  /* (non-Javadoc)
   * @see com.tiago.service.ExchangeQuotationService#getExchangeQuotationFromCompanyTwo(java.lang.Double)
   */
  @Override
  @Async("asyncExecutor")
  public CompletableFuture<ExchangeQuotationResponse> getExchangeQuotationFromCompanyTwo(Double value) {
    LOGGER.info("getExchangeQuotationFromCompanyTwo() starting");

    Double quotation = restTemplate.getForObject(companyTwoProperties.getUrl(), Double.class, value);

    LOGGER.info("getExchangeQuotationFromCompanyTwo() finished");

    return CompletableFuture.completedFuture(buildExchangeQuotationResponse(companyTwoProperties.getName(), value, quotation));
  }

  /* (non-Javadoc)
   * @see com.tiago.service.ExchangeQuotationService#getExchangeQuotationFromCompanyThree(java.lang.Double)
   */
  @Override
  @Async("asyncExecutor")
  public CompletableFuture<ExchangeQuotationResponse> getExchangeQuotationFromCompanyThree(Double value) {
    LOGGER.info("getExchangeQuotationFromCompanyThree() starting");

    Double quotation = restTemplate.getForObject(companyThreeProperties.getUrl(), Double.class, value);

    LOGGER.info("getExchangeQuotationFromCompanyThree() finished");

    return CompletableFuture.completedFuture(buildExchangeQuotationResponse(companyThreeProperties.getName(), value, quotation));
  }

  private ExchangeQuotationResponse buildExchangeQuotationResponse(String companyName, Double dollars, Double exchangeQuotation) {
    return new ExchangeQuotationResponse(companyName, dollars, exchangeQuotation);
  }
}

```

Now let's take a closer look at what it does:

```
@Autowired
private RestTemplate restTemplate;

@Autowired
private CompanyOneProperties companyOneProperties;

@Autowired
private CompanyTwoProperties companyTwoProperties;

@Autowired
private CompanyThreeProperties companyThreeProperties;

```

Here we are injecting the [RestTemplate](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/client/RestTemplate.html) and the bean classes representing each company configuration.

Next, let get one of the service methods to see what it does:

```
/* (non-Javadoc)
 * @see com.tiago.service.ExchangeQuotationService#getExchangeQuotationFromCompanyOne(java.lang.Double)
 */
@Override
@Async("asyncExecutor")
public CompletableFuture<ExchangeQuotationResponse> getExchangeQuotationFromCompanyOne(Double value) {
  LOGGER.info("getExchangeQuotationFromCompanyOne() starting");

  Double quotation = restTemplate.getForObject(companyOneProperties.getUrl(), Double.class, value);

  LOGGER.info("getExchangeQuotationFromCompanyOne() finished");

  return CompletableFuture.completedFuture(buildExchangeQuotationResponse(companyOneProperties.getName(), value, quotation));
}

```

By annotating with '@Async("asyncExecutor")' we are defining our method as an asynchronous one. Note that we are passing our [ThreadPoolTaskExecutor](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/scheduling/concurrent/ThreadPoolTaskExecutor.html) configured earlier.

To make the REST call, we pass the desired URL, the type that this endpoint returns (in our case, Double) and the value to get a quotation for.

Then we return a [CompletableFuture](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/CompletableFuture.html) that is composed of ' _ExchangeQuotationResponse'_, thatencapsulates the response:

```
package com.tiago.payload;

/**
 * Encapsulates quotation response data.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
public class ExchangeQuotationResponse {

  private String companyName;

  private Double dollars;

  private Double exchangeQuotation;

  public ExchangeQuotationResponse(String companyName, Double dollars, Double exchangeQuotation) {
    this.companyName = companyName;
    this.dollars = dollars;
    this.exchangeQuotation = exchangeQuotation;
  }

  public String getCompanyName() {
    return companyName;
  }

  public void setCompanyName(String companyName) {
    this.companyName = companyName;
  }

  public Double getDollars() {
    return dollars;
  }

  public void setDollars(Double dollars) {
    this.dollars = dollars;
  }

  public Double getExchangeQuotation() {
    return exchangeQuotation;
  }

  public void setExchangeQuotation(Double exchangeQuotation) {
    this.exchangeQuotation = exchangeQuotation;
  }
}

```

Finally, this is our ' _ExchangeCompaniesController_' that emulates exchange companies:

```
package com.tiago.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.tiago.configuration.CompanyOneProperties;
import com.tiago.configuration.CompanyThreeProperties;
import com.tiago.configuration.CompanyTwoProperties;
import com.tiago.util.NumberUtils;

/**
 * Restful controller that emulates different exchange companies.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@RestController
@RequestMapping("/api")
public class ExchangeCompaniesController {

  @Autowired
  private CompanyOneProperties companyOneProperties;

  @Autowired
  private CompanyTwoProperties companyTwoProperties;

  @Autowired
  private CompanyThreeProperties companyThreeProperties;

  /**
   * Emulates quotation calculation for a exchange company.
   *
   * @param value
   * @return the quotation
   * @throws InterruptedException
   */
  @GetMapping("/companyOne/getQuotation")
  public Double getExchangeQuotationFromCompanyOne(       @RequestParam(value = "value") Double value) throws InterruptedException {

    // simulates some processing time
    Thread.sleep(3000L);

    return NumberUtils.getRoundedDouble(value * companyOneProperties.getQuotation());
  }

  /**
   * Emulates quotation calculation for a exchange company.
   *
   * @param value
   * @return the quotation
   * @throws InterruptedException
   */
  @GetMapping("/companyTwo/getQuotation")
  public Double getExchangeQuotationFromCompanyTwo (       @RequestParam(value = "value") Double value) throws InterruptedException {

    // simulates some processing time
    Thread.sleep(5000L);

    return NumberUtils.getRoundedDouble(value * companyTwoProperties.getQuotation());
  }

  /**
   * Emulates quotation calculation for a exchange company.
   *
   * @param value
   * @return the quotation
   * @throws InterruptedException
   */
  @GetMapping("/companyThree/getQuotation")
  public Double getExchangeQuotationFromCompanyThree(       @RequestParam(value = "value") Double value) throws InterruptedException {

    // simulates some processing time
    Thread.sleep(4000L);

    return NumberUtils.getRoundedDouble(value * companyThreeProperties.getQuotation());
  }
}

```

So, we will simulate different response times for each exchange company:

- 'Company One' will take 3 seconds to respond;
- 'Company Two' will take 5 seconds to respond;
- 'Company Three' will take 4 seconds to respond.

## It's show time!

Let's fire up the application:

```
$ mvn spring-boot:run

```

Let's call the endpoint:

```
$ curl -v "http://localhost:8080/dollar/exchangeQuotationsInBRL?value=331.54"

```

This is the response:

```
[
  {
    "companyName": "Company One",
    "dollars": 331.54,
    "exchangeQuotation": 1236.64
  },
  {
    "companyName": "Company Two",
    "dollars": 331.54,
    "exchangeQuotation": 1226.7
  },
  {
    "companyName": "Company Three",
    "dollars": 331.54,
    "exchangeQuotation": 1243.28
  }
]

```

Alright. Let's see the server's console:

```
2019-02-24 14:26:50.308  INFO 4405 --- [nio-8080-exec-1] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring DispatcherServlet 'dispatcherServlet'
2019-02-24 14:26:50.308  INFO 4405 --- [nio-8080-exec-1] o.s.web.servlet.DispatcherServlet        : Initializing Servlet 'dispatcherServlet'
2019-02-24 14:26:50.317  INFO 4405 --- [nio-8080-exec-1] o.s.web.servlet.DispatcherServlet        : Completed initialization in 9 ms
2019-02-24 14:26:50.361  INFO 4405 --- [nio-8080-exec-1] c.t.c.DollarExchangeQuotationController  : GET "/exchangeQuotations" starting
2019-02-24 14:26:50.374  INFO 4405 --- [ AsynchThread-1] c.t.service.ExchangeQuotationService     : getExchangeQuotationFromCompanyOne() starting
2019-02-24 14:26:50.378  INFO 4405 --- [ AsynchThread-2] c.t.service.ExchangeQuotationService     : getExchangeQuotationFromCompanyTwo() starting
2019-02-24 14:26:50.385  INFO 4405 --- [ AsynchThread-3] c.t.service.ExchangeQuotationService     : getExchangeQuotationFromCompanyThree() starting
2019-02-24 14:26:53.532  INFO 4405 --- [ AsynchThread-1] c.t.service.ExchangeQuotationService     : getExchangeQuotationFromCompanyOne() finished
2019-02-24 14:26:54.456  INFO 4405 --- [ AsynchThread-3] c.t.service.ExchangeQuotationService     : getExchangeQuotationFromCompanyThree() finished
2019-02-24 14:26:55.455  INFO 4405 --- [ AsynchThread-2] c.t.service.ExchangeQuotationService     : getExchangeQuotationFromCompanyTwo() finished
2019-02-24 14:26:55.457  INFO 4405 --- [nio-8080-exec-1] c.t.c.DollarExchangeQuotationController  : GET "/exchangeQuotations" finished

```

The three [REST](https://en.wikipedia.org/wiki/Representational_state_transfer) calls were run in parallel at 2019-02-24 14:26:50; notice the three different thread names:

- AsynchThread-1
- AsynchThread-2
- AsynchThread-3

The processing was finished at 2019-02-24 14:26:55, so the overall time was **5 seconds** due to the slowest company to respond ('Company Two' takes exactly 5 seconds to respond).

Now let's see the what happens if we turn off asynchronous processing. We can do it by commenting [@EnableAsync](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/scheduling/annotation/EnableAsync.html) annotation from our configuration class, like this:

```
package com.tiago.configuration;

import java.util.concurrent.Executor;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.web.client.RestTemplate;

/**
 * Configuration class that makes possible to inject the beans listed here.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Configuration
//@EnableAsync
public class AsyncMethodsExampleApplicationConfiguration {

  @Bean(name = "asyncExecutor")
  public Executor asyncExecutor() {
      ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
      executor.setCorePoolSize(3);
      executor.setMaxPoolSize(3);
      executor.setQueueCapacity(100);
      executor.setThreadNamePrefix("AsynchThread-");
      executor.initialize();
      return executor;
  }

  @Bean
  public RestTemplate restTemplate() {
      return new RestTemplate();
  }
}

```

Now if we call the endpoint in the same way we did earlier, this is what we have on server's log:

```
2019-02-24 14:27:28.659  INFO 4482 --- [nio-8080-exec-1] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring DispatcherServlet 'dispatcherServlet'
2019-02-24 14:27:28.659  INFO 4482 --- [nio-8080-exec-1] o.s.web.servlet.DispatcherServlet        : Initializing Servlet 'dispatcherServlet'
2019-02-24 14:27:28.668  INFO 4482 --- [nio-8080-exec-1] o.s.web.servlet.DispatcherServlet        : Completed initialization in 9 ms
2019-02-24 14:27:28.701  INFO 4482 --- [nio-8080-exec-1] c.t.c.DollarExchangeQuotationController  : GET "/exchangeQuotations" starting
2019-02-24 14:27:28.701  INFO 4482 --- [nio-8080-exec-1] c.t.service.ExchangeQuotationService     : getExchangeQuotationFromCompanyOne() starting
2019-02-24 14:27:31.823  INFO 4482 --- [nio-8080-exec-1] c.t.service.ExchangeQuotationService     : getExchangeQuotationFromCompanyOne() finished
2019-02-24 14:27:31.826  INFO 4482 --- [nio-8080-exec-1] c.t.service.ExchangeQuotationService     : getExchangeQuotationFromCompanyTwo() starting
2019-02-24 14:27:36.839  INFO 4482 --- [nio-8080-exec-1] c.t.service.ExchangeQuotationService     : getExchangeQuotationFromCompanyTwo() finished
2019-02-24 14:27:36.840  INFO 4482 --- [nio-8080-exec-1] c.t.service.ExchangeQuotationService     : getExchangeQuotationFromCompanyThree() starting
2019-02-24 14:27:40.861  INFO 4482 --- [nio-8080-exec-1] c.t.service.ExchangeQuotationService     : getExchangeQuotationFromCompanyThree() finished
2019-02-24 14:27:40.862  INFO 4482 --- [nio-8080-exec-1] c.t.c.DollarExchangeQuotationController  : GET "/exchangeQuotations" finished

```

We can clearly see that the three [REST](https://en.wikipedia.org/wiki/Representational_state_transfer) calls were sequentially called; the processing began at 2019-02-24 14:27:28 and it finished at 2019-02-24 14:27:40, having an overall time of **12 seconds**, which is the sum of all companies response times (3 + 5 + 4).

## Conclusion

Through this simple example we learnt how to scale up services by enabling asynchronous processing in Spring Boot by enabling it using [@EnableAsync](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/scheduling/annotation/EnableAsync.html) annotation and by writing asynchronous methods by using [@Async](https://docs.spring.io/spring/docs/current/javadoc-api/org/springframework/scheduling/annotation/Async.html) annotation.

We also saw how to map properties to bean classes and how to make [REST](https://en.wikipedia.org/wiki/Representational_state_transfer) calls using [RestTemplate](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/client/RestTemplate.html).

## Download the source

Here: [https://bitbucket.org/tiagoharris/async-methods-example/src/master/](https://bitbucket.org/tiagoharris/async-methods-example/src/master/)
