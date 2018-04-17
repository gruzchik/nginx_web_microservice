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

#V_IF=$(cat vm2.config | grep "^INTERNAL_IF=" | awk -F"=" {' print $2 '} | tr -d \")
#V_N=$(cat vm2.config | grep "^VLAN=" | awk -F"=" {' print $2 '} | tr -d \")
#V_IP=$(cat vm2.config | grep "^INT_IP=" | awk -F"=" {' print $2 '})
#V_GW=$(cat vm2.config | grep "^GW_IP=" | awk -F"=" {' print $2 '})

VLAN_IF=${INTERNAL_IF}.${VLAN}
echo "vlan if= ${VLAN_IF}"
# add VLAN interface
if [[ -z $(cat /etc/network/interfaces | grep -v "^#" | grep "${VLAN_IF}") ]]; then
echo install vlan..
cat <<EOF >> /etc/network/interfaces

auto ${VLAN_IF}
iface ${VLAN_IF} inet static
address ${INT_IP}
vlan_raw_device ${INTERNAL_IF}
EOF

systemctl restart networking.service
route add default gw ${GW_IP}
fi

TEST_NS=$(cat /etc/resolv.conf | grep "^nameserver")
if [[ -z "${TEST_NS}" ]]; then
	echo "nameserver 8.8.8.8" >> /etc/resolv.conf
fi
