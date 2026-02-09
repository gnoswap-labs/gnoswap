package v1

import (
	"strings"
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
)

func TestTickCrossEventInfo_ToString(t *testing.T) {
	tests := []struct {
		name                 string
		tickID               int32
		stakedLiquidityGross string
		stakedLiquidityDelta string
		outsideAccumulation  string
	}{
		{
			name:                 "positive tick positive delta",
			tickID:               100,
			stakedLiquidityGross: "1000000",
			stakedLiquidityDelta: "500000",
			outsideAccumulation:  "123456789",
		},
		{
			name:                 "negative tick negative delta",
			tickID:               -200,
			stakedLiquidityGross: "2000000",
			stakedLiquidityDelta: "-1000000",
			outsideAccumulation:  "987654321",
		},
		{
			name:                 "zero values",
			tickID:               0,
			stakedLiquidityGross: "0",
			stakedLiquidityDelta: "0",
			outsideAccumulation:  "0",
		},
		{
			name:                 "max tick boundary",
			tickID:               887272,
			stakedLiquidityGross: "115792089237316195423570985008687907853269984665640564039457584007913129639935",
			stakedLiquidityDelta: "57896044618658097711785492504343953926634992332820282019728792003956564819967",
			outsideAccumulation:  "100000000000000000000000000000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			eventInfo := NewTickCrossEventInfo(
				tt.tickID,
				u256.MustFromDecimal(tt.stakedLiquidityGross),
				i256.MustFromDecimal(tt.stakedLiquidityDelta),
				u256.MustFromDecimal(tt.outsideAccumulation),
			)
			result := eventInfo.ToString()

			uassert.True(t, strings.HasPrefix(result, "{"))
			uassert.True(t, strings.HasSuffix(result, "}"))
			uassert.True(t, strings.Contains(result, `"t":`))
			uassert.True(t, strings.Contains(result, `"slg":`))
			uassert.True(t, strings.Contains(result, `"sld":`))
			uassert.True(t, strings.Contains(result, `"oa":`))
		})
	}
}

func TestTickCrossEventInfo_JSONFormat(t *testing.T) {
	eventInfo := NewTickCrossEventInfo(
		42,
		u256.MustFromDecimal("1000"),
		i256.MustFromDecimal("500"),
		u256.MustFromDecimal("100"),
	)
	result := eventInfo.ToString()

	requiredKeys := []string{"t", "slg", "sld", "oa"}
	for _, key := range requiredKeys {
		uassert.True(t, strings.Contains(result, `"`+key+`":`))
	}

	uassert.False(t, strings.Contains(result, ",,"))
	uassert.False(t, strings.Contains(result, ",}"))
}

func TestNewTickCrossEventInfo(t *testing.T) {
	tickID := int32(100)
	stakedLiquidityGross := u256.MustFromDecimal("1000")
	stakedLiquidityDelta := i256.MustFromDecimal("500")
	outsideAccumulation := u256.MustFromDecimal("200")

	eventInfo := NewTickCrossEventInfo(tickID, stakedLiquidityGross, stakedLiquidityDelta, outsideAccumulation)

	uassert.NotNil(t, eventInfo)
	uassert.Equal(t, tickID, eventInfo.tickID)
	uassert.Equal(t, stakedLiquidityGross.ToString(), eventInfo.stakedLiquidityGross.ToString())
	uassert.Equal(t, stakedLiquidityDelta.ToString(), eventInfo.stakedLiquidityDelta.ToString())
	uassert.Equal(t, outsideAccumulation.ToString(), eventInfo.outsideAccumulation.ToString())
}
