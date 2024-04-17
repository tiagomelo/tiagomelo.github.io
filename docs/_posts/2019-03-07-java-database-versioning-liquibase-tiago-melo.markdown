---
layout: post
title:  "Java: database versioning with Liquibase"
date:   2019-03-07 13:26:01 -0300
categories: java springboot liquibase
---
![Java: database versioning with Liquibase](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/2019-03-07-banner.jpeg)

Versioning database changes is as important as versioning source code. By using a database migration tool we can safely manage how the database evolves, instead of running a bunch of non versioned loose [SQL](https://en.wikipedia.org/wiki/SQL) files.

In some frameworks like [Ruby On Rails](https://rubyonrails.org/), database versioning occurs along the development. But when it comes to [Java](https://www.java.com) world, I don't see it happening so often.

In this article we’ll see how to integrate [Liquibase](http://www.liquibase.org/) with [Spring Boot](https://spring.io/projects/spring-boot) to evolve the database schema of a [Java](https://www.java.com/) application using [MySQL](https://dev.mysql.com/).

## Meet Liquibase

Currently, the most popular database tools are [Flyway](https://flywaydb.org/) and [Liquibase](http://www.liquibase.org/). I've choose the latter due to these benefits:

- It's database agnostic - it works for all major database vendors;
- You can specify your changes in [XML](https://en.wikipedia.org/wiki/XML), [YAML](https://en.wikipedia.org/wiki/YAML) , [JSON](https://en.wikipedia.org/wiki/JSON) and [SQL](https://en.wikipedia.org/wiki/SQL) formats.

We'll use [YAML](https://en.wikipedia.org/wiki/YAML) format.

### Liquibase concepts

These are the key concepts:

- **changeLog**: a file that keeps track of all changes that need to run to update the DB;
- **changeSet**: these are atomic changes that would be applied to the database. Each _changeSet_ is uniquely identified by 'id' and 'author'. Each _changeset_ is run as a single transaction.

## The domain model

This is our initial domain model that will be evolved during this article:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551889004894.png)

The ' _Library_' table has a [One To Many](https://en.wikipedia.org/wiki/One-to-many_(data_model)) relationship with ' _Book_' table.

## The Rails way

When I had my first experience with [Ruby On Rails](https://rubyonrails.org/), back in 2007, the first feature that caught my attention was [Active Record Migrations](https://guides.rubyonrails.org/active_record_migrations.html). [Active Record](https://guides.rubyonrails.org/active_record_basics.html) is the [ORM](https://en.wikipedia.org/wiki/Object-relational_mapping) framework shipped with [Ruby On Rails](https://rubyonrails.org/).

So, for the given domain model above, to generate a migration file that create the two tables:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551889803190.png)

A migration file is created. Then, we add instructions:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551889938427.png)

Alright. Let's fire up the server:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551895942650.png)

Then, using [cURL](https://curl.haxx.se), if we try to access ' _Book_' resource, for example:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551896191865.png)

We'll get an error, as we can see at server's log:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551896438272.png)

Self-explanatory: we need to run the migration that will create the tables. Like this:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551896719171.png)

Let's check in [MySQL](https://dev.mysql.com/). Both tables were created:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551896923746.png)

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551896938603.png)

OK. suppose that we need to add two fields to ' _Books_' table: ' _isbn_' and ' _publisher_'. To accomplish this, we create another migration file like this:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551897245410.png)

Then we open the migration file and add the instructions:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551897570482.png)

Let's run this migration:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551897757734.png)

If we check the table again, both fields were added:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551898329969.png)

What if ' _publisher_' field is not necessary anymore? Let's create a migration to fix this:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551898508752.png)

This is the migration file:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551898618784.png)

Let's run this migration:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551898930992.png)

Now if we check the table, ' _publisher_' field was removed:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551899277332.png)

## The Java way

How can we do the same in a Java application?

