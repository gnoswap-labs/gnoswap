package router

import (
	"chain"
	"strings"
	"testing"
	"time"

	"gno.land/p/gnoswap/utils"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"
)

const dryPoolFee uint32 = fee100

var (
	dryBasicPoolsReady      bool
	dryMultiRoutePoolsReady bool
)

type DrySwapTestCase struct {
	name              string
	setupFn           func(cur realm, env *TestEnv)
	swapParams        DrySwapParams
	expectedAmountIn  string
	expectedAmountOut string
	expectedSuccess   bool
	expectedErrMsg    string
}

// assertDrySwap verifies the result of a DrySwapRoute call:
//   - expectedErrMsg non-empty: expect an error containing the message
//   - expectedSuccess true: expect nil error and matching amounts
//   - expectedSuccess false: expect a non-nil error
func assertDrySwap(t *testing.T, tt DrySwapTestCase, amountIn, amountOut string, err error) {
	t.Helper()

	if tt.expectedErrMsg != "" {
		uassert.ErrorContains(t, err, tt.expectedErrMsg)
		return
	}

	if tt.expectedSuccess {
		uassert.NoError(t, err)
		uassert.Equal(t, tt.expectedAmountIn, amountIn)
		uassert.Equal(t, tt.expectedAmountOut, amountOut)
		return
	}

	uassert.Error(t, err)
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

func setupBasicPools(cur realm, env *TestEnv) {
	if dryBasicPoolsReady {
		return
	}

	gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee()*2)

	env.GivenPoolCreated(cur, barPath, bazPath, dryPoolFee, "130621891405341611593710811006")
	env.GivenPoolCreated(cur, bazPath, quxPath, dryPoolFee, "130621891405341611593710811006")

	bar.Approve(cross(cur), poolAddr, maxApprove)
	baz.Approve(cross(cur), poolAddr, maxApprove)
	qux.Approve(cross(cur), poolAddr, maxApprove)

	positionParams1 := NewPositionBuilder().
		Tokens(barPath, bazPath).
		Fee(dryPoolFee).
		Range(9000, 11000).
		Amounts("100000", "100000").
		MinAmounts("0", "0").
		Build()

	env.AndLiquidityProvided(cur, adminAddr, positionParams1)

	positionParams2 := NewPositionBuilder().
		Tokens(bazPath, quxPath).
		Fee(dryPoolFee).
		Range(9000, 11000).
		Amounts("100000", "100000").
		MinAmounts("0", "0").
		Build()

	env.AndLiquidityProvided(cur, adminAddr, positionParams2)

	dryBasicPoolsReady = true
}

func setupFullFillParityPools(cur realm, env *TestEnv) {
	gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee()*2)

	env.GivenPoolCreated(cur, barPath, oblPath, dryPoolFee, "130621891405341611593710811006")
	env.GivenPoolCreated(cur, oblPath, quxPath, dryPoolFee, "130621891405341611593710811006")

	bar.Approve(cross(cur), poolAddr, maxApprove)
	obl.Approve(cross(cur), poolAddr, maxApprove)
	qux.Approve(cross(cur), poolAddr, maxApprove)

	env.AndLiquidityProvided(cur, adminAddr, NewPositionBuilder().
		Tokens(barPath, oblPath).
		Fee(dryPoolFee).
		Range(9000, 11000).
		Amounts("100000", "100000").
		MinAmounts("0", "0").
		Build())
	env.AndLiquidityProvided(cur, adminAddr, NewPositionBuilder().
		Tokens(oblPath, quxPath).
		Fee(dryPoolFee).
		Range(9000, 11000).
		Amounts("100000", "100000").
		MinAmounts("0", "0").
		Build())
}

