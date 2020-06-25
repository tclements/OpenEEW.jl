export read_openeew, openeew2seisdata, OpenEEWRecord, splitjson

# structure for holding an individual OpenEEW structure
struct OpenEEWRecord
    country_code::String
    device_id::String
    x::Array{Float32,1}
    y::Array{Float32,1}
    z::Array{Float32,1}
    device_t::Float64
    cloud_t::Float64
    sr::Float64
end

function OpenEEWRecord(d::Dict)
    return OpenEEWRecord(
        d["country_code"],
        d["device_id"],
        d["x"],
        d["y"],
        d["z"],
        d["device_t"],
        d["cloud_t"],
        d["sr"],
)
end

"""
  read_openeew(filepath)

Read OpenEEW data using SeisIO.

# Arguments
- `filepath::String`: Path to OpenEEW .jsonl file.

# Returns
- `O::Array{OpenEEW}`: 3-channel SeisData structure.
"""
function read_openeew(filepath::String)
    # read JSON lines file
    records  = splitjson(read(filepath))

    # convert to Julia struct
    O = OpenEEWRecord.(JSON.parse.(records))
    return openeew2seisdata(O)
end

"""
  openeew2seisdata(O)

Convert `Array` `O` of `OpenEEWRecords` to SeisData structure.
"""
function openeew2seisdata(O::Array{OpenEEWRecord})
    N = length(O)

    # allocate arrays
    x = vcat([O[ii].x for ii = 1:N]...)
    y = vcat([O[ii].y for ii = 1:N]...)
    z = vcat([O[ii].z for ii = 1:N]...)

    # enforce constraint that channels must be same length
    Nx = length(x)
    Ny = length(y)
    Nz = length(z)
    if Nx != Ny != Nz
        throw(ArgumentError("x, y, and z channels must be same length."))
    end

    # check sample rate same for all records
    @assert length(Set(o.sr for o in O)) == 1
    sr = O[1].sr # sample rate

    # check country code same for all records
    @assert length(Set(o.country_code for o in O)) == 1
    country_code = O[1].country_code

    # check country code same for all records
    @assert length(Set(o.device_id for o in O)) == 1
    device_id = O[1].device_id

    # allocate time variable and re-sort by time
    t = vcat([sample(o.device_t,o.sr,length(o.x)) for o in O]...)
    ind = sortperm(t)
    t .= t[ind]
    x .= x[ind]
    y .= y[ind]
    z .= z[ind]

    # find gaps and interpolate data onto an even grid-spacing
    # due to time-delays, the last few points will be lost
    newt = resample_time(t,sr)
    bad = ceil(Int,(newt[end] - t[end]) * sr)
    bad = bad < 0 ? 0 : bad
    itpx = interpolate((t,), x, Gridded(Linear()))
    itpy = interpolate((t,), y, Gridded(Linear()))
    itpz = interpolate((t,), z, Gridded(Linear()))
    newx = itpx(newt[1:end-bad])
    newy = itpy(newt[1:end-bad])
    newz = itpz(newt[1:end-bad])
    newt = newt[1:end-bad]
    return openeew2seisdata(newx,newy,newz,newt,sr,country_code,device_id)
end

function sample(t::Real,sr::Real,N::Int)
    return round.(t .- (1/sr) .* collect(N-1:-1:0),digits=3)
end

function resample_time(t::AbstractArray,sr::Real)
    newt = Array{Float64}(undef,0)
    gaps = get_gaps(t,sr)
    for ii = 1:length(gaps)-1
            gapt = t[gaps[ii]+1:gaps[ii+1]]
            Ngap = length(gapt)
            resampt = round.(collect((0:Ngap-1) ./ sr .+ gapt[1]),digits=3)
            append!(newt,resampt)
    end
    return newt
end

function get_gaps(t::AbstractArray,sr::Real)
    tdiff = abs.(diff(t))
    gaps = vcat([0; findall(tdiff .>= 2 / sr )])
    append!(gaps,length(t))
    return gaps
end

"""
  openeew2seisdata(x,y,z,t,sr,country_code,device_id)

Convert `OpenEEW` data to SeisData structure.
"""
function openeew2seisdata(
    x::AbstractArray,
    y::AbstractArray,
    z::AbstractArray,
    t::AbstractArray,
    sr::Real,
    country_code::String,
    device_id::String,
)
    @assert length(x) == length(y) == length(z) == length(t)
    S = SeisData(3)

    # use SEED naming convetion
    S.id[1] = "$country_code.$device_id..x"
    S.id[2] = "$country_code.$device_id..y"
    S.id[3] = "$country_code.$device_id..z"
    S.name[1] = "$country_code.$device_id..x"
    S.name[2] = "$country_code.$device_id..y"
    S.name[3] = "$country_code.$device_id..z"

    # add sampling rate
    S.fs[1] = sr
    S.fs[2] = sr
    S.fs[3] = sr

    # check for gaps with t
    tmat = SeisIO.t_collapse(convert.(Int,t .* 1e6),sr)
    S.t[1] = tmat
    S.t[2] = tmat
    S.t[3] = tmat
    S.x[1] = x
    S.x[2] = y
    S.x[3] = z
    return S
end

function splitjson(A::AbstractArray)
    splits = split(String(A),"\n")

    # remove empty last record
    if splits[end] == ""
        deleteat!(splits,length(splits))
    end

    return splits
end
