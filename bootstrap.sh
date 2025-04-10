#!/bin/bash
set -euo pipefail

# Prerequisites checks
if ! command -v oc >/dev/null 2>&1; then
  echo "[ERROR] oc CLI is not installed."
  exit 1
fi
if ! command -v sed >/dev/null 2>&1; then
  echo "[ERROR] sed is not installed."
  exit 1
fi

echo "[INFO] Verifying OpenShift login..."
if ! oc whoami &>/dev/null; then
  echo "[ERROR] You are not logged in. Please run 'oc login' first."
  exit 1
fi
echo "[SUCCESS] Logged in as: $(oc whoami)"


# Set Argo CD source Git repo URL
echo "==> Enter the Argo CD application source Git repo URL:"
read -rp "Repo URL: " REPO_URL
sed -i.bak -E "s|(repoURL:[[:space:]]+)[^[:space:]]+|\1${REPO_URL}|" ./application/cloud-pak-deployer.yaml
rm -f ./application/cloud-pak-deployer.yaml.bak
echo "[SUCCESS] Updated application/cloud-pak-deployer.yaml with repoURL: $REPO_URL"

# Detect StorageClass, Patch the PVC YAML with storageClassName
echo "[INFO] Detecting a suitable StorageClass for cloud-pak-deployer-status PVC..."
STORAGE_CLASS=""
if oc get sc managed-nfs-storage >/dev/null 2>&1; then
  STORAGE_CLASS="managed-nfs-storage"
elif oc get sc ocs-storagecluster-cephfs >/dev/null 2>&1; then
  STORAGE_CLASS="ocs-storagecluster-cephfs"
elif oc get sc ocs-external-storagecluster-cephfs >/dev/null 2>&1; then
  STORAGE_CLASS="ocs-external-storagecluster-cephfs"
elif oc get sc ibmc-file-gold-gid >/dev/null 2>&1; then
  STORAGE_CLASS="ibmc-file-gold-gid"
else
  echo "[WARN] No recognized storage class found automatically."
  echo "[INFO] Available storage classes:"
  oc get sc
  read -rp "==> Please enter a valid storage class name to use: " STORAGE_CLASS
fi
echo "[SUCCESS] Using storage class: $STORAGE_CLASS"

echo "[INFO] Patching ./base/pvc.yaml to use $STORAGE_CLASS ..."
sed -i.bak -E "s|(storageClassName:[[:space:]]+)[^[:space:]]+|\1${STORAGE_CLASS}|" ./base/pvc.yaml
rm -f ./base/pvc.yaml.bak
echo "[SUCCESS] Patched PVC with correct storage class."


# Commit and push changes to Git 
echo "==> Would you like to commit and push the YAML changes now? (y/n):"
read -r PUSH_NOW
if [[ "$PUSH_NOW" =~ ^[Yy]$ ]]; then
  git add ./base
  git add ./application/cloud-pak-deployer.yaml
  if git diff --cached --quiet; then
    echo "[INFO] No changes to commit."
  else
    git commit -m "Bootstrap script: set storage class and repo URL"
    git push
    echo "[SUCCESS] Changes committed and pushed to Git."
  fi
fi


# Create the entitlement secret
echo "==> Enter the IBM Container Entitlement Key (from https://myibm.ibm.com/products-services/containerlibrary):"
read -srp "Entitlement Key: " ENTITLEMENT_KEY
echo ""

if ! oc get ns cloud-pak-deployer &>/dev/null; then
  echo "[INFO] Creating namespace cloud-pak-deployer..."
  oc create namespace cloud-pak-deployer
  echo "[SUCCESS] Namespace created."
fi

if oc get secret cloud-pak-entitlement-key -n cloud-pak-deployer &>/dev/null; then
  echo "[INFO] Deleting existing cloud-pak-entitlement-key secret..."
  oc delete secret cloud-pak-entitlement-key -n cloud-pak-deployer
fi
echo "[INFO] Creating new secret cloud-pak-entitlement-key..."
oc create secret generic cloud-pak-entitlement-key -n cloud-pak-deployer \
  --from-literal=cp-entitlement-key="${ENTITLEMENT_KEY}"
echo "[SUCCESS] Secret created/updated."


# Apply the Argo CD Application
echo "[INFO] Applying the Argo CD Application manifest..."
oc apply -f ./application/cloud-pak-deployer.yaml -n openshift-gitops
echo "[SUCCESS] Argo CD Application bootstrapped successfully."

echo "[INFO] Retrieving Argo CD dashboard information..."
ARGO_ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')
ARGO_PASS=$(oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath="{.data.admin\.password}" | base64 -d 2>/dev/null || true)

if [[ -z "$ARGO_ROUTE" || -z "$ARGO_PASS" ]]; then
  echo "[WARN] Could not retrieve Argo CD dashboard URL or admin password."
else
  echo "=============================================================="
  echo "[INFO] Argo CD Dashboard URL : https://${ARGO_ROUTE}"
  echo "[INFO] Argo CD Admin Password: ${ARGO_PASS}"
  echo "=============================================================="
fi

echo "[SUCCESS] Bootstrap completed."
