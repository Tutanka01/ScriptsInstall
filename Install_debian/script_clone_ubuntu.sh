#!/bin/bash

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script en tant que root."
  exit 1
fi

# Fonction pour gérer les erreurs
handle_error() {
  echo "Erreur à la ligne $1"
  exit 1
}

# Activation du mode strict et gestion des erreurs
set -e
trap 'handle_error $LINENO' ERR

# Mise à jour du système
echo "Mise à jour du système..."
apt update && apt upgrade -y

# Nettoyage des logs
echo "Nettoyage des logs..."
find /var/log -type f -exec truncate -s 0 {} \;

# Réinitialisation de l'identifiant machine (regénéré au prochain démarrage)
echo "Réinitialisation de l'identifiant machine..."
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# Nettoyage des règles udev persistantes pour les interfaces réseau
echo "Nettoyage des règles udev..."
rm -f /etc/udev/rules.d/70-persistent-net.rules

# Réinitialisation des configurations spécifiques
echo "Réinitialisation des configurations spécifiques..."
rm -f /etc/hostname
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A

# Gestion du hostname
if [ -n "$1" ]; then
  # Hostname fourni en paramètre
  new_hostname="$1"
  if [[ ! "$new_hostname" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Erreur : Nom d'hôte invalide '$new_hostname'"
    exit 1
  fi
  echo "Utilisation du hostname fourni : $new_hostname"
else
  # Demande interactive du hostname
  while true; do
    read -p "Nouveau nom d'hôte (hostname) : " new_hostname
    if [[ "$new_hostname" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      break
    else
      echo "Nom d'hôte invalide. Veuillez réessayer."
    fi
  done
fi

echo "$new_hostname" > /etc/hostname
hostnamectl set-hostname "$new_hostname"

# Mise à jour des fichiers hosts
cat <<EOL > /etc/hosts
127.0.0.1 localhost
127.0.1.1 $new_hostname

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOL

# Nettoyage des clés SSH connues pour éviter des conflits
echo "Nettoyage des clés SSH connues..."
rm -rf /root/.ssh/known_hosts
find /home -type f -name "known_hosts" -exec rm -f {} \;

# Nettoyage de l'historique des commandes
echo "Nettoyage de l'historique des commandes..."
unset HISTFILE
rm -f /root/.bash_history
find /home -type f -name ".bash_history" -exec rm -f {} \;

echo "Réinitialisation terminée."
echo "Redémarrez la VM clonée pour générer son nouvel identifiant machine et activer ses nouvelles clés SSH."
echo ""
