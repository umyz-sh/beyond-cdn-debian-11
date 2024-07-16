#!/bin/bash

# Root yetkileriyle betiği çalıştırmak için kontrol
if [ "$EUID" -ne 0 ]; then
  echo "Lütfen betiği root olarak çalıştırın."
  exit
fi

# Renkler ve UI fonksiyonları
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[*] $1${NC}"
}

print_error() {
    echo -e "${RED}[!] $1${NC}"
}

# Kurulum aşamaları
STEPS=("Nginx Kurulumu" "Nginx Yapılandırması" "HTML Dosyası Oluşturma" "vDDoS Kurulumu" "Yapılandırma ve Başlatma")
CURRENT_STEP=0

print_progress() {
    clear
    echo "Beyond:V FastDL Kurulum Asistanı"
    echo "--------------------------------"
    for i in "${!STEPS[@]}"; do
        if [ $i -lt $CURRENT_STEP ]; then
            echo -e "${GREEN}[✓] ${STEPS[$i]}${NC}"
        elif [ $i -eq $CURRENT_STEP ]; then
            echo -e "${GREEN}[*] ${STEPS[$i]}${NC}"
        else
            echo "[ ] ${STEPS[$i]}"
        fi
    done
    echo "--------------------------------"
}

# Nginx kurulumu
print_progress
CURRENT_STEP=0
apt-get update > /dev/null 2>&1
apt-get install -y nginx > /dev/null 2>&1

# Nginx'i başlatma ve sistem başlatıldığında çalışmasını sağlama
systemctl start nginx > /dev/null 2>&1
systemctl enable nginx > /dev/null 2>&1

# Nginx yapılandırma dosyasını düzenleme
CURRENT_STEP=1
print_progress
cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 8080 default_server;
    listen [::]:8080 default_server;
    server_name _;

    root /var/www/html;
    index index.html;
    access_log /var/log/nginx/example_access.log;
    error_log /var/log/nginx/example_error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Nginx yeniden başlatma
systemctl restart nginx > /dev/null 2>&1

# HTML dosyasını oluşturma
CURRENT_STEP=2
print_progress
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Erişim Reddedildi</title>
</head>
<body>
    <script>
        const response = {
            "status": "error",
            "message": "Erişim reddedildi"
        };
        document.write(JSON.stringify(response, null, 2));
    </script>
</body>
</html>
EOF

# İzinleri ayarlama
chown -R www-data:www-data /var/www/html > /dev/null 2>&1

# vDDoS Proxy Protection kurulumu
CURRENT_STEP=3
print_progress
latest_version=2.3.3
wget https://files.voduy.com/vDDoS-Proxy-Protection/vddos-$latest_version.tar.gz > /dev/null 2>&1
tar xvf vddos-$latest_version.tar.gz > /dev/null 2>&1
cd vddos-$latest_version
chmod 700 *.sh > /dev/null 2>&1
./install.sh <<EOF > /dev/null 2>&1
1
EOF

# website.conf dosyasını düzenleme
CURRENT_STEP=4
print_progress
cat <<EOF > /vddos/conf.d/website.conf
default         http://0.0.0.0:80    http://0.0.0.0:8080    no    200      no           no
default         https://0.0.0.0:443  https://0.0.0.0:8443   no    200      /vddos/ssl/your-domain.com.pri /vddos/ssl/your-domain.com.crt
EOF

# vDDoS'u başlatma
/vddos/vddos start > /dev/null 2>&1

# Crontab'a vDDoS başlatma görevi ekleme
(crontab -l 2>/dev/null; echo "@reboot /vddos/vddos start") | crontab -

print_progress
echo ""
print_status "Kurulum tamamlandı. Nginx 8080 portunda çalışıyor ve HTML sayfası oluşturuldu."
print_status "vDDoS Proxy Protection başlatıldı ve sunucu yeniden başlatıldığında otomatik olarak çalışacak."
