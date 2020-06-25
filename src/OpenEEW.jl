module OpenEEW

using Dates
using AWSCore, AWSS3, AWSSDK, DataFrames, Interpolations, JSON2, SeisIO, StructArrays
include("io.jl")
include("aws.jl")
end
