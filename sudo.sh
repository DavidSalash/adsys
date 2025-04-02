
PATH=$PATH/usr/sbin
echo $PATH
apt update && apt install sudo -y
usermod -aG sudo as
su - as
sudo whoami
