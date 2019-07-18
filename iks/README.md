# Installing API Connect on IBM Kubernetes Service (IKS)

In these instructions, you will learn how to deploy API Connect on IBM Kubernetes service, and configuring the required components, such as Block storage, networking and custom ingress.

These are basic instructions and you should consult product documentation / reference material to harden your installation for production deployments.

## Create Kubernetes Cluster

1. Login to [IBM Cloud][https://cloud.ibm.com/]
2. Click on the **Catalog** link and search for or click on **Kubernetes service**.
3. Click the **Create** button and enter the following values and leave the others at the default values (customize them based on your requirements):
 * Cluster name: apic2018
 * Location: Single Zone -> Toronto 01
 * Flavor: 8 cores 32 GB RAM Ubuntu 16 (b2c.8x32)
 * Worker nodes: 3 (default)
4. Click **Create cluster** to start the process of creating your Kubernetes cluster. The process takes 10-15 minutes to complete.
5. Follow the instructions to download the `ibmcloud` cli tool. You will need it to install Kubernetes components and provides easier access to the Kubernetes cluster. Before acccessing the cluster, make sure its been provisioned.

Note: If your using an IBM W3 account, add `-sso` as a flag to the `ibmcloud login` command.

    ```
    ibmcloud login -a https://api.us-east.bluemix.net --sso
    .
    .
    export KUBECONFIG=/Users/ozairs/Development/kubernetes/config-ibmcloud/kube-config-tor01-apiconnect.yml
    ```

6. As you wait, make a note of your API Connect components and populate the [apiconnect-up.yml](./apiconnect-up.yml) file. You will need to replace `apic2018` with your cluster name since the cluster name is uniquely defined into each IKS cluster.
 * API Connect Cloud Manager: https://cloud.apic2018.tor01.containers.appdomain.cloud/admin/ 
 * API Connect Manager: https://manager.apic2018.tor01.containers.appdomain.cloud/manager/
 * API Gateway: https://apigateway.apic2018.tor01.containers.appdomain.cloud/ & https://apigateway-service.apic2018.tor01.containers.appdomain.cloud/
 * Portal: https://portal.apic2018.tor01.containers.appdomain.cloud/ & https://portal-admin.apic2018.tor01.containers.appdomain.cloud/ 
 * Analytics: https://ac.apic2018.tor01.containers.appdomain.cloud/ & https://ai.apic2018.tor01.containers.appdomain.cloud/ 

7. Create Block Storage for your cluster using `helm`

    ```
    kubectl apply -f https://raw.githubusercontent.com/IBM-Cloud/kube-samples/master/rbac/serviceaccount-tiller.yaml
    helm init --service-account-tiller
    helm repo add ibm https://registry.bluemix.net/helm/ibm
    helm repo update
    helm install --name ibmcloud-block-storage-plugin ibm/ibmcloud-block-storage-plugin
    ```

8. Follow the prompts and verify the installation. 
    ```
    kubectl get pods -n kube-system | grep ibmcloud-block-storage
    ibmcloud-block-storage-driver-7l2t8                               1/1       Running   0          <invalid>
    ibmcloud-block-storage-driver-c2vbz                               1/1       Running   0          <invalid>
    ibmcloud-block-storage-driver-j6kff                               1/1       Running   0          <invalid>
    ibmcloud-block-storage-plugin-554686486d-rwj42                    1/1       Running   0          <invalid>
    ```

9. Make sure that the storage class is available and make a note of the block storage class (ie `ibmc-block-gold`).

    ```
    kubectl get storageclass
    NAME                         PROVISIONER         AGE
    default                      ibm.io/ibmc-file    1h
    ibmc-block-bronze            ibm.io/ibmc-block   9s
    ibmc-block-custom            ibm.io/ibmc-block   9s
    ibmc-block-gold              ibm.io/ibmc-block   9s
    ibmc-block-retain-bronze     ibm.io/ibmc-block   9s
    ibmc-block-retain-custom     ibm.io/ibmc-block   9s
    ibmc-block-retain-gold       ibm.io/ibmc-block   9s
    ibmc-block-retain-silver     ibm.io/ibmc-block   9s
    ibmc-block-silver            ibm.io/ibmc-block   9s
    ibmc-file-bronze (default)   ibm.io/ibmc-file    1h
    ibmc-file-custom             ibm.io/ibmc-file    1h
    ibmc-file-gold               ibm.io/ibmc-file    1h
    ibmc-file-retain-bronze      ibm.io/ibmc-file    1h
    ibmc-file-retain-custom      ibm.io/ibmc-file    1h
    ibmc-file-retain-gold        ibm.io/ibmc-file    1h
    ibmc-file-retain-silver      ibm.io/ibmc-file    1h
    ibmc-file-silver             ibm.io/ibmc-file    1h
    ```


## Install Custom Ingress and reuse IBM-provided Ingress subdomain

In this section, you will install a custom ingress for your Kubernetes cluster, disabling the existing load balancer while preserving the load balancer hostnames.

The Application load balance (ALB) is a built-in Kubernetes service that uses a selector to run an ingress controller. You will modify the ALB selector value to use the custom ingress instead of the default ingress controller.

1. Obtain the Kubernettes Application load balance (ALB) service name

    ```
    kubectl get svc -n kube-system | grep alb
    public-crdc6f88a0ecca43259966dbb9b7c1479b-alb1   LoadBalancer   172.21.97.105    169.53.186.140   80:31306/TCP,443:30792/TCP   59m
    ```

    The <ALB_ID> is public-crdc6f88a0ecca43259966dbb9b7c1479b-alb1

2. Disable the ALB using the `ibmcloud` CLI. The ALB service manages the cluster load balancer and provides DNS host resolution.
    ```
    ibmcloud ks alb-configure --albID <ALB_ID> --disable-deployment
    Configuring ALB...
    OK
    ```

3. Install custom ingress controller

    ```
    helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
    helm install stable/nginx-ingress --name ingress --version 0.15 --values ingress-values.yml --namespace kube-system
    ```

    This action deploys custom ingress controller pods in the `kube-system` namespace. In the next step, you will modify the existing `ingress-nginx-ingress-controller` Kubernetes service to use the custom ingress pods. This task is done using kubernetes selectors.

4. Obtain the custom ingress selector value. Its done indirectly by examining an existing Kubernetes service, `ingress-nginx-ingress-controller`. You will use this value in the ALB Kubernetes service.

    ```
    kubectl describe svc ingress-nginx-ingress-controller -n kube-system
    Namespace:                kube-system
    Labels:                   app=nginx-ingress
                              chart=nginx-ingress-0.15.0
                              component=controller
                              heritage=Tiller
                              release=ingress
    Annotations:              <none>
    Selector:                 app=nginx-ingress,component=controller,release=ingress
    ```
5. Make a note of the `Selector` value: `app=nginx-ingress,component=controller,release=ingress`

6. Modify the ALB Kubernetes service to use the selector values from the custom ingress.

    ```
    kubectl edit svc <ALB_ID> -n kube-system
    apiVersion: v1
    kind: Service
    metadata:
    ...
    spec:
    clusterIP: 172.21.xxx.xxx
    externalTrafficPolicy: Cluster
    loadBalancerIP: 169.xx.xxx.xxx
    ports:
    - name: http
        nodePort: 31070
        port: 80
        protocol: TCP
        targetPort: 80
    - name: https
        nodePort: 31854
        port: 443
        protocol: TCP
        targetPort: 443
    selector:
        app: nginx-ingress
        component: controller 
        release: ingress
    ```

7. Verify that the ALB selector is now using the custom ingress controller

    ```
    kubectl describe svc <ALB_ID> -n kube-system
    Name:                     public-crdc6f88a0ecca43259966dbb9b7c1479b-alb1
    Namespace:                kube-system
    Labels:                   app=public-crdc6f88a0ecca43259966dbb9b7c1479b-alb1
    Annotations:              service.kubernetes.io/ibm-load-balancer-cloud-provider-vlan: 2658847
                            service.kubernetes.io/ibm-load-balancer-cloud-provider-zone: tor01
    Selector:                 app=nginx-ingress,component=controller,release=ingress
    ```

## Install API Connect

**Manual**

1. Create a Kubernetes namespace with the command `kubectl create namespace apic`
2. Download and prepare the Docker images into your Docker registry. 
3. Create the `apiconnect-image-pull-secret` docker secret that is used to access the Docker registry
    ```
    kubectl create secret docker-registry apiconnect-image-pull-secret --docker-server=myserver --docker-username=ozairs --docker-password=******* --docker-email=ozairs -n apic
    ```
4. Prepare the `apiconnect-up.yml` file. You can use the existing file in this repository and modify them based on your environment and requirements.
5. Install each API Connect subsystem based on the instructions [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_Kubernetes_overview.html)

**Automatic**

1. Install each API Connect subsystem using the script [here](../scripts/)
2. Run the script with the command `./install-apic` and follow the prompts

    ```
    sd
    ```

3. Verify that

## Troubleshooting

kubectl logs public-cr404f0cb74f40433aa3e3d0d2e6532258-alb1-69758c49-tpt6m -n kube-system -c nginx-ingress

kubectl get secret default-service --namespace=default --export -o yaml |\
   kubectl apply --namespace=kube-system -f -
