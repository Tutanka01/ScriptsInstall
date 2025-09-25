#!/bin/bash

#================================================================
# Script de réinitialisation et de préparation pour Debian 13
#================================================================

# --- Vérification des privilèges root ---
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ Erreur : Veuillez exécuter ce script avec les privilèges root."
  exit 1
fi

# --- Gestion des erreurs ---
# Arrête le script si une commande échoue
set -o errexit
# Arrête le script si une variable non définie est utilisée
set -o nounset
# Gère les erreurs dans les pipelines
set -o pipefail

# --- Mise à jour du système ---
echo "🔄 Mise à jour du système (apt)..."
apt update && apt upgrade -y

# --- Nettoyage des logs ---
echo "🧹 Nettoyage des journaux système..."
# La méthode la plus propre est de laisser systemd-journald gérer ses fichiers,
# mais si un nettoyage est nécessaire, voici une approche.
journalctl --rotate
journalctl --vacuum-time=1s

# --- Régénération de l'ID machine ---
echo "⚙️  Régénération du machine-id..."
# Supprime l'ancien ID
rm -f /etc/machine-id
# systemd-machine-id-setup va le régénérer au prochain démarrage ou via la commande suivante.
systemd-machine-id-setup

# --- Nettoyage des règles réseau persistantes (généralement plus nécessaire) ---
# Ce fichier est souvent obsolète sur les systèmes modernes utilisant des noms d'interface prévisibles.
# La commande le supprime au cas où il existerait sur une ancienne installation.
echo "🌐 Nettoyage des anciennes règles udev réseau..."
rm -f /etc/udev/rules.d/70-persistent-net.rules

# --- Réinitialisation des clés d'hôte SSH ---
echo "🔑 Régénération des clés d'hôte SSH..."
rm -f /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

# --- Gestion du nom d'hôte (hostname) ---
new_hostname=""
if [ -n "${1-}" ]; then
  new_hostname="$1"
  echo "🖥️  Nom d'hôte fourni en argument : $new_hostname"
else
  read -rp "Veuillez entrer le nouveau nom d'hôte : " new_hostname
fi

# Validation du nom d'hôte
if ! [[ "$new_hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]$ ]]; then
  echo "❌ Erreur : Nom d'hôte invalide."
  exit 1
fi

echo "Définition du nom d'hôte sur '$new_hostname'..."
hostnamectl set-hostname "$new_hostname"

# --- Mise à jour du fichier /etc/hosts ---
echo "📝 Mise à jour du fichier /etc/hosts..."
cat <<EOL > /etc/hosts
127.0.0.1   localhost
127.0.1.1   $new_hostname

# Les lignes suivantes sont souhaitables pour les hôtes compatibles IPv6
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOL

# --- Nettoyage final ---
echo "🗑️  Nettoyage des fichiers temporaires et de l'historique..."

# Vide la corbeille de tous les utilisateurs, y compris root
rm -rf /root/.local/share/Trash/*
find /home/ -mindepth 2 -maxdepth 2 -type d -name ".local" -exec rm -rf {}/share/Trash/* \; &> /dev/null || true

# Nettoyage de l'historique bash
unset HISTFILE
history -c && history -w
rm -f /root/.bash_history
find /home/ -type f -name ".bash_history" -delete

# Nettoyage du cache apt
apt-get clean
apt-get autoremove -y

echo "✅ Réinitialisation terminée avec succès !"
echo "Il est recommandé de redémarrer le système pour que tous les changements prennent effet."