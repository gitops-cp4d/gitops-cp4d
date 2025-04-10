
# CP4D GitOps Deployment with Argo CD

This repository provides a GitOps-based framework for deploying Cloud Pak for Data (CP4D) on OpenShift by Argo CD. It uses Kustomize overlays to declaratively manage the CP4D installation process across multiple environments.

---

## Prerequisites

Make sure you have the following before starting:

- ✅ OpenShift CLI (`oc`)
- ✅ Git installed and configured
- ✅ Access to an OpenShift cluster  (You can reserve one from [IBM TechZone](https://techzone.ibm.com/collection/tech-zone-certified-base-images/journey-base-open-shift))
- ✅ IBM Container Entitlement Key (Get it from [IBM Container Library](https://myibm.ibm.com/products-services/containerlibrary))

---


## Usage

### Clone the Repository

Click the **[Use this template](https://github.com/new?template_name=gitops-cp4d&template_owner=gitops-cp4d)** button to create your own repo.
Then clone your new repo and navigate into root directory

### Configure the CP4D Installation

Edit the `cpd-config.yaml` file in the desired overlay (e.g., `./overlays/dev/cpd-config.yaml`).
- Set cartridges/components to `"installed"` to enable them
- Set them to `"removed"` to disable
You can tailor the config per environment (`dev`, `prod`, etc.).

### Log in to OpenShift
Make sure you're logged into the correct cluster (`oc login`)and have the necessary permissions.

### Run the Bootstrap Script

This will prompt you through initial setup:
```
./bootstrap.sh
```
The script will:
- Patch the Git repo URL and detected storage class into your manifests
- Prompt for your IBM Container Entitlement Key and create a Kubernetes secret
- Commit changes to Git
- Apply the Argo CD Application manifest to trigger CP4D installation

### Access Argo CD
After bootstrapping, the script will display:
- Argo CD dashboard URL
- Argo CD admin Password

Login and monitor the sync process. Argo CD will continuously watch this repo and apply changes automatically.