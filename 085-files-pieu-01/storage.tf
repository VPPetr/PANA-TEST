# Account euwstpieufs01
# share name ??
# Private endpoint for storage in 085 vnet
# DNS configuration for private endpoint in DNS zone "privatelink.file.core.windows.net"\RG euw-rg-pdns-003-connectivity-01\ sub pisceu-az-003-connectivity

locals {
  storage_accounts = {
    ### Temp Storage for Training Migrations
    "tpieufs" = {
      name     = "euwstpieufs01"
      rg       = azurerm_resource_group.rgs["rgstorage01"].name
      location = local.primary_location
     # subnet_ids = local.subnet_ids["vnet_085-1"]["euw-snet-085-files-pieu-01"]
      shares = {
        "PFCOE" = {
          quota = 2048
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
  boot_diags = module.storage["bootdiags"].primary_blob_endpoint
}

output "storage" {
  value = module.storage
}

## Temp PE for Training storage account

resource "azurerm_private_endpoint" "swotemp" {
  name                = "pep-euwstpieufs01"
  location            = local.primary_location
  resource_group_name = azurerm_resource_group.rgs["rgstorage01"].name
  subnet_id           = local.subnet_ids["vnet_085-1"]["euw-snet-085-files-pieu-01"]

  private_service_connection {
    name                           = "euwstpieufs01"
    is_manual_connection           = false
    private_connection_resource_id = module.storage["euwstpieufs01"].id
    subresource_names              = ["file"]
  }

  ip_configuration {
    name               = "ip-euwstpieufs01"
    private_ip_address = "10.181.58.98"
    subresource_name   = "file"
  }
}