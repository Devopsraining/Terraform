# Specify the provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
}

provider "azurerm" {
    features {
      resource_group {
        prevent_deletion_if_contains_resources = false
      }
  }

  subscription_id = "eb2d5feb-eda9-434b-aa4a-5dc00952aafa"
  client_id       = "ab270fc4-2472-4e55-922c-9cfe11cfea54"
  client_secret   = "qzH8Q~zF6~Bpo275lu6AGZXnZG2pC-3FyBXuQb3Y"
  tenant_id       = "b834bb77-834b-427e-b30c-5ff48a2731ab"
}

# Define resource group
resource "azurerm_resource_group" "venkydemorg" {
  name     = "venkydemo-resource-group"
  location = "UK South"
}

# Define virtual network
resource "azurerm_virtual_network" "venkydemonw" {
  name                = "venky-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.venkydemorg.location
  resource_group_name = azurerm_resource_group.venkydemorg.name
}

# Define subnet
resource "azurerm_subnet" "venkydemosn" {
  name                 = "venkydemosn-subnet"
  resource_group_name  = azurerm_resource_group.venkydemorg.name
  virtual_network_name = azurerm_virtual_network.venkydemonw.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Define network interface
resource "azurerm_network_interface" "venkydemoni" {
  name                = "venkydemoni-nic"
  location            = azurerm_resource_group.venkydemorg.location
  resource_group_name = azurerm_resource_group.venkydemorg.name

  ip_configuration {
    name                          = "venkydemo-ip-config"
    subnet_id                     = azurerm_subnet.venkydemosn.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_public_ip" "venkydemoPIP" {
  name                = "venkydemo-pip"
  resource_group_name = azurerm_resource_group.venkydemorg.name
  location            = azurerm_resource_group.venkydemorg.location
  allocation_method   = "Static"

  tags = {
    environment = "Dev"
  }
}

# Managed Disk
resource "azurerm_managed_disk" "Demovm_disk" {
  name                 = "Demo-disk"
  resource_group_name  = azurerm_resource_group.venkydemorg.name
  location             = azurerm_resource_group.venkydemorg.location
  storage_account_type = "Standard_LRS"
  disk_size_gb         = 10
  create_option        = "Empty"
}

# Disable Security Center Standard Tier
resource "azurerm_security_center_subscription_pricing" "SecurityCenter" {
  tier          = "Free" # JIT is part of the Standard tier; set to "Free" to disable
  resource_type = "VirtualMachines"
}

# Network Security Group
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "vm-nsg"
  location            = azurerm_resource_group.venkydemorg.location
  resource_group_name = azurerm_resource_group.venkydemorg.name

  security_rule {
    name                       = "allow_ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "tls_private_key" "venkyrsa" {
  algorithm = "RSA"
  rsa_bits = 4096
}

# Define virtual machine
resource "azurerm_linux_virtual_machine" "venkydemovm" {
  name                = "venkydemovm-vm"
  location            = azurerm_resource_group.venkydemorg.location
  resource_group_name = azurerm_resource_group.venkydemorg.name
  size                = "Standard_B1s"
  admin_username      = "venkat"

  # Use a secure SSH key
  admin_ssh_key {
    username   = "venkat"
    public_key = tls_private_key.venkyrsa.public_key_openssh
  }

  network_interface_ids = [
    azurerm_network_interface.venkydemoni.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.boot_diag_Demovm-vm_sa.primary_blob_endpoint
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

# Data Disk Attachment
resource "azurerm_virtual_machine_data_disk_attachment" "Demovm_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.Demovm_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.venkydemovm.id
  lun                = 0 # Logical Unit Number
  caching            = "ReadWrite"
}

# enable boot diag for vm
resource "azurerm_storage_account" "boot_diag_Demovm-vm_sa" {
  name = "venkydemovmdiag" # Must be globally unique
  resource_group_name      = azurerm_resource_group.venkydemorg.name
  location                 = azurerm_resource_group.venkydemorg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Output the public IP of the VM
output "public_ip" {
  value = azurerm_linux_virtual_machine.venkydemovm.public_ip_address
}

# Storage Account
resource "azurerm_storage_account" "venkydemo-bucket-sa" {
  name                     = "venkystorageacct" # Must be globally unique
  resource_group_name      = azurerm_resource_group.venkydemorg.name
  location                 = azurerm_resource_group.venkydemorg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "aksdemo"
  }
}

# Storage Container (Bucket)
resource "azurerm_storage_container" "venkydemo-bucket" {
  name                  = "venkydemo-bucket-container"
  storage_account_id  = azurerm_storage_account.venkydemo-bucket-sa.id
  container_access_type = "private" # Options: private, blob, or container
}