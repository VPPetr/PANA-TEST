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
  alias = "azconnectivity"
  # subscription_id = "c24b3069-0534-4556-b91a-679c9f8e68ff"
  subscription_id = "47710623-3ba0-4e16-a1da-38b69b6be17c"
}

data "azurerm_virtual_network" "convnet" {
  name                = "euw-vnet-018-testdomain-01"
  resource_group_name = "euw-rg-vnet-018-testdomain-01"
  provider            = azurerm.azconnectivity
}

