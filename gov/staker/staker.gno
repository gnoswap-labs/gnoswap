package staker

import (
	"std"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/wugnot"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/xgns"

	en "gno.land/r/gnoswap/v1/emission"
)

type lockedGNS struct {
	amount    uint64
	unlock    uint64
	collected bool // TODO:
}

const TIMESTAMP_7_DAYS = uint64(604800) // 7 days in seconds

var (
	addrLockedGns = avl.NewTree() // address -> []lockedGNS
	lockedAmount  = uint64(0)
)

var (
	minimumAmount = uint64(1_000_000)
)

// Delegate delegates GNS tokens to a specified address.
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#delegate
func Delegate(to std.Address, amount uint64) {
	if running {
		cleanDelegationStatHistory() // 함수명 변경
	}

	CollectReward()

	if !to.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("invalid address %s to delegate", to.String()),
		))
	}

	if amount < minimumAmount {
		panic(addDetailToError(
			errLessThanMinimum,
			ufmt.Sprintf("minimum amount to delegate is %d (requested:%d)", minimumAmount, amount),
		))
	}

	caller := std.PrevRealm().Addr()

	// GNS // caller -> GovStaker
	gns.TransferFrom(a2u(caller), a2u(std.CurrentRealm().Addr()), amount)

	// xGNS mint to caller
	xgns.Mint(a2u(caller), amount)

	// actual delegate
	delegate(to, amount)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"Delegate",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"from", caller.String(),
		"to", to.String(),
		"amount", formatUint(amount),
	)
}

// Redelegate redelegates xGNS from existing delegate to another.
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#redelegate
func Redelegate(from, to std.Address, amount uint64) {
	if running {
		cleanDelegationStatHistory()
	}

	CollectReward()

	if !from.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("invalid from address %s to redelegate", to.String()),
		))
	}

	if !to.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("invalid to address %s to redelegate", to.String()),
		))
	}

	if amount < minimumAmount {
		panic(addDetailToError(
			errLessThanMinimum,
			ufmt.Sprintf("minimum amount to redelegate is %d (requested:%d)", minimumAmount, amount),
		))
	}

	caller := std.PrevRealm().Addr()

	delegated := xgns.BalanceOf(a2u(caller))
	if delegated < amount {
		panic(addDetailToError(
			errNotEnoughBalance,
			ufmt.Sprintf("not enough xGNS delegated(%d) to redelegate(%d)", delegated, amount),
		))
	}

	undelegate(from, amount)
	delegate(to, amount)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"Redelegate",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"from", from.String(),
		"to", to.String(),
		"amount", formatUint(amount),
	)
}

// Undelegate undelegates xGNS from the existing delegate.
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#undelegate
func Undelegate(from std.Address, amount uint64) {
	if running {
		cleanDelegationStatHistory()
	}

	CollectReward()

	if !from.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("invalid address %s to undelegate", from.String()),
		))
	}

	if amount < minimumAmount {
		panic(addDetailToError(
			errLessThanMinimum,
			ufmt.Sprintf("minimum amount to undelegate is %d (requested:%d)", minimumAmount, amount),
		))
	}

	caller := std.PrevRealm().Addr()
	delegated := xgns.BalanceOf(a2u(caller))

	if delegated < amount {
		panic(addDetailToError(
			errNotEnoughBalance,
			ufmt.Sprintf("not enough xGNS delegated(%d) to undelegate(%d)", delegated, amount),
		))
	}

	// burn equivalent amount of xGNS
	xgns.Burn(a2u(caller), amount)

	// actual undelegate
	undelegate(from, amount)

	// lock up
	userLocked := lockedGNS{
		amount: amount,
		unlock: uint64(time.Now().Unix()) + TIMESTAMP_7_DAYS, // after 7 days, call Collect() to receive GNS
	}

	var lockedList []lockedGNS
	if value, exists := addrLockedGns.Get(caller.String()); exists {
		lockedList = value.([]lockedGNS)
	}

	lockedList = append(lockedList, userLocked)
	addrLockedGns.Set(caller.String(), lockedList)
	lockedAmount += amount

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"Undelegate",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"from", from.String(),
		"amount", formatUint(amount),
	)
}

// CollectUndelegatedGns collects the amount of the undelegated GNS.
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#collectundelegatedgns
func CollectUndelegatedGns() uint64 {
	common.IsHalted()
	en.MintAndDistributeGns()
	calculateReward()

	caller := std.PrevRealm().Addr()

	value, exists := addrLockedGns.Get(caller.String())
	if !exists {
		return 0
	}

	lockedList := value.([]lockedGNS)
	if len(lockedList) == 0 {
		return 0
	}

	prevAddr, prevPkgPath := getPrev()
	collected := uint64(0)
	currentTime := uint64(time.Now().Unix())

	newLockedList := make([]lockedGNS, 0)
	for _, locked := range lockedList {
		if currentTime >= locked.unlock { // passed 7 days
			// transfer GNS to caller
			gns.Transfer(a2u(caller), locked.amount)
			lockedAmount -= locked.amount
			collected += locked.amount
		} else {
			newLockedList = append(newLockedList, locked)
		}
	}

	if len(newLockedList) > 0 {
		addrLockedGns.Set(caller.String(), newLockedList)
	} else {
		_, removed := addrLockedGns.Remove(caller.String())
		if !removed {
			panic("failed to remove locked GNS list")
		}
	}

	if collected > 0 {
		std.Emit(
			"CollectUndelegatedGns",
			"prevAddr", prevAddr,
			"prevRealm", prevPkgPath,
			"from", consts.GOV_STAKER_ADDR.String(),
			"to", caller.String(),
			"collectedAmount", formatUint(collected),
		)
	}

	return collected
}

