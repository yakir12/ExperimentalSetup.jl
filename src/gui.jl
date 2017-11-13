
using ExperimentalSetup,Gtk.ShortNames, GtkReactive, Reactive, DataStructures
const ES = ExperimentalSetup
function create_log(f=string.(1:5))
    factors = [Factor(f[i], f[1:i]) for i in linearindices(f)]
    a = ES.Log(ES.Metadata(factors))
    push!(a, repeat(f[1,:], outer=[length(f)]), "comment")
    push!(a, f, "comment")
end


_unique_factor(factors::Vector{Factor}, fname::String) = all(fname ≠ y.name for y in factors)

function edit_metadata!(a::ExperimentalSetup.Log, builder)
    update = Signal(nothing)
    backup = deepcopy(a)
    foreach(update) do _
        empty!(builder["metadata.box"])
        for (i, f) in enumerate(a.md.factors)
            b = Box(:h)
            name = textbox(f.name)
            foreach(name, init=nothing) do fname
                if isempty(fname)
                    delete!(a, f)
                elseif _unique_factor(a.md.factors, fname)
                    a.md.factors[i] = Factor(fname, f.levels)
                end
                push!(update, nothing)
            end
            push!(b, name)
            push!(b, label(": "))
            for (j, l) in enumerate(f.levels)
                name = textbox(l)
                foreach(name, init=nothing) do lname
                    if isempty(lname)
                        delete!(a, f, l)
                    elseif lname ∉ f.levels
                        f.levels[j] = lname
                    end
                    push!(update, nothing)
                end
                push!(b, name)
            end
            add_level = textbox("")
            foreach(add_level, init=nothing) do lname
                lname ∉ f.levels && push!(f.levels, lname)
                push!(update, nothing)
            end
            push!(b, add_level)
            push!(builder["metadata.box"], b)
        end
        add_factor = textbox("")
        foreach(add_factor, init=nothing) do fname
            _unique_factor(a.md.factors, fname) && push!(a.md.factors, Factor(fname, ["level 1"]))
            push!(update, nothing)
        end
        push!(builder["metadata.box"], add_factor)
        showall(builder["metadata.box"])
    end

    ok = button(widget = builder["metadata.ok"]) do _
        populate_collect!(a.md.factors, builder)
        visible(builder["metadata.window"], false)
    end

    cancel = button(widget = builder["metadata.cancel"], init=nothing) do _
        a = deepcopy(backup)
        # push!(update, nothing)
        visible(builder["metadata.window"], false)
        nothing
    end

    return a
end

function populate_collect!(factors::Vector{Factor}, builder)
    empty!(builder["collect.run.label.box"])
    empty!(builder["collect.run.combobox"])
    for f in factors
        push!(builder["collect.run.label.box"], Label(f.name))
        cb = ComboBoxText()
        for level in f.levels
            push!(cb, level)
        end
        setproperty!(cb, :active, 0)
        push!(builder["collect.run.combobox"], cb)
    end
    return builder
end

function collect_run(builder, levels::Vector{Int}, comment::String)
    for (i, level) in enumerate(levels)
        setproperty!(builder["collect.run.combobox"][i], :active, level - 1)
    end
    setproperty!(builder["collect.run.comment"], :text, comment)
    canceled = false
    c = Condition()
    okh = signal_connect(builder["collect.run.ok"], :clicked) do _
        notify(c)
    end
    cancelh = signal_connect(builder["collect.run.cancel"], :clicked) do _
        canceled = true
        notify(c)
    end
    visible(builder["collect.run.window"], true)
    wait(c)
    visible(builder["collect.run.window"], false)
    levels_ = [Gtk.GLib.bytestring(Gtk.GAccessor.active_text(cb)) for cb in builder["collect.run.combobox"]]
    comment_ = getproperty(builder["collect.run.comment"], :text, String)
    return (levels_, comment_, canceled)
end


