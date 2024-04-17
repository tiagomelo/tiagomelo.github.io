---
layout: post
title:  "Java: Multithread testing using JUnit"
date:   2019-02-01 13:26:01 -0300
categories: java multithread junit
---
![Java: Multithread testing using JUnit](/assets/images/2019-02-01-5b678502-8a1c-4ebd-b298-36e03fa29a94/2019-02-01-banner.jpeg)

We all know that Java offers a mechanism to avoid race conditions by synchronizing thread access to shared data: the _synchronized_ keyword. But what if you want to test a [synchronized method](https://docs.oracle.com/javase/tutorial/essential/concurrency/syncmeth.html) using JUnit? Let's do this.

## Introduction

Testing multithreaded code is something tricky to do. Since I'm a great fan of [TDD](https://en.wikipedia.org/wiki/Test-driven_development), I'm always looking to reach the maximum test coverage in every project that I take part. And testing a [synchronized method](https://docs.oracle.com/javase/tutorial/essential/concurrency/syncmeth.html) is important not only to guarantee that the system behaves the way you expect, but it helps you to have a better comprehension of what's going on.

## The test project

I've wrote a small project using [Spring Boot](https://spring.io/projects/spring-boot) to illustrate the following situation: how can a system gracefully handle concurrent threads trying to persist the same object to the database?

This is a situation that you could face when writing a REST API to manage reservations for a hotel, for example. You don't want the system to crack when two different people try to book the same dates, right?

## The classes

Suppose we have the following table. Note that we have a UNIQUE constraint to prevent duplicate combinations of user and email:

```
CREATE TABLE IF NOT EXISTS `user` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(200) NOT NULL,
  `email` varchar(200) NOT NULL,

  PRIMARY KEY(`id`),
  UNIQUE(`name`, `email`)

)

```

This is the entity class for it:

```
package com.tiago.entity;

import java.util.Objects;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;

/**
 * Entity for table "User".
 *
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Entity(name = "user")
public class User {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Integer id;

  @Column(nullable = false)
  private String name;

  @Column(nullable = false)
  private String email;

  public Integer getId() {
    return id;
  }

  public void setId(Integer id) {
    this.id = id;
  }

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  public String getEmail() {
    return email;
  }

  public void setEmail(String email) {
    this.email = email;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) {
      return true;
    }

    if (!(o instanceof User)) {
      return false;
    }

    User user = (User) o;

    if (!Objects.equals(getId(), user.getId())) {
      return false;
    } else if (!Objects.equals(getName(), user.getName())) {
      return false;
    } else if (!Objects.equals(getEmail(), user.getEmail())) {
      return false;
    }

    return true;
  }

  @Override
  public int hashCode() {
    return Objects.hash(getId());
  }
}

```

We are using this [Spring Data JPA repository](https://docs.spring.io/spring-data/jpa/docs/1.6.0.RELEASE/reference/html/jpa.repositories.html):

```
package com.tiago.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.tiago.entity.User;

/**
 * Repository for {@link User} entity.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Repository
public interface UserRepository extends JpaRepository<User, Integer> {
}

```

This is the service class:

```
package com.tiago.service;

import com.tiago.entity.User;

/**
 * Service to manage users.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
public interface UserService {

  /**
   * Saves a user
   *
   * @param user to be saved
   * @return the saved user
   */
  User save(User user);

}

```

... and its implementation, which we want to test:

```
package com.tiago.service.impl;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.tiago.entity.User;
import com.tiago.repository.UserRepository;
import com.tiago.service.UserService;

/**
 * Implements {@link UserService} interface.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Service
public class UserServiceImpl implements UserService {

  @Autowired
  UserRepository userRepository;

  /* (non-Javadoc)
   * @see com.tiago.service.UserService#save(com.tiago.entity.User)
   */
  @Override
  public User save(User user) {
    userRepository.save(user);

    return user;
  }
}

```

Sure, the UserServiceImpl#save() method should be marked as _synchronized_ in order to prevent errors by concurrent threads trying to persist the same User object. But let's write a multithreaded test to reproduce this scenario.

## The test class

This is how you test the service class mentioned above.

```
package com.tiago.service.impl;

import static org.junit.Assert.assertEquals;

import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicInteger;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.test.context.junit4.SpringRunner;

import com.tiago.entity.User;
import com.tiago.repository.UserRepository;
import com.tiago.service.UserService;

/**
 * This class represents a test case of multiple threads attempting to
 * save the same User.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@RunWith(SpringRunner.class)
@DataJpaTest
public class UserServiceImplMultithreadedTest {

  @Autowired
  UserService service;

  @Autowired
  UserRepository userRepository;

  AtomicInteger threadExecutionCount = new AtomicInteger();

  @Test
  public void testSaveMethod() throws InterruptedException, ExecutionException {
    // Number of threads that will try to persist the same User object
    int threadCount = 10;

    // The User object
    User newUser = buildUser();

    // A task that persists the User object
    Callable<User> task = getCallable(newUser);

    // A list of the task mentioned above
    List<Callable<User>> tasks = Collections.nCopies(threadCount, task);

    // The thread pool that will execute all tasks from the list
    ExecutorService executorService = Executors.newFixedThreadPool(threadCount);

    // Here we are asking to execute all the tasks
    List<Future<User>> futures = executorService.invokeAll(tasks);

    // This set will hold the persisted User object
    HashSet<User> userSet = new HashSet<User>();

    // Here we will check for exceptions
    for (Future<User> future : futures) {
      // Counts the number of threads that were executed
      threadExecutionCount.incrementAndGet();

      // future.get() will throw java.util.concurrent.ExecutionException if an exception was
      // thrown by any task.
      //
      // If UserServiceImpl.save(User user) method were not
      // synchronized, a task would throw a org.springframework.dao.DataIntegrityViolationException.
      //
      // The User is stored only once at the database; future.get() returns the
      // same object.
      userSet.add(future.get());
    }

    // Since a Set does not stores duplicated objects, this set will contain only
    // one User object.
    assertEquals(1, userSet.size());

    // Here we assure that all threads were executed
    assertEquals(threadExecutionCount.get(), threadCount);

    // There will be only one User object in the database
    assertEquals(newUser, userSet.iterator().next());
  }

  private Callable<User> getCallable(User newUser) {
    Callable<User> task = new Callable<User>() {
      @Override
      public User call() {
        return service.save(newUser);
      }
    };

    return task;
  }

  private User buildUser() {
    User newUser = new User();
    newUser.setName("Steve Harris");
    newUser.setEmail("steve@ironmaiden.com");

    return newUser;
  }
}

```

If we run it, the test will fail as expected:

![No alt text provided for this image](/assets/images/2019-02-01-5b678502-8a1c-4ebd-b298-36e03fa29a94/1548989081120.png)

This is the detailed stack trace:

```
java.util.concurrent.ExecutionException:

org.springframework.dao.DataIntegrityViolationException:

could not execute statement; SQL [n/a];

constraint ["CONSTRAINT_INDEX_2 ON PUBLIC.USER(NAME, EMAIL)
VALUES ('Steve Harris', 'steve@ironmaiden.com', 1)";

SQL statement: insert into user (id, email, name) values (null, ?, ?)
[23505-197]]; nested exception is
org.hibernate.exception.ConstraintViolationException:
could not execute statement

```

This happens because UserServiceImpl#save() method is not marked as _synchronized_.

Let's make this test pass: we will expect an _ExecutionException_ to be thrown.

```
@Test(expected = ExecutionException.class)
public void testSaveMethod() throws InterruptedException, ExecutionException {
 // Number of threads that will try to persist the same User object
 int threadCount = 10;

 // The User object
 User newUser = buildUser();

 // A task that persists the User object
 Callable < User > task = getCallable(newUser);

 // A list of the task mentioned above
 List < Callable < User >> tasks = Collections.nCopies(threadCount, task);

 // The thread pool that will execute all tasks from the list
 ExecutorService executorService = Executors.newFixedThreadPool(threadCount);

 // Here we are asking to execute all the tasks
 List < Future < User >> futures = executorService.invokeAll(tasks);

 // This set will hold the persisted User object
 HashSet < User > userSet = new HashSet < User > ();

 // Here we will check for exceptions
 for (Future < User > future: futures) {
  // Counts the number of threads that were executed
  threadExecutionCount.incrementAndGet();

  // future.get() will throw java.util.concurrent.ExecutionException if an exception was
  // thrown by any task.
  //
  // If UserServiceImpl.save(User user) method were not
  // synchronized, a task would throw a org.springframework.dao.DataIntegrityViolationException.
  //
  // The User is stored only once at the database; future.get() returns the
  // same object.
  userSet.add(future.get());
 }

 // Since a Set does not stores duplicated objects, this set will contain only
 // one User object.
 assertEquals(1, userSet.size());

 // Here we assure that all threads were executed
 assertEquals(threadExecutionCount.get(), threadCount);

 // There will be only one User object in the database
 assertEquals(newUser, userSet.iterator().next());
}

```

It will pass as expected:

![No alt text provided for this image](/assets/images/2019-02-01-5b678502-8a1c-4ebd-b298-36e03fa29a94/1548989715019.png)

Alright. Time to make it right. Let's mark UserServiceImpl#save() method as _synchronized_.

```
package com.tiago.service.impl;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.tiago.entity.User;
import com.tiago.repository.UserRepository;
import com.tiago.service.UserService;

/**
 * Implements {@link UserService} interface.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Service
public class UserServiceImpl implements UserService {

  @Autowired
  UserRepository userRepository;

  /* (non-Javadoc)
   * @see com.tiago.service.UserService#save(com.tiago.entity.User)
   */
  @Override
  public synchronized User save(User user) {
    userRepository.save(user);

    return user;
  }
}

```

Now let's change our test: we do not expect any exception to occur, and only one _User_ object should be persisted _even if 10 threads attempts to save the same object._

```
package com.tiago.service.impl;

import static org.junit.Assert.assertEquals;

import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicInteger;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.test.context.junit4.SpringRunner;

import com.tiago.entity.User;
import com.tiago.repository.UserRepository;
import com.tiago.service.UserService;

/**
 * This class represents a test case of multiple threads attempting to
 * save the same User.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@RunWith(SpringRunner.class)
@DataJpaTest
public class UserServiceImplMultithreadedTest {

  @Autowired
  UserService service;

  @Autowired
  UserRepository userRepository;

  AtomicInteger threadExecutionCount = new AtomicInteger();

  @Test
  public void testSaveMethod() throws InterruptedException, ExecutionException {
    // Number of threads that will try to persist the same User object
    int threadCount = 10;

    // The User object
    User newUser = buildUser();

    // A task that persists the User object
    Callable<User> task = getCallable(newUser);

    // A list of the task mentioned above
    List<Callable<User>> tasks = Collections.nCopies(threadCount, task);

    // The thread pool that will execute all tasks from the list
    ExecutorService executorService = Executors.newFixedThreadPool(threadCount);

    // Here we are asking to execute all the tasks
    List<Future<User>> futures = executorService.invokeAll(tasks);

    // This set will hold the persisted User object
    HashSet<User> userSet = new HashSet<User>();

    // Here we will check for exceptions
    for (Future<User> future : futures) {
      // Counts the number of threads that were executed
      threadExecutionCount.incrementAndGet();

      // future.get() will throw java.util.concurrent.ExecutionException if an exception was
      // thrown by any task.
      //
      // If UserServiceImpl.save(User user) method were not
      // synchronized, a task would throw a org.springframework.dao.DataIntegrityViolationException.
      //
      // The User is stored only once at the database; future.get() returns the
      // same object.
      userSet.add(future.get());
    }

    // Since a Set does not stores duplicated objects, this set will contain only
    // one User object.
    assertEquals(1, userSet.size());

    // Here we assure that all threads were executed
    assertEquals(threadExecutionCount.get(), threadCount);

    // There will be only one User object in the database
    assertEquals(newUser, userSet.iterator().next());
  }

  private Callable<User> getCallable(User newUser) {
    Callable<User> task = new Callable<User>() {
      @Override
      public User call() {
        return service.save(newUser);
      }
    };

    return task;
  }

  private User buildUser() {
    User newUser = new User();
    newUser.setName("Steve Harris");
    newUser.setEmail("steve@ironmaiden.com");

    return newUser;
  }
}

```

It passes as expected:

![No alt text provided for this image](/assets/images/2019-02-01-5b678502-8a1c-4ebd-b298-36e03fa29a94/1548990059829.png)

## Conclusion

Through this simple example we learnt to test the multithreaded code using JUnit. It's a little bit tricky but it pays the price: now we can assure that the system will behave as expected.

## Download the source code

Here: [https://bitbucket.org/tiagoharris/multithread-test/src/master/](https://bitbucket.org/tiagoharris/multithread-test/src/master/)