func setupPartialUpstreamPools(cur realm, env *TestEnv) {
	gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee()*2)

	env.GivenPoolCreated(cur, fooPath, oblPath, dryPoolFee, "130621891405341611593710811006")
	env.GivenPoolCreated(cur, oblPath, quxPath, dryPoolFee, "130621891405341611593710811006")

	foo.Approve(cross(cur), poolAddr, maxApprove)
	obl.Approve(cross(cur), poolAddr, maxApprove)
	qux.Approve(cross(cur), poolAddr, maxApprove)

	env.AndLiquidityProvided(cur, adminAddr, NewPositionBuilder().
		Tokens(fooPath, oblPath).
		Fee(dryPoolFee).
		Range(9000, 11000).
		Amounts("100", "100").
		MinAmounts("0", "0").
		Build())
	env.AndLiquidityProvided(cur, adminAddr, NewPositionBuilder().
		Tokens(oblPath, quxPath).
		Fee(dryPoolFee).
		Range(9000, 11000).
		Amounts("100000", "100000").
		MinAmounts("0", "0").
		Build())
}

func TestDrySwapRoute_ExactOutMultiHopMatchesActualSwap(cur realm, t *testing.T) {
	initRouterTest(cur, t)
	testing.SetRealm(adminRealm)
	env := NewTestEnv(cur, t)
	payer := chain.PackageAddress(routerV1Path)
	TokenFaucet(cur, t, barPath, payer)
	TokenApprove(cur, t, barPath, payer, routerAddr, maxApprove)
	testing.SetRealm(adminRealm)
	setupFullFillParityPools(cur, env)

	const route = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/obl.OBL:100*POOL*gno.land/r/onbloc/obl.OBL:gno.land/r/onbloc/qux.QUX:100"
	router := mockRouter()
	testing.SetRealm(adminRealm)
	func(cur realm) { router.SetSwapFee(0, cur, 0) }(cross(cur))
	testing.SetRealm(routerRealm)
	dryAmountIn, dryAmountOut, err := router.DrySwapRoute(barPath, quxPath, "5", "EXACT_OUT", route, "100", "10000")
	uassert.NoError(t, err)

	testing.SetRealm(adminRealm)
	var actualAmountIn, actualAmountOut int64
	var actualErr error
	func(cur realm) {
		testing.SetRealm(routerRealm)
		actualAmountIn, actualAmountOut, actualErr = router.commonSwapRoute(0, cur, SwapRouteParams{
			inputToken:  barPath,
			outputToken: quxPath,
			routeArr:    route,
			quoteArr:    "100",
			typ:         ExactOut,
			exactAmount: 5,
			limitAmount: 10000,
		})
	}(cross(cur))

	uassert.NoError(t, actualErr)
	actualIn := utils.FormatInt(actualAmountIn)
	actualOut := utils.FormatInt(actualAmountOut)
	t.Logf("full-fill exact-out parity: dry=(%s,%s) actual=(%s,%s)", dryAmountIn, dryAmountOut, actualIn, actualOut)
	uassert.Equal(t, actualIn, dryAmountIn)
	uassert.Equal(t, actualOut, dryAmountOut)
}