const run_row = """
<interface>
<requires lib="gtk+" version="3.20"/>
<object class="GtkImage" id="delete.image">
<property name="visible">True</property>
<property name="can_focus">False</property>
<property name="stock">gtk-delete</property>
</object>
<object class="GtkImage" id="edit.image">
<property name="visible">True</property>
<property name="can_focus">False</property>
<property name="stock">gtk-edit</property>
</object>
<object class="GtkBox" id="run.row.box">
<property name="visible">True</property>
<property name="can_focus">False</property>
<child>
<object class="GtkLabel" id="label.run">
<property name="visible">True</property>
<property name="can_focus">False</property>
<property name="label" translatable="yes">None</property>
<property name="ellipsize">middle</property>
<property name="width_chars">20</property>
<property name="max_width_chars">20</property>
<property name="xalign">0</property>
</object>
<packing>
<property name="expand">False</property>
<property name="fill">True</property>
<property name="position">0</property>
</packing>
</child>
<child>
<object class="GtkButton" id="delete.run">
<property name="visible">True</property>
<property name="can_focus">True</property>
<property name="receives_default">True</property>
<property name="tooltip_markup" translatable="yes">&lt;b&gt;Delete&lt;/b&gt; this run!</property>
<property name="image">delete.image</property>
<property name="always_show_image">True</property>
</object>
<packing>
<property name="expand">False</property>
<property name="fill">True</property>
<property name="position">1</property>
</packing>
</child>
<child>
<object class="GtkButton" id="edit.run">
<property name="visible">True</property>
<property name="can_focus">True</property>
<property name="receives_default">True</property>
<property name="image">edit.image</property>
<property name="always_show_image">True</property>
</object>
<packing>
<property name="expand">False</property>
<property name="fill">True</property>
<property name="position">2</property>
</packing>
</child>
</object>
</interface>
"""



function edit_runs!(aᵗ::Signal{ExperimentalSetup.Log}, builder)
    foreach(aᵗ) do a
        empty!(builder["runs.box"])
        for (k, v) in a.reps
            levels, _ = ES.pop(a, k)
            l = string(join(levels, ","), ":", v.replicate)
            row = Builder(buffer = run_row)
            Gtk.GAccessor.text(row["label.run"], l)
            deleteh = button(widget = row["delete.run"])
            foreach(deleteh, init=nothing) do _
                delete!(a, k)
                push!(aᵗ, a)
                nothing
            end
            edith = button(widget = row["edit.run"])
            foreach(edith, init=nothing) do _
                levels, comment, canceled = collect_run(builder, a.md.setups[a.reps[k].setup].levels, a.reps[k].comment)
                canceled || replace!(a, k, levels, comment)
                push!(aᵗ, a)
                nothing
            end
            push!(builder["runs.box"], row["run.row.box"])
        end
        addrun = button("+")
        foreach(addrun, init=nothing) do _
            levels_int = a.last == 0 ? ones(Int, a.md.nfactors) : a.md.setups[a.reps[end].setup].levels
            levels, comment, canceled = collect_run(builder, levels_int, "")
            canceled || push!(a, levels, comment)
            push!(aᵗ, a)
            nothing
        end
        push!(builder["runs.box"], addrun)

        # push!(aᵗ, a)
        showall(builder["runs.box"])
    end


    c = Condition()
    editmetadatah = signal_connect(builder["edit.metadata"], :clicked) do _
        notify(c)
    end
    # visible(builder["main.window"], true)
    wait(c)
    # visible(builder["main.window"], false)

    return value(aᵗ)
end

function main(a::ExperimentalSetup.Log)
    builder = Builder(filename=joinpath("/home/yakir/.julia/v0.6/ExperimentalSetup/src", "main.glade"))
    aᵗ = Signal(a)
    edit_metadata!(aᵗ, builder)
    edit_runs!(aᵗ, builder)
    # bᵗ = map(x -> edit_metadata!(x, builder), aᵗ)
    # cᵗ = map(x -> edit_runs!(x, builder), bᵗ)
    # bind!(aᵗ, cᵗ)

    showall(builder["main.window"])
    showall(builder["metadata.window"])
    visible(builder["metadata.window"], false)
    showall(builder["collect.run.window"])
    visible(builder["collect.run.window"], false)
end

a = create_log()
main(a)
# factors = [Factor("a", ["1","1000000000"]), Factor("b", ["1","100000000000000"])]
# a = ES.Log(ES.Metadata(factors))
# push!(a, ["1","1"], "")
# push!(a, ["1000000000","100000000000000"], "")



# function that takes an a, sends it to the main window and waits, main window returns a and message, then this function decides what to do with the a: save? edit metadata? etc.. this function has no window.



# s1 = Signal(Void())
# h1 = signal_connect(builder["edit.metadata.menu"], :activate) do _
# push!(s1, nothing)
# end







