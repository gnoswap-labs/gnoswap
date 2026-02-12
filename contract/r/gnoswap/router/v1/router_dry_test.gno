package v1

import (
	"strings"
	"testing"

	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
)

type DrySwapTestCase struct {
	name              string
	setupFn           func(*TestEnv)
	swapParams        DrySwapParams
	expectedAmountIn  string
	expectedAmountOut string
	expectedSuccess   bool
	expectPanic       bool
	expectedPanicMsg  string
}

type DrySwapParams struct {
	inputToken       string
	outputToken      string
	specifiedAmount  string
	swapTypeStr      string
	strRouteArr      string
	quoteArr         string
	tokenAmountLimit string
}

type DrySwapBuilder struct {
	params DrySwapParams
}

func NewDrySwapBuilder() *DrySwapBuilder {
	return &DrySwapBuilder{
		params: DrySwapParams{
			quoteArr: "100",
		},
	}
}

func (b *DrySwapBuilder) InputToken(token string) *DrySwapBuilder {
	b.params.inputToken = token
	return b
}

func (b *DrySwapBuilder) OutputToken(token string) *DrySwapBuilder {
	b.params.outputToken = token
	return b
}

func (b *DrySwapBuilder) SpecifiedAmount(amount string) *DrySwapBuilder {
	b.params.specifiedAmount = amount
	return b
}

func (b *DrySwapBuilder) SwapType(swapType string) *DrySwapBuilder {
	b.params.swapTypeStr = swapType
	return b
}

func (b *DrySwapBuilder) Route(route string) *DrySwapBuilder {
	b.params.strRouteArr = route
	return b
}

func (b *DrySwapBuilder) Quote(quote string) *DrySwapBuilder {
	b.params.quoteArr = quote
	return b
}

func (b *DrySwapBuilder) TokenAmountLimit(limit string) *DrySwapBuilder {
	b.params.tokenAmountLimit = limit
	return b
}

func (b *DrySwapBuilder) Build() DrySwapParams {
	return b.params
}

func setupBasicPools(env *TestEnv) {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*2)

	env.GivenPoolCreated(barPath, bazPath, 500, "130621891405341611593710811006")
	env.GivenPoolCreated(bazPath, quxPath, 500, "130621891405341611593710811006")

	bar.Approve(cross, poolAddr, maxApprove)
	baz.Approve(cross, poolAddr, maxApprove)
	qux.Approve(cross, poolAddr, maxApprove)

	positionParams1 := NewPositionBuilder().
		Tokens(barPath, bazPath).
		Fee(500).
		Range(9000, 11000).
		Amounts("100000", "100000").
		MinAmounts("0", "0").
		Build()

	env.AndLiquidityProvided(adminAddr, positionParams1)

	positionParams2 := NewPositionBuilder().
		Tokens(bazPath, quxPath).
		Fee(500).
		Range(9000, 11000).
		Amounts("100000", "100000").
		MinAmounts("0", "0").
		Build()

	env.AndLiquidityProvided(adminAddr, positionParams2)
}

