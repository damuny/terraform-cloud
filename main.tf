# ******************************************************************************************************
#  Main Terraform file  /   terraform-on-azure-services            /           by Daniel M.
#  v1.1
#  Create and destroy some Azure resources 
# ******************************************************************************************************

# ------------------------------------------------------------------------ local variables declaration 
locals {
  resource_group_name = "rg-infra-01"
  location            = "North Europe"
  virtual_network = {
    name          = "vnet-infra-01"
    address_space = "10.0.0.0/16"
  }
  subnets = [
    {
      name           = "subnetA"
      address_prefix = "10.0.0.0/24"
    },
    {
      name           = "subnetB"
      address_prefix = "10.0.1.0/24"

    }
  ]
  nic_name      = "nic-infra-001"
  nic2_name     = "nic-infra-002"
  ip_name       = "ip-infra-001"
  pip_name      = "pip-infra-001"
  nsg_name      = "nsg-infra-001"
  vm_name       = "vm-infra-001"
  vm_size       = "Standard_Ds1_v2"
  vm_admin_user = "adminuser"
  vm_admin_pass = "Azure@123"
}

# ------------------------------------------------------------------------  create a RG  
resource "azurerm_resource_group" "app_rg" {
  name     = local.resource_group_name
  location = local.location
  lifecycle {
    ignore_changes = [tags]
  }
}

# ------------------------------------------------------------------------  create a storage   
resource "azurerm_storage_account" "app_storage" {
  name                     = "sainfraneu001"
  resource_group_name      = local.resource_group_name
  location                 = azurerm_resource_group.app_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  depends_on               = [azurerm_resource_group.app_rg]
  lifecycle {
    ignore_changes = [tags]
  }
}

# ------------------------------------------------------------------------  create a container in storage 
resource "azurerm_storage_container" "app_stcontainer" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.app_storage.name
  container_access_type = "blob"
  depends_on            = [azurerm_storage_account.app_storage]
}

# ------------------------------------------------------------------------ upload a file as blob in storage 
resource "azurerm_storage_blob" "app_blobfile" {
  name                   = "main.tf"
  storage_account_name   = azurerm_storage_account.app_storage.name
  storage_container_name = azurerm_storage_container.app_stcontainer.name
  type                   = "Block"
  source                 = "main.tf"
  depends_on             = [azurerm_storage_container.app_stcontainer]
}

# ------------------------------------------------------------------------  create a vNET + subNets 
resource "azurerm_virtual_network" "app_vnet" {
  name                = local.virtual_network.name
  location            = local.location
  resource_group_name = local.resource_group_name
  address_space       = [local.virtual_network.address_space]
  depends_on          = [azurerm_resource_group.app_rg]
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_subnet" "subnetA" {
  name                 = local.subnets[0].name
  resource_group_name  = local.resource_group_name
  virtual_network_name = local.virtual_network.name
  address_prefixes     = [local.subnets[0].address_prefix]
  depends_on           = [azurerm_virtual_network.app_vnet]
}

resource "azurerm_subnet" "subnetB" {
  name                 = local.subnets[1].name
  resource_group_name  = local.resource_group_name
  virtual_network_name = local.virtual_network.name
  address_prefixes     = [local.subnets[1].address_prefix]
  depends_on           = [azurerm_virtual_network.app_vnet]
}

# ------------------------------------------------------------------------  create NIC
resource "azurerm_network_interface" "app_interface" {
  name                = local.nic_name
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = local.ip_name
    subnet_id                     = azurerm_subnet.subnetA.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app_ip.id
  }
  depends_on = [azurerm_virtual_network.app_vnet]
  lifecycle {
    ignore_changes = [tags]
  }
}
# ------------------------------------------------------------------------  create NIC2

resource "azurerm_network_interface" "app_interface_2" {
  name                = local.nic2_name
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnetA.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [azurerm_virtual_network.app_vnet]
  lifecycle {
    ignore_changes = [tags]
  }
}

# ------------------------------------------------------------------------  create PUBLIC IP
resource "azurerm_public_ip" "app_ip" {
  name                = local.pip_name
  domain_name_label   = "pip-infra-vm001"
  resource_group_name = local.resource_group_name
  location            = local.location
  allocation_method   = "Static"
  depends_on          = [azurerm_resource_group.app_rg]
  lifecycle {
    ignore_changes = [tags]
  }
}

# ------------------------------------------------------------------------  create NSG 
resource "azurerm_network_security_group" "app_nsg" {
  name                = local.nsg_name
  location            = local.location
  resource_group_name = local.resource_group_name

  security_rule {
    name                       = "AllowRDP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [
    azurerm_resource_group.app_rg
  ]
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_subnet_network_security_group_association" "app_nsglink" {
  subnet_id                 = azurerm_subnet.subnetA.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

# ------------------------------------------------------------------------  Create VM
resource "azurerm_windows_virtual_machine" "app_vm" {
  name                = local.vm_name
  resource_group_name = local.resource_group_name
  location            = local.location
  size                = local.vm_size
  admin_username      = local.vm_admin_user
  admin_password      = local.vm_admin_pass
  network_interface_ids = [
    azurerm_network_interface.app_interface.id,
    azurerm_network_interface.app_interface_2.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  depends_on = [
    azurerm_network_interface.app_interface,
    azurerm_network_interface.app_interface_2,
    azurerm_resource_group.app_rg
  ]
  lifecycle {
    ignore_changes = [tags]
  }
}

# ------------------------------------------------------------------------  Create disk
resource "azurerm_managed_disk" "app_disk" {
  name                 = "disk-infra-001"
  location             = local.location
  resource_group_name  = local.resource_group_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "16"
  depends_on = [
    azurerm_resource_group.app_rg
  ]
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "app-disk-attach" {
  managed_disk_id    = azurerm_managed_disk.app_disk.id
  virtual_machine_id = azurerm_windows_virtual_machine.app_vm.id
  lun                = "0"
  caching            = "ReadWrite"
  depends_on         = [azurerm_managed_disk.app_disk]
}