module LLVMLoopInfo

export @loopinfo

function loopinfo(expr, nodes...)
  if expr.head !== :for
    error("Syntax error: loopinfo needs a for loop")
  end
  push!(expr.args[2].args, Expr(:loopinfo, nodes...))
  return expr
end

map_symbol(s::Symbol, arg)::Tuple{Symbol,Int} =
  if s === :predicate
    if arg === 0 || arg === false
      return Symbol("llvm.loop.predicate.disable"), 1
    end
    return Symbol("llvm.loop.vectorize.predicate.enable"), something(arg, 1)
  elseif s === :vectorize
    if arg === 0 || arg === false
      return Symbol("llvm.loop.vectorize.disable"), 1
    end
    return Symbol("llvm.loop.vectorize.enable"), something(arg, 1)
  elseif s === :unroll
    if arg === 0 || arg === false
      return Symbol("llvm.loop.unroll.disable"), 1
    end
    return Symbol("llvm.loop.unroll.enable"), something(arg, 1)
  elseif s === :unrollfull
    return Symbol("llvm.loop.unroll.full"), something(arg, 1)
  elseif s === :unrollcount
    return Symbol("llvm.loop.unroll.count"), something(arg, 4)
  elseif s === :jam
    if arg === 0 || arg === false
      return Symbol("llvm.loop.unroll_and_jam.disable"), 1
    end
    return Symbol("llvm.loop.unroll_and_jam.enable"), something(arg, 1)
  elseif s === :jamcount
    return Symbol("llvm.loop.unroll_and_jam.count"), something(arg, 4)
  elseif s === :interleave
    return Symbol("llvm.loop.interleave.count"), something(arg, 4)
  elseif s === :scalable
    if arg === 0 || arg === false
      return Symbol("llvm.loop.vectorize.scalable.disable"), 1
    end
    return Symbol("llvm.loop.vectorize.scalable.enable"), something(arg, 1)
  elseif s === :vectorwidth
    return Symbol("llvm.loop.vectorize.width"), something(arg, 8)
  else
    return s, something(arg, 1)
  end

# Followup attributes, see
# https://llvm.org/docs/TransformMetadata.html#transformation-metadata
const FOLLOWUPS = Dict{Symbol,Symbol}(
  :followup_vectorize => Symbol("llvm.loop.vectorize.followup_all"),
  :followup_vectorized => Symbol("llvm.loop.vectorize.followup_vectorized"),
  :followup_epilogue => Symbol("llvm.loop.vectorize.followup_epilogue"),
  :followup_unroll => Symbol("llvm.loop.unroll.followup_all"),
  :followup_unrolled => Symbol("llvm.loop.unroll.followup_unrolled"),
  :followup_remainder => Symbol("llvm.loop.unroll.followup_remainder"),
  :followup_jam => Symbol("llvm.loop.unroll_and_jam.followup_all"),
  :followup_outer => Symbol("llvm.loop.unroll_and_jam.followup_outer"),
  :followup_inner => Symbol("llvm.loop.unroll_and_jam.followup_inner"),
  :followup_remainder_outer =>
    Symbol("llvm.loop.unroll_and_jam.followup_remainder_outer"),
  :followup_remainder_inner =>
    Symbol("llvm.loop.unroll_and_jam.followup_remainder_inner"),
  :followup_distribute => Symbol("llvm.loop.distribute.followup_all"),
  :followup_coincident => Symbol("llvm.loop.distribute.followup_coincident"),
  :followup_sequential => Symbol("llvm.loop.distribute.followup_sequential"),
  :followup_fallback => Symbol("llvm.loop.distribute.followup_fallback")
)

# The value of a followup is a single option or a tuple of options, e.g.
# `followup_vectorized = unrollfull` or `followup_vectorized = (unroll = false,)`.
is_nested(val) =
  val isa Symbol || Meta.isexpr(val, :tuple) || Meta.isexpr(val, :(=))
nested_args(val) = Meta.isexpr(val, :tuple) ? val.args : Any[val]

function process_arg(arg)
  if arg isa Expr && is_nested(arg.args[2])
    name = get(FOLLOWUPS, arg.args[1], arg.args[1])
    return (name, map(process_arg, nested_args(arg.args[2]))...)
  end
  arg isa Symbol && (arg = (arg, nothing))
  arg isa Expr && (arg = (arg.args[1], arg.args[2]))
  map_symbol(arg[1], arg[2])
end

"""
@loopinfo unrollcount[ = 4]
@loopinfo predicate
@loopinfo vectorize
@loopinfo unrollfull
@loopinfo jam
@loopinfo jamcount[ = 4]
@loopinfo interleave[ = 4]
@loopinfo followup_vectorized = (options...)

Followup attributes (`followup_vectorized`, `followup_epilogue`,
`followup_unrolled`, `followup_remainder`, `followup_outer`, `followup_inner`,
...) set the loop properties of the loops created by a transformation, e.g.
`@loopinfo vectorize unroll=false followup_vectorized=(unrollcount=2,)`
disables unrolling before vectorization but unrolls the vectorized loop by 2.
The value is a single option or a tuple of options. A full LLVM name can be
used as well, e.g. `var"llvm.loop.vectorize.followup_all"=(unroll=false,)`.

See https://llvm.org/docs/TransformMetadata.html#transformation-metadata for information on llvm loopinfo.
"""
macro loopinfo(args...)
  esc(loopinfo(last(args), map(process_arg, Base.front(args))...))
end

end
