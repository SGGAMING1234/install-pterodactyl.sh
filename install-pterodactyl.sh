#!/bin/bash

Auto Pterodactyl Panel + Wings Installer (IPv4 Only, No Domain)

Tested on Ubuntu 22.04

set -e

--- System Prep ---

echo "[1/8] Updating system..." apt update -y && apt upgrade -y

--- Install dependencies ---

echo "[2/8] Installing dependencies..." apt install -y nginx mariadb-server php8.1 php8.1-{cli,fpm,mysql,curl,mbstring,xml,bcmath,zip} 
curl unzip git redis-server composer docker.io ufw

systemctl enable --now redis mariadb php8.1-fpm docker

--- Secure MariaDB ---

echo "[3/8] Securing MariaDB..." mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'StrongRootPassword123!'; FLUSH PRIVILEGES;"

--- Create Database ---

echo "[4/8] Creating panel database..." mysql -uroot -pStrongRootPassword123! -e "CREATE DATABASE panel; CREATE USER 'ptero'@'127.0.0.1' IDENTIFIED BY 'PteroDBPass!'; GRANT ALL PRIVILEGES ON panel.* TO 'ptero'@'127.0.0.1'; FLUSH PRIVILEGES;"

--- Install Pterodactyl Panel ---

echo "[5/8] Installing Pterodactyl panel..." mkdir -p /var/www/pterodactyl && cd /var/www/pterodactyl curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz tar -xzvf panel.tar.gz composer install --no-dev --optimize-autoloader cp .env.example .env php artisan key:generate

--- Configure .env ---

sed -i "s|APP_URL=.|APP_URL=http://$(curl -s ifconfig.me)|" .env sed -i "s|DB_PASSWORD=.|DB_PASSWORD=PteroDBPass!|" .env php artisan migrate --seed --force chown -R www-data:www-data /var/www/pterodactyl

--- Setup Nginx ---

echo "[6/8] Configuring Nginx..." cat > /etc/nginx/sites-available/pterodactyl <<EOF server { listen 80; server_name $(curl -s ifconfig.me);

root /var/www/pterodactyl/public;
index index.php;

location / {
    try_files \$uri \$uri/ /index.php?\$query_string;
}

location ~ \.php\$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php8.1-fpm.sock;
}

location ~ /\.ht {
    deny all;
}

} EOF

ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/pterodactyl rm /etc/nginx/sites-enabled/default systemctl restart nginx

--- Install Wings ---

echo "[7/8] Installing Wings daemon..." curl -sSL https://get.docker.com/ | bash mkdir -p /etc/pterodactyl /var/lib/pterodactyl curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 chmod +x /usr/local/bin/wings

--- Setup Wings Config ---

echo "[8/8] Configuring Wings..." cat > /etc/systemd/system/wings.service <<EOF [Unit] Description=Pterodactyl Wings Daemon After=docker.service Requires=docker.service

[Service] User=root Restart=on-failure ExecStart=/usr/local/bin/wings

[Install] WantedBy=multi-user.target EOF

systemctl daemon-reexec systemctl enable --now wings

--- Done ---

echo "\nInstallation complete!" echo "Access your panel at: http://$(curl -s ifconfig.me)" echo "Default DB User: ptero | Password: PteroDBPass!" echo "MySQL Root Password: StrongRootPassword123!" echo "Happy hosting!"

