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

VLAN_IF=${INTERNAL_IF}.${VLAN}
echo "vlan if="${VLAN_IF}

# test and add external_if
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

EXT_IP=$(ifconfig ${EXTERNAL_IF} | grep "inet\ addr" | awk -F":" {' print $2 '} | awk {' print $1 '})
echo "EXT_IP1= "${EXT_IP}

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

# add INT interface
if [[ -z $(cat /etc/network/interfaces | grep -v "^#" | grep "${INTERNAL_IF}") ]]; then
echo install int..
cat <<EOF >> /etc/network/interfaces

auto ${INTERNAL_IF}
iface ${INTERNAL_IF} inet static
address ${INT_IP}
EOF
fi
#add VLAN interface
if [[ -z $(cat /etc/network/interfaces | grep -v "^#" | grep "${VLAN_IF}") ]]; then

echo install vlan..
cat <<EOF >> /etc/network/interfaces

auto ${VLAN_IF}
iface ${VLAN_IF} inet static
address ${VLAN_IP}
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

# check if openssl was installed
if [ ! -x "$(command -v openssl)" ]; then
        apt-get install -y openssl
else
        echo "openssl had been already installed"
fi

# generate root certificate
openssl genrsa -out /etc/ssl/private/root-ca.key 2048
openssl req -x509 -days 365 -new -nodes -key /etc/ssl/private/root-ca.key -sha256 -out /etc/ssl/certs/root-ca.crt -subj "/C=UA/ST=Kharkiv/L=Kharkiv/O=Nure/OU=Admin/CN=rootCA"
# generate nginx cert
HOSTT=$(hostname -f); if [ $? -eq 0 ] && [[ "${HOSTT}" != 'vm1' ]] && [ -n "${HOSTT}" ]; then HOSTNAME_F=",DNS:$(hostname -f)"; else HOSTNAME_F=""; fi
openssl genrsa -out /etc/ssl/private/web.key 2048
openssl req -nodes -new -sha256 -key /etc/ssl/private/web.key -out /etc/ssl/certs/web.csr -subj "/C=UA/ST=Kharkiv/L=Kharkiv/O=Datacenter/OU=Server/CN=vm1"
openssl x509 -req -extfile <(printf "subjectAltName=IP:${EXT_IP}${HOSTNAME_F}") -days 365 -in /etc/ssl/certs/web.csr -CA /etc/ssl/certs/root-ca.crt -CAkey /etc/ssl/private/root-ca.key -CAcreateserial -out /etc/ssl/certs/web.crt

# add SSL_CHAIN
cat /etc/ssl/certs/web.crt /etc/ssl/certs/root-ca.crt > /etc/ssl/certs/web-bundle.crt
SSL_KEY="/etc/ssl/private/web.key"
SSL_CHAIN="/etc/ssl/certs/web-bundle.crt"

cat <<EOF >/etc/nginx/sites-available/default
server {
        listen $NGINX_PORT ssl;
        ssl on;
        ssl_certificate ${SSL_CHAIN};
        ssl_certificate_key ${SSL_KEY};
        location / {
                proxy_pass http://$APACHE_VLAN_IP;
        }
}
EOF
service nginx restart
