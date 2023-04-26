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

function process_arg(arg)::Tuple{Symbol,Int}
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

See https://llvm.org/docs/TransformMetadata.html#transformation-metadata for information on llvm loopinfo.
"""
macro loopinfo(args...)
  esc(loopinfo(last(args), map(process_arg, Base.front(args))...))
end

end
