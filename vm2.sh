#!/bin/bash
SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# enable config file
source ${SCRIPTPATH}/vm2.config
if [ $? != 0 ]; then
        echo "Configuration file is not persists. Please fix it"
        exit 1
fi

#echo "INTERNAL_IF= "${INTERNAL_IF}
#echo "VLAN= "${VLAN}
#echo "MANAGEMENT_IP= "${MANAGEMENT_IP}
#echo "INT_IP= "${INT_IP}
#echo "GW_IP= "${GW_IP}
#echo "APACHE_VLAN_IP= "${APACHE_VLAN_IP}
#exit

VLAN_IF=${INTERNAL_IF}.${VLAN}
echo "vlan if= ${VLAN_IF}"
# add INT interface
if [[ -z $(cat /etc/network/interfaces | grep -v "^#" | grep "${INTERNAL_IF}") ]]; then
echo install int..
cat <<EOF >> /etc/network/interfaces

auto ${INTERNAL_IF}
iface ${INTERNAL_IF} inet static
address ${INT_IP}
EOF
fi
# add VLAN interface
if [[ -z $(cat /etc/network/interfaces | grep -v "^#" | grep "${VLAN_IF}") ]]; then
echo install vlan..
cat <<EOF >> /etc/network/interfaces

auto ${VLAN_IF}
iface ${VLAN_IF} inet static
address ${APACHE_VLAN_IP}
vlan_raw_device ${INTERNAL_IF}
EOF

systemctl restart networking.service
route del default
route add default gw ${GW_IP}
fi

# add nameserver if it need
TEST_NS=$(cat /etc/resolv.conf | grep "^nameserver")
if [[ -z "${TEST_NS}" ]]; then
	echo "nameserver 8.8.8.8" >> /etc/resolv.conf
fi

# check if apache2 was installed
if [ ! -x "$(command -v apache2)" ]; then
        apt-get install -y apache2
else
        echo "apache had been already installed"
fi

# listen IP for apache
APACHE_LISTEN_IP=$(ifconfig $INTERNAL_IF.$VLAN | grep 'inet\ addr'| awk -F":" {' print $2 '} | awk {' print $1 '})
cp /etc/apache2/ports.conf /etc/apache2/ports.conf_def
echo "Listen ${APACHE_LISTEN_IP}:80" > /etc/apache2/ports.conf
service apache2 restart
