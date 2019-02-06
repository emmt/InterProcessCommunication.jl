using Documenter

push!(LOAD_PATH,"../src/")
using IPC

DEPLOYDOCS = true #(get(ENV, "CI", nothing) == "true")

makedocs(
    sitename = "IPC.jl Package",
    #format = Documenter.HTML(
    #    prettyurls = DEPLOYDOCS,
    #),
    authors = "Éric Thiébaut and contributors",
    pages = ["index.md", "semaphores.md", "reference.md"]
)

if DEPLOYDOCS
    deploydocs(
        repo = "github.com/emmt/IPC.jl.git",
    )
end
