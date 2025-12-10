package v1

import (
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
			// Multi-hop ExactOut: requested 5, got 3 (diff=2, swapCount=2 -> within tolerance)
			expectedAmountIn:  "3",
			expectedAmountOut: "3",
			expectedSuccess:   true,
		},
		{
			name:    "ExactOut - Multi Route exceeds tolerance",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(quxPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500").
				TokenAmountLimit("10000").
				Build(),
			expectedAmountIn:  "138",
			expectedAmountOut: "370",
			expectedSuccess:   false,
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

func TestCalculateSwapCount(t *testing.T) {
	tests := []struct {
		name     string
		routeArr string
		expected int64
	}{
		{
			name:     "single hop single route",
			routeArr: "tokenA:tokenB:500",
			expected: 1,
		},
		{
			name:     "two hops single route",
			routeArr: "tokenA:tokenB:500*POOL*tokenB:tokenC:500",
			expected: 2,
		},
		{
			name:     "three hops single route",
			routeArr: "tokenA:tokenB:500*POOL*tokenB:tokenC:500*POOL*tokenC:tokenD:500",
			expected: 3,
		},
		{
			name:     "two single hop routes",
			routeArr: "tokenA:tokenB:500,tokenA:tokenC:500",
			expected: 2,
		},
		{
			name:     "mixed routes - one single hop and one two hop",
			routeArr: "tokenA:tokenB:500,tokenA:tokenC:500*POOL*tokenC:tokenB:500",
			expected: 3,
		},
		{
			name:     "complex multi-route",
			routeArr: "tokenA:tokenB:500*POOL*tokenB:tokenC:500,tokenA:tokenD:500*POOL*tokenD:tokenE:500*POOL*tokenE:tokenC:500",
			expected: 5,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := calculateSwapCount(tt.routeArr)
			uassert.Equal(t, tt.expected, result)
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
			name:             "exceeds tolerance by 1 - should fail",
			resultAmountIn:   1000,
			resultAmountOut:  496, // diff = 4, swapCount = 3
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
