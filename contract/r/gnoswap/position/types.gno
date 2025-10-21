package position

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
)

type IPosition interface {
	IPositionManager
	IPositionGetter
	IPositionApi
}

type IPositionManager interface {
	Mint(
		token0 string,
		token1 string,
		fee uint32,
		tickLower int32,
		tickUpper int32,
		amount0Desired string,
		amount1Desired string,
		amount0Min string,
		amount1Min string,
		deadline int64,
		mintTo address,
		caller address,
		referrer string,
	) (uint64, string, string, string)

	IncreaseLiquidity(
		positionId uint64,
		amount0DesiredStr string,
		amount1DesiredStr string,
		amount0MinStr string,
		amount1MinStr string,
		deadline int64,
	) (uint64, string, string, string, string)

	DecreaseLiquidity(
		positionId uint64,
		liquidityStr string,
		amount0MinStr string,
		amount1MinStr string,
		deadline int64,
		unwrapResult bool,
	) (uint64, string, string, string, string, string, string)

	Reposition(
		positionId uint64,
		tickLower int32,
		tickUpper int32,
		amount0DesiredStr string,
		amount1DesiredStr string,
		amount0MinStr string,
		amount1MinStr string,
	) (uint64, string, int32, int32, string, string)

	CollectFee(
		positionId uint64,
		unwrapResult bool,
	) (uint64, string, string, string, string, string)

	SetPositionOperator(
		positionId uint64,
		operator address,
	)
}

type IPositionGetter interface {
	GetPosition(positionId uint64) (Position, bool)
	MustGetPosition(positionId uint64) Position
	IsBurned(positionId uint64) bool
	IsInRange(positionId uint64) bool
	GetPositionFeeGrowthInside0LastX128(positionId uint64) *u256.Uint
	GetPositionFeeGrowthInside1LastX128(positionId uint64) *u256.Uint
	GetPositionLiquidity(positionId uint64) *u256.Uint
	GetPositionOperator(positionId uint64) string
	GetPositionPoolKey(positionId uint64) string
	GetPositionTickLower(positionId uint64) int32
	GetPositionTickUpper(positionId uint64) int32
	GetPositionTokensOwed0(positionId uint64) *u256.Uint
	GetPositionTokensOwed1(positionId uint64) *u256.Uint
	GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint)
}

type IPositionApi interface {
	ApiGetPosition(positionId uint64) string
	ApiGetPositionUnclaimedFeeByPositionID(positionId uint64) string
}

type IPositionStore interface {
	HasPositionsStoreKey() bool
	GetPositions() *avl.Tree
	SetPositions(positions *avl.Tree) error

	HasPositionNextIDStoreKey() bool
	GetPositionNextID() uint64
	SetPositionNextID(nextID uint64) error

	HasPosition(positionId uint64) bool
	GetPosition(positionId uint64) (Position, bool)
	SetPosition(positionId uint64, position Position) error
}
