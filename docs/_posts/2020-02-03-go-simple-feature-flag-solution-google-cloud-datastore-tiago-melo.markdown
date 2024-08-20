---
layout: post
title:  "Go: a simple feature flag solution with Google Cloud Datastore"
date:   2020-02-03 13:26:01 -0300
categories: go gcp featureflag
---
![Go: a simple feature flag solution with Google Cloud Datastore](/assets/images/2020-02-03-48f01379-820e-4bf5-8619-81b2f7811477/2020-02-03-banner.png)

In this article, we'll see what [feature flag](https://en.wikipedia.org/wiki/Feature_toggle) is, why it's useful and a simple implementation of it using [Golang](https://golang.org/) and [Google Cloud Datastore](https://cloud.google.com/datastore/).

## What is a feature flag?

From [Wikipedia](https://en.wikipedia.org/wiki/Feature_toggle):

> A **feature toggle** (also **feature switch**, **feature flag**, **feature flipper**, **conditional feature**, etc.) is a technique in [software development](https://en.wikipedia.org/wiki/Software_development) that attempts to provide an alternative to maintaining multiple [source-code](https://en.wikipedia.org/wiki/Source_code) branches (known as feature branches), such that a feature can be tested even before it is completed and ready for release. Feature toggle is used to hide, enable or disable the feature during run time. For example, during the development process, a developer can enable the feature for testing and disable it for other users.

## Motivation

I was working in a huge [RESTful API](https://en.wikipedia.org/wiki/Representational_state_transfer), written in [Golang](https://golang.org/) and running on [Google Cloud Platform](https://cloud.google.com/), and I needed to use the [feature flag](https://en.wikipedia.org/wiki/Feature_toggle) technique to be able to test a new integration with an internal system without breaking the existing behavior - and thus not worrying about undesired side effects when deploying it to the production environment.

Although there are [many existing solutions out there](http://featureflags.io/go-feature-flags/), I needed something simpler. I just needed boolean flags. Then I thought of using the [Google Datastore console](https://console.cloud.google.com/datastore) as a visual 'dashboard' to easily create/delete/enable/disable features for a given system, in the form of [entities](https://cloud.google.com/datastore/docs/concepts/entities).

Every entity [kind](https://cloud.google.com/datastore/docs/concepts/entities#kinds_and_identifiers) will represent the collection of [feature flags](https://en.wikipedia.org/wiki/Feature_toggle) for a given system, and each entity of that [kind](https://cloud.google.com/datastore/docs/concepts/entities#kinds_and_identifiers) is a [feature flag](https://en.wikipedia.org/wiki/Feature_toggle).

## The solution

I've created [a small toolkit](https://github.com/tiagomelo/datastore-feature-flags) that could be used not only for the aforementioned [API](https://en.wikipedia.org/wiki/Representational_state_transfer) but for the other [Golang](https://golang.org/) systems that we have.

### Prerequisites

- [A Google Cloud Platform project](https://cloud.google.com/resource-manager/docs/creating-managing-projects) and a [service account](https://cloud.google.com/iam/docs/creating-managing-service-accounts) for it
- [A service account key (as JSON)](https://cloud.google.com/iam/docs/creating-managing-service-account-keys) for the service account and [GOOGLE\_APPLICATION\_CREDENTIALS](https://cloud.google.com/docs/authentication/getting-started?hl=en#setting_the_environment_variable) environment variable with its path
- [A Google Cloud Datastore instance](https://cloud.google.com/datastore/docs/quickstart) in [Datastore Mode](https://cloud.google.com/datastore/docs/quickstart?hl=en#firestore-or-datastore)

### The code

_datastore.go_

```
// A minimal interface to expose datastore related functions.
// Author: Tiago Melo (tiagoharris@gmail.com)

package datastore

import (
	"context"
)

type Datastore interface {
	GetFeatureFlagByName(ctx context.Context, name string (*FeatureFlag, error)
}

```

_store.go_

```
// Author: Tiago Melo (tiagoharris@gmail.com)

package datastore

import (
	"context"

	"cloud.google.com/go/datastore"
	"github.com/pkg/errors"
)

type Store struct {
	Client *datastore.Client

	// Kind represents the entity type to be queried
	Kind string
}

// NewStore initializes a new datastore client
func NewStore(ctx context.Context, kind string) (Datastore, error) {
	dsClient, err := datastore.NewClient(ctx, datastore.DetectProjectID)
	if err != nil {
		return nil, errors.Wrap(err, "unable to init datastore client")
	}

	return &Store{
		Client: dsClient,
		Kind:   kind,
	}, nil
}

```

Interesting note: instead of hardcoding the GCP project name, 'datastore.DetectProjectID' detects it by reading the project name that it's defined on the aforementioned [JSON credential file](https://cloud.google.com/iam/docs/creating-managing-service-account-keys).

_feature\_flag.go_

```
// Author: Tiago Melo (tiagoharris@gmail.com)

package datastore

import (
	"context"

	"cloud.google.com/go/datastore"
)

// FeatureFlag is used to store information about a feature flag for a given system
type FeatureFlag struct {
	Name     string `datastore:"name" json:"name"`
	IsActive bool   `datastore:"is_active" json:"is_active"`
}

// FeatureFlagKey creates a new datastore key for a given entity type and feature flag name
func FeatureFlagKey(ctx context.Context, kind, name string) *datastore.Key {
	return datastore.NameKey(kind, name, nil)
}

// GetFeatureFlagByName queries datastore for a given entity type and feature flag name
func GetFeatureFlagByName(ctx context.Context, s *Store, name string) (*FeatureFlag, error) {
	var f FeatureFlag
	err := s.Client.Get(ctx, FeatureFlagKey(ctx, s.Kind, name), &f)

	return &f, err
}

// GetFeatureFlagByName returns the feature flag of a given system
func (s *Store) GetFeatureFlagByName(ctx context.Context, name string) (*FeatureFlag, error) {
	flag, err := GetFeatureFlagByName(ctx, s, name)
	return flag, err
}

```

## Running it

Suppose the entity [kind](https://cloud.google.com/datastore/docs/concepts/entities#kinds_and_identifiers) 'my-api-feature-flags'. We have a feature named 'Test flag' which is active:

![No alt text provided for this image](/assets/images/2020-02-03-48f01379-820e-4bf5-8619-81b2f7811477/1580523434759.png)

So we could read it like this:

```
package main

package main

import (
	"context"
	"log"

	"github.com/tiagomelo/datastore-feature-flags"
)

func main() {
	ctx := context.Background()

	store, err := datastore.NewStore(ctx, "follow-cms-feature-flags")
	if err != nil {
		log.Fatal(err, "unable to init database")
	}

	featureFlag, err := store.GetFeatureFlagByName(ctx, "Test flag")
	if err != nil {
		log.Fatal(err, "unable to read feature flag")
	}

	if featureFlag.IsActive {
		log.Println(featureFlag.Name)
	}
}

```

Output:

```
2020/02/02 18:25:37 Test flag

```

Of course, you don't want to hit [Datastore](https://cloud.google.com/datastore) every time. In a production app, we might add a [cache](https://en.wikipedia.org/wiki/Cache_(computing)) layer, reading from it first, then reading from [Datastore](https://cloud.google.com/datastore) in case of a [cache miss](https://en.wikipedia.org/wiki/CPU_cache#CACHE-MISS) and then storing it into the [cache](https://en.wikipedia.org/wiki/Cache_(computing)). But that's a subject for a future article.

### Unit testing

The cool thing about [Google Cloud Platform](https://cloud.google.com/) is that it provides some emulators to ease the unit testing. I'll show how to use the [Datastore emulator](https://cloud.google.com/datastore/docs/tools/datastore-emulator).

The prerequisites are:

- a [Java](http://java.com) 8+ JRE must be installed and on your system PATH
- [Google Cloud SDK Datastore Emulator](https://cloud.google.com/datastore/docs/tools/datastore-emulator)

_Makefile_: the 'datastore-start' target will launch the [emulator](https://cloud.google.com/datastore/docs/tools/datastore-emulator) at 127.0.0.1:8084.

```
# Starts the datastore emulator for running locally. Called by `make test`.
datastore-start:
	@gcloud beta emulators datastore start --no-store-on-disk --host-port=127.0.0.1:8084 --consistency 1.0 --quiet > /dev/null 2>&1 &
	@echo "Cloud Datastore Emulator started..."

# Looks for a running datastore emulator and stops it.
datastore-stop:
	@kill -9 `ps ax | grep 'CloudDatastore.jar' | grep -v grep | awk '{print $1}'` > /dev/null 2>&1 &
	@echo "Cloud Datastore Emulator stopped"

test: datastore-start
	@export DATASTORE_EMULATOR_HOST=127.0.0.1:8084; \
	go test -v ./...
	@$(MAKE) -s datastore-stop

```

_test\_util.go_: it creates a [datastore](https://pkg.go.dev/cloud.google.com/go/datastore?tab=doc) instance that connects to the [emulator](https://cloud.google.com/datastore/docs/tools/datastore-emulator).

```
// Author: Tiago Melo (tiagoharris@gmail.com)

package datastore

import (
	"context"
	"fmt"

	"cloud.google.com/go/datastore"
)

func newTestDB(ctx context.Context, kind string) Datastore {
	dsClient, err := datastore.NewClient(ctx, datastore.DetectProjectID)
	if err != nil {
		panic(fmt.Sprintf("could not create new datastore client: %s", err))
	}

	return &Store{
		Client: dsClient,
		Kind:   kind,
	}
}

```

_feature\_flag\_test.go_: it connects to the [emulator](https://cloud.google.com/datastore/docs/tools/datastore-emulator) and first tries to retrieve an entity [kind](https://cloud.google.com/datastore/docs/concepts/entities#kinds_and_identifiers) that does not exist. Then, we create it. And, finally, we retrieve it and check its name.

```
// Author: Tiago Melo (tiagoharris@gmail.com)

package datastore

import (
	"context"
	"testing"

	"cloud.google.com/go/datastore"
)

func TestGetFeatureFlagByName(t *testing.T) {
	ctx := context.Background()
	testKind := "test-feature-flags"

	store := newTestDB(ctx, testKind).(*Store)

	featureFlagName := "Test Flag"
	featureFlag, err := store.GetFeatureFlagByName(ctx, featureFlagName)
	if err == nil {
		t.Error("expected 'datastore.ErrNoSuchEntity' error")
	}

	f := FeatureFlag{
		Name:     featureFlagName,
		IsActive: true,
	}
	_, err = store.Client.Put(ctx, datastore.NameKey(testKind, featureFlagName, nil), &f)
	if err != nil {
		t.Errorf("Creating feature flag entry %s", err)
	}
	featureFlag, err = store.GetFeatureFlagByName(ctx, featureFlagName)
	if err != nil {
		t.Errorf("GetFeatureFlagByName %s", err)
	}
	if !featureFlag.IsActive {
		t.Errorf("Expected feature flag to be active, got %v", featureFlag.IsActive)
	}
}

```

Running it:

```
tiago@tiago:~/develop/go/datastore-feature-flags$ make test
Cloud Datastore Emulator started...
=== RUN   TestGetFeatureFlagByName
--- PASS: TestGetFeatureFlagByName (0.43s)
PASS
ok  	github.com/tiagomelo/datastore-feature-flags	1.144s
Cloud Datastore Emulator stopped

```

## Conclusion

In this article, we've covered a simple [feature flag](https://en.wikipedia.org/wiki/Feature_toggle) solution using [Golang](https://golang.org/) and [Google Cloud Datastore](https://cloud.google.com/datastore).

## Repository link

Here: [https://github.com/tiagomelo/datastore-feature-flags](https://github.com/tiagomelo/datastore-feature-flags)