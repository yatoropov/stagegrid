#!/usr/bin/env bash
set -eux

NGINX_VER=1.9.9

sudo apt update
sudo apt install -y build-essential libpcre3 libpcre3-dev libssl-dev zlib1g-dev git wget

cd /usr/local/src
git clone https://github.com/arut/nginx-rtmp-module.git
wget http://nginx.org/download/nginx-${NGINX_VER}.tar.gz
tar xzf nginx-${NGINX_VER}.tar.gz
cd nginx-${NGINX_VER}

./configure \
  --with-http_ssl_module \
  --add-module=../nginx-rtmp-module

make -j"$(nproc)"
sudo make install

sudo /usr/local/nginx/sbin/nginx -t
sudo systemctl stop nginx || true
sudo ln -sf /usr/local/nginx/sbin/nginx /usr/sbin/nginx
sudo systemctl start nginx