func TestDrySwapRoute_ExactOutMultiHopPartialUpstreamParity(cur realm, t *testing.T) {
	initRouterTest(cur, t)
	testing.SetRealm(adminRealm)
	env := NewTestEnv(cur, t)
	payer := chain.PackageAddress(routerV1Path)
	TokenFaucet(cur, t, fooPath, payer)
	TokenApprove(cur, t, fooPath, payer, routerAddr, maxApprove)
	testing.SetRealm(adminRealm)
	setupPartialUpstreamPools(cur, env)

	const route = "gno.land/r/onbloc/foo.FOO:gno.land/r/onbloc/obl.OBL:100*POOL*gno.land/r/onbloc/obl.OBL:gno.land/r/onbloc/qux.QUX:100"
	router := mockRouter()
	testing.SetRealm(adminRealm)
	func(cur realm) { router.SetSwapFee(0, cur, 0) }(cross(cur))
	testing.SetRealm(routerRealm)
	dryAmountIn, dryAmountOut, dryErr := router.DrySwapRoute(fooPath, quxPath, "1000", "EXACT_OUT", route, "100", "10000")

	testing.SetRealm(adminRealm)
	var actualAmountIn, actualAmountOut int64
	func(cur realm) {
		testing.SetRealm(routerRealm)
		sp := newSwapParams(oblPath, quxPath, dryPoolFee, routerAddr, -calculateExactOutWithRouterFee(1000, router.store.GetSwapFee()))
		swapInfo := router.collectBackwardDrySwapInfo(sp.SingleSwapParams, 2, route)
		actualAmountIn, actualAmountOut = router.executeCollectedSwaps(0, cur, swapInfo, routerAddr)
	}(cross(cur))

	actualIn := utils.FormatInt(actualAmountIn)
	actualNetOut := actualAmountOut - calculateRouterFee(actualAmountOut, router.store.GetSwapFee())
	actualOut := utils.FormatInt(actualNetOut)
	_, _, actualErr := (&SwapProcessor{router: router}).ValidateSwapResults(ExactOut, actualAmountIn, actualNetOut, 1000, 10000, 2)
	t.Logf("partial-upstream exact-out parity: dry=(%s,%s,err=%v) actual=(%s,%s,err=%v)", dryAmountIn, dryAmountOut, dryErr, actualIn, actualOut, actualErr)
	uassert.Equal(t, actualErr == nil, dryErr == nil)
	uassert.Equal(t, actualIn, dryAmountIn)
	uassert.Equal(t, actualOut, dryAmountOut)
}

func TestDrySwapRoute_Basic(cur realm, t *testing.T) {
	initRouterTest(cur, t)

	tests := []DrySwapTestCase{
		{
			name:    "ExactIn - Single Route",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(bazPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_IN").
				Route("gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100").
				TokenAmountLimit("1").
				Build(),
			expectedAmountIn:  "1000",
			expectedAmountOut: "2703",
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
				Route("gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/bar.BAR:100").
				TokenAmountLimit("100000").
				Build(),
			expectedAmountIn:  "2726",
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
				Route("gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:100").
				TokenAmountLimit("1").
				Build(),
			expectedAmountIn:  "1000",
			expectedAmountOut: "7314",
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
				Route("gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:100").
				TokenAmountLimit("10000").
				Build(),
			// Multi-hop ExactOut: the first pool outputs 3 intermediate tokens;
			// the last pool outputs the requested 5 route-final tokens.
			expectedAmountIn:  "3",
			expectedAmountOut: "5",
			expectedSuccess:   true,
		},
		{
			name:    "ExactOut - Multi Route returns route final output",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(quxPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:100").
				TokenAmountLimit("10000").
				Build(),
			// Forward replay produces 1002, then the 0.15% router fee deducts 1.
			expectedAmountIn:  "138",
			expectedAmountOut: "1001",
			expectedSuccess:   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			testing.SetRealm(adminRealm)
			env := NewTestEnv(cur, t)

			if tt.setupFn != nil {
				tt.setupFn(cur, env)
			}

			testing.SetRealm(routerRealm)

			router := mockRouter()

			amountIn, amountOut, err := router.DrySwapRoute(
				tt.swapParams.inputToken,
				tt.swapParams.outputToken,
				tt.swapParams.specifiedAmount,
				tt.swapParams.swapTypeStr,
				tt.swapParams.strRouteArr,
				tt.swapParams.quoteArr,
				tt.swapParams.tokenAmountLimit,
			)
			assertDrySwap(t, tt, amountIn, amountOut, err)
		})
	}
}

func setupMultiRoutePools(cur realm, env *TestEnv) {
	if dryMultiRoutePoolsReady {
		return
	}

	if !dryBasicPoolsReady {
		setupBasicPools(cur, env)
	}

	gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee())

	barQuxPath := pl.GetPoolPath(barPath, quxPath, dryPoolFee)
	if !pl.ExistsPoolPath(barQuxPath) {
		env.GivenPoolCreated(cur, barPath, quxPath, dryPoolFee, "130621891405341611593710811006")

		bar.Approve(cross(cur), poolAddr, maxApprove)
		qux.Approve(cross(cur), poolAddr, maxApprove)

		positionParams := NewPositionBuilder().
			Tokens(barPath, quxPath).
			Fee(dryPoolFee).
			Range(9000, 11000).
			Amounts("100000", "100000").
			MinAmounts("0", "0").
			Build()

		env.AndLiquidityProvided(cur, adminAddr, positionParams)
	}

	dryMultiRoutePoolsReady = true
}

