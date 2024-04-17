---
layout: post
title:  "Spring Boot: an example of a CRUD RESTful API with global exception handling"
date:   2019-02-15 13:26:01 -0300
categories: java springboot rest api
---
![Spring Boot: an example of a CRUD RESTful API with global exception handling](/assets/images/2019-02-15-e3ae59fd-0d46-40c5-97e9-a5c8791d1145/2019-02-15-banner.png)

As [Spring Boot](https://spring.io/projects/spring-boot) popularity keeps growing, it's becoming the framework of choice to ease the development of different kinds of applications, like web apps, stand-alone apps or RESTful APIs, for example. In this article we'll see how we can write a CRUD RESTFul API with global exception handling.

## Introduction

When writing a RESTFul API, it's very important to provide appropriate error messages to the caller to indicate the error cases in a clean and concise manner. But is it possible to handle exceptions in a more elegant way by centralizing error handling logic? Fortunately, Spring Boot provides a pretty straightforward way to tackle this: meet the [@ControllerAdvice](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/bind/annotation/ControllerAdvice.html) annotation.

## The test project

I've written a [small project](https://bitbucket.org/tiagoharris/crud-exceptionhandling-example/src/master/) using [Spring Boot](https://spring.io/projects/spring-boot) to implement a very simple CRUD RESTFul API to manage Students. Besides exception handling, we'll see some interesting things as well:

- bootstrapping with [Spring Initializr](http://start.spring.io/);
- database initialization using SQL scripts;
- database configuration;
- layered architecture;
- use of [DTO](https://en.wikipedia.org/wiki/Data_transfer_object) to avoid exposing the entity directly;
- use of [JaCoCo](https://www.eclemma.org/jacoco/) that help us to keep a good test coverage.

So let's get started.

## Creating the project

[Spring Initializr](http://start.spring.io/) is our start point:

![No alt text provided for this image](/assets/images/2019-02-15-e3ae59fd-0d46-40c5-97e9-a5c8791d1145/1550188477132.png)

We've choose the following dependencies:

- [Web](https://docs.spring.io/spring-boot/docs/current/reference/html/using-boot-build-systems.html#spring-boot-starter-web): Starter for building web, including RESTful, applications using Spring MVC. Uses Tomcat as the default embedded container.
- [JPA](https://docs.spring.io/spring-boot/docs/current/reference/html/using-boot-build-systems.html#spring-boot-starter-data-jpa): Starter for using Spring Data JPA with Hibernate.
- [DevTools](https://docs.spring.io/spring-boot/docs/current/reference/html/using-boot-devtools.html): utility tool that offers property defaults, automatic restart, live reload, etc
- [H2](http://www.h2database.com/html/main.html): one of the most popular in memory databases.

## Database initialization

We'll initialize the database using SQL scripts. This approach does not require a command line runner to populate data, nor Hibernate to create the database schema. Everything will be defined in two SQL scripts: **schema.sql** and **data.sql**, both located in 'src/main/resources' folder.

The schema is defined in **schema.sql**:

```
CREATE TABLE IF NOT EXISTS `student` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `email` varchar(50) NOT NULL,
  `birth_date` date not null,

  PRIMARY KEY(`id`),
  UNIQUE(`name`, `email`, `birth_date`)
) engine=InnoDB default charset=utf8;

```

The initialization data is defined in **data.sql**:

```
INSERT INTO student(birth_date, name, email) values ('2001-01-01', 'Marcelino Lund','marcelino@email.com');
INSERT INTO student(birth_date, name, email) values ('2001-02-10', 'Malorie Hawkes','malorie@email.com');
INSERT INTO student(birth_date, name, email) values ('2000-03-09', 'Kara Eckel','kara@email.com');
INSERT INTO student(birth_date, name, email) values ('2001-05-29', 'Gwen Culpepper','gwen@email.com');
INSERT INTO student(birth_date, name, email) values ('2000-04-12', 'Ingrid Palmer','dennis@email.com');

```

## Database configuration

The application will persist data to disk. This is our 'src/main/resources/application.yml':

```
spring:
  h2:
    console:
      enabled: true
      path: /h2
  datasource:
    url: jdbc:h2:file:./db/crud
    driverClassName: org.h2.Driver
    username: sa
    password:
    continueOnError: true
  jpa:
    database-platform: org.hibernate.dialect.H2Dialect
    hibernate:
      ddl-auto: none

```

A few notes:

- we are defining 'path' as '/h2'. This way you can access [H2](http://www.h2database.com/html/main.html) console by hitting 'http://localhost:8080/h2' once you fire up the application;
- by defining 'url' as 'jdbc:h2:file:./db/crud', we are telling to [H2](http://www.h2database.com/html/main.html) that we will persist to disk rather than in memory. The database file will be stored at 'db/crud';
- setting 'continueOnError' to 'true' prevents errors when initializing database with **data.sql**, if some of the records already exists in database.
- remember: we are using JPA and initializing our database via SQL scripts; so we don't want Hibernate do generate the DDL, that's why we are setting 'ddl-auto' to 'none'.

The unit tests will use an in memory database. This is our 'src/test/resources/application.yml':

```
spring:
  datasource:
    driver-class-name: org.h2.Driver
    url: jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1
    username: sa
    password: sa
  jpa:
    database-platform: org.hibernate.dialect.H2Dialect
    hibernate:
      ddl-auto: create-drop
```

A few notes:

- notice 'url' defined as 'jdbc:h2:mem:testdb;DB\_CLOSE\_DELAY=-1'. This is the way to define a [H2](http://www.h2database.com/html/main.html) in memory database;
- since it's a database used for unit testing, we want a fresh database every time we launch the tests. That's why we define 'ddl-auto' as 'create-drop'.

Now, to initialize our in memory test database, we define a file called **import.sql** in 'src/test/resources' folder:

```
INSERT INTO student(birth_date, name, email) values ('2001-01-01', 'Student 1','student1@email.com');
INSERT INTO student(birth_date, name, email) values ('2001-02-10', 'Student 2','student2@email.com');
INSERT INTO student(birth_date, name, email) values ('2000-03-09', 'Student 3','student3@email.com');
INSERT INTO student(birth_date, name, email) values ('2001-05-29', 'Student 4','student4@email.com');
INSERT INTO student(birth_date, name, email) values ('2000-04-12', 'Student 5','student5@email.com');

```

## The classes

It's time to dig in. Let's see how we implement each layer of our API.

### The persistence layer

This is our entity:

```
package com.tiago.entity;

import java.time.LocalDate;
import java.util.Objects;

import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;

/**
 * Entity for table "Student"
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Entity(name = "student")
public class Student {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Integer id;

  private String name;

  private String email;

  private LocalDate birthDate;

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

  public LocalDate getBirthDate() {
    return birthDate;
  }

  public void setBirthDate(LocalDate birthDate) {
    this.birthDate = birthDate;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;

    if (o == null) return false;

    if (this.getClass() != o.getClass()) return false;

    Student student = (Student) o;

    return Objects.equals(getId(), student.getId())
      && Objects.equals(getName(), student.getName())
      && Objects.equals(getEmail(), student.getEmail())
      && Objects.equals(getBirthDate(), student.getBirthDate());
  }

  @Override
  public int hashCode() {
    int hash = 7;

    hash = 31 * hash + Objects.hashCode(id);
    hash = 31 * hash + Objects.hashCode(name);
    hash = 31 * hash + Objects.hashCode(email);
    hash = 31 * hash + Objects.hashCode(birthDate);
    return hash;
  }
}

```

Repository:

```
package com.tiago.repository;

import java.time.LocalDate;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import com.tiago.entity.Student;

/**
 * Repository for {@link Student} entity.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
*/
@Repository
public interface StudentRepository extends JpaRepository<Student, Integer> {

  /**
   * Find all students born between a date range
   *
   * @param fromDate
   * @param toDate
   * @return the list of students
   */
  @Query("SELECT s FROM student s WHERE s.birthDate BETWEEN ?1 and ?2")
  List<Student> findAllStudentsBornBetween(LocalDate fromDate, LocalDate toDate);
}

```

### The service layer

Service class:

```
package com.tiago.service;

import java.time.LocalDate;
import java.util.List;

import com.tiago.entity.Student;
import com.tiago.exception.ResourceNotFoundException;

/**
 * Service to manage students.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
public interface StudentService {

  /**
   * Finds a Student by id
   *
   * @param id
   * @return {@link Student}
   * @throws ResourceNotFoundException if no {@link Student} is found
   */
  Student findById(Integer id);

  /**
   * Find all students born between the desired date range
   *
   * @param fromDate
   * @param toDate
   * @return the list of students
   */
  List<Student> findByBirthDateBetween(LocalDate fromDate, LocalDate toDate);

  /**
   * Find all students
   *
   * @return the list of students
   */
  List<Student> findAll();

  /**
   * Saves a student
   *
   * @param student to be saved
   * @return the saved student
   */
  Student save(Student student);

  /**
   * Deletes a student
   *
   * @param id
   * @throws ResourceNotFoundException if no {@link Student} is found
   */
  void delete(Integer id);
}

```

Service class implementation:

```
package com.tiago.service.impl;

import java.time.LocalDate;
import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.tiago.entity.Student;
import com.tiago.exception.ResourceNotFoundException;
import com.tiago.repository.StudentRepository;
import com.tiago.service.StudentService;

/**
 * Implements {@link StudentService} interface
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Service
public class StudentServiceImpl implements StudentService {

  @Autowired
  StudentRepository repository;

  /* (non-Javadoc)
   * @see com.tiago.service.StudentService#findById(java.lang.Long)
   */
  @Override
  public Student findById(Integer id) {
    Student student = repository.findById(id).orElse(null);

    if (student == null) {
      throw new ResourceNotFoundException(Student.class.getSimpleName(), "id", id);
    }

    return student;
  }

  /* (non-Javadoc)
   * @see com.tiago.service.StudentService#findByBirthDateBetween(java.time.LocalDate, java.time.LocalDate)
   */
  @Override
  public List<Student> findByBirthDateBetween(LocalDate fromDate, LocalDate toDate) {
    return repository.findAllStudentsBornBetween(fromDate, toDate);
  }

  /* (non-Javadoc)
   * @see com.tiago.service.StudentService#findAll()
   */
  @Override
  public List<Student> findAll() {
    return repository.findAll();
  }

  /* (non-Javadoc)
   * @see com.tiago.service.StudentService#save(com.tiago.entity.Student)
   */
  @Override
  public Student save(Student student) {
    return repository.save(student);
  }

  /* (non-Javadoc)
   * @see com.tiago.service.StudentService#delete(java.lang.Long)
   */
  @Override
  public void delete(Integer id) {
    Student student = findById(id);

    repository.delete(student);
  }
}

```

### The controller layer

This is our controller:

```
package com.tiago.controller;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

import javax.validation.Valid;

import org.modelmapper.ModelMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.tiago.dto.StudentDTO;
import com.tiago.entity.Student;
import com.tiago.service.StudentService;

/**
 * Restful controller responsible for managing students
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@RestController
@RequestMapping("/api")
public class StudentController {

  @Autowired
  ModelMapper modelMapper;

  @Autowired
  StudentService service;

  /**
   * Get all students
   *
   * @return the list of students
   */
  @GetMapping("/students")
  public List<StudentDTO> getAllStudents() {
    List<Student> students = service.findAll();

    return students.stream().map(student -> convertToDTO(student)).collect(Collectors.toList());
  }

  /**
   * Get all students that were born between the desired date range
   *
   * @param fromDate
   * @param toDate
   * @return the list of students
   */
  @GetMapping(path = "/students/bornBetween")
  public List<StudentDTO> getAllStudentsThatWereBornBetween(
      @RequestParam(value = "fromDate") @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate fromDate,
      @RequestParam(value = "toDate") @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate toDate) {
    List<Student> students = service.findByBirthDateBetween(fromDate, toDate);

    return students.stream().map(student -> convertToDTO(student)).collect(Collectors.toList());
  }

  /**
   * Creates a student
   *
   * @param studentDTO
   * @return the created student
   */
  @PostMapping("/student")
  public StudentDTO createStudent(@Valid @RequestBody StudentDTO studentDTO) {
    Student student = convertToEntity(studentDTO);

    return convertToDTO(service.save(student));
  }

  /**
   * Updates a student
   *
   * @param studentId
   * @param studentDTO
   * @return the updated student
   */
  @PutMapping("/student/{id}")
  public StudentDTO updateStudent(@PathVariable(value = "id", required = true) Integer studentId,
      @Valid @RequestBody StudentDTO studentDTO) {
    studentDTO.setId(studentId);
    Student student = convertToEntity(studentDTO);

    return convertToDTO(service.save(student));
  }

  /**
   * Deletes a student
   *
   * @param studentId
   * @return 200 OK
   */
  @DeleteMapping("/student/{id}")
  public ResponseEntity<?> deleteStudent(@PathVariable(value = "id") Integer studentId) {
    service.delete(studentId);

    return ResponseEntity.ok().build();
  }

  private StudentDTO convertToDTO(Student student) {
    return modelMapper.map(student, StudentDTO.class);
  }

  private Student convertToEntity(StudentDTO studentDTO) {
    Student student = null;

    if(studentDTO.getId() != null) {
      student = service.findById(studentDTO.getId());
    }

    student = modelMapper.map(studentDTO, Student.class);

    return student;
  }
}

```

### The ExceptionHandlingController

This is our global exception handler: a class annotated with '@ControllerAdvice' that handles exceptions thrown by the controller layer.

```
package com.tiago.exception;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import com.tiago.util.ValidationUtil;

/**
 * This class handles the exceptions thrown by the controller layer.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@ControllerAdvice
public class ExceptionHandlingController {

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

    return new ResponseEntity<ExceptionResponse>(response, HttpStatus.NOT_FOUND);
  }

  /**
   * This exception is thrown when inputs are invalid
   *
   * @param ex
   * @return {@link ExceptionResponse}
   */
  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<ExceptionResponse> invalidInput(MethodArgumentNotValidException ex) {
    BindingResult result = ex.getBindingResult();
    ExceptionResponse response = new ExceptionResponse();
    response.setErrorCode("Bad Request");
    response.setErrorMessage("Invalid inputs");
    response.setErrors(new ValidationUtil().fromBindingErrors(result));
    return new ResponseEntity<ExceptionResponse>(response, HttpStatus.BAD_REQUEST);
  }

  /**
   * This exception is thrown when query string parameter is missing
   *
   * @param ex
   * @return {@link ExceptionResponse}
   */
  @ExceptionHandler(MissingServletRequestParameterException.class)
  public ResponseEntity<ExceptionResponse> missingRequestParameter(MissingServletRequestParameterException ex) {
    ExceptionResponse response = new ExceptionResponse();
    response.setErrorCode("Bad Request");
    response.setErrorMessage(ex.getMessage());

    return new ResponseEntity<ExceptionResponse>(response, HttpStatus.BAD_REQUEST);
  }

  /**
   * This exception is thrown when an error occurs when parsing input JSON
   * or if it's missing
   *
   * @param ex
   * @return {@link ExceptionResponse}
   */
  @ExceptionHandler(HttpMessageNotReadableException.class)
  public ResponseEntity<ExceptionResponse> invalidRequestData(HttpMessageNotReadableException ex) {
    Throwable mostSpecificCause = ex.getMostSpecificCause();

    ExceptionResponse response = new ExceptionResponse();
    response.setErrorCode("Bad Request");

    if (mostSpecificCause != null) {
      String message = mostSpecificCause.getMessage();

      if(message.matches("(.*)Required request body is missing(.*)")) {
        response.setErrorMessage("Missing request body");
      } else {
        response.setErrorMessage(mostSpecificCause.getMessage());
      }
    } else {
      response.setErrorMessage(ex.getMessage());
    }

    return new ResponseEntity<ExceptionResponse>(response, HttpStatus.BAD_REQUEST);
  }

  /**
   * This exception is thrown when an error occurs while parsing the value
   * of a query string parameter
   *
   * @param ex
   * @return {@link ExceptionResponse}
   */
  @ExceptionHandler(MethodArgumentTypeMismatchException.class)
  public ResponseEntity<ExceptionResponse> handleTypeMismatch(MethodArgumentTypeMismatchException ex) {
    String name = ex.getName();
    String type = ex.getRequiredType().getSimpleName();
    Object value = ex.getValue();
    String message = String.format("'%s' should be a valid '%s' and '%s' isn't", name, type, value);

    ExceptionResponse response = new ExceptionResponse();
    response.setErrorCode("Bad Request");
    response.setErrorMessage(message);
    return new ResponseEntity<ExceptionResponse>(response, HttpStatus.BAD_REQUEST);
  }

  /**
   * This exception is thrown when the new record conflicts with an
   * existing record in the database
   *
   * @param ex
   * @return {@link ExceptionResponse}
   */
  @ExceptionHandler(DataIntegrityViolationException.class)
  public ResponseEntity<ExceptionResponse> constraintViolation(DataIntegrityViolationException ex) {
    ExceptionResponse response = new ExceptionResponse();

    response.setErrorCode("Conflict");
    response.setErrorMessage("This student is already registered");

    return new ResponseEntity<ExceptionResponse>(response, HttpStatus.CONFLICT);
  }

  /**
   * This is a general catching exception
   *
   * @param ex
   * @return {@link ExceptionResponse}
   */
  @ExceptionHandler(Exception.class)
  public ResponseEntity<ExceptionResponse> handleException(Exception ex) {
    ExceptionResponse response = new ExceptionResponse();
    response.setErrorCode("error");
    response.setErrorMessage(ex.getMessage());

    return new ResponseEntity<ExceptionResponse>(response, HttpStatus.INTERNAL_SERVER_ERROR);
  }
}

```

### The ExceptionResponse

This class represents the error JSON message that will be presented to the final user:

```
package com.tiago.exception;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * This class holds information of a given exception.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ExceptionResponse {
  private String errorCode;
  private String errorMessage;
  private List<String> errors;

  public ExceptionResponse() {
  }

  public String getErrorCode() {
    return errorCode;
  }

  public void setErrorCode(String errorCode) {
    this.errorCode = errorCode;
  }

  public String getErrorMessage() {
    return errorMessage;
  }

  public void setErrorMessage(String errorMessage) {
    this.errorMessage = errorMessage;
  }

  public List<String> getErrors() {
    return errors;
  }

  public void setErrors(List<String> errors) {
    this.errors = errors;
  }
}

```

### The ValidationUtil

This is a utility class that helps formatting error messages coming from validation errors:

```
package com.tiago.util;

import java.util.ArrayList;
import java.util.List;

import org.springframework.validation.Errors;
import org.springframework.validation.ObjectError;

import com.tiago.exception.ExceptionHandlingController;

/**
 * Utility class used in {@link ExceptionHandlingController} to build errors.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
public class ValidationUtil {

	/**
	 * Builds a list of validation errors.
	 *
	 * @param errors
	 * @return the list of validations errors
	 */
	public List<String> fromBindingErrors(Errors errors) {
		List<String> validationErrors = new ArrayList<String>();
		for (ObjectError objectError : errors.getAllErrors()) {
			validationErrors.add(objectError.getDefaultMessage());
		}
		return validationErrors;
	}
}

```

## It's show time!

Now let's explore our API. This is what it does:

- **GET /api/students**: returns a list of students;
- **GET /api/students/bornBetween?fromDate=<yyyy-MM-dd>&toDate=<yyyy-MM-dd>**: returns a list of students born between a desired date range;
- **POST /api/student**: creates a student from a JSON in the request body;
- **PUT /api/student/{id}**: updates a student with the given ID, from a JSON in the request body;
- **DELETE /api/student/{id}**: deletes a student with the given ID.

For each endpoint we'll test failure scenarios, if applicable, showing how the application handles error messages.

We'll use [cURL](https://curl.haxx.se/) to test it.

Fire up the server:

```
crud-exceptionhandling-example$ mvn spring-boot:run

```

### Testing GET /api/students

Let's see how it is implemented in our controller:

```
/**
 * Get all students
 *
 * @return the list of students
 */
@GetMapping("/students")
public List<StudentDTO> getAllStudents() {
  List<Student> students = service.findAll();

  return students.stream().map(student -> convertToDTO(student)).collect(Collectors.toList());
}

```

As mentioned ealier, we are using [DTO](https://en.wikipedia.org/wiki/Data_transfer_object) to avoid exposing the entity directly.

[Cassio Mazzochi](https://stackoverflow.com/users/1426227/cassio-mazzochi-molin) gave a really good [explanation](https://stackoverflow.com/a/36175349) about why it's a good idea to use [DTO](https://en.wikipedia.org/wiki/Data_transfer_object) s in a RESTFul API:

> This pattern was created with a very well defined purpose:
>  **transfer data to _remote interfaces_**, just like
>  _web services_.This pattern fits very well in a REST API and DTOs will give you more
>  _flexibility_ in the long run. REST resources representations don't need to have the same attributes as the persistence models: you may need to omit, add or rename attributes.

We are using [ModelMapper](http://modelmapper.org/) to map [DTO](https://en.wikipedia.org/wiki/Data_transfer_object) s to entities and vice-versa.

So, this is how we map 'Student' entity to 'StudentDTO':

```
private StudentDTO convertToDTO(Student student) {
  return modelMapper.map(student, StudentDTO.class);
}
```

Pretty straightforward. By [reflection](https://en.wikipedia.org/wiki/Reflection_(computer_programming)), all fields with the same name in 'StudentDTO' are mapped to 'Student' fields.

Now let's call the endpoint:

```
crud-exceptionhandling-example$ curl -v "http://localhost:8080/api/students"

```

As we initialized our database, we'll get:

```
[
  {
    "id": 1,
    "name": "Marcelino Lund",
    "email": "marcelino@email.com",
    "birthDate": "2001-01-01"
  },
  {
    "id": 2,
    "name": "Malorie Hawkes",
    "email": "malorie@email.com",
    "birthDate": "2001-02-10"
  },
  {
    "id": 3,
    "name": "Kara Eckel",
    "email": "kara@email.com",
    "birthDate": "2000-03-09"
  },
  {
    "id": 4,
    "name": "Gwen Culpepper",
    "email": "gwen@email.com",
    "birthDate": "2001-05-29"
  },
  {
    "id": 5,
    "name": "Ingrid Palmer",
    "email": "dennis@email.com",
    "birthDate": "2000-04-12"
  }
]
```

### Testing GET /api/students/bornBetween?fromDate=<yyyy-MM-dd>&toDate=<yyyy-MM-dd>

Let's see how it is implemented in our controller:

```
/**
 * Get all students that were born between the desired date range
 *
 * @param fromDate
 * @param toDate
 * @return the list of students
 */
@GetMapping(path = "/students/bornBetween")
public List<StudentDTO> getAllStudentsThatWereBornBetween(
  @RequestParam(value = "fromDate") @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate fromDate,
  @RequestParam(value = "toDate") @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate toDate) {

  List<Student> students = service.findByBirthDateBetween(fromDate, toDate);

  return students.stream().map(student -> convertToDTO(student)).collect(Collectors.toList());
}

```

So, through '@DateTimeFormat' we are specifying the format that we are expecting.

Possible errors:

- missing 'fromDate' parameter;
- missing 'toDate' parameter;
- 'fromDate' parameter with an invalid date;
- 'toDate' parameter with an invalid date.

Let's begin with the first possibility, missing 'fromDate' parameter:

```
crud-exceptionhandling-example$ curl -v "http://localhost:8080/api/students/bornBetween?toDate=2001-03-01"

```

This is the result:

```
< HTTP/1.1 400
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
< Date: Fri, 15 Feb 2019 02:29:42 GMT
< Connection: close
<
* Closing connection 0
{"errorCode":"Bad Request","errorMessage":"Required LocalDate parameter 'fromDate' is not present"}

```

Now if we miss 'toDate' parameter:

```
crud-exceptionhandling-example$ curl -v "http://localhost:8080/api/students/bornBetween?fromDate=2001-03-01"

```

This is the result:

```
< HTTP/1.1 400
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
< Date: Fri, 15 Feb 2019 02:29:42 GMT
< Connection: close
<
* Closing connection 0
{"errorCode":"Bad Request","errorMessage":"Required LocalDate parameter 'toDate' is not present"}

```

When a request parameter is missing, a 'MissingServletRequestParameterException' is thrown. And we are handling it in our 'ExceptionHandlingController':

```
/**
 * This exception is thrown when query string parameter is missing
 *
 * @param ex
 * @return {@link ExceptionResponse}
 */
@ExceptionHandler(MissingServletRequestParameterException.class)
public ResponseEntity<ExceptionResponse> missingRequestParameter(MissingServletRequestParameterException ex) {
  ExceptionResponse response = new ExceptionResponse();
  response.setErrorCode("Bad Request");
  response.setErrorMessage(ex.getMessage());

  return new ResponseEntity<ExceptionResponse>(response, HttpStatus.BAD_REQUEST);
}

```

Now, if 'fromDate' is an invalid date:

```
crud-exceptionhandling-example$ curl -v "http://localhost:8080/api/students/bornBetween?fromDate=hahaha&toDate=2001-03-1"

```

This is the result:

```
< HTTP/1.1 400
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
< Date: Fri, 15 Feb 2019 02:38:48 GMT
< Connection: close
<
* Closing connection 0

{"errorCode":"Bad Request","errorMessage":"'fromDate' should be a valid 'LocalDate' and 'hahaha' isn't"}

```

And if 'toDate' is an invalid date:

```
crud-exceptionhandling-example$ curl -v "http://localhost:8080/api/students/bornBetween?fromDate=2001-03-01&toDate=hahaha"

```

This is the result:

```
< HTTP/1.1 400
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
< Date: Fri, 15 Feb 2019 02:38:48 GMT
< Connection: close
<
* Closing connection 0
{"errorCode":"Bad Request","errorMessage":"'toDate' should be a valid 'LocalDate' and 'hahaha' isn't"}

```

When a request parameter fails the expected data type, a 'MethodArgumentTypeMismatchException' is thrown. And we are handling it in our 'ExceptionHandlingController':

```
/**
 * This exception is thrown when an error occurs while parsing the value
 * of a query string parameter
 *
 * @param ex
 * @return {@link ExceptionResponse}
 */
public ResponseEntity<ExceptionResponse> handleTypeMismatch(MethodArgumentTypeMismatchException ex) {
  String name = ex.getName();
  String type = ex.getRequiredType().getSimpleName();
  Object value = ex.getValue();
  String message = String.format("'%s' should be a valid '%s' and '%s' isn't", name, type, value);

  ExceptionResponse response = new ExceptionResponse();
  response.setErrorCode("Bad Request");
  response.setErrorMessage(message);

  return new ResponseEntity<ExceptionResponse>(response, HttpStatus.BAD_REQUEST);
}

  @ExceptionHandler(MethodArgumentTypeMismatchException.class)

```

### Testing POST /api/student:

Let's see how it is implemented in our controller:

```
/**
 * Creates a student
 *
 * @param studentDTO
 * @return the created student
 */
@PostMapping("/student")

public StudentDTO createStudent(@Valid @RequestBody StudentDTO studentDTO) {
  Student student = convertToEntity(studentDTO);

  return convertToDTO(service.save(student));
}

```

By using '@RequestBody' annotation we are mapping the _HttpRequest_ body to a transfer or domain object, enabling automatic deserialization of the inbound _HttpRequest_ body onto a Java object. In other words, we are mapping the JSON that we will pass in the request body to a 'StudentDTO' object.

By using '@Valid' annotation we are triggering all validation annotations in 'StudentDTO'.

Take a look at 'StudentDTO' class:

```
package com.tiago.dto;

import java.time.LocalDate;

import javax.validation.constraints.Email;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * DTO with Student information.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public class StudentDTO {

  private Integer id;

  @NotBlank(message = "'name' property is missing")
  private String name;

  @NotBlank(message = "'email' property is missing")
  @Email
  private String email;

  @NotNull(message = "'birthDate' property is missing")
  private LocalDate birthDate;

  // getters and setters ommited
}

```

See that we are using validation annotations like '@NotBlank' and '@NotNull' that validates the presence of the annotated fields, and '@Email' that validates if the annotated field is a well-formed email address.

Possible errors:

- missing 'name' property;
- missing 'email' property;
- missing 'birthDate' property;
- malformed 'email' property;
- invalid date format in 'birthDate' property;
- missing request body;
- inserting a Student that is already registered.

Let's begin with missing 'name' property:

```
crud-exceptionhandling-example$ curl -v -H "Content-Type: application/json" -X POST "http://localhost:8080/api/student" -d '{"email":"tiago@email.com", "birthDate":"1983-02-01"}'

```

This is the result:

```
< HTTP/1.1 400
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
< Date: Fri, 15 Feb 2019 02:57:36 GMT
< Connection: close
<
* Closing connection 0

{"errorCode":"Bad Request","errorMessage":"Invalid inputs","errors":["'name' property is missing"]}

```

Now if we miss 'email' property:

```
crud-exceptionhandling-example$ curl -v -H "Content-Type: application/json" -X POST "http://localhost:8080/api/student" -d '{"name":"tiago", "birthDate":"1983-02-01"}'

```

This is the result:

```
< HTTP/1.1 400
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
< Date: Fri, 15 Feb 2019 02:59:57 GMT
< Connection: close
<
* Closing connection 0

{"errorCode":"Bad Request","errorMessage":"Invalid inputs","errors":["'email' property is missing"]}

```

Now if 'email' is a malformed email address:

```
crud-exceptionhandling-example$ curl -v -H "Content-Type: application/json" -X POST "http://localhost:8080/api/student" -d '{"name":"tiago", "email":"invalid", "birthDate":"1983-02-01"}'

```

This is the result:

```
< HTTP/1.1 400
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
< Date: Fri, 15 Feb 2019 03:07:41 GMT
< Connection: close
<
* Closing connection 0

{"errorCode":"Bad Request","errorMessage":"Invalid inputs","errors":["must be a well-formed email address"]}

```

Now if we miss 'birthDate' property:

```
crud-exceptionhandling-example$ curl -v -H "Content-Type: application/json" -X POST "http://localhost:8080/api/student" -d '{"name":"tiago", "email":"tiago@email.com"}'

```

This is the result:

```
< HTTP/1.1 400
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
< Date: Fri, 15 Feb 2019 03:01:47 GMT
< Connection: close
<
* Closing connection 0

{"errorCode":"Bad Request","errorMessage":"Invalid inputs","errors":["'birthDate' property is missing"]}

```

As mentioned earlier, the input JSON will be mapped into a 'StudentDTO' object. And if any validation annotation in the DTO is violated, like '@NotBlank' or '@Email' for example, a 'MethodArgumentNotValidException' is thrown. And we are handling it in our 'ExceptionHandlingController':

```
/**
 * This exception is thrown when inputs are invalid
 *
 * @param ex
 * @return {@link ExceptionResponse}
 */
@ExceptionHandler(MethodArgumentNotValidException.class)
public ResponseEntity<ExceptionResponse> invalidInput(MethodArgumentNotValidException ex) {
  BindingResult result = ex.getBindingResult();
  ExceptionResponse response = new ExceptionResponse();
  response.setErrorCode("Bad Request");
  response.setErrorMessage("Invalid inputs");
  response.setErrors(new ValidationUtil().fromBindingErrors(result));

  return new ResponseEntity<ExceptionResponse>(response, HttpStatus.BAD_REQUEST);
}

```

Now if 'birthDate' is an invalid date:

```
crud-exceptionhandling-example$ curl -v -H "Content-Type: application/json" -X POST "http://localhost:8080/api/student" -d '{"name":"tiago", "email":"tiago@email.com", "birthDate":"hahaha"}'

```

This is the result:

```
< HTTP/1.1 400
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
< Date: Fri, 15 Feb 2019 03:17:16 GMT
< Connection: close
<
* Closing connection 0

{"errorCode":"Bad Request","errorMessage":"Text 'hahaha' could not be parsed at index 0"}

```

Now if we don't pass any JSON:

```
crud-exceptionhandling-example$ curl -v -H "Content-Type: application/json" -X POST "http://localhost:8080/api/student"

```

This is the result:

```
< HTTP/1.1 400
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
< Date: Fri, 15 Feb 2019 03:19:21 GMT
< Connection: close
<
* Closing connection 0
{"errorCode":"Bad Request","errorMessage":"Missing request body"}

```

When an error occurs when parsing the input JSON or if it's missing, a 'HttpMessageNotReadableException' is thrown. And we are handling it in our 'ExceptionHandlingController':

```
/**
 * This exception is thrown when an error occurs when parsing input JSON
 * or if it's missing
 *
 * @param ex
 * @return {@link ExceptionResponse}
 */
@ExceptionHandler(HttpMessageNotReadableException.class)
public ResponseEntity<ExceptionResponse> invalidRequestData(HttpMessageNotReadableException ex) {
  Throwable mostSpecificCause = ex.getMostSpecificCause();

  ExceptionResponse response = new ExceptionResponse();
  response.setErrorCode("Bad Request");

  if (mostSpecificCause != null) {
    String message = mostSpecificCause.getMessage();

    if(message.matches("(.*)Required request body is missing(.*)")) {
      response.setErrorMessage("Missing request body");
    } else {
      response.setErrorMessage(mostSpecificCause.getMessage());
    }
  } else {
    response.setErrorMessage(ex.getMessage());
  }

  return new ResponseEntity<ExceptionResponse>(response, HttpStatus.BAD_REQUEST);
}

```

Now if we try to insert a Student that is already registered:

```
crud-exceptionhandling-example$ curl -v -H "Content-Type: application/json" -X POST "http://localhost:8080/api/student" -d '{"name":"tiago", "email":"email@email.com", "birthDate":"2000-01-01"}'

```

This is the result:

```
< HTTP/1.1 409
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
< Date: Fri, 15 Feb 2019 03:28:47 GMT
<
* Connection #0 to host localhost left intact

{"errorCode":"Conflict","errorMessage":"This student is already registered"}

```

When a constraint is violated in the database, a 'DataIntegrityViolationException' is thrown. And we are handling it in our 'ExceptionHandlingController':

```
/**
 * This exception is thrown when the new record conflicts with an
 * existing record in the database
 *
 * @param ex
 * @return {@link ExceptionResponse}
 */
@ExceptionHandler(DataIntegrityViolationException.class)

public ResponseEntity<ExceptionResponse> constraintViolation(DataIntegrityViolationException ex) {
  ExceptionResponse response = new ExceptionResponse();

  response.setErrorCode("Conflict");
  response.setErrorMessage("This student is already registered");

  return new ResponseEntity<ExceptionResponse>(response, HttpStatus.CONFLICT);
}

```

### Testing PUT /api/student/{id}

Let's see how it is implemented in our controller:

```
/**
 * Updates a student
 *
 * @param studentId
 * @param studentDTO
 * @return the updated student
 */

@PutMapping("/student/{id}")
public StudentDTO updateStudent(@PathVariable(value = "id", required = true) Integer studentId,
    @Valid @RequestBody StudentDTO studentDTO) {
  studentDTO.setId(studentId);
  Student student = convertToEntity(studentDTO);

  return convertToDTO(service.save(student));
}

```

Possible errors:

- missing 'name', 'email' and 'birthDate' properties: will happen the same as we saw in POST /api/student;
- malformed 'email' property: will happen the same as we saw in POST /api/student;
- invalid date format in 'birthDate' property: will happen the same as we saw in POST /api/student;
- missing request body: will happen the same as we saw in POST /api/student;
- no student is found for the given id.

If we try to update an non-existing student:

```
crud-exceptionhandling-example$ curl -v -H "Content-Type: application/json" -X PUT "http://localhost:8080/api/student/666" -d '{"name":"tiago", "email":"email@email.com", "birthDate":"2000-01-01"}'

```

This is the result:

```
< HTTP/1.1 404
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
< Date: Fri, 15 Feb 2019 03:38:42 GMT
<
* Connection #0 to host localhost left intact

{"errorCode":"Not Found","errorMessage":"Student not found with id: '666'"}

```

When a record is not found in the database, a custom 'ResourceNotFoundException' is thrown. And we are handling it in our 'ExceptionHandlingController':

```
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

  return new ResponseEntity<ExceptionResponse>(response, HttpStatus.NOT_FOUND);
}

```

### Testing DELETE /api/student/{id}

Let's see how it is implemented in our controller:

```
/**
 * Deletes a student
 *
 * @param studentId
 * @return 200 OK
 */
@DeleteMapping("/student/{id}")

public ResponseEntity<?> deleteStudent(@PathVariable(value = "id") Integer studentId) {
  service.delete(studentId);

  return ResponseEntity.ok().build();
}

```

Possible errors:

- no student is found for the given id: will happen the same as we saw in PUT /api/student/{id}

## Unit testing

I like to use [JaCoCo](https://www.eclemma.org/jacoco/) to check for test coverage. I usually exclude the main spring boot class.

It can be used as a Maven plugin as follows:

```
<build>
   <plugins>
      <plugin>
         <groupId>org.springframework.boot</groupId>
         <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
      <plugin>
         <groupId>org.jacoco</groupId>
         <artifactId>jacoco-maven-plugin</artifactId>
         <version>0.8.3</version>
         <configuration>
            <excludes>
               <exclude>**/CrudExceptionhandlingExampleApplication.class</exclude>
            </excludes>
         </configuration>
         <executions>
            <execution>
               <goals>
                  <goal>prepare-agent</goal>
               </goals>
            </execution>
            <execution>
               <id>report</id>
               <phase>prepare-package</phase>
               <goals>
                  <goal>report</goal>
               </goals>
            </execution>
         </executions>
      </plugin>
   </plugins>
</build>

```

To check test coverage, fire up with maven:

```
crud-exceptionhandling-example$ mvn test && mvn jacoco:report

```

The report will be available at 'target/site/jacoco/index.html':

![No alt text provided for this image](/assets/images/2019-02-15-e3ae59fd-0d46-40c5-97e9-a5c8791d1145/1550203405893.png)

## Conclusion

Through this simple example we learnt how we can handle exceptions globally with '@ControllerAdvice' annotation. It's very useful to centralize error handling logic, thus reducing duplicate code and keeping your code cleaner.

## Download the source code

Here: [https://bitbucket.org/tiagoharris/crud-exceptionhandling-example/src/master/](https://bitbucket.org/tiagoharris/crud-exceptionhandling-example/src/master/)
