sudo apt-get update -y
sudo rm -r stagegrid
git clone https://github.com/yatoropov/stagegrid.git
cd stagegrid
chmod +x install.sh
chmod +x start.sh
./install.sh
