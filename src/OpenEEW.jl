module OpenEEW

using LazyJSON, SeisIO

export read_openeew

"""
  read_openeew(filepath)

Read OpenEEW data using SeisIO.

# Arguments
- `filepath::String`: Path to OpenEEW .jsonl file.

# Returns
- `S::SeisData`: 3-channel SeisData structure.
"""
function read_openeew(filepath::String)
    # read JSON lines file
    records  = String(read(filepath))
    # convert to Julia struct
    oeew = convert.(OpenEEWRecord,LazyJSON.parse.(split(records,"\n")))

    # check for duplicated data
    t = [o.cloud_t for o in oeew]
    S = SeisData()
    for ii in indexin(unique(t), t)
        merge!(S,openeew2seisdata(oeew[ii]))
    end

    # convert to 3 channel data
    merge!(S)
    ungap!(S)
    return S
end

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

"""
  openeew2seisdata(record)

Convert `OpenEEW` structure to SeisData structure.
"""
function openeew2seisdata(record::OpenEEWRecord)
    S = SeisData(3)
    S.id[1] = "$(record.country_code).$(record.device_id)..x"
    S.id[2] = "$(record.country_code).$(record.device_id)..y"
    S.id[3] = "$(record.country_code).$(record.device_id)..z"
    S.name[1] = "$(record.country_code).$(record.device_id)..x"
    S.name[2] = "$(record.country_code).$(record.device_id)..y"
    S.name[3] = "$(record.country_code).$(record.device_id)..z"
    S.fs[1] = record.sr
    S.fs[2] = record.sr
    S.fs[3] = record.sr
    S.t[1] = [1 record.cloud_t * 1e6; length(record.x) 0]
    S.t[2] = [1 record.cloud_t * 1e6; length(record.y) 0]
    S.t[3] = [1 record.cloud_t * 1e6; length(record.z) 0]
    S.x[1] = record.x
    S.x[2] = record.y
    S.x[3] = record.z
    return S
end
end
