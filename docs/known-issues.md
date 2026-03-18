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

The temporary solution for this is to disable CRDs creation on the helm chart and manually create the CRDS into the folder `applications/cloudnative-pg/crds` with the command:

```
VERSION=1.28.1

curl -L https://github.com/cloudnative-pg/cloudnative-pg/releases/download/v${VERSION}/cnpg-${VERSION}.yaml | yq 'select(.kind == "CustomResourceDefinition")' > applications/cloudnative-pg/crds/cnpg-${VERSION}.yaml
```

Then make sure the file `cnpg-${VERSION}.yaml` is included in the `applications/cloudnative-pg/kustomization.yaml` and make sure that only on `cnpg-*.yaml` is added to avoid duplications or conflicts.