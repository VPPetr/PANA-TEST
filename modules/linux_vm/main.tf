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
  disks            = lookup(var.vm_config, "disks", {})
  nics             = lookup(var.vm_config, "nics", {})
  ips              = [for k, v in lookup(local.nics, "ips", {}) : v.ip_address]
  disable_password = lookup(var.vm_config, "password", null) == null ? true : false
  source_sku = lookup(var.vm_config, "image", {
    publisher = "redhat"
    offer     = "rhel-byos"
    sku       = "rhel-lvm84-gen2"
    version   = "latest"
  })
  do_plan = local.source_sku.offer == "rhel-byos" ? true : false
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
      ip_configuration[0].public_ip_address_id,
    ]
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  resource_group_name = var.vm_config.resource_group_name
  location            = var.vm_config.location

  name                            = var.vm_config.name
  computer_name                   = var.vm_config.name
  size                            = var.vm_config.size
  availability_set_id             = lookup(var.vm_config, "availability_set_id", null)
  license_type                    = lookup(var.vm_config, "license_type", null)
  admin_username                  = var.vm_config.username
  admin_password                  = lookup(var.vm_config, "password", null)
  tags                            = lookup(var.vm_config, "tags", null)
  disable_password_authentication = local.disable_password

  network_interface_ids = values(azurerm_network_interface.nic)[*]["id"]

  dynamic "identity" {
    for_each = lookup(var.vm_config, "managed_id", false) ? ["managed_id"] : []
    content {
      type = "SystemAssigned"
    }
  }

  os_disk {
    name                 = var.vm_config.os_disk.name
    caching              = lookup(var.vm_config.os_disk, "caching", "None")
    storage_account_type = var.vm_config.os_disk.storage_type
    disk_size_gb         = lookup(var.vm_config.os_disk, "size", 128)
  }

  dynamic "admin_ssh_key" {
    for_each = local.disable_password == true ? ["ssh"] : []
    content {
      username   = var.vm_config.username
      public_key = lookup(var.vm_config, "ssh_public_key", "")
    }
  }

  boot_diagnostics {
    storage_account_uri = lookup(var.vm_config, "boot_diags_url", null)
  }

  source_image_reference {
    publisher = local.source_sku.publisher
    offer     = local.source_sku.offer
    sku       = local.source_sku.sku
    version   = local.source_sku.version
  }

  plan {
    publisher = local.do_plan == true ? local.source_sku.publisher : null
    product   = local.do_plan == true ? local.source_sku.offer : null
    name      = local.do_plan == true ? local.source_sku.sku : null
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
  virtual_machine_id = azurerm_linux_virtual_machine.vm.id

  lun                       = each.value.lun
  caching                   = lookup(each.value, "caching", "None")
  write_accelerator_enabled = lookup(each.value, "write_accelerator", false)
}

resource "azurerm_backup_protected_vm" "vm" {
  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.md
  ]
  count               = lookup(var.vm_config, "backup", false) != false ? 1 : 0
  resource_group_name = var.vm_config.backup.rg
  recovery_vault_name = var.vm_config.backup.rsv_name
  source_vm_id        = azurerm_linux_virtual_machine.vm.id
  backup_policy_id    = var.vm_config.backup.pol_id
  exclude_disk_luns   = lookup(var.vm_config.backup, "exclude_disk_luns", null)
  include_disk_luns   = lookup(var.vm_config.backup, "include_disk_luns", null)
}

data "azurerm_managed_disk" "os" {
  name                = var.vm_config.os_disk.name
  resource_group_name = var.vm_config.resource_group_name
  depends_on          = [azurerm_linux_virtual_machine.vm]
}

locals {
  alldisks = merge(azurerm_managed_disk.md, {
    "osdisk" = data.azurerm_managed_disk.os
  })
}

resource "azurerm_site_recovery_replicated_vm" "asr" {
  count                                     = lookup(var.vm_config, "asr", false) != false ? 1 : 0
  name                                      = "${azurerm_linux_virtual_machine.vm.name}-asr"
  resource_group_name                       = var.vm_config.asr.asrdetails.rg_name
  recovery_vault_name                       = var.vm_config.asr.asrdetails.rv_name
  source_recovery_fabric_name               = var.vm_config.asr.asrdetails.source_fabric
  source_vm_id                              = azurerm_linux_virtual_machine.vm.id
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
  value = azurerm_linux_virtual_machine.vm.id
}

output "managed_id" {
  value = try(azurerm_linux_virtual_machine.vm.identity[0].principal_id, null)
}

output "replication_id" {
  value = try(azurerm_site_recovery_replicated_vm.asr[0].id, null)
}
