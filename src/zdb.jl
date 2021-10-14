module zdb

using Dates
using JSON3
using StructTypes

ZDB_HOME = ENV["ZDB_HOME"]
nanoseconds(x::DateTime)::Int64 = (Dates.value(x) - Dates.UNIXEPOCH) * 1_000_000
nanoseconds(x::Date)::Int64 = (Dates.value(DateTime(x)) - Dates.UNIXEPOCH) * 1_000_000

struct Column
  name::String
  type::String
  size::Int64
  resolution::Int64
  sym_name::String
end
StructTypes.StructType(::Type{Column}) = StructTypes.Struct()

struct Schema
  columns::Vector{Column}
  partition_by::String
  partition_dirs::Vector{String}
end
StructTypes.StructType(::Type{Schema}) = StructTypes.Struct()

struct PartitionMeta
  dir::String
  from_ts::Int64
  to_ts::Int64
  min_ts::Int64
  max_ts::Int64
  row_count::UInt64
end
StructTypes.StructType(::Type{PartitionMeta}) = StructTypes.Struct()

struct TableMeta
  schema::Schema
  partition_meta::Dict{String, PartitionMeta}
  dir_index::UInt64
end
StructTypes.StructType(::Type{TableMeta}) = StructTypes.Struct()

struct Table
  name::String
  meta::TableMeta
end
StructTypes.StructType(::Type{Table}) = StructTypes.Struct()

function data_path(name::String)
  joinpath(ZDB_HOME, "data", name)
end

function open(name::String)::Table
  meta_path = joinpath(data_path(name), "_meta")
  println(meta_path)
  meta = read(meta_path, String)

  Table(name, JSON3.read(meta, TableMeta))
end

function symbols(table::Table, column::String)::Vector{String}
  symbol_path = ""
  column = findfirst(c -> c.name == column, table.meta.schema.columns)
  column = table.meta.schema.columns[column]
  if isempty(column.sym_name)
    symbol_path = joinpath(data_path(table.name), "$(column.name).symbols")
  else
    symbol_path = joinpath(data_path(table.name), "../$(column.sym_name).symbols")
  end

  readlines(symbol_path)
end

function query(table::String, from::Union{Int64, String}, to::Union{Int64, String}, query::String)
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

