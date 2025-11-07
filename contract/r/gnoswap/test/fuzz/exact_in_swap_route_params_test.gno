package fuzz

import (
	"math"
	"strconv"
	"strings"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/router"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// ExactInSwapRouteParams is the parameters for the ExactInSwapRoute fuzz test.
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

func (p *exactInSwapRouteParams) IsValid() bool {
	if !p.isValidTokenPair() {
		return false
	}

	if !p.isValidAmount() {
		return false
	}

	if !p.isValidRouteArr() {
		return false
	}

	if !p.isValidQuoteArr() {
		return false
	}

	if !p.isValidDeadline() {
		return false
	}

	if !p.isValidDrySwap() {
		return false
	}

	return true
}

func (p *exactInSwapRouteParams) isValidTokenPair() bool {
	if p.inputToken == "" || p.outputToken == "" {
		return false
	}

	return true
}

func (p *exactInSwapRouteParams) isValidAmount() bool {
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

	return true
}

// validate the routeArr
func (p *exactInSwapRouteParams) isValidRouteArr() bool {
	routes := strings.Split(p.routeArr, ",")
	for _, route := range routes {
		routePools := strings.Split(route, "*POOL*")
		if len(routePools) < 1 {
			return false
		}

		firstToken := ""
		lastToken := ""

		for i, routePool := range routePools {
			inputToken, outputToken, feeInt64 := parsePoolPath(routePool)

			if i == 0 && firstToken != p.inputToken {
				firstToken = inputToken
			}

			if lastToken != p.outputToken {
				lastToken = outputToken
			}

			if feeInt64 != 100 && feeInt64 != 500 && feeInt64 != 3000 && feeInt64 != 10000 {
				return false
			}
		}

		if firstToken != p.inputToken {
			return false
		}

		if lastToken != p.outputToken {
			return false
		}
	}

	return true
}

func (p *exactInSwapRouteParams) isValidQuoteArr() bool {
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

	return true
}

func (p *exactInSwapRouteParams) isValidDeadline() bool {
	if p.deadline < time.Now().Unix() {
		return false
	}

	return true
}

func (p *exactInSwapRouteParams) isValidDrySwap() bool {
	_, _, success := router.DrySwapRoute(
		p.inputToken,
		p.outputToken,
		p.amountIn,
		"EXACT_IN",
		p.routeArr,
		p.quoteArr,
		"1",
	)

	if !success {
		// if the drySwapRoute fails, check if the amountIn is less than 10
		return u256.MustFromDecimal(p.amountIn).LtUint64(10)
	}

	return success
}

func NewValidExactInSwapRouteParams(t *fuzz.T) *exactInSwapRouteParams {
	inputToken, outputToken := generateTokenPair(t)
	routeArr := generateRoutePathArr(t, inputToken, outputToken, 1, 1)
	quoteArr := generateRouteQuoteArr(t, len(strings.Split(routeArr, ",")))

	amountIn := fuzz.Int64Range(10, 100_000_000_000_000).Draw(t, "amountIn").(int64)
	amountInUint256 := u256.NewUintFromInt64(amountIn)

	return &exactInSwapRouteParams{
		inputToken:   inputToken,
		outputToken:  outputToken,
		amountIn:     amountInUint256.ToString(),
		routeArr:     routeArr,
		quoteArr:     quoteArr,
		amountOutMin: "0",
		deadline:     time.Now().Add(time.Hour).Unix(),
		referrer:     "",
	}
}

func NewRandomizedExactInSwapRouteParams(t *fuzz.T) *exactInSwapRouteParams {
	const maxRoutePathCount = 3
	const maxHops = 3

	inputToken, outputToken := generateTokenPair(t)
	routeArr := generateRoutePathArr(t, inputToken, outputToken, maxRoutePathCount, maxHops)
	quoteArr := generateRouteQuoteArr(t, len(strings.Split(routeArr, ",")))

	amountInVal := fuzz.Uint256().Draw(t, "amountIn").(*uint256.Uint)
	amountIn := amountInVal.ToString()

	return &exactInSwapRouteParams{
		inputToken:   inputToken,
		outputToken:  outputToken,
		amountIn:     amountIn,
		routeArr:     routeArr,
		quoteArr:     quoteArr,
		amountOutMin: "0",
		deadline:     time.Now().Add(time.Hour).Unix(),
		referrer:     "",
	}
}
