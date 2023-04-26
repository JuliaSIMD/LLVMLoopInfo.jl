using LLVMLoopInfo
using Documenter

DocMeta.setdocmeta!(LLVMLoopInfo, :DocTestSetup, :(using LLVMLoopInfo); recursive=true)

makedocs(;
    modules=[LLVMLoopInfo],
    authors="chriselrod <elrodc@gmail.com> and contributors",
    repo="https://github.com/chriselrod/LLVMLoopInfo.jl/blob/{commit}{path}#{line}",
    sitename="LLVMLoopInfo.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)
