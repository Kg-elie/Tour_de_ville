using JuMP, HiGHS

function tour_de_ville(li::Array{Int64}, lj::Array{Int64})
    size_i = size(li,1)
    size_j = size(lj,1)

    model = Model(HiGHS.Optimizer)
    
    @variable(model, x[i in 1:size_i, j in 1:size_j], Bin) # si la case est visitée
    @variable(model, c[i1 in 1:size_i, j1 in 1:size_j, i2 in 1:size_i, j2 in 1:size_j], Bin) # chemin de la case 1 a la case 2

    @objective(model, Max, 0)

    
    @constraint(model, ligne[i in 1:size_i], sum(x[i,j] for j in 1:size_j) == li[i])
    @constraint(model, colonne[j in 1:size_j], sum(x[i,j] for i in 1:size_i) == lj[j])
    @constraint(model, voisine[i1 in 1:size_i, j1 in 1:size_j, i2 in size_j, j2 in 1:size_j; abs(i1-i2) + abs(j1-j2) == 1], c[i1,j1,i2,j2] <= 1)
    @constraint(model, pas_voisin[i1 in 1:size_i, j1 in 1:size_j, i2 in 1:size_i, j2 in 1:size_j; abs(i1-i2) + abs(j1-j2) != 1 ], c[i1,j1,i2,j2] == 0)
    @constraint(model, entrant[i in 1:size_i, j in 1:size_j], sum(c[i1,j1,i,j] for i1 in 1:size_i, j1 in 1:size_j) == x[i,j])
    @constraint(model, sortant[i in 1:size_i, j in 1:size_j], sum(c[i,j,i2,j2] for i2 in 1:size_i, j2 in 1:size_j) == x[i,j])
    #@constraint(model, direction[i1 in 1:size_i, j1 in 1:size_j, i2 in size_j, j2 in 1:size_j], c[i1,j1,i2,j2]+c[i2,j2,i1,j1] == x[i1,j1])
    
    #println(model)
    set_silent(model)
    optimize!(model)

    if termination_status(model) == MOI.OPTIMAL
        x_sol = round.(Int64, value.(x))
        c_sol = round.(Int64, value.(c))
        print("   ")
        for j in 1:size_j
            print(" ", lj[j], "  ")
        end 
        println("")
        for i in 1:size_i
            println("   -------------------")
            print(li[i], " ")
            for j in 1:size_j
                print("| ")
                if x_sol[i,j] == 1 
                    if i > 1 && c_sol[i,j,i-1,j] == 1 print("↑ ")
                    elseif i < size_i && c_sol[i,j,i+1,j] == 1 print("↓ ")
                    elseif j > 1 && c_sol[i,j,i,j-1] == 1 print("← ")
                    elseif j < size_j && c_sol[i,j,i,j+1] == 1 print("→ ")
                    else print("x ")
                    end
                else print("  ")
                end
            end
            println("|") 
        end
        println("   -------------------")
        #print_c_values(c_sol, size_i, size_j)
    else
        println("Pas de de solution optimale trouvée")
    end
   
end

function print_c_values(c, size_i, size_j)
    for i1 in 1:size_i
        for j1 in 1:size_j
            for i2 in 1:size_i
                for j2 in 1:size_j
                    println("c[$i1, $j1, $i2, $j2] = ", c[i1, j1, i2, j2])
                end
            end
        end
    end
end

function main()
    lignes = [5,5,5,5,2]
    colonnes = [4,4,4,5,5]
    tour_de_ville(lignes, colonnes)   
end

main()