func TestDrySwapRoute_Basic(t *testing.T) {
	tests := []DrySwapTestCase{
		{
			name:    "ExactIn - Single Route",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(bazPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_IN").
				Route("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500").
				TokenAmountLimit("1").
				Build(),
			expectedAmountIn:  "1000",
			expectedAmountOut: "2707",
			expectedSuccess:   true,
		},
		{
			name:    "ExactOut - Single Route",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(bazPath).
				OutputToken(barPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500").
				TokenAmountLimit("100000").
				Build(),
			expectedAmountIn:  "2727",
			expectedAmountOut: "1000",
			expectedSuccess:   true,
		},
		{
			name:    "ExactIn - Multi Route",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(quxPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_IN").
				Route("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500").
				TokenAmountLimit("1").
				Build(),
			expectedAmountIn:  "1000",
			expectedAmountOut: "7326",
			expectedSuccess:   true,
		},
		{
			name:    "ExactOut - Multi Route within tolerance",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(quxPath).
				SpecifiedAmount("5").
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500").
				TokenAmountLimit("10000").
				Build(),
			// Multi-hop ExactOut: backward dry swap now returns the correct final output
			expectedAmountIn:  "3",
			expectedAmountOut: "5",
			expectedSuccess:   true,
		},
		{
			name:    "ExactOut - Multi Route now within compound tolerance",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(quxPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500").
				TokenAmountLimit("10000").
				Build(),
			// With the backward dry swap fix, the correct final output is returned
			expectedAmountIn:  "138",
			expectedAmountOut: "1000",
			expectedSuccess:   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := NewTestEnv(t)

			if tt.setupFn != nil {
				tt.setupFn(env)
			}

			router := mockRouter()

			amountIn, amountOut, success := router.DrySwapRoute(
				tt.swapParams.inputToken,
				tt.swapParams.outputToken,
				tt.swapParams.specifiedAmount,
				tt.swapParams.swapTypeStr,
				tt.swapParams.strRouteArr,
				tt.swapParams.quoteArr,
				tt.swapParams.tokenAmountLimit,
			)

			uassert.Equal(t, tt.expectedAmountIn, amountIn)
			uassert.Equal(t, tt.expectedAmountOut, amountOut)
			uassert.Equal(t, tt.expectedSuccess, success)
		})
	}
}

func setupMultiRoutePools(env *TestEnv) {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*3)

	env.GivenPoolCreated(barPath, bazPath, 500, "130621891405341611593710811006")
	env.GivenPoolCreated(bazPath, quxPath, 500, "130621891405341611593710811006")
	env.GivenPoolCreated(barPath, quxPath, 500, "130621891405341611593710811006")

	bar.Approve(cross, poolAddr, maxApprove)
	baz.Approve(cross, poolAddr, maxApprove)
	qux.Approve(cross, poolAddr, maxApprove)

	positionParams1 := NewPositionBuilder().
		Tokens(barPath, bazPath).
		Fee(500).
		Range(9000, 11000).
		Amounts("100000", "100000").
		MinAmounts("0", "0").
		Build()

	env.AndLiquidityProvided(adminAddr, positionParams1)

	positionParams2 := NewPositionBuilder().
		Tokens(bazPath, quxPath).
		Fee(500).
		Range(9000, 11000).
		Amounts("100000", "100000").
		MinAmounts("0", "0").
		Build()

	env.AndLiquidityProvided(adminAddr, positionParams2)

	positionParams3 := NewPositionBuilder().
		Tokens(barPath, quxPath).
		Fee(500).
		Range(9000, 11000).
		Amounts("100000", "100000").
		MinAmounts("0", "0").
		Build()

	env.AndLiquidityProvided(adminAddr, positionParams3)
}

func TestDrySwapRoute_MultiRouteSplitQuote(t *testing.T) {
	tests := []DrySwapTestCase{
		{
			name:    "ExactOut - Two routes with split quote (50:50)",
			setupFn: setupMultiRoutePools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(quxPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500").
				Quote("50,50").
				TokenAmountLimit("10000").
				Build(),
			// With backward dry swap fix, multi-hop routes now return the correct final output
			expectedAmountIn:  "255",
			expectedAmountOut: "1000",
			expectedSuccess:   true,
		},
		{
			name:    "ExactOut - Three routes mixed hops (1-hop + 2-hop + 1-hop)",
			setupFn: setupMultiRoutePools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(quxPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:500").
				Quote("33,34,33").
				TokenAmountLimit("10000").
				Build(),
			expectedAmountIn:  "294",
			expectedAmountOut: "1000",
			expectedSuccess:   true,
		},
		{
			name:    "ExactIn - Two routes with split quote (70:30) - swapCount=3 total",
			setupFn: setupMultiRoutePools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(quxPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_IN").
				Route("gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500").
				Quote("70,30").
				TokenAmountLimit("1").
				Build(),
			expectedAmountIn:  "1000",
			expectedAmountOut: "4094",
			expectedSuccess:   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := NewTestEnv(t)

			if tt.setupFn != nil {
				tt.setupFn(env)
			}

			router := mockRouter()

			amountIn, amountOut, success := router.DrySwapRoute(
				tt.swapParams.inputToken,
				tt.swapParams.outputToken,
				tt.swapParams.specifiedAmount,
				tt.swapParams.swapTypeStr,
				tt.swapParams.strRouteArr,
				tt.swapParams.quoteArr,
				tt.swapParams.tokenAmountLimit,
			)

			uassert.Equal(t, tt.expectedAmountIn, amountIn)
			uassert.Equal(t, tt.expectedAmountOut, amountOut)
			uassert.Equal(t, tt.expectedSuccess, success)
		})
	}
}

func TestValidateSwapResults_ExactOutTolerance(t *testing.T) {
	processor := &SwapProcessor{}

	tests := []struct {
		name             string
		resultAmountIn   int64
		resultAmountOut  int64
		amountSpecified  int64
		amountLimit      int64
		swapCount        int64
		expectedSuccess  bool
	}{
		{
			name:             "exact match - should succeed",
			resultAmountIn:   1000,
			resultAmountOut:  500,
			amountSpecified:  -500, // negative for ExactOut
			amountLimit:      2000,
			swapCount:        1,
			expectedSuccess:  true,
		},
		{
			name:             "within tolerance (diff = swapCount) - should succeed",
			resultAmountIn:   1000,
			resultAmountOut:  499, // diff = 1, swapCount = 1
			amountSpecified:  -500,
			amountLimit:      2000,
			swapCount:        1,
			expectedSuccess:  true,
		},
		{
			name:             "within tolerance multi-hop (diff = swapCount) - should succeed",
			resultAmountIn:   1000,
			resultAmountOut:  497, // diff = 3, swapCount = 3
			amountSpecified:  -500,
			amountLimit:      2000,
			swapCount:        3,
			expectedSuccess:  true,
		},
		{
			name:             "diff=4 within compound rounding tolerance (swapCount=3) - should succeed",
			resultAmountIn:   1000,
			resultAmountOut:  496, // diff = 4, tolerance = 3*4 = 12
			amountSpecified:  -500,
			amountLimit:      2000,
			swapCount:        3,
			expectedSuccess:  true,
		},
		{
			name:             "exceeds compound rounding tolerance - should fail",
			resultAmountIn:   1000,
			resultAmountOut:  487, // diff = 13, tolerance = 3*4 = 12
			amountSpecified:  -500,
			amountLimit:      2000,
			swapCount:        3,
			expectedSuccess:  false,
		},
		{
			name:             "result higher than specified within tolerance - should succeed",
			resultAmountIn:   1000,
			resultAmountOut:  502, // diff = 2, swapCount = 3
			amountSpecified:  -500,
			amountLimit:      2000,
			swapCount:        3,
			expectedSuccess:  true,
		},
		{
			name:             "slippage exceeded (amountIn > limit) - should fail",
			resultAmountIn:   3000,
			resultAmountOut:  500,
			amountSpecified:  -500,
			amountLimit:      2000,
			swapCount:        1,
			expectedSuccess:  false,
		},
		{
			name:             "zero amounts - should fail",
			resultAmountIn:   0,
			resultAmountOut:  0,
			amountSpecified:  -500,
			amountLimit:      2000,
			swapCount:        1,
			expectedSuccess:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, success := processor.ValidateSwapResults(
				ExactOut,
				tt.resultAmountIn,
				tt.resultAmountOut,
				tt.amountSpecified,
				tt.amountLimit,
				tt.swapCount,
			)
			uassert.Equal(t, tt.expectedSuccess, success)
		})
	}
}

func TestValidateSwapResults_ExactOutToleranceWithVariousSwapCounts(t *testing.T) {
	processor := &SwapProcessor{}

	tests := []struct {
		name            string
		resultAmountOut int64
		amountSpecified int64
		swapCount       int64
		expectedSuccess bool
		description     string
	}{
		{
			name:            "swapCount=1, diff=0 - should succeed",
			resultAmountOut: 1000,
			amountSpecified: -1000,
			swapCount:       1,
			expectedSuccess: true,
			description:     "Exact match with single hop",
		},
		{
			name:            "swapCount=1, diff=4 - should succeed (boundary, tolerance=4)",
			resultAmountOut: 1004,
			amountSpecified: -1000,
			swapCount:       1,
			expectedSuccess: true,
			description:     "At tolerance boundary for single hop",
		},
		{
			name:            "swapCount=1, diff=5 - should fail (exceeds tolerance=4)",
			resultAmountOut: 1005,
			amountSpecified: -1000,
			swapCount:       1,
			expectedSuccess: false,
			description:     "Exceeds tolerance for single hop",
		},
		{
			name:            "swapCount=2, diff=8 - should succeed (boundary, tolerance=8)",
			resultAmountOut: 1008,
			amountSpecified: -1000,
			swapCount:       2,
			expectedSuccess: true,
			description:     "At tolerance boundary for 2-hop",
		},
		{
			name:            "swapCount=2, diff=9 - should fail (exceeds tolerance=8)",
			resultAmountOut: 1009,
			amountSpecified: -1000,
			swapCount:       2,
			expectedSuccess: false,
			description:     "Exceeds tolerance for 2-hop",
		},
		{
			name:            "swapCount=3, diff=12 - should succeed (boundary, tolerance=12)",
			resultAmountOut: 1012,
			amountSpecified: -1000,
			swapCount:       3,
			expectedSuccess: true,
			description:     "At tolerance boundary for 3-hop",
		},
		{
			name:            "swapCount=3, diff=13 - should fail (exceeds tolerance=12)",
			resultAmountOut: 1013,
			amountSpecified: -1000,
			swapCount:       3,
			expectedSuccess: false,
			description:     "Exceeds tolerance for 3-hop",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, success := processor.ValidateSwapResults(
				ExactOut,
				1000, // resultAmountIn doesn't matter for this test
				tt.resultAmountOut,
				tt.amountSpecified,
				999999, // high limit to not trigger slippage check
				tt.swapCount,
			)
			uassert.Equal(t, tt.expectedSuccess, success)
		})
	}
}

func TestValidateSwapResults_ExactIn(t *testing.T) {
	processor := &SwapProcessor{}

	tests := []struct {
		name             string
		resultAmountIn   int64
		resultAmountOut  int64
		amountSpecified  int64
		amountLimit      int64
		swapCount        int64
		expectedSuccess  bool
	}{
		{
			name:             "exact match - should succeed",
			resultAmountIn:   1000,
			resultAmountOut:  500,
			amountSpecified:  1000,
			amountLimit:      400,
			swapCount:        1,
			expectedSuccess:  true,
		},
		{
			name:             "amountIn less than specified - should succeed",
			resultAmountIn:   900,
			resultAmountOut:  500,
			amountSpecified:  1000,
			amountLimit:      400,
			swapCount:        1,
			expectedSuccess:  true,
		},
		{
			name:             "amountOut below limit - should fail",
			resultAmountIn:   1000,
			resultAmountOut:  300,
			amountSpecified:  1000,
			amountLimit:      400,
			swapCount:        1,
			expectedSuccess:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, success := processor.ValidateSwapResults(
				ExactIn,
				tt.resultAmountIn,
				tt.resultAmountOut,
				tt.amountSpecified,
				tt.amountLimit,
				tt.swapCount,
			)
			uassert.Equal(t, tt.expectedSuccess, success)
		})
	}
}

func TestDrySwapRouteOverflow(t *testing.T) {
	// maxUint256 exceeds int64 max, so parsing it as int64 will overflow
	maxUint256 := "115792089237316195423570985008687907853269984665640564039457584007913129639935"

	tests := []DrySwapTestCase{
		{
			name:    "ExactIn - Overflow in calculateSwapAmount",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(bazPath).
				SpecifiedAmount(maxUint256).
				SwapType("EXACT_IN").
				Route("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500").
				TokenAmountLimit("1").
				Build(),
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectedSuccess:   false,
			expectPanic:       true,
			expectedPanicMsg:  "value out of range",
		},
		{
			name:    "ExactOut - Overflow in calculateSwapAmount",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(bazPath).
				OutputToken(barPath).
				SpecifiedAmount(maxUint256).
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500").
				TokenAmountLimit("100000").
				Build(),
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectPanic:       true,
			expectedPanicMsg:  "value out of range",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := NewTestEnv(t)

			if tt.setupFn != nil {
				tt.setupFn(env)
			}

			router := mockRouter()

			if tt.expectPanic {
				uassert.PanicsContains(t, tt.expectedPanicMsg, func() {
					router.DrySwapRoute(
						tt.swapParams.inputToken,
						tt.swapParams.outputToken,
						tt.swapParams.specifiedAmount,
						tt.swapParams.swapTypeStr,
						tt.swapParams.strRouteArr,
						tt.swapParams.quoteArr,
						tt.swapParams.tokenAmountLimit,
					)
				})
			} else {
				amountIn, amountOut, success := router.DrySwapRoute(
					tt.swapParams.inputToken,
					tt.swapParams.outputToken,
					tt.swapParams.specifiedAmount,
					tt.swapParams.swapTypeStr,
					tt.swapParams.strRouteArr,
					tt.swapParams.quoteArr,
					tt.swapParams.tokenAmountLimit,
				)
				uassert.Equal(t, amountIn, tt.expectedAmountIn)
				uassert.Equal(t, amountOut, tt.expectedAmountOut)
				uassert.Equal(t, success, tt.expectedSuccess)
			}
		})
	}
}

