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

// ExactOutSwapRouteParams is the parameters for the ExactOutSwapRoute fuzz test.
type exactOutSwapRouteParams struct {
	inputToken       string
	outputToken      string
	amountOut        string
	amountIn         string
	routeArr         string
	quoteArr         string
	amountInMax      string
	deadline         int64
	referrer         string
	isPreDrySwap     bool
	preDrySwapResult bool
}

func (p *exactOutSwapRouteParams) ToString() string {
	return ufmt.Sprintf("inputToken: %s, outputToken: %s, amountOut: %s, routeArr: %s, quoteArr: %s, amountInMax: %s, deadline: %d, referrer: %s",
		p.inputToken,
		p.outputToken,
		p.amountOut,
		p.routeArr,
		p.quoteArr,
		p.amountInMax,
		p.deadline,
		p.referrer,
	)
}

func (p *exactOutSwapRouteParams) IsValid() bool {
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

func (p *exactOutSwapRouteParams) isValidTokenPair() bool {
	if p.inputToken == "" || p.outputToken == "" {
		return false
	}

	return true
}

func (p *exactOutSwapRouteParams) isValidAmount() bool {
	amountOut := u256.MustFromDecimal(p.amountOut)

	if amountOut.Cmp(u256.Zero()) <= 0 {
		return false
	}

	if amountOut.Cmp(u256.NewUintFromInt64(math.MaxInt64)) > 0 {
		return false
	}

	maxAmountIn := u256.MustFromDecimal(p.amountInMax)
	if maxAmountIn.Cmp(u256.Zero()) <= 0 {
		return false
	}

	if maxAmountIn.Cmp(u256.NewUintFromInt64(math.MaxInt64)) > 0 {
		return false
	}

	if p.amountIn != "" && p.amountIn != "0" {
        amountIn := u256.MustFromDecimal(p.amountIn)
        if amountIn.Gt(maxAmountIn) {
            return false
        }
    }

	return true
}

// validate the routeArr
func (p *exactOutSwapRouteParams) isValidRouteArr() bool {
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

func (p *exactOutSwapRouteParams) isValidQuoteArr() bool {
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

func (p *exactOutSwapRouteParams) isValidDeadline() bool {
	if p.deadline < time.Now().Unix() {
		return false
	}

	return true
}

// isValidMintOverflow checks if minting the required input tokens would cause int64 overflow
func (p *exactOutSwapRouteParams) isValidMintOverflow(amountInStr string) bool {
	amountIn := u256.MustFromDecimal(amountInStr)

	// Convert to int64 for mint check
	if amountIn.Cmp(u256.NewUintFromInt64(math.MaxInt64)) > 0 {
		return false
	}

	amountInInt64 := amountIn.Int64()
	if amountInInt64 < 0 {
		amountInInt64 = 0
	}

	// Get current total supply of the input token
	currentSupply := getTokenTotalSupply(p.inputToken)

	// Check for overflow: if currentSupply + amountInInt64 > MaxInt64
	if currentSupply > 0 && amountInInt64 > 0 {
		if math.MaxInt64-currentSupply < amountInInt64 {
			return false
		}
	}

	return true
}

func (p *exactOutSwapRouteParams) isValidDrySwap() bool {
	// If updateAmountInByPreDrySwap() was already called, use cached result
	if p.isPreDrySwap {
		return p.preDrySwapResult
	}

	// Otherwise, run a simple dry swap check
	_, _, success := p.drySwapRoute()
	return success
}

func (p *exactOutSwapRouteParams) updateAmountInByPreDrySwap() {
	p.isPreDrySwap = true

	amountIn, amountOut, success := p.drySwapRoute()

	if !success {
		p.preDrySwapResult = false
		return
	}

	// Check mint overflow for the required input amount
	if !p.isValidMintOverflow(amountIn) {
		p.preDrySwapResult = false
		return
	}

	p.preDrySwapResult = true
	p.amountIn = amountIn      // actual required input amount
	p.amountOut = amountOut    // use DrySwap's achievable output amount
}

func (p *exactOutSwapRouteParams) drySwapRoute() (amountIn string, amountOut string, success bool) {
	r := revive(func() {
		func(cur realm) {
			amountIn, amountOut, success = router.DrySwapRoute(
				p.inputToken,
				p.outputToken,
				p.amountOut,
				"EXACT_OUT",
				p.routeArr,
				p.quoteArr,
				u256.NewUintFromInt64(math.MaxInt64).ToString(),
			)
		}(cross)
	})

	if r != nil {
		return "0", "0", false
	}

	return amountIn, amountOut, success
}

func NewValidExactOutSwapRouteParams(t *fuzz.T) *exactOutSwapRouteParams {
	inputToken, outputToken := generateTokenPair(t)
	routeArr := generateRoutePathArr(t, inputToken, outputToken, 1, 1)
	quoteArr := generateRouteQuoteArr(t, len(strings.Split(routeArr, ",")))

	amountOut := fuzz.Int64Range(10, 100_000_000_000_000).Draw(t, "amountOut").(int64)
	amountOutUint256 := u256.NewUintFromInt64(amountOut)

	return &exactOutSwapRouteParams{
		inputToken:       inputToken,
		outputToken:      outputToken,
		amountOut:        amountOutUint256.ToString(),
		amountIn:         "0",
		routeArr:         routeArr,
		quoteArr:         quoteArr,
		amountInMax:      u256.NewUintFromInt64(math.MaxInt64).ToString(),
		deadline:         time.Now().Add(time.Hour).Unix(),
		referrer:         "",
		isPreDrySwap:     false,
		preDrySwapResult: false,
	}
}

func NewRandomizedExactOutSwapRouteParams(t *fuzz.T) *exactOutSwapRouteParams {
	const maxRoutePathCount = 3
	const maxHops = 3

	inputToken, outputToken := generateTokenPair(t)
	routeArr := generateRoutePathArr(t, inputToken, outputToken, maxRoutePathCount, maxHops)
	quoteArr := generateRouteQuoteArr(t, len(strings.Split(routeArr, ",")))

	amountOutVal := fuzz.Uint256().Draw(t, "amountOut").(*uint256.Uint)
	amountOut := amountOutVal.ToString()
	amountInMaxVal := fuzz.Uint256().Draw(t, "amountInMax").(*uint256.Uint)
	amountInMax := amountInMaxVal.ToString()

	return &exactOutSwapRouteParams{
		inputToken:       inputToken,
		outputToken:      outputToken,
		amountOut:        amountOut,
		amountIn:         "0",
		routeArr:         routeArr,
		quoteArr:         quoteArr,
		amountInMax:      amountInMax,
		deadline:         time.Now().Add(time.Hour).Unix(),
		referrer:         "",
		isPreDrySwap:     false,
		preDrySwapResult: false,
	}
}
