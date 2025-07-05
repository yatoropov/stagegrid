#!/bin/bash

sudo apt update
sudo add-apt-repository -y ppa:mc3man/trusty-media
sudo apt-get install -y ffmpeg
sudo apt install -y nginx libnginx-mod-rtmp
sudo systemctl restart nginx
sudo apt install -y net-tools
sudo apt install -y unzip

fileid=18uEA4rpfmOPjqOBLwuaKelaMRWa9MGn3
curl -L "https://drive.usercontent.google.com/download?id=${fileid}&export=download&confirm=t" -o restream.zip

unzip restream.zip
mv 'main server' restream
cd restream
chmod +x *.sh
cd ../
rm -r __*
rm restream.zip
cd restream/
ls -l
sudo systemctl status nginx
