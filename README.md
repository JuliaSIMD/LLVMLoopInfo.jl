# LLVMLoopInfo

[![Build Status](https://github.com/chriselrod/LLVMLoopInfo.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/chriselrod/LLVMLoopInfo.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/chriselrod/LLVMLoopInfo.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/chriselrod/LLVMLoopInfo.jl)

See [LLVM's docs](https://llvm.org/docs/TransformMetadata.html#transformation-metadata) for info on loop info.
Julia allows specifying loop info, but doesn't have a convenient API for doing so. This package aims to provide one.
```julia
using LLVMLoopInfo, LoopVectorization, BenchmarkTools

x = rand(31);
y = rand(31);

function fmdot(x,y) # set the baseline
  s = zero(Base.promote_eltype(x,y))
  for i = eachindex(x,y)
    @inbounds @fastmath s += x[i]*y[i]
  end
  s
end
function simddot(x,y) # set the baseline
  s = zero(Base.promote_eltype(x,y))
  @inbounds @simd for i = eachindex(x,y)
    s += x[i]*y[i]
  end
  s
end
function lvdot(x,y) # set the baseline
  s = zero(Base.promote_eltype(x,y))
  @turbo for i = eachindex(x,y)
    s += x[i]*y[i]
  end
  s
end
function vpdot(x,y)
  s = zero(Base.promote_eltype(x,y))
  # generate single loop body and mask it
  @loopinfo predicate for i = eachindex(x,y)
    @inbounds @fastmath s += x[i]*y[i]
  end
  s
end
function v8dot(x,y)
  s = zero(Base.promote_eltype(x,y))
  # generate single loop body and mask it
  @loopinfo vectorwidth=8 for i = eachindex(x,y)
    @inbounds @fastmath s += x[i]*y[i]
  end
  s
end
function v8preddot(x,y) # can add multiple loop info
  s = zero(Base.promote_eltype(x,y))
  # generate single loop body and mask it
  @loopinfo vectorwidth=8 predicate for i = eachindex(x,y)
    @inbounds @fastmath s += x[i]*y[i]
  end
  s
end
function u1dot(x,y)
  s = zero(Base.promote_eltype(x,y))
  # unroll count = 1
  @loopinfo unrollcount=1 for i = eachindex(x,y)
    @fastmath @inbounds s += x[i]*y[i]
  end
  s
end
function udot(x,y)
  s = zero(Base.promote_eltype(x,y))
  # don't unroll
  @loopinfo unroll for i = eachindex(x,y)
    @fastmath @inbounds s += x[i]*y[i]
  end
  s
end
function noudot(x,y)
  s = zero(Base.promote_eltype(x,y))
  # don't unroll
  @loopinfo unroll=false for i = eachindex(x,y)
    @fastmath @inbounds s += x[i]*y[i]
  end
  s
end

@btime fmdot($x,$y)
@btime simddot($x,$y)
@btime lvdot($x,$y)
@btime vpdot($x,$y)
@btime v8dot($x,$y)
@btime v8preddot($x,$y)
@btime u1dot($x,$y)
@btime udot($x,$y)
@btime noudot($x,$y)
```
Sample result:
```julia
julia> @btime fmdot($x,$y)
  14.898 ns (0 allocations: 0 bytes)
7.074580745671837

julia> @btime simddot($x,$y)
  15.143 ns (0 allocations: 0 bytes)
7.074580745671837

julia> @btime lvdot($x,$y)
  7.471 ns (0 allocations: 0 bytes)
7.074580745671838

julia> @btime vpdot($x,$y)
  9.268 ns (0 allocations: 0 bytes)
7.074580745671838

julia> @btime v8dot($x,$y)
  20.499 ns (0 allocations: 0 bytes)
7.074580745671838

julia> @btime v8preddot($x,$y)
  7.488 ns (0 allocations: 0 bytes)
7.074580745671838

julia> @btime u1dot($x,$y)
  8.240 ns (0 allocations: 0 bytes)
7.074580745671837

julia> @btime udot($x,$y)
  11.746 ns (0 allocations: 0 bytes)
7.074580745671838

julia> @btime noudot($x,$y)
  8.239 ns (0 allocations: 0 bytes)
7.074580745671837

julia> versioninfo()
Julia Version 1.10.0-DEV.1119
Commit 960870e3c6 (2023-04-26 07:43 UTC)
Platform Info:
  OS: Linux (x86_64-generic-linux)
  CPU: 28 × Intel(R) Core(TM) i9-9940X CPU @ 3.30GHz
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-14.0.6 (ORCJIT, skylake-avx512)
  Threads: 28 on 28 virtual cores
```
Options include `:vectorize`, `:predicate` (implies `:vectorize`), and more.
See
```julia
@less LLVMLoopInfo.map_symbol(:unroll, 1)
```
to see all the automatically expanded options. Note you can manually specify
```julia
  @loopinfo var"llvm.loop.unroll.count"=4 for ...
```
if an option isn't available. If something you're looking for is missing, please file a PR.

Explanation on the above example:
The CPU I'm benchmarking on has AVX512. By default, LLVM will create two loops:
1. An unrolled and vectorized loop. It'll unroll by 4x, and use 256 bit vectors (even though the CPU has AVX512). A 256 bit vector can hold 4x `Float64`.
2. A scalar epilogue loop.

I'm evaluating the dot product on vectors of length 31. Thus, it'll be evaluated with 1 iteration of the first loop (covering 4*4=16 iterations), and then 15 iterations of the scalar loop.
This is what happens with the `fmdot` and `simddot` loops.

Enabling predicates will instead create a single not-unrolled vector loop, that masks excess iterations. `vpdot` will thus evaluate this loop 8 times, using masked operations in case it overshoots (which it does on the last iteration). This is much faster, as we don't have the long scalar epilogue.

Setting the vector width to 8 means that each iteration of the unrolled and vectorized loop will cover 4*8 = 32 iterations. However, our loop is only 31 iterations total. In other words, setting a vector width of 8 means we end up doing 0 vector iterations and 31 scalar epilogue iterations. This is thus slow.

Enabling vector width of 8 and predication means we instead do 4 masked vector iterations. This is fast, and ties with `LoopVectorization.jl`'s `@turbo`, which also uses predication and masking (but `@turbo` also unrolls, and will thus be faster when we have higher trip counts).

`unrollcount=1` means we unroll only once, as does `unroll=false`. With a vector width of `4`, these mean we have 7 unmasked vector iterations, followed by 3 scalar iterations.

Setting `unroll=true` generates some nasty looking assembly full of shuffles. Performance is better than I'd have thought, perhaps because it does vectorize the epilogue.

