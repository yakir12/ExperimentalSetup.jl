module ExperimentalSetup

using DataStructures

export  Factor, Rep,
        delete, replace!

import Base: ∈, push!, delete!, empty!

struct Factor
    name::String
    levels::Vector{String}
end

struct Setup
    levels::Vector{Int}
    n::Base.RefValue{Int}
end

struct Metadata
    factors::Vector{Factor}
    setups::Vector{Setup}
    nfactors::Int

    Metadata(factors::Vector{Factor}, setups::Vector{Setup}) = new(factors, setups, length(factors))
end

Metadata(factors::Vector{Factor}) = Metadata(factors, Setup[])

Metadata() = Metadata(Factor[])

mutable struct Rep
    setup::Int
    replicate::Int
    comment::String
end

mutable struct Log
    md::Metadata
    last::UInt64

    reps::SortedDict{UInt64, Rep}
end

Log(md::Metadata) = Log(md, 0, SortedDict{UInt64, Rep}())

Log() = Log(Metadata())

# findfirst

# findfirst(a::Log, x::Rep) = findfirst(a.reps, x)

# in

# repID(md::Metadata, x::Rep) = hash((md.setups[x.setup],x.replicate, x.comment))

∈(k::UInt64, a::Log) = haskey(a.reps, k)
∈(k::T, a::Log) where T <: Integer = UInt64(k) ∈ a

# pushes

function push!(md::Metadata, str_levels::Vector{String})
    @assert length(str_levels) == md.nfactors "Number of levels doesn't match metadata"
    levels = Int[]
    for (factor, l) in zip(md.factors, str_levels)
        i = findfirst(factor.levels, l)
        @assert i ≠ 0 "Factor $(factor.name) does not have level $l"
        push!(levels, i)
    end
    i = findfirst(x -> x.levels == levels, md.setups)
    if i == 0
        push!(md.setups, Setup(levels, Ref(0)))
        i = length(md.setups)
    end
    md.setups[i].n.x += 1
    return (i, md.setups[i].n.x)
end

function push!(a::Log, str_levels::Vector{String}, comment::String)
    i, replicate = push!(a.md, str_levels)
    a.last += 1
    a.reps[a.last] = Rep(i, replicate, comment)
    return a
end

# empty

function empty!(a::Log)
    empty!(a.reps)
    empty!(a.md.setups)
    return a
end


# pop


pop(md::Metadata, x::Rep) = ([f.levels[i] for (i, f) in zip(md.setups[x.setup].levels, md.factors)], x.comment)

pop(a::Log, k::UInt64) = pop(a.md, a.reps[k])

pop(a::Log, k::T) where T <: Integer = pop(a, UInt64(k))

# deletes

function _delete!(md::Metadata, setup::Int)
    step_setup = md.setups[setup].n.x == 1
    if step_setup
        deleteat!(md.setups, setup)
    else
        md.setups[setup].n.x -= 1
    end
    return step_setup
end

function delete!(a::Log, k::UInt64)
    x = a.reps[k]
    step_setup = _delete!(a.md, x.setup)
    for (i,r) in a.reps
        if r.setup == x.setup
            if r.replicate > x.replicate
                r.replicate -= 1
            end
        elseif step_setup && r.setup > x.setup
            r.setup -= 1
        end
    end
    delete!(a.reps, k)
    return a
end

delete!(a::Log, k::T) where T <: Integer = delete!(a, UInt64(k))

function delete(a::Log, x::Factor)
    i = findfirst(y -> y == x, a.md.factors)
    @assert i ≠ 0 "factor not found in log"
    factors = deepcopy(a.md.factors)
    deleteat!(factors, i)
    b = Log(Metadata(factors))
    for r in values(a.reps)
        levels, comment = pop(a.md, r)
        deleteat!(levels, i)
        push!(b, levels, comment)
    end
    return b
end

function delete(a::Log, x::Factor, level::String)
    i = findfirst(y -> y == x, a.md.factors)
    @assert i ≠ 0 "factor not found in log"
    j = findfirst(a.md.factors[i].levels, level)
    @assert j ≠ 0 "level not found in log"
    nlevels = length(a.md.factors[i].levels)
    if nlevels == 1
        return delete(a, x)
    end
    factors = deepcopy(a.md.factors)
    deleteat!(factors[i].levels, j)
    b = Log(Metadata(factors))
    # if the level to be removed is first in the list of levels, then replace it with the second one. If it's the last, replace it with the next to last one. If it's neither, replace it with one level bellow.
    alternative = j == 1 ? a.md.factors[i].levels[2] : j == nlevels ? a.md.factors[i].levels[nlevels - 1] : a.md.factors[i].levels[j - 1]
    for r in values(a.reps)
        levels, comment = pop(a.md, r)
        if levels[i] == level
            levels[i] = alternative
        end
        push!(b, levels, comment)
    end
    return b
end



#=function delete!(a::Log, x::Rep)
    x ∉ a && return a
    step_setup = false
    if a.md.setups[x.setup].n.x == 1
        deleteat!(a.md.setups, x.setup)
        step_setup = true
    else
        a.md.setups[x.setup].n.x -= 1
    end
    ind = 0
    for (i,r) in enumerate(a.reps)
        if r.setup == x.setup
            if r == x
                ind = copy(i)
            else
                if r.replicate > x.replicate
                    r.replicate -= 1
                end
            end
        elseif r.setup > x.setup
            if step_setup
                r.setup -= 1
            end
        end
    end
    deleteat!(a.reps, ind)
    filter!(x -> x.rep ≠ ind, a.asss)
    for s in a.asss
        if s.rep > ind
            s.rep -= 1
        end
    end
    return a
end=#

# replace

function replace!(a::Log, o::UInt64, str_levels::Vector{String}, comment::String)
    @assert haskey(a.reps, o) ≠ 0 "old run not found"
    delete!(a, o)
    push!(a, str_levels, comment)
    a.reps[o] = pop!(a.reps, a.last)
    return a
end

replace!(a::Log, o::T, str_levels::Vector{String}, comment::String) where T <: Integer = replace!(a, UInt64(o), str_levels, comment)

# combine

function combine_factors(logs::Log...)
    factors = Factor[]
    for log in logs, new_factor in log.md.factors
        for old_factor in factors
            if new_factor.name == old_factor.name
                for new_level in new_factor.levels
                    new_level ∉ old_factor.levels && push!(old_factor.levels, new_level)
                end
                break
            end
        end
        push!(factors, new_factor)
    end
    return Metadata(factors)
end

function combine(logs::Log...)
    md = combine_factors(logs...)
    a = Log(md)
    x = OrderedDict{String, String}(f.name => f.levels[1] for f in md.factors)
    for log in logs, r in values(log.reps)
        for f in md.factors
            x[f.name] = f.levels[1] # non existant factors recieve a default first level
        end
        for (i, f) in zip(log.md.setups[r.setup].levels, log.md.factors)
            x[f.name] = f.levels[i]
        end
        push!(a, collect(values(x)), r.comment)
    end
    return a
end


end # module
