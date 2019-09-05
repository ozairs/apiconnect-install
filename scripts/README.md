# API Connect Scripts

These instructions provide details on how to automate your entire deployment of API Connect V2018, from the initial installation on Kubernetes to API subscription and testing.

Use the following scripts (in order) to deploy API Connect V2018


- Step 1. Install API Connect Subsystems (install-subsystems.sh)
  
  Using the apiconnect-up.yam file, this script installs API Connect subsystems. You have the option to install all or individual subsystems using the interactive shell.

- Step 2. Register API Connect Subsystems (register-subsystems.sh)

  This script uses the API Connect REST API to perform the initial setup of an API Connect cloud, and allow you to register individual subsystems using the interactive shell.

- Step 3. Create a provider organization (create-porg.sh)

  This script creates a provider organization either from an existing user or inviting a new user. Optionally, if you have created a portal instance, you can provision the portal instance for the catalog.

- Step 4. Deploy API definitions and product (deploy-api.sh)

  This script deploys multiple APIs and an API product, including an OAuth provider. The APIs and products are created within API drafts and published to the catalog (default sandbox catalog)

- Step 5. Create Application Subscription (create-app-subscription.sh)

  This script creates an application subscription to a published product, including registering a redirect URL and creating new application credential.

**Optional**

- Install Kubernetes cluster (install-k8.sh) - *Optional*

   Install a Kubernetes cluster (ie kubeadm), and its command line tools (ie kubectl, helm). The script will also install a storage based on rook. If your using a managed Kubernetes cluster, you don't need to install this script

- Publish and Subscribe (run-pub-sub.sh)
  
  This script helps in development where you can quickly publish and subscribe to an API product in the Sandbox catalog.

- Test deployed API products (test-api.sh)
  
  This script runs a series of tests to validate the deployed apis.