[Liquibase](http://www.liquibase.org/) can be seamless integrated with [Spring Boot](https://spring.io/projects/spring-boot), so let's begin.

### Creating the project

[Spring Initializr](http://start.spring.io/) is our start point:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551920253393.png)

We've choose the following dependencies:

- [MySQL](https://dev.mysql.com/downloads/connector/j/8.0.html): to add 'mysql-connector-java' jar to our project;
- [JPA](https://docs.spring.io/spring-boot/docs/current/reference/html/using-boot-build-systems.html#spring-boot-starter-data-jpa): Starter for using Spring Data JPA with Hibernate;
- [Liquibase](https://www.liquibase.org/): Starter for using [Liquibase](https://www.liquibase.org/);
- [Rest Repositories](https://spring.io/projects/spring-data-rest): Starter for exposing Spring Data repositories over REST using Spring Data REST.

Additionally, I'm using [Liquibase Maven plugin](https://www.liquibase.org/documentation/maven/maven_update.html) to ease calling [Liquibase](https://www.liquibase.org/) from command line as we'll see in the following examples.

This is the dependency:

```
<dependency>
	<groupId>org.liquibase</groupId>
	<artifactId>liquibase-maven-plugin</artifactId>
	<version>3.6.3</version>
</dependency>

```

And this is its configuration:

```
<build>
	<plugins>
		<plugin>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-maven-plugin</artifactId>
		</plugin>
		<plugin>
			<groupId>org.liquibase</groupId>
			<artifactId>liquibase-maven-plugin</artifactId>
			<version>3.6.3</version>
			<configuration>
				<propertyFile>src/main/resources/liquibase.yml</propertyFile>
			</configuration>
		</plugin>
	</plugins>
</build>

```

As stated in a [previous post](https://www.linkedin.com/pulse/spring-boot-example-crud-restful-api-global-exception-tiago-melo/), I rather not to expose entities or repositories directly, but just for the sake of demonstration, I'll use [Rest Repositories](https://spring.io/projects/spring-data-rest) this time. It makes it easy to build hypermedia-driven REST web services on top of [Spring Data](https://spring.io/projects/spring-data) repositories.

### Configuration

This is our ' _src/main/resources/application.yml_' file:

```
spring:
   datasource:
      url: jdbc:mysql://localhost:3306/liquibase_test?useSSL=false
      username: root
      password:

   jpa:
      hibernate:
         dialect: org.hibernate.dialect.MySQL5InnoDBDialect
         ddl-auto: none

   liquibase:
      change-log: classpath:db/liquibase-changelog.yml

```

A few notes:

- by setting ' _spring.jpa.hibernate.ddl-auto_' to ' _none_', the schema generation will be delegated to [Liquibase](https://www.liquibase.org/);
- by default, [Liquibase](https://www.liquibase.org/)'s changeLog file is expected to be in ' _db/changelog/db.changelog-master.yaml'_; but we are changing it by setting ' _spring.liquibase.change-log_' to put it in ' _src/main/resources/db/liquibase-changelog.yml_'.

And this is our ' _src/main/resources/liquibase.yml_' file, which is used by [Liquibase Maven plugin](https://www.liquibase.org/documentation/maven/maven_update.html):

```
url: jdbc:mysql://localhost:3306/liquibase_test?useSSL=false
username: root
password:
driver: com.mysql.cj.jdbc.Driver
outputChangeLogFile: src/main/resources/db/liquibase-OutputChangelog.yml

```

### The entities

This is our ' _Book_' entity:

```
package com.tiago.entity;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.JoinColumn;
import javax.persistence.ManyToOne;

/**
 * Entity for table "Book"
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Entity
public class Book {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable=false)
  private String title;

  @ManyToOne
  @JoinColumn(name="library_id")
  private Library library;

  public Long getId() {
    return id;
  }

  public void setId(Long id) {
    this.id = id;
  }

  public String getTitle() {
    return title;
  }

  public void setTitle(String title) {
    this.title = title;
  }

  public Library getLibrary() {
    return library;
  }

  public void setLibrary(Library library) {
    this.library = library;
  }
}

```

And this is our ' _Library_' entity:

```
package com.tiago.entity;

import java.util.List;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.OneToMany;

/**
 * Entity for table "Library"
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Entity
public class Library {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable=false)
  private String name;

  @OneToMany(mappedBy = "library")
  private List<Book> books;

  public Long getId() {
    return id;
  }

  public void setId(Long id) {
    this.id = id;
  }

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  public List<Book> getBooks() {
    return books;
  }

  public void setBooks(List<Book> books) {
    this.books = books;
  }
}

```

### The repositories

As mentioned earlier, since we are using [Rest Repositories](https://spring.io/projects/spring-data-rest), there's no need to write controllers; the repositories will be exposed directly.

This is our ' _BookRepository_':

```
package com.tiago.repository;

import org.springframework.data.repository.CrudRepository;

import com.tiago.entity.Book;

/**
 * Repository for {@link Book} entity.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
*/
public interface BookRepository extends CrudRepository<Book, Long> { }

```

And this is our ' _LibraryRepository_':

```
package com.tiago.repository;

import org.springframework.data.repository.CrudRepository;

import com.tiago.entity.Library;

/**
 * Repository for {@link Library} entity.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
*/
public interface LibraryRepository extends CrudRepository<Library, Long> { }

```

### Organizing our changelogs (migration files)

Let's take a look at our directory structure:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551923533445.png)

This is ' _src/main/resources/db/liquibase-changelog.yml_' file:

```
databaseChangeLog:
- includeAll:
   path: db/changelog/

```

We are telling [Liquibase](https://www.liquibase.org/) to execute all changelog files in ' _src/main/resources/db/changelog/_' directory.

### Changelog \#1: creating the tables

As a general rule, let's adopt the following naming convention:

```
<migration_number>_<what_does_this_migration_do>.yml

```

This way, [Liquibase](https://www.liquibase.org/) will execute changelogs ordered by its number.

This is our ' _1\_create\_book\_and\_library\_tables.yml_' file. As the name implies, it creates the tables:

```
databaseChangeLog:
- changeSet:
   author: "tiago"
   id: "creates_library_table"
   changes:
      - createTable:
         tableName: "library"
         columns:
            - column:
               name: "id"
               type: "BIGINT"
               autoIncrement: "true"
               constraints:
                  primaryKey: "true"
            - column:
               name: "name"
               type: "VARCHAR(255)"
               constraints:
                  nullable: "false"
                  unique: "true"

- changeSet:
   author: "tiago"
   id: "creates_book_table"
   changes:
      - createTable:
         tableName: "book"
         columns:
            - column:
               name: "id"
               type: "BIGINT"
               autoIncrement: "true"
               constraints:
                  primaryKey: "true"
            - column:
               name: "title"
               type: "VARCHAR(255)"
               constraints:
                  nullable: "false"
                  unique: "true"
            - column:
               name: "library_id"
               type: "BIGINT"
               constraints:
                  foreignKeyName: "fk_book_library"
                  references: "library(id)"

```

Differently from [Rails](https://rubyonrails.org/), when we fire up the server, the changelogs will be automatically executed. Let's see:

```
$ mvn spring-boot:run

```

Taking a look at server's log, we notice that the two tables were created:

```
2019-03-06 23:17:14.103  INFO 29090 --- [           main] liquibase.executor.jvm.JdbcExecutor      : SELECT COUNT(*) FROM liquibase_test.DATABASECHANGELOG
2019-03-06 23:17:14.104  INFO 29090 --- [           main] l.c.StandardChangeLogHistoryService      : Reading from liquibase_test.DATABASECHANGELOG
2019-03-06 23:17:14.105  INFO 29090 --- [           main] liquibase.executor.jvm.JdbcExecutor      : SELECT * FROM liquibase_test.DATABASECHANGELOG ORDER BY DATEEXECUTED ASC, ORDEREXECUTED ASC
2019-03-06 23:17:14.106  INFO 29090 --- [           main] liquibase.executor.jvm.JdbcExecutor      : SELECT COUNT(*) FROM liquibase_test.DATABASECHANGELOGLOCK
2019-03-06 23:17:14.123  INFO 29090 --- [           main] liquibase.executor.jvm.JdbcExecutor      : CREATE TABLE liquibase_test.library (id BIGINT AUTO_INCREMENT NOT NULL, name VARCHAR(255) NOT NULL, CONSTRAINT PK_LIBRARY PRIMARY KEY (id), UNIQUE (name))
2019-03-06 23:17:14.145  INFO 29090 --- [           main] liquibase.changelog.ChangeSet            : Table library created
2019-03-06 23:17:14.145  INFO 29090 --- [           main] liquibase.changelog.ChangeSet            : ChangeSet db/changelog/1_create_book_and_library_tables.yml::creates_library_table::tiago ran successfully in 23ms
2019-03-06 23:17:14.146  INFO 29090 --- [           main] liquibase.executor.jvm.JdbcExecutor      : SELECT MAX(ORDEREXECUTED) FROM liquibase_test.DATABASECHANGELOG
2019-03-06 23:17:14.148  INFO 29090 --- [           main] liquibase.executor.jvm.JdbcExecutor      : INSERT INTO liquibase_test.DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, `DESCRIPTION`, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE, DEPLOYMENT_ID) VALUES ('creates_library_table', 'tiago', 'db/changelog/1_create_book_and_library_tables.yml', NOW(), 1, '8:a4b142ffda1ccd5c1840ddad83e249b5', 'createTable tableName=library', '', 'EXECUTED', NULL, NULL, '3.6.3', '1925034107')
2019-03-06 23:17:14.151  INFO 29090 --- [           main] liquibase.executor.jvm.JdbcExecutor      : CREATE TABLE liquibase_test.book (id BIGINT AUTO_INCREMENT NOT NULL, title VARCHAR(255) NOT NULL, library_id BIGINT NULL, CONSTRAINT PK_BOOK PRIMARY KEY (id), CONSTRAINT fk_book_library FOREIGN KEY (library_id) REFERENCES liquibase_test.library(id), UNIQUE (title))
2019-03-06 23:17:14.173  INFO 29090 --- [           main] liquibase.changelog.ChangeSet            : Table book created
2019-03-06 23:17:14.174  INFO 29090 --- [           main] liquibase.changelog.ChangeSet            : ChangeSet db/changelog/1_create_book_and_library_tables.yml::creates_book_table::tiago ran successfully in 24ms
2019-03-06 23:17:14.175  INFO 29090 --- [           main] liquibase.executor.jvm.JdbcExecutor      : INSERT INTO liquibase_test.DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, `DESCRIPTION`, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE, DEPLOYMENT_ID) VALUES ('creates_book_table', 'tiago', 'db/changelog/1_create_book_and_library_tables.yml', NOW(), 2, '8:a54634bf0781ac011818976bf5e36351', 'createTable tableName=book', '', 'EXECUTED', NULL, NULL, '3.6.3', '1925034107')
2019-03-06 23:17:14.186  INFO 29090 --- [           main] l.lockservice.StandardLockService        : Successfully released change log lock

```

Let's check them in [MySQL](https://dev.mysql.com/):

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551925472278.png)

Great.

Now, using [cURL](https://curl.haxx.se/), let's access the ' _Book_' resource:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551926433999.png)

No books as expected. The same occurs with ' _Library_' resource:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551926525268.png)

### Changelog \#2 and \#3: initialization data

Let's see how we can initialize our tables.

This is ' _2\_insert\_data\_books.yml_':

```
databaseChangeLog:
- changeSet:
   author: "tiago"
   id: "insert_data_books"
   changes:
      - insert:
         tableName: "book"
         columns:
            - column:
               name: "title"
               value: "Test Book 1"

```

And this is ' _3\_insert\_data\_library.yml_':

```
databaseChangeLog:
- changeSet:
   author: "tiago"
   id: "insert_data_library"
   changes:
      - insert:
         tableName: "library"
         columns:
            - column:
               name: "name"
               value: "Library 1"

```

Now let's try something different. Instead of firing up the server to make [Liquibase](https://www.liquibase.org/) to run these changelogs, we'll do it by using the [Maven plugin](https://www.liquibase.org/documentation/maven/maven_update.html):

```
$ mvn liquibase:update -Dliquibase.changeLogFile=db/liquibase-changelog.yml

```

This is the output:

```
[INFO] INSERT INTO book (title) VALUES ('Test Book 1')
[INFO] New row inserted into book
[INFO] INSERT INTO book (title) VALUES ('Test Book 2')
[INFO] New row inserted into book

...
[INFO] INSERT INTO library (name) VALUES ('Library 1')
[INFO] New row inserted into library
....

```

Then, if we fire up the server and access ' _Book_' resource again...

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551927356995.png)

Take a look at this:

```
"library" : {
   "href" : "http://localhost:8080/books/1/library"
}

```

We'll use this URL to associate this book to ' _Library 1_' soon.

Calling ' _Library_' resource:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551927479429.png)

Now we'll associate ' _Test Book 1_' to ' _Library 1_':

```
$ curl -i -X PUT -H "Content-Type:text/uri-list" -d "http://localhost:8080/libraries/1" http://localhost:8080/books/1/library

```

Then we can check if it worked, by querying the ' _library_' association of our book:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551928067765.png)

### Changelog \#4: adding columns

During the development, we found necessary to add ' _isbn_' and ' _publisher_' fields to our ' _book_' table.

The first step is to create the changelog file. This is ' _4\_add\_isbn\_and\_publisher\_to\_book.yml_':

```
databaseChangeLog:
- changeSet:
   author: "tiago"
   id: "add_isbn_and_publisher_to_book"
   changes:
   - addColumn:
      columns:
      - column:
          name: "isbn"
          type: "VARCHAR(255)"
          constraints:
            nullable: "false"
      - column:
          name: "publisher"
          type: "VARCHAR(255)"
          constraints:
            nullable: "false"
      tableName: "book"

```

Then, let's run the changelog:

```
$ mvn liquibase:update -Dliquibase.changeLogFile=db/liquibase-changelog.yml

```

This is the output:

```
[INFO] ALTER TABLE book ADD isbn VARCHAR(255) NOT NULL, ADD publisher VARCHAR(255) NOT NULL
[INFO] Columns isbn(VARCHAR(255)),publisher(VARCHAR(255)) added to book
[INFO] ChangeSet db/changelog/4_add_isbn_and_publisher_to_book.yml::add_isbn::tiago ran successfully in 60ms

```

Let's check it in [MySQL](https://dev.mysql.com/):

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551928739987.png)

Great. The second step is to change our ' _Book_' entity to add these two new fields:

```
package com.tiago.entity;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.JoinColumn;
import javax.persistence.ManyToOne;

/**
 * Entity for table "Book"
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Entity
public class Book {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable=false)
  private String title;

  @ManyToOne
  @JoinColumn(name="library_id")
  private Library library;

  @Column(nullable=false)
  private String isbn;

  @Column(nullable=false)
  private String publisher;

  public Long getId() {
    return id;
  }

  public void setId(Long id) {
    this.id = id;
  }

  public String getTitle() {
    return title;
  }

  public void setTitle(String title) {
    this.title = title;
  }

  public Library getLibrary() {
    return library;
  }

  public void setLibrary(Library library) {
    this.library = library;
  }

  public String getIsbn() {
    return isbn;
  }

  public void setIsbn(String isbn) {
    this.isbn = isbn;
  }

  public String getPublisher() {
    return publisher;
  }

  public void setPublisher(String publisher) {
    this.publisher = publisher;
  }
}

```

Now let's update our book to set ' _isbn_' and ' _publisher_':

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551929229492.png)

### Changelog \#5: dropping a column

The ' _publisher_' field is not necessary anymore.

The first step is to create the changelog file. This is ' _5\_drop\_publisher\_from\_book.yml_':

```
databaseChangeLog:
- changeSet:
   author: "tiago"
   id: "drop_publisher_from_book"
   changes:
   - dropColumn:
      columnName: "publisher"
      tableName: "book"

```

Then, let's run the changelog:

```
$ mvn liquibase:update -Dliquibase.changeLogFile=db/liquibase-changelog.yml

```

This is the output:

```
[INFO] ALTER TABLE book DROP COLUMN publisher
[INFO] Column book.publisher dropped

```

Let's check it in [MySQL](https://dev.mysql.com/):

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551929815117.png)

OK. The second step is to change our ' _Book_' entity to remove ' _publisher_' property:

```
package com.tiago.entity;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.JoinColumn;
import javax.persistence.ManyToOne;

/**
 * Entity for table "Book"
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Entity
public class Book {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable=false)
  private String title;

  @ManyToOne
  @JoinColumn(name="library_id")
  private Library library;

  @Column(nullable=false)
  private String isbn;

  public Long getId() {
    return id;
  }

  public void setId(Long id) {
    this.id = id;
  }

  public String getTitle() {
    return title;
  }

  public void setTitle(String title) {
    this.title = title;
  }

  public Library getLibrary() {
    return library;
  }

  public void setLibrary(Library library) {
    this.library = library;
  }

  public String getIsbn() {
    return isbn;
  }

  public void setIsbn(String isbn) {
    this.isbn = isbn;
  }
}

```

Now let's fire up the server and check our ' _Book_' resource:

![No alt text provided for this image](/assets/images/2019-03-07-a96a93f8-5bb0-481f-af29-5a086529540f/1551930063588.png)

Great! The ' _publisher_' property does not exists anymore.

## Conclusion

Versioning database changes is as important as versioning source code, and tools like [Liquibase](http://www.liquibase.org/) makes it possible to do it in a safe and manageable way.

Through this simple example we learnt how we can evolve database in a Java application by integrating [Liquibase](http://www.liquibase.org/) with [Spring Boot](https://spring.io/projects/spring-boot).

## Download the source

Here: [https://bitbucket.org/tiagoharris/liquibase-hibernate-example/src/master/](https://bitbucket.org/tiagoharris/liquibase-hibernate-example/src/master/)