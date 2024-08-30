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

type lockedXGNS struct {
	amount uint64
	unlock uint64
}

const TIMESTAMP_7_DAYS = uint64(604800) // 7 days in seconds

var (
	addrLockedXGns = make(map[string][]lockedXGNS)
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

	// TODO: std.Emit()
}

// xGNS from -> xGNS to
func Redelegate(from, to std.Address, amount uint64) {
	en.MintAndDistributeGns()
	calculateReward()

	if !from.IsValid() {
		panic(ufmt.Sprintf("invalid from address %s to Redelegate", to.String()))
	}

	if !to.IsValid() {
		panic(ufmt.Sprintf("invalid to address %s to Redelegate", to.String()))
	}

	if amount < minimumAmount {
		panic(ufmt.Sprintf("minimum amount to re-delegate is %d (requested:%d)", minimumAmount, amount))
	}

	undelegate(from, amount)
	delegate(to, amount)

	// TODO: std.Emit()
}

func Undelegate(from std.Address, amount uint64) {
	en.MintAndDistributeGns()
	calculateReward()

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
	userLocked := lockedXGNS{
		amount: amount,
		unlock: uint64(time.Now().Unix()) + TIMESTAMP_7_DAYS, // after 7 days, call Collect() to receive GNS
	}
	addrLockedXGns[caller.String()] = append(addrLockedXGns[caller.String()], userLocked)

	// TODO: std.Emit()
}

func CollectUndelegated() uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	caller := std.GetOrigCaller()

	if len(addrLockedXGns[caller.String()]) == 0 {
		return 0
	}

	// check if caller has any GNS to claim
	for i, locked := range addrLockedXGns[caller.String()] {
		if uint64(time.Now().Unix()) >= locked.unlock { // passed 20 days
			// transfer GNS to caller
			gns.Transfer(a2u(caller), locked.amount)

			// TOOD:
			// std.Emit()

			// remove from locked list
			addrLockedXGns[caller.String()] = append(addrLockedXGns[caller.String()][:i], addrLockedXGns[caller.String()][i+1:]...)
			return locked.amount
		}
	}

	return 0
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
		println("CollectReward_GNS", emissionReward)
		userEmissionReward[caller.String()] = 0

		// TODO: std.Emit()
	}

	// PROTOCOL FEE
	protocolFee, exist := userProtocolFeeReward[caller.String()]
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
		println("CollectReward_TOKEN", tokenPath, "AMOUNT", amount)
		userProtocolFeeReward[caller.String()][tokenPath] = 0

		// TODO: std.Emit()
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
