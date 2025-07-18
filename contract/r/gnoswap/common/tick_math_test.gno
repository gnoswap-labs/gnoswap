package common

import (
	"testing"

	"gno.land/p/demo/uassert"

	u256 "gno.land/p/gnoswap/uint256"
)

var (
	MIN_TICK       = int32(-887272)
	MIN_SQRT_RATIO = "4295128739"

	MAX_TICK       = int32(887272)
	MAX_SQRT_RATIO = "1461446703485210103287273052203988822378723970342"
)

func TestTickMathGetSqrtRatioAtTick(t *testing.T) {
	tests := []struct {
		name                 string
		tick                 int32
		expectedSqrtPriceX96 string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:                 "throws for too low",
			tick:                 MIN_TICK - 1,
			expectedSqrtPriceX96: "",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-003] value out of range || tick is out of range (smaller than -887272), tick: -887273",
		},
		{
			name:                 "throws for too high",
			tick:                 MAX_TICK + 1,
			expectedSqrtPriceX96: "",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-003] value out of range || tick is out of range (larger than 887272), tick: 887273",
		},
		{
			name:                 "min tick",
			tick:                 MIN_TICK,
			expectedSqrtPriceX96: "4295128739",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "min tick + 1",
			tick:                 MIN_TICK + 1,
			expectedSqrtPriceX96: "4295343490",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "max tick",
			tick:                 MAX_TICK,
			expectedSqrtPriceX96: "1461446703485210103287273052203988822378723970342",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "max tick - 1",
			tick:                 MAX_TICK - 1,
			expectedSqrtPriceX96: "1461373636630004318706518188784493106690254656249",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "zero tick",
			tick:                 0,
			expectedSqrtPriceX96: "79228162514264337593543950336",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "positive tick 50",
			tick:                 50,
			expectedSqrtPriceX96: "79426470787362580746886972461",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "negative tick -50",
			tick:                 -50,
			expectedSqrtPriceX96: "79030349367926598376800521322",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "positive tick 100",
			tick:                 100,
			expectedSqrtPriceX96: "79625275426524748796330556128",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "negative tick -100",
			tick:                 -100,
			expectedSqrtPriceX96: "78833030112140176575862854579",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "positive tick 150000",
			tick:                 150000,
			expectedSqrtPriceX96: "143194173941309278083010301478497",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "negative tick -150000",
			tick:                 -150000,
			expectedSqrtPriceX96: "43836292794701720435367485",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "positive tick 250000",
			tick:                 250000,
			expectedSqrtPriceX96: "21246587762933397357449903968194344",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "negative tick -250000",
			tick:                 -250000,
			expectedSqrtPriceX96: "295440463448801648376846",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "positive tick 500000",
			tick:                 500000,
			expectedSqrtPriceX96: "5697689776495288729098254600827762987878",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "negative tick -500000",
			tick:                 -500000,
			expectedSqrtPriceX96: "1101692437043807371",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "positive tick 738203",
			tick:                 738203,
			expectedSqrtPriceX96: "847134979253254120489401328389043031315994541",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "negative tick -738203",
			tick:                 -738203,
			expectedSqrtPriceX96: "7409801140451",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "positive tick 499999",
			tick:                 499999,
			expectedSqrtPriceX96: "5697404913371020254246162096779746564305",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectedHasPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					TickMathGetSqrtRatioAtTick(tt.tick)
				})
			} else {
				result := TickMathGetSqrtRatioAtTick(tt.tick)
				uassert.Equal(t, tt.expectedSqrtPriceX96, result.ToString())
			}
		})
	}
}

func TestTickMathGetSqrtRatioAtTick_AdditionalValidation(t *testing.T) {
	t.Run("min tick ratio is less than js implementation", func(t *testing.T) {
		sqrtPriceX96 := TickMathGetSqrtRatioAtTick(MIN_TICK)
		uassert.False(t, sqrtPriceX96.Cmp(u256.MustFromDecimal("6085630636")) >= 0, "should be less than 6085630636")
	})

	t.Run("max tick ratio is greater than js implementation", func(t *testing.T) {
		sqrtPriceX96 := TickMathGetSqrtRatioAtTick(MAX_TICK - int32(1))
		uassert.False(t, sqrtPriceX96.Cmp(u256.MustFromDecimal("1033437718471923706666374484006904511252097097914")) < 0, "should be greater than 1033437718471923706666374484006904511252097097914")
	})
}

