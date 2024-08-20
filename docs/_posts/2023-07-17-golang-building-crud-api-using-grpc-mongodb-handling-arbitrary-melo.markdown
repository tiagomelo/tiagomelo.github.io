---
layout: post
title:  "Golang: building a CRUD API using GRPC and MongoDB + handling arbitrary data types"
date:   2023-07-17 13:26:01 -0300
categories: go grpc mongodb
---
![Golang: building a CRUD API using GRPC and MongoDB + handling arbitrary data types](/assets/images/2023-07-17-fc3352e1-3ef8-424c-a0af-7aa5e0492d3a/2023-07-17-banner.jpeg)

If you follow my posts, you may remember the articles I've written talking about [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) services:

- [Golang: a dockerized gRPC server example](https://www.linkedin.com/pulse/go-dockerized-grpc-server-example-tiago-melo?trk=article-ssr-frontend-pulse_little-text-block)
- [Golang: a dockerized gRPC service using TLS](https://www.linkedin.com/pulse/golang-dockerized-grpc-service-using-tls-tiago-melo?trk=article-ssr-frontend-pulse_little-text-block)

This time I'd like to show how to build a [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete?trk=article-ssr-frontend-pulse_little-text-block) API using [MongoDB](http://mongodb.com?trk=article-ssr-frontend-pulse_little-text-block). More than that, we'll see how to handle arbitrary data types.

## The Need for Flexibility in Data Structures

In many real-world applications, the structure and attributes of data can vary significantly between entities. Take, for example, an e-commerce platform that deals with a diverse range of products. Each product can possess different attributes, such as color (string), size (number), weight (number), or even complex properties like a list of available sizes or recommended products. Traditional relational databases often struggle to handle such dynamic structures efficiently, as altering the schema for each change becomes a cumbersome task.

## MongoDB's Schemaless Nature

[MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block), on the other hand, is a document-oriented NoSQL database that embraces a schemaless design. This means that [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) allows you to store documents with varying structures within the same collection. With the absence of rigid schemas, [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) grants developers the freedom to work with evolving data models without the need for extensive schema modifications or migrations. This characteristic makes [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) an excellent choice for APIs dealing with arbitrary data types, such as our example of a product domain model.

## Handling Arbitrary Data Types

In our [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete?trk=article-ssr-frontend-pulse_little-text-block) API implementation, we will utilize [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) to store and retrieve product data. The flexible nature of [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) allows us to effortlessly handle the diverse attributes associated with different product types. For instance, we can store a product with attributes like color (string), size (number), or any other custom field that a particular product may require. With [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block)'s dynamic schema, we can easily accommodate these varying attributes, making it an ideal database for our use case.

## Implementing the CRUD API

### Protofile and its compilation

api/proto/productcatalog.proto

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
syntax = "proto3";

import "google/protobuf/struct.proto";

// Package productcatalog defines the service and message types for managing products.
package productcatalog;
option go_package = "github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data/api/proto/gen/productcatalog";

// Product is a data structure that represents an item for sale.
message Product {
    string uuid = 1;  // Unique identifier for the product.
    string name = 2;  // The name of the product.
    string description = 3;  // A detailed description of the product.
    float price = 4;  // The price of the product.
    map<string, google.protobuf.Value> attributes = 5; // The product attributes.
}

// ProductCatalogService defines the methods for managing products.
service ProductCatalogService {
    rpc CreateProduct (Product) returns (Product) {}  // Creates a new product.
    rpc GetProduct (GetProductRequest) returns (Product) {}  // Retrieves a specific product.
    rpc UpdateProduct (Product) returns (Product) {}  // Updates a specific product.
    rpc DeleteProduct (DeleteProductRequest) returns (DeleteProductResponse) {}  // Deletes a specific product.
    rpc ListProducts (ListProductsRequest) returns (ListProductsResponse) {}  // Lists all products.
}

// GetProductRequest is the request structure for retrieving a specific product.
message GetProductRequest {
    string uuid = 1;  // Unique identifier of the product to retrieve.
}

// DeleteProductRequest is the request structure for deleting a specific product.
message DeleteProductRequest {
    string uuid = 1;  // Unique identifier of the product to delete.
}

// DeleteProductResponse is the response structure for the delete product operation.
message DeleteProductResponse {
    string result = 1;  // Result of the deletion operation.
}

// ListProductsRequest is the request structure for listing all products.
message ListProductsRequest {}

// ListProductsResponse is the response structure for the list products operation.
message ListProductsResponse {
    repeated Product products = 1;  // A list of products.
}

```

google.protobuf.Value is a well-known type for encoding JSON-like data structures. It has the ability to represent null, boolean, number, string, lists (arrays), and objects (key-value pairs) - all the basic types of a typical JSON value. So it's kind of a dynamic data container for these data types.

Here's our target in Makefile that compiles it:

```
.PHONY: proto
## proto: compiles .proto files
proto:
    @ rm -rf api/proto/gen/productcatalog
    @ mkdir -p api/proto/gen/productcatalog
    @ cd api/proto ; \
    protoc --go_out=gen/productcatalog --go_opt=paths=source_relative --go-grpc_out=gen/productcatalog --go-grpc_opt=paths=source_relative productcatalog.proto

```

After invoking it,

```
$ make proto
```

we'll have both productcatalog\_grpc.pb.go and productcatalog.pb.go files under api/proto/gen/productcatalog folder.

### The data layer

store/store.go provides a function to connect to the [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) instance:

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
//
// Package store provides functionality to connect to a
// MongoDB instance and perform database operations.
package store

import (
    "context"
    "fmt"

    "github.com/pkg/errors"
    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

type MongoDb struct {
    DatabaseName string
    *mongo.Client
}

// For ease of unit testing.
var (
    newClient = func(opts ...*options.ClientOptions) (*mongo.Client, error) {
        return mongo.NewClient(opts...)
    }
    connect = func(ctx context.Context, client *mongo.Client) error {
        return client.Connect(ctx)
    }
    ping = func(ctx context.Context, client *mongo.Client) error {
        return client.Ping(ctx, nil)
    }
)

// Connect connects to a running MongoDB instance.
func Connect(ctx context.Context, host, database string, port int) (*MongoDb, error) {
    client, err := newClient(options.Client().ApplyURI(
        uri(host, port),
    ))
    if err != nil {
        return nil, errors.Wrap(err, "failed to create MongoDB client")
    }
    err = connect(ctx, client)
    if err != nil {
        return nil, errors.Wrap(err, "failed to connect to MongoDB server")
    }
    err = ping(ctx, client)
    if err != nil {
        return nil, errors.Wrap(err, "failed to ping MongoDB server")
    }
    return &MongoDb{
        DatabaseName: database,
        Client:       client,
    }, nil
}

// uri generates uri string for connecting to MongoDB.
func uri(host string, port int) string {
    const format = "mongodb://%s:%d"
    return fmt.Sprintf(format, host, port)
}

```

store/product/models/models.go is the product model in [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block):

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
//
// Package models provides the data models used in the application.
package models

// Product represents a product with its associated attributes.
type Product struct {
    Uuid        string                 `bson:"uuid"`
    Name        string                 `bson:"name"`
    Description string                 `bson:"description"`
    Price       float32                `bson:"price"`
    Attributes  map[string]interface{} `bson:"attributes"`
}

```

store/product/product.go support the [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete?trk=article-ssr-frontend-pulse_little-text-block) operations:

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
//
// Package product provides the business logic and data operations for the product catalog.
// It includes functions for creating, getting, updating, deleting, and listing products.
package product

import (
    "context"
    "fmt"

    "github.com/google/uuid"
    "github.com/pkg/errors"
    "github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data/api/proto/gen/productcatalog"
    "github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data/store"
    "github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data/store/product/models"
    "go.mongodb.org/mongo-driver/bson"
    "go.mongodb.org/mongo-driver/mongo"
)

const collectionName = "products"

// Cursor is an interface that defines the methods necessary for iterating
// over query results in a data layer.
// This interface is particularly useful for simplifying unit tests
// by allowing the implementation of mock cursors that can be used
// for testing data retrieval and manipulation operations.
type Cursor interface {
    Decode(interface{}) error
    Err() error
    Close(context.Context) error
    Next(context.Context) bool
}

type cursorWrapper struct {
    *mongo.Cursor
}

// For ease of unit testing.
var (
    uuidProvider         = uuid.NewString
    insertIntoCollection = func(ctx context.Context, collection *mongo.Collection, document interface{}) (*mongo.InsertOneResult, error) {
        return collection.InsertOne(ctx, document)
    }
    find = func(ctx context.Context, collection *mongo.Collection, filter interface{}) (Cursor, error) {
        cur, err := collection.Find(ctx, filter)
        return &cursorWrapper{cur}, err
    }
    findOne = func(ctx context.Context, collection *mongo.Collection, filter interface{}, p *models.Product) error {
        sr := collection.FindOne(ctx, filter)
        return sr.Decode(p)
    }
    updateOne = func(ctx context.Context, collection *mongo.Collection, filter interface{}, update interface{}) (*mongo.UpdateResult, error) {
        return collection.UpdateOne(ctx, filter, update)
    }
    deleteOne = func(ctx context.Context, collection *mongo.Collection, filter interface{}) (*mongo.DeleteResult, error) {
        return collection.DeleteOne(ctx, filter)
    }
)

// Get retrieves a product from the database by uuid.
func Get(ctx context.Context, db *store.MongoDb, req *productcatalog.GetProductRequest) (*models.Product, error) {
    coll := db.Client.Database(db.DatabaseName).Collection(collectionName)
    var product models.Product
    err := findOne(ctx, coll, bson.M{"uuid": req.GetUuid()}, &product)
    if err != nil {
        if err == mongo.ErrNoDocuments {
            return nil, fmt.Errorf(`product with uuid "%s" does not exist`, req.GetUuid())
        }
        return nil, errors.Wrapf(err, `getting product with uuid "%s"`, req.GetUuid())
    }
    return &product, nil
}

// Create creates a new product in the database.
func Create(ctx context.Context, db *store.MongoDb, newProduct *models.Product) (*models.Product, error) {
    coll := db.Client.Database(db.DatabaseName).Collection(collectionName)
    newProduct.Uuid = uuidProvider()
    _, err := insertIntoCollection(ctx, coll, newProduct)
    if err != nil {
        return nil, errors.Wrap(err, "inserting product")
    }
    return newProduct, nil
}

// Update updates a product in the database.
func Update(ctx context.Context, db *store.MongoDb, productToUpdate *models.Product) (*models.Product, error) {
    coll := db.Client.Database(db.DatabaseName).Collection(collectionName)
    _, err := updateOne(ctx, coll, bson.M{"uuid": productToUpdate.Uuid}, bson.M{"$set": productToUpdate})
    if err != nil {
        return nil, errors.Wrapf(err, `updating product with uuid "%s"`, productToUpdate.Uuid)
    }
    return productToUpdate, nil
}

// Delete deletes a product from the database by uuid.
func Delete(ctx context.Context, db *store.MongoDb, req *productcatalog.DeleteProductRequest) (*productcatalog.DeleteProductResponse, error) {
    coll := db.Client.Database(db.DatabaseName).Collection(collectionName)
    _, err := deleteOne(ctx, coll, bson.M{"uuid": req.Uuid})
    if err != nil {
        return nil, errors.Wrapf(err, `deleting product with uuid "%s"`, req.Uuid)
    }
    return &productcatalog.DeleteProductResponse{Result: "success"}, nil
}

// List lists all products in the database.
func List(ctx context.Context, db *store.MongoDb, req *productcatalog.ListProductsRequest) ([]*models.Product, error) {
    coll := db.Client.Database(db.DatabaseName).Collection(collectionName)
    cur, err := find(ctx, coll, bson.M{})
    if err != nil {
        return nil, errors.Wrap(err, "finding products")
    }
    defer cur.Close(ctx)
    var products []*models.Product
    for cur.Next(ctx) {
        var product models.Product
        if err = cur.Decode(&product); err != nil {
            return nil, errors.Wrap(err, "decoding product")
        }
        products = append(products, &product)
    }
    if err := cur.Err(); err != nil {
        return nil, errors.Wrap(err, "cursor error")
    }
    return products, nil
}

```

### Setting Up the gRPC Server

server/server.go implements the [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) operations:

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
//
// Package server implements the gRPC server for the product catalog service.
// It provides functions to handle CRUD operations for products.
//
// The server package is responsible for setting up the gRPC server,
// registering the product catalog service, and routing incoming gRPC
// requests to the corresponding functions in the product package.
package server

import (
    "context"

    "github.com/pkg/errors"
    "github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data/api/proto/gen/productcatalog"
    "github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data/mapper"
    "github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data/store"
    "github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data/store/product"
    "google.golang.org/grpc"
    "google.golang.org/grpc/reflection"
)

// server implements the ProductCatalogServiceServer interface.
// It handles the gRPC requests and delegates the actual processing to
// the corresponding functions in the product package.
type server struct {
    productcatalog.UnimplementedProductCatalogServiceServer
    GrpcSrv *grpc.Server
    db      *store.MongoDb
}

// New creates a new instance of the server with the provided database client.
// It sets up the gRPC server, registers the product catalog service,
// and initializes reflection for gRPC server debugging.
func New(db *store.MongoDb) *server {
    grpcServer := grpc.NewServer()
    srv := &server{
        GrpcSrv: grpcServer,
        db:      db}
    productcatalog.RegisterProductCatalogServiceServer(grpcServer, srv)
    reflection.Register(grpcServer)
    return srv
}

// CreateProduct creates a new product in the catalog.
// It delegates the actual creation logic to the product package's Create function.
func (s *server) CreateProduct(ctx context.Context, in *productcatalog.Product) (*productcatalog.Product, error) {
    newProduct, err := mapper.ProductProtobufToProductModel(in)
    if err != nil {
        return nil, err
    }
    createdProduct, err := product.Create(ctx, s.db, newProduct)
    if err != nil {
        return nil, err
    }
    protoResponse, err := mapper.ProductModelToProductProtobuf(createdProduct)
    if err != nil {
        return nil, err
    }
    return protoResponse, nil
}

// GetProduct retrieves a product by its ID from the catalog.
// It delegates the actual retrieval logic to the product package's Get function.
func (s *server) GetProduct(ctx context.Context, in *productcatalog.GetProductRequest) (*productcatalog.Product, error) {
    product, err := product.Get(ctx, s.db, in)
    if err != nil {
        return nil, errors.Wrapf(err, "getting product with uuid %s", in.Uuid)
    }
    protoResponse, err := mapper.ProductModelToProductProtobuf(product)
    if err != nil {
        return nil, err
    }
    return protoResponse, nil
}

// UpdateProduct updates an existing product in the catalog.
// It delegates the actual update logic to the product package's Update function.
func (s *server) UpdateProduct(ctx context.Context, in *productcatalog.Product) (*productcatalog.Product, error) {
    productToUpdate, err := mapper.ProductProtobufToProductModel(in)
    if err != nil {
        return nil, err
    }
    updatedProduct, err := product.Update(ctx, s.db, productToUpdate)
    if err != nil {
        return nil, err
    }
    protoResponse, err := mapper.ProductModelToProductProtobuf(updatedProduct)
    if err != nil {
        return nil, err
    }
    return protoResponse, nil
}

// DeleteProduct deletes a product from the catalog.
// It delegates the actual deletion logic to the product package's Delete function.
func (s *server) DeleteProduct(ctx context.Context, in *productcatalog.DeleteProductRequest) (*productcatalog.DeleteProductResponse, error) {
    resp, err := product.Delete(ctx, s.db, in)
    if err != nil {
        return nil, errors.Wrapf(err, "deleting product with uuid %s", in.Uuid)
    }
    return resp, nil
}

// ListProducts lists all the products in the catalog.
// It delegates the actual listing logic to the product package's ListProducts function.
func (s *server) ListProducts(ctx context.Context, in *productcatalog.ListProductsRequest) (*productcatalog.ListProductsResponse, error) {
    products, err := product.List(ctx, s.db, in)
    if err != nil {
        return nil, errors.Wrap(err, "listing products")
    }
    protoResponse, err := mapper.ProductModelListToListProductsResponse(products)
    if err != nil {
        return nil, err
    }
    return protoResponse, nil
}

```

The main logic of the server involves accepting incoming [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) requests as protobuf messages. These messages are then converted into corresponding database models when necessary. The server processes the requests using the appropriate [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete?trk=article-ssr-frontend-pulse_little-text-block) operations from the database layer and returns the results back as protobuf messages. This ensures smooth communication between the [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) API and the [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) data layer, allowing for seamless data exchange between the client and the server.

### Mapper

mapper/mapper.go contains functions used by the server to convert db models to protobuf messages and vice-versa:

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
//
// Package mapper provides functions for converting between Protobuf messages
// and MongoDB models in the context of a product catalog.
// The functions in this package handle the conversion of product data between
// the Protobuf representation used in the API and the MongoDB model representation
// used in the data store.
package mapper

import (
    "github.com/pkg/errors"
    "github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data/api/proto/gen/productcatalog"
    "github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data/store/product/models"
    "google.golang.org/protobuf/types/known/structpb"
)

// For ease of unit testing.
var structpbNewValue = structpb.NewValue

// ProductProtobufToProductModel converts a Protobuf Product message to a MongoDB Product model.
func ProductProtobufToProductModel(product *productcatalog.Product) (*models.Product, error) {
    dbProduct := &models.Product{
        Uuid:        product.Uuid,
        Name:        product.Name,
        Description: product.Description,
        Price:       product.Price,
    }
    attributes := make(map[string]interface{})
    for k, p := range product.Attributes {
        attributes[k] = p.AsInterface()
    }
    dbProduct.Attributes = attributes
    return dbProduct, nil
}

// ProductModelToProductProtobuf converts a MongoDB Product model to a Protobuf Product message.
func ProductModelToProductProtobuf(dbProduct *models.Product) (*productcatalog.Product, error) {
    product := &productcatalog.Product{
        Uuid:        dbProduct.Uuid,
        Name:        dbProduct.Name,
        Description: dbProduct.Description,
        Price:       dbProduct.Price,
    }
    var err error
    attributes := make(map[string]*structpb.Value)
    for k, p := range dbProduct.Attributes {
        attributes[k], err = structpbNewValue(p)
        if err != nil {
            return nil, errors.Wrapf(err, `parsing attribute "%s"`, k)
        }
    }
    product.Attributes = attributes
    return product, nil
}

// ProductModelListToListProductsResponse converts a list of MongoDB Product models to a Protobuf ListProductsResponse message.
func ProductModelListToListProductsResponse(dbProducts []*models.Product) (*productcatalog.ListProductsResponse, error) {
    response := &productcatalog.ListProductsResponse{}
    products := []*productcatalog.Product{}
    for _, dbProduct := range dbProducts {
        product, err := ProductModelToProductProtobuf(dbProduct)
        if err != nil {
            return nil, err
        }
        products = append(products, product)
    }
    response.Products = products
    return response, nil
}

```

Here's the big deal.

The attributes map is used in the mapper functions to convert attributes between Protobuf messages and MongoDB models.

In the ProductProtobufToProductModel function, the Protobuf attributes are stored as interface{} values in the attributes map. This allows flexibility in handling attributes of different types.

In the ProductModelToProductProtobuf function, the MongoDB attributes are stored as \*structpb.Value values in the attributes map. This ensures compatibility with the Protobuf representation of attributes.

These attribute conversion techniques facilitate seamless translation between Protobuf messages and [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) models, ensuring accurate representation of attribute values during data operations.

### Docker compose

docker-compose.yaml where we are defining two [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) instances, one to be used for the app and the other to be used for integration tests:

```
version: "3.8"
services:
  mongodb:
    image: mongo:latest
    container_name: ${MONGODB_DATABASE_CONTAINER_NAME}
    ports:
      - "27030:27017"
    volumes:
      - grpctutorial_mongodb_data:/data/db
    env_file:
      - .env
  mongodb_test:
    image: mongo:latest
    container_name: ${MONGODB_TEST_DATABASE_CONTAINER_NAME}
    ports:
      - "27031:27017"
    volumes:
      - grpctutorial_mongodb_test_data:/data/db
    env_file:
      - .env
volumes:
  grpctutorial_mongodb_data:
  grpctutorial_mongodb_test_data:

```

### Configuration file

.env holds all configuration variables that can be exported as env vars:

```
MONGODB_DATABASE=grpctutorial
MONGODB_HOST_NAME=localhost
MONGODB_PORT=27030
MONGODB_DATABASE_CONTAINER_NAME=grpc_tutorial_mongodb
MONGODB_TEST_DATABASE=grpctutorial
MONGODB_TEST_HOST_NAME=localhost
MONGODB_TEST_PORT=27031
MONGODB_TEST_DATABASE_CONTAINER_NAME=grpc_tutorial_mongodb_test
GRPC_SERVER_PORT=4000
```

### Reading configuration

config/config.go reads the .env file and parse it to a Config struct:

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
//
// Package config provides functions for reading and processing the application configuration.
// It reads environment variables from a file and populates a Config struct with the values.
// The configuration struct holds all the necessary configuration values needed by the application.
package config

import (
    "github.com/joho/godotenv"
    "github.com/kelseyhightower/envconfig"
    "github.com/pkg/errors"
)

// Config holds all the configuration needed by the application.
type Config struct {
    MongodbDatabase     string `envconfig:"MONGODB_DATABASE" required:"true"`
    MongodbHostName     string `envconfig:"MONGODB_HOST_NAME" required:"true"`
    MongodbPort         int    `envconfig:"MONGODB_PORT" required:"true"`
    MongodbTestDatabase string `envconfig:"MONGODB_TEST_DATABASE" required:"true"`
    MongodbTestHostName string `envconfig:"MONGODB_TEST_HOST_NAME" required:"true"`
    MongodbTestPort     int    `envconfig:"MONGODB_TEST_PORT" required:"true"`
    GrpcServerṔort      int    `envconfig:"GRPC_SERVER_PORT" required:"true"`
}

// For ease of unit testing.
var (
    godotenvLoad     = godotenv.Load
    envconfigProcess = envconfig.Process
)

// Read reads the environment variables from the given file and returns a Config.
func Read(envFilePath string) (*Config, error) {
    if err := godotenvLoad(envFilePath); err != nil {
        return nil, errors.Wrap(err, "loading env vars")
    }
    config := new(Config)
    if err := envconfigProcess("", config); err != nil {
        return nil, errors.Wrap(err, "processing env vars")
    }
    return config, nil
}

```

## Running it

You can use a tool like [Postman](http://postman.com?trk=article-ssr-frontend-pulse_little-text-block) to make the requests.

```
$ make run
```

This will launch the MongoDB instance and the [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) server.

### Create product

Whenever we create a product, a [UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier?trk=article-ssr-frontend-pulse_little-text-block) will be assigned to it. It makes it easer to keep the uniqueness of a product's identifier.

Payload:

```
{
  "name": "Product Name",
  "description": "Product description",
  "price": 9.99,
  "attributes": {
    "color": {
      "string_value": "blue"
    },
    "size": {
      "number_value": 2
    }
  }
}
```

Protobuf supports other value types for attributes. Here are the possible value types and their corresponding fields:

1. null\_value: Represents a null value for an attribute. It can be specified as "null\_value": null.
2. number\_value: Represents a numeric value for an attribute. It can be specified using a numerical value, like "number\_value": 2.5.
3. string\_value: Represents a string value for an attribute. It can be specified using a string, like "string\_value": "blue".
4. bool\_value: Represents a boolean value for an attribute. It can be specified as either "bool\_value": true or "bool\_value": false.
5. struct\_value: Represents a nested structure for an attribute. It can contain multiple fields, forming a hierarchical structure.

For the "color" attribute in our payload, the value type is "string\_value" with the value "blue". It indicates that the color attribute is a string.

For the "size" attribute, the value type is "number\_value" with the value 2, indicating that the size attribute is a numeric value.

For a comprehensive scalar value types, check [here](https://protobuf.dev/programming-guides/proto3/#scalar?trk=article-ssr-frontend-pulse_little-text-block).

Result:

```
{
    "attributes": {
        "color": {
            "string_value": "blue"
        },
        "size": {
            "number_value": 2
        }
    },
    "uuid": "fc69395e-1072-4bc8-825d-9f56868bdf32",
    "name": "Product Name",
    "description": "Product description",
    "price": 9.989999771118164
}

```

### Get product

Payload:

```
{
    "uuid": "fc69395e-1072-4bc8-825d-9f56868bdf32"
}
```

Result:

```
{
    "attributes": {
        "color": {
            "string_value": "blue"
        },
        "size": {
            "number_value": 2
        }
    },
    "uuid": "fc69395e-1072-4bc8-825d-9f56868bdf32",
    "name": "Product Name",
    "description": "Product description",
    "price": 9.989999771118164
}

```

### Update product

In [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block), the update operations typically expect the full object to be provided rather than supporting partial updates. Unlike traditional [REST APIs](https://en.wikipedia.org/wiki/Representational_state_transfer?trk=article-ssr-frontend-pulse_little-text-block) that often allow modifying specific fields of an object, [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) follows a different approach. When performing an update operation, the entire updated object is sent as a request. This means that all fields of the object must be included in the update request, even if only a subset of them has changed.

The rationale behind this design choice in [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) is to ensure strong contract enforcement and to maintain consistency across client-server interactions. By requiring the full object in update requests, [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) avoids potential conflicts or inconsistencies that may arise when partial updates are allowed. It ensures that the server has a complete and accurate representation of the updated object.

Payload:

```
{
  "uuid": "fc69395e-1072-4bc8-825d-9f56868bdf32",
  "name": "Updated Product Name",
  "description": "Updated Product description",
  "price": 19.99,
  "attributes": {
    "color": {
      "string_value": "blue"
    },
    "style": {
      "string_value": "some style"
    },
    "size": {
      "number_value": 2
    }
  }
}

```

Result:

```
{
    "attributes": {
        "size": {
            "number_value": 2
        },
        "color": {
            "string_value": "blue"
        },
        "style": {
            "string_value": "some style"
        }
    },
    "uuid": "fc69395e-1072-4bc8-825d-9f56868bdf32",
    "name": "Updated Product Name",
    "description": "Updated Product description",
    "price": 19.989999771118164
}

```

### List products

Payload:

```
{}
```

Result:

```
{
    "products": [
        {
            "attributes": {
                "color": {
                    "string_value": "blue"
                },
                "style": {
                    "string_value": "some style"
                },
                "size": {
                    "number_value": 2
                }
            },
            "uuid": "fc69395e-1072-4bc8-825d-9f56868bdf32",
            "name": "Updated Product Name",
            "description": "Updated Product description",
            "price": 19.989999771118164
        }
    ]
}

```

### Delete product

Payload:

```
{
    "uuid": "fc69395e-1072-4bc8-825d-9f56868bdf32"
}

```

Result:

```
{
    "result": "success"
}

```

## Integration tests

Besides unit tests, I think it is important to have integration tests in place for each [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete?trk=article-ssr-frontend-pulse_little-text-block) operation to make sure our [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) API behaves as expected.

server/server\_test.go

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package server

import (
    "context"
    "fmt"
    "log"
    "net"
    "os"
    "testing"

    "github.com/stretchr/testify/require"
    "github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data/api/proto/gen/productcatalog"
    "github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data/config"
    "github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data/store"
    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials/insecure"
    "google.golang.org/grpc/reflection"
    "google.golang.org/protobuf/proto"
    "google.golang.org/protobuf/types/known/structpb"
)

var (
    ctx context.Context
    db  *store.MongoDb
)

const host = "localhost:4444"

func TestMain(m *testing.M) {
    ctx = context.Background()
    const envFilePath = "../.env"
    cfg, err := config.Read(envFilePath)
    if err != nil {
        fmt.Println("error when reading config for integration tests:", err)
        os.Exit(1)
    }
    db, err = store.Connect(ctx, cfg.MongodbTestHostName, cfg.MongodbTestDatabase, cfg.MongodbTestPort)
    if err != nil {
        fmt.Println("error when connecting to MongoDB:", err)
        os.Exit(1)
    }
    lis, err := net.Listen("tcp", host)
    if err != nil {
        fmt.Printf("Failed to listen: %v\n", err)
        os.Exit(1)
    }
    defer lis.Close()
    srv := New(db)
    go func() {
        grpcServer := grpc.NewServer()
        productcatalog.RegisterProductCatalogServiceServer(grpcServer, srv)
        reflection.Register(grpcServer)
        log.Println("Server started")
        if err := grpcServer.Serve(lis); err != nil {
            log.Fatalf("Server error: %v", err)
        }
    }()
    exitVal := m.Run()
    if err := db.Database(cfg.MongodbTestDatabase).Drop(ctx); err != nil {
        fmt.Println("error when dropping test MongoDB:", err)
        os.Exit(1)
    }
    os.Exit(exitVal)
}

func TestProduct(t *testing.T) {
    conn, err := grpc.Dial(host, grpc.WithTransportCredentials(insecure.NewCredentials()))
    if err != nil {
        t.Fatalf("Failed to dial server: %v", err)
    }
    defer conn.Close()
    client := productcatalog.NewProductCatalogServiceClient(conn)

    _newProduct := newProduct()
    _newProduct2 := newProduct()

    // Create two products.
    t.Run("Create", func(t *testing.T) {
        response, err := client.CreateProduct(ctx, _newProduct)
        require.Nil(t, err)
        require.NotNil(t, response)
        require.Equal(t, _newProduct.Name, response.Name)
        require.Equal(t, _newProduct.Price, response.Price)
        require.Equal(t, _newProduct.Description, response.Description)
        for k, v := range response.Attributes {
            require.Equal(t, _newProduct.Attributes[k].AsInterface(), v.AsInterface())
        }

        response2, err2 := client.CreateProduct(ctx, _newProduct2)
        require.Nil(t, err2)
        require.NotNil(t, response2)
        require.Equal(t, _newProduct2.Name, response2.Name)
        require.Equal(t, _newProduct2.Price, response2.Price)
        require.Equal(t, _newProduct2.Description, response2.Description)
        for k, v := range response2.Attributes {
            require.Equal(t, _newProduct2.Attributes[k].AsInterface(), v.AsInterface())
        }

        _newProduct.Uuid = response.Uuid
        _newProduct2.Uuid = response2.Uuid
    })

    // Get the first product.
    t.Run("Get", func(t *testing.T) {
        response, err := client.GetProduct(ctx, &productcatalog.GetProductRequest{Uuid: _newProduct.Uuid})
        require.Nil(t, err)
        require.NotNil(t, response)
        require.True(t, proto.Equal(_newProduct, response))
    })

    // List the products.
    t.Run("List", func(t *testing.T) {
        response, err := client.ListProducts(ctx, &productcatalog.ListProductsRequest{})
        require.Nil(t, err)
        require.NotNil(t, response)
        require.True(t, proto.Equal(products(_newProduct.Uuid, _newProduct2.Uuid), response))
    })

    // Update the second product.
    t.Run("Update", func(t *testing.T) {
        _updatedProduct := updatedProduct(_newProduct2.Uuid)
        response, err := client.UpdateProduct(ctx, _updatedProduct)
        require.Nil(t, err)
        require.NotNil(t, response)
        require.True(t, proto.Equal(_updatedProduct, response))
    })

    // Delete the first product.
    t.Run("Delete", func(t *testing.T) {
        response, err := client.DeleteProduct(ctx, &productcatalog.DeleteProductRequest{Uuid: _newProduct.Uuid})
        require.Nil(t, err)
        require.NotNil(t, response)
        require.True(t, proto.Equal(deletedProductResponse(), response))
    })

    // List the products again. There should be only the updated product.
    t.Run("List", func(t *testing.T) {
        _updatedProduct := updatedProduct(_newProduct2.Uuid)
        response, err := client.ListProducts(ctx, &productcatalog.ListProductsRequest{})
        require.Nil(t, err)
        require.NotNil(t, response)
        require.True(t, proto.Equal(_updatedProduct, response.Products[0]))
    })
}

func newProduct() *productcatalog.Product {
    return &productcatalog.Product{
        Name:        "Test Product Name",
        Description: "Test Product Description",
        Price:       9.99,
        Attributes: map[string]*structpb.Value{
            "color": structpb.NewStringValue("blue"),
            "size":  structpb.NewNumberValue(12),
        },
    }
}

func updatedProduct(id string) *productcatalog.Product {
    return &productcatalog.Product{
        Uuid:        id,
        Name:        "Test Product Name updated",
        Description: "Test Product Description",
        Price:       9.99,
        Attributes: map[string]*structpb.Value{
            "color": structpb.NewStringValue("red"),
            "size":  structpb.NewNumberValue(15),
        },
    }
}

func products(productId1, productId2 string) *productcatalog.ListProductsResponse {
    return &productcatalog.ListProductsResponse{
        Products: []*productcatalog.Product{
            {
                Uuid:        productId1,
                Name:        "Test Product Name",
                Description: "Test Product Description",
                Price:       9.99,
                Attributes: map[string]*structpb.Value{
                    "color": structpb.NewStringValue("blue"),
                    "size":  structpb.NewNumberValue(12),
                },
            },
            {
                Uuid:        productId2,
                Name:        "Test Product Name",
                Description: "Test Product Description",
                Price:       9.99,
                Attributes: map[string]*structpb.Value{
                    "color": structpb.NewStringValue("blue"),
                    "size":  structpb.NewNumberValue(12),
                },
            },
        },
    }
}

func deletedProductResponse() *productcatalog.DeleteProductResponse {
    return &productcatalog.DeleteProductResponse{
        Result: "success",
    }
}

```

## Makefile

Here's the complete Makefile:

```
include .env
export

# ==============================================================================
# Help

.PHONY: help
## help: shows this help message
help:
    @ echo "Usage: make [target]\n"
    @ sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

# ==============================================================================
# Proto

.PHONY: proto
## proto: compiles .proto files
proto:
    @ rm -rf api/proto/gen/productcatalog
    @ mkdir -p api/proto/gen/productcatalog
    @ cd api/proto ; \
    protoc --go_out=gen/productcatalog --go_opt=paths=source_relative --go-grpc_out=gen/productcatalog --go-grpc_opt=paths=source_relative productcatalog.proto

# ==============================================================================
# Docker-compose

.PHONY: start-mongodb
## start-mongodb: starts mongodb instance used for the app
start-mongodb:
    @ docker-compose up mongodb -d
    @ echo "Waiting for MongoDB to start..."
    @ until docker exec $(MONGODB_DATABASE_CONTAINER_NAME) mongosh --eval "db.adminCommand('ping')" >/dev/null 2>&1; do \
        echo "MongoDB not ready, sleeping for 5 seconds..."; \
        sleep 5; \
    done
    @ echo "MongoDB is up and running."

.PHONY: stop-mongodb
## stop-mongodb: stops mongodb instance used for the app
stop-mongodb:
    @ docker-compose stop mongodb

.PHONY: start-test-mongodb
## start-test-mongodb: starts mongodb instance used for integration tests
start-test-mongodb:
    @ docker-compose up mongodb_test -d
    @ echo "Waiting for Test MongoDB to start..."
    @ until docker exec $(MONGODB_TEST_DATABASE_CONTAINER_NAME) mongosh --eval "db.adminCommand('ping')" >/dev/null 2>&1; do \
        echo "Test MongoDB not ready, sleeping for 5 seconds..."; \
        sleep 5; \
    done
    @ echo "Test MongoDB is up and running."

.PHONY: stop-test-mongodb
## stop-test-mongodb: stops mongodb instance used for integration tests
stop-test-mongodb:
    @ docker-compose stop mongodb_test

.PHONY: stop-all-mongodb
## stop-all-mongodb: stops all mongodb instances
stop-all-mongodb:
    @ docker-compose down

# ==============================================================================
# Tests

.PHONY: test
## test: runs both unit and integration tests
test: start-test-mongodb
    @ go test -v ./...

# ==============================================================================
# Execution

.PHONY: run
## run: runs the gRPC server
run: start-mongodb
    @ go run cmd/main.go

```

By doing "include .env" and "export", we are able to use the variables defined in there.

## Conclusion

In this article, we explored the implementation of a [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete?trk=article-ssr-frontend-pulse_little-text-block) API using Go (Golang), gRPC, and [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block). We leveraged the power of [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block), a high-performance, language-agnostic RPC framework, to build efficient and scalable APIs. Additionally, we utilized MongoDB, a flexible NoSQL database, to handle arbitrary data types seamlessly.

By integrating gRPC and [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block), we achieved a robust and performant API. The [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) framework allowed us to define service contracts using Protocol Buffers (Protobuf), providing a clear and standardized way to communicate between clients and servers. With Protobuf, we defined the structure of messages and services, enabling easy-to-maintain API contracts.

A significant advantage of using [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) was its schemaless nature, which proved ideal for handling arbitrary data types. The ability to store varying attributes within the same collection made [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) a suitable choice for our [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete?trk=article-ssr-frontend-pulse_little-text-block) API. We demonstrated this capability by implementing a product domain model with attributes like color (string) and size (number) that could vary across different product types. [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block)'s flexibility enabled us to seamlessly adapt to evolving data models without the need for extensive schema modifications or migrations.

To bridge the gap between the [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) API and [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block), we introduced a mapper package. This package provided functions for converting between Protobuf messages and [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) models, ensuring smooth communication between the API layer and the database layer. The mapper functions facilitated the translation of attributes and maintained compatibility between the gRPC API's Protobuf representation and the [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) data model.

In conclusion, by combining the power of [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block), [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block), and the mapper techniques, we built a robust and flexible [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete?trk=article-ssr-frontend-pulse_little-text-block) API. The [gRPC](https://grpc.io/?trk=article-ssr-frontend-pulse_little-text-block) framework provided efficient and standardized communication, while [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block)'s schemaless nature allowed us to handle arbitrary data types with ease. The mapper functions served as a bridge, enabling seamless conversion between Protobuf messages and [MongoDB](http://mongodb.com/?trk=article-ssr-frontend-pulse_little-text-block) models. With these technologies and techniques, we empowered developers to build scalable and adaptable APIs capable of handling diverse and evolving data structures.

## Download the source

Here: [https://github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data](https://github.com/tiagomelo/golang-grpc-mongodb-arbitrary-data?trk=article-ssr-frontend-pulse_little-text-block)