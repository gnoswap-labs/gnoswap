package v1

import (
	"chain"
	"chain/runtime"
	"strconv"
	"strings"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/router"
)

// DistributeProtocolFee distributes collected protocol fees.
//
// Splits fees between devOps and gov/staker based on configured percentages.
// This function processes all accumulated fees since last distribution.
//
// Returns:
//   - map[string]int64: Token paths to amounts distributed to gov/staker
//
// Only callable by admin or gov/staker contract.
// Note: Default split is 0% devOps, 100% gov/staker.
func (pf *protocolFeeV1) DistributeProtocolFee() map[string]int64 {
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	assertIsAdminOrGovStaker(caller)

	sentToDevOpsForEvent := make([]string, 0)
	sentToGovStakerForEvent := make([]string, 0)
	toReturnDistributedToGovStaker := make(map[string]int64)

	for token, amount := range pf.store.GetTokenListWithAmounts() {
		balance := common.BalanceOf(token, protocolFeeAddr)

		// amount should be less than or equal to balance
		if amount > balance {
			panic(makeErrorWithDetail(
				errInvalidAmount,
				ufmt.Sprintf("amount: %d should be less than or equal to balance: %d", amount, balance),
			))
		}

		if amount <= 0 {
			continue
		}

		// Distribute only the recorded amount, not the entire balance
		distributeAmount := amount
		if distributeAmount > balance {
			// This should not happen due to the check above, but safeguard anyway
			distributeAmount = balance
		}

		devOpsPct := pf.getProtocolFeeState().DevOpsPct()
		toDevOpsAmount := safeMulDiv(distributeAmount, devOpsPct, 10000)    // default 0%
		toGovStakerAmount := safeSubInt64(distributeAmount, toDevOpsAmount) // default 100%

		// Distribute to DevOps
		if err := pf.getProtocolFeeState().distributeToDevOps(token, toDevOpsAmount); err != nil {
			panic(err)
		}
		if toDevOpsAmount > 0 {
			sentToDevOpsForEvent = append(sentToDevOpsForEvent, makeEventString(token, toDevOpsAmount))
		}

		// Distribute to Gov/Staker
		if err := pf.getProtocolFeeState().distributeToGovStaker(token, toGovStakerAmount); err != nil {
			panic(err)
		}
		if toGovStakerAmount > 0 {
			sentToGovStakerForEvent = append(sentToGovStakerForEvent, makeEventString(token, toGovStakerAmount))
			toReturnDistributedToGovStaker[token] = toGovStakerAmount
		}
	}

	if err := pf.getProtocolFeeState().clearTokenListWithAmount(); err != nil {
		panic(err)
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"TransferProtocolFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"toDevOps", strings.Join(sentToDevOpsForEvent, ","),
		"toGovStaker", strings.Join(sentToGovStakerForEvent, ","),
	)

	return toReturnDistributedToGovStaker
}

// SetDevOpsPct sets the devOpsPct.
//
// Parameters:
//   - pct: percentage for devOps (0-10000, where 10000 = 100%)
//
// Only callable by admin or governance.
// Note: GovStaker percentage is automatically adjusted to (10000 - devOpsPct).
func (pf *protocolFeeV1) SetDevOpsPct(pct int64) {
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidPercent(pct)

	prevDevOpsPct := pf.getProtocolFeeState().DevOpsPct()
	prevGovStakerPct := pf.getProtocolFeeState().GovStakerPct()

	newDevOpsPct, err := pf.getProtocolFeeState().setDevOpsPct(pct)
	if err != nil {
		panic(err)
	}
	newGovStakerPct := pf.getProtocolFeeState().GovStakerPct()

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"SetDevOpsPct",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"newDevOpsPct", strconv.FormatInt(newDevOpsPct, 10),
		"prevDevOpsPct", strconv.FormatInt(prevDevOpsPct, 10),
		"newGovStakerPct", strconv.FormatInt(newGovStakerPct, 10),
		"prevGovStakerPct", strconv.FormatInt(prevGovStakerPct, 10),
	)
}

