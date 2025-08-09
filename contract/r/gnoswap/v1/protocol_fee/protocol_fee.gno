package protocol_fee

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"
)

// DistributeProtocolFee distributes collected protocol fees to devOps and gov/staker addresses.
// Only admin or gov/staker can execute this function.
func DistributeProtocolFee(cur realm) map[string]int64 {
	halt.AssertIsNotHaltedProtocolFee()

	caller := std.PreviousRealm().Address()
	assertIsAdminOrGovStaker(caller)

	sentToDevOpsForEvent := make([]string, 0)
	sentToGovStakerForEvent := make([]string, 0)
	toReturnDistributedToGovStaker := make(map[string]int64)

	for token, amount := range protocolFeeState.tokenListWithAmount {
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

		toDevOpsAmount := distributeAmount * protocolFeeState.DevOpsPct() / 10000 // default 0%
		toGovStakerAmount := distributeAmount - toDevOpsAmount                    // default 100%

		// Distribute to DevOps
		if err := protocolFeeState.distributeToDevOps(token, toDevOpsAmount); err != nil {
			panic(err)
		}
		if toDevOpsAmount > 0 {
			sentToDevOpsForEvent = append(sentToDevOpsForEvent, makeEventString(token, toDevOpsAmount))
		}

		// Distribute to Gov/Staker
		if err := protocolFeeState.distributeToGovStaker(token, toGovStakerAmount); err != nil {
			panic(err)
		}
		if toGovStakerAmount > 0 {
			sentToGovStakerForEvent = append(sentToGovStakerForEvent, makeEventString(token, toGovStakerAmount))
			toReturnDistributedToGovStaker[token] = toGovStakerAmount
		}
	}

	protocolFeeState.clearTokenListWithAmount()

	previousRealm := std.PreviousRealm()
	std.Emit(
		"TransferProtocolFee",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"toDevOps", strings.Join(sentToDevOpsForEvent, ","),
		"toGovStaker", strings.Join(sentToGovStakerForEvent, ","),
	)

	return toReturnDistributedToGovStaker
}

// SetDevOpsPct sets the devOpsPct.
// Only admin or governance contract can execute this function via proposal.
func SetDevOpsPct(cur realm, pct int64) {
	halt.AssertIsNotHaltedProtocolFee()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidPercent(pct)

	prevDevOpsPct := protocolFeeState.DevOpsPct()
	prevGovStakerPct := protocolFeeState.GovStakerPct()

	newDevOpsPct, err := protocolFeeState.setDevOpsPct(pct)
	if err != nil {
		panic(err)
	}
	newGovStakerPct := protocolFeeState.GovStakerPct()

	previousRealm := std.PreviousRealm()
	std.Emit(
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
// Only admin or governance contract can execute this function via proposal.
func SetGovStakerPct(cur realm, pct int64) {
	halt.AssertIsNotHaltedProtocolFee()

	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidPercent(pct)

	prevDevOpsPct := protocolFeeState.DevOpsPct()
	prevGovStakerPct := protocolFeeState.GovStakerPct()

	newGovStakerPct, err := protocolFeeState.setGovStakerPct(pct)
	if err != nil {
		panic(err)
	}
	newDevOpsPct := protocolFeeState.DevOpsPct()

	previousRealm := std.PreviousRealm()
	std.Emit(
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
// Only pool, router or staker can execute this function.
func AddToProtocolFee(cur realm, tokenPath string, amount int64) {
	halt.AssertIsNotHaltedProtocolFee()

	caller := std.PreviousRealm().Address()
	assertIsPoolOrRouterOrStaker(caller)

	if amount < 0 {
		panic(makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("amount(%d) should not be negative", amount),
		))
	}

	currentAmount := protocolFeeState.tokenListWithAmount[tokenPath]

	// Check for overflow
	if amount > 0 && currentAmount > 0 && currentAmount > (9223372036854775807-amount) {
		panic(makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("overflow detected: current(%d) + amount(%d) would exceed int64 max", currentAmount, amount),
		))
	}

	protocolFeeState.tokenListWithAmount[tokenPath] += amount
}

// ClearTokenListWithAmount clears the tokenListWithAmount.
// Only gov/staker can execute this function.
func ClearTokenListWithAmount(cur realm) {
	halt.AssertIsNotHaltedProtocolFee()

	caller := std.PreviousRealm().Address()
	access.AssertIsGovStaker(caller)

	protocolFeeState.clearTokenListWithAmount()
}

// ClearAccuTransferToGovStaker clears the accuToGovStaker.
// Only gov/staker can execute this function.
// Protocol_fee just sends the accumulated amount to gov/staker
// which means gov/staker doesn't know how much protocol_fee has been distributed from last time.
// Therefore, gov/staker calls GetAccuTransferToGovStaker to get the accumulated amount and clear it.
func ClearAccuTransferToGovStaker(cur realm) {
	halt.AssertIsNotHaltedProtocolFee()

	caller := std.PreviousRealm().Address()
	access.AssertIsGovStaker(caller)

	protocolFeeState.accuToGovStaker = avl.NewTree()
}

func makeEventString(tokenPath string, amount int64) string {
	return tokenPath + "*FEE*" + strconv.FormatInt(amount, 10)
}
