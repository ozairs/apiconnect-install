# Performing Blue / Green API Connect Upgrades

## Pre-Requisites
- Ubuntu 16.0.4
- Kubernetes 1.13
- Helm 2.13.1
- CoreDNS
- [Minio] (https://www.linuxhelp.com/how-to-install-minio-server-on-ubuntu-16-04)
- [sFTP server] (https://websiteforstudents.com/setup-retrictive-sftp-with-chroot-on-ubuntu-16-04-17-10-and-18-04/) 

## Step 0. Install Kubernetes and Dependencies (Optional)

1. Install Docker CE & Kubernetes (kubeadm) and initialize the Kubernetes cluster. Documentation is available on most Linux based operating system(s) and Windows machines. 

2. Optionally, you can install client-side tools, such as `kubectl` and `helm` within the same machine where Kubernetes is installed. Ideally, you should have these tools installed on a remote machine where you can configure your Kubernetes context (ie `export KUBECONFIG=mykubeconfig`) and perform `kubectl` and `helm` command remotely.

3. You will also need storage for persisting data into volumes. For API Connect, you can view storage recommendations [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_Kubernetes_mgmt.html). For sandbox environments, you can use the host machine and any appropriate storage class that supports the host file system.

4. Sample build script is available in the repository [here](install-k8.sh)

These instructions refer to "Green" stack and "Blue" stacks. THe "Green" Stack will the initial Active stack and the "Blue" stack will be the Passive stack, and the one that will be subsequently upgraded.

![alt](images/green-blue-stacks.jpg)

5. Build your Kubernetes environment for both the API Connect Blue & Green stacks, reflecting the IP addresses for each environment before moving onto the next step.

## 1. Configure API Connect project

The steps to build an API Connect cloud configuration are documented [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_Kubernetes_overview.html). The key file produced is the `apiconnect-up-yml` file, which contains the topology information, including hostnames and system resources allocated. The same `apiconnect-up-yml` file must be used in both the green stack and the blue stack.

1. Make a note of the hostnames used for your environment and the IP address for each component. You will customize the DNS server (ie CoreDNS) within Kubernetes with your hostnames. 
    - manager.ozairs.fyre.ibm.com 10.1.2.3 ;9.1.2.3
    - platform.ozairs.fyre.ibm.com 10.1.2.3 ;9.1.2.3
    - consumer.ozairs.fyre.ibm.com 10.1.2.3 ;9.1.2.3
    - gateway.ozairs.fyre.ibm.com 10.1.2.3 ;9.1.2.3
    - gateway-service.ozairs.fyre.ibm.com 10.1.2.3 ;9.1.2.3
    - portal.ozairs.fyre.ibm.com 10.1.2.3 ;9.1.2.3
    - portal-admin.ozairs.fyre.ibm.com 10.1.2.3 ;9.1.2.3
    - analytics-ingest.ozairs.fyre.ibm.com 10.1.2.3 ;9.1.2.3
    - analytics-client.ozairs.fyre.ibm.com 10.1.2.3 ;9.1.2.3

2. For this demo environment, we will apply CoreDNS customizations to both the Green (Active) and Blue (Passive) API Connect stacks,  but you may only need to apply it to the Blue (Passive) stack if your built-in DNS server is used in the Green deployment. Instructions for CoreDNS configuration are available [here](../master/coredns/README.md). Once you have completed them, move to the next step.

3. For the API manager, make sure you populate the sFTP server where backups are stored.

    ```
        cassandra-backup-protocol: sftp
        cassandra-backup-host: 10.1.2.3
        cassandra-backup-port: 22
        cassandra-backup-path: /<username>/<dir>
        cassandra-backup-schedule: 0 0 * * *
        cassandra-backup-auth-user: <username>
        cassandra-backup-auth-pass: <base64_encoded_password>
    ```

## 2. Install the Green API Connect Stack

1. Minimal steps for installing API Connect subsystems are shown below, adjust them based on your environment, for example make sure your namespace exists before you perform the install. Full instructions are available [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_Kubernetes_overview.html)

    ```
    kubectl create namespace apic

    kubectl create secret docker-registry apiconnect-image-pull-secret --docker-server=<my_docker_registry> --docker-username=<my_email> --docker-password=******* --docker-email=<my_email> -n apic

    #install manager
    apicup subsys install manager --debug

    # install analytics
    apicup subsys install analytics --debug

    # install portal
    apicup subsys install portal --debug

    #install gateway
    apicup subsys install gateway --debug

    ```

Sample script is available [here](install-apic.sh)

2. Once the installation is complete, you will need to access the API Manager Cloud console. If the API Connect subsystem hostnames are not defined in your DNS server, you will need to manually add them to your host machine using the `/etc/hosts` file.

3. Login the API Manager Cloud console, for example, based on previous example, the login will be https://cloud.ozairs.fyre.ibm.com/admin.

4. Perform the following steps in the API Manager cloud console (https://cloud.ozairs.fyre.ibm.com/admin)
 a. Configure email server instance, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.cmc.doc/config_emailserver.html)
 b. Register a gateway service, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.cmc.doc/config_gateway.html)
 c. Register an analytivs service, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.cmc.doc/config_analytics.html)
 d. Register a portal service, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.cmc.doc/config_portal.html)
 e. Associate an analytics service with a gateway service, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.cmc.doc/associate_analytics.html) 
 f. Configure the default gateway service for each catalog, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.cmc.doc/task_cmc_config_catalogDefaults.html)
 g. Configure a provider organization account, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.cmc.doc/create_organization.html)

 5. Perform the following steps in the API Manager (https://manager.ozairs.fyre.ibm.com/manager)
  a. Configure the portal for the catalog, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.devportal.doc/tapim_tutorial_creating_portal.html)
  b. Using the Develop tab in the Sandbiox catalog, create an API, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.toolkit.doc/task_editor_using_editor.html)
  c. Publish the API into the Gateway, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.toolkit.doc/tapic_publish_api_offline.html)
  d. Test the API using any tool or built-in API Assemyl test tool, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.toolkit.doc/task_toolkit_testing.html)
 

