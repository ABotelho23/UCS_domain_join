#!/bin/bash

# obtain LDAP server IP
read -p "What is the IP of the LDAP server? " MASTER_IP

mkdir /etc/univention
ssh -n root@${MASTER_IP} 'ucr shell | grep -v ^hostname=' >/etc/univention/ucr_master
echo "master_ip=${MASTER_IP}" >>/etc/univention/ucr_master
chmod 660 /etc/univention/ucr_master

echo "${MASTER_IP} ${ldap_master}" >>/etc/hosts
