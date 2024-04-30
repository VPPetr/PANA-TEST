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
  disks = lookup(var.vm_config, "disks", {})
  nics  = lookup(var.vm_config, "nics", {})
  ips   = [for k, v in lookup(local.nics, "ips", {}) : v.ip_address]
  source_sku = lookup(var.vm_config, "image", {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  })

}

resource "azurerm_network_interface" "nic" {
  for_each            = local.nics
  resource_group_name = var.vm_config.resource_group_name
  location            = var.vm_config.location
  tags                = lookup(var.vm_config, "tags", null)

  name = each.value.name

  enable_accelerated_networking = lookup(each.value, "accelerated_networking", false)

  dynamic "ip_configuration" {
    for_each = each.value.ips
    content {
      name                          = ip_configuration.value.name
      primary                       = index([for k, v in each.value.ips : v.ip_address], ip_configuration.value.ip_address) == 0 ? true : false
      subnet_id                     = ip_configuration.value.subnet_id
      private_ip_address_allocation = "Static"
      private_ip_address            = ip_configuration.value.ip_address
    }
  }

  lifecycle {
    ignore_changes = [
      tags,
      ip_configuration[0].public_ip_address_id
    ]
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  resource_group_name = var.vm_config.resource_group_name
  location            = var.vm_config.location

  name                     = var.vm_config.name
  size                     = var.vm_config.size
  availability_set_id      = lookup(var.vm_config, "availability_set_id", null)
  license_type             = lookup(var.vm_config, "license_type", "Windows_Server")
  admin_username           = var.vm_config.username
  admin_password           = var.vm_config.password
  tags                     = lookup(var.vm_config, "tags", null)
  patch_mode               = lookup(var.vm_config, "patch_mode", "Manual")
  enable_automatic_updates = lookup(var.vm_config, "patch_mode", "Manual") == "Manual" ? false : true

  network_interface_ids = values(azurerm_network_interface.nic)[*]["id"]

  os_disk {
    name                 = var.vm_config.os_disk.name
    caching              = lookup(var.vm_config.os_disk, "caching", "None")
    storage_account_type = var.vm_config.os_disk.storage_type
    disk_size_gb         = lookup(var.vm_config.os_disk, "size", 128)
  }

  source_image_reference {
    publisher = local.source_sku.publisher
    offer     = local.source_sku.offer
    sku       = local.source_sku.sku
    version   = local.source_sku.version
  }

  zone                         = lookup(var.vm_config, "zone", null)
  proximity_placement_group_id = lookup(var.vm_config, "ppg_id", null)
  lifecycle {
    ignore_changes = [
      admin_password,
      boot_diagnostics,
      tags
    ]
  }

  boot_diagnostics {
    storage_account_uri = lookup(var.vm_config, "boot_diags_url", null)
  }
}

resource "azurerm_managed_disk" "md" {
  for_each            = var.vm_config.disks
  resource_group_name = var.vm_config.resource_group_name
  location            = var.vm_config.location

  name                          = each.key
  storage_account_type          = each.value.storage_account_type
  public_network_access_enabled = lookup(each.value, "public_access", false)
  create_option                 = lookup(each.value, "create_option", "Empty")
  disk_size_gb                  = each.value.disk_size_gb
  tags                          = lookup(var.vm_config, "tags", null)
  zone                          = lookup(var.vm_config, "zone", null)

  lifecycle {
    ignore_changes = [
      tags,
      encryption_settings
    ]
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "md" {
  for_each           = var.vm_config.disks
  managed_disk_id    = azurerm_managed_disk.md[each.key].id
  virtual_machine_id = azurerm_windows_virtual_machine.vm.id

  lun     = each.value.lun
  caching = lookup(each.value, "caching", "None")
}

# }


# extensions
resource "azurerm_virtual_machine_extension" "bitlocker" {
  depends_on = [azurerm_virtual_machine_data_disk_attachment.md]
  for_each   = lookup(var.vm_config, "enc", {})

  name                       = "AzureDiskEncryption"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.Security"
  type                       = "AzureDiskEncryption"
  type_handler_version       = "2.2"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
  {
    "EncryptionOperation": "EnableEncryption",
    "KeyVaultURL": "${each.value.kv_uri}",
    "KeyVaultResourceId": "${each.value.kv_id}",                   
    "KeyEncryptionKeyURL": "${each.value.kek_id}",
    "KekVaultResourceId": "${each.value.kv_id}",                   
    "KeyEncryptionAlgorithm": "${lookup(each.value, "algorithm", "RSA-OAEP")}",
    "VolumeType": "${lookup(each.value, "volume_type", "All")}"
  }
SETTINGS

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}


resource "azurerm_virtual_machine_extension" "bginfo" {
  depends_on = [azurerm_virtual_machine_extension.bitlocker]

  name                       = "BGInfo"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Compute"
  type                       = "BGInfo"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

locals {
  domainjoin = lookup(var.vm_config, "domainjoin", {
    enable    = false
    domain    = ""
    username  = ""
    OU        = ""
    kv_secret = ""
    kv_id     = ""
  })
}

data "azurerm_key_vault_secret" "domjoin" {
  count        = local.domainjoin.enable == true ? 1 : 0
  name         = lookup(local.domainjoin, "kv_secret", "")
  key_vault_id = lookup(local.domainjoin, "kv_id", "")
}

resource "azurerm_virtual_machine_extension" "domainjoin" {
  depends_on = [azurerm_virtual_machine_extension.bginfo]
  count      = local.domainjoin.enable == true ? 1 : 0

  name                       = "${var.vm_config.name}-joindomain"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
  {
    "Name": "${local.domainjoin.domain}",
    "User": "${local.domainjoin.username}",
    "Restart": "true",                   
    "Options": "3",
    "OUPath=": "${local.domainjoin.OU}"                   
  }
SETTINGS

  protected_settings = <<PROT
   {
    "Password": "${data.azurerm_key_vault_secret.domjoin[0].value}"
   }
PROT

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_backup_protected_vm" "vm" {
  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.md
  ]
  count               = lookup(var.vm_config, "backup", false) != false ? 1 : 0
  resource_group_name = var.vm_config.backup.rg
  recovery_vault_name = var.vm_config.backup.rsv_name
  source_vm_id        = azurerm_windows_virtual_machine.vm.id
  backup_policy_id    = var.vm_config.backup.pol_id
  exclude_disk_luns   = lookup(var.vm_config.backup, "exclude_disk_luns", null)
  include_disk_luns   = lookup(var.vm_config.backup, "include_disk_luns", null)
}

data "azurerm_managed_disk" "os" {
  name                = var.vm_config.os_disk.name
  resource_group_name = var.vm_config.resource_group_name
  depends_on          = [azurerm_windows_virtual_machine.vm]
}

data "azurerm_managed_disk" "data" {
  for_each            = var.vm_config.disks
  name                = each.key
  resource_group_name = var.vm_config.resource_group_name
  depends_on          = [azurerm_managed_disk.md]
}

locals {
  alldisks = try(var.vm_config.asr.kek_name, null) == null ? {} : merge(data.azurerm_managed_disk.data, {
    "osdisk" = data.azurerm_managed_disk.os
  })
  enckeyname = {
    for k, v in local.alldisks : k => try(split("/", v.encryption_settings[0].disk_encryption_key[0].secret_url)[4], null)
  }
}

data "azurerm_key_vault_secret" "diskenc" {
  for_each     = { for k, v in local.enckeyname : k => v if v != null }
  name         = each.value
  key_vault_id = var.vm_config.enc.disk.kv_id
  depends_on   = [data.azurerm_managed_disk.os]
}

data "azurerm_key_vault_secret" "diskenc-asr" {
  for_each     = { for k, v in local.enckeyname : k => v if(v != null && try(var.vm_config.asr.key_vault_id, null) != null) }
  name         = each.value
  key_vault_id = try(var.vm_config.asr.key_vault_id, "fail")
  depends_on   = [data.azurerm_managed_disk.os]
}

data "azurerm_key_vault_key" "kek" {
  for_each     = try(var.vm_config.asr.kek_name, null) == null ? {} : { "this" = true }
  name         = var.vm_config.asr.kek_name
  key_vault_id = var.vm_config.asr.key_vault_id
}

resource "azurerm_site_recovery_replicated_vm" "asr" {
  count                                     = lookup(var.vm_config, "asr", false) != false ? 1 : 0
  name                                      = "${azurerm_windows_virtual_machine.vm.name}-asr"
  resource_group_name                       = var.vm_config.asr.asrdetails.rg_name
  recovery_vault_name                       = var.vm_config.asr.asrdetails.rv_name
  source_recovery_fabric_name               = var.vm_config.asr.asrdetails.source_fabric
  source_vm_id                              = azurerm_windows_virtual_machine.vm.id
  recovery_replication_policy_id            = var.vm_config.asr.asrdetails.pol_id
  source_recovery_protection_container_name = var.vm_config.asr.asrdetails.source_container

  target_resource_group_id                = var.vm_config.asr.target_rg_id
  target_recovery_fabric_id               = var.vm_config.asr.asrdetails.target_fabric
  target_recovery_protection_container_id = var.vm_config.asr.asrdetails.target_container
  target_network_id                       = lower(var.vm_config.asr.target_network_id)
  test_network_id                         = var.vm_config.asr.target_network_id

  dynamic "managed_disk" {
    for_each = local.alldisks
    content {
      disk_id                    = managed_disk.value.id
      staging_storage_account_id = var.vm_config.asr.staging_sa_id
      target_resource_group_id   = var.vm_config.asr.target_rg_id
      target_disk_type           = managed_disk.value.storage_account_type
      target_replica_disk_type   = managed_disk.value.storage_account_type

      dynamic "target_disk_encryption" {
        for_each = try(managed_disk.value.encryption_settings[0].disk_encryption_key[0].secret_url, null) != null ? { "this" = true } : {}
        content {
          disk_encryption_key {
            secret_url = data.azurerm_key_vault_secret.diskenc-asr[managed_disk.key].id
            vault_id   = try(var.vm_config.asr.key_vault_id, "fail")
          }

          key_encryption_key {
            key_url  = data.azurerm_key_vault_key.kek["this"].id
            vault_id = try(var.vm_config.asr.key_vault_id, "fail")
          }
        }
      }
    }
  }

  dynamic "network_interface" {
    for_each = azurerm_network_interface.nic
    content {
      source_network_interface_id = network_interface.value.id
      target_subnet_name          = var.vm_config.asr.target_subnet
      target_static_ip            = var.vm_config.asr.target_ip
      failover_test_subnet_name   = var.vm_config.asr.target_subnet
      failover_test_static_ip     = var.vm_config.asr.target_ip
    }
  }
}

output "network_interfaces" {
  value = azurerm_network_interface.nic
}

output "id" {
  value = azurerm_windows_virtual_machine.vm.id
}

output "replication_id" {
  value = try(azurerm_site_recovery_replicated_vm.asr[0].id, null)
}
