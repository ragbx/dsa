# Les datas sans aléas : analyser des métadonnées Marc avec Catmandu

## Problématique
Une fois que l'on sait ce que l'on doit chercher / vérifier au sein de nos notices, concrètement comment faire ? quels outils utiliser, sachant que les SIGB ne proposent pas nécessairement les fonctionnalités adéquates ?
=> on va partir de l'hypothèse qu'on est en mesure d'extraire du SIGB un fichier marc (ISO ou MARCXML) propre, auquel on va faire subir quelques transformations grâce à Catmandu pour effectuer ensuite une analyse avec des outils statistiques (tableur, etc...)

## Catmandu ?
Un outil de gestion de données spécifique aux formats et protocoles utilisés en bibliothèques, travail conjoint de développeurs issus des universités de Gand, Lund et Bielefeld. Pour aller plus loin (découvertes des fonctionnalités, installation, documentation technique, ...), voir le [site web du projet](http://librecat.org/).

### Principe :
- on donne des données en entrée (par exemple sous forme de fichier csv, xml, marc (iso ou xml), ...),

- on indique éventuellement quelles transformations appliquer,

- on récupère des données en sortie, que l'on va pouvoir intégrer dans un autre outil

### Pour mieux comprendre :
On entre un fichier MARC iso 2709 que l'on transforme en YAML.
```bash
$ catmandu convert MARC --type RAW to YAML < input/biblio.mrc
```

Même exemple que précédemment, mais on applique une transformation : on va extraire le titre de chaque document.
```bash
$ catmandu convert MARC --type RAW to YAML --fix 'marc_map(200a,titre)' < input/biblio.mrc
```
Pour cela, on utilise un langage simple, appelé "fix", dont on peut trouver le détail en [ligne](http://librecat.org/Catmandu/#fixes-cheat-sheet).


On indique qu'on ne souhaite retenir que les champs '_id' et 'titre' :
```bash
$ catmandu convert MARC --type RAW to YAML --fix 'marc_map(200a,titre) ; retain(_id,titre)' < input/biblio.mrc
```

Pour simplifier l'écriture, on peut regrouper les commandes fix dans un fichier :
```bash
$ catmandu convert MARC --type RAW to YAML --fix fix/demo.fix < input/biblio.mrc
```

## Trois exemples, à travers trois questions simples :
### Exemple 1 : Comment puis-je savoir si mes notices comportent des identifiants qui me permettront d'effectuer un alignement avec les données de la BnF ?
ce que l'on va faire : produire à partir d'un fichier marc un fichier csv comportant quelques colonnes essentielles qu'on analysera via un tableur.

#### Etapes :
1. On a exporté au préalable du SIGB les notices bibliographiques sous forme de fichier unimarc ISO 2709 encodé en UTF-8, que l'on nomme [input/biblio.mrc](https://github.com/medrbx/dsa/blob/master/input/biblio.mrc).
Ici, on utilisera un fichier représantant seulement 5 % des notices bibliographiques de Roubaix, pour accélerer les temps de traitement.

2. On crée un fichier fix pour Catmandu, que l'on nommera [fix/biblio.fix](https://github.com/medrbx/dsa/blob/master/fix/biblio.fix).

3. On exécute la commande suivante :
```bash
$ catmandu convert -v MARC --fix fix/biblio.fix to CSV < input/biblio.mrc > output/biblio.csv
```

4. On obtient alors un fichier [output/biblio.csv](https://github.com/medrbx/dsa/blob/master/output/biblio.csv), qu'on analysera via une table pivot dans un logiciel tableur (Excel ou Libre Office), via une table pivot.


### Exemple 2 : Comment connaître la composition d'un fichier autorités ? quelle part de notices récupérées auprès d'une agence comme la BnF ? quelle répartition selon les types d'autorités (nom de personne, nom de collectivité, sujet nom commun, ... )
ce que l'on va faire : produire à partir d'un fichier marc un fichier csv comportant quelques colonnes essentielles qu'on analysera via un tableur.

#### Etapes :
1. On a exporté au préalable du SIGB les notices autorités sous forme de fichier unimarc ISO 2709 encodé en UTF-8, que l'on nomme [input/auth.mrc](https://github.com/medrbx/dsa/blob/master/input/auth.mrc). Ici, on utilisera un fichier represantant seulement 5 % des notices autorités de Roubaix, pour accélerer les temps de traitement.


2. On crée un fichier fix pour Catmandu, que l'on nommera [fix/auth.fix](https://github.com/medrbx/dsa/blob/master/fix/auth.fix).

3. On exécute la commande suivante :
```bash
$ catmandu convert -v MARC --fix fix/auth.fix to CSV < input/auth.mrc > output/auth.csv
```

4. On obtient alors un fichier [output/auth.csv](https://github.com/medrbx/dsa/blob/master/output/auth.csv), qu'on analysera via une table pivot dans un logiciel tableur (Excel ou Libre Office), via une table pivot.


### Exemple 3 : Comment mettre en place un tableau de bord pour effectuer du contrôle qualité ?
ce que l'on va faire : pour suivre les imports et les remplacements effectués au quotidien, il est nécessaire de mettre en place des tableaux de bord, régulièrement mis à jour.
Montrer comment l'on peut faire cela simplement avec Elasticsearch / Kibana, grâce à des exports effectués via Catmandu.

#### Etapes :
1. On reprend les paires de fichiers biblio.mrc, biblio.fix et auth.mrc, auth.fix des deux exemples précédents.

2. On présuppose que l'on a au préalable installé et configuré Elasticsearch et Kibana.
On exécute les deux commandes suivantes :
```bash
$ catmandu import -v MARC --fix fix/biblio.fix to ES --index-name 'catmandu_ex' --bag 'biblio' < input/biblio.mrc
$ catmandu import -v MARC --fix fix/auth.fix to ES --index-name 'catmandu_ex' --bag 'auth' < input/auth.mrc
```
On obtient le tableau de bord suivant :
![Tableau de bord](https://github.com/medrbx/dsa/blob/master/doc/tableau_bord.png)

## Pour aller plus loin : Catmandu comme outil de prototypage
Réaliser les opérations d'alignement peuvent être complexes à réaliser au sein d'un SIGB, on peut en revanche réaliser des prototypes à l'aide de Catmandu.

Exemple : pour chaque notice du catalogue, lancer une requête sur le service SRU de la BnF pour récupérer un identifiant ark. Voir le script [bin/getArkBySru.pl](https://github.com/medrbx/dsa/blob/master/bin/getArkBySru.pl)
