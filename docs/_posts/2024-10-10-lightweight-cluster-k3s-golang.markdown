---
layout: post
title:  "Setting up a lightweight Kubernetes cluster with k3s: a gRPC service example"
date:   2024-10-10 13:52:44 -0000
categories: go golang grpc k8s k3s
---

![banner](/assets/images/2024-10-10-lightweight-cluster-k3s-golang/banner.png)

[Kubernetes](https://kubernetes.io/) is known for its ability to orchestrate complex, large-scale containerized applications. However, for smaller-scale projects or local development, the full [Kubernetes](https://kubernetes.io/) stack can be overkill. 

Meet [k3s](https://k3s.io/https://k3s.io/) — a lightweight, production-grade [Kubernetes](https://kubernetes.io/) distribution designed for resource-constrained environments. 

In this article, I’ll walk you through setting up a [k3s](https://k3s.io/https://k3s.io/) cluster and deploying a simple [gRPC](https://grpc.io/) service using the [go-grpc-bin](https://github.com/tiagomelo/go-grpc-bin) project as an example.

# What is k3s?

[k3s](https://k3s.io/https://k3s.io/) is a fully compliant Kubernetes distribution but is much lighter than its full [Kubernetes](https://kubernetes.io/) counterpart. 

It packages required dependencies such as [Flannel](https://github.com/flannel-io/flannel), [Traefik](https://traefik.io/traefik/), and [ServiceLB](https://github.com/k3s-io/klipper-lb) into a single binary, making it ideal for edge computing, IoT, and small VPS environments. The key advantage is that it requires fewer resources while still providing the robust orchestration features of [Kubernetes](https://kubernetes.io/).

## Step 1: Installing k3s

To get started with [k3s](https://k3s.io/https://k3s.io/), you can install it on any Linux-based machine. For this example, I’m using a VPS, but the steps are similar for local setups or bare-metal installations.

### Installation Command

Run the following command on your machine or VPS to install [k3s](https://k3s.io/https://k3s.io/):

```
curl -sfL https://get.k3s.io | sh -
```

This command installs [k3s](https://k3s.io/https://k3s.io/) and starts the [Kubernetes](https://kubernetes.io/) control plane. By default, it uses [containerd](https://containerd.io/) as the container runtime and [Flannel](https://github.com/flannel-io/flannel) for networking.

Once [k3s](https://k3s.io/https://k3s.io/) is installed, you can verify the status of your cluster:

```
$ sudo kubectl get nodes
NAME        STATUS   ROLES                  AGE   VERSION
srv613524   Ready    control-plane,master   9s    v1.30.5+k3s1
```

This will list the nodes in your [k3s](https://k3s.io/https://k3s.io/) cluster. At this point, your lightweight [Kubernetes](https://kubernetes.io/) environment is ready.

## Step 2: Deploying a gRPC Service

Next, we will deploy the [go-grpc-bin](https://github.com/tiagomelo/go-grpc-bin) [gRPC](https://grpc.io/) service to the [k3s](https://k3s.io/https://k3s.io/) cluster. We'll use two [Kubernetes](https://kubernetes.io/) manifests: one for the `Deployment` and one for the `Service`.

### go-grpc-bin deployment

The `Deployment` manifest defines how the [go-grpc-bin](https://github.com/tiagomelo/go-grpc-bin) service will run. It specifies the container image, the number of replicas (1 in this case), and the container port.

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-grpc-bin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: go-grpc-bin
  template:
    metadata:
      labels:
        app: go-grpc-bin
    spec:
      containers:
      - name: go-grpc-bin
        image: tiagoharris/go-grpc-bin:latest
        args: ["-p", "50051"]
        ports:
        - containerPort: 50051
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-grpc-bin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: go-grpc-bin
  template:
    metadata:
      labels:
        app: go-grpc-bin
    spec:
      containers:
      - name: go-grpc-bin
        image: tiagoharris/go-grpc-bin:latest
        args: ["-p", "50051"]
        ports:
        - containerPort: 50051

```

Apply the Deployment:

```
$ sudo kubectl apply -f deployment.yaml 
deployment.apps/go-grpc-bin created
```

This will create a single instance (replica) of the [go-grpc-bin](https://github.com/tiagomelo/go-grpc-bin) service, running on port 50051.

Check if the deployment was successful:

```
$ sudo kubectl get deployments
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
go-grpc-bin   1/1     1            1           39s
```

### go-grpc-bin Service

Next, create a `Service` to expose the [gRPC](https://grpc.io/) application. We'll use a `LoadBalancer` service to assign an external IP so the service can be accessed outside the cluster.

```
apiVersion: v1
kind: Service
metadata:
  name: go-grpc-bin
spec:
  type: LoadBalancer
  selector:
    app: go-grpc-bin
  ports:
    - protocol: TCP
      port: 50051
      targetPort: 50051

```

Apply the Service manifest:

```
$ sudo kubectl apply -f service.yaml 
service/go-grpc-bin created
```

The `type: LoadBalancer` ensures that k3s’s built-in [ServiceLB](https://github.com/k3s-io/klipper-lb) load-balancer controller assigns an external IP for your [gRPC](https://grpc.io/) service. You can verify this by running:

![svc](/assets/images/2024-10-10-lightweight-cluster-k3s-golang/svc.png)

You should see an external IP assigned to the [go-grpc-bin](https://github.com/tiagomelo/go-grpc-bin) service.

## Step 3: Testing the gRPC Service

Once the deployment and service are running, you can test the [gRPC](https://grpc.io/) service using [grpcurl](https://github.com/fullstorydev/grpcurl), a command-line tool that allows you to interact with [gRPC](https://grpc.io/) servers, similar to how `curl` interacts with HTTP services.

To test the service, run the following command:

```
grpcurl -plaintext -d '{"message": "Hello, gRPC!"}' <EXTERNAL-IP>:50051 grpcbin.GRPCBin/Echo
```

Replace `<EXTERNAL-IP>` with the external IP assigned to the [go-grpc-bin](https://github.com/tiagomelo/go-grpc-bin) service.

Output you should see:

![echo](/assets/images/2024-10-10-lightweight-cluster-k3s-golang/echo.png)

## Step 4: Scaling your service (optional)

If you need more instances of the [go-grpc-bin](https://github.com/tiagomelo/go-grpc-bin) service, you can easily scale the deployment by modifying the replicas field in the deployment manifest or using the `kubectl scale` command:

```
$ sudo kubectl scale deployment go-grpc-bin --replicas=3
deployment.apps/go-grpc-bin scaled
```

Then we can see that we have 3 pods now:

```
$ sudo kubectl get pods
NAME                           READY   STATUS    RESTARTS   AGE
go-grpc-bin-7595547bf5-ckznw   1/1     Running   0          20m
go-grpc-bin-7595547bf5-s979z   1/1     Running   0          13s
go-grpc-bin-7595547bf5-zt22m   1/1     Running   0          13s
```

# Conclusion

In this article, we set up a lightweight [Kubernetes](https://kubernetes.io/) cluster using [k3s](https://k3s.io/https://k3s.io/) and deployed a [gRPC](https://grpc.io/)[gRPC](https://grpc.io/) service using the [go-grpc-bin](https://github.com/tiagomelo/go-grpc-bin) project. [k3s](https://k3s.io/https://k3s.io/) offers a simple, resource-efficient way to run [Kubernetes](https://kubernetes.io/) in environments where the full [Kubernetes](https://kubernetes.io/) stack would be too heavy. With built-in components like [ServiceLB](https://github.com/k3s-io/klipper-lb), [k3s](https://k3s.io/https://k3s.io/) provides an easy way to manage services and expose them to external clients.

If you’re looking for a lightweight [Kubernetes](https://kubernetes.io/)[Kubernetes](https://kubernetes.io/) solution for edge, IoT, or small-scale applications, [k3s](https://k3s.io/https://k3s.io/) is an excellent choice. By following the steps outlined above, you can have a fully functioning [Kubernetes](https://kubernetes.io/) environment up and running with minimal effort.