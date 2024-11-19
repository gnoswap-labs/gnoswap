package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/xgns"

	en "gno.land/r/gnoswap/v1/emission"
)

type lockedGNS struct {
	amount uint64
	unlock uint64
}

// ORIG TIME
// const TIMESTAMP_7_DAYS = uint64(604800) // 7 days in seconds
// QA TIME
const TIMESTAMP_7_DAYS = uint64(60)

var (
	addrLockedGns = make(map[std.Address][]lockedGNS)
	lockedAmount  = uint64(0)
)

var (
	minimumAmount = uint64(1_000_000)
)

// Delegate delegates GNS tokens to a specified address.
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#delegate
func Delegate(to std.Address, amount uint64) {
	if running {
		cleanDelegationStatHistory()
	}

	CollectReward() // common.IsHalted() + en.MintAndDistributeGns() + calculateReward()

	if !to.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("staker.gno__Delegate() || invalid address %s to delegate", to.String()),
		))
	}

	if amount < minimumAmount {
		panic(addDetailToError(
			errLessThanMinimum,
			ufmt.Sprintf("staker.gno__Delegate() || minimum amount to delegate is %d (requested:%d)", minimumAmount, amount),
		))
	}

	caller := std.PrevRealm().Addr()

	// GNS // caller -> GovStaker
	gns.TransferFrom(a2u(caller), a2u(std.CurrentRealm().Addr()), amount)

	// xGNS mint to caller
	xgns.Mint(a2u(caller), amount)

	// actual delegate
	delegate(to, amount)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"Delegate",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"to", to.String(),
		"amount", ufmt.Sprintf("%d", amount),
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
			ufmt.Sprintf("staker.gno__Redelegate() || invalid from address %s to redelegate", to.String()),
		))
	}

	if !to.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("staker.gno__Redelegate() || invalid to address %s to redelegate", to.String()),
		))
	}

	if amount < minimumAmount {
		panic(addDetailToError(
			errLessThanMinimum,
			ufmt.Sprintf("staker.gno__Redelegate() || minimum amount to redelegate is %d (requested:%d)", minimumAmount, amount),
		))
	}

	caller := std.PrevRealm().Addr()

	delegated := xgns.BalanceOf(a2u(caller))
	if delegated < amount {
		panic(addDetailToError(
			errNotEnoughBalance,
			ufmt.Sprintf("staker.gno__Redelegate() || not enough xGNS delegated(%d) to redelegate(%d)", delegated, amount),
		))
	}

	undelegate(from, amount)
	delegate(to, amount)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"Redelegate",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"from", from.String(),
		"to", to.String(),
		"amount", ufmt.Sprintf("%d", amount),
	)
}