func TestSwapCountCalculation(t *testing.T) {
	tests := []struct {
		name          string
		routes        []string
		expectedCount int64
	}{
		{
			name:          "Single route - 1 hop",
			routes:        []string{"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500"},
			expectedCount: 1,
		},
		{
			name:          "Single route - 2 hops",
			routes:        []string{"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500"},
			expectedCount: 2,
		},
		{
			name:          "Single route - 3 hops",
			routes:        []string{"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500*POOL*gno.land/r/onbloc/qux:gno.land/r/onbloc/foo:500"},
			expectedCount: 3,
		},
		{
			name: "Two routes - 1 hop each (total 2)",
			routes: []string{
				"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500",
				"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500",
			},
			expectedCount: 2,
		},
		{
			name: "Two routes - 2 hops each (total 4)",
			routes: []string{
				"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500",
				"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500",
			},
			expectedCount: 4,
		},
		{
			name: "Mixed routes - 1 hop + 3 hops (total 4)",
			routes: []string{
				"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500",
				"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500*POOL*gno.land/r/onbloc/qux:gno.land/r/onbloc/foo:500",
			},
			expectedCount: 4,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var totalCount int64
			for _, route := range tt.routes {
				numHops := strings.Count(route, POOL_SEPARATOR) + 1
				totalCount += int64(numHops)
			}
			uassert.Equal(t, tt.expectedCount, totalCount)
		})
	}
}

