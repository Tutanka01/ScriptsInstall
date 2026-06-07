#!/bin/bash

#================================================================
# Script de réinitialisation et de préparation pour Debian 13
#================================================================

# --- Gestion des erreurs ---
set -o errexit
set -o nounset
set -o pipefail

trap 'echo "❌ Erreur : échec à la ligne ${LINENO}. Script interrompu."; exit 1' ERR

show_banner() {
  cat <<'EOF'
 __  __       _    _           _       _____
|  \/  | __ _| | _| |__   __ _| |     |  ___| __
| |\/| |/ _` | |/ / '_ \ / _` | |_____| |_ | '__|
| |  | | (_| |   <| | | | (_| | |_____|  _|| |
|_|  |_|\__,_|_|\_\_| |_|\__,_|_|     |_|  |_|

              makhal.Fr - Debian 13 Clone Prep
EOF
}

log() {
  echo "➡️  $*"
}

die() {
  echo "❌ Erreur : $*" >&2
  exit 1
}

confirm() {
  local prompt="$1"
  local default="${2:-n}"
  local answer=""
  local suffix="[y/N]"

  if [[ "$default" == "y" ]]; then
    suffix="[Y/n]"
  fi

  if [[ ! -t 0 ]]; then
    if [[ "$default" == "y" ]]; then
      return 0
    fi
    return 1
  fi

  while true; do
    read -rp "$prompt $suffix " answer
    answer="${answer:-$default}"
    case "${answer,,}" in
      y|yes|o|oui) return 0 ;;
      n|no|non) return 1 ;;
      *) echo "Réponse invalide. Répondez par y/n ou oui/non." ;;
    esac
  done
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "commande requise introuvable : $1"
}

validate_hostname() {
  local hostname="$1"

  [[ ${#hostname} -le 63 ]] || return 1
  [[ "$hostname" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]
}

show_banner

# --- Vérification des privilèges root ---
if [[ "$EUID" -ne 0 ]]; then
  die "veuillez exécuter ce script avec les privilèges root."
fi

# --- Vérification des commandes nécessaires ---
require_command apt
require_command apt-get
require_command hostnamectl
require_command journalctl
require_command systemd-machine-id-setup
require_command ssh-keygen

# --- Mise à jour du système ---
log "Mise à jour de l'index des paquets (apt update)..."
apt update

if confirm "Voulez-vous lancer apt upgrade maintenant ?" "n"; then
  log "Mise à niveau du système (apt upgrade)..."
  apt upgrade -y
else
  log "Upgrade ignoré à la demande de l'utilisateur."
fi

# --- Nettoyage des logs ---
log "Nettoyage des journaux système..."
# La méthode la plus propre est de laisser systemd-journald gérer ses fichiers,
# mais si un nettoyage est nécessaire, voici une approche.
journalctl --rotate
journalctl --vacuum-time=1s

# --- Régénération de l'ID machine ---
log "Régénération du machine-id..."
rm -f /etc/machine-id /var/lib/dbus/machine-id
mkdir -p /var/lib/dbus
systemd-machine-id-setup
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# --- Nettoyage des règles réseau persistantes (généralement plus nécessaire) ---
# Ce fichier est souvent obsolète sur les systèmes modernes utilisant des noms d'interface prévisibles.
# La commande le supprime au cas où il existerait sur une ancienne installation.
log "Nettoyage des anciennes règles udev réseau..."
rm -f /etc/udev/rules.d/70-persistent-net.rules

# --- Réinitialisation des clés d'hôte SSH ---
log "Régénération des clés d'hôte SSH..."
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A

# --- Gestion du nom d'hôte (hostname) ---
new_hostname=""
if [ -n "${1-}" ]; then
  new_hostname="$1"
  log "Nom d'hôte fourni en argument : $new_hostname"
else
  [[ -t 0 ]] || die "aucun hostname fourni et le mode interactif n'est pas disponible."

  while true; do
    read -rp "Veuillez entrer le nouveau nom d'hôte : " new_hostname
    validate_hostname "$new_hostname" && break
    echo "Nom d'hôte invalide. Utilisez 1 à 63 caractères : lettres, chiffres ou tirets, sans tiret au début/à la fin."
  done
fi

# Validation du nom d'hôte
if ! validate_hostname "$new_hostname"; then
  die "nom d'hôte invalide : $new_hostname"
fi

log "Définition du nom d'hôte sur '$new_hostname'..."
hostnamectl set-hostname "$new_hostname"

# --- Mise à jour du fichier /etc/hosts ---
log "Mise à jour du fichier /etc/hosts..."
cp -a /etc/hosts "/etc/hosts.bak.$(date +%Y%m%d-%H%M%S)"
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
log "Nettoyage des fichiers temporaires et de l'historique..."

# Vide la corbeille de tous les utilisateurs, y compris root
rm -rf /root/.local/share/Trash/*
find /home/ -mindepth 2 -maxdepth 2 -type d -name ".local" -exec rm -rf {}/share/Trash/* \; &> /dev/null || true

# Nettoyage de l'historique bash
unset HISTFILE
history -c && history -w || true
rm -f /root/.bash_history
find /home/ -type f -name ".bash_history" -delete

# Nettoyage du cache apt
apt-get clean
apt-get autoremove -y

echo "✅ Réinitialisation terminée avec succès !"
echo "Il est recommandé de redémarrer le système pour que tous les changements prennent effet."
