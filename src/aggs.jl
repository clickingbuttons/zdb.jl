module Aggs 

using Dates
using ..zdb
using ..Scan

const agg1d_table = "agg1d"
const trades_table = "trades2"
const DATE_FORMAT = "yyyy-mm-dd"

mutable struct Range
  min::Float32
  max::Float32
end

@enum Direction begin
  UP
  DOWN
  LEVEL
end

mutable struct PriceBucket
  trades::Vector{Scan.Trade}
  upticks::Vector{Direction}
  volume::UInt32
end

mutable struct MinuteBucketRange
  minutes::Dict{Int64, Dict{Float32, PriceBucket}}
  range_price::Range
  max_volume::UInt32
  min_price_distance::Float32
  last_price::Float32
end

const agg1d_syms = zdb.symbols(agg1d_table, "sym")
const trade_syms = zdb.symbols(trades_table, "sym")

function get_agg1ds(date::String)::Dict{String, Scan.OHLCV}
  date = Date(date, DATE_FORMAT)
  next_day = date + Dates.Day(1)
  agg1ds = zdb.query(agg1d_table, string(date), string(date), """
  struct OHLCV
    sym::UInt16
    open::Float32
    high::Float32
    low::Float32
    close::Float32
    volume::UInt64
  end

  agg1ds = OHLCV[]
  function scan(
    sym::Vector{UInt16},
    open::Vector{Float32},
    high::Vector{Float32},
    low::Vector{Float32},
    close::Vector{Float32},
    volume::Vector{UInt64}
  )::Vector{OHLCV}
    for (index, (sy, o, h, l, c, v)) in enumerate(zip(sym, open, high, low, close, volume))
      push!(agg1ds, OHLCV(sy, o, h, l, c, v))
    end

    agg1ds
  end
  """)
  res = Dict{String, Scan.OHLCV}()
  for agg in agg1ds
    res[agg1d_syms[agg.sym + 1]] = agg
  end
  
  res
end

function get_trades(date::String)::Vector{Scan.Trade}
  date = Date(date, DATE_FORMAT)
  next_day = date + Dates.Day(1)
  zdb.query(trades_table, string(date), string(next_day), """
  struct Trade
    sym::UInt16
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
      push!(trades, Trade(sy, t, si, p, c))
    end

    trades
  end
  """)
end

function aggregate_trades(
  agg1ds::Dict{String, Scan.OHLCV},
  trades::Vector{Scan.Trade},
  date::String
)::Dict{String, MinuteBucketRange}
  date_nanos = DateTime(date, DATE_FORMAT)
  date_nanos = zdb.nanoseconds(date_nanos)

  res = Dict{String, MinuteBucketRange}()
  num_allocations = 0

  for t in trades
    sym = trade_syms[t.sym + 1]
    agg1d = agg1ds[sym]
    # Cheat for now and use OHLCV until we store errors
    if t.price < agg1d.low || t.price > agg1d.high
      continue
    end
    minute_bucket_range = get!(res, sym) do
      MinuteBucketRange(
        Dict{Float32, UInt32}(),
        Range(t.price, t.price),
        UInt32(0),
        100f0,
        NaN32
      )
    end

    minute = round(Int64, (t.ts - date_nanos) / (60 * 1_000_000_000))

    # Add volume
    # println("$sym $p_i64 $minute")
    prices = get!(minute_bucket_range.minutes, minute) do
      Dict{Float32, PriceBucket}()
    end
    if !haskey(prices, t.price)
      prices[t.price] = PriceBucket(Scan.Trade[], Direction[], 0)
    end
    prices[t.price].volume += t.size
    push!(prices[t.price].trades, t)

    # Check volume range
    new_volume = prices[t.price].volume
    if new_volume > minute_bucket_range.max_volume
      minute_bucket_range.max_volume = new_volume
    end
    # Check price range
    range_price = minute_bucket_range.range_price
    if t.price < range_price.min
      range_price.min = t.price
    elseif t.price > range_price.max
      range_price.max = t.price
    end
    # Check price distance
    if !isnan(minute_bucket_range.last_price)
      distance = abs(minute_bucket_range.last_price - t.price)
      if distance < minute_bucket_range.min_price_distance
        minute_bucket_range.min_price_distance = distance
      end
      direction = LEVEL
      if t.price > minute_bucket_range.last_price
        direction = UP
      elseif t.price < minute_bucket_range.last_price
        direction = DOWN
      end
      push!(prices[t.price].upticks, direction)
    else
      push!(prices[t.price].upticks, LEVEL)
    end
    minute_bucket_range.last_price = t.price
  end
  println("bucketed $(length(trades)) trades")

  res
end

function get_minute_bucket_ranges(date::String)::Dict{String, MinuteBucketRange}
  agg1ds = get_agg1ds(date) # TODO: Remove for proper condition checking
  trades = get_trades(date)

  @timev aggregate_trades(agg1ds, trades, date)
end

end

