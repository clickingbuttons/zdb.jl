module Aggs 

using Dates

include("./zdb.jl")

const DATE_FORMAT = "yyyy-mm-dd"

function trade_volume(date::String, symbol::String)::Vector{Tuple{Int64, UInt32, Float64}}
  syms = zdb.symbols("trades", "sym")
  # Julia starts indexing at 1, zdb does for symbols at 0
  sym_index = findfirst(s -> s == symbol, syms) - 1

  date = Date(date, DATE_FORMAT)
  next_day = date + Dates.Day(1)
  zdb.query("trades", string(date), string(next_day), """
  trades = Tuple{Int64, UInt32, Float64}[]
  function scan(ts::Vector{Int64}, sym::Vector{UInt16}, size::Vector{UInt32}, price::Vector{Float32})::Vector{Tuple{Int64, UInt32, Float64}}
    for (t, sy, si, p) in zip(ts, sym, size, price)
      if sy == $(sym_index)
        push!(trades, (t, si, p))
      end
    end

    trades
  end
  """)
end

struct MinuteBucket
  time::Int64
  prices::Dict{Float32, UInt32}
end

function minute_price_buckets(date::String, symbol::String)
  date_nanos = DateTime(date, DATE_FORMAT)
  date_nanos = zdb.nanoseconds(date_nanos)
  trades = trade_volume(date, symbol)
  timestamps = map(t -> t[1], trades)
  buckets = MinuteBucket[]
  bucket = MinuteBucket(0, Dict())
  for t in trades
    minute = round(Int64, (t[1] - date_nanos) / (60 * 1_000_000_000))
    if minute != bucket.time
      bucket = MinuteBucket(minute, Dict())
      push!(buckets, bucket)
    end
    bucket.prices[t[3]] = get(bucket.prices, minute, 0)
    bucket.prices[t[3]] += t[2]
  end

  buckets
end

end

