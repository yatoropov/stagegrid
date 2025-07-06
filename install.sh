#!/usr/bin/env bash
set -euxo pipefail

# 🔧 Змінна версії nginx
NGINX_VER=1.25.3

# 📁 Директорія для збірки
BUILD_DIR="$HOME/nginx-rtmp-build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 📦 Встановлення залежностей
sudo apt update
sudo apt install -y build-essential libpcre3-dev zlib1g-dev libssl-dev git wget ffmpeg curl

# ⬇️ Завантаження nginx та RTMP-модуля
wget "http://nginx.org/download/nginx-${NGINX_VER}.tar.gz"
tar zxvf "nginx-${NGINX_VER}.tar.gz"
git clone --depth=1 https://github.com/arut/nginx-rtmp-module.git

# ⚙️ Збірка nginx з RTMP
cd "nginx-${NGINX_VER}"
./configure --with-http_ssl_module --add-module=../nginx-rtmp-module
make -j"$(nproc)"
sudo make install

# 🔗 Символічне посилання
sudo ln -sf /usr/local/nginx/sbin/nginx /usr/sbin/nginx

# 🔥 Створення systemd сервісу nginx-rtmp
sudo tee /etc/systemd/system/nginx-rtmp.service > /dev/null <<EOF
[Unit]
Description=Custom NGINX RTMP Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/usr/local/nginx/sbin/nginx -s quit
PIDFile=/usr/local/nginx/logs/nginx.pid
Restart=on-failure
User=$(whoami)

[Install]
WantedBy=multi-user.target
EOF

# 🔄 Завантаження systemd юніта
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable nginx-rtmp

#   Зупинка попереднього nginx (якщо працює)
sudo pkill -f nginx || true

# 📝 Створення базового конфігу nginx з RTMP
sudo tee /usr/local/nginx/conf/nginx.conf > /dev/null <<'EOF'
user toropov;
worker_processes auto;

events {
    worker_connections 1024;
}

rtmp {
    server {
        listen 1935;
        chunk_size 4096;

        application onlinestage {
            live on;
            record off;
            drop_idle_publisher 10s;
            exec_push /home/toropov/stagegrid/start.sh;
        }
    }
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    server {
        listen 8080;
        location / {
            return 200 'nginx with rtmp works';
        }
    }
}
EOF

# ✅ Тест та старт nginx через systemd
sudo systemctl start nginx-rtmp
sudo systemctl status nginx-rtmp --no-pager

# 🔍 Перевірка RTMP-модуля
/usr/local/nginx/sbin/nginx -V 2>&1 | grep rtmp || echo "⚠️ RTMP not found – перевір вручну"
