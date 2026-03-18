# Add or update applications in environments

In this context, we call an `application` all the the k8s resources needed to make an application (e.g.: Grafana, Prometheus, etc) to run and work fine. These could include K8s resources such as Deployments, Persistent Volumes, Secrets, etc.  

All the applications

## Add and deploy a new application

When wanting to create a new reusable application, I'm using [Kustomize](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/) and also frequently [Helm](https://helm.sh/docs).

These are the options:

#### Reuse helm charts

If you have a new application that you want to deploy and a official (or good) helm chart for it already exist, you can add it at `helmfile/helmfile.yaml`.

Then execute the command `./update-manifests.sh` and you can confirm that a new folder with the application manifests was created. Let's follow the Loki application as example with the folder `applications/loki`.

You can add files under `applications/loki` and update `applications/loki/kustomization.yaml` if you intend to override the default configuration of this application or add extra k8s resources, but you should not change anything inside `applications/loki/loki` because it will be overrided by `./update-manifests.sh`. Such changes will update the application on every environment using it.

If there isn't a proper helm chart and the application will be deployed by other teams/customers, I would suggest create a helm chart for it and follow the same above instructions, otherwise I suggest to simply create the manifests as explained below. The reason for this is because helm is usually better for packaging and sharing with other teams/customers that might don't know much about kubernetes and kustomize is usually better when used internally by a team with advanced knowledge in kubernetes. 

#### Use Kustomize

If an official Kustomization (Base manifests + patches/overlays) is available for the application, then this might be a good option:

- Add the Kustomization folder under `manifests` with the name of the application
- Validate the final result with the command `kustomize build applications/<application-name>`
- Create a README.md under the folder `applications/<application-name>` explaining the source and version of the kustomization and how to update it when new versions are available.

#### Create manifests from scratch

If a proper helm chart or kustomization to deploy the application don't exist and the manifests will be used internally only, you can:

- create a new folder under `applications` with the name of the application
- create the K8s manifests to deploy this application under `applications/<application-name>`
- create the file `applications/<application-name>/kustomization.yaml` and add all the manifests as [resources](https://kubectl.docs.kubernetes.io/guides/example/inline_patch/#base).
- validate the final result with the command `kustomize build applications/<application-name>`


## Deploy or update kubernetes resources in environments (In Progress)

Make sure the applications that you want to be deployed to be added as resources on `environments/<cluster-name>/kustomization.yaml`. If needed, you can also override k8s manifests using kustomize.

If you want to deploy to a local cluster, you can follow the above section `Quick start deploying to local kubernetes cluster`.

If you want to deploy to a different environment such as development, staging or production, you will need to make a merge request to the `main` branch which should be reviewed, approved and merged. Then a GitOps Operator such as Flux or ArgoCD will check the desired state of the applications and deploy them into the cluster.

As an example, ArgoCD can have an ApplicationSet for each environment (development, staging and production) and iterate all folders inside each environment folder (`environments/<environment>`). Then deploy to the cluster with the same name as those folders, following the related configuration.