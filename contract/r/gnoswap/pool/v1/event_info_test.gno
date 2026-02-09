package v1

import (
	"strings"
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
	pl "gno.land/r/gnoswap/pool"
)

func makeTickInfo(liquidityGross, feeGrowth0, feeGrowth1, secondsPerLiquidity, liquidityNet string, tickCumulative int64, secondsOutside uint32, initialized bool) pl.TickInfo {
	info := pl.NewTickInfo()
	info.SetLiquidityGross(u256.MustFromDecimal(liquidityGross))
	info.SetLiquidityNet(i256.MustFromDecimal(liquidityNet))
	info.SetFeeGrowthOutside0X128(u256.MustFromDecimal(feeGrowth0))
	info.SetFeeGrowthOutside1X128(u256.MustFromDecimal(feeGrowth1))
	info.SetTickCumulativeOutside(tickCumulative)
	info.SetSecondsPerLiquidityOutsideX128(u256.MustFromDecimal(secondsPerLiquidity))
	info.SetSecondsOutside(secondsOutside)
	info.SetInitialized(initialized)
	return info
}

func TestTickEventInfo_ToString(t *testing.T) {
	tests := []struct {
		name     string
		tickID   int32
		tickInfo pl.TickInfo
	}{
		{
			name:     "positive values",
			tickID:   100,
			tickInfo: makeTickInfo("1000000", "123456", "789012", "999", "500000", 12345, 3600, true),
		},
		{
			name:     "negative tick",
			tickID:   -200,
			tickInfo: makeTickInfo("2000000", "0", "0", "0", "-1000000", -5000, 0, true),
		},
		{
			name:     "zero values",
			tickID:   0,
			tickInfo: makeTickInfo("0", "0", "0", "0", "0", 0, 0, false),
		},
		{
			name:     "max values",
			tickID:   887272,
			tickInfo: makeTickInfo("115792089237316195423570985008687907853269984665640564039457584007913129639935", "100000000000000000000", "200000000000000000000", "999999999999", "57896044618658097711785492504343953926634992332820282019728792003956564819967", 2147483647, 4294967295, true),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			eventInfo := NewTickEventInfo(tt.tickID, tt.tickInfo)
			result := eventInfo.ToString()

			uassert.True(t, strings.HasPrefix(result, "{"))
			uassert.True(t, strings.HasSuffix(result, "}"))
			uassert.True(t, strings.Contains(result, `"t":`))
			uassert.True(t, strings.Contains(result, `"lg":`))
			uassert.True(t, strings.Contains(result, `"ln":`))
		})
	}
}

func TestTickEventInfo_JSONFormat(t *testing.T) {
	tickInfo := makeTickInfo("1000", "100", "200", "50", "500", 10, 100, true)
	eventInfo := NewTickEventInfo(42, tickInfo)
	result := eventInfo.ToString()

	requiredKeys := []string{"t", "lg", "ln", "fg0", "fg1", "tco", "spl", "so", "i"}
	for _, key := range requiredKeys {
		uassert.True(t, strings.Contains(result, `"`+key+`":`))
	}

	uassert.False(t, strings.Contains(result, ",,"))
	uassert.False(t, strings.Contains(result, ",}"))
}

func TestNewTickEventInfo(t *testing.T) {
	tickID := int32(100)
	tickInfo := makeTickInfo("1000", "100", "200", "50", "500", 10, 100, true)

	eventInfo := NewTickEventInfo(tickID, tickInfo)

	uassert.NotNil(t, eventInfo)
	uassert.Equal(t, tickID, eventInfo.tickID)
	uassert.Equal(t, tickInfo.LiquidityGross().ToString(), eventInfo.tickInfo.LiquidityGross().ToString())
}
