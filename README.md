# Gestion des règles NFTables

## Description
Ce script Bash permet de gérer les règles de redirection de ports (port forwarding) avec NFTables. Il offre une interface interactive en ligne de commande pour lister, ajouter, supprimer des règles de forwarding et afficher les logs associés.

## Fonctionnalités principales
- Lister les règles existantes avec les détails des IP source/destination et des ports.
- Ajouter une règle de redirection de port.
- Supprimer une règle existante via son handle.
- Afficher les logs des actions effectuées par le script.
- Vérification et configuration automatique des tables et chaînes NFTables nécessaires.

## Prérequis
Avant d'utiliser ce script, assurez-vous que :
- NFTables est installé sur votre système. Si ce n'est pas le cas, le script tentera de l'installer automatiquement.
- Vous disposez des permissions suffisantes (exécution avec sudo).
- Le fichier de log `/var/log/nft.log` est accessible en écriture.

## Installation
1. Clonez le dépôt GitHub contenant ce script :
   ```bash
   git clone https://github.com/jfontaine35/nft.sh.git
   cd nft
   ```

2. Rendez le script exécutable :
   ```bash
   chmod +x nft.sh
   ```

3. Exécutez le script avec sudo :
   ```bash
   sudo ./nft.sh
   ```

## Utilisation
### Menu principal
Le script affiche un menu interactif avec les options suivantes :
1. Lister les règles existantes : Affiche les détails des règles configurées dans NFTables (ports externes/internes, IP locale).
2. Ajouter une règle : Configure une nouvelle redirection de port en spécifiant le port externe, interne et l'IP locale.
3. Supprimer une règle : Supprime une règle existante en fournissant son handle.
4. Afficher les logs : Montre les dernières entrées du journal `/var/log/nft.log`.
5. Quitter : Ferme le script.

### Exemple d'utilisation
#### Ajouter une règle de port forwarding
1. Choisissez l'option 3 dans le menu.
2. Entrez :
   - Le port externe à rediriger (exemple : 8080).
   - Le port interne correspondant (exemple : 80).
   - L'octet final de l'adresse IP locale (exemple : 42 pour 192.168.100.42).
3. Le script configurera automatiquement la redirection.

#### Supprimer une règle
1. Choisissez l'option 2.
2. Identifiez la règle à supprimer via son handle (affiché dans la liste des règles).
3. Confirmez la suppression.

## Logs
Le script génère un fichier de log situé dans `/var/log/nft.log`. Ce fichier contient des informations sur :
- Les actions effectuées (ajout/suppression de règles).
- Les erreurs ou avertissements rencontrés.

Exemple d'entrée dans le log :
```
[2025-04-11 10:00:00] [INFO] Redirection ajoutée - Port 8080 vers 192.168.100.42:80
[2025-04-11 10:05:00] [ERREUR] Tentative de suppression avec handle invalide: 12345
```

## Configuration automatique
Lors du premier lancement, le script vérifie et configure automatiquement :
- La table `nat` et sa chaîne `PREROUTING`.
- La table `filter` et sa chaîne `FORWARD`.

Si ces éléments n'existent pas, ils seront créés.

## Points importants
- Ce script utilise la commande `nft`. Assurez-vous que vos règles sont compatibles avec NFTables.
- Les modifications apportées par ce script sont immédiates et affectent directement la configuration réseau.

## Dépendances
Le script repose sur :
- NFTables : Gestion des règles réseau.
- Bash : Interpréteur pour exécuter le script.

## Contributions
Les contributions sont les bienvenues ! Si vous souhaitez améliorer ce projet, ouvrez une issue ou soumettez une pull request sur GitHub.

## Licence
Ce projet est sous licence [MIT](licence.txt). Vous êtes libre d'utiliser, modifier et redistribuer ce code sous les conditions de cette licence.

## Auteur
Script développé par SI H3Campus.