func TestDrySwapRouteZeroAmount(t *testing.T) {
	tests := []DrySwapTestCase{
		{
			name:    "ExactIn - Zero amount should panic",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(bazPath).
				SpecifiedAmount("0").
				SwapType("EXACT_IN").
				Route("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500").
				TokenAmountLimit("1").
				Build(),
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectedSuccess:   false,
			expectPanic:       true,
			expectedPanicMsg:  "must be positive",
		},
		{
			name:    "ExactOut - Zero amount should panic",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(bazPath).
				OutputToken(barPath).
				SpecifiedAmount("0").
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500").
				TokenAmountLimit("100000").
				Build(),
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectPanic:       true,
			expectedPanicMsg:  "must be positive",
		},
		{
			name:    "ExactIn - Negative amount should panic",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(bazPath).
				SpecifiedAmount("-100").
				SwapType("EXACT_IN").
				Route("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500").
				TokenAmountLimit("1").
				Build(),
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectedSuccess:   false,
			expectPanic:       true,
			expectedPanicMsg:  "must be positive",
		},
		{
			name:    "ExactOut - Negative amount should panic",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(bazPath).
				OutputToken(barPath).
				SpecifiedAmount("-100").
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500").
				TokenAmountLimit("100000").
				Build(),
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectPanic:       true,
			expectedPanicMsg:  "must be positive",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := NewTestEnv(t)

			if tt.setupFn != nil {
				tt.setupFn(env)
			}

			router := mockRouter()

			if tt.expectPanic {
				uassert.PanicsContains(t, tt.expectedPanicMsg, func() {
					router.DrySwapRoute(
						tt.swapParams.inputToken,
						tt.swapParams.outputToken,
						tt.swapParams.specifiedAmount,
						tt.swapParams.swapTypeStr,
						tt.swapParams.strRouteArr,
						tt.swapParams.quoteArr,
						tt.swapParams.tokenAmountLimit,
					)
				})
			} else {
				amountIn, amountOut, success := router.DrySwapRoute(
					tt.swapParams.inputToken,
					tt.swapParams.outputToken,
					tt.swapParams.specifiedAmount,
					tt.swapParams.swapTypeStr,
					tt.swapParams.strRouteArr,
					tt.swapParams.quoteArr,
					tt.swapParams.tokenAmountLimit,
				)
				uassert.Equal(t, amountIn, tt.expectedAmountIn)
				uassert.Equal(t, amountOut, tt.expectedAmountOut)
				uassert.Equal(t, success, tt.expectedSuccess)
			}
		})
	}
}

