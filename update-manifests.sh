#!/usr/bin/env bash

# update-manifests.sh
# Creates the manifests based on the helm charts defined on helmfile/helmfile.yaml
# Walks the immediate subdirectories of the "manifests" folder, finds all
# YAML files beneath each one (recursively) and writes a kustomization.yaml
# in the top of each subdirectory listing those files as resources.
#
# Usage: ./update-manifests.sh
# Run it from the repository root (where "manifests" lives).

set -euo pipefail

manifests_dir="manifests"

# # ensure we start with a clean output tree so repeated runs don't accumulate
# # old rendered resources.  helmfile's --output-dir-template simply writes files
# # and does not delete what was there previously.  We only want to remove the
# # second‑level directories (e.g. manifests/alloy/alloy), leaving the top‑level
# # folder itself and any other files behind.
for dir in "$manifests_dir"/*/; do
    rm -rf "${dir}/$(basename "$dir")"
done

helmfile template -f helmfile/helmfile.yaml --include-crds --output-dir-template "../${manifests_dir}/{{ .Release.Name }}"

if [[ ! -d "$manifests_dir" ]]; then
    echo "error: '$manifests_dir' directory not found" >&2
    exit 1
fi

# For each inner release directory we just generated (manifests/<release>/<release>)
# the glob picks up the second-level folder so kustomization files live next to
# the rendered YAMLs and resource paths are relative.
for dir in "$manifests_dir"/*/; do

    chart_templates_dir="${dir}$(basename "$dir")" # Only this directory should have the kustomization.yaml automatically created

    # skip non-directories (globbing behavior)
    [[ -d "$chart_templates_dir" ]] || continue
    echo "processing $chart_templates_dir"

    # Find all yaml/yml files recursively under this child, but skip any
    # existing kustomization.yaml so we don't create a self-reference.
    # sort so output is deterministic.
    mapfile -t files < <(
        find "$chart_templates_dir" -type f \( -name '*.yaml' -o -name '*.yml' \) \
            ! -name 'kustomization.yaml' | sort
    )

    # Convert absolute paths to relative paths against the child directory
    resources=()
    for f in "${files[@]}"; do
        # strip the parent directory including the trailing slash so the
        # resulting path has no leading "/".  previously we removed only the
        # directory name which left "/templates/..." in the output.
        rel=${f#"$chart_templates_dir"/}
        resources+=("$rel")
    done

    # Write kustomization.yaml in the child directory
    outfile="${chart_templates_dir}/kustomization.yaml"
    {
        echo "apiVersion: kustomize.config.k8s.io/v1beta1"
        echo "kind: Kustomization"
        echo "resources:"
        for r in "${resources[@]}"; do
            echo "  - $r"
        done
    } > "$outfile"

done

# Making sure that every application has a root kustomization.yaml if missing
# This file can be manually updated since it will only be created once
for dir in "$manifests_dir"/*/; do
    outfile="${dir}/kustomization.yaml"
    if [ ! -f "$outfile" ]; then
        # Write kustomization.yaml in the child directory    
        {
            echo "apiVersion: kustomize.config.k8s.io/v1beta1"
            echo "kind: Kustomization"
            echo "resources:"
            echo "  - $(basename "$dir")"
        } > "$outfile"
    fi
done
