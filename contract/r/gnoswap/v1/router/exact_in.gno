package router

import (
	"std"
	"strconv"

	"gno.land/p/demo/ufmt"

	i256 "gno.land/p/gnoswap/int256"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/referral"
)

type ExactInSwapOperation struct {
	baseSwapOperation
	params ExactInParams
}

func NewExactInSwapOperation(pp ExactInParams) *ExactInSwapOperation {
	return &ExactInSwapOperation{
		params: pp,
		baseSwapOperation: baseSwapOperation{
			userWrappedWugnot: INITIAL_WUGNOT_BALANCE,
		},
	}
}

// ExactInSwapRoute swaps an exact amount of input tokens for output tokens.
//
// Parameters:
//   - inputToken, outputToken: token contract paths
//   - amountIn: exact input amount
//   - routeArr: swap route "POOL_PATH,TOKEN0,TOKEN1,FEE:NEXT_POOL..."
//   - quoteArr: percentage allocation for multi-path swaps
//   - amountOutMin: minimum output amount
//   - deadline: transaction deadline
//   - referrer: referral address
//
// Returns amountIn, amountOut as decimal strings.
// Note: Reverts if output < amountOutMin or deadline passed.
func ExactInSwapRoute(cur realm,
	inputToken string,
	outputToken string,
	amountIn string,
	RouteArr string,
	quoteArr string,
	amountOutMin string,
	deadline int64,
	referrer string,
) (string, string) {
	halt.AssertIsNotHaltedRouter()

	assertIsNotPassedDeadline(deadline)

	emission.MintAndDistributeGns(cross)

	params := SwapRouteParams{
		inputToken:  inputToken,
		outputToken: outputToken,
		routeArr:    RouteArr,
		quoteArr:    quoteArr,
		deadline:    deadline,
		typ:         ExactIn,
		exactAmount: amountIn,
		limitAmount: amountOutMin,
	}

	inputAmount, outputAmount, err := commonSwapRoute(params)
	if err != nil {
		panic(err)
	}

	if params.IsUnwrap() {
		amount, err := strconv.ParseInt(params.exactAmount, 10, 64)
		if err != nil {
			panic(err)
		}

		err = unwrapWithTransfer(std.PreviousRealm().Address(), amount)
		if err != nil {
			panic(err)
		}
	}

	// handle referral registration
	previousRealm := std.PreviousRealm()
	caller := previousRealm.Address()
	success := referral.TryRegister(cross, caller, referrer)
	actualReferrer := referrer
	if !success {
		actualReferrer = referral.GetReferral(caller.String())
	}

	std.Emit(
		"ExactInSwap",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"input", inputToken,
		"output", outputToken,
		"exactAmount", amountIn,
		"route", RouteArr,
		"quote", quoteArr,
		"resultInputAmount", inputAmount,
		"resultOutputAmount", outputAmount,
		"referrer", actualReferrer,
	)

	return inputAmount, outputAmount
}

// Validate validates the exact-in swap operation parameters.
func (op *ExactInSwapOperation) Validate() error {
	amountIn := i256.MustFromDecimal(op.params.AmountIn)
	if amountIn.IsZero() || amountIn.IsNeg() {
		return ufmt.Errorf("invalid amountIn(%s), must be positive", amountIn.ToString())
	}

	// when `SwapType` is `ExactIn`, assign `amountSpecified` the `amountIn`
	// obtained from above.
	op.amountSpecified = amountIn

	routes, quotes, err := validateRoutesAndQuotes(op.params.RouteArr, op.params.QuoteArr)
	if err != nil {
		return err
	}

	op.routes = routes
	op.quotes = quotes

	return nil
}

// Process executes the exact-in swap operation.
func (op *ExactInSwapOperation) Process() (*SwapResult, error) {
	if err := op.handleNativeTokenWrapping(); err != nil {
		return nil, err
	}

	resultAmountIn, resultAmountOut, err := op.processRoutes(ExactIn)
	if err != nil {
		return nil, err
	}

	return &SwapResult{
		AmountIn:        resultAmountIn,
		AmountOut:       resultAmountOut,
		Routes:          op.routes,
		Quotes:          op.quotes,
		AmountSpecified: op.amountSpecified,
		WithUnwrap:      op.withUnwrap,
	}, nil
}

// handleNativeTokenWrapping handles the wrapping of native tokens if needed.
func (op *ExactInSwapOperation) handleNativeTokenWrapping() error {
	return op.baseSwapOperation.handleNativeTokenWrapping(
		op.params.InputToken,
		op.params.OutputToken,
		op.amountSpecified,
	)
}
