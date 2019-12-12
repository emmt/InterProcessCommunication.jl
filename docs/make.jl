using Documenter

push!(LOAD_PATH, "../src/")
using InterProcessCommunication

DEPLOYDOCS = (get(ENV, "CI", nothing) == "true")

makedocs(
    sitename = "Inter-Process Communication",
    format = Documenter.HTML(
        prettyurls = DEPLOYDOCS,
    ),
    authors = "Éric Thiébaut and contributors",
    pages = ["index.md", "semaphores.md", "sharedmemory.md", "reference.md"]
)

if DEPLOYDOCS
    deploydocs(
        repo = "github.com/emmt/InterProcessCommunication.jl.git",
    )
end