func TestDrySwapRoute_MultiRouteSplitQuote(cur realm, t *testing.T) {
	initRouterTest(cur, t)

	tests := []DrySwapTestCase{
		{
			name:    "ExactOut - Two routes with split quote (50:50)",
			setupFn: setupMultiRoutePools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(quxPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100,gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:100").
				Quote("50,50").
				TokenAmountLimit("10000").
				Build(),
			expectedAmountIn:  "255",
			expectedAmountOut: "1001",
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
				Route("gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100,gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:100,gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100").
				Quote("33,34,33").
				TokenAmountLimit("10000").
				Build(),
			expectedAmountIn:  "294",
			expectedAmountOut: "1002",
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
				Route("gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100,gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:100").
				Quote("70,30").
				TokenAmountLimit("1").
				Build(),
			expectedAmountIn:  "1000",
			expectedAmountOut: "4085",
			expectedSuccess:   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			testing.SetRealm(adminRealm)
			env := NewTestEnv(cur, t)

			if tt.setupFn != nil {
				tt.setupFn(cur, env)
			}

			testing.SetRealm(routerRealm)

			router := mockRouter()

			amountIn, amountOut, err := router.DrySwapRoute(
				tt.swapParams.inputToken,
				tt.swapParams.outputToken,
				tt.swapParams.specifiedAmount,
				tt.swapParams.swapTypeStr,
				tt.swapParams.strRouteArr,
				tt.swapParams.quoteArr,
				tt.swapParams.tokenAmountLimit,
			)
			assertDrySwap(t, tt, amountIn, amountOut, err)
		})
	}
}

func TestValidateSwapResults_ExactOutTolerance(cur realm, t *testing.T) {
	processor := &SwapProcessor{}

	tests := []struct {
		name            string
		resultAmountIn  int64
		resultAmountOut int64
		amountSpecified int64
		amountLimit     int64
		swapCount       int64
		expectedSuccess bool
	}{
		{
			name:            "exact match - should succeed",
			resultAmountIn:  1000,
			resultAmountOut: 500,
			amountSpecified: -500, // negative for ExactOut
			amountLimit:     2000,
			swapCount:       1,
			expectedSuccess: true,
		},
		{
			name:            "within tolerance (diff = swapCount) - should succeed",
			resultAmountIn:  1000,
			resultAmountOut: 499, // diff = 1, swapCount = 1
			amountSpecified: -500,
			amountLimit:     2000,
			swapCount:       1,
			expectedSuccess: true,
		},
		{
			name:            "within tolerance multi-hop (diff = swapCount) - should succeed",
			resultAmountIn:  1000,
			resultAmountOut: 497, // diff = 3, swapCount = 3
			amountSpecified: -500,
			amountLimit:     2000,
			swapCount:       3,
			expectedSuccess: true,
		},
		{
			name:            "exceeds tolerance by 1 - should fail",
			resultAmountIn:  1000,
			resultAmountOut: 496, // diff = 4, swapCount = 3
			amountSpecified: -500,
			amountLimit:     2000,
			swapCount:       3,
			expectedSuccess: false,
		},
		{
			name:            "result higher than specified within tolerance - should succeed",
			resultAmountIn:  1000,
			resultAmountOut: 502, // diff = 2, swapCount = 3
			amountSpecified: -500,
			amountLimit:     2000,
			swapCount:       3,
			expectedSuccess: true,
		},
		{
			name:            "slippage exceeded (amountIn > limit) - should fail",
			resultAmountIn:  3000,
			resultAmountOut: 500,
			amountSpecified: -500,
			amountLimit:     2000,
			swapCount:       1,
			expectedSuccess: false,
		},
		{
			name:            "zero amounts - should fail",
			resultAmountIn:  0,
			resultAmountOut: 0,
			amountSpecified: -500,
			amountLimit:     2000,
			swapCount:       1,
			expectedSuccess: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			_, _, err := processor.ValidateSwapResults(
				ExactOut,
				tt.resultAmountIn,
				tt.resultAmountOut,
				tt.amountSpecified,
				tt.amountLimit,
				tt.swapCount,
			)
			if tt.expectedSuccess {
				uassert.NoError(t, err)
			} else {
				uassert.Error(t, err)
			}
		})
	}
}

