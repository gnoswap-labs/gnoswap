package fuzzing

import (
	"math"
	"strconv"
	"strings"
	"time"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/gnoswap/fuzzing"
	"gno.land/p/gnoswap/uint256"
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
	if p.inputToken == "" || p.outputToken == "" {
		return false
	}

	amountIn := u256.MustFromDecimal(p.amountIn)

	if amountIn.Cmp(u256.Zero()) <= 0 {
		return false
	}

	if amountIn.Cmp(u256.NewUintFromInt64(math.MaxInt64)) > 0 {
		return false
	}

	minAmountOut := u256.MustFromDecimal(p.amountOutMin)
	if minAmountOut.Cmp(u256.NewUintFromInt64(math.MaxInt64)) > 0 {
		return false
	}

	quoteSum := int64(0)
	quotes := make([]int64, 0)

	for _, quote := range strings.Split(p.quoteArr, ",") {
		quoteInt, err := strconv.ParseInt(quote, 10, 64)
		if err != nil {
			return false
		}

		quoteSum += quoteInt
		quotes = append(quotes, quoteInt)
	}

	if quoteSum != 100 {
		return false
	}

	// validate the routeArr
	routes := strings.Split(p.routeArr, ",")
	for _, route := range routes {
		routePools := strings.Split(route, "*POOL*")
		if len(routePools) < 1 {
			return false
		}

		firstToken := ""
		lastToken := ""

		for _, routePool := range routePools {
			routePoolParts := strings.Split(routePool, ":")
			if len(routePoolParts) != 3 {
				return false
			}

			if firstToken == "" {
				firstToken = routePoolParts[0]
			}

			lastToken = routePoolParts[1]

			feeInt64, err := strconv.ParseInt(routePoolParts[2], 10, 64)
			if err != nil {
				return false
			}

			if firstToken != p.inputToken {
				return false
			}

			if lastToken != p.outputToken {
				return false
			}

			if feeInt64 != 100 && feeInt64 != 500 && feeInt64 != 3000 && feeInt64 != 10000 {
				return false
			}
		}
	}

	if p.deadline < time.Now().Unix() {
		return false
	}

	return true
}

func (p *exactInSwapRouteParams) ToString() string {
	return ufmt.Sprintf("inputToken: %s, outputToken: %s, amountIn: %s, routeArr: %s, quoteArr: %s, amountOutMin: %s, deadline: %d, referrer: %s",
		p.inputToken,
		p.outputToken,
		p.amountIn,
		p.routeArr,
		p.quoteArr,
		p.amountOutMin,
		p.deadline,
		p.referrer,
	)
}

func NewValidExactInSwapRouteParams(t *fuzzing.T) *exactInSwapRouteParams {
	amountIn := fuzzing.Int64Range(1, math.MaxInt64).Draw(t, "amountIn").(int64)
	amountInUint256 := u256.NewUintFromInt64(amountIn)

	return &exactInSwapRouteParams{
		inputToken:   "gno.land/r/onbloc/bar",
		outputToken:  "gno.land/r/onbloc/foo",
		amountIn:     amountInUint256.ToString(),
		routeArr:     "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000",
		quoteArr:     "100",
		amountOutMin: "0",
		deadline:     time.Now().Add(time.Hour).Unix(),
		referrer:     "",
	}
}

func NewRandomizedExactInSwapRouteParams(t *fuzzing.T) *exactInSwapRouteParams {
	amountInVal := fuzzing.Uint256().Draw(t, "amountIn").(*uint256.Uint)
	amountIn := amountInVal.ToString()

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
