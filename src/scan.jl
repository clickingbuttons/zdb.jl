module Scan
struct Trade
  ts::Int64
  size::UInt32
  price::Float32
  conditions::UInt32
end
struct OHLCV
  open::Float32
  high::Float32
  low::Float32
  close::Float32
  volume::UInt64
end
end

