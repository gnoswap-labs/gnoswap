package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"
	"gno.land/r/gnoswap/v2/gov/xgns"

	en "gno.land/r/gnoswap/v2/emission"
)

type lockedGNS struct {
	amount uint64
	unlock uint64
}

var lockedAmount uint64

const TIMESTAMP_7_DAYS = uint64(60) // 60s // XXX: TODO, REMOVE AFTER QA
// const TIMESTAMP_7_DAYS = uint64(604800) // 7 days in seconds

var (
	addrLockedGns = make(map[std.Address][]lockedGNS)
)

var (
	minimumAmount = uint64(1_000_000)
)

func Delegate(to std.Address, amount uint64) {
	en.MintAndDistributeGns()
	calculateReward()

	if !to.IsValid() {
		panic(ufmt.Sprintf("invalid address %s to Delegate", to.String()))
	}

	if amount < minimumAmount {
		panic(ufmt.Sprintf("minimum amount to delegate is %d (requested:%d)", minimumAmount, amount))
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

// xGNS from -> xGNS to
func Redelegate(from, to std.Address, amount uint64) {
	CollectReward() // en.MintAndDistributeGns() + calculateReward()

	if !from.IsValid() {
		panic(ufmt.Sprintf("invalid from address %s to Redelegate", to.String()))
	}

	if !to.IsValid() {
		panic(ufmt.Sprintf("invalid to address %s to Redelegate", to.String()))
	}

	if amount < minimumAmount {
		panic(ufmt.Sprintf("minimum amount to re-delegate is %d (requested:%d)", minimumAmount, amount))
	}

	caller := std.PrevRealm().Addr()

	if xgns.BalanceOf(a2u(caller)) < amount {
		panic("not enough xGNS staked")
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

func Undelegate(from std.Address, amount uint64) {
	CollectReward()

	if !from.IsValid() {
		panic(ufmt.Sprintf("invalid address %s to Undelegate", from.String()))
	}

	if amount < minimumAmount {
		panic(ufmt.Sprintf("minimum amount to undelegate is %d (requested:%d)", minimumAmount, amount))
	}

	caller := std.PrevRealm().Addr()

	if xgns.BalanceOf(a2u(caller)) < amount {
		panic("not enough xGNS staked")
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

func CollectUndelegated() uint64 {
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

func CollectReward() {
	en.MintAndDistributeGns()
	calculateReward()

	prevAddr, prevRealm := getPrev()

	// GNS EMISSION
	caller := std.PrevRealm().Addr()
	emissionReward := userEmissionReward[caller]
	if emissionReward > 0 {
		if gns.BalanceOf(a2u(std.CurrentRealm().Addr())) < emissionReward {
			panic(ufmt.Sprintf("not enough GNS in the realm to send emission reward(%d) for user %s", emissionReward, caller.String()))
		}

		// transfer GNS to caller
		gns.Transfer(a2u(caller), emissionReward)
		println("GOV_STAKER_GNS_EMISSION_USER", caller.String(), "AMOUNT", emissionReward)
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
		println("no protocol fee reward for user", caller)
		return
	}

	for tokenPath, amount := range protocolFee {
		if amount == 0 {
			continue
		}

		// transfer token to caller
		// token.Transfer(a2u(caller), amount)
		transferByRegisterCall(tokenPath, caller, amount)
		println("GOV_STAKER_PROTOCOL_FEE_USER", caller.String(), "TOKEN", tokenPath, "AMOUNT", amount)
		userProtocolFeeReward[caller][tokenPath] = 0

		std.Emit(
			"CollectProtocolFeeReward",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"internal_token", tokenPath,
			"internal_amount", ufmt.Sprintf("%d", amount),
		)
	}
}

func CollectRewardFromLaunchPad(to std.Address) {
	prevRealm := std.PrevRealm().PkgPath()
	if prevRealm != consts.LAUNCHPAD_PATH {
		panic("only launchpad can call CollectRewardFromLaunchPad()")
	}

	en.MintAndDistributeGns()
	calculateReward()

	prevAddr, prevRealm := getPrev()

	// GNS EMISSION
	emissionReward := userEmissionReward[to]
	if emissionReward > 0 {
		if gns.BalanceOf(a2u(std.CurrentRealm().Addr())) < emissionReward {
			panic(ufmt.Sprintf("not enough GNS in the realm to send emission reward(%d) for user %s", emissionReward, to.String()))
		}

		// transfer GNS to to
		gns.Transfer(a2u(to), emissionReward)
		println("GOV_STAKER_GNS_EMISSION_USER", to.String(), "AMOUNT", emissionReward)
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
		println("no protocol fee reward for user", to)
		return
	}

	for tokenPath, amount := range protocolFee {
		if amount == 0 {
			continue
		}

		// transfer token to to
		// token.Transfer(a2u(to), amount)
		transferByRegisterCall(tokenPath, to, amount)
		println("GOV_STAKER_PROTOCOL_FEE_USER", to.String(), "TOKEN", tokenPath, "AMOUNT", amount)
		userProtocolFeeReward[to][tokenPath] = 0

		prevAddr, prevRealm := getPrev()
		std.Emit(
			"CollectProtocolFeeFromLaunchPad",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"to", to.String(),
			"internal_token", tokenPath,
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
