#!/bin/bash

echo "Installing necessary packages..."
sudo dnf install -y realmd sssd sssd-client sssd-tools sssd-ad adcli samba-common oddjob lsb nfs4-acl-tools
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
    --set name="$(hostname -s)" \
    --set password="${password}" \
    --set operatingSystem="$(lsb_release -is)" \
    --set operatingSystemVersion="$(lsb_release -rs | cut -d"." -f1)"
printf '%s' "$password" >/etc/ldap.secret
chmod 0400 /etc/ldap.secret

echo "Performing domain join operation. Password for domain admin will be prompted."
sudo realm join --automatic-id-mapping=no -v -U "$REALMADMIN" "$REALMAD"

sudo systemctl restart sssd

# Make the domain the default login domain for the login screen. Simplifies logins.
sudo sed -i "/sssd/a default_domain_suffix = $REALMAD" /etc/sssd/sssd.conf

#prompt
read -r -p "UCS Domain Join Complete! REBOOT NOW? [y/N] " rebootnow
if [[ "$rebootnow" =~ ^([yY][eE][sS]|[yY])+$ ]]
then
echo "Rebooting!"
sudo reboot
else
read -p "Reboot not selected. Press any key to finish with script."
fi
