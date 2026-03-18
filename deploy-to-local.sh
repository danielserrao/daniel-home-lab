#!/usr/bin/env bash
set -e

LOCAL_ENV_DIR="environments/local"
LOCAL_ENV="${1:-}"

# This script is only intended to deploy to local clusters
if [[ "$LOCAL_ENV" != *-loc-*-* ]]; then
  echo "Error: LOCAL_ENV must match the pattern *-loc-*-*." >&2
  exit 1
fi

if [ -z "$LOCAL_ENV_DIR/$LOCAL_ENV" ] || [ ! -d "$LOCAL_ENV_DIR/$LOCAL_ENV" ]; then
  echo "Error: LOCAL_ENV must be a valid directory path." >&2
  exit 1
fi

if [ ! -f "$LOCAL_ENV_DIR/$LOCAL_ENV/kustomization.yaml" ]; then
  echo "Error: $LOCAL_ENV_DIR/$LOCAL_ENV/kustomization.yaml doesn't exist." >&2
  exit 1
fi

echo "Installing CRDs"
kustomize build "$LOCAL_ENV_DIR/$LOCAL_ENV" \
  | yq 'select(.kind == "CustomResourceDefinition")' \
  | kubectl apply --server-side -f -

kubectl wait --for=condition=Established crd --all --timeout=60s

echo "Installing remaining resources"
kubectl apply --server-side -k "$LOCAL_ENV_DIR/$LOCAL_ENV"
