# Rapport du Projet Solveur de Tour de Grille

## Aperçu du Projet

Ce projet implémente une solution d'optimisation mathématique pour le problème "Tour de Ville" sur une grille. Le problème consiste à trouver un chemin continu unique qui visite un nombre spécifique de cellules dans chaque ligne et colonne d'une grille, selon des paramètres d'entrée définis.

## Définition du Problème

Données :
- Une grille de taille m×n
- Des tableaux spécifiant le nombre de cellules à visiter dans chaque ligne (li) et colonne (lj)

L'objectif est de trouver un chemin valide qui :
1. Visite exactement le nombre spécifié de cellules dans chaque ligne et colonne
2. Forme un circuit continu unique (sans sous-tours)
3. Ne se déplace qu'entre des cellules orthogonalement adjacentes (haut, bas, gauche, droite)

## Approche d'Implémentation

La solution utilise la Programmation Linéaire en Nombres Entiers (PLNE) à travers le langage de modélisation JuMP avec le solveur Cbc en Julia. L'approche comprend :

### Variables
- Variables de décision binaires `x[i,j]` indiquant si la cellule (i,j) est visitée
- Variables de décision binaires `c[i1,j1,i2,j2]` indiquant s'il existe un segment de chemin de la cellule (i1,j1) à la cellule (i2,j2)

### Contraintes et leur Utilité

1. **Contraintes de ligne et colonne**:
   ```julia
   @constraint(model, ligne[i in 1:size_i], sum(x[i,j] for j in 1:size_j) == li[i])
   @constraint(model, colonne[j in 1:size_j], sum(x[i,j] for i in 1:size_i) == lj[j])
   ```
   - **Utilité**: Ces contraintes garantissent que le nombre exact de cellules visitées dans chaque ligne et colonne correspond aux valeurs spécifiées dans les tableaux d'entrée. Elles sont fondamentales pour respecter les règles du problème.

2. **Contraintes sur les arcs entre cellules non-adjacentes**:
   ```julia
   @constraint(model, pas_voisin[i1 in 1:size_i, j1 in 1:size_j, i2 in 1:size_i, j2 in 1:size_j; abs(i1-i2) + abs(j1-j2) != 1], c[i1,j1,i2,j2] == 0)
   ```
   - **Utilité**: Cette contrainte empêche la création d'arcs entre des cellules qui ne sont pas orthogonalement adjacentes. Elle utilise la distance de Manhattan (abs(i1-i2) + abs(j1-j2)) pour déterminer l'adjacence. Cette contrainte est essentielle pour respecter la règle de déplacement orthogonal uniquement.

3. **Contraintes sur l'existence des arcs**:
   ```julia
   @constraint(model, arc_source[i1 in 1:size_i, j1 in 1:size_j, i2 in 1:size_i, j2 in 1:size_j], c[i1,j1,i2,j2] <= x[i1,j1])
   @constraint(model, arc_dest[i1 in 1:size_i, j1 in 1:size_j, i2 in 1:size_i, j2 in 1:size_j], c[i1,j1,i2,j2] <= x[i2,j2])
   ```
   - **Utilité**: Ces contraintes garantissent qu'un arc ne peut exister que si ses deux extrémités (cellules source et destination) sont visitées. Cela lie les variables d'arc `c` aux variables de visite de cellule `x`, assurant la cohérence du modèle.

4. **Contraintes de flux**:
   ```julia
   @constraint(model, entrant[i in 1:size_i, j in 1:size_j], sum(c[i1,j1,i,j] for i1 in 1:size_i, j1 in 1:size_j) == x[i,j])
   @constraint(model, sortant[i in 1:size_i, j in 1:size_j], sum(c[i,j,i2,j2] for i2 in 1:size_i, j2 in 1:size_j) == x[i,j])
   ```
   - **Utilité**: Ces contraintes de conservation de flux assurent que chaque cellule visitée a exactement un arc entrant et un arc sortant. C'est un élément crucial pour former un chemin continu, garantissant que l'on entre et sort de chaque cellule visitée exactement une fois.

