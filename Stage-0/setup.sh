#!/bin/bash

# Variables
WEB_ROOT="/var/www/website"
CSS="/home/azureuser/website/css"
HTML="/home/azureuser/website/index.html"
JS="/home/azureuser/website/script.js"

# Update package list and install Apache
echo "Updating package list and installing Apache..."
sudo apt update
sudo apt install -y apache2

# Create the root directory for your website
echo "Creating web root directory..."
sudo mkdir -p $WEB_ROOT

# Copy your website files to the web root directory
echo "Copying website files to web root directory..."
sudo cp -r $CSS $WEB_ROOT
sudo cp $HTML $WEB_ROOT
sudo cp $JS $WEB_ROOT

# Set permissions
echo "Setting permissions for web root directory..."
sudo chown -R www-data:www-data $WEB_ROOT
sudo chmod -R 755 $WEB_ROOT

# Configure Apache to use your website as the root
echo "Configuring Apache..."
sudo bash -c "cat > /etc/apache2/sites-available/000-default.conf <<EOL
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot $WEB_ROOT
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL"

# Enable the new configuration and restart Apache
echo "Enabling new configuration and restarting Apache..."
sudo a2ensite 000-default.conf
sudo systemctl restart apache2

echo "Apache installation and configuration complete. Your website should be live."
