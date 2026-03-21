# Introduction

This is my personal and public repo to experiment and do demos about Observability, Kubernetes and GitOps.

Feel free to fork it and reuse it.


# Environments / Clusters naming convention

This is one possible naming convention, but should be updated according the organization requirements, services, architecture, preferences, etc.

The naming convention is `<cloud>-<env>-<cluster-type>-<index>`. Possible values for each:

cloud: `aws`, `azu`, `gcp`, `dnl` (3 letters contained in your first name. Used when it is a local cluster)  
env: `loc` (local), `dev`, `stg`, `prd`.  
cluster-type: `obs` (Observability), `man` (Management), etc 
index: `001`, `002`, `003`, etc  


# Tooling Requirements

The manifests created in the repo were tested on Ubuntu 24.04 LTS with the following packages installed:

- Helm v3.20.0
- Docker 29.1.3
- Kubectl v1.34.1
- Kustomize v5.8.1
- Minikube v1.38.1
- Helmfile v1.3.2
- yq v4.52.4

This will probably still work with newer versions or with an alternative of Minikube, such as kind or k3d.


# Quick start deploying to local kubernetes cluster

In this example we use the environment `dnl-loc-obs-001`, but you can use a different one.

> [!WARNING]
> Make sure you use the context for local and not another environment.

```bash
minikube start
```
```bash
./deploy-to-local.sh dnl-loc-obs-001
```

> [!WARNING]
> The deploy.sh script was created to deploy to local clusters while avoiding race conditions between CRDs and the related resources.
> When executing "kubectl apply" directly, some resources may fail because CRDs need to be applied before hand.
> This problem can be avoided in other environments such as development, staging and production when using a GitOps operators like ArgoCD or Flux since they have the capability to create dependencies, allowing to always deploy CRDs before other resources.

To delete all resources in the local cluster execute the below command:

```bash
kubectl delete -k environments/local/dnl-loc-obs-001/
```

## Testing Observability on the Grafana UI

Access Grafana UI

Get `admin` password with the command below: 
```bash
kubectl --namespace default get secrets kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

Port forward from your host to the Gateway API:
```bash
./port-forward-gateway-api.sh -l 8001 -r 80
```

> [!WARNING]
> The port-forward-gateway-api.sh script was created to wait for the Gateway API to be ready before trying to port forward. 
> It can take a couple of minutes depending on the amount of resources available in your laptop.

- On the browser, write http://localhost:8001/grafana.

- The user is “admin” and the password is what you got from your first command.

Query that will test if metrics are being pulled successfully
- Go to `Explore` on the left menu and select the `Prometheus` datasource.
- Select `Code` on the right side.
- Query `rate(node_cpu_seconds_total{mode="idle"}[1m])` which returns the average amount of CPU time spent in idle mode, per second, over the last minute (in seconds)
- `node_cpu_seconds_total` is a Prometheus counter metric, exported by node_exporter, that tracks the cumulative seconds CPUs spend in various modes.

Query that will test if logs are being pulled successfully
- Go to `Explore` on the left menu and select the `loki` datasource.
- Query `{namespace="default"}` which will return the logs of all the pods running in the default namespace. Feel free to check the logs on other namespaces.


# Other documentation

- [Add or update applications in environments](docs/add-update-apps.md)
- [Architecture Overview of the Observability components in the Cluster](docs/architecture-overview.png) (Implementation in progress)
- [Deployment Process Architecture](docs/deployment-process-architecture.png) (Implementation in progress)
- [Load Balancing and routing](alb-nginx.md) (Implementation in progress)
- [Known Issues](known-issues.md)
- [Trade-offs between deploying with pipeline versus deploying with a GitOps Operator](pipelines-vs-gitops-trade-offs.md)
