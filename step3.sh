#!/bin/bash

read -p "What is the full hostname? (FQDN e.g. laptop1.example.com)? " hostnamead
sudo hostnamectl set-hostname $hostnamead

sudo apt -y install realmd libnss-sss libpam-sss sssd sssd-tools adcli samba-common-bin oddjob oddjob-mkhomedir packagekit -y
echo "Installed necessary packages."

echo "Printing available Kerberos realms. If AD does not appear, exit now and resolve DNS issues."
read -p "What is the AD domain/realm? " adrealm
read -p "What is the domain admin username? " aduser

sudo realm join -v -U "$aduser" "$adrealm"

echo "Ensure activate mkhomedir is selected in the next prompt."

echo 'Name: activate mkhomedir
Default: yes
Priority: 900
Session-Type: Additional
Session:
        required  pam_mkhomedir.so umask=0022 skel=/etc/skel' | sudo tee /usr/share/pam-configs/mkhomedir
sudo pam-auth-update -f
sudo systemctl restart sssd
