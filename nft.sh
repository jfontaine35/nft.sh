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

# Dossier pour stocker les sauvegardes
BACKUP_DIR="/etc/nftables/backups"

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
    echo -e "${VERT}5)${RESET} Gestion des sauvegardes"
    echo -e "${ROUGE}q)${RESET} Quitter"
    echo
    echo -e -n "${GRAS}${JAUNE}Entrez le numéro de votre choix : ${RESET}"
    read choix
}

# Fonction pour afficher le menu de gestion des sauvegardes
afficher_menu_sauvegardes() {
    clear
    echo -e "${GRAS}${CYAN}=== GESTION DES SAUVEGARDES NFTABLES ===${RESET}"
    echo -e "${JAUNE}Choisis une option :${RESET}"
    echo -e "${VERT}1)${RESET} Sauvegarder la configuration actuelle"
    echo -e "${VERT}2)${RESET} Restaurer une configuration sauvegardée"
    echo -e "${VERT}3)${RESET} Lister les sauvegardes disponibles"
    echo -e "${VERT}4)${RESET} Supprimer une sauvegarde"
    echo -e "${VERT}5)${RESET} Activer le chargement automatique au démarrage"
    echo -e "${ROUGE}r)${RESET} Retour au menu principal"
    echo
    echo -e -n "${GRAS}${JAUNE}Entrez le numéro de votre choix : ${RESET}"
    read choix_sauvegarde
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

# Fonction modifiée pour supprimer une règle de forwarding
supprimer_regle_forwarding() {
    echo -e "${GRAS}${CYAN}Suppression d'une règle de forwarding${RESET}"
    echo -e "${GRIS}=======================================${RESET}"
    
    # Afficher les règles avec leur handle
    lister_ports_et_ip
    
    # Vérifier d'abord si des règles existent
    if ! sudo nft -a list table nat | grep -q "dnat to"; then
        echo -e "${JAUNE}Aucune règle de redirection de port à supprimer.${RESET}"
        ecrire_log "INFO" "Tentative de suppression sans règles existantes"
        return
    fi
    
    echo
    echo -e -n "${JAUNE}Entrez le handle de la règle à supprimer : ${RESET}"
    read handle_regle
    
    # Vérifier si l'entrée est un nombre
    if ! [[ "$handle_regle" =~ ^[0-9]+$ ]]; then
        echo -e "${ROUGE}Erreur: Le handle doit être un nombre.${RESET}"
        ecrire_log "ERREUR" "Handle invalide entré: $handle_regle"
        return
    fi
    
    # Vérifier si le handle existe réellement
    if ! sudo nft -a list table nat | grep -q "handle $handle_regle"; then
        echo -e "${ROUGE}Erreur: Handle $handle_regle non trouvé.${RESET}"
        ecrire_log "ERREUR" "Handle non trouvé: $handle_regle"
        return
    fi
    
    # Confirmation de suppression
    echo -e -n "${ROUGE}Êtes-vous sûr de vouloir supprimer cette règle ? (y/n) : ${RESET}"
    read confirmation
    if [[ $confirmation == "y" || $confirmation == "Y" ]]; then
        # Commande NFTables corrigée pour la suppression
        resultat=$(sudo nft delete rule nat PREROUTING handle $handle_regle 2>&1)
        
        # Vérifier si la commande a réussi
        if [ $? -eq 0 ]; then
            echo -e "${VERT}Règle supprimée avec succès.${RESET}"
            
            # Trouver et supprimer la règle FORWARD correspondante
            # Note: Ceci est une simplification, car nous ne pouvons pas facilement faire correspondre les règles FORWARD
            echo -e "${JAUNE}Note: Vérifiez si des règles FORWARD correspondantes doivent être supprimées.${RESET}"
            
            ecrire_log "INFO" "Règle avec handle $handle_regle supprimée avec succès"
        else
            echo -e "${ROUGE}Erreur lors de la suppression: $resultat${RESET}"
            ecrire_log "ERREUR" "Échec lors de la suppression du handle $handle_regle: $resultat"
        fi
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
    resultat_nat=$(sudo nft add rule nat PREROUTING iifname eth0 tcp dport $PortExterne counter dnat to $IP:$PortInterne 2>&1)
    
    # Vérifier si la commande a réussi
    if [ $? -eq 0 ]; then
        # Ajouter la règle de forwarding correspondante
        resultat_fwd=$(sudo nft add rule filter FORWARD ip daddr $IP tcp dport $PortInterne counter accept 2>&1)
        
        if [ $? -eq 0 ]; then
            echo -e "${VERT}Redirection configurée : Port $PortExterne vers $IP:$PortInterne${RESET}"
            ecrire_log "INFO" "Redirection ajoutée - Port $PortExterne vers $IP:$PortInterne"
        else
            echo -e "${ROUGE}Erreur lors de l'ajout de la règle FORWARD: $resultat_fwd${RESET}"
            ecrire_log "ERREUR" "Échec de l'ajout de la règle FORWARD: $resultat_fwd"
        fi
    else
        echo -e "${ROUGE}Erreur lors de l'ajout de la règle NAT: $resultat_nat${RESET}"
        ecrire_log "ERREUR" "Échec de l'ajout de la règle NAT: $resultat_nat"
    fi
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

# Fonction pour sauvegarder la configuration actuelle
sauvegarder_configuration() {
    echo -e "${GRAS}${CYAN}Sauvegarde de la configuration actuelle${RESET}"
    echo -e "${GRIS}=====================================${RESET}"
    
    # Créer le répertoire de sauvegarde s'il n'existe pas
    if [[ ! -d "$BACKUP_DIR" ]]; then
        sudo mkdir -p "$BACKUP_DIR"
        ecrire_log "INFO" "Répertoire de sauvegarde créé: $BACKUP_DIR"
    fi
    
    # Demander un nom pour la sauvegarde
    echo -e -n "${JAUNE}Entrez un nom pour cette sauvegarde (laissez vide pour timestamp auto) : ${RESET}"
    read backup_name
    
    # Utiliser un timestamp si aucun nom n'est fourni
    if [[ -z "$backup_name" ]]; then
        backup_name="nftables_$(date +%Y%m%d_%H%M%S)"
    else
        # Remplacer les espaces et caractères spéciaux par des underscores
        backup_name=$(echo "$backup_name" | sed 's/[^a-zA-Z0-9]/_/g')
    fi
    
    # Chemin complet du fichier de sauvegarde
    backup_file="$BACKUP_DIR/${backup_name}.nft"
    
    # Exporter les règles nftables actuelles
    sudo nft list ruleset > "$backup_file"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${VERT}Configuration sauvegardée avec succès dans $backup_file${RESET}"
        ecrire_log "INFO" "Configuration sauvegardée dans $backup_file"
        
        # Créer un fichier supplémentaire avec des informations sur la sauvegarde
        echo "Date de sauvegarde : $(date)" > "${backup_file}.info"
        echo "Description : Sauvegarde des règles nftables" >> "${backup_file}.info"
        
        # Optionnellement ajouter des statistiques sur les règles
        echo -e "Nombre de règles NAT: $(sudo nft list table nat 2>/dev/null | grep -c "dnat to")" >> "${backup_file}.info"
    else
        echo -e "${ROUGE}Erreur lors de la sauvegarde de la configuration.${RESET}"
        ecrire_log "ERREUR" "Échec de sauvegarde de la configuration"
    fi
}

# Fonction pour lister les sauvegardes disponibles
lister_sauvegardes() {
    echo -e "${GRAS}${CYAN}Liste des sauvegardes disponibles${RESET}"
    echo -e "${GRIS}===============================${RESET}"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "${JAUNE}Aucune sauvegarde trouvée.${RESET}"
        return
    fi
    
    # Compter le nombre de fichiers de sauvegarde
    backup_count=$(find "$BACKUP_DIR" -name "*.nft" | wc -l)
    
    if [[ $backup_count -eq 0 ]]; then
        echo -e "${JAUNE}Aucune sauvegarde trouvée dans $BACKUP_DIR${RESET}"
        return
    fi
    
    echo -e "${VERT}Sauvegardes disponibles :${RESET}"
    echo -e "${GRIS}------------------------${RESET}"
    
    # Afficher chaque sauvegarde avec ses métadonnées
    i=1
    for backup in "$BACKUP_DIR"/*.nft; do
        filename=$(basename "$backup")
        creation_date=$(stat -c %y "$backup")
        
        # Vérifier si un fichier d'information existe
        if [[ -f "${backup}.info" ]]; then
            description=$(grep "Description" "${backup}.info" | cut -d':' -f2- | sed 's/^[ \t]*//')
        else
            description="Pas de description disponible"
        fi
        
        # Extraire le nombre de règles
        rule_count=$(grep -c "dnat to" "$backup")
        
        echo -e "${GRAS}${VERT}$i)${RESET} ${GRAS}$filename${RESET}"
        echo -e "   ${GRIS}Créé le: ${RESET}$creation_date"
        echo -e "   ${GRIS}Description: ${RESET}$description"
        echo -e "   ${GRIS}Nombre de règles: ${RESET}$rule_count"
        echo
        
        i=$((i + 1))
    done
    
    ecrire_log "INFO" "Liste des sauvegardes affichée"
}

# Fonction pour restaurer une sauvegarde
restaurer_sauvegarde() {
    echo -e "${GRAS}${CYAN}Restauration d'une sauvegarde${RESET}"
    echo -e "${GRIS}============================${RESET}"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "${JAUNE}Aucune sauvegarde trouvée.${RESET}"
        return
    fi
    
    # Compter le nombre de fichiers de sauvegarde
    backup_count=$(find "$BACKUP_DIR" -name "*.nft" | wc -l)
    
    if [[ $backup_count -eq 0 ]]; then
        echo -e "${JAUNE}Aucune sauvegarde trouvée dans $BACKUP_DIR${RESET}"
        return
    fi
    
    # Lister les sauvegardes avec un index
    echo -e "${VERT}Sauvegardes disponibles :${RESET}"
    echo
    
    # Créer un tableau pour stocker les chemins des sauvegardes
    declare -a backup_files
    i=1
    
    for backup in "$BACKUP_DIR"/*.nft; do
        backup_files[$i]="$backup"
        filename=$(basename "$backup")
        creation_date=$(stat -c %y "$backup")
        
        echo -e "${GRAS}${VERT}$i)${RESET} $filename (Créé le: $creation_date)"
        i=$((i + 1))
    done
    
    echo
    echo -e -n "${JAUNE}Entrez le numéro de la sauvegarde à restaurer : ${RESET}"
    read backup_index
    
    # Vérifier si l'entrée est valide
    if ! [[ "$backup_index" =~ ^[0-9]+$ ]] || [[ $backup_index -lt 1 ]] || [[ $backup_index -ge $i ]]; then
        echo -e "${ROUGE}Numéro de sauvegarde invalide.${RESET}"
        ecrire_log "ERREUR" "Numéro de sauvegarde invalide: $backup_index"
        return
    fi
    
    # Récupérer le chemin de la sauvegarde sélectionnée
    selected_backup="${backup_files[$backup_index]}"
    
    echo -e "${JAUNE}Vous avez sélectionné : $(basename "$selected_backup")${RESET}"
    echo -e "${ROUGE}ATTENTION: La restauration remplacera toutes les règles actuelles.${RESET}"
    echo -e -n "${JAUNE}Êtes-vous sûr de vouloir continuer ? (y/n) : ${RESET}"
    read confirmation
    
    if [[ $confirmation == "y" || $confirmation == "Y" ]]; then
        # Sauvegarder la configuration actuelle avant restauration (sauvegarde automatique)
        auto_backup="$BACKUP_DIR/avant_restauration_$(date +%Y%m%d_%H%M%S).nft"
        sudo nft list ruleset > "$auto_backup"
        ecrire_log "INFO" "Configuration actuelle sauvegardée dans $auto_backup avant restauration"
        
        # Effacer les règles actuelles
        sudo nft flush ruleset
        
        # Restaurer les règles depuis la sauvegarde
        sudo nft -f "$selected_backup"
        
        if [[ $? -eq 0 ]]; then
            echo -e "${VERT}Configuration restaurée avec succès depuis $(basename "$selected_backup")${RESET}"
            ecrire_log "INFO" "Configuration restaurée depuis $(basename "$selected_backup")"
        else
            echo -e "${ROUGE}Erreur lors de la restauration. Tentative de restauration de la sauvegarde automatique...${RESET}"
            sudo nft -f "$auto_backup"
            
            if [[ $? -eq 0 ]]; then
                echo -e "${JAUNE}État précédent restauré.${RESET}"
                ecrire_log "AVERTISSEMENT" "Échec de restauration, état précédent restauré"
            else
                echo -e "${ROUGE}ERREUR CRITIQUE: Impossible de restaurer l'état précédent. Les règles nftables peuvent être corrompues.${RESET}"
                ecrire_log "ERREUR" "Échec de restauration de la sauvegarde et de l'état précédent"
            fi
        fi
    else
        echo -e "${JAUNE}Restauration annulée.${RESET}"
        ecrire_log "INFO" "Restauration annulée"
    fi
}
# Fonction pour supprimer une sauvegarde
supprimer_sauvegarde() {
    echo -e "${GRAS}${CYAN}Suppression d'une sauvegarde${RESET}"
    echo -e "${GRIS}===========================${RESET}"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "${JAUNE}Aucune sauvegarde trouvée.${RESET}"
        return
    fi
    
    # Compter le nombre de fichiers de sauvegarde
    backup_count=$(find "$BACKUP_DIR" -name "*.nft" | wc -l)
    
    if [[ $backup_count -eq 0 ]]; then
        echo -e "${JAUNE}Aucune sauvegarde trouvée dans $BACKUP_DIR${RESET}"
        return
    fi
    
    # Lister les sauvegardes avec un index
    echo -e "${VERT}Sauvegardes disponibles :${RESET}"
    echo
    
    # Créer un tableau pour stocker les chemins des sauvegardes
    declare -a backup_files
    i=1
    
    for backup in "$BACKUP_DIR"/*.nft; do
        backup_files[$i]="$backup"
        filename=$(basename "$backup")
        creation_date=$(stat -c %y "$backup")
        
        echo -e "${GRAS}${VERT}$i)${RESET} $filename (Créé le: $creation_date)"
        i=$((i + 1))
    done
    
    echo
    echo -e -n "${JAUNE}Entrez le numéro de la sauvegarde à supprimer : ${RESET}"
    read backup_index
    
    # Vérifier si l'entrée est valide
    if ! [[ "$backup_index" =~ ^[0-9]+$ ]] || [[ $backup_index -lt 1 ]] || [[ $backup_index -ge $i ]]; then
        echo -e "${ROUGE}Numéro de sauvegarde invalide.${RESET}"
        ecrire_log "ERREUR" "Numéro de sauvegarde invalide: $backup_index"
        return
    fi
    
    # Récupérer le chemin de la sauvegarde sélectionnée
    selected_backup="${backup_files[$backup_index]}"
    
    echo -e "${JAUNE}Vous avez sélectionné : $(basename "$selected_backup")${RESET}"
    echo -e "${ROUGE}ATTENTION: Cette action est irréversible.${RESET}"
    echo -e -n "${JAUNE}Êtes-vous sûr de vouloir supprimer cette sauvegarde ? (y/n) : ${RESET}"
    read confirmation
    
    if [[ $confirmation == "y" || $confirmation == "Y" ]]; then
        # Supprimer la sauvegarde et son fichier d'information associé
        sudo rm -f "$selected_backup" "${selected_backup}.info" 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            echo -e "${VERT}Sauvegarde supprimée avec succès.${RESET}"
            ecrire_log "INFO" "Sauvegarde supprimée: $(basename "$selected_backup")"
        else
            echo -e "${ROUGE}Erreur lors de la suppression de la sauvegarde.${RESET}"
            ecrire_log "ERREUR" "Échec de suppression de la sauvegarde: $(basename "$selected_backup")"
        fi
    else
        echo -e "${JAUNE}Suppression annulée.${RESET}"
        ecrire_log "INFO" "Suppression de sauvegarde annulée"
    fi
}

# Fonction pour activer le chargement automatique des règles au démarrage
activer_chargement_auto() {
    echo -e "${GRAS}${CYAN}Configuration du chargement automatique au démarrage${RESET}"
    echo -e "${GRIS}=================================================${RESET}"
    
    echo -e "${JAUNE}Cette option configurera nftables pour charger automatiquement les règles au démarrage.${RESET}"
    echo -e "${JAUNE}Les règles actuelles seront utilisées comme configuration par défaut.${RESET}"
    echo -e -n "${JAUNE}Voulez-vous continuer ? (y/n) : ${RESET}"
    read confirmation
    
    if [[ $confirmation == "y" || $confirmation == "Y" ]]; then
        # Sauvegarder les règles actuelles dans le fichier de configuration nftables
        sudo nft list ruleset > /tmp/current_rules.nft
        sudo cp /tmp/current_rules.nft /etc/nftables.conf
        
        # S'assurer que le service nftables est activé au démarrage
        sudo systemctl enable nftables
        
        # Créer un script systemd pour s'assurer que le forwarding IP est activé au démarrage
        if [[ ! -f /etc/systemd/system/ip-forward.service ]]; then
            echo "[Unit]
Description=Enable IP Forwarding
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/ip-forward.service > /dev/null
            
            sudo systemctl daemon-reload
            sudo systemctl enable ip-forward.service
            sudo systemctl start ip-forward.service
        fi
        
        echo -e "${VERT}Configuration terminée ! Les règles seront chargées automatiquement au démarrage.${RESET}"
        ecrire_log "INFO" "Chargement automatique des règles configuré"
    else
        echo -e "${JAUNE}Configuration annulée.${RESET}"
        ecrire_log "INFO" "Configuration du chargement automatique annulée"
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

# Fonction pour vérifier si une chaîne existe, si non la créer
verifier_creer_chaine() {
    local table="$1"
    local chaine="$2"
    local type="$3"
    local hook="$4"
    local priorite="$5"
    
    if ! sudo nft list chain ip $table $chaine 2>/dev/null; then
        sudo nft add chain ip $table $chaine { type $type hook $hook priority $priorite \; }
        ecrire_log "INFO" "Chaîne $chaine créée dans table $table"
    fi
}

# Créer les tables et chaînes NFTables si elles n'existent pas
setup_nftables() {
    # Vérifier si la table nat existe déjà
    if ! sudo nft list tables | grep -q "table ip nat"; then
        sudo nft add table ip nat
        ecrire_log "INFO" "Table nat créée"
    fi
    
    # Vérifier et créer la chaîne PREROUTING
    verifier_creer_chaine "nat" "PREROUTING" "nat" "prerouting" "-100"
    
    # Vérifier si la table filter existe
    if ! sudo nft list tables | grep -q "table ip filter"; then
        sudo nft add table ip filter
        ecrire_log "INFO" "Table filter créée"
    fi
    
    # Vérifier et créer la chaîne FORWARD
    verifier_creer_chaine "filter" "FORWARD" "filter" "forward" "0"
    
    # S'assurer que le forwarding IP est activé
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
        echo -e "${JAUNE}Activation du forwarding IP...${RESET}"
        sudo sysctl -w net.ipv4.ip_forward=1
        sudo sh -c 'echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf'
        sudo sysctl -p
        ecrire_log "INFO" "Forwarding IP activé"
    fi
}

# Initialisation des tables et chaînes NFTables
setup_nftables

# Créer le répertoire de sauvegarde s'il n'existe pas déjà
if [[ ! -d "$BACKUP_DIR" ]]; then
    sudo mkdir -p "$BACKUP_DIR"
    ecrire_log "INFO" "Répertoire de sauvegarde créé: $BACKUP_DIR"
fi

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
        5)
            # Sous-menu pour la gestion des sauvegardes
            while true; do
                afficher_menu_sauvegardes
                case $choix_sauvegarde in
                    1)
                        sauvegarder_configuration
                        ;;
                    2)
                        restaurer_sauvegarde
                        ;;
                    3)
                        lister_sauvegardes
                        ;;
                    4)
                        supprimer_sauvegarde
                        ;;
                    5)
                        activer_chargement_auto
                        ;;
                    r|R)
                        break
                        ;;
                    *)
                        echo -e "${ROUGE}Choix non valide. Veuillez réessayer.${RESET}"
                        ecrire_log "AVERTISSEMENT" "Choix invalide saisi dans le menu de sauvegarde: $choix_sauvegarde"
                        ;;
                esac
                
                echo
                echo -e -n "${JAUNE}Appuyez sur Entrée pour continuer...${RESET}"
                read dummy
            done
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
