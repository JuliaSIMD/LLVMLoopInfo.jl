using LLVMLoopInfo, InteractiveUtils, Test

function loopinfo_nodes(options)
  ex =
    macroexpand(@__MODULE__, Meta.parse("@loopinfo $options for i in 1:2\nend"))
  return last(ex.args[2].args).args
end

@testset "followup nodes" begin
  @test loopinfo_nodes("followup_vectorized=(unrollcount=2,)") == Any[(
    Symbol("llvm.loop.vectorize.followup_vectorized"),
    (Symbol("llvm.loop.unroll.count"), 2)
  )]
  @test loopinfo_nodes("followup_epilogue=unrollfull") == Any[(
    Symbol("llvm.loop.vectorize.followup_epilogue"),
    (Symbol("llvm.loop.unroll.full"), 1)
  )]
  @test loopinfo_nodes("followup_unrolled=(unroll=false, vectorize=false)") ==
        Any[(
    Symbol("llvm.loop.unroll.followup_unrolled"),
    (Symbol("llvm.loop.unroll.disable"), 1),
    (Symbol("llvm.loop.vectorize.disable"), 1)
  )]
  @test loopinfo_nodes(
    "var\"llvm.loop.vectorize.followup_all\"=(unroll=false,)"
  ) == Any[(
    Symbol("llvm.loop.vectorize.followup_all"),
    (Symbol("llvm.loop.unroll.disable"), 1)
  )]
  # plain options are unchanged
  @test loopinfo_nodes("vectorize unroll=false vectorwidth=4") == Any[
    (Symbol("llvm.loop.vectorize.enable"), 1),
    (Symbol("llvm.loop.unroll.disable"), 1),
    (Symbol("llvm.loop.vectorize.width"), 4)
  ]
end

function double_nounroll!(y, x)
  @inbounds @loopinfo(
    vectorize,
    vectorwidth = 4,
    interleave = 1,
    unroll = false,
    for i in eachindex(x, y)
      y[i] = 2 * x[i]
    end
  )
  y
end
# unrolling is disabled for the original loop, but the vectorized loop is
# unrolled by 2
function double_followup!(y, x)
  @inbounds @loopinfo(
    vectorize,
    vectorwidth = 4,
    interleave = 1,
    unroll = false,
    followup_vectorized = (unrollcount = 2,),
    for i in eachindex(x, y)
      y[i] = 2 * x[i]
    end
  )
  y
end

numoccurences(x, str) = length(collect(eachmatch(x, str)))

@testset "followup metadata" begin
  T = Tuple{Vector{Float64},Vector{Float64}}
  ir = sprint(
    io -> InteractiveUtils.code_llvm(
      io,
      double_followup!,
      T;
      optimize = false,
      raw = true,
      dump_module = true
    )
  )
  m = match(r"(![0-9]+) = !{!\"llvm.loop.unroll.count\", i64 2}", ir)
  @test m !== nothing
  @test occursin("!{!\"llvm.loop.vectorize.followup_vectorized\", $(m[1])}", ir)
end

# Julia's pass pipeline runs LoopUnroll after LoopVectorize only on newer versions
if Base.JLOptions().check_bounds != 1 && VERSION >= v"1.10"
  @testset "followup codegen" begin
    T = Tuple{Vector{Float64},Vector{Float64}}
    ir(f) = sprint(io -> InteractiveUtils.code_llvm(io, f, T))
    @test numoccurences(r" = load <4 x double>", ir(double_nounroll!)) == 1
    @test numoccurences(r" = load <4 x double>", ir(double_followup!)) >= 2
  end
end

@testset "followup results" begin
  x = rand(37)
  @test double_followup!(similar(x), x) == 2 .* x
end
