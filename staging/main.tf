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

# going to use the exisitng azure vnet  ---This errored for resources creation like subnet , DNS Zone 
/*data "azurerm_virtual_network" "vnet" {
  name                = "terraform_vnet"
  resource_group_name = "testRg"
}
*/
resource "azurerm_virtual_network" "staging_vnet" {
  name                = "${var.name}_vnet"
  location            = azurerm_resource_group.staging_rg.location
  resource_group_name = azurerm_resource_group.staging_rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "staging_subnet" {
  name                 = "${var.name}_subnet"
  resource_group_name  = azurerm_resource_group.staging_rg.name
  virtual_network_name = azurerm_virtual_network.staging_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  #This staging_subnet will remain in azure portal even if the terraform config is destroyed
 /* lifecycle {
    prevent_destroy = true
  }*/
}
#testing public ip
/*resource "azurerm_public_ip" "test_pubip" {
  count               = var.compute_count
  name                = "${var.name}_pubip${count.index + 1}"
  resource_group_name = azurerm_resource_group.staging_rg.name
  location            = azurerm_resource_group.staging_rg.location
  allocation_method   = "Static"
} */

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
  # to be deleted after testing
  security_rule{
  name                        = "ssh-inbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  # if all inbounds are open , I can reach the apache server! 
}

}

#associate NSG rules to Staging_subnet

resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.staging_subnet.id
  network_security_group_id = azurerm_network_security_group.staging_nsg.id
}

# associate nsg to nics
resource "azurerm_network_interface_security_group_association" "nic_nsg_association" {
  count = var.compute_count
  network_interface_id      = azurerm_network_interface.staging_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.staging_nsg.id
}
resource "azurerm_linux_virtual_machine" "staging_vm" {
  #for_each = length(var.vm)
  count = var.compute_count

  name                = "stagingvm${count.index + 1}"
  resource_group_name = azurerm_resource_group.staging_rg.name
  location            = azurerm_resource_group.staging_rg.location
  size                = "Standard_B1s"
  #need to check if standard_b1s right size
  admin_username = "kaliadmin"

  #looks like i had to specify count again wit this resource block
  #count = var.compute_count

  network_interface_ids = [
    azurerm_network_interface.staging_nic[count.index].id,
  ]

  admin_ssh_key {
    username   = "kaliadmin"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # below is script to install, start apache2 
  custom_data = filebase64("customdata.tpl")

  # provisioner to send the name of virtual machine to customdata script 
  # idea is on LBalancing, i want to know which vm is the request being sent to 
  /*provisioner "local-exec" {
    command = templatefile("customdata.tpl", {
      vmname = self.name
    })
  } */

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

#Simple Storage account and added random characters for namemanually as it should be globally unique
resource "azurerm_storage_account" "staging_storage" {
  name                     = "${var.name}storagekjadh"
  resource_group_name      = azurerm_resource_group.staging_rg.name
  location                 = azurerm_resource_group.staging_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Creating a public ip for public facing Load Balancer 

resource "azurerm_public_ip" "staging_lb_pubip" {
  name                = "${var.name}_lb_pubip"
  resource_group_name = azurerm_resource_group.staging_rg.name
  location            = azurerm_resource_group.staging_rg.location
  allocation_method   = "Static"
}

# loadbalancer resouce block and assigning public ip to lb
resource "azurerm_lb" "staging_lb" {
  name                = "${var.name}_lb"
  resource_group_name = azurerm_resource_group.staging_rg.name
  location            = azurerm_resource_group.staging_rg.location
  #sku                 = "Basic"
  #basic sku had error referencing public ip so commented it

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.staging_lb_pubip.id
  }
}
# Giving a name for LB back end
resource "azurerm_lb_backend_address_pool" "staging_lb_backend_address_pool" {
  loadbalancer_id = azurerm_lb.staging_lb.id
  name            = "BackEnd_Pool_name"
}

# Two NIC are being added as Backend address of LB backend
resource "azurerm_lb_backend_address_pool_address" "staging_lb_backend_address_pool_address" {
  count = var.compute_count
  #Instead of a giving a random name, i've assigned NIC name so its easy to relate
  name                    = azurerm_network_interface.staging_nic[count.index].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.staging_lb_backend_address_pool.id
  # Basic SKU LB can't be assigned ip address directly ***
  ip_address         = azurerm_network_interface.staging_nic[count.index].private_ip_address
  virtual_network_id = azurerm_virtual_network.staging_vnet.id
}

# LB Inbound rule 
resource "azurerm_lb_rule" "lb_rule1" {
  loadbalancer_id                = azurerm_lb.staging_lb.id
  name                           = "http-inbound"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.staging_lb_backend_address_pool.id]
  probe_id                       = azurerm_lb_probe.http_heath_probe.id
  # hardcoded front end ip name of lb instead of referencing it!!!
}
resource "azurerm_lb_probe" "http_heath_probe" {
  loadbalancer_id = azurerm_lb.staging_lb.id
  name            = "http-probe"
  port            = 80
}
# DNS zone - using data block to access DNS

resource "azurerm_dns_zone" "dns_zone" {
  name                = "ganeshsaravanan.online"
  resource_group_name = azurerm_resource_group.staging_rg.name
}
#adding 'A record' for dns zone and referencing public ip of Load bal
resource "azurerm_dns_a_record" "www" {
  name                = "www"
  zone_name           = azurerm_dns_zone.dns_zone.name
  resource_group_name = azurerm_resource_group.staging_rg.name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.staging_lb_pubip.id
}