func TestDrySwapFailure_ShouldMatchActualSwapFailure(t *testing.T) {
	tests := []struct {
		name         string
		setupFn      func(*TestEnv)
		swapParams   DrySwapParams
		description  string
	}{
		{
			name:    "ExactOut - Multi Route with tight slippage limit (DrySwap fails due to amountIn > limit)",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(quxPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500").
				TokenAmountLimit("1").
				Build(),
			description: "DrySwap returns success=false due to amountIn exceeding tight slippage limit",
		},
		{
			name:    "ExactIn - Slippage too tight (amountOut below limit)",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(bazPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_IN").
				Route("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500").
				TokenAmountLimit("9999999").
				Build(),
			description: "DrySwap returns success=false due to slippage",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := NewTestEnv(t)

			if tt.setupFn != nil {
				tt.setupFn(env)
			}

			router := mockRouter()

			amountIn, amountOut, success := router.DrySwapRoute(
				tt.swapParams.inputToken,
				tt.swapParams.outputToken,
				tt.swapParams.specifiedAmount,
				tt.swapParams.swapTypeStr,
				tt.swapParams.strRouteArr,
				tt.swapParams.quoteArr,
				tt.swapParams.tokenAmountLimit,
			)

			uassert.Equal(t, false, success)
			t.Logf("DrySwap failed as expected: in=%s, out=%s, success=%t", amountIn, amountOut, success)
		})
	}
}
