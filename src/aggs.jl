module Aggs 

using Dates
using ..zdb
using ..Scan

const agg1d_table = "agg1d"
const trades_table = "trades2"
const DATE_FORMAT = "yyyy-mm-dd"
agg1d_syms = zdb.symbols(agg1d_table, "sym")
trade_syms = zdb.symbols(trades_table, "sym")

function trade_volume(date::String, symbol::String)::Vector{Scan.Trade}
  # Julia starts indexing at 1, zdb does for symbols at 0
  sym_index = findfirst(s -> s == symbol, trade_syms) - 1

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

function ohlcv(date::String, symbol::String)::Scan.OHLCV
  sym_index = findfirst(s -> s == symbol, agg1d_syms) - 1

  date = Date(date, DATE_FORMAT)
  next_day = date + Dates.Day(1)
  zdb.query(agg1d_table, string(date), string(date), """
  struct OHLCV
    open::Float32
    high::Float32
    low::Float32
    close::Float32
    volume::UInt64
  end

  function scan(
    sym::Vector{UInt16},
    open::Vector{Float32},
    high::Vector{Float32},
    low::Vector{Float32},
    close::Vector{Float32},
    volume::Vector{UInt64}
  )::OHLCV
    for (index, (sy, o, h, l, c, v)) in enumerate(zip(sym, open, high, low, close, volume))
      if sy == $(sym_index)
        return OHLCV(o, h, l, c, v)
      end
    end
  end
  """)
end

struct Bucket
  time::Int64
  prices::Dict{Float32, UInt32}
end

mutable struct Range
  start::Float64
  stop::Float64
end

struct MinuteBucketRange
  buckets::Vector{Bucket}
  range_price::Range
  max_volume::UInt64
  min_price_distance::Float32
end

function minute_price_buckets(date::String, symbol::String)::MinuteBucketRange
  date_nanos = DateTime(date, DATE_FORMAT)
  date_nanos = zdb.nanoseconds(date_nanos)
  trades = trade_volume(date, symbol)
  candle = ohlcv(date, symbol)
  println(candle)
  timestamps = map(t -> t.ts, trades)
  buckets = Bucket[]
  bucket = Bucket(0, Dict())
  range_price = Range(trades[1].price, trades[1].price)
  max_volume = UInt64(0)
  min_price_distance = typemax(Float32)

  for (i, t) in enumerate(trades)
    # Cheat for now and use OHLCV until we store errors
    if t.price < candle.low || t.price > candle.high
      continue
    end
    minute = round(Int64, (t.ts - date_nanos) / (60 * 1_000_000_000))
    if minute != bucket.time
      bucket = Bucket(minute, Dict())
      push!(buckets, bucket)
    end
    bucket.prices[t.price] = get(bucket.prices, t.price, 0)
    bucket.prices[t.price] += t.size
    if t.price < range_price.start
      range_price.start = t.price
    elseif t.price > range_price.stop
      range_price.stop = t.price
    end
    if bucket.prices[t.price] > max_volume
      max_volume = bucket.prices[t.price]
    end
    if i > 2
      price_distance = abs(t.price - trades[i - 1].price)
      if price_distance > 0f0 && price_distance < min_price_distance
        min_price_distance = price_distance
      end
    end
  end

  MinuteBucketRange(
    buckets,
    range_price,
    max_volume,
    min_price_distance
  )
end

end

