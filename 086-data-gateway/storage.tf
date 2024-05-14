# Account euwstpieufs01
# share name ??
# Private endpoint for storage in 085 vnet
# DNS configuration for private endpoint in DNS zone "privatelink.file.core.windows.net"\RG euw-rg-pdns-003-connectivity-01\ sub pisceu-az-003-connectivity


locals {
  storage_accounts = {
    ### Temp Storage for Training Migrations
    "datagw" = {
      name       = "euwbdiag086datagateway01"
      rg         = azurerm_resource_group.rgs["rgstorage01"].name
      location   = local.primary_location
      subnet_ids = ["/subscriptions/4611ef78-d0cc-4b0c-845c-5e89d6384919/resourceGroups/euw-rg-vnet-086-data-gateway-01/providers/Microsoft.Network/virtualNetworks/euw-vnet-086-data-gateway-01/subnets/euw-snet-086-data-gateway-01"]

      #shares = {
      #  "pfcoe" = {
      #    quota = 2048
      #  }
      #}
    }
  }
}


module "storage" {
  source    = "../modules/storage_account"
  for_each  = local.storage_accounts
  sa_config = each.value
}


locals {
  boot_diags = module.storage["datagw"].primary_blob_endpoint
}

output "storage" {
  value = module.storage
}

## Temp PE for Training storage account

resource "azurerm_private_endpoint" "stdatagwfs01" {
  name                = "pep-euwbdiag086datagateway01"
  location            = local.primary_location
  resource_group_name = azurerm_resource_group.rgs["rgstorage01"].name
  subnet_id           = local.vnets_086-snetid["vnet_086-1"]["euw-snet-086-data-gateway-01"]
  private_service_connection {
    name                           = "euwbdiag086datagateway01"
    is_manual_connection           = false
    private_connection_resource_id = module.storage["datagw"].id
    subresource_names              = ["file"]
  }

  ip_configuration {
    name               = "ip-euwbdiag086datagw001"
    private_ip_address = "10.111.148.165"
    subresource_name   = "file"
  }
}

resource "azurerm_private_dns_a_record" "st_fqdn" {
  provider            = azurerm.azconnectivity
  name                = "euwbdiag086datagateway01"
  zone_name           = data.azurerm_private_dns_zone.filepdns.name
  resource_group_name = data.azurerm_private_dns_zone.filepdns.resource_group_name
  ttl                 = 10
  records             = [azurerm_private_endpoint.stdatagwfs01.ip_configuration[0].private_ip_address]
}