func TestValidateSwapResults_ExactOutToleranceWithVariousSwapCounts(cur realm, t *testing.T) {
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
			name:            "swapCount=1, diff=1 - should succeed (boundary)",
			resultAmountOut: 1001,
			amountSpecified: -1000,
			swapCount:       1,
			expectedSuccess: true,
			description:     "Within tolerance for single hop",
		},
		{
			name:            "swapCount=1, diff=2 - should fail",
			resultAmountOut: 1002,
			amountSpecified: -1000,
			swapCount:       1,
			expectedSuccess: false,
			description:     "Exceeds tolerance for single hop",
		},
		{
			name:            "swapCount=2, diff=2 - should succeed (boundary)",
			resultAmountOut: 1002,
			amountSpecified: -1000,
			swapCount:       2,
			expectedSuccess: true,
			description:     "Within tolerance for 2-hop",
		},
		{
			name:            "swapCount=2, diff=3 - should fail",
			resultAmountOut: 1003,
			amountSpecified: -1000,
			swapCount:       2,
			expectedSuccess: false,
			description:     "Exceeds tolerance for 2-hop",
		},
		{
			name:            "swapCount=3, diff=3 - should succeed (boundary)",
			resultAmountOut: 1003,
			amountSpecified: -1000,
			swapCount:       3,
			expectedSuccess: true,
			description:     "Within tolerance for 3-hop",
		},
		{
			name:            "swapCount=3, diff=4 - should fail",
			resultAmountOut: 1004,
			amountSpecified: -1000,
			swapCount:       3,
			expectedSuccess: false,
			description:     "Exceeds tolerance for 3-hop",
		},
		{
			name:            "swapCount=5, diff=5 - should succeed (boundary)",
			resultAmountOut: 1005,
			amountSpecified: -1000,
			swapCount:       5,
			expectedSuccess: true,
			description:     "Within tolerance for 5-hop",
		},
		{
			name:            "swapCount=5, diff=6 - should fail",
			resultAmountOut: 1006,
			amountSpecified: -1000,
			swapCount:       5,
			expectedSuccess: false,
			description:     "Exceeds tolerance for 5-hop",
		},
		{
			name:            "swapCount=10, diff=10 - should succeed (boundary)",
			resultAmountOut: 1010,
			amountSpecified: -1000,
			swapCount:       10,
			expectedSuccess: true,
			description:     "Within tolerance for 10-hop",
		},
		{
			name:            "swapCount=10, diff=11 - should fail",
			resultAmountOut: 1011,
			amountSpecified: -1000,
			swapCount:       10,
			expectedSuccess: false,
			description:     "Exceeds tolerance for 10-hop",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			_, _, err := processor.ValidateSwapResults(
				ExactOut,
				1000, // resultAmountIn doesn't matter for this test
				tt.resultAmountOut,
				tt.amountSpecified,
				999999, // high limit to not trigger slippage check
				tt.swapCount,
			)
			if tt.expectedSuccess {
				uassert.NoError(t, err)
			} else {
				uassert.Error(t, err)
			}
		})
	}
}

