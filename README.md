# OpenEEW

The OpenEEW.jl is Julia package for working with OpenEEW, including:

- downloading and analyzing accelerometer data
- real-time data processing
- detection algorithms

Currently it provides a client to simplify downloading data held as an [AWS Public Dataset](https://registry.opendata.aws/grillo-openeew/). See [here](https://github.com/grillo/openeew/tree/master/data#accessing-openeew-data-on-aws) for information about how data is organized.


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
