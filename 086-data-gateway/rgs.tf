locals {
  rgs = {
    rgvnet = {
      name     = "euw-rg-vnet-086-data-gateway-01"
      location = local.primary_location
    }
    rgstorage01 = {
      name     = "euw-rg-st-086-data-gateway-01"
      location = local.primary_location
    }
    rgvm = {
      name     = "euw-rg-vm-086-data-gateway-01"
      location = local.primary_location
    }
  }
}

resource "azurerm_resource_group" "rgs" {
  for_each = local.rgs
  name     = each.value.name
  location = each.value.location
}