func TestValidateSwapResults_ExactIn(cur realm, t *testing.T) {
	processor := &SwapProcessor{}

	tests := []struct {
		name            string
		resultAmountIn  int64
		resultAmountOut int64
		amountSpecified int64
		amountLimit     int64
		swapCount       int64
		expectedSuccess bool
	}{
		{
			name:            "exact match - should succeed",
			resultAmountIn:  1000,
			resultAmountOut: 500,
			amountSpecified: 1000,
			amountLimit:     400,
			swapCount:       1,
			expectedSuccess: true,
		},
		{
			name:            "amountIn less than specified (partial fill) - should fail",
			resultAmountIn:  900,
			resultAmountOut: 500,
			amountSpecified: 1000,
			amountLimit:     400,
			swapCount:       1,
			expectedSuccess: false,
		},
		{
			name:            "amountIn greater than specified - should fail",
			resultAmountIn:  1100,
			resultAmountOut: 500,
			amountSpecified: 1000,
			amountLimit:     400,
			swapCount:       1,
			expectedSuccess: false,
		},
		{
			name:            "amountOut below limit - should fail",
			resultAmountIn:  1000,
			resultAmountOut: 300,
			amountSpecified: 1000,
			amountLimit:     400,
			swapCount:       1,
			expectedSuccess: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			_, _, err := processor.ValidateSwapResults(
				ExactIn,
				tt.resultAmountIn,
				tt.resultAmountOut,
				tt.amountSpecified,
				tt.amountLimit,
				tt.swapCount,
			)
			if tt.expectedSuccess {
				uassert.NoError(t, err)
			} else {
				uassert.Error(t, err)
			}
		})
	}
}

func TestDrySwapRouteOverflow(cur realm, t *testing.T) {
	initRouterTest(cur, t)

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
				Route("gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100").
				TokenAmountLimit("1").
				Build(),
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectedSuccess:   false,
			expectedErrMsg:    "value out of range",
		},
		{
			name:    "ExactOut - Overflow in calculateSwapAmount",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(bazPath).
				OutputToken(barPath).
				SpecifiedAmount(maxUint256).
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/bar.BAR:100").
				TokenAmountLimit("100000").
				Build(),
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectedErrMsg:    "value out of range",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			testing.SetRealm(adminRealm)
			env := NewTestEnv(cur, t)

			if tt.setupFn != nil {
				tt.setupFn(cur, env)
			}

			testing.SetRealm(routerRealm)

			router := mockRouter()

			amountIn, amountOut, err := router.DrySwapRoute(
				tt.swapParams.inputToken,
				tt.swapParams.outputToken,
				tt.swapParams.specifiedAmount,
				tt.swapParams.swapTypeStr,
				tt.swapParams.strRouteArr,
				tt.swapParams.quoteArr,
				tt.swapParams.tokenAmountLimit,
			)
			assertDrySwap(t, tt, amountIn, amountOut, err)
		})
	}
}

func TestSwapCountCalculation(cur realm, t *testing.T) {
	tests := []struct {
		name          string
		routes        []string
		expectedCount int64
	}{
		{
			name:          "Single route - 1 hop",
			routes:        []string{"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"},
			expectedCount: 1,
		},
		{
			name:          "Single route - 2 hops",
			routes:        []string{"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:100"},
			expectedCount: 2,
		},
		{
			name:          "Single route - 3 hops",
			routes:        []string{"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:100*POOL*gno.land/r/onbloc/qux.QUX:gno.land/r/onbloc/foo.FOO:100"},
			expectedCount: 3,
		},
		{
			name: "Two routes - 1 hop each (total 2)",
			routes: []string{
				"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100",
				"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100",
			},
			expectedCount: 2,
		},
		{
			name: "Two routes - 2 hops each (total 4)",
			routes: []string{
				"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:100",
				"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:100",
			},
			expectedCount: 4,
		},
		{
			name: "Mixed routes - 1 hop + 3 hops (total 4)",
			routes: []string{
				"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100",
				"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:100*POOL*gno.land/r/onbloc/qux.QUX:gno.land/r/onbloc/foo.FOO:100",
			},
			expectedCount: 4,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			var totalCount int64
			for _, route := range tt.routes {
				numHops := strings.Count(route, POOL_SEPARATOR) + 1
				totalCount += int64(numHops)
			}
			uassert.Equal(t, tt.expectedCount, totalCount)
		})
	}
}