// SetGovStakerPct sets the stakerPct.
//
// Parameters:
//   - pct: percentage for gov/staker (0-10000, where 10000 = 100%)
//
// Only callable by admin or governance.
// Note: DevOps percentage is automatically adjusted to (10000 - govStakerPct).
func (pf *protocolFeeV1) SetGovStakerPct(pct int64) {
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidPercent(pct)

	prevDevOpsPct := pf.getProtocolFeeState().DevOpsPct()
	prevGovStakerPct := pf.getProtocolFeeState().GovStakerPct()

	newGovStakerPct, err := pf.getProtocolFeeState().setGovStakerPct(pct)
	if err != nil {
		panic(err)
	}
	newDevOpsPct := pf.getProtocolFeeState().DevOpsPct()

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"SetGovStakerPct",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"newDevOpsPct", strconv.FormatInt(newDevOpsPct, 10),
		"prevDevOpsPct", strconv.FormatInt(prevDevOpsPct, 10),
		"newGovStakerPct", strconv.FormatInt(newGovStakerPct, 10),
		"prevGovStakerPct", strconv.FormatInt(prevGovStakerPct, 10),
	)
}

// AddToProtocolFee adds the amount to the tokenListWithAmount.
//
// Parameters:
//   - tokenPath: token contract path
//   - amount: fee amount to add
//
// Only callable by pool, router or staker contracts.
// Note: Accumulated fees are distributed when DistributeProtocolFee is called.
func (pf *protocolFeeV1) AddToProtocolFee(tokenPath string, amount int64) {
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	assertIsPoolOrPositionOrRouterOrStaker(caller)

	if amount < 0 {
		panic(makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("amount(%d) should not be negative", amount),
		))
	}

	currentAmount, exists := pf.store.GetTokenListWithAmountItem(tokenPath)
	if !exists {
		currentAmount = 0
	}

	// Check for overflow
	addedAmount := safeAddInt64(currentAmount, amount)

	pf.store.SetTokenListWithAmountItem(tokenPath, addedAmount)
}

// SetDustClaimMinAmount sets the minimum amount eligible for dust claim.
//
// Only callable by admin or governance.
func (pf *protocolFeeV1) SetDustClaimMinAmount(amount int64) {
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	currentMax := pf.getProtocolFeeState().DustClaimMaxAmount("")
	if amount > currentMax {
		panic(makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("min(%d) should be less than or equal to max(%d)", amount, currentMax),
		))
	}

	if _, err := pf.getProtocolFeeState().setDustClaimMinAmount(amount); err != nil {
		panic(err)
	}
}

// SetDustClaimMaxAmount sets the maximum amount eligible for dust claim.
//
// Only callable by admin or governance.
func (pf *protocolFeeV1) SetDustClaimMaxAmount(amount int64) {
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	currentMin := pf.getProtocolFeeState().DustClaimMinAmount("")
	if amount < currentMin {
		panic(makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("max(%d) should be greater than or equal to min(%d)", amount, currentMin),
		))
	}

	if _, err := pf.getProtocolFeeState().setDustClaimMaxAmount(amount); err != nil {
		panic(err)
	}
}

