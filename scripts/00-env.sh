#!/usr/bin/env bash
# Source this first in every shell session before running any other script:
#   source ./00-env.sh
# Shell variables don't persist across sessions — this is the single most common
# source of broken systemd units in this build (see README "Known gotchas").

export CP_IP="${CP_IP:?Set CP_IP to the control-plane private IP before sourcing this file}"
export WORKER_IP="${WORKER_IP:?Set WORKER_IP to the worker private IP before sourcing this file}"
export SERVICE_CLUSTER_IP="${SERVICE_CLUSTER_IP:-10.32.0.1}"

echo "CP_IP=${CP_IP}"
echo "WORKER_IP=${WORKER_IP}"
echo "SERVICE_CLUSTER_IP=${SERVICE_CLUSTER_IP}"