5. **Contraintes d'élimination des sous-tours** (ajoutées dynamiquement):
   ```julia
   @constraint(model, sum(c[i1,j1,i2,j2] for (i1,j1) in sous_tour for (i2,j2) in sous_tour if (i1 != i2 || j1 != j2) && abs(i1-i2) + abs(j1-j2) == 1) <= length(sous_tour) - 1)
   ```
   - **Utilité**: Ces contraintes sont ajoutées dynamiquement après chaque résolution du modèle lorsque des sous-tours sont détectés. Elles limitent le nombre d'arcs à l'intérieur d'un sous-tour à être strictement inférieur au nombre de cellules dans ce sous-tour, forçant ainsi la connexion avec le reste du circuit. C'est une adaptation de la méthode classique d'élimination des sous-tours utilisée dans le problème du voyageur de commerce (TSP).

### Élimination des Sous-tours

L'algorithme utilise une approche itérative pour détecter et éliminer les sous-tours :
1. Résoudre le problème PLNE initial
2. Détecter si plusieurs circuits séparés existent dans la solution
3. Ajouter des contraintes pour éliminer les sous-tours détectés
4. Résoudre à nouveau le PLNE et répéter jusqu'à ce qu'un tour unique soit trouvé

## Visualisation

La solution est visualisée sous forme textuelle, montrant :
- Les nombres en haut représentant les contraintes de colonne
- Les nombres à gauche représentant les contraintes de ligne
- Des astérisques (*) indiquant les cellules visitées
- Des connexions de chemin entre les cellules

Format de sortie exemple :
```
    3   4   3   3   5  
   ---------------------
4  |   |   |   | * |   |
   |   |   |   |** |   |
   |   |   |   | * |   |
   ---------------------
5  |   | * | * | * | * |
   |   |** |** |** |** |
   |   | * | * | * | * |
   ---------------------
...
```

## Analyse de Performance

Le programme a été testé sur 5 différentes configurations de grille avec les temps d'exécution suivants :

| Cas de Test | Temps d'Exécution (secondes) |
|-------------|------------------------------|
| Jeux 1      | 16,6                         |
| Jeux 2      | 16,8                         |
| Jeux 3      | 16,8                         |
| Jeux 4      | 17,1                         |
| Jeux 5      | 25,975                       |
| Jeux 6      | Trop grand (non résolvable)  |

Le temps d'exécution augmente avec la complexité et la taille de la grille, comme attendu pour un problème NP-difficile.

## Structure du Code

Les composants principaux de l'implémentation comprennent :

1. **`tour_de_ville()`** : La fonction principale qui configure et résout le modèle PLNE
2. **`detecte_sous_tours()`** : Fonction auxiliaire pour identifier les sous-tours dans la solution actuelle
3. **`suivant_case()`** : Fonction auxiliaire pour trouver la cellule suivante dans un chemin
4. **`main()`** : Fonction pilote pour sélectionner et exécuter les cas de test

## Complexité Algorithmique

Le problème est computationnellement complexe en raison de :
- Variables binaires qui évoluent en O(n²) pour les visites de cellules et en O(n⁴) pour les segments de chemin
- La nature NP-difficile de la recherche d'un chemin hamiltonien avec contraintes
- L'approche itérative nécessaire pour l'élimination des sous-tours

## Limitations

- Les grandes tailles de grille (comme le cas de test 6) deviennent computationnellement infaisables
- L'algorithme utilise une limite maximale d'itérations (100) pour l'élimination des sous-tours
- L'approche est gourmande en mémoire en raison du grand nombre de variables binaires

## Améliorations Possibles

1. **Efficacité de l'Algorithme** :
   - Implémenter des techniques plus sophistiquées d'élimination des sous-tours
   - Utiliser des contraintes de cassure de symétrie pour réduire l'espace de recherche
   
2. **Optimisation des Performances** :
   - Utiliser un mécanisme de démarrage à chaud avec des solutions heuristiques
   - Envisager une approche de génération de colonnes pour les instances plus grandes
   
3. **Interface Utilisateur** :
   - Implémenter une visualisation graphique
   - Permettre la saisie manuelle des contraintes de grille
   - Prendre en charge l'enregistrement/chargement des instances de problème

## Conclusion

Cette implémentation résout avec succès le problème du "Tour de Ville" sur une grille en utilisant la programmation linéaire en nombres entiers. La solution est efficace pour des grilles de taille modérée mais fait face à des défis de scalabilité pour des instances plus grandes, ce qui est attendu étant donné la nature combinatoire du problème.
