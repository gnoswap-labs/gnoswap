package router

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"
)

var errMsg string

const (
    unknown                          errMsg = "An unknown error has occurred."
    quoteSumMustBe100                errMsg = "The sum of the quotes must be 100."
    quotesAndRoutesLengthNotMatch    errMsg = "The length of quotes and routes do not match."
    numHopsMustInRange               errMsg = "The number of hops should be within the range of 1 to 3."
    amountNotBeZero                  errMsg = "The specified amount should not be zero." 
)

type errorType struct {
	router 	RouterKind
	msg   	errMsg
}

func (e *errorType) Error() string {
	return ufmt.Sprintf("%s || %s", e.router, e.msg)
}

func errorf(kind routerKind, msg errMsg) error {
	return &errorType{
		router: kind,
		msg:    msg,
	}
}

func DrySwapRoute(
	inputToken string,
	outputToken string,
	amountSpecified bigint,
	swapType SwapType,
	routeListStr string, // []string
	quoteListStr string, // []int
) bigint {
	var routerKind RouterKind = DrySwap

	if amountSpecified == 0 {
		panic(errorf(routerKind, amountNotBeZero))
	}

	amountSpecified, err := setAmountSepcified(routerKind, amountSpecified, swapType)
	if err != nil {
		panic(err)
	}

	routes := strings.Split(routeListStr, ",")
	if !(1 <= len(routes) && len(routes) <= 7) {
		panic(ufmt.Sprintf("%s || %s. got %d", routerKind, routesLengthNotInRange, len(routes)))
	}

	isValidQuoteSum, err := validateQuoteSum(routerKind, quoteListStr)
	if err != nil {
		panic(err)
	}

	if !isValidQuoteSum {
		panic(errorf(routerKind, quoteSumMustBe100))
	}

	resultAmount, err := calculateAmount(routerKind, routes, swapType)
	if err != nil {
		panic(err)
	}

	return resultAmount
}

func SwapRoute(
	inputToken string,
	outputToken string,
	amountSpecified bigint,
	swapType SwapType,
	routeListStr string, // []string
	quoteListStr string, // []int
	tokenAmountLimit bigint,
) bigint {
	var routerKind RouterKind = Swap

	if amountSpecified == 0 {
		panic(errorf(routerKind, amountNotBeZero))
	}

	amountSpecified, err := setAmountSepcified(routerKind, amountSpecified, swapType)
	if err != nil {
		panic(err)
	}

	routes := strings.Split(routeListStr, ",")
	if !(1 <= len(routes) && len(routes) <= 7) {
		panic(ufmt.Sprintf("%s || %s. got %d", routerKind, routesLengthNotInRange, len(routes)))
	}

	isValidQuoteSum, err := validateQuoteSum(routerKind, quoteListStr)
	if err != nil {
		panic(err)
	}

	if !isValidQuoteSum {
		panic(errorf(routerKind, quoteSumMustBe100))
	}

	resultAmount, err := calculateAmount(routerKind, routes, swapType)
	if err != nil {
		panic(err)
	}

	return validateAmount(swapType, tokenAmountLimit, resultAmount, routerKind)
}

func setAmountSepcified(
	kind routerKind,
	amount bigint,
	swapType SwapType
) (bigInt, error) {
	swtich swapType {
	case ExactIn:
		return amount
	case ExactOut:
		return -amount
	default:
		return errorf(kind, unknown)
	}

	return amount, nil
}

func validateQuoteSum(kind RouterKind, quoteListStr string) (bool, error) {
	quoteSum := 0

	quotes := strings.Split(quoteListStr, ",") // []string
	if len(quotes) != len(routes) {
		return errorf(kind, quotesAndRoutesLengthNotMatch)
	}

	return checkQuoteSum(kind, quotes)
}

func checkQuoteSum(kind RouterKind, quotes []string) bool {
	quoteSum := 0

	for _, quote := range quotes {
		intQuote, _ := strconv.Atoi(quote)
		quoteSum += intQuote
	}

	return quoteSum == 100
}

func calculateAmount(kind RouterKind, routes string, swapTyp SwapType) (bigInt, error) {
	result := bigInt(0)

	for i, route := range routes {
		hops := strings.Count(route, "*POOL*") + 1
		quote, _ := strconv.Atoi(quotes[i])

		if hops > 3 {
			return errorf(kind, numHopsMustInRange)
		}

		toSwap := amountSpecified / bigInt(100) * bigInt(quote)

		if hops == 1 {
			result += handleSingleSwap(route, toSwap, true)
		} else {
			result += handleMultiSwap(swapTyp, route, hops, toSwap, true)
		}
	}

	return result, nil
}

func validateAmount(swapType SwapType, tokenAmountLimit, resultAmount int, routerKind RouterKind) int {
    if swapType == ExactIn {
        require(
            tokenAmountLimit <= resultAmount, 
            ufmt.Sprintf(
                "%s || Received fewer outputs than expected (expected minimum outputs: %d, got: %d)",
                routerKind,
                tokenAmountLimit, 
                resultAmount
            ),
        )
    } else { // EXACT_OUT
        require(
            resultAmount <= tokenAmountLimit, 
            ufmt.Sprintf(
                "%s || Input exceeded the expected maximum (expected maximum input: %d, got: %d)",
                routerKind,
                tokenAmountLimit, 
                resultAmount
            )
        )
    }

    return resultAmount
}

func handleSingleSwap(route string, amountSpecified bigint, isDry bool) bigint {
	input, output, fee := getDataForSinglePath(route)
	singleParams := SingleSwapParams{
		tokenIn:         input,
		tokenOut:        output,
		fee:             fee,
		amountSpecified: amountSpecified,
	}

	if isDry {
		return singleSwapDry(singleParams)
	}

	return singleSwap(singleParams)
}

func handleMultiSwap(
	swapType SwapType,
	route string,
	numHops int,
	amountSpecified bigint,
	isDry bool
) bigint {
	switch swapType {
	case ExactIn:
		input, output, fee := getDataForMultiPath(route, 0) // first data
		swapParams := SwapParams{
			tokenIn:         input,
			tokenOut:        output,
			fee:             fee,
			recipient:       std.GetOrigCaller(),
			amountSpecified: amountSpecified,
		}

		if isDry {
			return multiSwapDry(swapParams, 0, numHops, route) // iterate here
		}
		return multiSwap(swapParams, 0, numHops, route) // iterate here

	case ExactOut:
		input, output, fee := getDataForMultiPath(route, numHops-1) // last data
		swapParams := SwapParams{
			tokenIn:         input,
			tokenOut:        output,
			fee:             fee,
			recipient:       std.GetOrigCaller(),
			amountSpecified: amountSpecified,
		}

		if isDry {
			return multiSwapNegativeDry(swapParams, numHops-1, route) // iterate here
		}
		return multiSwapNegative(swapParams, numHops-1, route) // iterate here

	default:
		return errorf(multiSwap, unknown)
	}
}
