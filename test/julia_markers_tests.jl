using LLVMLoopInfo, InteractiveUtils, Test

function loopinfo_nodes(options)
  ex = macroexpand(@__MODULE__, Meta.parse("@loopinfo $options for i in 1:2\nend"))
  body = ex.args[2]
  return last(body.args).args
end

@testset "Julia loop markers" begin
  @test loopinfo_nodes("ivdep") == Any[Symbol("julia.ivdep")]
  @test loopinfo_nodes("simd") == Any[Symbol("julia.simdloop")]
  @test loopinfo_nodes("var\"julia.ivdep\"") == Any[Symbol("julia.ivdep")]
  @test loopinfo_nodes("ivdep=false") == Any[nothing]
  @test loopinfo_nodes("simd ivdep unroll=false") ==
        Any[Symbol("julia.simdloop"), Symbol("julia.ivdep"), (Symbol("llvm.loop.unroll.disable"), 1)]
end

function copy_plain!(a, b)
  @inbounds for i in eachindex(a)
    a[i] = 2 * b[i]
  end
  a
end
function copy_ivdep!(a, b)
  @inbounds @loopinfo ivdep for i in eachindex(a)
    a[i] = 2 * b[i]
  end
  a
end
function sum_plain(x)
  s = zero(eltype(x))
  @inbounds for i in eachindex(x)
    s += x[i]
  end
  s
end
function sum_simd(x)
  s = zero(eltype(x))
  @inbounds @loopinfo simd for i in eachindex(x)
    s += x[i]
  end
  s
end

llvm_ir(f, tt) = sprint(io -> InteractiveUtils.code_llvm(io, f, tt; raw = true, debuginfo = :none))

if Base.JLOptions().check_bounds != 1
  @testset "julia.ivdep / julia.simdloop codegen" begin
    T = Tuple{Vector{Float64},Vector{Float64}}
    # `julia.ivdep` marks the memory accesses as parallel, so no runtime alias checks are needed
    @test !occursin("llvm.mem.parallel_loop_access", llvm_ir(copy_plain!, T))
    @test occursin("llvm.mem.parallel_loop_access", llvm_ir(copy_ivdep!, T))
    # `julia.simdloop` allows reassociating the reduction, so it gets vectorized
    @test !occursin(r"fadd reassoc|fadd fast", llvm_ir(sum_plain, Tuple{Vector{Float64}}))
    @test occursin(r"fadd reassoc|fadd fast", llvm_ir(sum_simd, Tuple{Vector{Float64}}))
    x = rand(100); y = similar(x)
    @test copy_ivdep!(y, x) == 2 .* x
    @test sum_simd(x) ≈ sum(x)
  end
end
