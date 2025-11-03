---
layout: post
title:  "Scaling Kubernetes configuration with Jsonnet: no more copy-paste YAML"
date:   2025-11-03 07:21:00 -0000
categories: jsonnet kubernetes devops configuration
image: "/assets/images/2025-11-03-scaling-configuration-jsonnet/banner.png"
---

![banner](/assets/images/2025-11-03-scaling-configuration-jsonnet/banner.png)

Every [Kubernetes](https://kubernetes.io/) project begins with a `deployment.yaml` and a `kubectl apply`. It’s fast, simple, and satisfying.

But what happens when you go beyond a single environment? Now you’ve got `dev`, `staging`, and `prod`. And maybe a `qa` or `sandbox` env too.

Suddenly your repo looks like this:

```bash
k8s/
├── dev/
│   └── deployment.yaml
├── staging/
│   └── deployment.yaml
└── prod/
    └── deployment.yaml
```

Those files start off identical — but not for long. A changed replica count here, a version mismatch there... and before you know it, your configurations are out of sync.

**Config drift has begun.**

So how do we scale config without copy-paste chaos?

Enter [**Jsonnet**](https://jsonnet.org/).

---

## The problem with scaling YAML

YAML itself doesn’t support:

* variables
* functions
* imports
* mixins
* conditional logic

Which means Kubernetes users are left maintaining multiple slightly-different files that share 90% of the same structure.

- That’s config duplication.
- That’s error-prone.
- That’s what we’re fixing.

---

## Jsonnet to the rescue

[Jsonnet](https://jsonnet.org/) is a data templating language:

* JSON superscript — but with `import`, `function`, `if`/`else`, and more
* Purely declarative and side-effect-free
* Perfect for generating config files

And you can generate **dozens** of Kubernetes manifests from a single template.

---

## What we’re building

We’ll build a structure where:

1. **Base config** defines all shared Kubernetes configuration
2. **Mixins** add reusable extensions (like resources, probes, labels)
3. **Environment files** override only what's different
4. **Everything** can be validated offline using `kubeconform`

Environments covered:

* `dev`
* `staging`
* `prod`

---

## Folder structure

```bash
jsonnet-config-scaling/
├── k8s/
│   ├── base.libsonnet           # Base shared Deployment template
│   ├── mixins/
│   │   └── resources.libsonnet  # Add CPU/memory config
│   └── environments/
│       ├── dev.jsonnet
│       ├── staging.jsonnet
│       ├── prod.jsonnet
│       └── all.jsonnet          # Demo: generate all envs via loop
├── output/                      # Generated manifests
├── Makefile
└── README.md
```

---

## Base deployment template

`k8s/base.libsonnet`

```jsonnet
{
  // deployment generates a Kubernetes Deployment manifest
  // Parameters:
  //   name: Name of the deployment
  //   image: Container image to use
  //   replicas: Number of replicas
  //   envVars: (optional) Environment variables for the container
  deployment(name, image, replicas, envVars={}):: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: name,
      labels: {
        app: name,
      },
    },
    spec: {
      replicas: replicas,
      selector: {
        matchLabels: {
          app: name,
        },
      },
      template: {
        metadata: {
          labels: {
            app: name,
          },
        },
        spec: {
          containers: [{
            name: name,
            image: image,
            env: std.map(
              function(k) { name: k, value: envVars[k] },
              std.objectFields(envVars),
            ),
          }],
        },
      },
    },
  },
}
```

This single function can generate a fully valid Kubernetes Deployment, making it reusable across environments.

---

## Adding resource mixins

We don't want to define CPU/memory in every environment — so let’s patch that using a mixin.

`k8s/mixins/resources.libsonnet`

```jsonnet
{
  // Mixin to add resource requests and limits to the first container of a Kubernetes Pod spec
  // Parameters:
  //   cpu: CPU resource (e.g., "500m", "1")
  //   memory: Memory resource (e.g., "256Mi", "1Gi")
  withResources(cpu, memory):: {
    spec+: {
      template+: {
        spec+: {
          containers: [
            super.containers[0] {  // Merge into first container
              resources: {
                limits: { cpu: cpu, memory: memory },
                requests: { cpu: cpu, memory: memory },
              },
            },
          ] + super.containers[1:],  // Keep any remaining containers
        },
      },
    },
  },
}
```

That `+` deep merge operator lets us add resource configuration **without modifying** anything else in the original container definition.

---

## Per-environment files

Example: `k8s/environments/dev.jsonnet`

```jsonnet
local base = import '../base.libsonnet';
local mixins = import '../mixins/resources.libsonnet';

base.deployment(
  name='myapp-dev',
  image='myorg/myapp:1.1.0',
  replicas=1,
  envVars={ ENV: 'dev' },
) + mixins.withResources('100m', '256Mi')
```

`staging` and `prod` follow this pattern:

| Env     | Replicas | CPU  | Memory |
| ------- | -------- | ---- | ------ |
| dev     | 1        | 100m | 256Mi  |
| staging | 1        | 200m | 512Mi  |
| prod    | 3        | 500m | 1Gi    |

---

## Generate all environments at once

Here’s where Jsonnet loops show their power:

`k8s/environments/all.jsonnet`

```jsonnet
local base = import '../base.libsonnet';
local mixins = import '../mixins/resources.libsonnet';

// resources for different environments.
local resourceMap = {
  dev: { cpu: '100m', memory: '256Mi' },
  staging: { cpu: '200m', memory: '512Mi' },
  prod: { cpu: '500m', memory: '1Gi' },
};

[
  // Generate deployments for all environments.
  base.deployment(
    name='myapp-' + env,
    image='myorg/myapp:1.2.0',
    replicas=if env == 'prod' then 3 else 1,
    envVars={ ENV: env },
  ) + mixins.withResources(resourceMap[env].cpu, resourceMap[env].memory)
  for env in std.objectFields(resourceMap)
]
```

---

## YAML vs JSON: why convert?

Jsonnet always outputs **JSON**, which is valid Kubernetes input — but most tools, linters, and CI platforms work best with **YAML**.

- `kubectl apply -f file.yaml`
- `kubeconform`
- `helm`
- Git diffs look better

So we convert our Jsonnet output to YAML as a final step before applying or validating.

---

## Generating single YAML for all environments

Many workflows want all resources in a **single `all.yaml`** instead of individual files. That’s totally supported — just add a Makefile target:

```makefile
## build-all-to-single-file: generates all environments into a single .yaml
.PHONY: build-all-to-single-file
build-all-to-single-file: fmt
	@mkdir -p $(OUTPUT_DIR)
	@$(JSONNET) k8s/environments/all.jsonnet | \
	yq eval -P '.[]' - | \
	awk 'BEGIN{first=1} /^apiVersion:/ {if (!first) print "---"; first=0} {print}' \
	> $(OUTPUT_DIR)/all.yaml
	@echo "Generated: $(OUTPUT_DIR)/all.yaml"
```

### What’s going on?

| Tool                  | Purpose                                                                      |
| --------------------- | ---------------------------------------------------------------------------- |
| `jsonnet all.jsonnet` | Generates a JSON array of Kubernetes objects                                 |
| `yq eval -P '.[]'`    | Converts each element to YAML and prints them individually                   |
| `awk`                 | Adds `---` between top-level resources to create a valid multi-doc YAML file |

This gives you a result like:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-dev
...

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-staging
...

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-prod
...
```

- Ready for `kubectl apply -f all.yaml`

- Easy to diff in GitHub

- Consumed by `kustomize`, ArgoCD, Flux, and CI tools

---

## Validating manifests with kubeconform

You don’t need a Kubernetes cluster to ensure your generated manifests are valid — just use [kubeconform](https://github.com/yannh/kubeconform):

```bash
$ make build
Generated: output/dev.yaml
Generated: output/staging.yaml
Generated: output/prod.yaml

$ make build-all-to-single-file 
Generated: output/all.yaml

$ make validate
Summary: 3 resources found in 1 file - Valid: 3, Invalid: 0, Errors: 0, Skipped: 0
Validated output/all.yaml
Summary: 1 resource found in 1 file - Valid: 1, Invalid: 0, Errors: 0, Skipped: 0
Validated output/dev.yaml
Summary: 1 resource found in 1 file - Valid: 1, Invalid: 0, Errors: 0, Skipped: 0
Validated output/prod.yaml
Summary: 1 resource found in 1 file - Valid: 1, Invalid: 0, Errors: 0, Skipped: 0
Validated output/staging.yaml
```

---

## Dependencies

To follow along and generate the manifests, install these tools:

### 1. Jsonnet

Used to compile `.jsonnet` files into JSON.

```bash
# macOS
brew install jsonnet

# Linux (via package manager)
sudo apt install jsonnet

# Or use the GitHub release
https://github.com/google/jsonnet/releases
```

### 2. `kubeconform`

Schema validation tool for Kubernetes manifests.
Does **not** require a cluster.

```bash
# macOS
brew install kubeconform

# Linux
curl -L https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz \
  | tar xz && mv kubeconform /usr/local/bin/
```

---

## Final Makefile

```makefile
JSONNET ?= jsonnet
FMT ?= jsonnetfmt
OUTPUT_DIR = output

.PHONY: help
## help: shows this help message
help:
	@echo "Usage: make [target]\n"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

## fmt: formats all Jsonnet files
.PHONY: fmt
fmt:
	@find k8s -name '*.jsonnet' -o -name '*.libsonnet' | xargs $(FMT) -i

## build: generates all environments into output dir
.PHONY: build
build: fmt
	@mkdir -p $(OUTPUT_DIR)
	@for env in dev staging prod; do \
		$(JSONNET) k8s/environments/$$env.jsonnet | yq -P > $(OUTPUT_DIR)/$$env.yaml; \
		echo "Generated: $(OUTPUT_DIR)/$$env.yaml"; \
	done

## build-all-to-single-file: generates all environments into a single .yaml
.PHONY: build-all-to-single-file
build-all-to-single-file: fmt
	@mkdir -p $(OUTPUT_DIR)
	@$(JSONNET) k8s/environments/all.jsonnet | \
	yq eval -P '.[]' - | \
	awk 'BEGIN{first=1} /^apiVersion:/ {if (!first) print "---"; first=0} {print}' \
	> $(OUTPUT_DIR)/all.yaml
	@echo "Generated: $(OUTPUT_DIR)/all.yaml"

## validate: validates generated k8s manifests (requires kubeconform)
.PHONY: validate
validate:
	@for file in $(OUTPUT_DIR)/*.yaml; do \
		kubeconform -strict -summary $$file || exit 1; \
		echo "Validated $$file"; \
	done

## clean: cleans output directory
.PHONY: clean
clean:
	@rm -rf $(OUTPUT_DIR)
```

---

## Full example repo

Here: [https://github.com/tiagomelo/jsonnet-config-scaling](https://github.com/tiagomelo/jsonnet-config-scaling)

---

## Final thoughts

With this approach we've:

- Eliminated YAML duplication
- Added structured environment overrides
- Scaled Kubernetes config with clean composition
- Kept full compatibility with `kubectl`, Helm, ArgoCD, and CI
- Added static validation with `kubeconform`

If you're managing more than one environment, Jsonnet is a huge quality-of-life upgrade over raw YAML.

Let me know if you'd like a follow-up article using: ConfigMaps, Secrets, Kustomize, or Helm interop!

---

## 📚 References

1. [Jsonnet Language](https://jsonnet.org/learning/tutorial.html)
2. [Kubeconform Validator](https://github.com/yannh/kubeconform)
4. [kubectl apply Best Practices](https://kubernetes.io/docs/reference/kubectl/)

