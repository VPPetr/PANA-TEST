locals {
  storage_accounts = {
    "tpieufs" = {
      name       = "euwstpitfs01"
      rg         = azurerm_resource_group.rgs["rgstorage01"].name
      location   = local.primary_location
      subnet_ids = ["/subscriptions/99e09532-ba2f-4d0b-bf82-692f0ad9c773/resourceGroups/euw-rg-vnet-087-files-pit-01/providers/Microsoft.Network/virtualNetworks/euw-vnet-087-files-pit-01/subnets/euw-snet-087-files-pit-01", "/subscriptions/c60ec3ef-a135-4868-b9e7-40801ee2765e/resourceGroups/euw-rg-vnet-001-management-01/providers/Microsoft.Network/virtualNetworks/euw-vnet-001-management-01/subnets/euw-snet-001-management-01", "/subscriptions/c60ec3ef-a135-4868-b9e7-40801ee2765e/resourceGroups/euw-rg-vnet-001-management-01/providers/Microsoft.Network/virtualNetworks/euw-vnet-001-management-01/subnets/euw-snet-001-management-02"]

      shares = {
        "pceu" = {
          quota = 100
        }
      }
    }
  }
}

module "storage" {
  source    = "../modules/storage_account"
  for_each  = local.storage_accounts
  sa_config = each.value
}


locals {
  boot_diags = module.storage["tpitfs"].primary_blob_endpoint
}

output "storage" {
  value = module.storage
}

resource "azurerm_private_endpoint" "stpitfs01" {
  name                = "pep-euwstpitfs01"
  location            = local.primary_location
  resource_group_name = azurerm_resource_group.rgs["rgstorage01"].name
  subnet_id           = local.vnets_087-snetid["vnet_087-1"]["euw-snet-087-files-pit-01"]
  private_service_connection {
    name                           = "euwstpitfs01"
    is_manual_connection           = false
    private_connection_resource_id = module.storage["tpitfs"].id
    subresource_names              = ["file"]
  }

  ip_configuration {
    name               = "ip-euwstpitfs01"
    # private_ip_address = "10.111.148.148"
    subresource_name   = "file"
  }
}

resource "azurerm_private_dns_a_record" "st_fqdn" {
  provider            = azurerm.azconnectivity
  name                = "euwstpitfs01"
  zone_name           = data.azurerm_private_dns_zone.filepdns.name
  resource_group_name = data.azurerm_private_dns_zone.filepdns.resource_group_name
  ttl                 = 10
  records             = [azurerm_private_endpoint.stpitfs01.ip_configuration[0].private_ip_address]
}