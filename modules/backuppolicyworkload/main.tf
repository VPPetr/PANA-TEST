terraform {
  required_version = ">= 1.3.0"
}

resource "azurerm_backup_policy_vm_workload" "vm-backup-policy" {
  name                = var.vm-workload-backup-policy_config.name
  resource_group_name = var.vm-workload-backup-policy_config.resource_group_name
  recovery_vault_name = var.vm-workload-backup-policy_config.recovery_vault_name
  workload_type       = var.vm-workload-backup-policy_config.workload_type

  settings {
    time_zone            = lookup(var.vm-workload-backup-policy_config, "time_zone", "UTC")
    compression_enabled = lookup(var.vm-workload-backup-policy_config, "compression", false)
  }

  dynamic "protection_policy" {
    for_each = var.vm-workload-backup-policy_config.protection_policy
    content {
      policy_type = protection_policy.value.policy_type

      backup {
        frequency            = lookup(protection_policy.value, "frequency", null)
        frequency_in_minutes = lookup(protection_policy.value, "frequency_in_minutes", null)
        time                 = lookup(protection_policy.value, "time", null)
        weekdays             = lookup(protection_policy.value, "weekdays", null)
      }

      dynamic "retention_daily" {
        for_each = lookup(protection_policy.value, "retention_daily", false) != false ? ["true"] : []
        content {
          count = protection_policy.value.retention_daily.count
        }
      }

      dynamic "retention_weekly" {
        for_each = lookup(protection_policy.value, "retention_weekly", false) != false ? ["true"] : []
        content {
          count    = protection_policy.value.retention_weekly.count
          weekdays = protection_policy.value.retention_weekly.weekdays
        }
      }

      dynamic "retention_monthly" {
        for_each = lookup(protection_policy.value, "retention_monthly", false) != false ? ["true"] : []
        content {
          count       = protection_policy.value.retention_monthly.count
          format_type = protection_policy.value.retention_monthly.format_type
          monthdays   = lookup(protection_policy.value.retention_monthly, "monthdays", null)
          weekdays    = lookup(protection_policy.value.retention_monthly, "weekdays", null)
          weeks       = lookup(protection_policy.value.retention_monthly, "weeks", null)
        }
      }

      dynamic "retention_yearly" {
        for_each = lookup(protection_policy.value, "retention_yearly", false) != false ? ["true"] : []
        content {
          count       = protection_policy.value.retention_yearly.count
          format_type = protection_policy.value.retention_yearly.format_type
          months      = protection_policy.value.retention_yearly.months
          monthdays   = lookup(protection_policy.value.retention_yearly, "monthdays", null)
          weekdays    = lookup(protection_policy.value.retention_yearly, "weekdays", null)
          weeks       = lookup(protection_policy.value.retention_yearly, "weeks", null)
        }
      }

      dynamic "simple_retention" {
        for_each = lookup(protection_policy.value, "simple_retention", false) != false ? ["true"] : []
        content {
          count = protection_policy.value.simple_retention.count
        }
      }
    }
  }
}

output "id" {
  value = azurerm_backup_policy_vm_workload.vm-backup-policy.id
}