---
layout: post
title:  "Java: how to assert exception messages with JUnit 4"
date:   2019-02-08 13:26:01 -0300
categories: java junit
---
![Java: how to assert exception messages with JUnit 4](/assets/images/2019-02-08-441e95e5-e484-4917-a0a0-a9870f429338/2019-02-08-banner.png)

Have you ever wanted to assert exception messages in your unit tests? Let's do this.

## Introduction

It's easy to write a unit test to check if a certain exception is thrown, like this:

```
@Test(expected = IndexOutOfBoundsException.class)
public void testIndexOutOfBoundsException() {
    ArrayList emptyList = new ArrayList();
    Object o = emptyList.get(0);
}
```

But we may want to assert the exception's message as well.

## The test project

I've wrote a small project using [Spring Boot](https://spring.io/projects/spring-boot) to illustrate the following situation: if we have, let's say, a utility class that deals with dates and different exceptions can be thrown depending on the kind of error, how can we effectively test it?

## The classes

This is our utility class:

```
package com.tiago.util;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;

import org.springframework.stereotype.Component;

/**
 * Utility class that deals with dates.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Component
public class DateUtil {

  public static final DateTimeFormatter FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd.HH:mm:ss");

  /**
   * Parse a String to a LocalDateTime object.
   *
   * @param date the String in "yyyy-MM-dd.HH:mm:ss" format
   * @return LocalDateTime
   * @throws IllegalArgumentException if date parameter is null
   * @throws DateTimeParseException if date parameter is in invalid format
   */
  public static LocalDateTime parse(String date) {
    if(date == null) {
      throw new IllegalArgumentException("date parameter is null");
    }

    LocalDateTime ldt = null;

    try {
      ldt = LocalDateTime.parse(date, FORMATTER);
    } catch (DateTimeParseException e) {
      throw new RuntimeException("\"" + date + "\" is not a valid date");
    }

    return ldt;
  }
}

```

So, if the 'date' parameter is null, an 'IllegalArgumentException' is thrown; otherwise, a 'RuntimeException' is thrown if it's in an invalid format.

This is how we can test it:

```
package com.tiago.util;

import static org.junit.Assert.assertEquals;

import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.ExpectedException;

public class DateUtilTest {

  @Rule
  public ExpectedException expectedEx = ExpectedException.none();

  @Test
  public void whenDateParameterIsNull_thenThrowIllegalArgumentException() {
    expectedEx.expect(IllegalArgumentException.class);
    expectedEx.expectMessage("date parameter is null");

    DateUtil.parse(null);
  }

  @Test
  public void whenDateParameterIsInvalid_thenThrowRuntimeException() {
    String invalidDateStr = "2019-01-a";

    expectedEx.expect(RuntimeException.class);
    expectedEx.expectMessage("\"" + invalidDateStr + "\" is not a valid date");

    DateUtil.parse(invalidDateStr);
  }

  @Test
  public void whenDateParameterIsValid_thenReturnLocalDateTimeObject() {
    String validDateTimeStr = "2019-01-01.22:03:01";
    String returneDateTimeStr = DateUtil.parse(validDateTimeStr).format(DateUtil.FORMATTER);

    assertEquals(validDateTimeStr, returneDateTimeStr);
  }
}

```

Lets walk through it:

```
@Rule
public ExpectedException expectedEx = ExpectedException.none();
```

A [JUnit 4 rule](https://junit.org/junit4/javadoc/latest/org/junit/Rule.html) is a component that intercepts test method calls and allows us to do something before a test method is run and after a test method has been run. All JUnit 4 rule classes must implement the [TestRule](https://junit.org/junit4/javadoc/latest/org/junit/rules/TestRule.html) interface.

From the various [TestRule implementations](https://junit.org/junit4/javadoc/4.12/org/junit/rules/TestRule.html) available we are using [ExpectedException](https://junit.org/junit4/javadoc/4.12/org/junit/rules/ExpectedException.html) that allow us to verify that our code throws a specific exception.

Now we want to test _DateUtil.parse()_ method passing a null parameter:

```
@Test
public void whenDateParameterIsNull_thenThrowIllegalArgumentException() {
  expectedEx.expect(IllegalArgumentException.class);
  expectedEx.expectMessage("date parameter is null");

  DateUtil.parse(null);
}

```

We are able to check not only the kind of exception, but its message as well.

Likewise, when testing a invalid format:

```
@Test
public void whenDateParameterIsInvalid_thenThrowRuntimeException() {
  String invalidDateStr = "2019-01-a";

  expectedEx.expect(RuntimeException.class);
  expectedEx.expectMessage("\"" + invalidDateStr + "\" is not a valid date");

  DateUtil.parse(invalidDateStr);
}

```

Finally, when 'date' parameter is valid:

```
@Test
public void whenDateParameterIsValid_thenReturnLocalDateTimeObject() {
  String validDateTimeStr = "2019-01-01.22:03:01";
  String returneDateTimeStr = DateUtil.parse(validDateTimeStr).format(DateUtil.FORMATTER);

  assertEquals(validDateTimeStr, returneDateTimeStr);
}
```

All tests passes as expected:

![No alt text provided for this image](/assets/images/2019-02-08-441e95e5-e484-4917-a0a0-a9870f429338/1549657483245.png)

## Conclusion

Through this simple example we learnt how to assert not only the exception type, but its message as well.

## Download the source code

Here: [https://bitbucket.org/tiagoharris/exception-message-test/src/master/](https://bitbucket.org/tiagoharris/exception-message-test/src/master/)
