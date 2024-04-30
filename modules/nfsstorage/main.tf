terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "> 3"
    }
  }
}

resource "azurerm_storage_account" "nfsstorage" {
  name                      = var.nfs_config.sa_name
  resource_group_name       = var.nfs_config.rg
  location                  = var.nfs_config.location
  account_kind              = "FileStorage"
  account_tier              = "Premium"
  account_replication_type  = lookup(var.nfs_config, "account_replication_type", "ZRS")
  enable_https_traffic_only = false

  tags = lookup(var.nfs_config, "tags", null)

  network_rules {
    default_action             = lookup(var.nfs_config, "default_action", "Deny")
    virtual_network_subnet_ids = lookup(var.nfs_config, "allowed_subnet_ids", [])
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }

}

resource "azurerm_private_endpoint" "nfsstorage" {
  name                = lookup(var.nfs_config, "pep_name", "pep-${var.nfs_config.sa_name}")
  location            = var.nfs_config.location
  resource_group_name = var.nfs_config.rg
  subnet_id           = var.nfs_config.subnet_id

  private_service_connection {
    name                           = var.nfs_config.sa_name
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.nfsstorage.id
    subresource_names              = ["file"]
  }

  ip_configuration {
    name               = "ip-${var.nfs_config.sa_name}"
    private_ip_address = var.nfs_config.ip_address
    subresource_name   = "file"
  }
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_storage_share" "nfsstorage" {
  depends_on = [
    azurerm_private_endpoint.nfsstorage
  ]
  for_each             = var.nfs_config.shares
  name                 = each.key
  storage_account_name = azurerm_storage_account.nfsstorage.name
  quota                = each.value
  enabled_protocol     = "NFS"
}
