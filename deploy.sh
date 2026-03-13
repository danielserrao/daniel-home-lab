#!/usr/bin/env bash
set -e

ROOT_DIR="${1:-}"

if [ -z "$ROOT_DIR" ] || [ ! -d "$ROOT_DIR" ]; then
  echo "Error: ROOT_DIR must be a valid directory path." >&2
  exit 1
fi

if [ ! -f "$ROOT_DIR/kustomization.yaml" ]; then
  echo "Error: $ROOT_DIR/kustomization.yaml doesn't exist." >&2
  exit 1
fi

echo "Installing CRDs"
kustomize build "$ROOT_DIR" \
  | yq 'select(.kind == "CustomResourceDefinition")' \
  | kubectl apply --server-side -f -

kubectl wait --for=condition=Established crd --all --timeout=60s

echo "Installing remaining resources"
kubectl apply --server-side -k "$ROOT_DIR"
