terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "lamp-rg" {
  name     = "Laravel-Mini-Project"
  location = "East US"
  tags = {
    environment = "test"
  }
}

resource "azurerm_virtual_network" "lamp-vn" {
  name                = "lamp-network"
  resource_group_name = azurerm_resource_group.lamp-rg.name
  location            = azurerm_resource_group.lamp-rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "test"
  }
}

resource "azurerm_subnet" "lamp-sn" {
  name                 = "lamp-subnet"
  resource_group_name  = azurerm_resource_group.lamp-rg.name
  virtual_network_name = azurerm_virtual_network.lamp-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "jump-nsg" {
  name                = "jump-nsg"
  location            = azurerm_resource_group.lamp-rg.location
  resource_group_name = azurerm_resource_group.lamp-rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DisallowHTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "lamp-nsg" {
  name                = "lamp-nsg"
  location            = azurerm_resource_group.lamp-rg.location
  resource_group_name = azurerm_resource_group.lamp-rg.name

  security_rule {
    name                       = "AllowSSHFromJump"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.123.0.0/16" 
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "jump_nic" {
  name                = "jump-vm-nic"
  location            = azurerm_resource_group.lamp-rg.location
  resource_group_name = azurerm_resource_group.lamp-rg.name

  ip_configuration {
    name                          = "jump-vm-nic-ip"
    subnet_id                     = azurerm_subnet.lamp-sn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jump_ip.id
  }

  tags = {
    environment = "test"
  }
}

resource "azurerm_public_ip" "jump_ip" {
  name                = "jump-public-ip"
  location            = azurerm_resource_group.lamp-rg.location
  resource_group_name = azurerm_resource_group.lamp-rg.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "test"
  }
}

resource "azurerm_linux_virtual_machine" "jump_vm" {
  name                = "jump-vm"
  location            = azurerm_resource_group.lamp-rg.location
  resource_group_name = azurerm_resource_group.lamp-rg.name
  size                = "Standard_B1s"
  admin_username      = "jumpuser"

  admin_ssh_key {
    username   = "jumpuser"
    public_key = file("~/.ssh/lampazurekey.pub")
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

  network_interface_ids = [azurerm_network_interface.jump_nic.id]

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "jumpuser",
      IdentityFile = "~/.ssh/lampazurekey",
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }

  tags = {
    environment = "test"
  }
}

resource "azurerm_public_ip" "lamp-ip" {
  name                = "lamp-public-ip"
  resource_group_name = azurerm_resource_group.lamp-rg.name
  location            = azurerm_resource_group.lamp-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "test"
  }
}

resource "azurerm_network_interface" "lamp-nic" {
  name                = "lamp-network-interface"
  location            = azurerm_resource_group.lamp-rg.location
  resource_group_name = azurerm_resource_group.lamp-rg.name

  ip_configuration {
    name                          = "lamp-nic-ip"
    subnet_id                     = azurerm_subnet.lamp-sn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lamp-ip.id
  }

  tags = {
    environment = "test"
  }
}

resource "azurerm_linux_virtual_machine" "lamp-vm" {
  name                = "lamp-virtual-machine"
  resource_group_name = azurerm_resource_group.lamp-rg.name
  location            = azurerm_resource_group.lamp-rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.lamp-nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/lampazurekey.pub")
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

  tags = {
    environment = "test"
  }
}

resource "azurerm_network_interface_security_group_association" "jump_nic_sg_assoc" {
  network_interface_id      = azurerm_network_interface.jump_nic.id
  network_security_group_id = azurerm_network_security_group.jump-nsg.id
}

resource "azurerm_network_interface_security_group_association" "lamp_nic_sg_assoc" {
  network_interface_id      = azurerm_network_interface.lamp-nic.id
  network_security_group_id = azurerm_network_security_group.lamp-nsg.id
}

data "azurerm_public_ip" "lamp-ip-data" {
  name                = azurerm_public_ip.lamp-ip.name
  resource_group_name = azurerm_resource_group.lamp-rg.name
}

output "public-ip-address" {
  value = "${azurerm_linux_virtual_machine.lamp-vm.name}: ${data.azurerm_public_ip.lamp-ip-data.ip_address}"
}