## 3. Install the Blue API Connect Stack

1. Repeat steps 1 and 2 from the [previous section] or run the build script to create a Blue stack.

2. Since the Blue stack will be restored from the Green stack, you do NOT need to perform steps 3-5. You will need to manually edit the `/etc/hosts` file on the Kubernetes host machine(s) since this environment will use the same hostnames as the Green stack but uses different IP addresses.

## 4. Perform the Backup from Green API Connect Stack

1. You will need to perform the backup using the `apiconnect-up.yaml` file, so make sure your executing commands from the directory where this file is located. If you make any changes to this file, after the initial install, you will need to run the `apicup subsys install manager --debug` command again.

2. Perform the backup with the command:

    ```
    > apicup subsys exec manager backup --debug
    ```
    Make sure the backup completed successsfully. The backup file will be copied into the sFTP server specified in the `apiconnect-up.yaml` file.

3. List the backups available with the command:

    ```
    apicup subsys exec ${MANAGER_SUBSYS} list-backups
    ```

4. Make a note of the backup id, since you will need that value when you perform the restore in the Blue stack.

## 5. Perform Restore into the Blue API Connect Stack

1. You will need to perform the backup using the `apiconnect-up.yaml` file, so make sure your executing commands from the directory where this file is located. If you make any changes to this file, after the initial install, you will need to run the `apicup subsys install manager --debug` command again.

2. Switch to the Kubernetes context to the Blue stack (ie `export KUBECONFIG=path_to_kubeconfig`). Perform the restore with the command:

    ```
    > apicup subsys exec manager restore <backupID> --debug
    ```
    Make sure the backup completed successsfully. The backup file will be copied into the sFTP server specified in the `apiconnect-up.yaml` file.

3. The restore should complete in a few minutes. Change any static host entries on your machine.

4. Login to the API Cloud Manager and verify the same settings from the Green stack are displayed.

5. Login to the API Manager and verify the same settings from the Green stack are displayed.

6. Invoke the API and make sure you get the same response as you did from the Green stack.

## 6. Perform Backup and Restore for the Developer Portal

Coming soon ....

## 7. Perform Backup and Restore for the Analytics service

Coming soon ....

## Reference
- [Back up and restore in a Kubernetes environment](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapim_K8s_overview_backup_restore.html)

## Summary

TBD