func TestDrySwapRouteZeroAmount(cur realm, t *testing.T) {
	initRouterTest(cur, t)

	tests := []DrySwapTestCase{
		{
			name:    "ExactIn - Zero amount should panic",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(bazPath).
				SpecifiedAmount("0").
				SwapType("EXACT_IN").
				Route("gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100").
				TokenAmountLimit("1").
				Build(),
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectedSuccess:   false,
			expectedErrMsg:    "must be positive",
		},
		{
			name:    "ExactOut - Zero amount should panic",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(bazPath).
				OutputToken(barPath).
				SpecifiedAmount("0").
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/bar.BAR:100").
				TokenAmountLimit("100000").
				Build(),
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectedErrMsg:    "must be positive",
		},
		{
			name:    "ExactIn - Negative amount should panic",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(bazPath).
				SpecifiedAmount("-100").
				SwapType("EXACT_IN").
				Route("gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100").
				TokenAmountLimit("1").
				Build(),
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectedSuccess:   false,
			expectedErrMsg:    "must be positive",
		},
		{
			name:    "ExactOut - Negative amount should panic",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(bazPath).
				OutputToken(barPath).
				SpecifiedAmount("-100").
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/bar.BAR:100").
				TokenAmountLimit("100000").
				Build(),
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectedErrMsg:    "must be positive",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			testing.SetRealm(adminRealm)
			env := NewTestEnv(cur, t)

			if tt.setupFn != nil {
				tt.setupFn(cur, env)
			}

			testing.SetRealm(routerRealm)

			router := mockRouter()

			amountIn, amountOut, err := router.DrySwapRoute(
				tt.swapParams.inputToken,
				tt.swapParams.outputToken,
				tt.swapParams.specifiedAmount,
				tt.swapParams.swapTypeStr,
				tt.swapParams.strRouteArr,
				tt.swapParams.quoteArr,
				tt.swapParams.tokenAmountLimit,
			)
			assertDrySwap(t, tt, amountIn, amountOut, err)
		})
	}
}

