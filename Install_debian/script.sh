#!/bin/bash

# Vérification si l'utilisateur est root
if [ "$EUID" -ne 0 ]; then
  echo "# Ce script doit être exécuté en tant que root."
  exit 1
fi

# Demande de confirmation pour démarrer
read -p "# Voulez-vous démarrer l'installation ? (Y/n) " choice
case "$(echo "$choice" | tr '[:upper:]' '[:lower:]')" in
  n) 
    echo "# Installation annulée."
    exit 0
    ;;
  *) 
    echo "# Début de l'installation..."
    ;;
esac

# Mise à jour du système
 apt update
 apt upgrade -y

# Installation des outils de base
 apt install -y vim htop curl wget git

# Installation de fail2ban
 apt install -y fail2ban
 systemctl enable fail2ban
 systemctl start fail2ban

# Config fail2ban
 cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Modifier le fichier de configuration de fail2ban
 sed -i '/^\[sshd\]$/,/^\[/ {
  s|^#mode.*$|mode = normal|
  s|^port.*$|port = ssh|
  s|^logpath.*$|logpath = %(sshd_log)s|
  s|^backend.*$|backend = systemd|
}' /etc/fail2ban/jail.local

 systemctl restart fail2ban

# Configuration SSH
 cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak  # Sauvegarde de la configuration actuelle
 sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
 systemctl restart ssh

# Installation d'un firewall
 apt install -y ufw
 ufw default deny incoming
 ufw default allow outgoing
 ufw allow ssh
 ufw enable

# Demande d'installation de Docker
read -p "# Voulez-vous installer Docker ? (Y/n) " docker_choice
case "$(echo "$docker_choice" | tr '[:upper:]' '[:lower:]')" in
  y) 
    echo "# Installation de Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
     sh get-docker.sh
    ;;
  *) 
    echo "# Installation de Docker annulée."
    ;;
esac


echo "# Script de post-installation terminé."
