package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

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
	addrLockedGns = make(map[string][]lockedGNS)
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

	caller := std.GetOrigCaller()

	// GNS // caller -> GovStaker
	gns.TransferFrom(a2u(caller), a2u(std.CurrentRealm().Addr()), amount)

	// xGNS mint to caller
	xgns.Mint(a2u(caller), amount)

	// actual delegate
	delegate(to, amount)

	std.Emit(
		"Delegate",
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_to", to.String(),
		"p_amount", ufmt.Sprintf("%d", amount),
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

	caller := std.GetOrigCaller()

	if xgns.BalanceOf(a2u(caller)) < amount {
		panic("not enough xGNS staked")
	}

	undelegate(from, amount)
	delegate(to, amount)

	std.Emit(
		"Redelegate",
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_from", from.String(),
		"p_to", to.String(),
		"p_amount", ufmt.Sprintf("%d", amount),
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

	caller := std.GetOrigCaller()

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
	addrLockedGns[caller.String()] = append(addrLockedGns[caller.String()], userLocked)
	lockedAmount += amount

	std.Emit(
		"Undelegate",
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_from", from.String(),
		"p_amount", ufmt.Sprintf("%d", amount),
	)
}

func CollectUndelegated() uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	caller := std.GetOrigCaller()

	if len(addrLockedGns[caller.String()]) == 0 {
		return 0
	}

	// check if caller has any GNS to claim
	collected := uint64(0)
	for i, locked := range addrLockedGns[caller.String()] {
		if uint64(time.Now().Unix()) >= locked.unlock && locked.amount > 0 { // passed 7 days
			// transfer GNS to caller
			gns.Transfer(a2u(caller), locked.amount)

			std.Emit(
				"CollectUndelegated",
				"m_origCaller", origCaller(),
				"m_prevRealm", prevRealm(),
				"amount", ufmt.Sprintf("%d", locked.amount),
			)

			// remove from locked list
			addrLockedGns[caller.String()] = append(addrLockedGns[caller.String()][:i], addrLockedGns[caller.String()][i+1:]...)

			lockedAmount -= locked.amount
			collected += locked.amount
		}
	}

	return collected
}

func CollectReward() {
	en.MintAndDistributeGns()
	calculateReward()

	// GNS EMISSION
	caller := std.GetOrigCaller()
	emissionReward := userEmissionReward[caller.String()]
	if emissionReward > 0 {
		if gns.BalanceOf(a2u(std.CurrentRealm().Addr())) < emissionReward {
			panic(ufmt.Sprintf("not enough GNS in the realm to send emission reward(%d) for user %s", emissionReward, caller.String()))
		}

		// transfer GNS to caller
		gns.Transfer(a2u(caller), emissionReward)
		println("GOV_STAKER_GNS_EMISSION_USER", caller.String(), "AMOUNT", emissionReward)
		userEmissionReward[caller.String()] = 0

		std.Emit(
			"CollectReward",
			"m_origCaller", origCaller(),
			"m_prevRealm", prevRealm(),
			"reward", "emission",
			"amount", ufmt.Sprintf("%d", emissionReward),
		)
	}

	// PROTOCOL FEE
	protocolFee, exist := userProtocolFeeReward[caller.String()]
	if !exist || len(protocolFee) == 0 {
		println("no protocol fee reward for user", caller.String())
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
		userProtocolFeeReward[caller.String()][tokenPath] = 0

		std.Emit(
			"CollectReward",
			"m_origCaller", origCaller(),
			"m_prevRealm", prevRealm(),
			"reward", "protocol_fee",
			"token", tokenPath,
			"amount", ufmt.Sprintf("%d", amount),
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
