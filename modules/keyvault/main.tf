terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "> 3"
    }
  }
}

locals {
  keys = lookup(var.kv_config, "keys", {})
}

resource "azurerm_key_vault" "kv" {
  name                        = var.kv_config.name
  location                    = var.kv_config.location
  resource_group_name         = var.kv_config.resource_group_name
  enabled_for_disk_encryption = lookup(var.kv_config, "disk_encryption", false)
  tenant_id                   = var.kv_config.tenant_id
  sku_name                    = lookup(var.kv_config, "sku_name", "premium")
  soft_delete_retention_days  = 7

  dynamic "access_policy" {
    for_each = var.kv_config.access_policy
    content {
      tenant_id           = var.kv_config.tenant_id
      object_id           = access_policy.value.object_id
      key_permissions     = lookup(access_policy.value, "key_permissions", [])
      secret_permissions  = lookup(access_policy.value, "secret_permissions", [])
      storage_permissions = lookup(access_policy.value, "storage_permissions", [])
    }
  }
  lifecycle {
    ignore_changes = [
      tags
    ]
  }

}

resource "azurerm_key_vault_key" "key" {
  for_each     = local.keys == null ? {} : local.keys
  name         = each.key
  key_vault_id = azurerm_key_vault.kv.id
  key_type     = lookup(each.value, "key_type", "RSA")
  key_size     = lookup(each.value, "key_size", 4096)

  key_opts = lookup(each.value, "key_opts", [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey"
  ])
}

output "kv" {
  value = {
    id  = azurerm_key_vault.kv.id
    uri = azurerm_key_vault.kv.vault_uri
  }
}

output "kek" {
  value = {
    for k, v in azurerm_key_vault_key.key : k => {
      id                      = v.id
      resource_id             = v.resource_id
      resource_versionless_id = v.resource_versionless_id
    }
  }
}
