#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
set -x

SCRIPT_DIR="$(
  cd "$(dirname "$0")" >/dev/null
  pwd
)"

is_cluster_expired() {
    MAX_DURATION_MINS=120

    local cluster_name="$1"
    
    # If hostedcluster doesn't exist, skip
    if ! kubectl get hostedcluster -n clusters "$cluster_name" > /dev/null 2>&1; then
        return 1
    fi
    
    local deletionTimestamp
    deletionTimestamp=$(kubectl get hostedcluster -n clusters "$cluster_name" -o json \
        | jq -r '.metadata.deletionTimestamp?')
    
    # If the cluster has "deletionTimestamp" metadata, it means the cluster is triggered for deletion
    if [ -n "$deletionTimestamp" ]; then
        return 1
    fi
    
    local creationTime
    creationTime=$(kubectl -n clusters get hostedcluster "$cluster_name" -o json | jq -r '.metadata.creationTimestamp')
    local duration_mins=$(( ( $(date +%s) - $(date +%s -d "$creationTime") ) / 60 ))
    
    # If the cluster is older than $MAX_DURATION_MINS mins, it is considered expired
    if [ "$duration_mins" -gt "$MAX_DURATION_MINS" ]; then
        return 0
    fi
    
    return 1
}

EXCLUDE_CLUSTER=(local-cluster)

mapfile -t clusters < <(kubectl get hostedcluster -n clusters -o=custom-columns=NAME:.metadata.name --no-headers)
for cluster in "${clusters[@]}"; do
    if [[ "${EXCLUDE_CLUSTER[*]}" =~ $cluster ]]; then
        continue
    fi
    # if the cluster is expired, destroy it
    if is_cluster_expired "$cluster"; then
        "$SCRIPT_DIR"/destroy-clusters.sh "$cluster"
    fi
done