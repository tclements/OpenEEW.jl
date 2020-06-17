# OpenEEW

OpenEEW.jl is a Julia package for working with the [OpenEEW AWS Public Dataset](https://registry.opendata.aws/grillo-openeew/). It provides a client to simplify downloading accelerometer data from AWS. See [here](https://github.com/grillo/openeew/tree/master/data#accessing-openeew-data-on-aws) for information about how the data are organized.

For further analysis of the data, we suggest using [SeisIO](https://github.com/jpjones76/SeisIO.jl). 


Some additional resources:

- [OpenEEW GitHub repository](https://github.com/grillo/openeew)
- [openeew-python GitHub repository](https://github.com/grillo/openeew-python)

Installation
===========

You can install the latest version of OpenEEW using the Julia package manager (Press `]` to enter `pkg`). 
From the Julia command prompt:

```julia
julia>]
(@v1.4) pkg> add https://github.com/tclements/OpenEEW.jl
```

Or, equivalently, via the `Pkg` API:

```julia
julia> using Pkg; Pkg.add(PackageSpec(url="https://github.com/tclements/OpenEEW.jl", rev="master"))
```

We recommend using the latest version of OpenEEW by updating with the Julia package manager:

```julia 
(@v1.4) pkg> update OpenEEW
```

# Usage 
Here is an example of how the package can be used to download data for a chosen date range.
First import the `OpenEEW` package: 

```julia
using OpenEEW
```

Get your AWS credentials to access the `grillo-openeew` [bucket](https://registry.opendata.aws/grillo-openeew/) in the `us-east-1` region: 

```julia
aws = OpenEEW.aws_config(region="us-east-1")
```

Select a country, either `mx` for Mexico or `cl` for Chile to get data:

```julia
country_code = "cl"
```

Query the current devices: 

```julia
devices = get_devices(aws,country_code)
```

To get data for a specific (UTC) date range, first specify the start and end dates:
```julia
starttime = OpenEEW.DateTime(2019,1,27)
endtime = OpenEEW.DateTime(2019,1,29)
```

Then call `get_records` to get data:
```julia
S = get_records(aws,country_code,starttime,endtime)
SeisIO.SeisData with 12 channels (3 shown)
    ID: cl.1000..x                         cl.1000..y                         cl.1000..z                         …
  NAME: cl.1000..x                         cl.1000..y                         cl.1000..z                         …
   LOC: 0.0 N, 0.0 E, 0.0 m                0.0 N, 0.0 E, 0.0 m                0.0 N, 0.0 E, 0.0 m                …
    FS: 31.25                              31.25                              31.25                              …
  GAIN: 1.0                                1.0                                1.0                                …
  RESP: a0 1.0, f0 1.0, 0z, 0p             a0 1.0, f0 1.0, 0z, 0p             a0 1.0, f0 1.0, 0z, 0p             …
 UNITS:                                                                                                          …
   SRC:                                                                                                          …
  MISC: 0 entries                          0 entries                          0 entries                          …
 NOTES: 1 entries                          1 entries                          1 entries                          …
     T: 2019-01-27T00:00:00 (26 gaps)      2019-01-27T00:00:00 (26 gaps)      2019-01-27T00:00:00 (26 gaps)      …
     X: -4.000e-02                         -3.000e-02                         +0.000e+00                         …
        -3.000e-02                         +2.000e-02                         +0.000e+00                         …
            ...                                ...                                ...                            …
        -6.838e-03                         +8.787e-03                         +1.737e-02                         …
        (nx = 3425534)                     (nx = 3425534)                     (nx = 3425534)                     …
     C: 0 open, 0 total
```

Data is returned as a [SeisIO](https://github.com/jpjones76/SeisIO.jl) `SeisData` structure, which allows for further processing with `SeisIO`. 
