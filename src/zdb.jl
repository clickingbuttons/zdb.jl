module zdb

using Dates
using Mmap
using JSON3
using StructTypes

ZDB_HOME = ENV["ZDB_HOME"]
nanoseconds(x::Int64)::Int64 = x
nanoseconds(x::Date)::Int64 = (Dates.value(DateTime(x)) - Dates.UNIXEPOCH) * 1_000_000
nanoseconds(x::DateTime)::Int64 = (Dates.value(x) - Dates.UNIXEPOCH) * 1_000_000
nanoseconds(x::String)::Int64 = nanoseconds(Date(x, dateformat"y-m-d"))

datetime(nanos::Int64) = unix2datetime(nanos / 1_000_000_000)

@enum ColumnType begin
  Timestamp
  Symbol8
  Symbol16
  Symbol32
  I8
  U8
  I16
  U16
  I32
  U32
  F32
  I64
  U64
  F64
end

struct Column
  name::String
  type::ColumnType
  size::UInt64
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

function data_path(name::String)::String
  joinpath(ZDB_HOME, "data", name)
end

function open(name::String)::Table
  meta_path = joinpath(data_path(name), "_meta")
  meta = read(meta_path, String)

  Table(name, JSON3.read(meta, TableMeta))
end

function get_col_type(column_type::ColumnType, size::UInt64)::Type
  if column_type == I8
    Int8
  elseif column_type == U8 || column_type == Symbol8 
    UInt8
  elseif column_type == I16 || column_type == Symbol16
    Int16
  elseif column_type == U16
    UInt16
  elseif column_type == I32
    Int32
  elseif column_type == U32 || column_type == Symbol32
    UInt32
  elseif column_type == F32
    Float32
  elseif column_type == I64
    Int64
  elseif column_type == U64
    UInt64
  elseif column_type == F64
    Float64
  elseif column_type == Timestamp
    if size == 1
      UInt8
    elseif size == 2
      UInt16
    elseif size == 4
      UInt32
    elseif size == 8
      Int64
    end
  else
    throw(DomainError(column_type, "needs to map to type"))
  end
end

struct TableColumn
  name::String
  file::IO
  data::Any # Vector{Real} causes a copy on constructing :(
  path::String
  type::ColumnType
  size::UInt64
  resolution::Int64
end

function get_col_path(
  partition_dir::String,
  table_name::String,
  column::Column
)::String
  fname = column.name * '.' * lowercase(string(column.type))
  joinpath(data_path(table_name), partition_dir, fname)
end

function open_column(
  partition_dir::String,
  table_name::String,
  row_count::Integer,
  offset::Integer,
  column::Column
)::TableColumn
  path = get_col_path(partition_dir, table_name, column)
  file = Base.open(path, "r")
  data = Mmap.mmap(
    file,
    Vector{get_col_type(column.type, column.size)},
    (row_count,),
    offset
  )
  TableColumn(
    column.name,
    file,
    data,
    path,
    column.type,
    column.size,
    column.resolution
  )
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

struct PartitionIter
  from_ts::Int64
  to_ts::Int64
  ts_column::Column
  columns::Vector{Column}
  table_name::String
  partitions::Vector{Tuple{String, PartitionMeta}}
end

function find_ts(ts_column::TableColumn, ts::Real, seek_start::Bool)::Int64
  needle = get_col_type(ts_column.type, ts_column.size)(ts / ts_column.resolution)
  len = length(ts_column.data) / ts_column.size
  if seek_start
    searchsortedfirst(ts_column.data, needle)
  else
    searchsortedlast(ts_column.data, needle) + 1
  end
end

Base.iterate(p::PartitionIter) = Base.iterate(p, UInt64(1))
Base.eltype(p::PartitionIter) = Vector{TableColumn}
Base.length(p::PartitionIter) = length(p.partitions)

function Base.iterate(p::PartitionIter, index::UInt64)
  if index - 1 == length(p.partitions)
    return nothing
  end
  (partition_dir, partition_meta) = p.partitions[index]
  start_row = index == 1 ? begin
      ts_column = open_column(
        partition_dir,
        p.table_name,
        partition_meta.row_count,
        0,
        p.ts_column
      )
      needle = ts_column.resolution == 1 ? p.from_ts : p.from_ts - partition_meta.min_ts
      find_ts(ts_column, needle, true)
    end : 1
  end_row = index == length(p.partitions) ? begin
      ts_column = open_column(
        partition_dir,
        p.table_name,
        partition_meta.row_count,
        0,
        p.ts_column
      )
      needle = ts_column.resolution == 1 ? p.to_ts : p.to_ts - partition_meta.min_ts
      find_ts(ts_column, needle, false)
    end : partition_meta.row_count

  data_columns = Vector{TableColumn}()
  for column in p.columns
    data_column = open_column(
      partition_dir,
      p.table_name,
      end_row - start_row,
      (start_row - 1) * column.size,
      column
    )
    push!(data_columns, data_column)
  end

  (data_columns, index + 1)
end

function get_union(table::Table, columns::Vector{String})::Vector{Column}
  map(col_name -> begin
    index = findfirst(col -> col.name == col_name, table.meta.schema.columns)
    if index == nothing
      available_columns = map(c -> c.name, table.meta.schema.columns)
      throw(DomainError("column \"$(col_name)\" not in $(available_columns)"))
    end
    table.meta.schema.columns[index]
  end, columns)
end

function partition_iter(
  table::Table,
  from::Union{Int64, String, Date, DateTime},
  to::Union{Int64, String, Date, DateTime},
  columns::Vector{String}
)::PartitionIter
  from_ts = nanoseconds(from)
  to_ts = nanoseconds(to)
  partitions = Vector{Tuple{String, PartitionMeta}}()
  for (partition_dir, partition_meta) in table.meta.partition_meta
    if (from_ts >= partition_meta.from_ts && from_ts <= partition_meta.to_ts) ||
       (from_ts < partition_meta.from_ts && to_ts > partition_meta.to_ts) ||
       (to_ts >= partition_meta.from_ts && to_ts <= partition_meta.to_ts)
       push!(partitions, (partition_dir, partition_meta))
    end
  end
  sort!(partitions, by = p -> p.second.from_ts)
  ts_column = table.meta.schema.columns[1]
  columns = get_union(table, columns)
  PartitionIter(
    from_ts,
    to_ts,
    ts_column,
    columns,
    table.name,
    partitions
  )
end

end

