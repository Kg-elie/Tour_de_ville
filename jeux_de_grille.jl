using JuMP, Cbc
#using HiGHS

function tour_de_ville(li::Array{Int64}, lj::Array{Int64})
    size_i = size(li,1)
    size_j = size(lj,1)

    model = Model(Cbc.Optimizer)
    #model = Model(HiGHS.Optimizer)
    
    # Variables principales
    @variable(model, x[i in 1:size_i, j in 1:size_j], Bin) # Si la case est visitée
    @variable(model, c[i1 in 1:size_i, j1 in 1:size_j, i2 in 1:size_i, j2 in 1:size_j], Bin) # Chemin entre les cases
    
    @objective(model, Max, 0)

    # Contraintes sur les nombres de cases par ligne/colonne
    @constraint(model, ligne[i in 1:size_i], sum(x[i,j] for j in 1:size_j) == li[i])
    @constraint(model, colonne[j in 1:size_j], sum(x[i,j] for i in 1:size_i) == lj[j])
    
    # Contraintes sur les arcs
    # Un arc ne peut exister qu'entre cases voisines
    @constraint(model, pas_voisin[i1 in 1:size_i, j1 in 1:size_j, i2 in 1:size_i, j2 in 1:size_j; abs(i1-i2) + abs(j1-j2) != 1], 
                c[i1,j1,i2,j2] == 0)
    
    # Un arc ne peut exister que si les deux cases sont visitées
    @constraint(model, arc_source[i1 in 1:size_i, j1 in 1:size_j, i2 in 1:size_i, j2 in 1:size_j], 
                c[i1,j1,i2,j2] <= x[i1,j1])
    @constraint(model, arc_dest[i1 in 1:size_i, j1 in 1:size_j, i2 in 1:size_i, j2 in 1:size_j],
                c[i1,j1,i2,j2] <= x[i2,j2])
    
    # Contraintes de flux - chaque case visitée a un arc entrant et un arc sortant
    @constraint(model, entrant[i in 1:size_i, j in 1:size_j], 
                sum(c[i1,j1,i,j] for i1 in 1:size_i, j1 in 1:size_j) == x[i,j])
    @constraint(model, sortant[i in 1:size_i, j in 1:size_j], 
                sum(c[i,j,i2,j2] for i2 in 1:size_i, j2 in 1:size_j) == x[i,j])
    
    set_silent(model)
    optimize!(model)

    # Résoudre et vérifier les sous-tours - approche inspirée du TSP
    sous_tours_elimines = false
    iterations = 0
    max_iterations = 100
    
    while !sous_tours_elimines && iterations < max_iterations
        x_sol = round.(Int64, value.(x))
        c_sol = round.(Int64, value.(c))
        
        # Détecter les sous-tours
        sous_tours = detecte_sous_tours(c_sol, size_i, size_j)
        
        if length(sous_tours) == 1
            sous_tours_elimines = true
            println("Solution trouvée sans sous-tours après $iterations itérations.")
        else
            println("Détection de $(length(sous_tours)) sous-tours. Ajout de contraintes...")
            
            # Ajouter des contraintes pour éliminer chaque sous-tour
            for sous_tour in sous_tours
                if length(sous_tour) < sum(li) # Ne pas éliminer un tour complet
                    # Créer la contrainte: pour chaque sous-tour S, 
                    # la somme des arcs à l'intérieur de S doit être <= |S| - 1
                    # Format des index dans sous_tour: [(i1,j1), (i2,j2), ...]
                    @constraint(model, sum(c[i1,j1,i2,j2] 
                                           for (i1,j1) in sous_tour 
                                           for (i2,j2) in sous_tour 
                                           if (i1 != i2 || j1 != j2) && abs(i1-i2) + abs(j1-j2) == 1) 
                                <= length(sous_tour) - 1)
                end
            end
            
            iterations += 1
            optimize!(model)
        end
    end
    
    if termination_status(model) == MOI.OPTIMAL && sous_tours_elimines
        x_sol = round.(Int64, value.(x))
        c_sol = round.(Int64, value.(c))
        
        # Affichage des nombres en haut
        print("    ")
        for j in 1:size_j
            print("   ", lj[j], "    ")
        end 
        println("")
        
        # Affichage de la grille
        println("   " * "-" ^ (size_j * 4 * 2 + 1))
        
        for i in 1:size_i
            # Première ligne de chaque case
            print("   |")
            for j in 1:size_j
                if x_sol[i,j] == 1 && i > 1 && (c_sol[i,j,i-1,j] == 1 || c_sol[i-1,j,i,j] == 1)
                    print("   *   |") # Connection vers le haut
                else
                    print("       |")
                end
            end
            println("")
            
            # Deuxième ligne de chaque case
            print(li[i],"  |")
            for j in 1:size_j
                if x_sol[i,j] == 1
                    left = (j > 1 && (c_sol[i,j,i,j-1] == 1 || c_sol[i,j-1,i,j] == 1))
                    right = (j < size_j && (c_sol[i,j,i,j+1] == 1 || c_sol[i,j+1,i,j] == 1))
                    
                    if left && right
                        print(" * * * |") # Connexion gauche et droite
                    elseif left
                        print(" * *   |") # Connexion gauche
                    elseif right
                        print("   * * |") # Connexion droite
                    else
                        print("   *   |") # Juste un marqueur pour la case visitée
                    end
                else
                    print("       |")
                end
            end
            println("")
            
            # Troisième ligne de chaque case
            print("   |")
            for j in 1:size_j
                if x_sol[i,j] == 1 && i < size_i && (c_sol[i,j,i+1,j] == 1 || c_sol[i+1,j,i,j] == 1)
                    print("   *   |") # Connection vers le bas
                else
                    print("       |")
                end
            end
            println("")
            
            println("   " * "-" ^ (size_j * 4 * 2 + 1))
        end
        
        # Vérification finale du circuit
        sous_tours = detecte_sous_tours(c_sol, size_i, size_j)
        println("\nRésumé:")
        println("- Nombre total de cases visitées: ", sum(x_sol))
        println("- Nombre attendu de cases: ", sum(li))
        println("- Nombre de circuits distincts: ", length(sous_tours))
        
        if length(sous_tours) == 1
            println("✓ Circuit unique valide trouvé!")
            println("  Longueur du circuit: ", length(sous_tours[1]), " cases")
        else
            println("⚠ Attention: $(length(sous_tours)) circuits distincts trouvés:")
            for (idx, tour) in enumerate(sous_tours)
                println("  Circuit $idx: $(length(tour)) cases")
            end
        end
    else
        println("Pas de solution optimale trouvée ou sous-tours non éliminés")
        println("Status: ", termination_status(model))
        println("Nombre d'itérations: ", iterations)
    end
