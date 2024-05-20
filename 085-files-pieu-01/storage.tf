# Account euwstpieufs01
# share name ??
# Private endpoint for storage in 085 vnet
# DNS configuration for private endpoint in DNS zone "privatelink.file.core.windows.net"\RG euw-rg-pdns-003-connectivity-01\ sub pisceu-az-003-connectivity

locals {
  storage_accounts = {
    ### Temp Storage for Training Migrations
    "tpieufs" = {
      name       = "euwstpieufs01"
      rg         = azurerm_resource_group.rgs["rgstorage01"].name
      location   = local.primary_location
      subnet_ids = ["/subscriptions/0098d6b7-2012-4327-9b00-5515e478d5e5/resourceGroups/euw-rg-vnet-085-files-pieu-01/providers/Microsoft.Network/virtualNetworks/euw-vnet-085-files-pieu-01/subnets/euw-snet-085-files-pieu-01", "/subscriptions/c60ec3ef-a135-4868-b9e7-40801ee2765e/resourceGroups/euw-rg-vnet-001-management-01/providers/Microsoft.Network/virtualNetworks/euw-vnet-001-management-01/subnets/euw-snet-001-management-01", "/subscriptions/c60ec3ef-a135-4868-b9e7-40801ee2765e/resourceGroups/euw-rg-vnet-001-management-01/providers/Microsoft.Network/virtualNetworks/euw-vnet-001-management-01/subnets/euw-snet-001-management-02"]

      shares = {
        "pfcoe" = {
          quota = 2048
        }
      }
      ad_auth = {
        domain_guid         = "f6421d14-5ec3-4c39-a813-fa450fbca085"
        domain_name         = "eu.gds.panasonic.com"
        domain_sid          = "S-1-5-21-2739511847-3804836064-3058629999"
        forest_name         = "gds.panasonic.com"
        netbios_domain_name = "EU"
        storage_sid         = "S-1-5-21-2739511847-3804836064-3058629999-4765473"
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
  boot_diags = module.storage["tpieufs"].primary_blob_endpoint
}

output "storage" {
  value = module.storage
}

## Temp PE for Training storage account

resource "azurerm_private_endpoint" "stpieufs01" {
  name                = "pep-euwstpieufs01"
  location            = local.primary_location
  resource_group_name = azurerm_resource_group.rgs["rgstorage01"].name
  subnet_id           = local.vnets_085-snetid["vnet_085-1"]["euw-snet-085-files-pieu-01"]
  private_service_connection {
    name                           = "euwstpieufs01"
    is_manual_connection           = false
    private_connection_resource_id = module.storage["tpieufs"].id
    subresource_names              = ["file"]
  }

  ip_configuration {
    name               = "ip-euwstpieufs01"
    private_ip_address = "10.111.148.148"
    subresource_name   = "file"
  }
}

resource "azurerm_private_dns_a_record" "st_fqdn" {
  provider            = azurerm.azconnectivity
  name                = "euwstpieufs01"
  zone_name           = data.azurerm_private_dns_zone.filepdns.name
  resource_group_name = data.azurerm_private_dns_zone.filepdns.resource_group_name
  ttl                 = 10
  records             = [azurerm_private_endpoint.stpieufs01.ip_configuration[0].private_ip_address]
}