using ExperimentalSetup
const ES = ExperimentalSetup
using Base.Test
import Base: ==
==(a::Base.KeyIterator, b::Base.KeyIterator) = length(a)==length(b) && all(k->in(k,b), a)
==(a::ES.Log, b::ES.Log) = a.last == b.last && a.md == b.md && a.reps == b.reps
==(a::ES.Metadata, b::ES.Metadata) = a.factors == b.factors && a.nfactors == b.nfactors && a.setups == b.setups
==(a::ES.Factor, b::ES.Factor) = a.name == b.name && a.levels == b.levels
==(a::Vector{ES.Factor}, b::Vector{ES.Factor}) = length(a) == length(b) && all(a[i] == b[i] for i in 1:length(a))
==(a::ES.Setup, b::ES.Setup) = a.levels == b.levels && a.n.x == b.n.x
==(a::Vector{ES.Setup}, b::Vector{ES.Setup}) = length(a) == length(b) && all(a[i] == b[i] for i in 1:length(a))
==(a::ES.Rep, b::ES.Rep) = a.comment == b.comment && a.replicate == b.replicate && a.setup == b.setup
==(a::Vector{ES.Rep}, b::Vector{ES.Rep}) = length(a) == length(b) && all(a[i] == b[i] for i in 1:length(a))
function create_log(f=string.(1:5))
    factors = [Factor(f[i], f[1:i]) for i in linearindices(f)]
    a = ES.Log(ES.Metadata(factors))
    push!(a, repeat(f[1,:], outer=[length(f)]), "comment")
    push!(a, f, "comment")
end

@testset "other" begin

    a = create_log()
    @test a.md.nfactors == 5
    @test 1 ∈ a

    empty!(a)
    @test isempty(a.reps)
    @test isempty(a.md.setups)

    levels = [string(rand(1:i)) for i in 1:5]
    comment = "some comment"
    push!(a, levels, comment)
    @test ES.pop(a, a.last) == (levels, comment)

end

@testset "push" begin

    b = create_log()
    # replicate
    push!(b, repeat(["1"], outer=[5]), "comment")
    @test b.reps[end].setup == 1
    @test b.reps[end].replicate == 2

    # comment
    push!(b, repeat(["1"], outer=[5]), "different comment")
    @test b.reps[end].setup == 1
    @test b.reps[end].replicate == 3

    # new
    push!(b, [i > 1 ? "2" : "1" for i in 1:5], "comment")
    @test b.reps[end].setup == 3
    @test b.reps[end].replicate == 1

    # errors
    @test_throws AssertionError push!(b, repeat(["1"], outer=[6]), "comment")
    @test_throws AssertionError push!(b, repeat(["2"], outer=[5]), "comment")

end


@testset "delete" begin

    # delete a member
    b = create_log()
    delete!(b, 1)
    @test 1 ∉ b

    # delete something that isn't there
    @test_throws KeyError delete!(b, 1)

    # delete a factor
    b = create_log()
    c = delete(b, b.md.factors[2])
    @test b.md.factors[2] ∉ c.md.factors
    @test all(length(f.levels) == 4 for f in c.md.setups)
    @test all(f.levels[2] ≠ "2" for f in c.md.setups)

    # delete a level
    b = create_log()
    push!(b, [i > 1 ? "2" : "1" for i in 1:5], "comment")
    c = delete(b, b.md.factors[5], "2")
    f = 1:5
    factors = [i ≠ 5 ? Factor("$i", ["$j" for j in 1:i]) : Factor("$i", ["$j" for j in filter(x -> x ≠ 2, 1:i)]) for i in f]
    a = ES.Log(ES.Metadata(factors))
    push!(a, repeat(["1"], outer=[length(f)]), "comment")
    push!(a, ["$i" for i in f], "comment")
    push!(a, ["1", "2", "2", "2", "1"], "comment")

    @test c == a

end

@testset "replace" begin

    a = create_log()
    new = ([i < 3 ? "$i" : "3" for i in 1:5], "comment")
    old = 1
    replace!(a, old, new...)
    @test ES.pop(a, old) == new

end

@testset "combine" begin

    a = create_log()
    b = create_log(string.('a':'g'))
    c = ES.combine(a,b)
    @test c == ExperimentalSetup.Log(ExperimentalSetup.Metadata(ExperimentalSetup.Factor[ExperimentalSetup.Factor("1", String["1"]), ExperimentalSetup.Factor("2", String["1", "2"]), ExperimentalSetup.Factor("3", String["1", "2", "3"]), ExperimentalSetup.Factor("4", String["1", "2", "3", "4"]), ExperimentalSetup.Factor("5", String["1", "2", "3", "4", "5"]), ExperimentalSetup.Factor("a", String["a"]), ExperimentalSetup.Factor("b", String["a", "b"]), ExperimentalSetup.Factor("c", String["a", "b", "c"]), ExperimentalSetup.Factor("d", String["a", "b", "c", "d"]), ExperimentalSetup.Factor("e", String["a", "b", "c", "d", "e"]), ExperimentalSetup.Factor("f", String["a", "b", "c", "d", "e", "f"]), ExperimentalSetup.Factor("g", String["a", "b", "c", "d", "e", "f", "g"])], ExperimentalSetup.Setup[ExperimentalSetup.Setup([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], Base.RefValue{Int64}(2)), ExperimentalSetup.Setup([1, 2, 3, 4, 5, 1, 1, 1, 1, 1, 1, 1], Base.RefValue{Int64}(1)), ExperimentalSetup.Setup([1, 1, 1, 1, 1, 1, 2, 3, 4, 5, 6, 7], Base.RefValue{Int64}(1))]), 0x0000000000000004, DataStructures.SortedDict(0x0000000000000001=>ExperimentalSetup.Rep(1, 1, "comment"),0x0000000000000002=>ExperimentalSetup.Rep(2, 1, "comment"),0x0000000000000003=>ExperimentalSetup.Rep(1, 2, "comment"),0x0000000000000004=>ExperimentalSetup.Rep(3, 1, "comment")))

end


