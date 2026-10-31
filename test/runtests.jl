using LLVMLoopInfo, PerformanceTestTools, Test

@testset "LLVMLoopInfo.jl" begin
  PerformanceTestTools.@include("vectorization_tests.jl")
  PerformanceTestTools.@include("julia_markers_tests.jl")
end
