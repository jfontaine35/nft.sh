#!/bin/bash

# Définition des couleurs
ROUGE='\033[0;31m'
VERT='\033[0;32m'
JAUNE='\033[0;33m'
BLEU='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRIS='\033[0;37m'
RESET='\033[0m'
GRAS='\033[1m'

# Fichier de log
LOG_FILE="/var/log/portforward_nft.log"

# Fonction pour écrire dans le journal
ecrire_log() {
    local niveau="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$niveau] $message" | sudo tee -a "$LOG_FILE" > /dev/null
}

# Fonction pour afficher le menu principal
afficher_menu() {
    clear
    echo -e "${GRAS}${CYAN}=== GESTION DES RÈGLES NFTABLES ===${RESET}"
    echo -e "${JAUNE}Choisis une option :${RESET}"
    echo -e "${VERT}1)${RESET} Lister les règles de forwarding avec détail IP source, IP destination et ports"
    echo -e "${VERT}2)${RESET} Supprimer une règle de forwarding"
    echo -e "${VERT}3)${RESET} Ajouter un port"
    echo -e "${VERT}4)${RESET} Afficher les logs"
    echo -e "${ROUGE}q)${RESET} Quitter"
    echo
    echo -e -n "${GRAS}${JAUNE}Entrez le numéro de votre choix : ${RESET}"
    read choix
}

# Fonction pour lister les règles de forwarding avec les ports et IP
lister_ports_et_ip() {
    echo -e "${GRAS}${CYAN}Liste des règles de forwarding avec détails :${RESET}"
    echo -e "${GRIS}==================================================${RESET}"
    
    # Version simplifiée qui ne dépend pas des boucles compliquées dans awk
    echo -e "${GRAS}${CYAN}Règles dans la table NAT :${RESET}"
    sudo nft -a list table nat | grep -E 'dnat to|handle' | \
    sed -E 's/.*dport ([0-9]+) .* to ([0-9.]+):([0-9]+).* handle ([0-9]+)/Port Externe: \1 → IP Locale: \2 Port Interne: \3 (Handle: \4)/' | \
    grep "Port Externe"
    
    ecrire_log "INFO" "Liste des règles de forwarding affichée"
}

# Fonction pour supprimer une règle de forwarding
supprimer_regle_forwarding() {
    echo -e "${GRAS}${CYAN}Suppression d'une règle de forwarding${RESET}"
    echo -e "${GRIS}=======================================${RESET}"
    
    # Afficher les règles avec leur handle
    lister_ports_et_ip
    
    echo
    echo -e -n "${JAUNE}Entrez le handle de la règle à supprimer : ${RESET}"
    read handle_regle
    
    # Vérifier si le handle existe
    if [[ -z $(sudo nft -a list table nat | grep "handle $handle_regle") ]]; then
        echo -e "${ROUGE}Erreur: Handle invalide ou non trouvé.${RESET}"
        ecrire_log "ERREUR" "Tentative de suppression avec handle invalide: $handle_regle"
        return
    fi
    
    # Confirmation de suppression
    echo -e -n "${ROUGE}Êtes-vous sûr de vouloir supprimer cette règle ? (y/n) : ${RESET}"
    read confirmation
    if [[ $confirmation == "y" || $confirmation == "Y" ]]; then
        sudo nft delete rule nat PREROUTING handle $handle_regle
        echo -e "${VERT}Règle supprimée avec succès.${RESET}"
        ecrire_log "INFO" "Règle avec handle $handle_regle supprimée"
    else
        echo -e "${JAUNE}Suppression annulée.${RESET}"
        ecrire_log "INFO" "Suppression annulée pour handle $handle_regle"
    fi
}

# Fonction pour ajouter une règle de forwarding de port
ajouter_port() {
    echo -e "${GRAS}${CYAN}Ajout d'une règle de forwarding${RESET}"
    echo -e "${GRIS}===============================${RESET}"
    
    echo -e -n "${JAUNE}Entrez le Port Externe : ${RESET}"
    read PortExterne
    echo -e -n "${JAUNE}Entrez le Port Interne : ${RESET}"
    read PortInterne
    echo -e -n "${JAUNE}Entrez l'octet IP (192.168.100.X) : ${RESET}"
    read OctetIP
    
    # Validation des entrées
    if ! [[ "$PortExterne" =~ ^[0-9]+$ ]] || ! [[ "$PortInterne" =~ ^[0-9]+$ ]] || ! [[ "$OctetIP" =~ ^[0-9]+$ ]]; then
        echo -e "${ROUGE}Erreur: Les ports et l'octet IP doivent être des nombres.${RESET}"
        ecrire_log "ERREUR" "Entrées invalides - Port Ext: $PortExterne, Port Int: $PortInterne, Octet IP: $OctetIP"
        return
    fi
    
    if [[ "$PortExterne" -lt 1 || "$PortExterne" -gt 65535 || "$PortInterne" -lt 1 || "$PortInterne" -gt 65535 ]]; then
        echo -e "${ROUGE}Erreur: Les ports doivent être entre 1 et 65535.${RESET}"
        ecrire_log "ERREUR" "Ports hors limites - Port Ext: $PortExterne, Port Int: $PortInterne"
        return
    fi
    
    if [[ "$OctetIP" -lt 1 || "$OctetIP" -gt 254 ]]; then
        echo -e "${ROUGE}Erreur: L'octet IP doit être entre 1 et 254.${RESET}"
        ecrire_log "ERREUR" "Octet IP hors limites: $OctetIP"
        return
    fi
    
    IP="192.168.100.$OctetIP"
    
    # Ajouter la règle de redirection de port avec NFTables
    sudo nft add rule nat PREROUTING iifname eth0 tcp dport $PortExterne counter dnat to $IP:$PortInterne
    
    # Ajouter la règle de forwarding correspondante
    sudo nft add rule filter FORWARD ip daddr $IP tcp dport $PortInterne counter accept
    
    echo -e "${VERT}Redirection configurée : Port $PortExterne vers $IP:$PortInterne${RESET}"
    ecrire_log "INFO" "Redirection ajoutée - Port $PortExterne vers $IP:$PortInterne"
}

# Fonction pour afficher les logs
afficher_logs() {
    echo -e "${GRAS}${CYAN}Logs de l'application${RESET}"
    echo -e "${GRIS}====================${RESET}"
    
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "${GRIS}Dernières 10 entrées du journal :${RESET}"
        tail -n 10 "$LOG_FILE" | while read ligne; do
            if [[ $ligne == *"[INFO]"* ]]; then
                echo -e "${VERT}$ligne${RESET}"
            elif [[ $ligne == *"[ERREUR]"* ]]; then
                echo -e "${ROUGE}$ligne${RESET}"
            elif [[ $ligne == *"[AVERTISSEMENT]"* ]]; then
                echo -e "${JAUNE}$ligne${RESET}"
            else
                echo -e "$ligne"
            fi
        done
    else
        echo -e "${JAUNE}Aucun fichier de log trouvé.${RESET}"
    fi
}

# Vérifier si nftables est installé
if ! command -v nft &> /dev/null; then
    echo -e "${ROUGE}NFTables n'est pas installé. Installation...${RESET}"
    sudo apt-get update && sudo apt-get install -y nftables
    sudo systemctl enable nftables
    sudo systemctl start nftables
    ecrire_log "INFO" "NFTables installé et démarré"
fi

# Créer les tables et chaînes NFTables si elles n'existent pas
setup_nftables() {
    # Vérifier si la table nat existe déjà
    if ! sudo nft list tables | grep -q "nat"; then
        sudo nft add table ip nat
        ecrire_log "INFO" "Table nat créée"
    fi
    
    # Vérifier si la chaîne PREROUTING existe dans la table nat
    if ! sudo nft list table nat | grep -q "chain PREROUTING"; then
        sudo nft add chain ip nat PREROUTING { type nat hook prerouting priority -100 \; }
        ecrire_log "INFO" "Chaîne PREROUTING créée"
    fi
    
    # Vérifier si la table filter existe
    if ! sudo nft list tables | grep -q "filter"; then
        sudo nft add table ip filter
        ecrire_log "INFO" "Table filter créée"
    fi
    
    # Vérifier si la chaîne FORWARD existe dans la table filter
    if ! sudo nft list table filter | grep -q "chain FORWARD"; then
        sudo nft add chain ip filter FORWARD { type filter hook forward priority 0 \; }
        ecrire_log "INFO" "Chaîne FORWARD créée"
    fi
}

# Initialisation des tables et chaînes NFTables
setup_nftables

# Boucle principale du script
ecrire_log "INFO" "Script démarré"
while true; do
    afficher_menu
    case $choix in
        1)
            lister_ports_et_ip
            ;;
        2)
            supprimer_regle_forwarding
            ;;
        3)
            ajouter_port
            ;;
        4)
            afficher_logs
            ;;
        q|Q)
            echo -e "${VERT}Au revoir!${RESET}"
            ecrire_log "INFO" "Script terminé par l'utilisateur"
            exit 0
            ;;
        *)
            echo -e "${ROUGE}Choix non valide. Veuillez réessayer.${RESET}"
            ecrire_log "AVERTISSEMENT" "Choix invalide saisi: $choix"
            ;;
    esac
    
    echo
    echo -e -n "${JAUNE}Appuyez sur Entrée pour continuer...${RESET}"
    read dummy
done
