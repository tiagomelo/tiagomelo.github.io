---
layout: post
title:  "Open source project: go-project-config"
date:   2024-05-02 00:21:58 -0000
categories: opensource golang
image: "/assets/images/2024-05-02-goprojconfig-opensource/banner.png"
---

![banner](/assets/images/2024-05-02-goprojconfig-opensource/banner.png)

Based on a [previous post](https://tiagomelo.info/quicktip/go/envconfig/2024/04/08/golang-envconfig-pdf-post.html), I've decided to put together [go-project-config](https://github.com/tiagomelo/go-project-config), a simple utility tool to provide a clean and neat way for managing configuration data from environment variables for your Go project.

_check out my other open source projects [here](https://tiagomelo.info/opensource/)_

## installation

```
go install github.com/tiagomelo/go-project-config/cmd/goprojconfig
```

It will be installed into `bin` directory of your `$GOPATH` env.

```
go env | grep GOPATH
```

## usage

### generating config

At your project's root:

```
goprojconfig -p <packageName>
```

Let's use `appcfg` as an example.

```
goprojconfig -p appcfg
```

Then, three files will be generated at project's root:

1. `.env`

```
SAMPLE_ENV_VAR=some value
```

2. `appcfg/config.go`

```
package appcfg

import (
	"github.com/joho/godotenv"
	"github.com/kelseyhightower/envconfig"
	"github.com/pkg/errors"
)

// Config holds all configuration needed by this app.
type Config struct {
	SampleEnvVar string `envconfig:"SAMPLE_ENV_VAR" required:"true"`
}

// For ease of unit testing.
var (
	godotenvLoad     = godotenv.Load
	envconfigProcess = envconfig.Process
)

// Read reads configuration from environment variables.
// It assumes that an '.env' file is present at current path.
func Read() (*Config, error) {
	if err := godotenvLoad(); err != nil {
		return nil, errors.Wrap(err, "loading env vars from .env file")
	}
	config := new(Config)
	if err := envconfigProcess("", config); err != nil {
		return nil, errors.Wrap(err, "processing env vars")
	}
	return config, nil
}

// ReadFromEnvFile reads configuration from the specified environment file.
func ReadFromEnvFile(envFilePath string) (*Config, error) {
	if err := godotenvLoad(envFilePath); err != nil {
		return nil, errors.Wrapf(err, "loading env vars from %s", envFilePath)
	}
	config := new(Config)
	if err := envconfigProcess("", config); err != nil {
		return nil, errors.Wrap(err, "processing env vars")
	}
	return config, nil
}

```

3. `appcfg/config_test.go`

```
package appcfg

import (
	"errors"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestRead(t *testing.T) {
	testCases := []struct {
		name                   string
		mockedGodotenvLoad     func(filenames ...string) (err error)
		mockedEnvconfigProcess func(prefix string, spec interface{}) error
		expectedError          error
	}{
		{
			name: "happy path",
			mockedGodotenvLoad: func(filenames ...string) (err error) {
				return nil
			},
			mockedEnvconfigProcess: func(prefix string, spec interface{}) error {
				return nil
			},
		},
		{
			name: "error loading env vars",
			mockedGodotenvLoad: func(filenames ...string) (err error) {
				return errors.New("random error")
			},
			expectedError: errors.New("loading env vars from .env file: random error"),
		},
		{
			name: "error processing env vars",
			mockedGodotenvLoad: func(filenames ...string) (err error) {
				return nil
			},
			mockedEnvconfigProcess: func(prefix string, spec interface{}) error {
				return errors.New("random error")
			},
			expectedError: errors.New("processing env vars: random error"),
		},
	}
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			godotenvLoad = tc.mockedGodotenvLoad
			envconfigProcess = tc.mockedEnvconfigProcess
			config, err := Read()
			if err != nil {
				if tc.expectedError == nil {
					t.Fatalf("expected no error, got %v", err)
				}
				require.Nil(t, config)
				require.Equal(t, tc.expectedError.Error(), err.Error())
			} else {
				if tc.expectedError != nil {
					t.Fatalf("expected error, got nil")
				}
				require.NotNil(t, config)
			}
		})
	}
}

func TestReadFromEnvFile(t *testing.T) {
	testCases := []struct {
		name                   string
		mockedGodotenvLoad     func(filenames ...string) (err error)
		mockedEnvconfigProcess func(prefix string, spec interface{}) error
		expectedError          error
	}{
		{
			name: "happy path",
			mockedGodotenvLoad: func(filenames ...string) (err error) {
				return nil
			},
			mockedEnvconfigProcess: func(prefix string, spec interface{}) error {
				return nil
			},
		},
		{
			name: "error loading env vars",
			mockedGodotenvLoad: func(filenames ...string) (err error) {
				return errors.New("random error")
			},
			expectedError: errors.New("loading env vars from path/to/.env: random error"),
		},
		{
			name: "error processing env vars",
			mockedGodotenvLoad: func(filenames ...string) (err error) {
				return nil
			},
			mockedEnvconfigProcess: func(prefix string, spec interface{}) error {
				return errors.New("random error")
			},
			expectedError: errors.New("processing env vars: random error"),
		},
	}
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			godotenvLoad = tc.mockedGodotenvLoad
			envconfigProcess = tc.mockedEnvconfigProcess
			config, err := ReadFromEnvFile("path/to/.env")
			if err != nil {
				if tc.expectedError == nil {
					t.Fatalf("expected no error, got %v", err)
				}
				require.Nil(t, config)
				require.Equal(t, tc.expectedError.Error(), err.Error())
			} else {
				if tc.expectedError != nil {
					t.Fatalf("expected error, got nil")
				}
				require.NotNil(t, config)
			}
		})
	}
}

```

### generating config from an existing env file

Suppose an env file called `.env-local`:

```
KAFKA_BROKER_HOST=localhost:9092
KAFKA_TOPIC=sometopic
KAFKA_GROUP_ID=some-group-id

MONGODB_DATABASE=somedb
MONGODB_HOST_NAME=localhost
MONGODB_PORT=27017
```

At your project's root:

```
goprojconfig -p <package_name> -e </path/to/envfile>
```

Let's use `appcfg` as package name again, for example:

```
goprojconfig -p appcfg -e .env-local
```

Then, two files will be generated at project's root:

1. `appcfg/config.go`

```
package appcfg

import (
	"github.com/joho/godotenv"
	"github.com/kelseyhightower/envconfig"
	"github.com/pkg/errors"
)

// Config holds all configuration needed by this app.
type Config struct {
	SampleEnvVar string `envconfig:"SAMPLE_ENV_VAR" required:"true"`
}

// For ease of unit testing.
var (
	godotenvLoad     = godotenv.Load
	envconfigProcess = envconfig.Process
)

// Read reads configuration from environment variables.
// It assumes that an '.env' file is present at current path.
func Read() (*Config, error) {
	if err := godotenvLoad(); err != nil {
		return nil, errors.Wrap(err, "loading env vars from .env file")
	}
	config := new(Config)
	if err := envconfigProcess("", config); err != nil {
		return nil, errors.Wrap(err, "processing env vars")
	}
	return config, nil
}

// ReadFromEnvFile reads configuration from the specified environment file.
func ReadFromEnvFile(envFilePath string) (*Config, error) {
	if err := godotenvLoad(envFilePath); err != nil {
		return nil, errors.Wrapf(err, "loading env vars from %s", envFilePath)
	}
	config := new(Config)
	if err := envconfigProcess("", config); err != nil {
		return nil, errors.Wrap(err, "processing env vars")
	}
	return config, nil
}
```

3. `appcfg/config_test.go`

```
package appcfg

import (
	"errors"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestRead(t *testing.T) {
	testCases := []struct {
		name                   string
		mockedGodotenvLoad     func(filenames ...string) (err error)
		mockedEnvconfigProcess func(prefix string, spec interface{}) error
		expectedError          error
	}{
		{
			name: "happy path",
			mockedGodotenvLoad: func(filenames ...string) (err error) {
				return nil
			},
			mockedEnvconfigProcess: func(prefix string, spec interface{}) error {
				return nil
			},
		},
		{
			name: "error loading env vars",
			mockedGodotenvLoad: func(filenames ...string) (err error) {
				return errors.New("random error")
			},
			expectedError: errors.New("loading env vars from .env file: random error"),
		},
		{
			name: "error processing env vars",
			mockedGodotenvLoad: func(filenames ...string) (err error) {
				return nil
			},
			mockedEnvconfigProcess: func(prefix string, spec interface{}) error {
				return errors.New("random error")
			},
			expectedError: errors.New("processing env vars: random error"),
		},
	}
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			godotenvLoad = tc.mockedGodotenvLoad
			envconfigProcess = tc.mockedEnvconfigProcess
			config, err := Read()
			if err != nil {
				if tc.expectedError == nil {
					t.Fatalf("expected no error, got %v", err)
				}
				require.Nil(t, config)
				require.Equal(t, tc.expectedError.Error(), err.Error())
			} else {
				if tc.expectedError != nil {
					t.Fatalf("expected error, got nil")
				}
				require.NotNil(t, config)
			}
		})
	}
}

func TestReadFromEnvFile(t *testing.T) {
	testCases := []struct {
		name                   string
		mockedGodotenvLoad     func(filenames ...string) (err error)
		mockedEnvconfigProcess func(prefix string, spec interface{}) error
		expectedError          error
	}{
		{
			name: "happy path",
			mockedGodotenvLoad: func(filenames ...string) (err error) {
				return nil
			},
			mockedEnvconfigProcess: func(prefix string, spec interface{}) error {
				return nil
			},
		},
		{
			name: "error loading env vars",
			mockedGodotenvLoad: func(filenames ...string) (err error) {
				return errors.New("random error")
			},
			expectedError: errors.New("loading env vars from path/to/.env: random error"),
		},
		{
			name: "error processing env vars",
			mockedGodotenvLoad: func(filenames ...string) (err error) {
				return nil
			},
			mockedEnvconfigProcess: func(prefix string, spec interface{}) error {
				return errors.New("random error")
			},
			expectedError: errors.New("processing env vars: random error"),
		},
	}
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			godotenvLoad = tc.mockedGodotenvLoad
			envconfigProcess = tc.mockedEnvconfigProcess
			config, err := ReadFromEnvFile("path/to/.env")
			if err != nil {
				if tc.expectedError == nil {
					t.Fatalf("expected no error, got %v", err)
				}
				require.Nil(t, config)
				require.Equal(t, tc.expectedError.Error(), err.Error())
			} else {
				if tc.expectedError != nil {
					t.Fatalf("expected error, got nil")
				}
				require.NotNil(t, config)
			}
		})
	}
}

```

## using it in your application

1. reading configuration from `.env` file

```
package main

import (
	"fmt"
	"os"

	"github.com/tiagomelo/go-project-config/appcfg"
)

func main() {
	cfg, err := appcfg.Read()
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	fmt.Printf("cfg: %+v\n", cfg)
}
```

2. reading configuration from a given env file

```
package main

import (
	"fmt"
	"os"

	"github.com/tiagomelo/go-project-config/appcfg"
)

func main() {
	cfg, err := appcfg.ReadFromEnvFile(".env-sample")
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	fmt.Printf("cfg: %+v\n", cfg)
}
```