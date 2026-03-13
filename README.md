# Introduction

This is just my personal and public home lab for the purpose of doing tests and demos focused on Kubernetes, GitOps and Observability.

Feel free to fork it and reuse it.

# Environments / Clusters naming convention

This is one possible naming convention, but should be updated according the organization requirements, services, architecture, preferences, etc.

The naming convention is `<cloud>-<env>-<cluster-type>-<index>`. Possible values for each:

cloud: `aws`, `azu`, `gcp`, `dnl` (3 letters contained in your first name. Used when it is a local cluster)  
env: `loc` (local), `dev`, `stg`, `prd`.  
cluster-type: `obs` (observability), `stm` (Space Traffic Management), `dts` (Data & Tracking Services)  
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
./deploy.sh environments/local/dnl-loc-obs-001/
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


# Add or update Kubernetes resources (e.g.: Workloads, Configuration, Storage, etc) in environments

## Add and deploy a new set of K8s resources  

When wanting to deploy new set of K8s resources (e.g.: Grafana, Loki, etc), we use [Kustomize](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/) and also frequently [Helm](https://helm.sh/docs).

We have the following options:

#### Reuse helm charts

If you have a new application that you want to deploy and a official (or good) helm chart for it already exist, you can add it at `helmfile/helmfile.yaml`.

Then execute the command `./update-manifests.sh` and you can confirm that a new folder with the application manifests was created. Let's follow the Loki application as example with the folder `manifests/loki`.

You can add files under `manifests/loki` and update `manifests/loki/kustomization.yaml` if you intend to override the default configuration of this application or add extra k8s resources, but you should not change anything inside `manifests/loki/loki` because it will be overrided by `./update-manifests.sh`. Such changes will update the application on every environment using it.

If there isn't a proper helm chart and the application will be deployed by other teams/customers, I would suggest create a helm chart for it and follow the same above instructions, otherwise I suggest to simply create the manifests as explained below. The reason for this is because helm is usually better for packaging and sharing with other teams/customers that might don't know much about kubernetes and kustomize is usually better when used internally by a team with advanced knowledge in kubernetes. 

#### Use Kustomize

If an official Kustomization (Base manifests + patches/overlays) is available for the application, then this might be a good option:

- Add the Kustomization folder under `manifests` with the name of the application
- Validate the final result with the command `kustomize build manifests/<kustomization>`
- Create a README.md under the folder `manifests/<kustomization>` explaining the source and version of the kustomization and how to update it when new versions are available.

#### Create manifests from scratch

If a proper helm chart or kustomization to deploy the application don't exist and the manifests will be used internally only, you can:

- create a new folder under `manifests` with the name of the application
- create the K8s manifests to deploy this application under `manifests/<application>`
- create the file `manifests/<application>/kustomization.yaml` and add all the manifests as [resources](https://kubectl.docs.kubernetes.io/guides/example/inline_patch/#base).
- validate the final result with the command `kustomize build manifests/<application>`


## Deploy or update kubernetes resources in environments

Make sure the applications that you want to be deployed to be added as resources on `environments/<cluster-name>/kustomization.yaml`. If needed, you can also override k8s manifests using kustomize.

If you want to deploy to a local cluster, you can follow the above section `Quick start deploying to local kubernetes cluster`.

If you want to deploy to a different environment such as development, staging or production, you will need to make a merge request to the `main` branch which should be reviewed, approved and merged. Then a GitOps Operator such as Flux or ArgoCD will check the desired state of the applications and deploy them into the cluster.

As an example, ArgoCD can have an ApplicationSet for each environment (development, staging and production) and iterate all folders inside each environment folder (`environments/<environment>`). Then deploy to the cluster with the same name as those folders, following the related configuration.

# Known issues

## loki-helm-test Error

The pod loki-helm-test gets into Error state sometimes. It appears that this happens because the container may run the test before the service loki-canary is ready. 

To fix this, a readiness probe can be implemented to make loki-helm-test wait for loki-canary to be ready.

We can also implement alerting to let us know when pods such as loki-helm-test are not Ready for more than 2 minutes (or more depending on workloads), indicating that something might be wrong.

This error doesn't break loki functionality, but it would be nice to fix it.

## Idempotency broken on Grafana

Some fields such as `checksum/secret` and `admin-password` get a different value on every build.

These can probably be fixed after making an improvement to get secrets from an Secret Manager (e.g.: AWS Secret Manager, Vault, etc) using the External Secrets Operator.

## Postgresql CRD annotation too long

When installing the CloudNativePG Helm chart (Helm), Helm stores the full rendered manifest inside annotations, creating the error `The CustomResourceDefinition "poolers.postgresql.cnpg.io" is invalid: metadata.annotations: Too long: may not be more than 262144 bytes`.

The temporary solution for this is to disable CRDs creation on the helm chart and manually create the CRDS into the folder `manifests/cloudnative-pg/crds` with the command:

```
VERSION=1.28.1

curl -L https://github.com/cloudnative-pg/cloudnative-pg/releases/download/v${VERSION}/cnpg-${VERSION}.yaml | yq 'select(.kind == "CustomResourceDefinition")' > manifests/cloudnative-pg/crds/cnpg-${VERSION}.yaml
```

Then make sure the file `cnpg-${VERSION}.yaml` is included in the `manifests/cloudnative-pg/kustomization.yaml` and make sure that only on `cnpg-*.yaml` is added to avoid duplications or conflicts.

# Architecture Overview of the Applications running in the Cluster

Check the image at files/architecture-overview.png.

In this case the architecture in this image is more completed than the solution in this repo since I will need more time to complete it.

# Deployment Process Architecture

Check image at files/deployment-process-architecture.png.


# Trade-offs between deploying with pipeline versus deploying with a GitOps Operator

| Dimension | Deploying with Pipeline | Deploying with GitOps Operator |
| --- | --- | --- |
| Deployment trigger     | Push-based (CI/CD runs `kubectl`/`helm` on success).                         | Pull-based (operator reconciles cluster state from Git). |
| Source of truth        | Can be artifacts or Git repo                                                 | Git repo is the single source of truth for desired state. |
| Drift management       | Requires extra steps to detect/repair drift.                                 | Continuous reconciliation fixes drift automatically. |
| Audit trail            | Deployment details might be fragmented between Git history and pipeline logs | Git history shows who changed desired state and when. |
| Rollbacks              | Scripted/conditional; depends on pipeline tooling.                           | `git revert` restores desired state; operator reconciles. |
| Blast radius control   | Depends on pipeline targeting and credentials.                               | Can scope operators per cluster/namespace and use RBAC. |
| Secrets handling       | Often injected at deploy time by CI.                                         | Typically managed via sealed/external secrets integrated with GitOps. |
| Change visibility      | Requires pipeline logs or release dashboards.                                | Git PRs show diffs; operator can surface sync status. |
| Operational complexity | Simpler if you already run CI/CD only.                                       | Additional operator to run and secure in the cluster. |
| Speed to deploy        | Fast for one-off changes and manual runs.                                    | Great for steady, continuous changes once set up. |
| Failure handling       | Pipeline failures stop; retries are manual or scripted.                      | Operator keeps retrying until state converges. |
| Multi-cluster scale    | Requires orchestration in CI/CD.                                             | Operator can scale to many clusters with standard patterns. |

#### When Each Approach Works Best

Pipeline deployments better when:

- Small teams
- Few clusters
- Simpler infra
- Early stage platform

GitOps is best when:

- Many clusters
- Strong compliance/audit requirements
- Need drift correction
- Want immutable infrastructure workflows


# TODO

- Add tracing application such as Tempo or Jaeger.

- Build and deploy custom Golang Application sending traces to Tempo/Jaeger.

- Build and deploy custom Golang Application with simple CRUD API using Postgresql. Should be accessible via the Gateway API. 

- Create Terraform code to deploy EKS cluster with Flux installed and configured to pull the state from a development cluster.

- Add missing metrics needed to fill all the Grafana Dashboards.

- Add git commit pre-hook to make sure ./update-manifests.sh is always executed to maintain the manifests always in sync with the helmfile.

- Add GitHub Actions job that fails if manifests generated by ./update-manifests.sh don't match the manifests pushed. 

- Update Gateway API to access Grafana using port 443 (HTTPS).

- Document how to deploy new versions of helm charts to specific environments.

- Remove random and hardcoded secrets and get them from Secret Manager provider (e.g.: AWS Secret Manager, Vault) using the External Secrets Operator.

- Add Thanos to push metrics to long-term storage provider.

- Switch from Loki Single Binary deployment mode to Simple Scalable if dealing up to 1TB/day or Distributed mode if dealing with more than 1TB/day.

- Enable horizontal pod auto scaling on all applications that support it for higher availability an resiliency.

- Vulnerability scanning for container images.

- Create GitHub Action jobs to test manifests using tools like kube-score and kubeconform. These will help making all manifests compliant to best practices, including increasing security. 

- Create integration tests to be executed in Staging.

- Create job to create a diff file in the Pull Request that will show the difference between the source branch manifests with the target branch (usually main) manifests. This will make it much easier to identify which changes are planned and in which clusters.
