terraform {
  required_version = ">= 1.3.0"
}

resource "azurerm_backup_policy_vm" "vm-backup-policy" {
  name                           = var.vm-backup-policy_config.name
  resource_group_name            = var.vm-backup-policy_config.resource_group_name
  recovery_vault_name            = var.vm-backup-policy_config.recovery_vault_name
  timezone                       = lookup(var.vm-backup-policy_config, "timezone", "UTC")
  instant_restore_retention_days = lookup(var.vm-backup-policy_config, "instant_restore", "2")
  policy_type                    = try(var.vm-backup-policy_config.policy_type, null)

  backup {
    frequency     = var.vm-backup-policy_config.backup.frequency
    time          = var.vm-backup-policy_config.backup.time
    hour_interval = lookup(var.vm-backup-policy_config.backup, "hour_interval", null)
    hour_duration = lookup(var.vm-backup-policy_config.backup, "hour_duration", null)
    weekdays      = lookup(var.vm-backup-policy_config.backup, "weekdays", null)
  }

  dynamic "retention_daily" {
    for_each = lookup(var.vm-backup-policy_config, "retention_daily", false) != false ? ["true"] : []
    content {
      count = lookup(var.vm-backup-policy_config.retention_daily, "count", "7")
    }
  }

  dynamic "retention_weekly" {
    for_each = lookup(var.vm-backup-policy_config, "retention_weekly", false) != false ? ["true"] : []
    content {
      count    = var.vm-backup-policy_config.retention_weekly.count
      weekdays = var.vm-backup-policy_config.retention_weekly.weekdays
    }
  }

  dynamic "retention_monthly" {
    for_each = lookup(var.vm-backup-policy_config, "retention_monthly", false) != false ? ["true"] : []
    content {
      count    = var.vm-backup-policy_config.retention_monthly.count
      weekdays = var.vm-backup-policy_config.retention_monthly.weekdays
      weeks    = var.vm-backup-policy_config.retention_monthly.weeks
    }
  }

  dynamic "retention_yearly" {
    for_each = lookup(var.vm-backup-policy_config, "retention_yearly", false) != false ? ["true"] : []
    content {
      count    = var.vm-backup-policy_config.retention_yearly.count
      weekdays = var.vm-backup-policy_config.retention_yearly.weekdays
      weeks    = var.vm-backup-policy_config.retention_yearly.weeks
      months   = var.vm-backup-policy_config.retention_yearly.months
    }
  }
}

output "id" {
  value = azurerm_backup_policy_vm.vm-backup-policy.id
}