#!/bin/bash
SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

EX_IF=$(cat ${SCRIPTPATH}/vm1.config | grep "^EXTERNAL_IF=" | awk -F"=" {' print $2'}| tr -d \”| tr -d \")
V_IF=$(cat ${SCRIPTPATH}/vm1.config | grep "^INTERNAL_IF=" | awk -F"=" {' print $2'}| tr -d \”)
V_N=$(cat ${SCRIPTPATH}/vm1.config | grep "^VLAN=" | awk -F"=" {' print $2'}| tr -d \”)
V_IP=$(cat ${SCRIPTPATH}/vm1.config | grep "^INT_IP=" | awk -F"=" {' print $2'}| awk -F="/" {' print $1 '}| awk -F"/" {' print $1 '})

VLAN_IF=${V_IF}.${V_N}
echo "vlan if="${VLAN_IF}

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
if [[ -z $(cat /etc/network/interfaces | grep "${VLAN_IF}") ]]; then

echo install
cat <<EOF >> /etc/network/interfaces

auto ${VLAN_IF}
iface ${VLAN_IF} inet static
address ${V_IP}
#netmask 255.255.255.0
vlan_raw_device ${V_IF}
EOF

systemctl restart networking.service
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -I POSTROUTING -o ${EX_IF} -j MASQUERADE
fi


# check if nginx was installed
if [ ! -x "$(command -v nginx)" ]; then
        apt-get install -y nginx
else
        echo "nginx had been already installed"
fi
