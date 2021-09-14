module Aggs 

using Dates
using ..zdb
using ..Scan

const trades_table = "trades2"
const DATE_FORMAT = "yyyy-mm-dd"

function trade_volume(date::String, symbol::String)::Vector{Scan.Trade}
  syms = zdb.symbols(trades_table, "sym")
  # Julia starts indexing at 1, zdb does for symbols at 0
  sym_index = findfirst(s -> s == symbol, syms) - 1

  date = Date(date, DATE_FORMAT)
  next_day = date + Dates.Day(1)
  zdb.query(trades_table, string(date), string(next_day), """
  struct Trade
    ts::Int64
    size::UInt32
    price::Float32
    conditions::UInt32
  end

  trades = Trade[]
  function scan(
    ts::Vector{Int64},
    sym::Vector{UInt16},
    size::Vector{UInt32},
    price::Vector{Float32},
    conditions::Vector{UInt32}
  )::Vector{Trade}
    for (index, (t, sy, si, p, c)) in enumerate(zip(ts, sym, size, price, conditions))
      if sy == $(sym_index)
        push!(trades, Trade(t, si, p, c))
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

mutable struct Range
  start::Float64
  stop::Float64
end

struct MinuteBucketRange
  buckets::Vector{MinuteBucket}
  range_price::Range
  max_volume::UInt64
end

function minute_price_buckets(date::String, symbol::String)::MinuteBucketRange
  date_nanos = DateTime(date, DATE_FORMAT)
  date_nanos = zdb.nanoseconds(date_nanos)
  trades = trade_volume(date, symbol)
  timestamps = map(t -> t.ts, trades)
  buckets = MinuteBucket[]
  bucket = MinuteBucket(0, Dict())
  range_price = Range(trades[1].price, trades[1].price)
  max_volume = UInt64(0)

  for t in trades
    minute = round(Int64, (t.ts - date_nanos) / (60 * 1_000_000_000))
    if minute != bucket.time
      bucket = MinuteBucket(minute, Dict())
      push!(buckets, bucket)
    end
    bucket.prices[t.price] = get(bucket.prices, minute, 0)
    bucket.prices[t.price] += t.size
    if t.price < range_price.start
      range_price.start = t.price
    elseif t.price > range_price.stop
      range_price.stop = t.price
    end
    if bucket.prices[t.price] > max_volume
      max_volume = bucket.prices[t.price]
    end
  end

  MinuteBucketRange(
    buckets,
    range_price,
    max_volume
  )
end

end

