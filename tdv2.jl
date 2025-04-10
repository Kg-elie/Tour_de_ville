using JuMP
using Cbc

function resoudre_tour_de_ville(n_lignes, n_colonnes, contraintes_lignes, contraintes_colonnes)
    modele = Model(Cbc.Optimizer)

    @variable(modele, x[1:n_lignes, 1:n_colonnes, 1:4], Bin)
    @variable(modele, y[1:n_lignes, 1:n_colonnes], Bin)

    # Contraintes originales
    for i in 1:n_lignes
        @constraint(modele, sum(y[i,j] for j in 1:n_colonnes) == contraintes_lignes[i])
    end
    for j in 1:n_colonnes
        @constraint(modele, sum(y[i,j] for i in 1:n_lignes) == contraintes_colonnes[j])
    end
    for i in 1:n_lignes
        for j in 1:n_colonnes
            @constraint(modele, sum(x[i,j,d] for d in 1:4) == 2 * y[i,j])
        end
    end
    for i in 1:n_lignes
        @constraint(modele, x[i,1,3] == 0)
        @constraint(modele, x[i,n_colonnes,1] == 0)
    end
    for j in 1:n_colonnes
        @constraint(modele, x[1,j,4] == 0)
        @constraint(modele, x[n_lignes,j,2] == 0)
    end
    for i in 1:n_lignes
        for j in 1:n_colonnes
            flux_entrant = (i > 1 ? x[i-1,j,2] : 0) + (j > 1 ? x[i,j-1,1] : 0) +
                          (i < n_lignes ? x[i+1,j,4] : 0) + (j < n_colonnes ? x[i,j+1,3] : 0)
            @constraint(modele, flux_entrant == sum(x[i,j,d] for d in 1:4))
        end
    end

    # Contrainte pour garantir que le premier sommet est connecté au dernier
    @constraint(modele, sum(x[i,j,1] + x[i,j,2] + x[i,j,3] + x[i,j,4] for i in 1:n_lignes, j in 1:n_colonnes) >= 2)

    @objective(modele, Min, 0)

    # Variables pour suivre les sous-tours
    sous_tours = Vector{Vector{Tuple{Int,Int}}}()

    while true
        optimize!(modele)

        if termination_status(modele) != MOI.OPTIMAL
            return false, zeros(Int, n_lignes, n_colonnes), sous_tours
        end

        sol_x = round.(Int, value.(x))
        sol_y = round.(Int, value.(y))
        print( sol_y)
        # Détection des sous-tours
        sous_tours = detecter_sous_tours(sol_y, n_lignes, n_colonnes)
        
        if length(sous_tours) <= 1
            # Un seul tour trouvé - solution valide
            return true, sol_y, sous_tours
        else
            # Ajouter des contraintes pour éliminer les sous-tours
            for tour in sous_tours
                # Contrainte de sous-tour : au moins une entrée/sortie du sous-ensemble
                @constraint(modele, sum(y[i,j] for (i,j) in tour) <= length(tour) - 1)
            end
        end
    end
end

function detecter_sous_tours(sol_y, n_lignes, n_colonnes)
    visited = falses(n_lignes, n_colonnes)
    sous_tours = Vector{Vector{Tuple{Int,Int}}}()

    for i in 1:n_lignes
        for j in 1:n_colonnes
            if sol_y[i,j] == 1 && !visited[i,j]
                # Nouveau tour trouvé
                tour = Vector{Tuple{Int,Int}}()
                current = (i,j)
                
                while true
                    push!(tour, current)
                    visited[current[1], current[2]] = true
                    
                    # Trouver la prochaine case dans le tour
                    next_cell = nothing
                    ii, jj = current
                    
                    # Vérifier les 4 directions
                    if ii > 1 && sol_y[ii-1,jj] == 1 && !visited[ii-1,jj]
                        next_cell = (ii-1,jj)
                    elseif ii < n_lignes && sol_y[ii+1,jj] == 1 && !visited[ii+1,jj]
                        next_cell = (ii+1,jj)
                    elseif jj > 1 && sol_y[ii,jj-1] == 1 && !visited[ii,jj-1]
                        next_cell = (ii,jj-1)
                    elseif jj < n_colonnes && sol_y[ii,jj+1] == 1 && !visited[ii,jj+1]
                        next_cell = (ii,jj+1)
                    end
                    
                    if next_cell == nothing
                        # Retour au début du tour
                        if (ii > 1 && sol_y[ii-1,jj] == 1 && (ii-1,jj) == tour[1]) ||
                           (ii < n_lignes && sol_y[ii+1,jj] == 1 && (ii+1,jj) == tour[1]) ||
                           (jj > 1 && sol_y[ii,jj-1] == 1 && (ii,jj-1) == tour[1]) ||
                           (jj < n_colonnes && sol_y[ii,jj+1] == 1 && (ii,jj+1) == tour[1])
                            break
                        else
                            # Tour incomplet - problème dans la solution
                            break
                        end
                    end
                    
                    current = next_cell
                end
                
                push!(sous_tours, tour)
            end
        end
    end
    
    return sous_tours
