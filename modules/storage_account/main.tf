terraform {
  required_version = ">= 1.3.0"
}

resource "azurerm_storage_account" "sa" {
  name                             = var.sa_config.name
  resource_group_name              = var.sa_config.rg
  location                         = var.sa_config.location
  account_kind                     = lookup(var.sa_config, "account_kind", null)
  account_tier                     = lookup(var.sa_config, "account_tier", "Standard")
  account_replication_type         = lookup(var.sa_config, "replication_type", "LRS")
  enable_https_traffic_only        = lookup(var.sa_config, "https_only", true)
  allow_nested_items_to_be_public  = lookup(var.sa_config, "public_blob", false)
  cross_tenant_replication_enabled = lookup(var.sa_config, "cross_tenant_replication_enabled", false)
  large_file_share_enabled         = lookup(var.sa_config, "large_file_share_enabled", null)

  tags = lookup(var.sa_config, "tags", null)

  network_rules {
    default_action             = lookup(var.sa_config, "subnet_ids", null) == null ? "Allow" : "Deny"
    virtual_network_subnet_ids = lookup(var.sa_config, "subnet_ids", null)
  }

  dynamic "azure_files_authentication" {
    for_each = lookup(var.sa_config, "ad_auth", false) != false ? ["true"] : []
    content {
      directory_type = "AD"

      active_directory {
        domain_guid         = var.sa_config.ad_auth.domain_guid
        domain_name         = var.sa_config.ad_auth.domain_name
        domain_sid          = var.sa_config.ad_auth.domain_sid
        forest_name         = lookup(var.sa_config.ad_auth, "forest_name", var.sa_config.ad_auth.domain_name)
        netbios_domain_name = lookup(var.sa_config.ad_auth, "netbios_domain_name", var.sa_config.ad_auth.domain_name)
        storage_sid         = var.sa_config.ad_auth.storage_sid
      }
    }
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_storage_share" "share" {
  for_each             = lookup(var.sa_config, "shares", {})
  name                 = lookup(each.value, "name", each.key)
  storage_account_name = azurerm_storage_account.sa.name
  quota                = lookup(each.value, "quota", 1000)
}

resource "azurerm_storage_container" "container" {
  for_each              = lookup(var.sa_config, "containers", {})
  name                  = lookup(each.value, "name", each.key)
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = lookup(each.value, "access", "private")
}

output "primary_blob_endpoint" {
  value = azurerm_storage_account.sa.primary_blob_endpoint
}

output "id" {
  value = azurerm_storage_account.sa.id
}