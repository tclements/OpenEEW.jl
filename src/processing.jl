export smooth_gaps, smooth_gaps!, zero_out, zero_out!

"""
  smooth_gaps(S)

Remove and taper around gaps in `SeisData` `S`.

Use `ungap!(S,tap=true,m=false)` before applying this function to fill gaps
with `nan` values.

# Arguments
- `S::SeisData`: 3-component `SeisData` for detection.

# Keywords
- `pad::Int`: Number of sample points to taper before and after gap.
"""
function smooth_gaps!(S::SeisData;pad::Real=100)

    # check pad input
    pad = max(2,pad)
    if !isa(pad,Int)
        pad = convert(Int,ceil(pad))
    end
    for ii = 1:S.n
        # find all nan / gaps
        ind = findall(isnan.(S.x[ii]))
        if length(ind) == 0
            continue
        end

        # set all nan equal to zero
        out = unique(ind)
        T = eltype(S.x[ii])
        S.x[ii][out] .= T(0)
        padarr = T(0.):T(pad-1)

        # right tapering of gaps
        rightind = findall(diff(ind) .!= 1)
        for jj in ind[rightind]
            maxind = min(jj+pad-1,length(S[ii].x))
            if length(jj:maxind) == length(padarr)
                S.x[ii][jj:maxind] .*= cos.(T(pi) ./ T(2) .+ T(pi) ./ T(2) .* padarr ./ pad).^2
            else
                S.x[ii][jj:maxind] .= T(0)
            end
        end


        # left tapering of gaps
        prepend!(ind,1)
        leftind = findall(diff(ind) .> 1)
        for jj in ind[leftind]
            minind = max(1,jj-pad+1)
            if length(minind:jj) == length(padarr)
                S.x[ii][minind:jj] .*= cos.(T(pi) ./ T(2) .* padarr ./ pad).^2
            else
                S.x[ii][minind:jj] .= T(0)
            end
        end
    end
    return nothing
end
smooth_gaps(S::SeisData;pad::Int=100) = (U = deepcopy(S);smooth_gaps!(U,pad=pad);return U)


"""
  zero_out!(S)

Set data in SeisData `S` == 0 where `S.x .> thresh`
"""
function zero_out!(S::SeisData;thresh::AbstractFloat=1e-7)
    for ii = 1:S.n
        T = eltype(S.x[ii])
        ind = findall(abs.(S.x[ii]) .< thresh)
        S.x[ii][ind] .= T(0)
    end
    return nothing
end
zero_out(S::SeisData; thresh::AbstractFloat=1e-7) = (U = deepcopy(S);zero_out!(U,thresh=thresh);return U)
