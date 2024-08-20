---
layout: post
title:  "Golang templating: replacing values in a YAML file with values coming from another YAML file"
date:   2023-05-22 13:26:01 -0300
categories: go templating yaml
---
![Golang templating: replacing values in a YAML file with values coming from another YAML file](/assets/images/2023-05-22-bd7e472b-f2b0-4b60-85b6-23b51ba8ff7e/2023-05-22-banner.jpeg)

[Go](http://go.dev?trk=article-ssr-frontend-pulse_little-text-block) templating is a powerful feature provided by the language that allows you to generate text output by replacing placeholders (variables) in a template with their corresponding values. It's a convenient way to generate dynamic content, including [YAML](https://en.wikipedia.org/wiki/YAML?trk=article-ssr-frontend-pulse_little-text-block) files.

[Helm](https://helm.sh/?trk=article-ssr-frontend-pulse_little-text-block), a package manager for [Kubernetes](https://kubernetes.io/?trk=article-ssr-frontend-pulse_little-text-block), utilizes [Go templating](https://pkg.go.dev/text/template?trk=article-ssr-frontend-pulse_little-text-block) to generate [Kubernetes manifest files](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/?trk=article-ssr-frontend-pulse_little-text-block) from templates.

I needed the same in a project of mine.

In this tutorial we'll see how we can use [Go templating](https://pkg.go.dev/text/template?trk=article-ssr-frontend-pulse_little-text-block) to replace values in a [YAML](https://en.wikipedia.org/wiki/YAML?trk=article-ssr-frontend-pulse_little-text-block) file with values from another [YAML](https://en.wikipedia.org/wiki/YAML?trk=article-ssr-frontend-pulse_little-text-block) file, similar to what [Helm](https://helm.sh/?trk=article-ssr-frontend-pulse_little-text-block) does.

The reference Github repo can be found [here](https://github.com/tiagomelo/golang-yaml-template-tutorial?trk=article-ssr-frontend-pulse_little-text-block).

## Template file and values

Suppose we want to replace our template with some values, like [Helm](https://helm.sh/?trk=article-ssr-frontend-pulse_little-text-block) does.

template/template.yaml

{% raw %}
```
apiVersion: v1
kind: Deployment
metadata:
  name: {{ .AppName }}
spec:
  replicas: {{ .ReplicaCount }}
  template:
    spec:
      containers:
      - name: {{ .AppName }}
        image: {{ .Image }}

```
{% endraw %}

template/values.yaml

```
AppName: my-app
ReplicaCount: 3
Image: myregistry/my-app:v1.0.0

```

## Template parsing

parser/parser.go

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package parser

import (
    "html/template"
    "io"
    "os"

    "github.com/pkg/errors"
    "gopkg.in/yaml.v2"
)

// For ease of unit testing.
var (
    parseFile           = template.ParseFiles
    openFile            = os.Open
    createFile          = os.Create
    ioReadAll           = io.ReadAll
    yamlUnmarshal       = yaml.Unmarshal
    executeTemplateFile = func(templateFile *template.Template, wr io.Writer, data any) error {
        return templateFile.Execute(wr, data)
    }
)

// valuesFromYamlFile extracts values from yaml file.
func valuesFromYamlFile(dataFile string) (map[string]interface{}, error) {
    data, err := openFile(dataFile)
    if err != nil {
        return nil, errors.Wrap(err, "opening data file")
    }
    defer data.Close()
    s, err := ioReadAll(data)
    if err != nil {
        return nil, errors.Wrap(err, "reading data file")
    }
    var values map[string]interface{}
    err = yamlUnmarshal(s, &values)
    if err != nil {
        return nil, errors.Wrap(err, "unmarshalling yaml file")
    }
    return values, nil
}

// Parse replaces values present in the template file
// with values defined in the data file, saving the result
// as an output file.
func Parse(templateFile, dataFile, outputFile string) error {
    tmpl, err := parseFile(templateFile)
    if err != nil {
        return errors.Wrap(err, "parsing template file")
    }
    values, err := valuesFromYamlFile(dataFile)
    if err != nil {
        return err
    }
    output, err := createFile(outputFile)
    if err != nil {
        return errors.Wrap(err, "creating output file")
    }
    defer output.Close()
    err = executeTemplateFile(tmpl, output, values)
    if err != nil {
        return errors.Wrap(err, "executing template file")
    }
    return nil
}

```

1. First we call '[template.ParseFiles](https://pkg.go.dev/text/template#Template.ParseFiles?trk=article-ssr-frontend-pulse_little-text-block)' to create a new template and parse the template definitions from the named files.
2. Then, we need to read the [YAML](https://en.wikipedia.org/wiki/YAML?trk=article-ssr-frontend-pulse_little-text-block) file and parse it - our 'valuesFromYamlFile' returns a 'map\[string\]interface{}' containing keys and values found. We're using [gopkg.in/yaml.v2](http://gopkg.in/yaml.v2?trk=article-ssr-frontend-pulse_little-text-block) for that.
3. Next, we create the output file in which the output will be written - that is, the template file 'template/template.yaml' with all placeholders replaced by the values we defined in 'template/values.yaml'. If you do not want to save it to a new file, you can do just 'templateFile.Execute(os.Stdout, values)' and then the output will be printed to console.
4. Finally, we execute the template to replace all place holders in the template file and write the output to a new file.

### Using it

cmd/main.go

```
// Copyright (c) 2023 Tiago Melo. All rights reserved.
// Use of this source code is governed by the MIT License that can be found in
// the LICENSE file.
package main

import (
    "fmt"
    "os"

    "tiago.com/parser"
)

func run() error {
    const templateFile = "template/template.yaml"
    const dataFile = "template/values.yaml"
    const outputFile = "parsed/parsed.yaml"
    if err := parser.Parse(templateFile, dataFile, outputFile); err != nil {
        return err
    }
    fmt.Printf("file %s was generated.\n", outputFile)
    return nil
}

func main() {
    if err := run(); err != nil {
        fmt.Println(err)
        os.Exit(1)
    }
}

```

## Running it

```
$ make run

file parsed/parsed.yaml was generated.
```

### Output

parsed/parsed.yaml

```
apiVersion: v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: my-app
        image: myregistry/my-app:v1.0.0

```

Sweet.