module Aggs 

using Dates
using ..zdb

const agg1d_table = zdb.open("agg1d")
const trades_table = zdb.open("trades")
const DATE_FORMAT = "yyyy-mm-dd"

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

function aggregate_trades(
  agg1ds::Dict{String, OHLCV},
  date::String
)::Dict{String, MinuteBucketRange}
  res = Dict{String, MinuteBucketRange}()

  date = DateTime(date, DATE_FORMAT)
  date_nanos = zdb.nanoseconds(date)
  next_date = date + Dates.Day(1)
  columns = ["ts", "sym", "price", "size", "cond"]

  for p in zdb.partition_iter(trades_table, date, next_date, columns)
    tss::Vector{Int64} = p[1].data
    syms::Vector{UInt16} = p[2].data
    pricess::Vector{Float64} = p[3].data
    sizes::Vector{UInt32} = p[4].data
    conds::Vector{UInt32} = p[5].data
    for i in 1:length(syms)
      sym = trade_syms[syms[i]]
      agg1d = agg1ds[sym]
      t = Trade(
        tss[i],
        sizes[i],
        pricess[i],
        conds[i]
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
          0
        )
      end
      minute_bucket_range.num_trades += 1 

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

