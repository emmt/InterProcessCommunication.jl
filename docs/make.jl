using Documenter
push!(LOAD_PATH,"../src/")
using IPC
DEPLOYDOCS = (get(ENV, "CI", nothing) == "true")

makedocs(
    sitename = "IPC.jl Package",
    format = Documenter.HTML(prettyurls = DEPLOYDOCS),
    pages = ["index.md", "semaphores.md", "reference.md"]
)

if DEPLOYDOCS
    deploydocs(repo = "github.com/emmt/IPC.jl.git")
end
