module Aggs 

using Dates
using ..zdb

const agg1d_table = zdb.open("agg1d")
const trades_table = zdb.open("trades")
const DATE_FORMAT = "yyyy-mm-dd"
const min_tick_size = 1f-6
const default_symbol = "SPY" # for fast testing

mutable struct Range
  min::Float32
  max::Float32
end

@enum Direction begin
  UP
  DOWN
  FLAT
end

struct Trade
  ts::Int64
  size::UInt32
  price::Float32
  conditions::UInt32
  err::UInt8
end

mutable struct PriceBucket
  trades::Vector{Trade}
  upticks::Vector{Direction}
  volume::UInt32
end

mutable struct MinuteBucketRange
  minutes::Dict{Int64, Dict{Float64, PriceBucket}}
  range_price::Range
  max_volume::UInt32
  min_price_distance::Float32
  last_price::Float32
  liquidity::Float64
  total_volume::UInt64
  num_trades::UInt64
end

struct OHLCV
  open::Float32
  high::Float32
  low::Float32
  close::Float32
  volume::UInt64
end

const agg1d_syms = zdb.symbols(agg1d_table, "sym")
const trade_syms = zdb.symbols(trades_table, "sym")

function get_agg1ds(date::String)::Dict{String, OHLCV}
  res = Dict{String, OHLCV}()
  columns = ["sym", "open", "high", "low", "close", "volume"]

  for p in zdb.partition_iter(agg1d_table, date, date, columns)
    for i in 1:length(p[1].data)
      sym = agg1d_syms[p[1].data[i]]
      res[sym] = OHLCV(
        p[2].data[i],
        p[3].data[i],
        p[4].data[i],
        p[5].data[i],
        p[6].data[i]
      )
    end
  end

  res
end

function prettyprint(trade::Trade)
  nanos = trade.ts
  date = zdb.datetime(nanos)
  conditions = reinterpret(UInt8, [trade.conditions])
  conditions = convert(Vector{Int16}, conditions)
  println("$(date) ($(trade.ts)) $(trade.size) $(trade.price) $(conditions) $(trade.err)")
end

# Inspired by https://link.springer.com/article/10.1057/jdhf.2009.16#Sec9
function predicterror(minute_bucket_range::MinuteBucketRange, trade::Trade)::Bool
  liquidity = minute_bucket_range.liquidity
  vwap = liquidity / minute_bucket_range.total_volume
  # SPY is very liquid at $34 billion / day
  max_deviation = 0.1
  if liquidity > 10_000_000_000
    max_deviation = 0.01
  elseif liquidity > 1_000_000_000
    max_deviation = 0.03
  elseif liquidity > 1_000_000
    max_deviation = 0.05
  elseif liquidity > 100_000
    max_deviation = 0.09
  elseif liquidity > 10_000
    max_deviation = 0.20
  end

  # it's officially an error
  if trade.err != UInt8(0)
    println("should get this:")
    println(minute_bucket_range.last_price)
    println(minute_bucket_range.liquidity)
    println(minute_bucket_range.total_volume)
    println(vwap)
    println(abs(trade.price - vwap), " ", abs(trade.price - vwap) / vwap)
    println(max_deviation)
  end
  # first tick
  if isnan(minute_bucket_range.last_price)
    return false
  end
  # 1. Minumum tick effect
  # Useful for stocks <$1 that are soon to be delisted
  if abs(trade.price - minute_bucket_range.last_price) <= min_tick_size
    return false
  end

  # 2. Price level effect.
  # Instead of hardcoding values allowing larger volitility on cheaper shares, use vwap
  # and different liquidity brackets

  if abs(trade.price - vwap) / vwap > max_deviation
    return true
  end

  # 3. Median Absolute Deviation.
  # Unfortunately this is rather expensive to compute, so skip it

  false
end

function percentages(trades::Vector{Aggs.Trade})
  liquidity = 0e0
  vol = UInt64(0)
  cur_p = 0e0
  map(t -> begin
    vol += t.size
    liquidity += t.price * t.size
    if cur_p == 0e0
      cur_p = t.price
      0e0
    else
      vwap = liquidity / vol
      cur_p = t.price
      abs(t.price - vwap) / vwap
    end
  end, trades)