end

# Fonction pour détecter tous les sous-tours dans la solution
function detecte_sous_tours(c_sol, size_i, size_j)
    # Créer un ensemble de toutes les cases visitées
    cases_visitees = Set()
    for i in 1:size_i
        for j in 1:size_j
            if sum(c_sol[i,j,:,:]) > 0 || sum(c_sol[:,:,i,j]) > 0
                push!(cases_visitees, (i,j))
            end
        end
    end
    
    sous_tours = []
    
    while !isempty(cases_visitees)
        # Prendre une case comme point de départ
        start = first(cases_visitees)
        
        # Construire le sous-tour à partir de ce point
        sous_tour = [start]
        delete!(cases_visitees, start)
        courant = suivant_case(c_sol, start[1], start[2], size_i, size_j)
        
        while courant != start && courant !== nothing
            push!(sous_tour, courant)
            delete!(cases_visitees, courant)
            courant = suivant_case(c_sol, courant[1], courant[2], size_i, size_j)
        end
        
        # Si le sous-tour est fermé, l'ajouter à la liste
        if courant == start
            push!(sous_tours, sous_tour)
        else
            # Si le sous-tour n'est pas fermé, c'est un chemin ouvert
            println("Attention: chemin ouvert détecté!")
            push!(sous_tours, sous_tour)
        end
    end
    
    return sous_tours
end

# Fonction pour trouver la case suivante dans le circuit
function suivant_case(c_sol, i, j, size_i, size_j)
    for ni in 1:size_i
        for nj in 1:size_j
            if c_sol[i,j,ni,nj] == 1
                return (ni, nj)
            end
        end
    end
    return nothing  # Aucun successeur trouvé
end

function main()
    print("Entrez le numéro de l'exemple à résoudre (1-8) : ")
    
    choix = parse(Int64, readline())
    
    lignes = []
    colonnes = []
    
    if choix == 1
        lignes = [4,5,3,3,3]
        colonnes = [3,4,3,3,5]
    elseif choix == 2
        lignes = [3,5,2,5,3]
        colonnes = [3,2,4,5,4]
    elseif choix == 3
        lignes = [3,4,5,4,2]
        colonnes = [4,4,3,3,4]
    elseif choix == 4
        lignes = [3,4,3,2,6,2]
        colonnes = [4,4,2,3,2,5]
    elseif choix == 5
        lignes = [4,5,5,2,5,5]
        colonnes = [4,5,4,5,5,3]
    elseif choix == 6
        lignes = [6,6,7,6,4,7,6]
        colonnes = [7,7,6,4,7,5,6]
    elseif choix == 7
        lignes = [8,5,5,4,7,5,6,8]
        colonnes = [7,4,7,6,6,8,4,6]
    elseif choix == 8
        lignes = [6,7,7,4,8,5,8,9,4]
        colonnes = [7,6,6,7,7,6,5,7,7]
    else
        println("Choix invalide. Veuillez relancer le programme.")
        return
    end
    
    println("Résolution de l'exemple $choix...")
    
    # Chronométrer la résolution
    temps_execution = @elapsed tour_de_ville(lignes, colonnes)
    println("Temps d'exécution pour l'exemple $choix : $(round(temps_execution, digits=3)) secondes.")
end

main()