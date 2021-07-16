module Scan
  struct Trade
    ts::Int64
    size::UInt32
    price::Float64
  end
end

module Aggs 

using Dates

include("./zdb.jl")

const DATE_FORMAT = "yyyy-mm-dd"

function trade_volume(day::String, symbol::String)
  syms = zdb.symbols("trades", "sym")
  # Julia starts indexing at 1, zdb does for symbols at 0
  sym_index = findfirst(s -> s == symbol, syms) - 1

  day = Date(day, DATE_FORMAT)
  next_day = day + Dates.Day(1)
  day = Dates.format(day, DATE_FORMAT)
  next_day = Dates.format(next_day, DATE_FORMAT)
  zdb.query("trades", day, next_day, """
  struct Trade
    ts::Int64
    size::UInt32
    price::Float64
  end
  trades = Trade[]
  function scan(ts::Vector{Int64}, sym::Vector{UInt16}, size::Vector{UInt32}, price::Vector{Float32})::Vector{Trade}
    for (t, sy, si, p) in zip(ts, sym, size, price)
      if sy == $(sym_index)
        push!(trades, Trade(t, si, p))
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

function minute_price_buckets(day::String, symbol::String)
  trades = trade_volume(day, symbol)
  timestamps = map(t -> t.ts, trades)
  println("min $(minimum(timestamps)) max $(maximum(timestamps))")
  buckets = MinuteBucket[]
  bucket = MinuteBucket(0, Dict())
  for t in trades
    minute = round(Int64, t.ts / (60 * 1_000_000_000))
    if minute != bucket.time
      bucket = MinuteBucket(minute, Dict())
      push!(buckets, bucket)
    end
    bucket.prices[t.price] = get(bucket.prices, minute, 0)
    bucket.prices[t.price] += t.size
  end

  buckets
end

println(minute_price_buckets("2015-01-05", "AAPL"))

end
