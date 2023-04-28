package gnoswap

import (
  "std"
)


func GetPoolSlot0SqrtPriceX96() (bigint) {
  return slot0.sqrtPriceX96
}

func GetPoolTickSpacing() (bigint) {
  return tickSpacing
}

func GetPoolTickBitmap(x bigint) bigint {
  return tickBitmaps[x]
}

func GetPoolPosition(key string) PositionInfo {
  return positions[key]
}

func GetPoolPositionFeeGrowthInside0LastX128(key string) bigint {
  return positions[key].feeGrowthInside0LastX128
}

func GetPoolPositionFeeGrowthInside1LastX128(key string) bigint {
  return positions[key].feeGrowthInside0LastX128
}

func GetPoolAddress() std.Address {
  return std.GetOrigPkgAddr()
}

func GetPoolSlot0Tick() (bigint) {
  return slot0.tick
}

func GetPoolTicks(x bigint) TickInfo {
  return ticks[x]
}

func GetPoolTickFeeGrowthOutside0X128(x bigint) bigint {
  return ticks[x].feeGrowthOutside0X128
}

func GetPoolTickFeeGrowthOutside1X128(x bigint) bigint {
  return ticks[x].feeGrowthOutside1X128
}
