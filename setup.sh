
#!/bin/bash
echo "Installing necessary packages..."
sudo apt -y install realmd libnss-sss libpam-sss sssd sssd-tools adcli samba-common-bin oddjob oddjob-mkhomedir packagekit -y
echo "Installed necessary packages."
echo "Printing discovered Kerberos realms..."
realm discover

echo "Your domain and its properties should be printed above. If they are not, check DNS config."
read -p "What is the Kerberos realm? (dom.example.com)? " REALMAD
read -p "What is the domain controllers short hostname ? ('dc' part of dc.dom.example.com)? " REALMDC
read -p "What is the domain admin username? " REALMADMIN
shorthost=${HOSTNAME%%.*}

mkdir /etc/univention
echo "Connecting to $REALMDC.$REALMAD UCS server and pulling UCS config."
ssh -n root@$REALMDC.$REALMAD 'ucr shell | grep -v ^hostname=' >/etc/univention/ucr_master
echo "master_ip=$REALMDC.$REALMAD" >>/etc/univention/ucr_master
chmod 660 /etc/univention/ucr_master

. /etc/univention/ucr_master

# Create an account and save the password
echo "Creating computer account on "$realdc.$realad" UCS server. Connecting..."
password="$(tr -dc A-Za-z0-9_ </dev/urandom | head -c20)"
ssh -n root@$REALMDC.$REALMAD udm computers/ubuntu create \
    --position "cn=computers,${ldap_base}" \
    --set name=$(hostname) --set password="${password}" \
    --set operatingSystem="$(lsb_release -is)" \
    --set operatingSystemVersion="$(lsb_release -rs)"
printf '%s' "$password" >/etc/ldap.secret
chmod 0400 /etc/ldap.secret

sudo realm join -v -U "$REALMADMIN" "$REALMAD"

# Create ldap.conf
sudo rm /etc/ldap/ldap.conf
echo 'TLS_CACERT /etc/univention/ssl/ucsCA/CAcert.pem
URI ldap://$ldap_master:7389
BASE $ldap_base' | sudo tee /etc/ldap/ldap.conf

read -p "Ensure activate mkhomedir is selected using your arrow keys and space bar in the next prompt. Press ANY KEY to continue."
echo "Ensure activate mkhomedir is selected using your arrow keys and space bar in the next prompt."

echo 'Name: activate mkhomedir
Default: yes
Priority: 900
Session-Type: Additional
Session:
        required  pam_mkhomedir.so umask=0022 skel=/etc/skel' | sudo tee /usr/share/pam-configs/mkhomedir
DEBIAN_FRONTEND=noninteractive pam-auth-update --force
sudo systemctl restart sssd

#prompt
read -r -p "COMPLETE! REBOOT NOW? [y/N] " REBOOTNOW
if [[ "$REBOOTNOW" =~ ^([yY][eE][sS]|[yY])+$ ]]
then
echo "Rebooting now!"
sudo reboot
else
read -p "Reboot not selected. Please ensure you reboot at a later time. Press any key to continue. "
fi
