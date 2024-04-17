---
layout: post
title:  "Java: an appointment scheduler with Spring Boot, MySQL and Quartz"
date:   2019-02-19 13:26:01 -0300
categories: java springboot mysql quartz
---
![Java: an appointment scheduler with Spring Boot, MySQL and Quartz](/assets/images/2019-02-19-25799d90-eb49-4c8d-8421-0d41f4183572/2019-02-19-banner.png)

Let's continue to explore different ways to ease application development with [Spring Boot](https://spring.io/projects/spring-boot): this time we'll write a RESTFul API to schedule appointments using [Quartz](http://www.quartz-scheduler.org/) and [MySQL](https://dev.mysql.com/).

## Introduction

Besides being a software engineer, I'm also a qualified commercial airplane pilot and flight instructor. I must revalidate my medical certificate anually in order to be allowed to fly.

Before my certificate expires I visit the website of some specialized clinic like [Instituto Dédalo](https://www.institutodedalo.com.br/) to schedule the revalidation. This is what it looks like:

![No alt text provided for this image](/assets/images/2019-02-19-25799d90-eb49-4c8d-8421-0d41f4183572/1550591638223.png)

I choose the desired date and get a confirmation e-mail.

So imagine that you have a website that allows users to schedule appointments, like interviews or exams, for example:

- When the user schedules a date, he receives a confirmation e-mail;
- One day prior to the appointment, he receives a reminder e-mail.

The website could call a RESTFul API to create the schedules. We'll see how we can implement one.

## The project

To accomplish this, we'll integrate [Quartz](http://www.quartz-scheduler.org/) with our [Spring Boot](https://spring.io/projects/spring-boot) RESTFul API.

> Quartz is a richly featured, open source job scheduling library that can be integrated within virtually any Java application - from the smallest stand-alone application to the largest e-commerce system. Quartz can be used to create simple or complex schedules for executing tens, hundreds, or even tens-of-thousands of jobs; jobs whose tasks are defined as standard Java components that may execute virtually anything you may program them to do. The Quartz Scheduler includes many enterprise-class features, such as support for JTA transactions and clustering.

We can schedule Jobs to be executed at a certain time of day, or periodically at a certain interval, and much more. [Quartz](http://www.quartz-scheduler.org/) provides a fluent API for creating jobs and scheduling them.

So, every time a user makes a new schedule, we will:

- Create and fire a [Quartz](http://www.quartz-scheduler.org/) job to send confirmation e-mail immediately to him;
- Create and schedule a [Quartz](http://www.quartz-scheduler.org/) job to be fired one day prior to the appointment in order to send a reminder e-mail to him.

Quartz Jobs can be persisted into a database, or a cache, or in-memory. We will persist our jobs into a MySQL database; this way, even if the application crashes, all scheduling information won't be lost.

## A note about Gmail's SMTP server

We'll use Gmail to send e-mails and access to Gmail's SMTP server is disabled by default. To allow this API to use it:

- Go to your [Gmail account settings](https://myaccount.google.com/security?pli=1#connectedapps)
- Set ‘Allow less secure apps’ to YES

## Creating the project

[Spring Initializr](http://start.spring.io/) is our start point:

![No alt text provided for this image](/assets/images/2019-02-19-25799d90-eb49-4c8d-8421-0d41f4183572/1550600344813.png)

We've choose the following dependencies:

- [Web](https://docs.spring.io/spring-boot/docs/current/reference/html/using-boot-build-systems.html#spring-boot-starter-web): Starter for building web, including RESTful, applications using Spring MVC. Uses Tomcat as the default embedded container.
- [JPA](https://docs.spring.io/spring-boot/docs/current/reference/html/using-boot-build-systems.html#spring-boot-starter-data-jpa): Starter for using Spring Data JPA with Hibernate.
- [MySQL](https://dev.mysql.com/downloads/connector/j/8.0.html): mysql-connector-java jar
- [Quartz Scheduler](http://www.quartz-scheduler.org/): Starter for using Quartz Scheduler
- [Mail](https://javaee.github.io/javaee-spec/javadocs/javax/mail/package-summary.html): Starter for using Java Mail

## Creating Quartz tables

Since we have configured Quartz to store Jobs in the database, we’ll need to create the tables that Quartz uses to store Jobs and other job-related meta-data.

This is the script:

```
DROP TABLE IF EXISTS QRTZ_FIRED_TRIGGERS;
DROP TABLE IF EXISTS QRTZ_PAUSED_TRIGGER_GRPS;
DROP TABLE IF EXISTS QRTZ_SCHEDULER_STATE;
DROP TABLE IF EXISTS QRTZ_LOCKS;
DROP TABLE IF EXISTS QRTZ_SIMPLE_TRIGGERS;
DROP TABLE IF EXISTS QRTZ_SIMPROP_TRIGGERS;
DROP TABLE IF EXISTS QRTZ_CRON_TRIGGERS;
DROP TABLE IF EXISTS QRTZ_BLOB_TRIGGERS;
DROP TABLE IF EXISTS QRTZ_TRIGGERS;
DROP TABLE IF EXISTS QRTZ_JOB_DETAILS;
DROP TABLE IF EXISTS QRTZ_CALENDARS;

CREATE TABLE QRTZ_JOB_DETAILS(
SCHED_NAME VARCHAR(120) NOT NULL,
JOB_NAME VARCHAR(190) NOT NULL,
JOB_GROUP VARCHAR(190) NOT NULL,
DESCRIPTION VARCHAR(250) NULL,
JOB_CLASS_NAME VARCHAR(250) NOT NULL,
IS_DURABLE VARCHAR(1) NOT NULL,
IS_NONCONCURRENT VARCHAR(1) NOT NULL,
IS_UPDATE_DATA VARCHAR(1) NOT NULL,
REQUESTS_RECOVERY VARCHAR(1) NOT NULL,
JOB_DATA BLOB NULL,
PRIMARY KEY (SCHED_NAME,JOB_NAME,JOB_GROUP))
ENGINE=InnoDB;

CREATE TABLE QRTZ_TRIGGERS (
SCHED_NAME VARCHAR(120) NOT NULL,
TRIGGER_NAME VARCHAR(190) NOT NULL,
TRIGGER_GROUP VARCHAR(190) NOT NULL,
JOB_NAME VARCHAR(190) NOT NULL,
JOB_GROUP VARCHAR(190) NOT NULL,
DESCRIPTION VARCHAR(250) NULL,
NEXT_FIRE_TIME BIGINT(13) NULL,
PREV_FIRE_TIME BIGINT(13) NULL,
PRIORITY INTEGER NULL,
TRIGGER_STATE VARCHAR(16) NOT NULL,
TRIGGER_TYPE VARCHAR(8) NOT NULL,
START_TIME BIGINT(13) NOT NULL,
END_TIME BIGINT(13) NULL,
CALENDAR_NAME VARCHAR(190) NULL,
MISFIRE_INSTR SMALLINT(2) NULL,
JOB_DATA BLOB NULL,
PRIMARY KEY (SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP),
FOREIGN KEY (SCHED_NAME,JOB_NAME,JOB_GROUP)
REFERENCES QRTZ_JOB_DETAILS(SCHED_NAME,JOB_NAME,JOB_GROUP))
ENGINE=InnoDB;

CREATE TABLE QRTZ_SIMPLE_TRIGGERS (
SCHED_NAME VARCHAR(120) NOT NULL,
TRIGGER_NAME VARCHAR(190) NOT NULL,
TRIGGER_GROUP VARCHAR(190) NOT NULL,
REPEAT_COUNT BIGINT(7) NOT NULL,
REPEAT_INTERVAL BIGINT(12) NOT NULL,
TIMES_TRIGGERED BIGINT(10) NOT NULL,
PRIMARY KEY (SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP),
FOREIGN KEY (SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP)
REFERENCES QRTZ_TRIGGERS(SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP))
ENGINE=InnoDB;

CREATE TABLE QRTZ_CRON_TRIGGERS (
SCHED_NAME VARCHAR(120) NOT NULL,
TRIGGER_NAME VARCHAR(190) NOT NULL,
TRIGGER_GROUP VARCHAR(190) NOT NULL,
CRON_EXPRESSION VARCHAR(120) NOT NULL,
TIME_ZONE_ID VARCHAR(80),
PRIMARY KEY (SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP),
FOREIGN KEY (SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP)
REFERENCES QRTZ_TRIGGERS(SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP))
ENGINE=InnoDB;

CREATE TABLE QRTZ_SIMPROP_TRIGGERS
  (
    SCHED_NAME VARCHAR(120) NOT NULL,
    TRIGGER_NAME VARCHAR(190) NOT NULL,
    TRIGGER_GROUP VARCHAR(190) NOT NULL,
    STR_PROP_1 VARCHAR(512) NULL,
    STR_PROP_2 VARCHAR(512) NULL,
    STR_PROP_3 VARCHAR(512) NULL,
    INT_PROP_1 INT NULL,
    INT_PROP_2 INT NULL,
    LONG_PROP_1 BIGINT NULL,
    LONG_PROP_2 BIGINT NULL,
    DEC_PROP_1 NUMERIC(13,4) NULL,
    DEC_PROP_2 NUMERIC(13,4) NULL,
    BOOL_PROP_1 VARCHAR(1) NULL,
    BOOL_PROP_2 VARCHAR(1) NULL,
    PRIMARY KEY (SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP),
    FOREIGN KEY (SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP)
    REFERENCES QRTZ_TRIGGERS(SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP))
ENGINE=InnoDB;

CREATE TABLE QRTZ_BLOB_TRIGGERS (
SCHED_NAME VARCHAR(120) NOT NULL,
TRIGGER_NAME VARCHAR(190) NOT NULL,
TRIGGER_GROUP VARCHAR(190) NOT NULL,
BLOB_DATA BLOB NULL,
PRIMARY KEY (SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP),
INDEX (SCHED_NAME,TRIGGER_NAME, TRIGGER_GROUP),
FOREIGN KEY (SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP)
REFERENCES QRTZ_TRIGGERS(SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP))
ENGINE=InnoDB;

CREATE TABLE QRTZ_CALENDARS (
SCHED_NAME VARCHAR(120) NOT NULL,
CALENDAR_NAME VARCHAR(190) NOT NULL,
CALENDAR BLOB NOT NULL,
PRIMARY KEY (SCHED_NAME,CALENDAR_NAME))
ENGINE=InnoDB;

CREATE TABLE QRTZ_PAUSED_TRIGGER_GRPS (
SCHED_NAME VARCHAR(120) NOT NULL,
TRIGGER_GROUP VARCHAR(190) NOT NULL,
PRIMARY KEY (SCHED_NAME,TRIGGER_GROUP))
ENGINE=InnoDB;

CREATE TABLE QRTZ_FIRED_TRIGGERS (
SCHED_NAME VARCHAR(120) NOT NULL,
ENTRY_ID VARCHAR(95) NOT NULL,
TRIGGER_NAME VARCHAR(190) NOT NULL,
TRIGGER_GROUP VARCHAR(190) NOT NULL,
INSTANCE_NAME VARCHAR(190) NOT NULL,
FIRED_TIME BIGINT(13) NOT NULL,
SCHED_TIME BIGINT(13) NOT NULL,
PRIORITY INTEGER NOT NULL,
STATE VARCHAR(16) NOT NULL,
JOB_NAME VARCHAR(190) NULL,
JOB_GROUP VARCHAR(190) NULL,
IS_NONCONCURRENT VARCHAR(1) NULL,
REQUESTS_RECOVERY VARCHAR(1) NULL,
PRIMARY KEY (SCHED_NAME,ENTRY_ID))
ENGINE=InnoDB;

CREATE TABLE QRTZ_SCHEDULER_STATE (
SCHED_NAME VARCHAR(120) NOT NULL,
INSTANCE_NAME VARCHAR(190) NOT NULL,
LAST_CHECKIN_TIME BIGINT(13) NOT NULL,
CHECKIN_INTERVAL BIGINT(13) NOT NULL,
PRIMARY KEY (SCHED_NAME,INSTANCE_NAME))
ENGINE=InnoDB;

CREATE TABLE QRTZ_LOCKS (
SCHED_NAME VARCHAR(120) NOT NULL,
LOCK_NAME VARCHAR(40) NOT NULL,
PRIMARY KEY (SCHED_NAME,LOCK_NAME))
ENGINE=InnoDB;

CREATE INDEX IDX_QRTZ_J_REQ_RECOVERY ON QRTZ_JOB_DETAILS(SCHED_NAME,REQUESTS_RECOVERY);
CREATE INDEX IDX_QRTZ_J_GRP ON QRTZ_JOB_DETAILS(SCHED_NAME,JOB_GROUP);

CREATE INDEX IDX_QRTZ_T_J ON QRTZ_TRIGGERS(SCHED_NAME,JOB_NAME,JOB_GROUP);
CREATE INDEX IDX_QRTZ_T_JG ON QRTZ_TRIGGERS(SCHED_NAME,JOB_GROUP);
CREATE INDEX IDX_QRTZ_T_C ON QRTZ_TRIGGERS(SCHED_NAME,CALENDAR_NAME);
CREATE INDEX IDX_QRTZ_T_G ON QRTZ_TRIGGERS(SCHED_NAME,TRIGGER_GROUP);
CREATE INDEX IDX_QRTZ_T_STATE ON QRTZ_TRIGGERS(SCHED_NAME,TRIGGER_STATE);
CREATE INDEX IDX_QRTZ_T_N_STATE ON QRTZ_TRIGGERS(SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP,TRIGGER_STATE);
CREATE INDEX IDX_QRTZ_T_N_G_STATE ON QRTZ_TRIGGERS(SCHED_NAME,TRIGGER_GROUP,TRIGGER_STATE);
CREATE INDEX IDX_QRTZ_T_NEXT_FIRE_TIME ON QRTZ_TRIGGERS(SCHED_NAME,NEXT_FIRE_TIME);
CREATE INDEX IDX_QRTZ_T_NFT_ST ON QRTZ_TRIGGERS(SCHED_NAME,TRIGGER_STATE,NEXT_FIRE_TIME);
CREATE INDEX IDX_QRTZ_T_NFT_MISFIRE ON QRTZ_TRIGGERS(SCHED_NAME,MISFIRE_INSTR,NEXT_FIRE_TIME);
CREATE INDEX IDX_QRTZ_T_NFT_ST_MISFIRE ON QRTZ_TRIGGERS(SCHED_NAME,MISFIRE_INSTR,NEXT_FIRE_TIME,TRIGGER_STATE);
CREATE INDEX IDX_QRTZ_T_NFT_ST_MISFIRE_GRP ON QRTZ_TRIGGERS(SCHED_NAME,MISFIRE_INSTR,NEXT_FIRE_TIME,TRIGGER_GROUP,TRIGGER_STATE);

CREATE INDEX IDX_QRTZ_FT_TRIG_INST_NAME ON QRTZ_FIRED_TRIGGERS(SCHED_NAME,INSTANCE_NAME);
CREATE INDEX IDX_QRTZ_FT_INST_JOB_REQ_RCVRY ON QRTZ_FIRED_TRIGGERS(SCHED_NAME,INSTANCE_NAME,REQUESTS_RECOVERY);
CREATE INDEX IDX_QRTZ_FT_J_G ON QRTZ_FIRED_TRIGGERS(SCHED_NAME,JOB_NAME,JOB_GROUP);
CREATE INDEX IDX_QRTZ_FT_JG ON QRTZ_FIRED_TRIGGERS(SCHED_NAME,JOB_GROUP);
CREATE INDEX IDX_QRTZ_FT_T_G ON QRTZ_FIRED_TRIGGERS(SCHED_NAME,TRIGGER_NAME,TRIGGER_GROUP);
CREATE INDEX IDX_QRTZ_FT_TG ON QRTZ_FIRED_TRIGGERS(SCHED_NAME,TRIGGER_GROUP);

COMMIT;

```

After creating 'appointment\_scheduler' database, create the tables using the above script:

```
$ mysql -u root -D appointment_scheduler < <PATH_TO_SCRIPT.sql>

```

## Overview of Quartz Scheduler’s APIs and Terminologies

- [_Scheduler_](http://www.quartz-scheduler.org/api/2.2.1/org/quartz/Scheduler.html): the Primary API for scheduling, unscheduling, adding, and removing Jobs.
- [_Job_](http://www.quartz-scheduler.org/api/2.2.1/org/quartz/Job.html): The interface to be implemented by classes that represent a ‘job’ in Quartz. It has a single method called execute() where you write the work that needs to be performed by the Job.
- [_JobDetail_](http://www.quartz-scheduler.org/api/2.2.1/org/quartz/JobDetail.html) _:_ A JobDetail represents an instance of a Job. It also contains additional data in the form of a [JobDataMap](http://www.quartz-scheduler.org/api/2.2.1/org/quartz/JobDataMap.html) that is passed to the Job when it is executed. Every JobDetail is identified by a [JobKey](http://www.quartz-scheduler.org/api/2.2.1/org/quartz/JobKey.html) that consists of a _name_ and a _group_. The name must be unique within a group.
- [_Trigger_](http://www.quartz-scheduler.org/api/2.2.1/org/quartz/Trigger.html): A Trigger, as the name suggests, defines the schedule at which a given Job will be executed. A Job can have many Triggers, but a Trigger can only be associated with one Job. Every Trigger is identified by a [TriggerKey](http://www.quartz-scheduler.org/api/2.2.1/org/quartz/TriggerKey.html) that comprises of a _name_ and a _group_. The name must be unique within a group. Just like JobDetails, Triggers can also send parameters/data to the Job.
- [_JobBuilder_](http://www.quartz-scheduler.org/api/2.2.1/org/quartz/JobBuilder.html): JobBuilder is a fluent builder-style API to construct JobDetail instances.
- [_TriggerBuilder_](http://www.quartz-scheduler.org/api/2.2.1/org/quartz/TriggerBuilder.html): TriggerBuilder is used to instantiate Triggers.

## Configuring MySQL database, Quartz and Mail Sender

This is our 'src/main/resources/application.yml' file:

```
spring:
   datasource:
      url: jdbc:mysql://localhost:3306/appointment_scheduler?useSSL=false
      username: root
      password:

   quartz:
      job-store-type: jdbc
      threadPool:
         threadCount: 5

   mail:
      host: smtp.gmail.com
      port: 587
      username: your_email_here@gmail.com
      password:

      properties:
         mail:
            smtp:
               auth: true
               starttls:
                  required: true
                  enable: true

```

If we don't specify 'spring.mail.password' property, we can pass it at runtime as command line argument or set it as an environment variable.

## The classes

It's time to dig in. Let's see how we implement each layer of our API.

### The controller layer

This is our controller:

```
package com.tiago.controller;

import javax.validation.Valid;

import org.quartz.SchedulerException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.tiago.payload.ScheduleAppointmentRequest;
import com.tiago.payload.ScheduleAppointmentResponse;
import com.tiago.service.ScheduleAppointmentService;

/**
 * Restful controller responsible for scheduling appointments.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@RestController
@RequestMapping("/api")
public class AppointmentSchedulerController {

  @Autowired
  ScheduleAppointmentService service;

  /**
   * Schedules an appointment.
   *
   * @param scheduleAppointmentRequest
   * @return {@link ScheduleAppointmentResponse}
   * @throws SchedulerException
   */
  @PostMapping("/scheduleAppointment")
  public ScheduleAppointmentResponse scheduleAppointment(@Valid @RequestBody ScheduleAppointmentRequest scheduleAppointmentRequest) throws SchedulerException {
    return service.scheduleAppointment(scheduleAppointmentRequest);
  }
}

```

### DTO classes

As mentioned in my [previous article](https://www.linkedin.com/pulse/spring-boot-example-crud-restful-api-global-exception-tiago-melo/), I think it's a good idea to use [DTO](https://en.wikipedia.org/wiki/Data_transfer_object) s in a RESTFul API.

ScheduleAppointmentRequest

```
package com.tiago.payload;

import java.time.LocalDateTime;
import java.time.ZoneId;

import javax.validation.constraints.Email;
import javax.validation.constraints.FutureOrPresent;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;

/**
 * Encapsulates appointment request data.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
public class ScheduleAppointmentRequest {

  @NotBlank(message = "'name' is missing")
  private String name;

  @NotBlank(message = "'email' is missing")
  @Email
  private String email;

  @NotNull(message = "'appointmentDateTime' is missing")
  @FutureOrPresent(message = "'appointmentDateTime' must be after current date and time")
  private LocalDateTime appointmentDateTime;

  @NotNull(message = "'timeZone' is missing")
  private ZoneId timeZone;

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

  public LocalDateTime getAppointmentDateTime() {
    return appointmentDateTime;
  }

  public void setAppointmentDateTime(LocalDateTime appointmentDateTime) {
    this.appointmentDateTime = appointmentDateTime;
  }

  public ZoneId getTimeZone() {
    return timeZone;
  }

  public void setTimeZone(ZoneId timeZone) {
    this.timeZone = timeZone;
  }
}

```

ScheduleAppointmentResponse

```
package com.tiago.payload;

import java.time.LocalDateTime;

/**
 * Encapsulates appointment response data.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
public class ScheduleAppointmentResponse {

  private String appointmentId;

  private LocalDateTime scheduledDateTime;

  public String getAppointmentId() {
    return appointmentId;
  }

  public void setAppointmentId(String appointmentId) {
    this.appointmentId = appointmentId;
  }

  public LocalDateTime getScheduledDateTime() {
    return scheduledDateTime;
  }

  public void setScheduledDateTime(LocalDateTime scheduledDateTime) {
    this.scheduledDateTime = scheduledDateTime;
  }

}

```

### The service layer

Service interface:

```
package com.tiago.service;

import org.quartz.SchedulerException;

import com.tiago.payload.ScheduleAppointmentRequest;
import com.tiago.payload.ScheduleAppointmentResponse;

/**
 * Service to schedule appointments.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
public interface ScheduleAppointmentService {

  /**
   * Schedules an appointment.
   *
   * @param request {@link ScheduleAppointmentRequest}
   * @return {@link ScheduleAppointmentResponse}
   * @throws SchedulerException
   */
  ScheduleAppointmentResponse scheduleAppointment(ScheduleAppointmentRequest request) throws SchedulerException;

}

```

and its implementation:

```
package com.tiago.service.impl;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.Date;
import java.util.UUID;

import org.quartz.JobBuilder;
import org.quartz.JobDataMap;
import org.quartz.JobDetail;
import org.quartz.JobKey;
import org.quartz.Scheduler;
import org.quartz.SchedulerException;
import org.quartz.Trigger;
import org.quartz.TriggerBuilder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.tiago.job.AppointmentConfirmationEmailJob;
import com.tiago.job.AppointmentReminderEmailJob;
import com.tiago.payload.ScheduleAppointmentRequest;
import com.tiago.payload.ScheduleAppointmentResponse;
import com.tiago.service.ScheduleAppointmentService;
import com.tiago.util.DateUtil;

/**
 * Implements {@link ScheduleAppointmentService} interface.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Service
public class ScheduleAppointmentServiceImpl implements ScheduleAppointmentService {

  @Autowired
  private Scheduler scheduler;

  private JobDataMap jobDataMap;

  /* (non-Javadoc)
   * @see com.tiago.service.ScheduleAppointmentService#scheduleAppointment(com.tiago.payload.ScheduleAppointmentRequest)
   */
  @Override
  public ScheduleAppointmentResponse scheduleAppointment(ScheduleAppointmentRequest scheduleAppointmentRequest) throws SchedulerException {
    buildJobDataMap(scheduleAppointmentRequest);

    sendAppointmentConfirmationEmail();

    return scheduleAppointmentReminderEmail(scheduleAppointmentRequest.getAppointmentDateTime(), scheduleAppointmentRequest.getTimeZone());
  }

  private void sendAppointmentConfirmationEmail() throws SchedulerException {
    JobDetail jobDetail = buildJobDetail();
    JobKey jobKey = JobKey.jobKey(jobDetail.getKey().getName(), jobDetail.getKey().getGroup());

    scheduler.addJob(jobDetail, true);
    scheduler.triggerJob(jobKey);
  }

  private ScheduleAppointmentResponse scheduleAppointmentReminderEmail(LocalDateTime appointmentDateTime, ZoneId zoneId) throws SchedulerException {
    ZonedDateTime zonedDateTime = ZonedDateTime.of(appointmentDateTime, zoneId);
    JobDetail scheduledJobDetail = buildScheduledJobDetail();

    Trigger trigger = buildScheduledJobTrigger(scheduledJobDetail, Date.from(zonedDateTime.minusDays(1).toInstant()));
    scheduler.scheduleJob(scheduledJobDetail, trigger);

    return buildScheduleAppointmentResponse(scheduledJobDetail.getKey().getName(), zonedDateTime.toLocalDateTime());
  }

  private ScheduleAppointmentResponse buildScheduleAppointmentResponse(String appointmentId, LocalDateTime scheduledDateTime) {
    ScheduleAppointmentResponse scheduleAppointmentResponse = new ScheduleAppointmentResponse();

    scheduleAppointmentResponse.setAppointmentId(appointmentId);
    scheduleAppointmentResponse.setScheduledDateTime(scheduledDateTime);

    return scheduleAppointmentResponse;
  }

  private JobDetail buildJobDetail() {
    return JobBuilder.newJob(AppointmentConfirmationEmailJob.class)
        .withIdentity(UUID.randomUUID().toString(), "appointment-confirmation-email-jobs")
        .withDescription("Send Appointment Confirmation Email Job")
        .usingJobData(jobDataMap)
        .storeDurably()
        .build();
  }

  private JobDetail buildScheduledJobDetail() {
    return JobBuilder.newJob(AppointmentReminderEmailJob.class)
        .withIdentity(UUID.randomUUID().toString(), "appointment-reminder-email-jobs")
        .withDescription("Send Appointment Reminder Email Job")
        .usingJobData(jobDataMap)
        .storeDurably()
        .build();
  }

  private void buildJobDataMap(ScheduleAppointmentRequest scheduleAppointmentRequest) {
    jobDataMap = new JobDataMap();

    jobDataMap.put("name", scheduleAppointmentRequest.getName());
    jobDataMap.put("email", scheduleAppointmentRequest.getEmail());
    jobDataMap.put("scheduledDate", DateUtil.toString(scheduleAppointmentRequest.getAppointmentDateTime()));
  }

  private Trigger buildScheduledJobTrigger(JobDetail jobDetail, Date startAt) {
    return TriggerBuilder.newTrigger()
        .forJob(jobDetail)
        .withIdentity(jobDetail.getKey().getName(), "appointment-schedule-email-triggers")
        .withDescription("Send Appointment Schedule Email Trigger")
        .startAt(startAt)
        .build();
  }
}

```

Since we're using 'spring-boot-starter-quartz' starter, we can simply inject [Scheduler](http://www.quartz-scheduler.org/api/2.2.1/org/quartz/Scheduler.html) and it's already configured.

### The Quartz Jobs

This is the job that is invoked to send the confirmation e-mail:

```
package com.tiago.job;

import org.quartz.JobDataMap;
import org.quartz.JobExecutionContext;
import org.quartz.JobExecutionException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.quartz.QuartzJobBean;
import org.springframework.stereotype.Component;

import com.tiago.mailer.Mailer;

/**
 * Job class to send appointment confirmation email.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Component
public class AppointmentConfirmationEmailJob extends QuartzJobBean {

  @Autowired
  Mailer mailer;

  private static final Logger LOGGER = LoggerFactory.getLogger(AppointmentConfirmationEmailJob.class);

  private static final String SUBJECT_TEMPLATE = "%s, your appointment is confirmed to %s";

  private static final String TEXT_TEMPLATE = "Hi %s, <br><br> Your appointment is confirmed to <b>%s</b>. <br><br>See you!";

  @Override
  protected void executeInternal(JobExecutionContext jobExecutionContext) throws JobExecutionException {
    LOGGER.info("Executing Job with key {}", jobExecutionContext.getJobDetail().getKey());

    JobDataMap jobDataMap = jobExecutionContext.getMergedJobDataMap();

    String name = jobDataMap.getString("name");
    String recipientEmail = jobDataMap.getString("email");
    String scheduledDate = jobDataMap.getString("scheduledDate");
    String subject = String.format(SUBJECT_TEMPLATE, name, scheduledDate);
    String body = String.format(TEXT_TEMPLATE, name, scheduledDate);

    mailer.sendMail(name, recipientEmail, subject, body);

    LOGGER.info("Done execution of Job with key {}", jobExecutionContext.getJobDetail().getKey());
  }
}

```

And this is the job that is scheduled to send the reminder e-mail:

```
package com.tiago.job;

import org.quartz.JobDataMap;
import org.quartz.JobExecutionContext;
import org.quartz.JobExecutionException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.quartz.QuartzJobBean;
import org.springframework.stereotype.Component;

import com.tiago.mailer.Mailer;

/**
 * Job class to send appointment reminder email.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Component
public class AppointmentReminderEmailJob extends QuartzJobBean {

  @Autowired
  Mailer mailer;

  private static final Logger LOGGER = LoggerFactory.getLogger(AppointmentReminderEmailJob.class);

  private static final String SUBJECT_TEMPLATE = "%s, you have an appointment: %s";

  private static final String TEXT_TEMPLATE = "Hi %s, <br><br> Just to remember that you have an appointment: <b>%s</b>. <br><br> See you soon!";

  @Override
  protected void executeInternal(JobExecutionContext jobExecutionContext) throws JobExecutionException {
    LOGGER.info("Executing Job with key {}", jobExecutionContext.getJobDetail().getKey());

    JobDataMap jobDataMap = jobExecutionContext.getMergedJobDataMap();

    String name = jobDataMap.getString("name");
    String recipientEmail = jobDataMap.getString("email");
    String scheduledDate = jobDataMap.getString("scheduledDate");
    String subject = String.format(SUBJECT_TEMPLATE, name, scheduledDate);
    String body = String.format(TEXT_TEMPLATE, name, scheduledDate);

    mailer.sendMail(name, recipientEmail, subject, body);

    LOGGER.info("Done execution of Job with key {}", jobExecutionContext.getJobDetail().getKey());
  }
}

```

### The Mailer

This is our mailer. We are using [MimeMessage](https://javaee.github.io/javaee-spec/javadocs/javax/mail/internet/MimeMessage.html) to enable us to send HTML e-mails; we could use [SimpleMailMessage](https://docs.spring.io/spring-framework/docs/5.0.5.RELEASE/javadoc-api/org/springframework/mail/SimpleMailMessage.html) if we wanted to send plain text messages:

```
package com.tiago.mailer;

import java.nio.charset.StandardCharsets;

import javax.mail.internet.MimeMessage;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.mail.MailProperties;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Component;

/**
 * Utility class to send email.
 *
 * @author Tiago Melo (tiagoharris@gmail.com)
 *
 */
@Component
public class Mailer {

  @Autowired
  private JavaMailSender mailSender;

  @Autowired
  private MailProperties mailProperties;

  private static final Logger LOGGER = LoggerFactory.getLogger(Mailer.class);

  public void sendMail(String name, String toEmail, String subject, String body) {
    try {
      LOGGER.info("Sending Email to {}", toEmail);
      MimeMessage message = mailSender.createMimeMessage();

      MimeMessageHelper messageHelper = new MimeMessageHelper(message, StandardCharsets.UTF_8.toString());
      messageHelper.setSubject(subject);
      messageHelper.setText(body, true);
      messageHelper.setFrom(mailProperties.getUsername());
      messageHelper.setTo(toEmail);

      mailSender.send(message);

      LOGGER.info("Email sent to {}", toEmail);
    } catch (Exception ex) {
      LOGGER.error("Failed to send email to {}: {}", toEmail, ex.getMessage());
    }
  }
}

```

Again, thanks to 'spring-boot-starter-mail', [JavaMailSender](https://docs.spring.io/spring/docs/current/javadoc-api/org/springframework/mail/javamail/JavaMailSender.html) and [MailProperties](https://docs.spring.io/spring/docs/current/javadoc-api/org/springframework/mail/MailSender.html) are already configured to use.

### Exception handling

Following the example in my [previous article](https://www.linkedin.com/pulse/spring-boot-example-crud-restful-api-global-exception-tiago-melo/), this is our global exception handler:

```
package com.tiago.exception;

import org.quartz.SchedulerException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

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
   * This exception is thrown when an error occurs while scheduling
   * an appointment
   *
   * @param ex
   * @return {@link ExceptionResponse}
   */
  @ExceptionHandler(SchedulerException.class)
  public ResponseEntity<ExceptionResponse> handleSchedulerException(SchedulerException ex) {
    ExceptionResponse response = new ExceptionResponse();
    response.setErrorCode("error");
    response.setErrorMessage("an error ocurred while scheduling the appointment: " + ex.getMessage());

    return new ResponseEntity<ExceptionResponse>(response, HttpStatus.INTERNAL_SERVER_ERROR);
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

And this class represents the error JSON message that will be presented to the final user:

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

## It's show time!

Now let's explore our API. This is what it does:

- **POST /api/scheduleAppointment**: creates a schedule from a JSON in the request body

We'll use [cURL](https://curl.haxx.se/) to test it.

Fire up the server, passing your e-mail password if you didn't specify it as a property on 'src/main/re':

```
$ mvn spring-boot:run -Dspring.mail.password=<YOUR_PASSWORD>

```

### Testing POST /api/scheduleAppointment

Like I did in my [previous article](https://www.linkedin.com/pulse/spring-boot-example-crud-restful-api-global-exception-tiago-melo/), if the user submits a JSON and misses 'name', 'email', 'appointmentDateTime' or 'timeZone' properties, appropriate error messages will be presented. This is true even if 'appointmentDateTime' is in invalid format or if it's in the past.

Remember: when the user creates a schedule, a confirmation e-mail will be immediately sent and a reminder e-mail will be sent one day prior to 'appointmentDateTime'. But just to ease our testing, let's change 'ScheduleAppointmentServiceImpl#scheduleAppointmentReminderEmail' method to make it possible to receive a reminder e-mail when 'appointmentDateTime' is reached:

```
private ScheduleAppointmentResponse scheduleAppointmentReminderEmail(LocalDateTime appointmentDateTime, ZoneId zoneId) throws SchedulerException {
  ZonedDateTime zonedDateTime = ZonedDateTime.of(appointmentDateTime, zoneId);
  JobDetail scheduledJobDetail = buildScheduledJobDetail();

  //Trigger trigger = buildScheduledJobTrigger(scheduledJobDetail, Date.from(zonedDateTime.minusDays(1).toInstant()));
  Trigger trigger = buildScheduledJobTrigger(scheduledJobDetail, Date.from(zonedDateTime.toInstant()));
  scheduler.scheduleJob(scheduledJobDetail, trigger);

  return buildScheduleAppointmentResponse(scheduledJobDetail.getKey().getName(), zonedDateTime.toLocalDateTime());
}

```

Let's call it (omitting my e-mail :-P):

```
$ curl -v -H "Content-Type: application/json" -X POST "http://localhost:8080/api/scheduleAppointment" -d '{"name":"Tiago Melo", "email":"<OMITTED>", "appointmentDateTime":"2019-02-19T18:55:00" , "timeZone": "Brazil/East"}'

```

This is the response:

```
< HTTP/1.1 200
< Content-Type: application/json;charset=UTF-8
< Transfer-Encoding: chunked
< Date: Tue, 19 Feb 2019 21:52:37 GMT
<
* Connection #0 to host localhost left intact
{"appointmentId":"b912824a-d7d3-45a7-81b1-b99635fb0e0f","scheduledDateTime":"2019-02-19T18:55:00"}

```

Now let's take a look at the main console:

```
2019-02-19 18:52:36.642  INFO 22836 --- [nio-8080-exec-1] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring DispatcherServlet 'dispatcherServlet'
2019-02-19 18:52:36.643  INFO 22836 --- [nio-8080-exec-1] o.s.web.servlet.DispatcherServlet        : Initializing Servlet 'dispatcherServlet'
2019-02-19 18:52:36.652  INFO 22836 --- [nio-8080-exec-1] o.s.web.servlet.DispatcherServlet        : Completed initialization in 9 ms
2019-02-19 18:52:36.984  INFO 22836 --- [eduler_Worker-1] c.t.job.AppointmentConfirmationEmailJob  : Executing Job with key appointment-confirmation-email-jobs.574db7a3-cc1d-4a32-97ae-b8eda15ddfb5
2019-02-19 18:52:36.984  INFO 22836 --- [eduler_Worker-1] com.tiago.mailer.Mailer                  : Sending Email to <OMITTED_EMAIL>
2019-02-19 18:52:41.179  INFO 22836 --- [eduler_Worker-1] com.tiago.mailer.Mailer                  : Email sent to <OMITTED_EMAIL>
2019-02-19 18:52:41.180  INFO 22836 --- [eduler_Worker-1] c.t.job.AppointmentConfirmationEmailJob  : Done execution of Job with key appointment-confirmation-email-jobs.574db7a3-cc1d-4a32-97ae-b8eda15ddfb5

```

Well, seems that the confirmation e-mail was sent. Let's check it:

![No alt text provided for this image](/assets/images/2019-02-19-25799d90-eb49-4c8d-8421-0d41f4183572/1550613359537.png)

Great!

And then, when the appoinment date is reached (2019-02-19T18:55:00), let's check the main console again:

```
2019-02-19 18:55:00.040  INFO 22836 --- [eduler_Worker-2] c.tiago.job.AppointmentReminderEmailJob  : Executing Job with key appointment-reminder-email-jobs.b912824a-d7d3-45a7-81b1-b99635fb0e0f
2019-02-19 18:55:00.040  INFO 22836 --- [eduler_Worker-2] com.tiago.mailer.Mailer                  : Sending Email to <OMITTED_EMAIL>
2019-02-19 18:55:03.498  INFO 22836 --- [eduler_Worker-2] com.tiago.mailer.Mailer                  : Email sent to <OMITTED_EMAIL>
2019-02-19 18:55:03.499  INFO 22836 --- [eduler_Worker-2] c.tiago.job.AppointmentReminderEmailJob  : Done execution of Job with key appointment-reminder-email-jobs.b912824a-d7d3-45a7-81b1-b99635fb0e0f

```

Seems that the reminder e-mail was sent. Let's check it:

![No alt text provided for this image](/assets/images/2019-02-19-25799d90-eb49-4c8d-8421-0d41f4183572/1550613510284.png)

And it worked as expected.

## What if the applications goes down?

What happens if the applications goes down and there's pending e-mails to be sent?

Suppose that we've created the following schedule. I've issued this command at 2019-02-19 18:20:56.898:

```
$ curl -v -H "Content-Type: application/json" -X POST "http://localhost:8080/api/scheduleAppointment" -d '{"name":"Tiago Melo", "email":"<OMITTED>", "appointmentDateTime":"2019-02-19T18:22:00" , "timeZone": "Brazil/East"}'

```

We scheduled it to 2019-02-19 at 18:22:00. The job that sends confirmation e-mail was fired as expected:

```
2019-02-19 18:20:57.217  INFO 21235 --- [eduler_Worker-1] c.t.job.AppointmentConfirmationEmailJob  : Executing Job with key appointment-confirmation-email-jobs.3595ead0-accd-4233-bdfa-8c14f519c5fe
2019-02-19 18:20:57.217  INFO 21235 --- [eduler_Worker-1] com.tiago.mailer.Mailer                  : Sending Email to <OMITTED_EMAIL>
2019-02-19 18:21:01.378  INFO 21235 --- [eduler_Worker-1] com.tiago.mailer.Mailer                  : Email sent to <OMITTED_EMAIL>
2019-02-19 18:21:01.378  INFO 21235 --- [eduler_Worker-1] c.t.job.AppointmentConfirmationEmailJob  : Done execution of Job with key appointment-confirmation-email-jobs.3595ead0-accd-4233-bdfa-8c14f519c5fe

```

Let's check the mail box:

![No alt text provided for this image](/assets/images/2019-02-19-25799d90-eb49-4c8d-8421-0d41f4183572/1550611934155.png)

Everything is alright.

Now the application is stopped at 2019-02-19 18:21:04:

```
2019-02-19 18:21:04.576  INFO 21235 --- [       Thread-4] o.s.s.concurrent.ThreadPoolTaskExecutor  : Shutting down ExecutorService 'applicationTaskExecutor'
2019-02-19 18:21:04.579  INFO 21235 --- [       Thread-4] o.s.s.quartz.SchedulerFactoryBean        : Shutting down Quartz Scheduler
2019-02-19 18:21:04.580  INFO 21235 --- [       Thread-4] org.quartz.core.QuartzScheduler          : Scheduler quartzScheduler_$_NON_CLUSTERED shutting down.
2019-02-19 18:21:04.580  INFO 21235 --- [       Thread-4] org.quartz.core.QuartzScheduler          : Scheduler quartzScheduler_$_NON_CLUSTERED paused.
2019-02-19 18:21:04.582  INFO 21235 --- [       Thread-4] org.quartz.core.QuartzScheduler          : Scheduler quartzScheduler_$_NON_CLUSTERED shutdown complete.
2019-02-19 18:21:04.583  INFO 21235 --- [       Thread-4] j.LocalContainerEntityManagerFactoryBean : Closing JPA EntityManagerFactory for persistence unit 'default'
2019-02-19 18:21:04.592  INFO 21235 --- [       Thread-4] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Shutdown initiated...
2019-02-19 18:21:04.605  INFO 21235 --- [       Thread-4] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Shutdown completed.

```

There's a pending e-mail to be delivered. The reminder e-mail is scheduled to be fired at 18:22:00.

Now if we start the server later on...

```
...

2019-02-19 18:36:54.089  INFO 22238 --- [           main] org.quartz.core.QuartzScheduler          : Scheduler meta-data: Quartz Scheduler (v2.3.0) 'quartzScheduler' with instanceId 'NON_CLUSTERED'
  Scheduler class: 'org.quartz.core.QuartzScheduler' - running locally.
  NOT STARTED.
  Currently in standby mode.
  Number of jobs executed: 0
  Using thread pool 'org.quartz.simpl.SimpleThreadPool' - with 10 threads.
  Using job-store 'org.springframework.scheduling.quartz.LocalDataSourceJobStore' - which supports persistence. and is not clustered.

2019-02-19 18:36:54.089  INFO 22238 --- [           main] org.quartz.impl.StdSchedulerFactory      : Quartz scheduler 'quartzScheduler' initialized from an externally provided properties instance.
2019-02-19 18:36:54.089  INFO 22238 --- [           main] org.quartz.impl.StdSchedulerFactory      : Quartz scheduler version: 2.3.0
2019-02-19 18:36:54.090  INFO 22238 --- [           main] org.quartz.core.QuartzScheduler          : JobFactory set to: org.springframework.scheduling.quartz.SpringBeanJobFactory@51dd7905
2019-02-19 18:36:54.426  INFO 22238 --- [           main] o.s.s.concurrent.ThreadPoolTaskExecutor  : Initializing ExecutorService 'applicationTaskExecutor'
2019-02-19 18:36:54.493  WARN 22238 --- [           main] aWebConfiguration$JpaWebMvcConfiguration : spring.jpa.open-in-view is enabled by default. Therefore, database queries may be performed during view rendering. Explicitly configure spring.jpa.open-in-view to disable this warning
2019-02-19 18:36:54.704  INFO 22238 --- [           main] o.s.s.quartz.SchedulerFactoryBean        : Starting Quartz Scheduler now
2019-02-19 18:36:54.754  INFO 22238 --- [           main] o.s.s.quartz.LocalDataSourceJobStore     : Freed 0 triggers from 'acquired' / 'blocked' state.
2019-02-19 18:36:54.756  INFO 22238 --- [           main] o.s.s.quartz.LocalDataSourceJobStore     : Handling 1 trigger(s) that missed their scheduled fire-time.
2019-02-19 18:36:54.793  INFO 22238 --- [           main] o.s.s.quartz.LocalDataSourceJobStore     : Recovering 0 jobs that were in-progress at the time of the last shut-down.
2019-02-19 18:36:54.794  INFO 22238 --- [           main] o.s.s.quartz.LocalDataSourceJobStore     : Recovery complete.
2019-02-19 18:36:54.795  INFO 22238 --- [           main] o.s.s.quartz.LocalDataSourceJobStore     : Removed 0 'complete' triggers.
2019-02-19 18:36:54.796  INFO 22238 --- [           main] o.s.s.quartz.LocalDataSourceJobStore     : Removed 0 stale fired job entries.
2019-02-19 18:36:54.801  INFO 22238 --- [           main] org.quartz.core.QuartzScheduler          : Scheduler quartzScheduler_$_NON_CLUSTERED started.
2019-02-19 18:36:54.884  INFO 22238 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat started on port(s): 8080 (http) with context path ''
2019-02-19 18:36:54.891  INFO 22238 --- [           main] t.AppointmentSchedulerExampleApplication : Started AppointmentSchedulerExampleApplication in 4.419 seconds (JVM running for 7.56)
2019-02-19 18:36:54.892  INFO 22238 --- [eduler_Worker-1] c.tiago.job.AppointmentReminderEmailJob  : Executing Job with key appointment-reminder-email-jobs.1e10709d-eb1c-4fc9-be79-b17ed36d9487
2019-02-19 18:36:54.893  INFO 22238 --- [eduler_Worker-1] com.tiago.mailer.Mailer                  : Sending Email to <OMITTED_EMAIL>
2019-02-19 18:36:59.440  INFO 22238 --- [eduler_Worker-1] com.tiago.mailer.Mailer                  : Email sent to <OMITTED_EMAIL>
2019-02-19 18:36:59.441  INFO 22238 --- [eduler_Worker-1] c.tiago.job.AppointmentReminderEmailJob  : Done execution of Job with key appointment-reminder-email-jobs.1e10709d-eb1c-4fc9-be79-b17ed36d9487

```

Notice this:

```
2019-02-19 18:36:54.756  INFO 22238 --- [           main] o.s.s.quartz.LocalDataSourceJobStore     : Handling 1 trigger(s) that missed their scheduled fire-time.

```

Quartz Scheduler noticed that there's one pending e-mail whose scheduled fire-time was missed, so it will immediately fire it.

And the e-mail arrives, safe and sound:

![No alt text provided for this image](/assets/images/2019-02-19-25799d90-eb49-4c8d-8421-0d41f4183572/1550612603020.png)

## Conclusion

Through this simple example we learnt how we can use [Quartz](http://www.quartz-scheduler.org/) with [Spring Boot](https://spring.io/projects/spring-boot). We saw how we can save time by using Quartz and Mail starters, as well as how to run jobs immediately and how to schedule one.

## Download the source code

Here: [https://bitbucket.org/tiagoharris/appointment-scheduler-example/src/master/](https://bitbucket.org/tiagoharris/appointment-scheduler-example/src/master/)
