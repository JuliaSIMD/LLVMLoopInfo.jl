using LLVMLoopInfo, PerformanceTestTools, Test

@testset "LLVMLoopInfo.jl" begin
  PerformanceTestTools.@include("vectorization_tests.jl")
end
