#!/bin/bash

set -e

export LOCATION=westeurope
export RESOURCE_GROUP_NAME="euw-rg-tfstate-01"
export STORAGE_ACCOUNT_NAME="euwst001tfstateall"
export CONTAINER_NAME="terraform"
export TAGS="environment=Production creator=SoftwareOne"

echo "Displaying current Azure Subscription"

az account show

read -p "If this doesn't show the correct subscription - Ctrl-C NOW"

echo "Creating..."
echo "In region $LOCATION"
echo "Resource Group $RESOURCE_GROUP_NAME"
echo "Storage Account $STORAGE_ACCOUNT_NAME"
echo "Container $CONTAINER_NAME"

if [ $(az group exists --name "$RESOURCE_GROUP_NAME" | grep -c "true") -eq 1 ]
then
  echo "Resource group exists.  Exiting.  Cannot bootstrap an existing environment"
  exit 1
fi

az group create -n $RESOURCE_GROUP_NAME -l $LOCATION --tags $TAGS
az storage account create -g $RESOURCE_GROUP_NAME -l $LOCATION \
  --name $STORAGE_ACCOUNT_NAME \
  --sku Standard_LRS \
  --encryption-services blob \
  --min-tls-version TLS1_2 \
  --tags $TAGS
  
az storage container create --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --auth-mode login

echo "Bootstrap complete.  You should define all 3 objects (RG, Storage account and Container) in your code and import into terraform state"