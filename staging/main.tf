#Provider block
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.14.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "d142c4c7-733e-4ee6-9bb4-bcbe829e13c2"
}
# All Resources related to web app for staging environment 

resource "azurerm_resource_group" "staging_rg" {
  name     = "${var.name}_Rg"
  location = "East US"
}

# going to use the exisitng azure vnet 
data "azurerm_virtual_network" "vnet" {
  name                = "terraform_vnet"
  resource_group_name = "testRg"
}

resource "azurerm_subnet" "staging_subnet" {
  name                 = "${var.name}_subnet"
  resource_group_name  = azurerm_resource_group.staging_rg.name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  #This staging_subnet will remain in azure portal even if the terraform config is destroyed
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_network_interface" "staging_nic" {
  #this is going to create two Nic for two compute sources
  count               = var.compute_count
  name                = "${var.name}_nic_${count.index + 1}"
  location            = azurerm_resource_group.staging_rg.location
  resource_group_name = azurerm_resource_group.staging_rg.name

  ip_configuration {
    name                          = "nic_config_${count.index + 1}"
    subnet_id                     = azurerm_subnet.staging_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_security_group" "staging_nsg" {
  name                = "${var.name}_nsg"
  location            = azurerm_resource_group.staging_rg.location
  resource_group_name = azurerm_resource_group.staging_rg.name
  #allowing http inbound
  security_rule {
    name                       = "http-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  #allowing http outbound 
  security_rule {
    name                       = "http-Outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}
#associate NSG rules to Staging_subnet

resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.staging_subnet.id
  network_security_group_id = azurerm_network_security_group.staging_nsg.id
}

resource "azurerm_linux_virtual_machine" "staging_vm" {
  #for_each = length(var.vm)
  count =var.compute_count

  name                = "staging_vm_${count.index + 1}"
  resource_group_name = azurerm_resource_group.staging_rg.name
  location            = azurerm_resource_group.staging_rg.location
  size                = "Standard_B1S"
  #need to check if standard_b1s right size
  admin_username = "kaliadmin"
  
  #looks like i had to specify count again wit this resource block
  #count = var.compute_count

  network_interface_ids = [
    azurerm_network_interface.staging_nic[count.index].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}