// ClaimDustToGns swaps eligible dust tokens into GNS and transfers the total GNS to recipient.
//
// Parameters:
//   - tokenPaths: list of input token paths
//   - amounts: list of amounts to swap per token
//   - routeArrs: route strings per token (router format)
//   - quoteArrs: quote strings per token (router format; empty defaults to "100")
//   - amountOutMins: minimum output per token (empty defaults to "1")
//   - deadline: swap deadline
//   - referrer: referrer address string (router)
//   - recipient: address to receive total GNS
//
// Only callable by admin or gov/staker.
func (pf *protocolFeeV1) ClaimDustToGns(
	tokenPaths []string,
	amounts []int64,
	routeArrs []string,
	quoteArrs []string,
	amountOutMins []string,
	deadline int64,
	referrer string,
	recipient address,
) int64 {
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	assertIsAdminOrGovStaker(caller)

	if len(tokenPaths) != len(amounts) || len(tokenPaths) != len(routeArrs) || len(tokenPaths) != len(quoteArrs) || len(tokenPaths) != len(amountOutMins) {
		panic(makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("length mismatch: tokens(%d), amounts(%d), routes(%d), quotes(%d), mins(%d)", len(tokenPaths), len(amounts), len(routeArrs), len(quoteArrs), len(amountOutMins)),
		))
	}

	totalGnsOut := int64(0)
	processedForEvent := make([]string, 0)

	for i, tokenPath := range tokenPaths {
		amount := amounts[i]
		if amount <= 0 {
			continue
		}

		minAmount := pf.getProtocolFeeState().DustClaimMinAmount(tokenPath)
		maxAmount := pf.getProtocolFeeState().DustClaimMaxAmount(tokenPath)
		if amount < minAmount || amount > maxAmount {
			continue
		}

		recordedAmount, exists := pf.store.GetTokenListWithAmountItem(tokenPath)
		if !exists {
			continue
		}

		if amount > recordedAmount {
			panic(makeErrorWithDetail(
				errInvalidAmount,
				ufmt.Sprintf("amount(%d) should be less than or equal to recorded(%d)", amount, recordedAmount),
			))
		}

		balance := common.BalanceOf(tokenPath, protocolFeeAddr)
		if amount > balance {
			panic(makeErrorWithDetail(
				errInvalidAmount,
				ufmt.Sprintf("amount(%d) should be less than or equal to balance(%d)", amount, balance),
			))
		}

		if tokenPath == gnsTokenPath {
			totalGnsOut = safeAddInt64(totalGnsOut, amount)
			newAmount := safeSubInt64(recordedAmount, amount)
			pf.store.SetTokenListWithAmountItem(tokenPath, newAmount)
			processedForEvent = append(processedForEvent, makeDustClaimEventString(tokenPath, amount))
			continue
		}

		routeArr := routeArrs[i]
		if routeArr == "" {
			panic(makeErrorWithDetail(
				errInvalidAmount,
				ufmt.Sprintf("routeArr should not be empty for token(%s)", tokenPath),
			))
		}

		quoteArr := quoteArrs[i]
		if quoteArr == "" {
			quoteArr = "100"
		}

		amountOutMin := amountOutMins[i]
		if amountOutMin == "" {
			amountOutMin = "1"
		}

		_, outputAmountStr := router.ExactInSwapRoute(
			cross,
			tokenPath,
			gnsTokenPath,
			strconv.FormatInt(amount, 10),
			routeArr,
			quoteArr,
			amountOutMin,
			deadline,
			referrer,
		)

		outputAmount, err := strconv.ParseInt(outputAmountStr, 10, 64)
		if err != nil {
			panic(err)
		}

		if outputAmount < 0 {
			outputAmount = -outputAmount
		}

		totalGnsOut = safeAddInt64(totalGnsOut, outputAmount)
		newAmount := safeSubInt64(recordedAmount, amount)
		pf.store.SetTokenListWithAmountItem(tokenPath, newAmount)
		processedForEvent = append(processedForEvent, makeDustClaimEventString(tokenPath, amount))
	}

	if totalGnsOut > 0 {
		common.SafeGRC20Transfer(cross, gnsTokenPath, recipient, totalGnsOut)
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"ClaimDustToGns",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"recipient", recipient.String(),
		"totalGnsOut", strconv.FormatInt(totalGnsOut, 10),
		"processed", strings.Join(processedForEvent, ","),
	)

	return totalGnsOut
}

// ClearTokenListWithAmount clears the tokenListWithAmount.
//
// Resets all accumulated token amounts to zero.
// Only callable by gov/staker contract.
// Note: Should be called after successful distribution.
func (pf *protocolFeeV1) ClearTokenListWithAmount() {
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsGovStaker(caller)

	if err := pf.getProtocolFeeState().clearTokenListWithAmount(); err != nil {
		panic(err)
	}
}

// ClearAccuTransferToGovStaker clears the accuToGovStaker.
//
// Resets accumulated transfer tracking for gov/staker.
// This allows gov/staker to track distributions between calls.
//
// Only callable by gov/staker contract.
// Note: Should be called after reading accumulated amounts.
func (pf *protocolFeeV1) ClearAccuTransferToGovStaker() {
	halt.AssertIsNotHaltedProtocolFee()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsGovStaker(caller)

	pf.store.InitializeAccuToGovStaker()
}

func makeEventString(tokenPath string, amount int64) string {
	return tokenPath + "*FEE*" + strconv.FormatInt(amount, 10)
}

func makeDustClaimEventString(tokenPath string, amount int64) string {
	return tokenPath + "*DUST*" + strconv.FormatInt(amount, 10)
}
