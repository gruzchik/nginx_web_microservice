#!/bin/bash
SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# enable config file
source ${SCRIPTPATH}/vm1.config
if [ $? != 0 ]; then
        echo "Configuration file is not persists. Please fix it"
	exit 1
fi

EXTERNAL_IF=$(echo ${EXTERNAL_IF} | tr -d \”| tr -d \")
INTERNAL_IF=$(echo ${INTERNAL_IF} | tr -d \”| tr -d \")
EXT_IP=$(echo ${EXT_IP} | tr -d \”| tr -d \")
#echo "EXTERNAL_IF= "${EXTERNAL_IF}
#echo "INTERNAL_IF= "${INTERNAL_IF}
#echo "VLAN= "${VLAN}
#echo "EXT_IP= "${EXT_IP}
#echo "EXT_GW= "${EXT_GW}
#echo "INT_IP= "${INT_IP}
#echo "VLAN_IP= "${VLAN_IP}
#echo "APACHE_VLAN_IP= "${APACHE_VLAN_IP}
#exit


#EX_IF=$(cat ${SCRIPTPATH}/vm1.config | grep "^EXTERNAL_IF=" | awk -F"=" {' print $2'}| tr -d \”| tr -d \")
#EXT_IP=$(cat ${SCRIPTPATH}/vm1.config | awk {' print $1 '} | grep "^EXT_IP=" | awk -F"=" {' print $2'}| tr -d \”| tr -d \")
#EXT_GW=$(cat ${SCRIPTPATH}/vm1.config | grep "^EXT_GW=" | awk -F"=" {' print $2'}| tr -d \”| tr -d \")
#V_IF=$(cat ${SCRIPTPATH}/vm1.config | grep "^INTERNAL_IF=" | awk -F"=" {' print $2'}| tr -d \”)
#V_N=$(cat ${SCRIPTPATH}/vm1.config | grep "^VLAN=" | awk -F"=" {' print $2'}| tr -d \”)
#V_IP=$(cat ${SCRIPTPATH}/vm1.config | grep "^INT_IP=" | awk -F"=" {' print $2'}| awk -F="/" {' print $1 '}| awk -F"/" {' print $1 '})

VLAN_IF=${INTERNAL_IF}.${VLAN}
echo "vlan if="${VLAN_IF}

# test external_if
if [[ -z $(cat /etc/network/interfaces | grep -v "^#" | grep "${EXTERNAL_IF}") ]]; then

if [[ "${EXT_IP}" == "DHCP" ]]; then
cat <<EOF >> /etc/network/interfaces

auto ${EXTERNAL_IF}
iface ${EXTERNAL_IF} inet dhcp
EOF
else
cat <<EOF >> /etc/network/interfaces

auto ${EXTERNAL_IF}
iface ${EXTERNAL_IF} inet static
address ${EXT_IP}
gateway ${EXT_GW}
EOF
fi
systemctl restart networking.service
fi

# add nameserver if it need
TEST_NS=$(cat /etc/resolv.conf | grep "^nameserver")
if [[ -z "${TEST_NS}" ]]; then
        echo "nameserver 8.8.8.8" >> /etc/resolv.conf
fi

# check if vlan was installed
if [ ! -x "$(command -v vconfig)" ]; then
        apt-get install -y vlan
else
        echo "vlan had been already installed"
fi

#add VLAN interface
if [[ -z $(cat /etc/network/interfaces | grep -v "^#" | grep "${VLAN_IF}") ]]; then

echo install vlan..
cat <<EOF >> /etc/network/interfaces

auto ${VLAN_IF}
iface ${VLAN_IF} inet static
address ${INT_IP}
#netmask 255.255.255.0
vlan_raw_device ${INTERNAL_IF}
EOF

systemctl restart networking.service
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -I POSTROUTING -o ${EXTERNAL_IF} -j MASQUERADE
fi


# check if nginx was installed
if [ ! -x "$(command -v nginx)" ]; then
        apt-get install -y nginx
else
        echo "nginx had been already installed"
fi
