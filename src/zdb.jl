module zdb

using Dates
using HTTP
using JSON3
using Serialization

BASE_URL = "http://localhost:7878"
nanoseconds(x::DateTime)::Int64 = (Dates.value(x) - Dates.UNIXEPOCH) * 1_000_000

function symbols(table::String, column::String)::Vector{String}
  req = HTTP.request("GET", "$BASE_URL/symbols/$table/$column")
  if req.status != 200
    throw(ArgumentError(String(req.body)))
  end

  JSON3.read(String(req.body))
end

function query(table::String, from::Union{Int64,String}, to::Union{Int64,String}, query::String)
  query = JSON3.write(Dict([
     "table" => table,
     "from" => from,
     "to" => to,
     "query" => query
    ]))
  req = HTTP.request("POST", "$BASE_URL/q", [], query)

  if req.status != 200
    throw(ArgumentError(String(req.body)))
  end

  deserialize(IOBuffer(req.body))
end

end

