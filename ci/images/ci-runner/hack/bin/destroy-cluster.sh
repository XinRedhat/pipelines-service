#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
set -x

SCRIPT_DIR="$(
  cd "$(dirname "$0")" >/dev/null
  pwd
)"

# Give developers 15mins to connect to a pod and remove the file
# if they want to investigate the failure
if [ -e "$PWD/destroy-cluster.txt" ]; then
    sleep 900
    if [ -e "$PWD/destroy-cluster.txt" ]; then
      echo "Failure is not being investigated, cluster will be destroyed."
    else
      echo "KUBECONFIG:"
      cat "$KUBECONFIG"
      echo
      echo "Connect to the ci-runner: kubectl exec -n default --stdin --tty ci-runner -- bash"
      echo
      echo "Failure under investigation, cluster will not be destroyed."
      exit 1
    fi
fi

# shellcheck source=ci/images/ci-runner/hack/bin/bitwarden.sh
source "$SCRIPT_DIR/bitwarden.sh"

destroy_cluster() {
    cluster_name="$1"
    echo "Started to destroy cluster [$cluster_name]..."
    open_bitwarden_session
    get_aws_credentials

    # Set maximum number of retry attempts
    max_retries=5
    retries=0

    # Loop for retrying cluster destruction
    while true; do
        if hypershift destroy cluster aws --aws-creds "$AWS_CREDENTIALS" --name "$cluster_name"; then
            echo "Successfully destroyed cluster [$cluster_name]"
            break  # Exit the loop if cluster destruction succeeds
        else
            retries=$((retries+1))
            if [[ $retries -gt $max_retries ]]; then
                printf "Error: Hypershift cluster failed to be destroyed after %d retries.\n" "$max_retries"
                exit 1
            else
                printf "Retrying...\n"
                sleep 2
            fi
        fi
    done
}

if [[ -n "$CLUSTER_NAME" ]]; then
    destroy_cluster "$CLUSTER_NAME"
else
    echo "No OCP cluster needs to be destroyed."
fi