// CollectReward collects the rewards from the protocol fee contract based on the holdings of xGNS.
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#collectreward
func CollectReward() {
	common.IsHalted()
	en.MintAndDistributeGns()

	calculateReward()

	prevAddr, prevPkgPath := getPrev()
	caller := std.PrevRealm().Addr()

	// TODO:
	emissionReward := collectEmissionReward(caller)
	if emissionReward > 0 {
		std.Emit(
			"CollectEmissionReward",
			"prevAddr", prevAddr,
			"prevRealm", prevPkgPath,
			"to", caller.String(),
			"emissionRewardAmount", formatUint(emissionReward),
		)
	}

	// TODO::
	collectedFees := collectProtocolFeeReward(caller)
	for tokenPath, amount := range collectedFees {
		if tokenPath == consts.WUGNOT_PATH {
			tokenPath = "ugnot"
		}
		std.Emit(
			"CollectProtocolFeeReward",
			"prevAddr", prevAddr,
			"prevRealm", prevPkgPath,
			"tokenPath", tokenPath,
			"collectedAmount", formatUint(amount),
		)
	}
}

// CollectRewardFromLaunchPad collects the rewards from the protocol fee contract based on the holdings of xGNS in the launchpad contract.
// Only launchpad contract can call this function
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#collectrewardfromlaunchpad
func CollectRewardFromLaunchPad(to std.Address) {
	assertCallerIsLaunchpad()

	common.IsHalted()
	en.MintAndDistributeGns()

	calculateReward()

	prevAddr, prevPkgPath := getPrev()

	// TODO::
	emissionReward := collectEmissionReward(to)
	if emissionReward > 0 {
		std.Emit(
			"CollectEmissionFromLaunchPad",
			"prevAddr", prevAddr,
			"prevRealm", prevPkgPath,
			"to", to.String(),
			"internal_amount", formatUint(emissionReward),
		)
	}

	// TODO::
	collectedFees := collectProtocolFeeReward(to)
	for tokenPath, amount := range collectedFees {
		std.Emit(
			"CollectProtocolFeeFromLaunchPad",
			"prevAddr", prevAddr,
			"prevRealm", prevPkgPath,
			"internal_tokenPath", tokenPath,
			"internal_amount", formatUint(amount),
		)
	}
}

func collectEmissionReward(addr std.Address) uint64 {
	emissionReward := uint64(0)
	if value, exists := userEmissionReward.Get(addr.String()); exists {
		emissionReward = value.(uint64)
	}

	if emissionReward <= 0 {
		return 0
	}

	govStakerGnsBalance := gns.BalanceOf(a2u(consts.GOV_STAKER_ADDR))
	if govStakerGnsBalance < emissionReward {
		panic(addDetailToError(
			errNotEnoughBalance,
			ufmt.Sprintf("not enough GNS(%d) in the realm to send emission reward(%d) for user %s", govStakerGnsBalance, emissionReward, addr.String()),
		))
	}

	// transfer GNS to addr
	gns.Transfer(a2u(addr), emissionReward)
	userEmissionReward.Set(addr.String(), uint64(0))

	return emissionReward
}

func collectProtocolFeeReward(addr std.Address) map[string]uint64 {
	collectedFees := make(map[string]uint64)

	value, exists := userProtocolFeeReward.Get(addr.String())
	if !exists {
		return collectedFees
	}

	userFees := value.(*avl.Tree)
	if userFees.Size() == 0 {
		return collectedFees
	}

	userFees.Iterate("", "", func(tokenPath string, value interface{}) bool {
		amount := value.(uint64)
		if amount == 0 {
			return false
		}

		if tokenPath == consts.WUGNOT_PATH {
			if amount > 0 {
				wugnot.Withdraw(amount)
				banker := std.GetBanker(std.BankerTypeRealmSend)
				banker.SendCoins(consts.GOV_STAKER_ADDR, addr, std.Coins{{"ugnot", int64(amount)}})
			}
		} else {
			transferProtocolFee(tokenPath, addr, amount)
		}

		userFees.Set(tokenPath, uint64(0))
		collectedFees[tokenPath] = amount
		return false
	})

	return collectedFees
}

func transferProtocolFee(tokenPath string, to std.Address, amount uint64) {
	common.MustRegistered(tokenPath)
	if to.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("invalid address %s to transfer protocol fee", to.String()),
		))
	}
	if amount <= 0 {
		panic(addDetailToError(
			errInvalidAmount,
			ufmt.Sprintf("invalid amount %d to transfer protocol fee", amount),
		))
	}

	token := common.GetTokenTeller(tokenPath)
	checkTransferError(token.Transfer(to, amount))
}
