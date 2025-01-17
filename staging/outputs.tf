output "virtual_network_id" {
  value = azurerm_virtual_network.staging_vnet.id
}

# to display web app ip 
output "Lb_frontend_ip" {
  value = resource.azurerm_public_ip.staging_lb_pubip.ip_address
}

/*output "ip_address_for_vms" { 
value = 
}
*/