// Undelegate undelegates xGNS from the existing delegate.
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#undelegate
func Undelegate(from std.Address, amount uint64) {
	if running {
		cleanDelegationStatHistory()
	}

	CollectReward() // common.IsHalted() + en.MintAndDistributeGns() + calculateReward()

	if !from.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("staker.gno__Undelegate() || invalid address %s to undelegate", from.String()),
		))
	}

	if amount < minimumAmount {
		panic(addDetailToError(
			errLessThanMinimum,
			ufmt.Sprintf("staker.gno__Undelegate() || minimum amount to undelegate is %d (requested:%d)", minimumAmount, amount),
		))
	}

	caller := std.PrevRealm().Addr()
	delegated := xgns.BalanceOf(a2u(caller))

	if delegated < amount {
		panic(addDetailToError(
			errNotEnoughBalance,
			ufmt.Sprintf("staker.gno__Undelegate() || not enough xGNS delegated(%d) to undelegate(%d)", delegated, amount),
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
	addrLockedGns[caller] = append(addrLockedGns[caller], userLocked)
	lockedAmount += amount

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"Undelegate",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"from", from.String(),
		"amount", ufmt.Sprintf("%d", amount),
	)
}

// CollectUndelegatedGns collects the amount of the undelegated GNS.
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#collectundelegatedgns
func CollectUndelegatedGns() uint64 {
	common.IsHalted()
	en.MintAndDistributeGns()

	calculateReward()

	caller := std.PrevRealm().Addr()

	if len(addrLockedGns[caller]) == 0 {
		return 0
	}

	prevAddr, prevRealm := getPrev()

	// check if caller has any GNS to claim
	collected := uint64(0)
	for i, locked := range addrLockedGns[caller] {
		if uint64(time.Now().Unix()) >= locked.unlock && locked.amount > 0 { // passed 7 days
			// transfer GNS to caller
			gns.Transfer(a2u(caller), locked.amount)

			std.Emit(
				"CollectUndelegatedGns",
				"prevAddr", prevAddr,
				"prevRealm", prevRealm,
				"internal_amount", ufmt.Sprintf("%d", locked.amount),
			)

			// remove from locked list
			addrLockedGns[caller] = append(addrLockedGns[caller][:i], addrLockedGns[caller][i+1:]...)

			lockedAmount -= locked.amount
			collected += locked.amount
		}
	}

	return collected
}

// CollectReward collects the rewards from the protocol fee contract based on the holdings of xGNS.
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#collectreward
func CollectReward() {
	common.IsHalted()
	en.MintAndDistributeGns()

	calculateReward()

	prevAddr, prevRealm := getPrev()

	// GNS EMISSION
	caller := std.PrevRealm().Addr()
	emissionReward := userEmissionReward[caller]
	if emissionReward > 0 {
		govStakerGnsBalance := gns.BalanceOf(a2u(consts.GOV_STAKER_ADDR))
		if govStakerGnsBalance < emissionReward {
			panic(addDetailToError(
				errNotEnoughBalance,
				ufmt.Sprintf("staker.gno__CollectReward() || not enough GNS(%d) in the realm to send emission reward(%d) for user %s", govStakerGnsBalance, emissionReward, caller.String()),
			))
		}

		// transfer GNS to caller
		gns.Transfer(a2u(caller), emissionReward)
		userEmissionReward[caller] = 0

		std.Emit(
			"CollectEmissionReward",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"internal_amount", ufmt.Sprintf("%d", emissionReward),
		)
	}

	// PROTOCOL FEE
	protocolFee, exist := userProtocolFeeReward[caller]
	if !exist || len(protocolFee) == 0 {
		return
	}

	for tokenPath, amount := range protocolFee {
		if amount == 0 {
			continue
		}

		// transfer token to caller
		// token.Transfer(a2u(caller), amount)
		transferByRegisterCall(tokenPath, caller, amount)
		userProtocolFeeReward[caller][tokenPath] = 0

		std.Emit(
			"CollectProtocolFeeReward",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"internal_tokenPath", tokenPath,
			"internal_amount", ufmt.Sprintf("%d", amount),
		)
	}
}

// CollectRewardFromLaunchPad collects the rewards from the protocol fee contract based on the holdings of xGNS in the launchpad contract.
// Only launchpad contract can call this function
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#collectrewardfromlaunchpad
func CollectRewardFromLaunchPad(to std.Address) {
	caller := std.PrevRealm().Addr()
	if caller != consts.LAUNCHPAD_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("staker.gno__CollectRewardFromLaunchPad() || only launchpad can call CollectRewardFromLaunchPad(), called from %s", caller.String()),
		))
	}

	common.IsHalted()
	en.MintAndDistributeGns()

	calculateReward()

	prevAddr, prevRealm := getPrev()

	// GNS EMISSION
	emissionReward := userEmissionReward[to]
	if emissionReward > 0 {
		govStakerGnsBalance := gns.BalanceOf(a2u(consts.GOV_STAKER_ADDR))
		if govStakerGnsBalance < emissionReward {
			panic(addDetailToError(
				errNotEnoughBalance,
				ufmt.Sprintf("staker.gno__CollectRewardFromLaunchPad() || not enough GNS(%d) in the realm to send emission reward(%d) for user %s", govStakerGnsBalance, emissionReward, to.String()),
			))
		}

		// transfer GNS to `to``
		gns.Transfer(a2u(to), emissionReward)
		userEmissionReward[to] = 0

		std.Emit(
			"CollectEmissionFromLaunchPad",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"to", to.String(),
			"internal_amount", ufmt.Sprintf("%d", emissionReward),
		)
	}

	// PROTOCOL FEE
	protocolFee, exist := userProtocolFeeReward[to]
	if !exist || len(protocolFee) == 0 {
		return
	}

	for tokenPath, amount := range protocolFee {
		if amount == 0 {
			continue
		}

		// transfer token to to
		// token.Transfer(a2u(to), amount)
		transferByRegisterCall(tokenPath, to, amount)
		userProtocolFeeReward[to][tokenPath] = 0

		prevAddr, prevRealm := getPrev()
		std.Emit(
			"CollectProtocolFeeFromLaunchPad",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"to", to.String(),
			"internal_tokenPath", tokenPath,
			"internal_amount", ufmt.Sprintf("%d", amount),
		)
	}
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}
