package pool

import (
	"strconv"
	"strings"

	ufmt "gno.land/p/nt/ufmt/v0"
	u256 "gno.land/p/gnoswap/uint256"
)

const (
	MAX_UINT128          = "340282366920938463463374607431768211455"
	MAX_LIQUIDITY_PER_TICK_SPACING_1   = "191757530477355301479181766273477"
	MAX_LIQUIDITY_PER_TICK_SPACING_10  = "1917569901783203986719870431555990"
	MAX_LIQUIDITY_PER_TICK_SPACING_60  = "11505743598341114571880798222544994"
	MAX_LIQUIDITY_PER_TICK_SPACING_200 = "38350317471085141830651933667504588"
	MIN_TICK       int32 = -887272
	MAX_TICK            int32 = 887272
	ENCODED_TICK_OFFSET int32 = MAX_TICK
)

var (
	maxUint128FromDecimal                = u256.MustFromDecimal(MAX_UINT128)
	maxLiquidityPerTickSpacing1FromDec   = u256.MustFromDecimal(MAX_LIQUIDITY_PER_TICK_SPACING_1)
	maxLiquidityPerTickSpacing10FromDec  = u256.MustFromDecimal(MAX_LIQUIDITY_PER_TICK_SPACING_10)
	maxLiquidityPerTickSpacing60FromDec  = u256.MustFromDecimal(MAX_LIQUIDITY_PER_TICK_SPACING_60)
	maxLiquidityPerTickSpacing200FromDec = u256.MustFromDecimal(MAX_LIQUIDITY_PER_TICK_SPACING_200)
)

func calculateMaxLiquidityPerTick(tickSpacing int32) *u256.Uint {
	switch tickSpacing {
	case 1:
		return maxLiquidityPerTickSpacing1FromDec
	case 10:
		return maxLiquidityPerTickSpacing10FromDec
	case 60:
		return maxLiquidityPerTickSpacing60FromDec
	case 200:
		return maxLiquidityPerTickSpacing200FromDec
	default:
		return calculateMaxLiquidityPerTickByFormula(tickSpacing)
	}
}

func calculateMaxLiquidityPerTickByFormula(tickSpacing int32) *u256.Uint {
	minTick := (MIN_TICK / tickSpacing) * tickSpacing
	maxTick := (MAX_TICK / tickSpacing) * tickSpacing
	numTicks := uint64((maxTick-minTick)/tickSpacing) + 1

	return u256.Zero().Div(maxUint128FromDecimal, u256.NewUint(numTicks))
}

// GetPoolPath generates a unique pool path string based on the token paths and fee tier.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	// All the token paths in the pool are sorted in alphabetical order.
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}

	return token0Path + ":" + token1Path + ":" + strconv.FormatUint(uint64(fee), 10)
}

// EncodeTickKey encodes a tick to a string key for the tick tree.
func EncodeTickKey(tick int32) string {
	adjustTick := tick + ENCODED_TICK_OFFSET
	if adjustTick < 0 {
		panic(ufmt.Sprintf("tick(%d) + ENCODED_TICK_OFFSET(%d) < 0", tick, ENCODED_TICK_OFFSET))
	}

	// Convert the value to a decimal string.
	s := strconv.FormatInt(int64(adjustTick), 10)

	// Zero-pad to a total length of 10 characters.
	zerosNeeded := 10 - len(s)

	return strings.Repeat("0", zerosNeeded) + s
}

// DecodeTickKey decodes a string key to a tick.
func DecodeTickKey(s string) int32 {
	adjustTick, err := strconv.ParseInt(s, 10, 32)
	if err != nil {
		panic(ufmt.Sprintf("invalid tick key: %s", s))
	}

	return int32(adjustTick) - ENCODED_TICK_OFFSET
}
