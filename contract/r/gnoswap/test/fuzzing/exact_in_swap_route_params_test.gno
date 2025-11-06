package fuzzing

import (
	"time"

	"gno.land/p/gnoswap/fuzzing"
	"gno.land/p/nt/ufmt"
)

// ExactInSwapRouteParams is the parameters for the ExactInSwapRoute fuzzing test.
type exactInSwapRouteParams struct {
	inputToken   string
	outputToken  string
	amountIn     string
	routeArr     string
	quoteArr     string
	amountOutMin string
	deadline     int64
	referrer     string
}

func (p *exactInSwapRouteParams) IsValid() bool {
	return true
}

func (p *exactInSwapRouteParams) ToString() string {
	return ufmt.Sprintf("inputToken: %s, outputToken: %s, amountIn: %s, routeArr: %s, quoteArr: %s, amountOutMin: %s, deadline: %d, referrer: %s", p.inputToken, p.outputToken, p.amountIn, p.routeArr, p.quoteArr, p.amountOutMin, p.deadline, p.referrer)
}

func NewValidExactInSwapRouteParams(t *fuzzing.T) *exactInSwapRouteParams {
	amountIn := t.Uint256WithBoundaries(4).ToString()

	return &exactInSwapRouteParams{
		inputToken:   "gno.land/r/onbloc/bar",
		outputToken:  "gno.land/r/onbloc/foo",
		amountIn:     amountIn,
		routeArr:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
		quoteArr:     "100",
		amountOutMin: "0",
		deadline:     time.Now().Add(time.Hour).Unix(),
		referrer:     "",
	}
}

func NewRandomizedExactInSwapRouteParams(t *fuzzing.T) *exactInSwapRouteParams {
	return &exactInSwapRouteParams{
		inputToken:   "gno.land/r/gnoswap/test_token/token0",
		outputToken:  "gno.land/r/gnoswap/test_token/token1",
		amountIn:     "1000000",
		routeArr:     "gno.land/r/gnoswap/test_token/token0:gno.land/r/gnoswap/test_token/token1:3000",
		quoteArr:     "100",
		amountOutMin: "100",
		deadline:     time.Now().Add(time.Hour).Unix(),
		referrer:     "gno.land/r/gnoswap/test_token/token0",
	}
}
