#!/bin/bash -e
# pas root !!
if [ "$UID" -ne 0 ]; then
  echo "Mets toi en root mon reuf"
  exit 1
fi
# Declaration des couleurs
RED='\033[0;31m'

# Installer tout ce qui nous faut
if [ -x /usr/bin/apt-get ]; then
  apt-get update
  echo -e "${RED}Installation de Zabbix-agent${NC}"
  apt-get -y install zabbix-agent sysv-rc-conf
  sysv-rc-conf zabbix-agent on
  echo -e "${RED}Mise en place des conigs necessaires${NC}"
  sed -i 's/Server=127.0.0.1/Server=192.168.9.100/' /etc/zabbix/zabbix_agentd.conf
  sed -i 's/ServerActive=127.0.0.1/ServerActive=192.168.9.100/' /etc/zabbix/zabbix_agentd.conf
  sed -i '/HostMetadata=/s/.*/HostMetadata=Linux/' /etc/zabbix/zabbix_agentd.conf
  HOSTNAME=`hostname` && sed -i "s/Hostname=Zabbix\ server/Hostname=$HOSTNAME/" /etc/zabbix/zabbix_agentd.conf
  service zabbix-agent restart
fi
echo -e "${RED}###################################################################################${NC}"
echo -e "${RED}###################################################################################${NC}"
echo -e "${RED}# L'agent a bien ete installe, va verfier sur http://zabbix.makhal.lan/zabbix #${NC}"
echo -e "${RED}###################################################################################${NC}"
echo -e "${RED}###################################################################################${NC}"