func TestDrySwapFailure_ShouldMatchActualSwapFailure(cur realm, t *testing.T) {
	initRouterTest(cur, t)

	tests := []struct {
		name            string
		setupFn         func(cur realm, env *TestEnv)
		swapParams      DrySwapParams
		expectedErr     string
		actualSwapExact bool
	}{
		{
			name:    "ExactOut - Input exceeds limit (DrySwap fails, Swap should fail too)",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(quxPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_OUT").
				Route("gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:100").
				TokenAmountLimit("100").
				Build(),
			expectedErr:     "ExactOut: too much spent",
			actualSwapExact: true,
		},
		{
			name:    "ExactIn - Slippage too tight (amountOut below limit)",
			setupFn: setupBasicPools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(bazPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_IN").
				Route("gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100").
				TokenAmountLimit("9999999").
				Build(),
			expectedErr: "ExactIn: too few received",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			testing.SetRealm(adminRealm)
			env := NewTestEnv(cur, t)
			payer := chain.PackageAddress(routerV1Path)
			TokenFaucet(cur, t, barPath, payer)
			TokenApprove(cur, t, barPath, payer, routerAddr, maxApprove)
			testing.SetRealm(adminRealm)

			if tt.setupFn != nil {
				tt.setupFn(cur, env)
			}

			router := mockRouter()
			testing.SetRealm(routerRealm)

			_, _, err := router.DrySwapRoute(
				tt.swapParams.inputToken,
				tt.swapParams.outputToken,
				tt.swapParams.specifiedAmount,
				tt.swapParams.swapTypeStr,
				tt.swapParams.strRouteArr,
				tt.swapParams.quoteArr,
				tt.swapParams.tokenAmountLimit,
			)

			uassert.ErrorContains(t, err, tt.expectedErr)
			t.Logf("DrySwap failed as expected: %v", err)

			uassert.AbortsContains(t, cur, tt.expectedErr, func(cur realm) {
				testing.SetRealm(routerRealm)
				if tt.actualSwapExact {
					router.ExactOutSwapRoute(0, cur, tt.swapParams.inputToken, tt.swapParams.outputToken, tt.swapParams.specifiedAmount, tt.swapParams.strRouteArr, tt.swapParams.quoteArr, tt.swapParams.tokenAmountLimit, time.Now().Add(time.Hour).Unix(), "")
					return
				}
				router.ExactInSwapRoute(0, cur, tt.swapParams.inputToken, tt.swapParams.outputToken, tt.swapParams.specifiedAmount, tt.swapParams.strRouteArr, tt.swapParams.quoteArr, tt.swapParams.tokenAmountLimit, time.Now().Add(time.Hour).Unix(), "")
			})
		})
	}
}

// TestDrySwapRoute_InvalidRoutePaths asserts that DrySwapRoute validates route
// paths the same way real swaps do: the first token of every route must match
// inputToken, the last token must match outputToken, multi-hop routes must be
// hop-connected, and every referenced pool must exist. Before this fix,
// DrySwapRoute happily quoted an unrelated (but existing) pool, so callers
// could receive a successful quote for a route that real swaps would reject.
func TestDrySwapRoute_InvalidRoutePaths(cur realm, t *testing.T) {
	initRouterTest(cur, t)

	tests := []DrySwapTestCase{
		{
			name:    "ExactIn - route first token does not match inputToken",
			setupFn: setupMultiRoutePools,
			swapParams: NewDrySwapBuilder().
				InputToken(bazPath).
				OutputToken(quxPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_IN").
				Route(barPath + ":" + bazPath + ":100").
				TokenAmountLimit("1").
				Build(),
			expectedErrMsg: errInvalidRouteFirstToken,
		},
		{
			name:    "ExactIn - route last token does not match outputToken",
			setupFn: setupMultiRoutePools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(quxPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_IN").
				Route(barPath + ":" + bazPath + ":100").
				TokenAmountLimit("1").
				Build(),
			expectedErrMsg: errInvalidRouteLastToken,
		},
		{
			name:    "ExactOut - route last token does not match outputToken",
			setupFn: setupMultiRoutePools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(quxPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_OUT").
				Route(barPath + ":" + bazPath + ":100").
				TokenAmountLimit("100000").
				Build(),
			expectedErrMsg: errInvalidRouteLastToken,
		},
		{
			name:    "ExactIn - multi-hop route hops disconnected",
			setupFn: setupMultiRoutePools,
			// Route starts with barPath and ends with quxPath (matching
			// inputToken/outputToken) but hop 1 output (baz) != hop 2 input
			// (qux), isolating hop-connectivity validation from the
			// first/last-token checks.
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(quxPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_IN").
				Route(barPath + ":" + bazPath + ":100*POOL*" + quxPath + ":" + barPath + ":100*POOL*" + barPath + ":" + quxPath + ":100").
				TokenAmountLimit("1").
				Build(),
			expectedErrMsg: errRouteHopDisconnected,
		},
		{
			name:    "ExactIn - pool does not exist",
			setupFn: setupMultiRoutePools,
			swapParams: NewDrySwapBuilder().
				InputToken(barPath).
				OutputToken(bazPath).
				SpecifiedAmount("1000").
				SwapType("EXACT_IN").
				Route(barPath + ":" + fooPath + ":10000*POOL*" + fooPath + ":" + bazPath + ":10000").
				TokenAmountLimit("1").
				Build(),
			expectedErrMsg: "pool does not exist",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			testing.SetRealm(adminRealm)
			env := NewTestEnv(cur, t)

			if tt.setupFn != nil {
				tt.setupFn(cur, env)
			}

			testing.SetRealm(routerRealm)

			router := mockRouter()

			amountIn, amountOut, err := router.DrySwapRoute(
				tt.swapParams.inputToken,
				tt.swapParams.outputToken,
				tt.swapParams.specifiedAmount,
				tt.swapParams.swapTypeStr,
				tt.swapParams.strRouteArr,
				tt.swapParams.quoteArr,
				tt.swapParams.tokenAmountLimit,
			)
			assertDrySwap(t, tt, amountIn, amountOut, err)
		})
	}
}
