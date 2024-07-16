#!/bin/bash

# Root yetkileriyle betiği çalıştırmak için kontrol
if [ "$EUID" -ne 0 ]; then
  echo "Lütfen betiği root olarak çalıştırın."
  exit
fi

# Nginx ve PHP kurulumu
echo "Nginx ve PHP kurulumu başlıyor..."
apt-get update
apt-get install -y nginx php php-fpm php-curl php-cli php-zip php-mysql php-xml

# Nginx'i başlatma ve sistem başlatıldığında çalışmasını sağlama
echo "Nginx başlatılıyor ve sistem başlatıldığında otomatik başlatılacak şekilde ayarlanıyor..."
systemctl start nginx
systemctl enable nginx

# Nginx yapılandırma dosyasını düzenleme
echo "Nginx yapılandırma dosyası düzenleniyor..."
cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 8080 default_server;
    listen [::]:8080 default_server;
    server_name _;

    root /var/www/html;
    index index.php index.html index.nginx-debian.html;
    access_log /var/log/nginx/example_access.log;
    error_log /var/log/nginx/example_error.log;

    location / {
        try_files \$uri \$uri/ /index.php\$is_args\$args;
    }

    location ~ \.php\$ {
        try_files \$uri =404;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF

# Nginx yeniden başlatma
echo "Nginx yeniden başlatılıyor..."
systemctl restart nginx

# PHP dosyasını oluşturma
echo "PHP dosyası oluşturuluyor..."
cat <<'EOF' > /var/www/html/index.php
<?php
if(isset($_GET['get_data'])) {
    header('Content-Type: application/json');

    function getNginxStatus() {
        $output = shell_exec('systemctl is-active nginx 2>&1');
        return trim($output) === 'active' ? 'running' : 'stopped';
    }

    function getNginxConnections() {
        $output = shell_exec('ss -ant | grep :80 | wc -l');
        return intval(trim($output));
    }

    function getUptime() {
        $uptime = shell_exec('uptime -p');
        return trim($uptime);
    }

    $data = [
        'nginx_status' => getNginxStatus(),
        'nginx_connections' => getNginxConnections(),
        'uptime' => getUptime(),
        'current_time' => date('H:i:s')
    ];

    echo json_encode($data);
    exit;
}
?>

<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Beyond:V - FastDL Service Terminal</title>
    <style>
        body, html {
            margin: 0;
            padding: 0;
            height: 100%;
            background-color: #1e1e1e;
            display: flex;
            justify-content: center;
            align-items: center;
            font-family: 'Courier New', monospace;
        }
        #terminal {
            width: 800px;
            height: 500px;
            background-color: #2d2d2d;
            border: 1px solid #444;
            border-radius: 10px;
            color: #d4d4d4;
            padding: 20px;
            overflow-y: auto;
            box-shadow: 0 0 20px rgba(0,0,0,0.3);
        }
        .prompt::before {
            content: "beyond@fastdl:~$ ";
            color: #569cd6;
        }
        .output {
            color: #b5cea8;
        }
        .header {
            color: #ce9178;
            font-weight: bold;
            margin-bottom: 20px;
        }
        .cursor {
            background-color: #d4d4d4;
            animation: blink 1s step-end infinite;
        }
        @keyframes blink {
            50% { opacity: 0; }
        }
    </style>
</head>
<body>
    <div id="terminal">
        <p class="header">Beyond:V - FastDL Service Terminal</p>
        <p class="prompt">echo "Welcome to Beyond:V FastDL Service"</p>
        <p class="output">Welcome to Beyond:V FastDL Service</p>
        <p class="prompt">service nginx status</p>
        <p id="nginx-status" class="output"></p>
        <p class="prompt">beyond-fastdl --connections</p>
        <p id="nginx-connections" class="output"></p>
        <p class="prompt">beyond-fastdl --uptime</p>
        <p id="uptime-info" class="output"></p>
        <p class="prompt">date</p>
        <p id="current-time" class="output"></p>
        <p class="prompt">beyond-fastdl --version</p>
        <p class="output">Beyond:V FastDL Service v1.2.3</p>
        <p class="prompt"><span class="cursor">&nbsp;</span></p>
    </div>

    <script>
        function updateTerminal() {
            fetch('index.php?get_data=1')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('nginx-status').textContent = `[*] nginx is ${data.nginx_status}`;
                    document.getElementById('nginx-connections').textContent = `[*] Active FastDL connections: ${data.nginx_connections}`;
                    document.getElementById('uptime-info').textContent = `[*] Server uptime: ${data.uptime}`;
                    document.getElementById('current-time').textContent = `[*] Current time: ${data.current_time}`;
                })
                .catch(error => console.error('Error:', error));
        }

        updateTerminal();
        setInterval(updateTerminal, 5000);
    </script>
</body>
</html>
EOF

# İzinleri ayarlama
echo "PHP dosyası için izinler ayarlanıyor..."
chown -R www-data:www-data /var/www/html

# vDDoS Proxy Protection kurulumu
latest_version=2.3.3
echo "vDDoS Proxy Protection $latest_version sürümü indiriliyor..."
wget https://files.voduy.com/vDDoS-Proxy-Protection/vddos-$latest_version.tar.gz
tar xvf vddos-$latest_version.tar.gz
cd vddos-$latest_version
chmod 700 *.sh
echo "vDDoS Proxy Protection kurulumu başlatılıyor..."
./install.sh <<EOF
1
EOF

# website.conf dosyasını düzenleme
echo "vDDoS Proxy Protection yapılandırma dosyası düzenleniyor..."
cat <<EOF > /vddos/conf.d/website.conf
default         http://0.0.0.0:80    http://0.0.0.0:8080    no    200      no           no
default         https://0.0.0.0:443  https://0.0.0.0:8443   no    200      /vddos/ssl/your-domain.com.pri /vddos/ssl/your-domain.com.crt
EOF

echo "Kurulum tamamlandı. Nginx artık 8080 portunda çalışıyor ve PHP sayfası oluşturuldu."