end

function get_trades(
  date::String,
  symbol::String
)::Vector{Trade}
  res = Trade[]
  date = DateTime(date, DATE_FORMAT)
  date_nanos = zdb.nanoseconds(date)
  next_date = date + Dates.Day(1)
  columns = ["ts", "sym", "price", "size", "cond", "err"]

  for p in zdb.partition_iter(trades_table, date, next_date, columns)
    tss::Vector{Int64} = p[1].data
    syms::Vector{UInt16} = p[2].data
    pricess::Vector{Float64} = p[3].data
    sizes::Vector{UInt32} = p[4].data
    conds::Vector{UInt32} = p[5].data
    errs::Vector{UInt8} = p[6].data
    for i in 1:length(tss)
      sym = trade_syms[syms[i]]
      if sym != symbol
        continue
      end
      t = Trade(
        tss[i],
        sizes[i],
        pricess[i],
        conds[i],
        errs[i]
      )
      push!(res, t)
    end
  end

  res
end

function plot_percentages(date::String, sym::String, plot::Any)
  trades = get_trades(date, sym)
  percents = percentages(trades)
  plot(1:length(percents), percents)
end

function aggregate_trades(
  agg1ds::Dict{String, OHLCV},
  date::String
)::Dict{String, MinuteBucketRange}
  res = Dict{String, MinuteBucketRange}()

  date = DateTime(date, DATE_FORMAT)
  date_nanos = zdb.nanoseconds(date)
  next_date = date + Dates.Day(1)
  columns = ["ts", "sym", "price", "size", "cond", "err"]

  println("errors")
  for p in zdb.partition_iter(trades_table, date, next_date, columns)
    tss::Vector{Int64} = p[1].data
    syms::Vector{UInt16} = p[2].data
    pricess::Vector{Float64} = p[3].data
    sizes::Vector{UInt32} = p[4].data
    conds::Vector{UInt32} = p[5].data
    errs::Vector{UInt8} = p[6].data
    for i in 1:length(tss)
      sym = trade_syms[syms[i]]
      if sym != default_symbol
        #continue
      end
      agg1d = agg1ds[sym]
      t = Trade(
        tss[i],
        sizes[i],
        pricess[i],
        conds[i],
        errs[i]
      )
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
          NaN32,
          0,
          0,
          0
        )
      end
      # Check for error
      if t.err != UInt8(0)
        prettyprint(t)
      end
      #=
      if predicterror(minute_bucket_range, t)
        if t.err != UInt8(0)
          println("good!")
          prettyprint(t)
        else
          println("false positive!")
          prettyprint(t)
        end
      elseif t.err != UInt8(0)
        println("missed!")
        prettyprint(t)
      end
      =#
      minute_bucket_range.num_trades += 1 
      minute_bucket_range.total_volume += t.size
      minute_bucket_range.liquidity += t.price * t.size

      minute = round(Int64, (t.ts - date_nanos) / (60 * 1_000_000_000))

      # Add volume
      # println("$sym $p_i64 $minute")
      prices = get!(minute_bucket_range.minutes, minute) do
        Dict{Float64, PriceBucket}()
      end
      if !haskey(prices, t.price)
        prices[t.price] = PriceBucket(Trade[], Direction[], 0)
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
        direction = FLAT
        if t.price > minute_bucket_range.last_price
          direction = UP
        elseif t.price < minute_bucket_range.last_price
          direction = DOWN
        end
        push!(prices[t.price].upticks, direction)
      else
        push!(prices[t.price].upticks, FLAT)
      end
      minute_bucket_range.last_price = t.price
    end

  end

  res
end

function get_minute_bucket_ranges(date::String)::Dict{String, MinuteBucketRange}
  agg1ds = get_agg1ds(date) # TODO: Replace with cleaning

  aggregate_trades(agg1ds, date)
end

end

