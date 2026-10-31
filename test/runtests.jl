using LLVMLoopInfo, PerformanceTestTools, Test

@testset "LLVMLoopInfo.jl" begin
  PerformanceTestTools.@include("vectorization_tests.jl")
  PerformanceTestTools.@include("followup_tests.jl")
end
