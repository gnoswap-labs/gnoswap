package staker

import (
	"std"

	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/pool"
	"gno.land/r/gnoswap/v1/position"
	u256 "gno.land/p/gnoswap/uint256"
)

// EmissionI defines the interface for emission realm interactions
type EmissionI struct {
	MintAndDistributeGns func() uint64
	GetEmission func() uint64
	GetHalvingBlocksInRange func(start, end int64) ([]int64, []uint64)
	SetCallbackStakerEmissionChange func(callback func(emission uint64))
	RegisterGnsChangeCallback func()
}

// PoolI defines the interface for pool realm interactions
type PoolI struct {
	GetPoolFromPoolPath func(poolPath string) *pool.Pool
	PoolGetSlot0Tick func(poolPath string) int32
}

// PositionI defines the interface for position realm interactions
type PositionI struct {
	PositionGetPositionPoolKey      func(tokenId uint64) string
	PositionGetPositionLiquidityStr func(tokenId uint64) string
	PositionGetPositionTickLower    func(tokenId uint64) int32
	PositionGetPositionTickUpper    func(tokenId uint64) int32
	PositionIsInRange              func(tokenId uint64) bool
	SetPositionOperator            func(tokenId uint64, operator std.Address)
}

// en is the emission interface instance
var en EmissionI = EmissionI{
	MintAndDistributeGns: emission.MintAndDistributeGns,
	GetEmission: emission.GetEmission,
	GetHalvingBlocksInRange: emission.GetHalvingBlocksInRange,
	SetCallbackStakerEmissionChange: emission.SetCallbackStakerEmissionChange,
	RegisterGnsChangeCallback: emission.RegisterGnsChangeCallback,
}

// pl is the pool interface instance
var pl PoolI = PoolI{
	GetPoolFromPoolPath: pool.GetPoolFromPoolPath,
	PoolGetSlot0Tick: pool.PoolGetSlot0Tick,
}

// pn is the position interface instance
var pn PositionI = PositionI{
	PositionGetPositionPoolKey:      position.PositionGetPositionPoolKey,
	PositionGetPositionLiquidityStr: position.PositionGetPositionLiquidityStr,
	PositionGetPositionTickLower:    position.PositionGetPositionTickLower,
	PositionGetPositionTickUpper:    position.PositionGetPositionTickUpper,
	PositionIsInRange:              position.PositionIsInRange,
	SetPositionOperator:            position.SetPositionOperator,
}