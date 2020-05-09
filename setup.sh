#!/bin/bash

if [ "$EUID" -ne 0 ]
  then read -p "Please run with sudo or as root. Press any key to close script."
  exit
fi

#Killing dpkg processes and unattended upgrade service
echo "Killing unattended upgrades service temporarily and killing all dpkg processes to ensure lock for package installs."
sudo systemctl stop unattended-upgrades.service
sudo killall dpkg

echo "Installing necessary packages..."
sudo apt -y install realmd libnss-sss libpam-sss sssd sssd-tools adcli samba-common-bin oddjob oddjob-mkhomedir packagekit
clear
echo "Completed installation of necessary packages. Now printing discovered Kerberos realms..."
realm discover

echo "Your domain and its properties should be printed above. If they are not, check DNS config."
read -p "What is the Kerberos realm? (dom.example.com)? " REALMAD
read -p "What is the domain controllers short hostname ? ('dc' part of dc.dom.example.com)? " REALMDC
read -p "What is the domain admin username? " REALMADMIN
shorthost=${HOSTNAME%%.*}

mkdir /etc/univention
echo "Connecting to $REALMDC.$REALMAD UCS server and pulling UCS config. Password for domain admin will be prompted."
ssh -n root@"$REALMDC.$REALMAD" 'ucr shell | grep -v ^hostname=' >/etc/univention/ucr_master
echo "master_ip=$REALMDC.$REALMAD" >>/etc/univention/ucr_master
chmod 660 /etc/univention/ucr_master

. /etc/univention/ucr_master

# Create an account and save the password
echo "Creating computer account on $REALMDC.$REALMAD UCS server. Password for domain admin will be prompted."
password="$(tr -dc A-Za-z0-9_ </dev/urandom | head -c20)"
ssh -n root@"$REALMDC.$REALMAD" udm computers/linux create \
    --position "cn=computers,${ldap_base}" \
    --set name="$(hostname)" \
    --set password="${password}" \
    --set operatingSystem="$(lsb_release -is)" \
    --set operatingSystemVersion="$(lsb_release -rs)"
printf '%s' "$password" >/etc/ldap.secret
chmod 0400 /etc/ldap.secret

echo "Performing domain join operation. Password for domain admin will be prompted."
sudo realm join -v -U "$REALMADMIN" "$REALMAD"

# Create ldap.conf
sudo rm /etc/ldap/ldap.conf
echo "TLS_CACERT /etc/univention/ssl/ucsCA/CAcert.pem
URI ldap://$ldap_master:7389
BASE $ldap_base" | sudo tee /etc/ldap/ldap.conf


echo "Activating mkhomedir module..."
echo 'Name: activate mkhomedir
Default: yes
Priority: 900
Session-Type: Additional
Session:
        required  pam_mkhomedir.so umask=0022 skel=/etc/skel' | sudo tee /usr/share/pam-configs/mkhomedir
sudo pam-auth-update --enable mkhomedir
sudo systemctl restart sssd

sudocheck=0
while [ "$sudocheck" -ne 1 ]
do
  read -p "Add a domain user to local sudoers? (This gives the user admin permissions for this computer) Y/N " sudoinput
    if [[ "$sudoinput" =~ ^([yY][eE][sS]|[yY])+$ ]]
    then
      read -p "Alright! What's the username? Exclude the @$REALMAD part. " sudoun
      echo "Adding $sudoun@$REALMAD to /etc/sudoers.d directory.."
        echo "$sudoun@$REALMAD ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers
        echo "Done adding user $sudoun@$REALMAD"
      
    elif [[ "$sudoinput" =~ ^([nN][oO]|[nN])+$ ]]
    then
      echo "Alright, moving on."
      sudocheck=1
    
    else echo "That input doesn't make sense. Please try again."
    fi
done

#prompt
read -r -p "UCS Domain Join Complete! REBOOT NOW? [y/N] " rebootnow
if [[ "$rebootnow" =~ ^([yY][eE][sS]|[yY])+$ ]]
then
echo "Rebooting!"
sudo reboot
else
read -p "Reboot not selected. Press any key to finish with script."
fi
