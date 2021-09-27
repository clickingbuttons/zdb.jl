module Aggs 

using Dates
using ..zdb
using ..Scan

const agg1d_table = "agg1d"
const trades_table = "trades2"
const DATE_FORMAT = "yyyy-mm-dd"

mutable struct Range
  start::Float64
  stop::Float64
end

mutable struct MinuteBucketRange
  buckets::Vector{Dict{Float32, UInt32}}
  range_price::Range
  max_volume::UInt64
  min_price_distance::Float32
end

const agg1d_syms = zdb.symbols(agg1d_table, "sym")
const trade_syms = zdb.symbols(trades_table, "sym")

function get_agg1ds(date::String)::Dict{String, Scan.OHLCV}
  date = Date(date, DATE_FORMAT)
  next_day = date + Dates.Day(1)
  agg1ds = zdb.query(agg1d_table, string(date), string(date), """
  struct OHLCV
    open::Float32
    high::Float32
    low::Float32
    close::Float32
    volume::UInt64
  end

  struct Agg
    sym::UInt16
    ohlcv::OHLCV
  end

  agg1ds = Agg[]
  function scan(
    sym::Vector{UInt16},
    open::Vector{Float32},
    high::Vector{Float32},
    low::Vector{Float32},
    close::Vector{Float32},
    volume::Vector{UInt64}
  )::Vector{Agg}
    for (index, (sy, o, h, l, c, v)) in enumerate(zip(sym, open, high, low, close, volume))
      push!(agg1ds, Agg(sy, OHLCV(o, h, l, c, v)))
    end

    agg1ds
  end
  """)
  res = Dict{String, Scan.OHLCV}()
  for agg in agg1ds
    res[agg1d_syms[agg.sym + 1]] = agg.ohlcv
  end
  
  res
end

function get_trades(date::String)::Vector{Scan.TradeAgg}
  date = Date(date, DATE_FORMAT)
  next_day = date + Dates.Day(1)
  zdb.query(trades_table, string(date), string(next_day), """
  struct Trade
    ts::Int64
    size::UInt32
    price::Float32
    conditions::UInt32
  end

  struct TradeAgg
    sym::UInt16
    trade::Trade
  end

  trades = TradeAgg[]
  function scan(
    ts::Vector{Int64},
    sym::Vector{UInt16},
    size::Vector{UInt32},
    price::Vector{Float32},
    conditions::Vector{UInt32}
  )::Vector{TradeAgg}
    #prices = map(p -> round(Int64, p*1f6), price)
    for (index, (t, sy, si, p, c)) in enumerate(zip(ts, sym, size, price, conditions))
      push!(trades, TradeAgg(sy, Trade(t, si, p, c)))
    end

    trades
  end
  """)
end

function aggregate_trades(
  agg1ds::Dict{String, Scan.OHLCV},
  trades::Vector{Scan.TradeAgg},
  date::String
)::Vector{MinuteBucketRange}
  date_nanos = DateTime(date, DATE_FORMAT)
  date_nanos = zdb.nanoseconds(date_nanos)

  res = fill(
    MinuteBucketRange(
      fill(Dict{Float32, UInt32}(), 24 * 60),
      Range(typemax(Float32), typemin(Float32)),
      0,
      100f0 # BK.A
    ),
    length(trade_syms)
  )

  sym_prices = Dict{String, Vector{Float32}}()
  # sparse matrix that appears like it does on graph
  # ^
  # |
  # prices (i64, unbounded)         volume (u32)
  # |
  # v
  # <-         time  buckets (i64, bounded)         ->
  for trade_agg in trades
    t = trade_agg.trade
    sym = trade_syms[trade_agg.sym + 1]
    agg1d = agg1ds[sym]
    # Cheat for now and use OHLCV until we store errors
    if t.price < agg1d.low || t.price > agg1d.high
      continue
    end
    minute_bucket_range = res[trade_agg.sym + 1]
    minute = round(Int64, (t.ts - date_nanos) / (60 * 1_000_000_000))

    # Add volume
    buckets = minute_bucket_range.buckets[minute]
    if !haskey(buckets, t.price)
      buckets[t.price] = 0
    end
    buckets[t.price] += t.size

    # Check volume range
    new_volume = buckets[t.price]
    if new_volume > minute_bucket_range.max_volume
      minute_bucket_range.max_volume = new_volume
    end
    # Check price range
    range_price = minute_bucket_range.range_price
    if t.price < range_price.start
      range_price.start = t.price
    elseif t.price > range_price.stop
      range_price.stop = t.price
    end
  end
  println("bucketed trades")
  #=
  for (symbol, prices) in sym_prices
    prices = sort(prices)
    for (i, p) in enumerate(prices)
      if i == 1
        continue
      end
      distance = abs(prices[i] - prices[i - 1])
      if distance < res[symbol].min_price_distance
        res[symbol].min_price_distance = distance
      end
    end
  end
  println("computed min distances")
  =#

  res
end

function get_minute_bucket_ranges(date::String)::Dict{String, MinuteBucketRange}
  agg1ds = get_agg1ds(date) # TODO: Remove for proper condition checking
  trades = get_trades(date)

  aggregate_trades(agg1ds, trades, date)
end

end

