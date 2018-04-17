#!/bin/bash

V_IF=$(cat vm2.config | grep "^INTERNAL_IF=" | awk -F"=" {' print $2 '} | tr -d \")
V_N=$(cat vm2.config | grep "^VLAN=" | awk -F"=" {' print $2 '} | tr -d \")
V_IP=$(cat vm2.config | grep "^INT_IP=" | awk -F"=" {' print $2 '})
V_GW=$(cat vm2.config | grep "^GW_IP=" | awk -F"=" {' print $2 '})

VLAN_IF=${V_IF}.${V_N}
echo "vlan if= ${VLAN_IF}"

echo install..
cat <<EOF >> /etc/network/interfaces

auto ${VLAN_IF}
iface ${VLAN_IF} inet static
address ${V_IP}
vlan_raw_device ${V_IF}
EOF

systemctl restart networking.service
route add default gw ${V_GW}

TEST_NS=$(cat /etc/resolv.conf | grep "^nameserver")
if [[ -z "${TEST_NS}" ]]; then
	echo "nameserver 8.8.8.8" >> /etc/resolv.conf
fi
