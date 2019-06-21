#!/bin/bash

#README: You must configure your environment parameters in the config.cfg file.

if [ -e $PWD/config.cfg ] 
then
    echo 'script config file exists' $(pwd)
else 
    echo 'script config file is not available at $(pwd)'
    exit
fi
source $PWD/../scripts/config.cfg; # load the config library functions
#todo: add validation to make sure file exists

nice_echo() {
    echo -e "\n\033[1;36m >>>>>>>>>> $1 <<<<<<<<<< \033[0m\n"
}

check_pods() {
    echo "Check the status of pods in namespace $1"
    count=0
    while(true)
    do
    kubectl get pods -n $1
    kubectl get pods --namespace $1 | awk '{
        if ($2 ~ /0\/*/) {
            if ($3 != "Completed") {
                print $1 " is not up"; exit -1
            }
        }
        }';
    if [ $? -eq 0 ]
    then
    break;
    fi
    (( count++ ))
    if [ $count -eq 90 ]
    then
    exit -1
    fi
    sleep 10
    done
}

DOCKER_USERNAME=$DOCKER_USERNAME
DOCKER_PASSWORD=$DOCKER_PASSWORD
NAMESPACE=$NAMESPACE
DOCKER_REGISTRY=$DOCKER_REGISTRY

MANAGER_SUBSYS=$MANAGER_SUBSYS
GATEWAY_SUBSYS=$GATEWAY_SUBSYS
ANALYTICS_SUBSYS=$ANALYTICS_SUBSYS
PORTAL_SUBSYS=$PORTAL_SUBSYS

nice_echo "Check if kubernetes (kubectl) is installed"
if which kubectl > /dev/null; then
    echo 'kubectl exists with version' $(kubectl version)
else 
    echo 'kubectl is not installed'
    exit
fi

nice_echo "Check helm version" $(helm version)
echo "If your running different helm client and server versions, you can upgrade server with helm init --upgrade."

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
    echo 'apiconnect-up.yml is not available at $(pwd)'
    exit
fi

nice_echo "Check if Kubernetes environment is set"
if [ ! -z "${KUBECONFIG}" ]; then
    echo 'Kubernetes environment is available'
else 
    echo 'Kubernetes environment is not available'
    exit
fi

nice_echo "Creating Kubernetes namespace"
kubectl create namespace ${NAMESPACE}

#remove old secret
kubectl delete secret apiconnect-image-pull-secret -n ${NAMESPACE}

nice_echo "Creating docker registry secret"
kubectl create secret docker-registry apiconnect-image-pull-secret --docker-server=${DOCKER_REGISTRY} --docker-username=${DOCKER_USERNAME} --docker-password=${DOCKER_PASSWORD} --docker-email=${DOCKER_USERNAME} --namespace ${NAMESPACE}

read -p "Do you want to install the API Manager subsystem (y/n)." -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    nice_echo "Installing API Manager Subsystem"
    apicup subsys install ${MANAGER_SUBSYS} --debug
    nice_echo "Finished Installing API Manager Subsystem. Please review logs for any issues."
fi

read -p "Do you want to install the Gateway subsystem (y/n)." -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    nice_echo "Installing Gateway Subsystem"
    apicup subsys install ${GATEWAY_SUBSYS} --debug
    nice_echo "Finished Installing Gateway Subsystem. Please review logs for any issues."
fi

read -p "Do you want to install the Analytics subsystem (y/n)." -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    nice_echo "Installing Analytics Subsystem"
    apicup subsys install ${ANALYTICS_SUBSYS} --debug
    nice_echo "Finished Installing Analytics Subsystem. Please review logs for any issues."
fi

read -p "Do you want to install the Portal subsystem (y/n)." -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    nice_echo "Installing Portal Subsystem"
    apicup subsys install ${PORTAL_SUBSYS} --debug
    nice_echo "Finished Installing Analytics Subsystem. Please review logs for any issues."
fi

nice_echo "Finished installing API Connect Subsystems!"
