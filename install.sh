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

#   Зупинка попереднього nginx (якщо працює)
sudo pkill -f nginx || true

# 📝 Створення базового конфігу nginx з RTMP
sudo tee /usr/local/nginx/conf/nginx.conf > /dev/null <<EOF
worker_processes auto;

events {
    worker_connections 1024;
}

rtmp {
    server {
        listen 1935;
        chunk_size 4096;

        application live {
            live on;
            record off;
            drop_idle_publisher 10s;
            # Ключовий момент: використання exec_push для трансляції через ffmpeg
            exec_push /home/toropov/start.sh $name;
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

# ✅ Тест та запуск nginx
sudo /usr/local/nginx/sbin/nginx -t
sudo /usr/local/nginx/sbin/nginx

# 🔍 Перевірка RTMP-модуля
/usr/local/nginx/sbin/nginx -V 2>&1 | grep rtmp || echo "⚠️ RTMP not found – перевір вручну"