end

# Fonction pour extraire le circuit valide à partir de sol_y
function extraire_circuit(sol_y, n_lignes, n_colonnes)
    circuits = Vector{Vector{Tuple{Int, Int}}}()  # Liste pour stocker tous les circuits possibles
    visited = falses(n_lignes, n_colonnes)  # Matrice pour vérifier les points déjà visités

    for start_i in 1:n_lignes
        for start_j in 1:n_colonnes
            if sol_y[start_i, start_j] == 1 && !visited[start_i, start_j]
                circuit = Vector{Tuple{Int, Int}}()  # Circuit temporaire pour un départ spécifique
                current_i, current_j = start_i, start_j

                # Parcourir le circuit à partir de ce point
                while true
                    push!(circuit, (current_i, current_j))
                    visited[current_i, current_j] = true
                    
                    # Chercher un voisin non visité
                    next_cell = nothing
                    ii, jj = current_i, current_j
                    
                    # Vérifier les 4 directions
                    if ii > 1 && sol_y[ii-1, jj] == 1 && !visited[ii-1, jj]
                        next_cell = (ii-1, jj)
                    elseif ii < n_lignes && sol_y[ii+1, jj] == 1 && !visited[ii+1, jj]
                        next_cell = (ii+1, jj)
                    elseif jj > 1 && sol_y[ii, jj-1] == 1 && !visited[ii, jj-1]
                        next_cell = (ii, jj-1)
                    elseif jj < n_colonnes && sol_y[ii, jj+1] == 1 && !visited[ii, jj+1]
                        next_cell = (ii, jj+1)
                    end
                    
                    if next_cell === nothing
                        # Si on n'a plus de voisins à visiter, on a terminé le circuit
                        break
                    end

                    current_i, current_j = next_cell
                end

                # Vérifier que le dernier point du circuit est adjacent au premier
                last_i, last_j = circuit[end]
                first_i, first_j = circuit[1]

                if (abs(last_i - first_i) == 1 && last_j == first_j) || (abs(last_j - first_j) == 1 && last_i == first_i)
                    push!(circuits, circuit)  # Ajouter le circuit complet
                else
                    println("Le dernier point n'est pas adjacent au premier pour ce circuit. Circuit invalide.")
                end
            end
        end
    end

    return circuits
end


# Fonction principale pour démarrer la résolution
function main()
    println("=== Solveur de Tour de Ville avec élimination des sous-tours ===")
    print("Nombre de lignes : ")
    n_lignes = parse(Int, readline())
    print("Nombre de colonnes : ")
    n_colonnes = parse(Int, readline())

    println("Entrez les contraintes pour chaque ligne :")
    contraintes_lignes = zeros(Int, n_lignes)
    for i in 1:n_lignes
        print("Ligne $i : ")
        contraintes_lignes[i] = parse(Int, readline())
    end

    println("Entrez les contraintes pour chaque colonne :")
    contraintes_colonnes = zeros(Int, n_colonnes)
    for j in 1:n_colonnes
        print("Colonne $j : ")
        contraintes_colonnes[j] = parse(Int, readline())
    end

    succes, sol_y, sous_tours = resoudre_tour_de_ville(n_lignes, n_colonnes, contraintes_lignes, contraintes_colonnes)

    if succes
        println("\nSolution trouvée :")
        println(sol_y)
        circuit = extraire_circuit(sol_y, n_lignes, n_colonnes)
        println("Circuit extrait : ", circuit)
    else
        println("\nAucune solution trouvée pour les contraintes données.")
    end
end

main()
