module Scan

struct Trade
  sym::UInt16
  ts::Int64
  size::UInt32
  price::Float32
  conditions::UInt32
end
struct OHLCV
  sym::UInt16
  open::Float32
  high::Float32
  low::Float32
  close::Float32
  volume::UInt64
end

end

