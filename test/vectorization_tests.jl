using LLVMLoopInfo, InteractiveUtils, Test

function vpdot(x, y)
  s = zero(Base.promote_eltype(x, y))
  # generate single loop body and mask it
  @loopinfo predicate for i in eachindex(x, y)
    @inbounds @fastmath s += x[i] * y[i]
  end
  s
end
function v8dot(x, y)
  s = zero(Base.promote_eltype(x, y))
  # use a 8 elements/SIMD vector
  @loopinfo vectorwidth = 8 for i in eachindex(x, y)
    @inbounds @fastmath s += x[i] * y[i]
  end
  s
end
function v8preddot(x, y) # can add multiple loop info
  s = zero(Base.promote_eltype(x, y))
  # generate single loop body and mask it
  @loopinfo vectorwidth = 8 predicate for i in eachindex(x, y)
    @inbounds @fastmath s += x[i] * y[i]
  end
  s
end
function u1dot(x, y)
  s = zero(Base.promote_eltype(x, y))
  # unroll count = 1
  @loopinfo unrollcount = 1 for i in eachindex(x, y)
    @fastmath @inbounds s += x[i] * y[i]
  end
  s
end
function u2dot(x, y)
  s = zero(Base.promote_eltype(x, y))
  # unroll count = 1
  @loopinfo unrollcount = 2 for i in eachindex(x, y)
    @fastmath @inbounds s += x[i] * y[i]
  end
  s
end
function udot(x, y)
  s = zero(Base.promote_eltype(x, y))
  # unroll
  @loopinfo unroll for i in eachindex(x, y)
    @fastmath @inbounds s += x[i] * y[i]
  end
  s
end
function noudot(x, y)
  s = zero(Base.promote_eltype(x, y))
  # don't unroll
  @loopinfo unroll = false for i in eachindex(x, y)
    @fastmath @inbounds s += x[i] * y[i]
  end
  s
end

numoccurences(x, str) = length(collect(eachmatch(x, str)))

if Base.JLOptions().check_bounds != 1
  io = IOBuffer()
  InteractiveUtils.code_llvm(io, vpdot, Tuple{Vector{Float64},Vector{Float64}})
  str = String(take!(io))
  @test numoccurences(r"@llvm.masked.load.v", str) == 2
  InteractiveUtils.code_llvm(
    io,
    v8preddot,
    Tuple{Vector{Float64},Vector{Float64}}
  )
  str = String(take!(io))
  @test numoccurences(
    r"call <8 x double> @llvm.masked.load.v8f64.p0v8f64",
    str
  ) == 2

  InteractiveUtils.code_llvm(io, noudot, Tuple{Vector{Float64},Vector{Float64}})
  stru = String(take!(io))
  @test !occursin(r"call <8 x double> @llvm.masked.load.v8f64.p0v8f64", stru)
  @test numoccurences(r" = load <[0-9] x double>", stru) == 2

  InteractiveUtils.code_llvm(io, u1dot, Tuple{Vector{Float64},Vector{Float64}})
  stru = String(take!(io))
  @test !occursin(r"call <8 x double> @llvm.masked.load.v8f64.p0v8f64", stru)
  @test numoccurences(r" = load <[0-9] x double>", stru) == 2

  InteractiveUtils.code_llvm(io, u2dot, Tuple{Vector{Float64},Vector{Float64}})
  stru = String(take!(io))
  @test !occursin(r"call <8 x double> @llvm.masked.load.v8f64.p0v8f64", stru)
  @test numoccurences(r" = load <[0-9] x double>", stru) == 4
end
