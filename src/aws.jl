import Base: ==, isequal
export keys2download, get_records, get_devices, OpenEEWDevice

# structure for holding an individual OpenEEW device
struct OpenEEWDevice
    country_code::String
    device_id::String
    latitude::Float64
    longitude::Float64
    effective_from::Float64
    effective_to::Float64
    is_current_row::Bool
    vertical_axis::String
    horizontal_axes::Array{String}
end

function OpenEEWDevice(d::Dict)
    return OpenEEWDevice(
        d["country_code"],
        d["device_id"],
        d["latitude"],
        d["longitude"],
        d["effective_from"],
        d["effective_to"],
        d["is_current_row"],
        d["vertical_axis"],
        d["horizontal_axes"],
)
end

isequal(D1::OpenEEWDevice, D2::OpenEEWDevice) = all([hash(getfield(D1,i))==hash(getfield(D2,i)) for i in fieldnames(OpenEEWDevice)])
==(D1::OpenEEWDevice,D2::OpenEEWDevice) = isequal(D1,D2)

"""
  get_records(aws,country_code,starttime,endtime;device_ids="")

Get records from `country_code` in given time range from grillo-openeew dataset.

# Arguments
`aws::AWSConfig`: AWSConfig configuration dictionary.
`country_code::String`: The ISO 3166 two-letter country code, e.g "mx", "cl"..
`starttime::Union{String,TimeType,Real}`: The earliest time of the request.
  in String format (%Y-%m-%dT%H:%M:%S e.g. '2020-02-06T11:00:00'), `Date`,
  `DateTime` format or UnixTime (seconds since 1/1/1970). Only records with time
   greater than or equal to `starttime` will be returned.
`endtime::Union{String,TimeType,Real}`: The latest time of the request.
 in String (%Y-%m-%dT%H:%M:%S e.g. '2020-02-06T12:00:00'), `Date`,
 `DateTime` or UnixTime (seconds since 1/1/1970) formats. Only records with time
  less than or equal to `endtime` will be returned.

# Keywords
`device_ids::Union{String,Array{String}}`: ID or IDs of specific device(s) to download.

# Returns
`Union{Array{SeisData},SeisData}`: Array of device metadata for request.
"""
function get_records(
    aws::AWSConfig,
    country_code::String,
    starttime::Union{String,TimeType,Real},
    endtime::Union{String,TimeType,Real};
    device_ids::Union{String,Array{String}}="",
    rtype = SeisData
)

    # format starttime/endtime
    startfloat = format(starttime)
    endfloat = format(endtime)

    # check time bounds
    @assert starttime < endtime

    # get devices
    devices = get_devices(aws,country_code)
    df = DataFrame(StructArray(devices))

    # subset by time
    df = subset_time(df,startfloat,endfloat)

    # filter devices
    df = subset_devices(df,device_ids)

    # build file list
    startdate = unix2datetime(startfloat)
    enddate = unix2datetime(endfloat)

    # get keys to download
    device_ids = df[!,:device_id]

    # download
    Sout = Array{SeisData}(undef,0)
    for device_id in device_ids
        eewrecords = Array{OpenEEWRecord}(undef,0)
        files2download = keys2download(aws,country_code,device_id,startdate,enddate)
        if length(files2download) == 0
            continue
        end
        for file in files2download
            eewstream = s3_get(aws,"grillo-openeew",file)
            eewstr = split(String(eewstream),"\n")

            # remove last value if empty
            if eewstr[end] == ""
                deleteat!(eewstr,length(eewstr))
            end

            # add records to array
            append!(eewrecords,OpenEEWRecord.(JSON.parse.(eewstr)))
        end

        # check for gaps
        S = openeew2seisdata(eewrecords)
        sync!(S,s=startdate,t=enddate)
        push!(Sout,S)
    end

    # check for no data
    if length(Sout) == 0
        throw(ArgumentError("No data availble for:\n" *
                            "    country_code = $country_code\n" *
                            "    starttime = $(unix2datetime(starttime))\n" *
                            "    endtime = $(unix2datetime(endtime))"))
    end

    # return Array{SeisData} or SeisData
    if rtype == SeisData
        Sout = SeisData(Sout...)
    end
    return Sout
end

"""
  get_devices(aws,country_code;current=false,date=0.)

Get device metadata for each `country_code` in grillo-openeew dataset.

# Arguments
`aws::AWSConfig`: AWSConfig configuration dictionary.
`country_code::String`: The ISO 3166 two-letter country code, e.g "mx", "cl"..

# Keywords
`current::Bool=false`: Return current devices.
`date::Union{String,TimeType,Real}=0.`: Gets device metadata as of a chosen UTC date.

# Returns
`Array{OpenEEWDevice}`: Array of device metadata for request.
"""
function get_devices(aws::AWSConfig,country_code::String;
    current::Bool=false,
    date::Union{String,TimeType,Real}=0.)

    # check country code
    country_code = lowercase(country_code)
    if country_code ∉ ["cl","cr","mx"]
        throw(ArgumentError("Country code must be one of: 'cl', 'cr' or 'mx'."))
    end

    devreq = String(
        s3_get(
            aws,"grillo-openeew","devices/country_code=$country_code/devices.jsonl"
        )
    )

    devices = OpenEEWDevice.(JSON.parse.(split(devreq,"\n")[1:end-1]))
    if current
        devices = [d for d in devices if d.is_current_row == true]
    end

    if !current && date != 0
        t = format(date)
        devices = [d for d in devices if d.effective_from <= t && d.effective_to >= t]
    end
    return devices
end

function format(t::Union{String,TimeType,Real})
    if isa(t,String)
        try DateTime(x)
        catch ex
            throw(ArgumentError("'$x' is an invalid DateTime string."))
        end
        return datetime2unix(Dates.parse(DateTime,t))
    elseif isa(t,TimeType)
        return datetime2unix(DateTime(t))
    else
        return Float64(t)
    end
