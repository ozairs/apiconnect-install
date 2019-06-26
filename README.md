# 1. Performing Blue / Green API Connect Upgrades

## 1.1. Tested on these environments
- Ubuntu 16.0.4 / Ubuntu 18.0.4
- Kubernetes 1.12.7 / Kubernetes 1.13.5
- Helm 2.12.3 / Helm 2.13.1
- CoreDNS
- [Minio](https://www.linuxhelp.com/how-to-install-minio-server-on-ubuntu-16-04) / AWS S3 / S3 compatible storage
- [sFTP server](https://websiteforstudents.com/setup-retrictive-sftp-with-chroot-on-ubuntu-16-04-17-10-and-18-04/)

- [Back up and restore in a Kubernetes environment](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapim_K8s_overview_backup_restore.html)

## 1.2. Table of Contents

- [1. Performing Blue / Green API Connect Upgrades](#1-performing-blue--green-api-connect-upgrades)
- [1.1. Pre-Requisites](#11-pre-requisites)  
- [1.2. Table of Contents](#12-table-of-contents)
- [1.3. Install Kubernetes and Dependencies (Optional)](#13-install-kubernetes-and-dependencies-optional)
- [1.4. Configure API Connect project](#14-configure-api-connect-project)
- [1.5. Install the Green API Connect Stack](#15-install-the-green-api-connect-stack)
- [1.6. Install the Blue API Connect Stack](#16-install-the-blue-api-connect-stack)
- [1.7. Perform the Backup from Green API Connect Stack](#17-perform-the-backup-from-green-api-connect-stack)
- [1.8. Perform Restore into the Blue API Connect Stack](#18-perform-restore-into-the-blue-api-connect-stack)
- [1.9. Perform Backup and Restore for the Developer Portal](#19-perform-backup-and-restore-for-the-developer-portal)
- [1.10. Perform Backup and Restore for the Analytics service](#110-perform-backup-and-restore-for-the-analytics-service)
- [1.11. Upgrading the Blue API Connect Stack](#111-upgrading-the-blue-api-connect-stack)
- [1.12. Perform Testing against upgraded Blue API Connect instance](#112-perform-testing-against-upgraded-blue-api-connect-instance)
- [1.13. Summary](#114-summary)

## 1.3. Install Kubernetes and Dependencies (Optional)

1. Install Docker CE & Kubernetes (kubeadm) and initialize the Kubernetes cluster. Kubernetes documentation is available on most Linux based operating system(s) and Windows machines.

2. Optionally, you can install client-side tools, such as `kubectl` and `helm` within the same machine where Kubernetes is installed. Ideally, you should have these tools installed on a remote machine where you can configure your Kubernetes context (ie `export KUBECONFIG=mykubeconfig`) and perform `kubectl` and `helm` command remotely.

3. You will also need storage for persisting data into volumes. For API Connect, you can view storage recommendations [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_Kubernetes_mgmt.html). For sandbox environments, you can use the host machine and any appropriate storage class that supports the host file system.

4. Sample build script is available in the repository [here](install-k8.sh). If your helm client and server versions are different use the `helm init --upgrade` command to synchronize them.

These instructions refer to "Green" stack and "Blue" stacks. THe "Green" Stack will the initial Active stack and the "Blue" stack will be the Passive stack, and the one that will be subsequently upgraded.

![alt](images/green-blue-stacks.jpg)

5. Build your Kubernetes environment for both the API Connect Blue & Green stacks, reflecting the IP addresses for each environment before moving onto the next step.

Note: Alternatively, you can also build your blue/green environments on a managed k8s stack, like GKE, AWS EKS, IBM IKS, etc.

## 1.4. Configure API Connect project

The steps to build an API Connect cloud configuration are documented [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_Kubernetes_overview.html). The key file produced is the `apiconnect-up-yml` file, which contains the topology information, including hostnames and system resources allocated. The same `apiconnect-up-yml` along with the certificate files must be used in both the Green and Blue stacks.

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

2. For this demo environment, we will apply CoreDNS customizations to both the Green (Active) and Blue (Passive) API Connect stacks,  but you may only need to apply it to the Blue (Passive) stack if your built-in DNS server is used in the Green environment. Instructions for CoreDNS configuration are available [here](../master/coredns/README.md). Once you have completed them, move to the next step.

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

## 1.5. Install the Green API Connect Stack

1. Minimal steps for installing API Connect subsystems are shown below, adjust them based on your environment. For example, make sure your namespace exists before you perform the install. Full instructions are available [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_Kubernetes_overview.html)

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

    Sample script is available [here](install-apic.sh). Make sure you modify the `config.cfg` file to reflect your environment.

2. Once the installation is complete, you will need to access the API Manager Cloud console. If the API Connect subsystem hostnames are not defined in your DNS server, you will need to manually add them to your host machine using the `/etc/hosts` file.

3. Login to the API Manager Cloud console, for example, based on the previous hostnames, the login will be https://cloud.ozairs.fyre.ibm.com/admin.

4. Perform the following steps in the API Manager cloud console (https://cloud.ozairs.fyre.ibm.com/admin)
 * a. Configure email server instance, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.cmc.doc/config_emailserver.html)
 * b. Register a gateway service, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.cmc.doc/config_gateway.html)
 * c. Register an analytics service, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.cmc.doc/config_analytics.html)
 * d. Register a portal service, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.cmc.doc/config_portal.html)
 * e. Associate an analytics service with a gateway service, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.cmc.doc/associate_analytics.html)
 * f. Configure the default gateway service for each catalog, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.cmc.doc/task_cmc_config_catalogDefaults.html)
 * g. Configure a provider organization account, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.cmc.doc/create_organization.html)

 5. Perform the following steps in the API Manager (https://manager.ozairs.fyre.ibm.com/manager)
  * a. Configure the portal for the catalog, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.devportal.doc/tapim_tutorial_creating_portal.html)
  * b. Using the Develop tab in the Sandbox catalog, create an API, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.toolkit.doc/task_editor_using_editor.html)
  * c. Publish the API into the Gateway, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.toolkit.doc/tapic_publish_api_offline.html)
  * d. Test the API using any tool or built-in API Assembly test tool, see [here](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.toolkit.doc/task_toolkit_testing.html)


## 1.6. Install the Blue API Connect Stack

1. Repeat steps 1 and 2 from the [previous section] or run the build script to create a Blue stack.

2. Since the Blue stack will be restored from the Green stack, you do NOT need to perform steps 3-5.

Note: You will need to manually edit the `/etc/hosts` file on the machine(s) where you are running apicup and the web browser if you want to access the console since the Blue stack uses the same hostnames as the Green stack but different IP addresses.

## 1.7. Perform the Backup from Green API Connect Stack

1. You will need to perform the backup using the `apiconnect-up.yaml` file, so make sure your executing commands from the directory where this file is located. If you make any changes to this file, after the initial install, you will need to run the `apicup subsys install manager --debug` command again.

2. Perform the backup with the command:

    ```
    > apicup subsys exec manager backup --debug
    ```
    Make sure the backup completed successfully. The backup file will be copied into the sFTP server specified in the `apiconnect-up.yaml` file.

3. List the backups available with the command:

    ```
    apicup subsys exec manager list-backups
    ```

4. Make a note of the backup id, since you will need that value when you perform the restore in the Blue stack.

## 1.8. Perform Restore into the Blue API Connect Stack

1. You will need to perform the backup using the `apiconnect-up.yaml` file, so make sure your executing commands from the directory where this file is located. If you make any changes to this file, after the initial install, you will need to run the `apicup subsys install manager --debug` command again.

2. Switch the Kubernetes context to the Blue stack (ie `export KUBECONFIG=path_to_kubeconfig`). Perform the restore with the command:

    ```
    > apicup subsys exec manager restore <backupID> --debug
    ```
    Make sure the backup completed successfully. The backup file will be copied into the sFTP server specified in the `apiconnect-up.yaml` file.

3. The restore should complete in a few minutes. Change any static host entries on your machine.

4. Login to the API Cloud Manager and verify the same settings from the Green stack are displayed.

5. Login to the API Manager and verify the same settings from the Green stack are displayed.

6. Invoke the API and make sure you get the same response as you did from the Green stack.

## 1.9. Perform Backup and Restore for the Developer Portal

1. You will need to perform the backup using the `apiconnect-up.yaml` file, so make sure your executing commands from the directory where this file is located. If you make any changes to this file, after the initial install, you will need to run the `apicup subsys install portal --debug` command again. Ideally, you back up both the Management and Portal subsystems at the same time, to ensure synchronicity across the services.

2. Switch the Kubernetes context to the Green stack (ie `export KUBECONFIG=path_to_kubeconfig`). Perform the backup with the command:
    ```
    > apicup subsys exec portal backup-all --debug
    {
    "sitesBackedUp": [
        "cc4f03be-a8ec-49f8-8c4e-1664e2f1e8ee.00943c28-c961-4307-9b8d-d9e147dab0eb"
    ],
    "sitesFailed": []
    }
    ```
    Make sure the backup completed successfully. The backup file will be copied into the sFTP server specified in the `apiconnect-up.yaml` file.

3. Examine the backup created with the command
    ```
    > apicup subsys exec portal list-backups remote
    _portal_system_backup-20190621.213929.tar.gz
    portal.cluster.ozairs.fyre.ibm.com@om@sandbox-20190621.213931.tar.gz
    ```

4. Switch to the Kubernetes context to the Blue stack (ie `export KUBECONFIG=path_to_kubeconfig`). Perform the restore with the command:

    ```
    > apicup subsys exec portal restore-all run --debug
    ```
    Make sure the backup completed successfully. The backup file will be copied into the sFTP server specified in the `apiconnect-up.yaml` file.

5. The restore should complete in a few minutes. To view the list of installed and restored sites, run the following command: `apicup subsys exec portal list-sites sites`. Change any static host entries on your machine to validate access to the Portal.

6. The portal content includes three items. Verify the following items are available:
 - Portal data such as blogs, forums, etc ...
 - Portal Theming (CSS, plugins, etc ...)
 - API Consumers data, published Products & APIs, etc ...

## 1.10. Perform Backup and Restore for the Analytics service

For Analytics backup, you need to setup S3 compatible storage. These instructions use [minio](https://minio.io/index.html), which is a cloud-independent S3 storage provider.

1. You will need to perform the backup using the `apiconnect-up.yaml` file, so make sure you are executing commands from the directory where this file is located. If you make any changes to this file after the initial install, you will need to run the `apicup subsys install analytics --debug` command again.

2. You will need to create an S3 repository (for Minio) with the following values:
    * REPO_NAME - myrepo
    * REGION - US
    * BUCKET - bucket
    * ENDPOINT - myrepo.s3repo.com
    * ACCESS_KEY - access_key
    * SECRET_KEY - secret_key
    * BASEPATH - my_folder
    * COMPRESS_TRUE_FALSE - "" uses default of true
    * CHUNK_SIZE_GB - "" uses default of 1GB.
    * SERVER_SIDE_ENCRYPTION_TRUE_FALSE - "" sets to the default of false.

    and run the command
    ```
    apicup subsys exec analytics create-s3-repo myrepo US bucket myrepo.s3repo.com access_key secret_key my_folder "" "" ""
    ```

3. Verify the repository is created
    ```
    apicup subsys exec analytics list-repos
    ```

4. Switch to the Kubernetes context to the Green stack (ie `export KUBECONFIG=path_to_kubeconfig`). Perform the backup with the command:
    ```
    > apicup subsys exec analytics backup all mybackup myrepo ""
    ```
    Make sure the backup completed successfully. Use the command `apicup subsys exec analytics list-backups myrepo` to verify the backup.

5. Switch the Kubernetes context to the Blue stack (ie `export KUBECONFIG=path_to_kubeconfig`). Perform the restore with the command:

    ```
    > apicup subsys exec analytics restore all mybackup myrepo  "" true
    ```
    Make sure the backup completed successfully. The backup file will be copied into the s3 repository.

6. The restore should complete in a few minutes. Change any static host entries on your machine to validate access to the Analytics service.

## 1.11. Upgrading the Blue API Connect Stack

1. Download the new apicup tooling and upload the new subsystem images to a (new) image repository. If using a new registry, change the registry as for example, the manager and gateway subsystems registry settings shown below:
    ```
    metadata:
      name: manager
    .
    .
    .
    registry: location_of_upgraded_image
    .
    .
    metadata:
      name: apigateway
    .
    .
    .
    image: location_of_upgraded_image
    .
    .
    ```

2. Switch the Kubernetes context to the Blue stack (ie `export KUBECONFIG=path_to_kubeconfig`). Perform the upgrade of each component. You can use the `install-apic.sh` script to install each subsystem again. Keep the suggested order as outlined [here](https://www.ibm.com/support/knowledgecenter/en/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_upgrade_Kubernetes.html)

3. Make sure each subsystem completed successfully.

## 1.12. Perform Testing against upgraded Blue API Connect instance

Perform dark launch using the Blue stack to validate that the upgraded version is working with the same APIs published prior to the upgrade. You will need to access the Blue stack from a machine where you can resolve its IP addresses.

You will need a load balancer (ie HAProxy) that is capable of routing between the ingress for the Blue and Green stack if you want a percentage of traffic to route between the different stacks. These instructions are outside the scope of these tutorial.

Once you are satisfied with the functionality of the APIs, you can decommission the Active stack and cut over to the Passive stack, which now becomes the Active stack for your environment.

## 1.13. Summary

In this tutorial, you installed two independent stacks, an active stack (ie Green) and a passive stack (ie Blue). The API Connect environment was migrated (ie backup/restore) from the Green to the Blue stack and tested independently. After migration, the Blue stack was upgraded and testing was performed to validate the existing APIs are working. Finally, a load balancer such as HAProxy was used to support load distribution between the Green and Blue stacks.
