function push_dict!(dict, key, val)
    if !haskey(dict, key)
        dict[key] = [val]
    else
        push!(dict[key], val)
    end
end
