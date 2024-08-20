---
layout: post
title:  "Golang: a RESTful API using temporal table with MariaDB"
date:   2023-04-06 13:26:01 -0300
categories: go mariadb temporaltables
---
![Golang: a RESTful API using temporal table with MariaDB](/assets/images/2023-04-06-3eb1014e-dcf0-4f59-995e-b7bfcf706321/2023-04-06-banner.jpeg)

[Temporal tables](https://en.wikipedia.org/wiki/Temporal_database?trk=article-ssr-frontend-pulse_little-text-block) are a type of database table that store historical data, allowing users to query the data as it existed at specific points in time. These tables track changes made to data over time and retain a history of all modifications. This can be useful for auditing, compliance, and tracking changes over time. [Temporal tables](https://en.wikipedia.org/wiki/Temporal_database?trk=article-ssr-frontend-pulse_little-text-block) differ from regular tables in that they store both the current state of the data as well as a history of changes.

[MariaDB](https://mariadb.org/?trk=article-ssr-frontend-pulse_little-text-block) is a popular open-source relational database management system that supports temporal tables. Users can create and manage [temporal tables](https://en.wikipedia.org/wiki/Temporal_database?trk=article-ssr-frontend-pulse_little-text-block) using the [SQL](https://en.wikipedia.org/wiki/SQL?trk=article-ssr-frontend-pulse_little-text-block) syntax. This allows users to easily track changes to data and access historical versions of records.

Accordingly with its [oficial website](https://mariadb.com/kb/en/temporal-tables/?trk=article-ssr-frontend-pulse_little-text-block), temporal tables are supported in three forms: system versioned, application-time and bitemporal. We'll use system versioned in this example.

In this article we'll build a [dockerized](http://docker.com?trk=article-ssr-frontend-pulse_little-text-block)[REST API](https://en.wikipedia.org/wiki/Representational_state_transfer?trk=article-ssr-frontend-pulse_little-text-block), in [Go](http://golang.org?trk=article-ssr-frontend-pulse_little-text-block), that implements such a use case.

## Domain model

We'll build a simple API that offers endpoints to:

- list employees;
- list employee by id;
- create employee;
- update an employee;
- retrieve historical information about an employee;
- delete employee.

Our tables:

![No alt text provided for this image](/assets/images/2023-04-06-3eb1014e-dcf0-4f59-995e-b7bfcf706321/1680440508812.png)

schema\_migrations is a table used for [database migrations](https://www.linkedin.com/pulse/go-database-migrations-made-easy-example-using-mysql-tiago-melo/?trk=article-ssr-frontend-pulse_little-text-block).

## The API

I'm not going in too much detail about how I designed and implemented the [API](https://en.wikipedia.org/wiki/API?trk=article-ssr-frontend-pulse_little-text-block) itself, as it deserves an exclusive post for it. In a nutshell, here are the key points:

- I'm using [httptreemux](https://github.com/dimfeld/httptreemux?trk=article-ssr-frontend-pulse_little-text-block) as the router;
- I've written some custom [middlewares](https://drstearns.github.io/tutorials/gomiddleware/?trk=article-ssr-frontend-pulse_little-text-block) for both error handling and general logging, which reduce the amount of code in handler functions significantly;
- I decided to use [uri path versioning](https://dzone.com/articles/rest-api-versioning-strategies-1?trk=article-ssr-frontend-pulse_little-text-block) strategy for the api.

### Employee resource

Here are our handlers (handlers/v1/employees/employees.go):

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package employees

import (
    "context"
    "database/sql"
    "encoding/json"
    "errors"
    "fmt"
    "net/http"
    "strconv"

    mariaDb "github.com/tiagomelo/docker-mariadb-temporal-tables-tutorial/db"
    "github.com/tiagomelo/docker-mariadb-temporal-tables-tutorial/db/employees"
    "github.com/tiagomelo/docker-mariadb-temporal-tables-tutorial/db/employees/models"
    "github.com/tiagomelo/docker-mariadb-temporal-tables-tutorial/validate"
    "github.com/tiagomelo/docker-mariadb-temporal-tables-tutorial/web"
    v1Web "github.com/tiagomelo/docker-mariadb-temporal-tables-tutorial/web/v1"
)

type Handlers struct {
    Db *sql.DB
}

// handleGetEmployeeByIdError handles errors when getting an
// employee by its id.
func handleGetEmployeeByIdError(err error, id uint) error {
    if errors.Is(err, mariaDb.ErrDBNotFound) {
        return v1Web.NewRequestError(err, http.StatusNotFound)
    }
    return fmt.Errorf("ID[%d]: %w", id, err)
}

// handleCreateEmployeeError handles errors when creating an
// employee.
func handleCreateEmployeeError(err error) error {
    if errors.Is(err, mariaDb.ErrDBDuplicatedEntry) {
        return v1Web.NewRequestError(err, http.StatusConflict)
    }
    return fmt.Errorf("unable to create employee: %w", err)
}

// handleUpdateEmployeeByIdErr handles errors when updating an
// employee by its id.
func handleUpdateEmployeeByIdErr(err error, id uint) error {
    if errors.Is(err, mariaDb.ErrDBNotFound) {
        return v1Web.NewRequestError(err, http.StatusNotFound)
    }
    return fmt.Errorf("ID[%d]: %w", id, err)
}

// GetById returns a current employee with given id.
func (h Handlers) GetById(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
    idParam := web.Param(r, "id")
    id, err := strconv.Atoi(idParam)
    if err != nil {
        return v1Web.NewRequestError(fmt.Errorf("invalid id: %v", idParam), http.StatusBadRequest)
    }
    employee, err := employees.GetById(ctx, h.Db, uint(id))
    if err != nil {
        return handleGetEmployeeByIdError(err, uint(id))
    }
    return web.Respond(ctx, w, employee, http.StatusOK)
}

// GetAll returns all current employees.
func (h *Handlers) GetAll(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
    employees, err := employees.GetAll(ctx, h.Db)
    if err != nil {
        return fmt.Errorf("unable to query employees: %w", err)
    }
    return web.Respond(ctx, w, employees, http.StatusOK)
}

// Create creates an employee.
func (h Handlers) Create(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
    defer r.Body.Close()
    var newEmployee models.NewEmployee
    if err := json.NewDecoder(r.Body).Decode(&newEmployee); err != nil {
        return v1Web.NewRequestError(err, http.StatusBadRequest)
    }
    if err := validate.Check(newEmployee); err != nil {
        return fmt.Errorf("validating data: %w", err)
    }
    employee, err := employees.Create(ctx, h.Db, &newEmployee)
    if err != nil {
        return handleCreateEmployeeError(err)
    }
    return web.Respond(ctx, w, employee, http.StatusCreated)
}

// Update updates a current employee.
func (h Handlers) Update(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
    idParam := web.Param(r, "id")
    id, err := strconv.Atoi(idParam)
    if err != nil {
        return v1Web.NewRequestError(fmt.Errorf("invalid id: %v", idParam), http.StatusBadRequest)
    }
    var updateEmployee models.UpdateEmployee
    if err := json.NewDecoder(r.Body).Decode(&updateEmployee); err != nil {
        return v1Web.NewRequestError(err, http.StatusBadRequest)
    }
    updatedEmployee, err := employees.Update(ctx, h.Db, uint(id), &updateEmployee)
    if err != nil {
        return handleUpdateEmployeeByIdErr(err, uint(id))
    }
    return web.Respond(ctx, w, updatedEmployee, http.StatusOK)
}

// Delete deletes a current employee.
func (h Handlers) Delete(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
    idParam := web.Param(r, "id")
    id, err := strconv.Atoi(idParam)
    if err != nil {
        return v1Web.NewRequestError(fmt.Errorf("invalid id: %v", idParam), http.StatusBadRequest)
    }
    if err = employees.Delete(ctx, h.Db, uint(id)); err != nil {
        return fmt.Errorf("ID[%d]: %w", id, err)
    }
    return web.Respond(ctx, w, nil, http.StatusNoContent)
}
```

And here are our correlated DB functions (db/employees/employees.go):

```

// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package employees

import (
    "context"
    "database/sql"

    "github.com/go-sql-driver/mysql"
    mariaDb "github.com/tiagomelo/docker-mariadb-temporal-tables-tutorial/db"
    "github.com/tiagomelo/docker-mariadb-temporal-tables-tutorial/db/employees/models"
)

// For ease of unit testing.
var (
    readEmployee = func(row *sql.Row, dest ...any) error {
        return row.Scan(dest...)
    }
    readEmployees = func(rows *sql.Rows, dest ...any) error {
        return rows.Scan(dest...)
    }
)

// GetById returns a current employee with given id.
func GetById(ctx context.Context, db *sql.DB, id uint) (*models.Employee, error) {
    q := `
    SELECT id, first_name, last_name, salary, department
    FROM employees
    WHERE id = ?
    `
    var employee models.Employee
    row := db.QueryRowContext(ctx, q, id)
    if err := readEmployee(row,
        &employee.Id,
        &employee.FirstName,
        &employee.LastName,
        &employee.Salary,
        &employee.Department,
    ); err != nil {
        return nil, mariaDb.ErrDBNotFound
    }
    return &employee, nil
}

// GetAll returns all current employees.
func GetAll(ctx context.Context, db *sql.DB) ([]models.Employee, error) {
    q := `
    SELECT id, first_name, last_name, salary, department
    FROM employees
    `
    employees := make([]models.Employee, 0)
    rows, err := db.QueryContext(ctx, q)
    if err != nil {
        return employees, err
    }
    defer rows.Close()
    for rows.Next() {
        var employee models.Employee
        if err = readEmployees(rows,
            &employee.Id,
            &employee.FirstName,
            &employee.LastName,
            &employee.Salary,
            &employee.Department,
        ); err != nil {
            return employees, err
        }
        employees = append(employees, employee)
    }
    return employees, nil
}

// Create creates an employee.
func Create(ctx context.Context, db *sql.DB, newEmployee *models.NewEmployee) (*models.Employee, error) {
    q := `
    INSERT INTO
        employees(first_name, last_name, salary, department)
    VALUES
        (?, ?, ?, ?)
    RETURNING
        id, first_name, last_name, salary, department
    `
    var employee models.Employee
    row := db.QueryRowContext(ctx, q, newEmployee.FirstName, newEmployee.LastName, newEmployee.Salary, newEmployee.Department)
    if err := readEmployee(row,
        &employee.Id,
        &employee.FirstName,
        &employee.LastName,
        &employee.Salary,
        &employee.Department,
    ); err != nil {
        if mysqlErr, ok := err.(*mysql.MySQLError); ok && mysqlErr.Number == mariaDb.UniqueViolation {
            return nil, mariaDb.ErrDBDuplicatedEntry
        }
        return nil, err
    }
    return &employee, nil
}

// handleEmployeeChanges updates the changed properties.
func handleEmployeeChanges(updateEmployee *models.UpdateEmployee, dbEmployee *models.Employee) {
    if updateEmployee.FirstNameIsFulfilled() {
        dbEmployee.FirstName = *updateEmployee.FirstName
    }
    if updateEmployee.LastNameIsFulfilled() {
        dbEmployee.LastName = *updateEmployee.LastName
    }
    if updateEmployee.SalaryIsFulfilled() {
        dbEmployee.Salary = *updateEmployee.Salary
    }
    if updateEmployee.DepartmentIsFulfilled() {
        dbEmployee.Department = *updateEmployee.Department
    }
}

// Update updates an employee.
func Update(ctx context.Context, db *sql.DB, employeeId uint, updateEmployee *models.UpdateEmployee) (*models.Employee, error) {
    q := `
    UPDATE employees
    SET
        first_name = ?,
        last_name = ?,
        salary = ?,
        department = ?
    WHERE
        id = ?
    `
    dbEmployee, err := GetById(ctx, db, employeeId)
    if err != nil {
        return nil, err
    }
    handleEmployeeChanges(updateEmployee, dbEmployee)
    _, err = db.ExecContext(ctx, q, dbEmployee.FirstName, dbEmployee.LastName, dbEmployee.Salary, dbEmployee.Department, dbEmployee.Id)
    return dbEmployee, err
}

// Delete deletes an employee.
func Delete(ctx context.Context, db *sql.DB, id uint) error {
    q := `
    DELETE FROM
        employees
    WHERE id = ?
    `
    _, err := db.ExecContext(ctx, q, id)
    return err
}

```

As we can see, a plain old [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete?trk=article-ssr-frontend-pulse_little-text-block), nothing really special here.

Let's create our first employee:

```
curl 'http://localhost:3000/v1/employee'
> --header 'Content-Type: application/json' \
> --data '{
>     "first_name": "John",
>     "last_name": "Doe",
>     "salary": 1234.56,
>     "department": "IT"
> }'

{"id":1,"first_name":"John","last_name":"Doe","department":"IT","salary":1234.56}\
```

Now suppose that we want to update this employee's salary after some years. In order to do that we need to [manually change the default timestamp in MariaDB](https://mariadb.com/kb/en/system-versioned-tables/#inserting-data?trk=article-ssr-frontend-pulse_little-text-block) so it returns the timestamp in the future.

To accomplish that, I've created two endpoints:

- GET v1/db/timestamp/advance: it advances the default timestamp in [MariaDB](http://mariadb.com?trk=article-ssr-frontend-pulse_little-text-block) to a random number of years between 1 and 5;
- GET v1/db/timestamp/default: it sets back the default timestamp to the current date.

Let's call the endpoint to advance the timestamp:

```
curl 'http://localhost:3000/v1/db/timestamp/advance'

{"timestamp":"2025-04-06"}
```

We see that we randomly advanced the current year (2023) in two years (2025), which means that [MariaDB](http://mariadb.com/?trk=article-ssr-frontend-pulse_little-text-block) thinks that we're in 2025.

Let's then update the employee's salary:

```
curl --request PUT 'http://localhost:3000/v1/employee/1'
--header 'Content-Type: application/json' \
--data '{
    "salary": 2500
}'

{"id":1,"first_name":"John","last_name":"Doe","department":"IT","salary":2500}
```

Now we'll see the power of temporal tables. What if we want to query all historical changes for this employee?

### Employee history resource

We have three available endpoints:

- v1/employee/{id}/history/all, which enables us to check all historical data;
- v1/employee/{id}/history/{timestamp}, which enables us to fetch historical data at a given point in time;
- v1/employee/{id}/history/{start\_timestamp}/{end\_timestamp}, which makes it possible to get historical data between two dates.

Here are our handlers (handlers/v1/employees/history/history.go):

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package history

import (
    "context"
    "database/sql"
    "fmt"
    "net/http"
    "strconv"
    "time"

    "github.com/tiagomelo/docker-mariadb-temporal-tables-tutorial/db/employees"
    "github.com/tiagomelo/docker-mariadb-temporal-tables-tutorial/web"
    v1Web "github.com/tiagomelo/docker-mariadb-temporal-tables-tutorial/web/v1"
)

type Handlers struct {
    Db *sql.DB
}

// GetAll returns all historical data for a given employee.
func (h Handlers) GetAll(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
    idParam := web.Param(r, "id")
    id, err := strconv.Atoi(idParam)
    if err != nil {
        return v1Web.NewRequestError(fmt.Errorf("invalid id: %v", idParam), http.StatusBadRequest)
    }
    employeeHistory, err := employees.GetAllHistory(ctx, h.Db, uint(id))
    if err != nil {
        return fmt.Errorf("ID[%d]: %w", id, err)
    }
    return web.Respond(ctx, w, employeeHistory, http.StatusOK)
}

// AtPointInTime returns historical data for a given employee at a point in time.
func (h Handlers) AtPointInTime(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
    idParam := web.Param(r, "id")
    id, err := strconv.Atoi(idParam)
    if err != nil {
        return v1Web.NewRequestError(fmt.Errorf("invalid id: %v", idParam), http.StatusBadRequest)
    }
    timestampParam := web.Param(r, "timestamp")
    timestamp, err := strconv.ParseInt(timestampParam, 10, 64)
    if err != nil {
        return v1Web.NewRequestError(fmt.Errorf("invalid timestamp: %v", timestampParam), http.StatusBadRequest)
    }
    employeeHistory, err := employees.AtPointInTime(ctx, h.Db, uint(id), time.Unix(timestamp, 0).Format("2006-01-02 15:04:05"))
    if err != nil {
        return fmt.Errorf("ID[%d]: %w", timestamp, err)
    }
    return web.Respond(ctx, w, employeeHistory, http.StatusOK)
}

// BetweenDates returns historical data for a given employee between dates.
func (h Handlers) BetweenDates(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
    idParam := web.Param(r, "id")
    id, err := strconv.Atoi(idParam)
    if err != nil {
        return v1Web.NewRequestError(fmt.Errorf("invalid id: %v", idParam), http.StatusBadRequest)
    }
    startTimestampParam := web.Param(r, "startTimestamp")
    startTimestamp, err := strconv.ParseInt(startTimestampParam, 10, 64)
    if err != nil {
        return v1Web.NewRequestError(fmt.Errorf("invalid start timestamp: %v", startTimestampParam), http.StatusBadRequest)
    }
    endTimestampParam := web.Param(r, "endTimestamp")
    endTimestamp, err := strconv.ParseInt(endTimestampParam, 10, 64)
    if err != nil {
        return v1Web.NewRequestError(fmt.Errorf("invalid end timestamp: %v", endTimestampParam), http.StatusBadRequest)
    }
    employeeHistory, err := employees.BetweenDates(ctx, h.Db, uint(id), time.Unix(startTimestamp, 0).Format("2006-01-02 15:04:05"), time.Unix(endTimestamp, 0).Format("2006-01-02 15:04:05"))
    if err != nil {
        return fmt.Errorf("ID[%d]: %w", startTimestamp, err)
    }
    return web.Respond(ctx, w, employeeHistory, http.StatusOK)
}

```

Getting all historical data

Check the SQL query (db/employees/employees\_history.go) for fetching all historical data:

```
// GetAllHistory returns the complete history of a given employee.
func GetAllHistory(ctx context.Context, db *sql.DB, id uint) ([]models.EmployeeHistory, error) {
    q := `
    SELECT id, first_name, last_name, salary, department, row_start, row_end
    FROM employees
    FOR SYSTEM_TIME ALL
    WHERE id = ?
    `
    employeeHistory := make([]models.EmployeeHistory, 0)
    rows, err := db.QueryContext(ctx, q, id)
    if err != nil {
        return employeeHistory, err
    }
    defer rows.Close()
    for rows.Next() {
        var employeeHist models.EmployeeHistory
        if err = readEmployeeHistory(rows,
            &employeeHist.Id,
            &employeeHist.FirstName,
            &employeeHist.LastName,
            &employeeHist.Salary,
            &employeeHist.Department,
            &employeeHist.RowStart,
            &employeeHist.RowEnd,
        ); err != nil {
            return nil, err
        }
        employeeHistory = append(employeeHistory, employeeHist)
    }
    return employeeHistory, nil
}
```

Let's try it:

```
curl 'http://localhost:3000/v1/employee/1/history/all'

[
  {
    "id": 1,
    "first_name": "John",
    "last_name": "Doe",
    "department": "IT",
    "salary": 1234.56,
    "row_start": "2023-04-06T13:31:50.830757Z",
    "row_end": "2025-04-06T00:00:00Z"
  },
  {
    "id": 1,
    "first_name": "John",
    "last_name": "Doe",
    "department": "IT",
    "salary": 2500,
    "row_start": "2025-04-06T00:00:00Z",
    "row_end": "2038-01-19T03:14:07.999999Z"
  }
]
```

We see that John's first salary was registered in 2023-04-06 with a value of 1234.56, and he received a raise in 2025-04-06 to a value of 2500.

Getting historical data at a point in time

What if we want to check John's salary at a point in time? We have this SQL query:

```
// AtPointInTime returns the complete history of a given employee in a given
// point in time.
func AtPointInTime(ctx context.Context, db *sql.DB, id uint, timestamp string) ([]models.EmployeeHistory, error) {
    q := `
    SELECT id, first_name, last_name, salary, department, row_start, row_end
    FROM employees
    FOR SYSTEM_TIME
    AS OF TIMESTAMP ?
    WHERE id = ?
    `
    employeeHistory := make([]models.EmployeeHistory, 0)
    rows, err := db.QueryContext(ctx, q, timestamp, id)
    if err != nil {
        return employeeHistory, err
    }
    defer rows.Close()
    for rows.Next() {
        var employeeHist models.EmployeeHistory
        if err = readEmployeeHistory(rows,
            &employeeHist.Id,
            &employeeHist.FirstName,
            &employeeHist.LastName,
            &employeeHist.Salary,
            &employeeHist.Department,
            &employeeHist.RowStart,
            &employeeHist.RowEnd,
        ); err != nil {
            return nil, err
        }
        employeeHistory = append(employeeHistory, employeeHist)
    }
    return employeeHistory, nil
}

```

By using a website like [Epoch Converter](https://www.epochconverter.com/?trk=article-ssr-frontend-pulse_little-text-block) it is easy to get a timestamp. What was John's salary in 2024-04-06?

```
curl 'http://localhost:3000/v1/employee/1/history/1712411281'

[
  {
    "id": 1,
    "first_name": "John",
    "last_name": "Doe",
    "department": "IT",
    "salary": 1234.56,
    "row_start": "2023-04-06T13:31:50.830757Z",
    "row_end": "2025-04-06T00:00:00Z"
  }
]
```

1234.56 precisely, because he didn't receive a raise yet.

What was John's salary in 2025-06-06?

```
curl 'http://localhost:3000/v1/employee/1/history/1749217681'

[
  {
    "id": 1,
    "first_name": "John",
    "last_name": "Doe",
    "department": "IT",
    "salary": 2500,
    "row_start": "2025-04-06T00:00:00Z",
    "row_end": "2038-01-19T03:14:07.999999Z"
  }
]
```

It was 2500, because he received a raise in 2025-04-06.

Getting historical data between dates

To check this historical info between two dates, we have this query:

```
// BetweenDates returns the complete history of a given employee in a given period.
func BetweenDates(ctx context.Context, db *sql.DB, id uint, startTimestamp, endTimeStamp string) ([]models.EmployeeHistory, error) {
    q := `
    SELECT id, first_name, last_name, salary, department, row_start, row_end
    FROM employees
    FOR SYSTEM_TIME
    FROM ? TO ?
    WHERE id = ?
    `
    employeeHistory := make([]models.EmployeeHistory, 0)
    rows, err := db.QueryContext(ctx, q, startTimestamp, endTimeStamp, id)
    if err != nil {
        return employeeHistory, err
    }
    defer rows.Close()
    for rows.Next() {
        var employeeHist models.EmployeeHistory
        if err = readEmployeeHistory(rows,
            &employeeHist.Id,
            &employeeHist.FirstName,
            &employeeHist.LastName,
            &employeeHist.Salary,
            &employeeHist.Department,
            &employeeHist.RowStart,
            &employeeHist.RowEnd,
        ); err != nil {
            return nil, err
        }
        employeeHistory = append(employeeHistory, employeeHist)
    }
    return employeeHistory, nil
}

```

What was John's salary between 2023-04-06 and 2024-01-02, considering that he was given a raise at 2024-04-06?

```
curl 'http://localhost:3000/v1/employee/1/history/1680788881/1704203281'

[
  {
    "id": 1,
    "first_name": "John",
    "last_name": "Doe",
    "department": "IT",
    "salary": 1234.56,
    "row_start": "2023-04-06T13:31:50.830757Z",
    "row_end": "2025-04-06T00:00:00Z"
  }
]
```

Yep, 1234.56.

## Extra topics

### Generating Swagger documentation

Checking our Makefilewe have the following targets:

```
$ make help

Usage: make [target

  help                   shows this help message

  mariadb-console        launches mariadb local database console

  test-mariadb-console   launches mariadb test database console

  create-migration       creates a migration file

  test                   runs unit tests

  coverage               run unit tests and generate coverage report in html format

  test-db-up             starts test database

  int-test               runs integration tests

  vet                    runs go vet

  lint                   runs linter for all packages

  vul-setup              installs Golang's vulnerability check tool

  vul-check              checks for any known vulnerabilities

  swagger                generates api's documentation

  swagger-ui             launches swagger ui

  run                    runs the application

  stop                   stops all containers]
```

Generating [Swagger](https://swagger.io/?trk=article-ssr-frontend-pulse_little-text-block) documentation is fairly easy. Under 'doc' folder we have:

doc/doc.go

```
// Employees API
//
//   A sample RESTful API to manage employees.
//      Host: localhost:3000
//      Version: 0.0.1
//      Contact: Tiago Melo <tiagoharris@gmail.com>
//
//      Consumes:
//      - application/json
//
//      Produces:
//      - application/json
//
// swagger:meta
package doc
```

And doc/api.go

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package doc

import "github.com/tiagomelo/docker-mariadb-temporal-tables-tutorial/db/employees/models"

// swagger:route GET /v1/employees employees GetAll
// Get all current employees.
// ---
// responses:
//      200: getAllCurrentEmployeesResponse

// swagger:response getAllCurrentEmployeesResponse
type GetAllCurrentEmployeesResponseWrapper struct {
    // in:body
    Body []models.Employee
}

// swagger:route GET /v1/employee/{id} employee GetById
// Get a current employee by its id.
// ---
// responses:
//
//  200: employee
//  400: description: invalid id
//  404: description: employee not found
//
// swagger:parameters GetById
type GetEmployeeByIdParamsWrapper struct {
    // in:path
    Id int
}

// swagger:response employee
type EmployeeResponseWrapper struct {
    // in:body
    Body models.Employee
}

// swagger:route POST /v1/employee employee Create
// Create an employee.
// ---
// responses:
//
//  200: employee
//
// swagger:parameters Create
type PostEmployeeParamsWrapper struct {
    // in:body
    Body models.NewEmployee
}

// swagger:route PUT /v1/employee/{id} employee Update
// Updates a current employee.
// ---
// responses:
//
//  200: employee
//  400: description: invalid id
//  404: description: employee not found
//
// swagger:parameters Update
type PutEmployeeParamsWrapper struct {
    // in:path
    Id int
    // in:body
    Body models.UpdateEmployee
}

// swagger:route DELETE /v1/employee/{id} employee Delete
// Deletes a current employee.
// ---
// responses:
//
//  204: description: no content
//  400: description: invalid id
//
// swagger:parameters Delete
type DeleteEmployeeParamsWrapper struct {
    // in:path
    Id int
}

// swagger:route GET /v1/employee/{id}/history/all history GetAllEmployeeHistoryById
// Get all historical data about an employee with a given id.
// ---
// responses:
//
//  200: employeeHistory
//  400: description: invalid id
//
// swagger:parameters GetAllEmployeeHistoryById
type GetAllEmployeeHistoryByIdParamsWrapper struct {
    // in:path
    Id int
}

// swagger:route GET /v1/employee/{id}/history/{timestamp} history GetAllEmployeeHistoryAtPointInTime
// Get historical data about an employee with a given id at a given point in time.
// ---
// responses:
//
//  200: employeeHistory
//  400: description: invalid id
//  400: description: invalid timestamp
//
// swagger:parameters GetAllEmployeeHistoryAtPointInTime
type GetAllEmployeeHistoryAtPointInTimeParamsWrapper struct {
    // in:path
    Timestamp int
}

// swagger:route GET /v1/employee/{id}/history/{startTimestamp}/{endTimestamp} history GetAllEmployeeHistoryBetweenDates
// Get historical data about an employee with a given id between dates.
// ---
// responses:
//
//  200: employeeHistory
//  400: description: invalid id
//  400: description: invalid start timestamp
//  400: description: invalid end timestamp
//
// swagger:parameters GetAllEmployeeHistoryBetweenDates
type GetAllEmployeeHistoryBetweenDatesParamsWrapper struct {
    // in:path
    StartTimestamp int
    // in:path
    EndTimestamp int
}

// swagger:response employeeHistory
type EmployeeHistoryResponseWrapper struct {
    // in:body
    Body []models.EmployeeHistory
}
```

Then, let's run:

```

make swagger-ui
```

Check your browser at http://localhost/:

![No alt text provided for this image](/assets/images/2023-04-06-3eb1014e-dcf0-4f59-995e-b7bfcf706321/1680794427788.png)

### Check for known vulnerabilities

```
$ make run vul-check
```

### Run linter

```
$ make lint
```

## Conclusion

[Temporal tables](https://en.wikipedia.org/wiki/Temporal_database?trk=article-ssr-frontend-pulse_little-text-block) are an easy way to fetch historical data, making it easy to travel through time.

Check [here](https://en.wikipedia.org/wiki/Temporal_database#Implementations_in_notable_products?trk=article-ssr-frontend-pulse_little-text-block) the vendors that implement it.

## Download the source

Here: [https://github.com/tiagomelo/docker-mariadb-temporal-tables-tutorial](https://github.com/tiagomelo/docker-mariadb-temporal-tables-tutorial?trk=article-ssr-frontend-pulse_little-text-block)