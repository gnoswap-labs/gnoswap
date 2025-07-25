package protocol_fee

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/halt"
)

// DistributeProtocolFee distributes the protocol fee to devOps and gov/staker.
// only `gov/staker` can execute this function.
// It returns list of token with amount has been sent to gov/staker.
func DistributeProtocolFee(cur realm) map[string]uint64 {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedProtocolFee()
	halt.AssertIsNotHaltedWithdraw()
	access.AssertIsGovStaker(caller)

	sentToDevOpsForEvent := make([]string, 0)
	sentToGovStakerForEvent := make([]string, 0)
	toReturnDistributedToGovStaker := make(map[string]uint64)

	for token, amount := range protocolFeeState.TokenListWithAmount {
		balance := uint64(common.BalanceOf(token, protocolFeeAddr))

		// anyone can just send certain grc20 token to `protocol_fee` contract
		// therefore, we don't need any guard logic to check whether protocol_fee's xxx token balance is equal to `amount`
		// however, amount always should be less than or equal to balance
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

		toDevOpsAmount := distributeAmount * protocolFeeState.DevOpsPct / 10000 // default 0%
		toGovStakerAmount := distributeAmount - toDevOpsAmount                  // default 100%

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

func GetDevOpsPct() uint64 {
	return protocolFeeState.DevOpsPct
}

// SetDevOpsPctByAdmin sets the devOpsPct.
func SetDevOpsPctByAdmin(cur realm, pct uint64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedProtocolFee()
	access.AssertIsAdmin(caller)

	prevPct, newPct, err := protocolFeeState.setDevOpsPct(pct)
	if err != nil {
		panic(err)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetDevOpsPct",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"newPct", strconv.FormatUint(newPct, 10),
		"prevPct", strconv.FormatUint(prevPct, 10),
	)
}

// SetDevOpsPct sets the devOpsPct.
// Only governance contract can execute this function via proposal
func SetDevOpsPct(cur realm, pct uint64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedProtocolFee()
	access.AssertIsGovernance(caller)

	prevPct, newPct, err := protocolFeeState.setDevOpsPct(pct)
	if err != nil {
		panic(err)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"SetDevOpsPct",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"newPct", strconv.FormatUint(newPct, 10),
		"prevPct", strconv.FormatUint(prevPct, 10),
	)
}

// AddToProtocolFee adds the amount to the tokenListWithAmount
// Only `pool + router + staker` can execute this function.
func AddToProtocolFee(cur realm, tokenPath string, amount uint64) {
	halt.AssertIsNotHaltedProtocolFee()
	assertCallerHasAddProtocolFeePermission()

	protocolFeeState.TokenListWithAmount[tokenPath] += amount
}

// ClearTokenListWithAmount clears the tokenListWithAmount.
// only `gov/staker` can execute this function.
func ClearTokenListWithAmount(cur realm) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedProtocolFee()
	access.AssertIsGovStaker(caller)

	protocolFeeState.clearTokenListWithAmount()
}

// ClearAccuTransferToGovStaker clears the accuToGovStaker.
// Only gov/staker can execute this function.
// protocol_fee just sends the accumulated amount to gov/staker
// which means gov/staker doesn't known how much protocol_fee has been distributed from last time
// Therefore, gov/staker calls GetAccuTransferToGovStaker to get the accumulated amount and clear it
func ClearAccuTransferToGovStaker(cur realm) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedProtocolFee()
	access.AssertIsGovStaker(caller)

	protocolFeeState.AccuToGovStaker = avl.NewTree()
}

func makeEventString(tokenPath string, amount uint64) string {
	return tokenPath + "*FEE*" + strconv.FormatUint(amount, 10)
}
