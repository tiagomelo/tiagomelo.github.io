---
layout: post
title:  "Golang: uploading files to an AWS S3 bucket using pre-signed URL"
date:   2022-10-14 13:26:01 -0300
categories: go aws s3
---
![Golang: uploading files to an AWS S3 bucket using pre-signed URL](/assets/images/2022-10-14-d040f8c1-9082-4671-b37e-01df4eebb1d1/2022-04-14-banner.jpeg)

We all know that it is a best practice to keep [S3 buckets](https://aws.amazon.com/s3/?trk=article-ssr-frontend-pulse_little-text-block) private and only grant public access when absolutely required. So how can we grant a client (temporarily) to put an object on it without changing the bucket's [ACL](https://docs.aws.amazon.com/AmazonS3/latest/userguide/acl-overview.html?trk=article-ssr-frontend-pulse_little-text-block), creating roles or providing a user on your account? There's where [S3 pre-signed URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ShareObjectPreSignedURL.html?trk=article-ssr-frontend-pulse_little-text-block) come to play.

## Pre-signed URLs

They are a form of an [S3](https://aws.amazon.com/s3/?trk=article-ssr-frontend-pulse_little-text-block) URL that temporarily grants restricted access to a single S3 object to perform a single operation — either PUT or GET — for a predefined time limit.

In a nutshell,

- It is secure — the URL is signed using an AWS access key
- It grants restricted access — only one of GET or PUT is allowed for a single URL
- Only to a single object — each pre-signed URL corresponds to one object
- With a time-constrained — the URL expires after a set timeout

### Pitfalls

Here are some pointers to keep in mind:

1. You must send the same HTTP headers — when accessing a pre-signed URL — as you used when you generated it. For example, if you generate a pre-signed URL with the Content-Type header, then you must also provide this header when you access the pre-signed URL. Beware that some libraries - for example, Axios - attach default headers, such as Content-Type, if you don't provide your own.
2. The default pre-signed URL expiration time is 15 minutes. Make sure to adjust this value to your specific needs. Security-wise, you should keep it to the minimum possible — eventually, it depends on your design.
3. To upload a large file — larger than 10MB — you need to use multi-part upload. I'll write an article on it very soon.
4. Pre-signed URLs support only the getObject, putObject and uploadPart functions from the [AWS SDK](https://aws.amazon.com/sdk-for-go/?trk=article-ssr-frontend-pulse_little-text-block) for S3. It's impossible to grant any other access to an object or a bucket, such as listBucket.
5. Because of the previously mentioned [AWS SDK](https://aws.amazon.com/sdk-for-go/?trk=article-ssr-frontend-pulse_little-text-block) functions limitation, you can’t use pre-signed URLs as [Lambda](https://aws.amazon.com/lambda/?trk=article-ssr-frontend-pulse_little-text-block) function sources, since [Lambda](https://aws.amazon.com/lambda/?trk=article-ssr-frontend-pulse_little-text-block) requires both listBucket and getObject access to an [S3](https://aws.amazon.com/s3/?trk=article-ssr-frontend-pulse_little-text-block) object to use as a source.

## Sample implementation in Golang

Here's a sample implementation in [Golang](http://golang.org?trk=article-ssr-frontend-pulse_little-text-block): a [CLI](https://en.wikipedia.org/wiki/Command-line_interface?trk=article-ssr-frontend-pulse_little-text-block) that enables you to both upload and delete a file in a given bucket with a given key.

### Prerequisites

You need to have aws cli installed & configured with your access/secret keys.

### Pre-signing the request

Let's take a look at our [S3](https://aws.amazon.com/s3/?trk=article-ssr-frontend-pulse_little-text-block) client, specifically at how we sign the request in order to be able to upload a file:

```

// Copyright (c) 2022 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package s3

import (
    "fmt"
    "net/http"
    "os"
    "time"

    "github.com/aws/aws-sdk-go/aws"
    "github.com/aws/aws-sdk-go/aws/request"
    "github.com/aws/aws-sdk-go/aws/session"
    "github.com/aws/aws-sdk-go/service/s3"
    "github.com/pkg/errors"
)

// for ease of unit tests
var (
    newSession = session.NewSession
    osOpen     = os.Open
    fileSize   = func(file *os.File) (int64, error) {
        fileInfo, err := file.Stat()
        if err != nil {
            return 0, err
        }
        return fileInfo.Size(), nil
    }
    httpNewRequest   = http.NewRequest
    putObjectRequest = func(session *session.Session, input *s3.PutObjectInput) (req *request.Request, output *s3.PutObjectOutput) {
        return s3.New(session).PutObjectRequest(input)
    }
    deleteObject = func(session *session.Session, input *s3.DeleteObjectInput) (*s3.DeleteObjectOutput, error) {
        return s3.New(session).DeleteObject(input)
    }
    preSignRequest = func(req *request.Request, expire time.Duration) (string, error) {
        return req.Presign(expire)
    }
    doRequest = func(req *http.Request) (*http.Response, error) {
        return http.DefaultClient.Do(req)
    }
)

// client to interact with S3 using AWS SDK.
type client struct {
    session *session.Session
}

// NewClient creates a client using the specified AWS region.
func NewClient(region string) (*client, error) {
    s, err := newSession(&aws.Config{Region: aws.String(region)})
    if err != nil {
        return nil, err
    }
    return &client{s}, nil
}

// isSuccessfull checks wether an HTTP status code is withing 20x range.
func isSuccessfull(statusCode int) bool {
    return statusCode >= 200 && statusCode <= 299
}

// preSignUploadFileRequest generates a signed URL from a given bucket and returns
// *http.Request ready to be used.
func preSignUploadFileRequest(session *session.Session, key, bucket string, file *os.File, contentLen int64) (*http.Request, error) {
    req, _ := putObjectRequest(session, &s3.PutObjectInput{
        Bucket: aws.String(bucket),
        Key:    aws.String(key),
        Body:   file,
        // we need to set up content length to be included in the signature.
        ContentLength: aws.Int64(contentLen),
    })
    str, err := preSignRequest(req, 15*time.Minute)
    if err != nil {
        return nil, errors.Wrap(err, "pre signing request")
    }
    httpReq, err := httpNewRequest(http.MethodPut, str, file)
    if err != nil {
        return nil, errors.Wrap(err, "creating http request")
    }
    // setting the content length header with the same length
    httpReq.ContentLength = contentLen
    return httpReq, nil
}

// UploadFile uploads a file using a key to a given bucket.
func (c *client) UploadFile(key, bucket, filePath string) error {
    file, err := osOpen(filePath)
    if err != nil {
        return errors.Wrapf(err, `reading file "%s"`, filePath)
    }
    defer file.Close()
    fileSize, err := fileSize(file)
    if err != nil {
        return errors.Wrapf(err, `getting file size for file "%s"`, filePath)
    }
    req, err := preSignUploadFileRequest(c.session, key, bucket, file, fileSize)
    if err != nil {
        return err
    }
    resp, err := doRequest(req)
    if err != nil {
        return errors.Wrap(err, "making request")
    }
    statusCode := resp.StatusCode
    if !isSuccessfull(statusCode) {
        return fmt.Errorf("got http status code != 200: %d", statusCode)
    }
    return nil
}

// DeleteFile deletes a file with key from a given bucket.
func (c *client) DeleteFile(key, bucket string) error {
    if _, err := deleteObject(c.session, &s3.DeleteObjectInput{
        Bucket: aws.String(bucket),
        Key:    aws.String(key),
    }); err != nil {
        return errors.Wrapf(err, `deleting file with key "%s" from bucket "%s"`, key, bucket)
    }
    return nil
}

```

Breaking it down:

1. open the file and get its size;
2. create a PutObjectRequest passing along the bucket name, the desired key, the object data and its size. This information will be used to generate the signed url;
3. call Presign to generate the signed url;
4. create a \*http.Request using the generated url. It will be a PUT with the file in its body, along with Content-Lengh header properly set;
5. perform the request.

The delete operation is way simpler, since you have the right to delete files that you created. It is a matter of calling DeleteObject passing along the desired key and bucket.

## Running it

### Uploading a file

```

$ go run cmd/main.go -a upload -b test-tiago -f /Users/tiagomelo/Documents/test.txt -k test.txt

uploading file '/Users/tiagomelo/Documents/test.txt' to bucket 'test-tiago' with key 'test.txt'... success!

```

### Deleting a file

```

$ go run cmd/main.go -a delete -b test-tiago -k test.txt

deleting file with key 'test.txt' from bucket 'test-tiago'... success!

```

## Download the source

Here: [https://bitbucket.org/tiagoharris/s3-signed-url-tutorial](https://bitbucket.org/tiagoharris/s3-signed-url-tutorial?trk=article-ssr-frontend-pulse_little-text-block)
