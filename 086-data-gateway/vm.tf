provider "azurerm" {
  features {}
  alias = "az086"
  subscription_id = "4611ef78-d0cc-4b0c-845c-5e89d6384919"
}

variable "prefix" {
  default = "EUW-VMSWAP"
}

/*
resource "azurerm_resource_group" "vmrg" {
  name     = "euw-rg-vm-086-data-gateway-01"
  location = "West Europe"
}

resource "azurerm_virtual_network" "vmvnet" {
  name                = "euw-vnet-086-data-gateway-01"
  resource_group_name = "euw-rg-vnet-086-data-gateway-01"
  provider            = azurerm.az086
  location = "westeurope"
  address_space = ["10.111.148.160/28"]
}

resource "azurerm_subnet" "vmsnet" {
  name                 = "euw-snet-086-data-gateway-01"
  resource_group_name  = "euw-rg-vnet-086-data-gateway-01"
  virtual_network_name = azurerm_virtual_network.vmvnet.name
  address_prefixes     = ["10.111.148.160/28"]
}
*/

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}109-nic01"
  location            = "westeurope"
  resource_group_name = "euw-rg-vm-086-data-gateway-01"

  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    subnet_id           = local.vnets_086-snetid["vnet_086-1"]["euw-snet-086-data-gateway-01"]
  }
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.prefix}109"
  location              = "westeurope"
  resource_group_name   = "euw-rg-vm-086-data-gateway-01"
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_F8s_v2"
  

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  storage_os_disk {
    name              = "${var.prefix}109-OSdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "StandardSSD_LRS"
    disk_size_gb      = 128
   }
  os_profile {
    computer_name  = "${var.prefix}109"
    admin_username = "pisceuadminswo"
    admin_password = "Password1234!"
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

  tags = {
    environment = "staging"
  }
}