# Rapport Complet du Projet : Tour de Ville

## Introduction

Le projet **Tour de Ville** est une implémentation d'un problème d'optimisation combinatoire inspiré du **problème du voyageur de commerce (TSP)**. L'objectif est de trouver un circuit valide dans une grille, en respectant des contraintes spécifiques sur les lignes et les colonnes. Ce projet utilise des outils de modélisation mathématique pour résoudre des instances interactives et fournir des résultats optimaux.

---

## Objectifs du Projet

1. **Modéliser un problème d'optimisation combinatoire** :
   - Définir des variables binaires pour représenter les cases visitées et les connexions entre elles.
   - Ajouter des contraintes pour respecter les spécifications du problème.

2. **Éviter les sous-tours** :
   - Identifier et éliminer dynamiquement les sous-tours dans les solutions proposées.

3. **Fournir une interface interactive** :
   - Permettre à l'utilisateur de choisir parmi plusieurs exemples prédéfinis.
   - Afficher les résultats de manière claire et lisible.

4. **Mesurer les performances** :
   - Chronométrer le temps d'exécution pour chaque instance.

---

## Fonctionnalités

### 1. Modélisation Mathématique
Le projet utilise **JuMP**, une bibliothèque Julia pour la modélisation mathématique, et **Cbc**, un solveur d'optimisation. Les principales variables et contraintes sont :

- **Variables** :
  - `x[i, j]` : Indique si la case `(i, j)` est visitée.
  - `c[i1, j1, i2, j2]` : Indique s'il existe un chemin entre les cases `(i1, j1)` et `(i2, j2)`.

- **Contraintes** :
  - Chaque ligne et colonne doit contenir un nombre fixe de cases visitées.
  - Les arcs (connexions) ne peuvent exister qu'entre des cases voisines.
  - Chaque case visitée doit avoir un arc entrant et un arc sortant.

### 2. Élimination des Sous-Tours
Le programme détecte les sous-tours dans les solutions proposées et ajoute dynamiquement des contraintes pour les éliminer. Cette approche est inspirée des techniques utilisées pour résoudre le TSP.

### 3. Interaction Utilisateur
L'utilisateur peut choisir parmi plusieurs exemples prédéfinis (Jeux 1 à Jeux 5). Le programme résout l'exemple choisi et affiche les résultats, y compris une représentation visuelle de la grille.

### 4. Chronométrage
Le temps d'exécution pour chaque exemple est mesuré à l'aide de la macro `@elapsed` et affiché à l'utilisateur.

---

## Structure du Code

### Fichiers

- **`jeux_de_grille.jl`** : Contient le code principal du projet, y compris la modélisation, la résolution et l'interaction utilisateur.
- **`test.txt`** : Fichier contenant les temps d'exécution pour différents exemples.

### Fonctions Principales

1. **`tour_de_ville(li, lj)`** :
   - Résout le problème pour une grille donnée avec des contraintes sur les lignes (`li`) et les colonnes (`lj`).
   - Évite les sous-tours en ajoutant dynamiquement des contraintes.

2. **`detecte_sous_tours(c_sol, size_i, size_j)`** :
   - Détecte les sous-tours dans la solution actuelle.

3. **`suivant_case(c_sol, i, j, size_i, size_j)`** :
   - Trouve la case suivante dans un circuit donné.

4. **`main()`** :
   - Gère l'interaction utilisateur et appelle les fonctions nécessaires pour résoudre le problème.

---

## Résultats des Tests

Les temps d'exécution pour les différents exemples sont enregistrés dans le fichier `test.txt` :

```plaintext
jeux 1 : 16.6 S
jeux 2 : 16.8 s
jeux 3 : 16.8 s
jeux 4 : 17,1 s
jeux 5 : 25.975 
jeux 6 : trop grand