end

function subset_time(df::DataFrame,starttime::Float64, endtime::Float64)
    ind1 = starttime .<= df[!,:effective_from] .< endtime .<= df[!,:effective_to]
    ind2 = df[!,:effective_from] .<= starttime .< endtime .<= df[!,:effective_to]
    ind3 = df[!,:effective_from] .<= starttime .< df[!,:effective_to] .<= endtime
    ind = ind1 .| ind2 .| ind3
    newdf =  df[ind,:]

    # check newdf not empty
    if size(newdf,1) == 0
        throw(ArgumentError("No data availble for:\n" *
                            "    country_code = $country_code\n" *
                            "    starttime = $(unix2datetime(starttime))\n" *
                            "    endtime = $(unix2datetime(endtime))"))
    end
    return newdf
end

function subset_devices(df::DataFrame,device_ids::Union{String,Array{String}})
    # check empty string
    if device_ids == ""
        return df
    end

    # subset
    if isa(device_ids,String)
        newdf = df[df[!,:device_id] .== device_ids,:]
    else
        newdf = df[∈(device_ids).(df.device_id), :]
    end

    # check if any data left
    if size(newdf,1) == 0
        throw(ArgumentError("No data availble for:\n" *
                            "    country_code = $country_code\n" *
                            "    starttime = $(unix2datetime(starttime))\n" *
                            "    endtime = $(unix2datetime(endtime))\n" *
                            "    device_ids: $device_ids"))
    end
    return newdf
end

date_range(s::DateTime,e::DateTime) = floor(s,Minute(5)):Minute(5):ceil(e,Minute(5))


"""
  keys2download(aws,country_code,device_id,starttime,endtime)

Get device metadata for each `country_code` in grillo-openeew dataset.

# Arguments
`aws::AWSConfig`: AWSConfig configuration dictionary.
`country_code::String`: The ISO 3166 two-letter country code, e.g "mx", "cl"..
`device_id::String`: ID of specific device to download.
`starttime::Union{String,TimeType,Real}`: The earliest time of the request.
  in String format (%Y-%m-%dT%H:%M:%S e.g. '2020-02-06T11:00:00'), `Date`,
  `DateTime` format or UnixTime (seconds since 1/1/1970). Only records with time
   greater than or equal to `starttime` will be returned.
`endtime::Union{String,TimeType,Real}`: The latest time of the request.
 in String (%Y-%m-%dT%H:%M:%S e.g. '2020-02-06T12:00:00'), `Date`,
 `DateTime` or UnixTime (seconds since 1/1/1970) formats. Only records with time
  less than or equal to `endtime` will be returned.

# Returns
`Array{String}`: Array of file paths to download from `grillo-openeew` bucket.
"""
function keys2download(
    aws::AWSConfig,
    country_code::String,
    device_id::String,
    starttime::DateTime,
    endtime::DateTime,
)

    files2download = Array{String}(undef,0)
    prefix = get_prefix(country_code,device_id,starttime,endtime)

    # list all possible files
    s3req = AWSSDK.S3.list_objects_v2(
        aws,Bucket="grillo-openeew",prefix=prefix)
    if parse(Int,s3req["KeyCount"]) > 0
        c = s3req["Contents"]
        outfiles = [string(c[ii]["Key"]) for ii = 1:length(c)]
        append!(files2download,outfiles)

        while parse(Bool,s3req["IsTruncated"])
            s3req = AWSSDK.S3.list_objects_v2(
                aws,
                Bucket="grillo-openeew",
                prefix=prefix,
                var"continuation-token"=string(s3req["NextContinuationToken"]),
            )
            c = s3req["Contents"]
            outfiles = [c[ii]["Key"] for ii = 1:length(c)]
            append!(files2download,outfiles)
        end
    else
        @warn("No data availble for:\n" *
                            "    country_code = $country_code\n" *
                            "    starttime = $(starttime)\n" *
                            "    endtime = $(endtime)\n" *
                            "    device_id: $device_id")

    end

    # check downloaded times are correct
    starts = openeew2datetime.(files2download)
    ends = starts .+ Minute(5)
    ind1 = starttime .<= starts .< endtime .<= ends
    ind2 = (starttime .<= starts) .& (endtime .>= ends)
    ind3 = starts .<= starttime .< ends .<= endtime
    ind = ind1 .| ind2 .| ind3

    return files2download[ind]
end

function openeew2datetime(path::String)
    @assert occursin(".jsonl",path)
    yy = path[end-36:end-33]
    mm = path[end-25:end-24]
    dd = path[end-18:end-17]
    hh = path[end-10:end-9]
    m = path[end-7:end-6]
    yy,mm,dd,hh,m = parse.(Int,[yy,mm,dd,hh,m])
    return DateTime(yy,mm,dd,hh,m)
end

function get_prefix(
    country_code::String,
    device_id::String,
    starttime::DateTime,
    endtime::DateTime
)
    prefix = "records/country_code=$country_code/device_id=$device_id/"
    dates = date_range(starttime,endtime)
    ind = findall(.!(dates .>= endtime))
    dates = dates[ind]
    dateprefix = ["year","month","day","hour"]
    datelength = [4,2,2,2]
    for (ii,tfunc) in enumerate([year,month,day,hour])
        periods = unique(tfunc.(dates))
        if length(periods) == 1
            datestr = lpad(string(periods[1]),datelength[ii],'0')
            prefix = joinpath(prefix,"$(dateprefix[ii])=$datestr")
        else
            break
        end
    end

    if prefix[end] != '/'
        prefix *= '/'
    end
    return prefix
end
