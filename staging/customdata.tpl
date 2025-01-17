#!/bin/bash

# Update package repository
echo "Updating package repository..."
sudo apt update -y

# Install Apache2
echo "Installing Apache2..."
sudo apt install apache2 -y

# Ensure Apache2 service is enabled and started
echo "Starting Apache2 service..."
sudo systemctl enable apache2
sudo systemctl start apache2

# Check if the service is running
echo "Checking Apache2 service status..."
sudo systemctl status apache2

#$VM =${vmname}
# Create a basic index.html file
echo "Creating a basic index.html..."
echo "<html>
<head><title>Welcome to Apache!</title></head>
<body>
<h1>Welcome to Ganesh's Web Server. This is running on ? </h1>
</body>
</html>" | sudo tee /var/www/html/index.html > /dev/null

# Allow Apache through the firewall (if UFW is enabled)
echo "Configuring UFW to allow Apache traffic..."
sudo ufw allow 'Apache Full'

# Restart Apache2 to ensure all settings are applied
echo "Restarting Apache2 service..."
sudo systemctl restart apache2

