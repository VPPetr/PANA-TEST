resource "azurerm_recovery_services_vault" "rsv" {
  name                         = var.rsv_config.name
  location                     = var.rsv_config.location
  resource_group_name          = var.rsv_config.resource_group_name
  sku                          = lookup(var.rsv_config, "sku", "Standard")
  tags                         = lookup(var.rsv_config, "tags", null)
  soft_delete_enabled          = lookup(var.rsv_config, "soft_delete_enabled", true)
  storage_mode_type            = lookup(var.rsv_config, "storage_mode_type", "LocallyRedundant")
  cross_region_restore_enabled = lookup(var.rsv_config, "cross_region_restore", null)

  identity {
    type = "SystemAssigned"
  }
}

locals {
  default_retention = {
    days    = 0
    enabled = false
  }
  default_category = ["AzureBackupReport"]
}
resource "azurerm_monitor_diagnostic_setting" "rsv" {
  for_each                   = try(var.rsv_config.law.enable, null) == null ? {} : { "this" = true }
  name                       = lookup(var.rsv_config.law, "name", "${var.rsv_config.name}-diagnostic-setting")
  target_resource_id         = azurerm_recovery_services_vault.rsv.id
  log_analytics_workspace_id = var.rsv_config.law.id

  dynamic "enabled_log" {
    for_each = try(var.rsv_config.law.log_category, local.default_category)
    content {
      category = enabled_log.value
    }
  }

  metric {
    category = try(var.rsv_config.law.metric.category, "Health")
    enabled  = try(var.rsv_config.law.metric.enabled, true)
  }
}

output "name" {
  value = azurerm_recovery_services_vault.rsv.name
}

output "id" {
  value = azurerm_recovery_services_vault.rsv.id
}

output "managed_id" {
  value = try(azurerm_recovery_services_vault.rsv.identity[0].principal_id, null)
}
