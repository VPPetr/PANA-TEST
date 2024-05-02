terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "> 3"
    }
  }
  #managmenet sub
  backend "azurerm" {
    resource_group_name  = "euw-rg-tfstate-01"
    storage_account_name = "euwst001tfstatesall"
    container_name       = "terraform"
    key                  = "085-Terraform.tfstate"
    subscription_id      = "c60ec3ef-a135-4868-b9e7-40801ee2765e"
  }
}

provider "azurerm" {
  features {}
  #alias = "pieuenv"
  subscription_id = "0098d6b7-2012-4327-9b00-5515e478d5e5"
}

provider "azurerm" {
  features {}
  alias           = "azconnectivity"
  subscription_id = "c24b3069-0534-4556-b91a-679c9f8e68ff"
}
provider "azurerm" {
  features {}
  alias           = "management"
  subscription_id = "c60ec3ef-a135-4868-b9e7-40801ee2765e"
}

data "azurerm_virtual_network" "convnet" {
  name                = "euw-vnet-003-connectivity-01"
  resource_group_name = "euw-rg-vnet-003-connectivity-01"
  provider            = azurerm.azconnectivity
}

data "azurerm_virtual_network" "managementvnet" {
  name                = "euw-vnet-001-management-01"
  resource_group_name = "euw-rg-vnet-001-management-01"
  provider            = azurerm.management
}
data "azurerm_subnet" "managementsubnets" {
  name                 = data.azurerm_virtual_network.managementvnet.subnets[count.index]
  virtual_network_name = data.azurerm_virtual_network.managementvnet.name
  resource_group_name  = data.azurerm_virtual_network.managementvnet.resource_group_name
  count                = length(data.azurerm_virtual_network.managementvnet.subnets)
  provider             = azurerm.management
}
data "azurerm_private_dns_zone" "filepdns" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = "euw-rg-pdns-003-connectivity-01"
  provider            = azurerm.azconnectivity
}