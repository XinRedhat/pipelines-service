#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
set -x

echo "Copy source code of pipeline service to the ci-runner container"
kubectl exec -n default -it ci-runner -- bash -c "rm -rf /source/*"
kubectl cp "./" "default/ci-runner:/source"

echo "Copy new cluster's kubeconfig to the ci-runner container"
kubectl exec -n default -it ci-runner -- bash -c "rm -rf /kubeconfig"
kubectl cp "$KUBECONFIG" "default/ci-runner:/kubeconfig"
