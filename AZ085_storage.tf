# resource "azurerm_storage_account" "terraform" {
#   name                     = "euwst085pieufilestfstate01"
#   resource_group_name      = azurerm_resource_group.rg["tfstate"].name
#   location                 = azurerm_resource_group.rg["tfstate"].location
#   account_tier             = "Standard"
#   account_replication_type = "GRS"
# }

# resource "azurerm_storage_container" "terraform" {
#   name                  = "terraform"
#   storage_account_name  = azurerm_storage_account.terraform.name
#   container_access_type = "private"
# }


# resource "azurerm_storage_account" "storagepieu01" {
#   name                     = "eeuw-rg-st-085-files-pieu"
#   resource_group_name      = azurerm_resource_group.rg["rgstorage01"].name
#   location                 = azurerm_resource_group.rg["rgstorage01"].location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
# }