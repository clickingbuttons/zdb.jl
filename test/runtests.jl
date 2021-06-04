import zdb
using Dates
using HTTP
using JSON3

table = "agg1d"
symbol_names = zdb.symbols(table, "sym")
get_sym(sym::String) = findfirst(s -> s == sym, symbol_names) - 1

function zdb_symbols(from::DateTime, to::DateTime)
  zdb.query(
    table,
    zdb.nanoseconds(from),
    zdb.nanoseconds(to),
    "
    symbols = Dict{UInt16, Vector{Int64}}()
    function scan(ts::Vector{Int64}, sym::Vector{UInt16})
      for (t, s) in zip(ts, sym)
        if !haskey(symbols, s)
          symbols[s] = []
        end
        push!(symbols[s], t)
      end
      symbols
    end
    "
  )
end

function polygon_symbols(date::DateTime)
  res = HTTP.request("GET", "https://api.polygon.io/v2/aggs/grouped/locale/us/market/stocks/$(Dates.format(date, "yyyy-mm-dd"))?unadjusted=true&apiKey=E80ie5j0IXbd3BZX3im1BdWaZUFxbukL")

  results = JSON3.read(res.body).results
  Set(map(r -> r.T, results))
end

#=
d = DateTime("2021-01-04")
syms_a = zdb_symbolsl(d, d)
syms_b = polygon_symbols(d)
println(length(syms_a), " vs ", length(syms_b))
println(setdiff(syms_b, syms_a))
=#

from = DateTime("2004-03-01")
to = DateTime("2004-03-31")
num_days = zdb_symbols(from, to)[get_sym("CINpJ")]
println(map(n -> Dates.unix2datetime(n / 1_000_000_000), num_days))

