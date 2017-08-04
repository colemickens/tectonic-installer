#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

set -e
set -u
set -o pipefail
set -x

cd "${DIR}"

if [[ -z "${CLUSTER}" ]]; then echo "CLUSTER must be set"; fi
echo "CLUSTER: ${CLUSTER}"

if [[ -z "${PLATFORM}" ]]; then echo "PLATFORM must be set"; fi
echo "PLATFORM: ${PLATFORM}"

if [[ "${PLATFORM}" == "azure" ]]; then
  if [[ -f "$HOME/azure.env" ]]; then source "$HOME/azure.env"; fi
  
  # load ~/azure.env is available  
  if [[ -z "${ARM_SUBSCRIPTION_ID}" ]]; then echo "ARM_SUBSCRIPTION_ID must be set"; fi
  export ARM_SUBSCRIPTION_ID
  echo "ARM_SUBSCRIPTION_ID: ${ARM_SUBSCRIPTION_ID}"
  
  if [[ -z "${ARM_TENANT_ID}" ]]; then echo "ARM_TENANT_ID must be set"; fi
  export ARM_TENANT_ID
  echo "ARM_TENANT_ID: ${ARM_TENANT_ID}"
  
  if [[ -z "${ARM_CLIENT_ID}" ]]; then echo "ARM_CLIENT_ID must be set"; fi
  export ARM_CLIENT_ID
  echo "ARM_CLIENT_ID: ${ARM_CLIENT_ID}"

  if [[ -z "${ARM_CLIENT_SECRET}" ]]; then echo "ARM_CLIENT_SECRET must be set"; fi
  export ARM_CLIENT_SECRET
  echo "ARM_CLIENT_SECRET: <omitted>"
fi

if [[ ! -d "${DIR}/build/${CLUSTER}" ]]; then
  make localconfig

  AZURE_LOCATION="${AZURE_LOCATION:-westus}"
  SSH_KEY="${SSH_KEY:-"$HOME/.ssh/id_rsa.pub"}"
  ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

  if [[ "${ADMIN_PASSWORD_HASH:-}" == "" ]]; then
    # hash is for "CoreOSrocksMySocks123@"
    ADMIN_PASSWORD_HASH='$2a$10$RJWInIpb/mw7E0nj4V1HMeID1ju4LoZ7p1MF7/j/y3Rd1w1lbM5uy'
  fi

  sed -i "s|tectonic_admin_email = \"\"|tectonic_admin_email = \"${ADMIN_EMAIL}\"|g" "build/${CLUSTER}/terraform.tfvars"
  sed -i "s|tectonic_admin_password_hash = \"\"|tectonic_admin_password_hash = \"${ADMIN_PASSWORD_HASH}\"|g" "build/${CLUSTER}/terraform.tfvars"
  sed -i "s|tectonic_azure_client_secret = \"\"|tectonic_azure_client_secret = \"${ARM_CLIENT_SECRET}\"|g" "build/${CLUSTER}/terraform.tfvars"
  sed -i "s|tectonic_azure_location = \"\"|tectonic_azure_location = \"${AZURE_LOCATION}\"|g" "build/${CLUSTER}/terraform.tfvars"
  sed -i "s|tectonic_azure_ssh_key = \"\"|tectonic_azure_ssh_key = \"${SSH_KEY}\"|g" "build/${CLUSTER}/terraform.tfvars"
  sed -i "s|tectonic_cluster_name = \"\"|tectonic_cluster_name = \"${CLUSTER}\"|g" "build/${CLUSTER}/terraform.tfvars"

  # TODO: make this work with Tectonic license
  sed -i "s|tectonic_vanilla_k8s = false|tectonic_vanilla_k8s = true|g" "build/${CLUSTER}/terraform.tfvars"

  make plan
  make apply
else
  make apply
fi
