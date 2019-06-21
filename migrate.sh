#!/bin/bash

source config.shlib; # load the config library functions

nice_echo() {
    echo -e "\n\033[1;36m >>>>>>>>>> $1 <<<<<<<<<< \033[0m\n"
}

nice_echo "Check if kubernetes (kubectl) is installed"
if which kubectl > /dev/null; then
    echo 'kubectl exists with version' $(kubectl version)
else 
    echo 'kubectl is not installed'
    exit
fi

nice_echo "Check if apicup is installed"
if which apicup > /dev/null; then
    echo 'apicup exists with version' $(apicup version)
else 
    echo 'apicup is not installed'
    exit
fi

nice_echo "Check if apiconnect-up.yml file exists"
if [ -e apiconnect-up.yml ] 
then
    echo 'apiconnect-up.yml exists' $(pwd)
else 
    echo 'apiconnect-up.yml is not available'
    exit
fi

nice_echo "Check if Kubernetes environment is set"
if [ ! -z "${KUBECONFIG}" ]; then
    echo 'Kubernetes environment is available'
else 
    echo 'Kubernetes environment is not available'
    exit
fi

MANAGER_SUBSYS=$(config_get MANAGER_SUBSYS)
GATEWAY_SUBSYS=$(config_get GATEWAY_SUBSYS)
ANALYTICS_SUBSYS=$(config_get ANALYTICS_SUBSYS)
PORTAL_SUBSYS=$(config_get PORTAL_SUBSYS)

export KUBECONFIG=$(config_get BLUE_KUBECONFIG)

nice_echo "Performing on-demand API Manager Subsystem backup"
apicup subsys exec ${MANAGER_SUBSYS} backup --debug

echo "Back task completed, successful backups are stored at the location specified by the cassandra-backup-path parameter (within the apiconnect-up.yml file). "

nice_echo "Listing API Manager Subsystem backups"
apicup subsys exec ${MANAGER_SUBSYS} list-backups

export KUBECONFIG=/Users/ozairs/Development/kubernetes/apiconnect/fyre/kubeconfig-apic3-green

nice_echo "Performing on-demand API Manager Subsystem restore"
apicup subsys install ${MANAGER_SUBSYS} --debug

nice_echo "Restoring API Manager Subsystem restore"
apicup subsys exec ${MANAGER_SUBSYS} restore <backupID>

