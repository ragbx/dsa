# Les datas sans aléas : analyser des métadonnées Marc avec Catmandu

## Problématique
Une fois que l'on sait ce que l'on doit chercher / vérifier au sein de nos notices, concrètement comment faire ? quels outils utiliser, sachant que les SIGB ne proposent pas nécessairement les fonctionnalités adéquates ?
=> on va partir de l'hypothèse qu'on est en mesure d'extraire du SIGB un fichier marc (ISO ou MARCXML propre), pour l'analyser grâce à Catmandu

## Catmandu ?
Un ETL spécifique aux formats et protocoles utilisés en bibliothèques.
Principe : on donne des données en entrée (par exemple sous forme de fichier marc), on indique quels transformations appliquer, on récupère des données en sortie, que l'on va pouvoir intégrer dans un autre outil
**TO DO : illustrer concrètement**

## Trois exemples, à travers trois questions simples :
### Exemple 1 : Comment puis-je savoir si mes notices comportent des identifiants qui me permettront d'effectuer un alignement avec les données de la BnF ?
ce que l'on va faire : produire à partir d'un fichier marc un fichier csv comportant quelques colonnes essentielles qu'on analysera via un tableur.

#### Etapes :
1. On a exporté au préalable du SIGB les notices bibliographiques sous forme de fichier unimarc ISO 2709, que l'on nomme biblio.mrc. Ici, on utilisera un fichier représantant seulement 5 % des notices bibliographiques de Roubaix, pour accéler les temps de traitement.

2. On crée un fichier fix pour Catmandu, que l'on nommera fix/biblio.fix :
```
copy_field(_id,biblionumber)

marc_map(010a,isbn)
marc_map(011a,issn)
marc_map(073a,ean)

if exists(ean)
    add_field(identifiant,'ean')
elsif exists(issn)
    add_field(identifiant,'issn')
elsif exists(isbn)
    add_field(identifiant,'isbn')
else
    add_field(identifiant,'NC')
end

# On cherche le type de notice en fonction du label position 6 :
marc_map(LDR_/6,type_notice)
lookup(type_notice, "fix/lk_type_notice.txt", sep_char:"|", default:NC)

# On cherche à savoir si la notice décrit ou pas des documents patrimoniaux, pour cela on se base sur le champ exemplaire 995h
marc_map(995h,collection)
if any_match(collection,"^P")
    add_field(patrimoine,"oui")
else
    add_field(patrimoine,"non")
end

# On ne retient que les champs suivants :
retain(numero_biblio, type_notice, identifiant, patrimoine)
```
3. On exécute la commande suivante :
```bash
$ catmandu convert -v MARC --fix fix/biblio.fix to CSV < input/biblio.mrc > output/biblio.csv
```
On obtient alors un fichier csv de cette forme, qu'on analysera via une table pivot dans un logiciel tableur :
```csv
identifiant,numero_biblio,patrimoine,type_notice
NC,283,oui,"Ressource textuelle"
NC,319,non,"Ressource textuelle"
isbn,358,non,"Ressource textuelle"
NC,391,non,"Enregistrement sonore musical"
isbn,415,non,"Ressource textuelle"
...
```
4. On analyse enfin le fichier obtenu dans un tableau (Excel ou Libre Office), via une table pivot.


### Exemple 2 : Comment connaître la composition d'un fichier autorités ? quelle part de notices récupérées auprès d'une agence comme la BnF ? quelle répartition selon les types d'autorités (nom de personne, nom de collectivité, sujet nom commun, ... )
ce que l'on va faire : produire à partir d'un fichier marc un fichier csv comportant quelques colonnes essentielles qu'on analysera via un tableur.

#### Etapes :
1. On a exporté au préalable du SIGB les notices autoprités sous forme de fichier unimarc ISO 2709, que l'on nomme auth.mrc. Ici, on utilisera un fichier represantant seulement 5 % des notices autorités de Roubaix, pour accéler les temps de traitement.


2. On crée un fichier fix pour Catmandu, que l'on nommera fix/auth.fix :
```
# identifiant RBX
copy_field(_id,authnumber)

# 009 : ark BnF
marc_map(009_,auth_ark_bnf)
if any_match(auth.ark_bnf, 'catalogue.bnf.fr')
     add_field(origine, 'BnF')
else
     add_field(origine, 'Roubaix')
end

# On détermine le type d'autorité
marc_map(200,np)
marc_map(210,co)
marc_map(215,sng)
marc_map(220,fam)
marc_map(230,tu)
marc_map(240,sauttit)
marc_map(250,snc)


if exists(np)
    add_field(type_notice, 'nom_personne')
elsif exists(co)
    add_field(type_notice, 'nom_collectivite')
elsif exists(sng)
    add_field(type_notice, 'nom_geographique')
elsif exists(fam)
    add_field(type_notice, 'famille')
elsif exists(tu)
    add_field(type_notice, 'titre_uniforme')
elsif exists(sauttit)
    add_field(type_notice, 'auteur_titre')
elsif exists(snc)
    add_field(type_notice, 'matiere_nom_commun')
end

# On ne retient que les champs utiles
retain(authnumber, type_notice, origine)
```
3. On se place dans le répertoire contenant le fichier marc et on exécute la commande suivante :
```bash
$ catmandu convert -v MARC --fix fix/auth.fix to CSV < input/auth.mrc > output/auth.csv
```
On obtient alors un fichier csv de cette forme, qu'on analysera via une table pivot dans un logiciel tableur :
```csv
authnumber,origine,type_notice
271031,BnF,matiere_nom_commun
271051,BnF,nom_personne
271071,BnF,nom_personne
271091,BnF,nom_personne
271111,Roubaix,matiere_nom_commun
...
```
4. On analyse enfin le fichier obtenu dans un tableau (Excel ou Libre Office), via une table pivot.


### Exemple 3 : Comment mettre en place un tableau de bord pour effectuer du contrôle qualité ?
ce que l'on va faire : pour suivre les imports et les remplacements effectués au quotidien, il est nécessaire de mettre en place des tableaux de bord, régulièrement mis à jour.
Montrer comment l'on peut faire cela simplement avec Elasticsearch / Kibana, grâce à des exports effectués via Catmandu.

#### Etapes :
1. On reprend les paires de fichiers biblio.mrc, biblio.fix et auth.mrc, auth.fix des deux exemples précédents.

2. On présuppose que l'on a au préalable installé et configuré Elasticsearch et Kibana.
On exécute les deux commandes suivantes :
```bash
$ catmandu import -v MARC --fix fix/biblio.fix to ES --index-name 'catmandu_ex' --bag 'biblio' < input/biblio.mrc
$ catmandu import -v MARC --fix fix/auth.fix to ES --index-name 'catmandu_ex' --bag 'auth' < input/.auth.mrc
```
On obtient le tableau de bord suivant :
![Tableau de bord](https://github.com/medrbx/dsa/blob/master/doc/tableau_bord.png)

## Pour aller plus loin : Catmandu comme outil de prototypage
Réaliser les opérations d'alignement peuvent être complexes à réaliser au sein d'un SIGB, on peut en revanche réaliser des prototypes à l'aide de Catmandu.

Exemple : pour chaque notice du catalogue, lancer une requête sur le service SRU de la BnF (encore version bêta...) pour récupérer un identifiant ark et l'ajouter à la notice locale.
** TO DO : mettre un lien vers un tel script (qui sera en perl) => pas le lieu pour discuter pour cela **
