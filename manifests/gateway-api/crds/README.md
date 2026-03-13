# Importante notes about CRDs

CRDs need to be in their own folder, otherwise clean deployments may fail because some resources need the CRDs. This is a race condition problem.

These CRDs were initially copied from https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml.