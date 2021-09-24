module Scan

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

end