func TestTickMathGetTickAtSqrtRatio(t *testing.T) {
	tests := []struct {
		name                 string
		sqrtPriceX96         string
		expectedTick         int32
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:                 "throws for too low sqrt_ratio",
			sqrtPriceX96:         "4295128738", // MIN_SQRT_RATIO - 1
			expectedTick:         0,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-003] value out of range || sqrtPriceX96(4295128738) is out of range",
		},
		{
			name:                 "throws for too high sqrt_ratio",
			sqrtPriceX96:         "1461446703485210103287273052203988822378723970343", // MAX_SQRT_RATIO + 1
			expectedTick:         0,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-003] value out of range || sqrtPriceX96(1461446703485210103287273052203988822378723970343) is out of range",
		},
		{
			name:                 "ratio of min tick",
			sqrtPriceX96:         MIN_SQRT_RATIO,
			expectedTick:         MIN_TICK,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "ratio of min tick + 1",
			sqrtPriceX96:         "4295343490",
			expectedTick:         MIN_TICK + 1,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "ratio of max tick - 1",
			sqrtPriceX96:         "1461373636630004318706518188784493106690254656249",
			expectedTick:         MAX_TICK - 1,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick -887272",
			sqrtPriceX96:         "4295128739",
			expectedTick:         -887272,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick 276324",
			sqrtPriceX96:         "79228162514264337593543950336000000",
			expectedTick:         276324,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick 138162",
			sqrtPriceX96:         "79228162514264337593543950336000",
			expectedTick:         138162,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick -41591",
			sqrtPriceX96:         "9903520314283042199192993792",
			expectedTick:         -41591,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick -20796",
			sqrtPriceX96:         "28011385487393069959365969113",
			expectedTick:         -20796,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick -6932",
			sqrtPriceX96:         "56022770974786139918731938227",
			expectedTick:         -6932,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick 0",
			sqrtPriceX96:         "79228162514264337593543950336",
			expectedTick:         0,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick 6931",
			sqrtPriceX96:         "112045541949572279837463876454",
			expectedTick:         6931,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick 20795",
			sqrtPriceX96:         "224091083899144559674927752909",
			expectedTick:         20795,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick 41590",
			sqrtPriceX96:         "633825300114114700748351602688",
			expectedTick:         41590,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick -138163",
			sqrtPriceX96:         "79228162514264337593543950",
			expectedTick:         -138163,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick -276325",
			sqrtPriceX96:         "79228162514264337593543",
			expectedTick:         -276325,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick 887271",
			sqrtPriceX96:         "1461373636630004318706518188784493106690254656249",
			expectedTick:         887271,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sqrtPriceX96 := u256.MustFromDecimal(tt.sqrtPriceX96)
			
			if tt.expectedHasPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					TickMathGetTickAtSqrtRatio(sqrtPriceX96)
				})
			} else {
				result := TickMathGetTickAtSqrtRatio(sqrtPriceX96)
				uassert.Equal(t, tt.expectedTick, result)
			}
		})
	}
}

func TestTickMathGetTickAtSqrtRatio_EdgeCase(t *testing.T) {
	t.Run("ratio closest to max tick", func(t *testing.T) {
		maxSqrtRatio := u256.MustFromDecimal(MAX_SQRT_RATIO)
		gapSqrtRatio := u256.MustFromDecimal("73066855205784580754863419495715688469314093")
		maxSqrtRatioSubGap := u256.Zero().Sub(maxSqrtRatio, gapSqrtRatio)
		maxTickSub1 := MAX_TICK - int32(1)

		rst := TickMathGetTickAtSqrtRatio(maxSqrtRatioSubGap)
		uassert.Equal(t, maxTickSub1, rst)
	})
}
