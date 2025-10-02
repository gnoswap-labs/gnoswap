package router

import (
	"testing"

	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/v1/pool"

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
			name:    "ExactOut - Multi Route",
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
			expectedSuccess:   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := NewTestEnv(t)

			if tt.setupFn != nil {
				tt.setupFn(env)
			}

			amountIn, amountOut, success := DrySwapRoute(
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

func TestDrySwapRouteOverflow(t *testing.T) {
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
			expectPanic:       true,
			expectedPanicMsg:  "[GNOSWAP-ROUTER-005] invalid input data || overflow in calculateSwapAmount",
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
			expectedPanicMsg:  "overflow: denominator(9985) must be greater than hi(9999)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := NewTestEnv(t)

			if tt.setupFn != nil {
				tt.setupFn(env)
			}

			uassert.AbortsWithMessage(t, tt.expectedPanicMsg, func() {
				DrySwapRoute(
					tt.swapParams.inputToken,
					tt.swapParams.outputToken,
					tt.swapParams.specifiedAmount,
					tt.swapParams.swapTypeStr,
					tt.swapParams.strRouteArr,
					tt.swapParams.quoteArr,
					tt.swapParams.tokenAmountLimit,
				)
			})
		})
	}
}
