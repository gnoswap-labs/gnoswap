package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/gns"
	"gno.land/r/gnoswap/v2/gov/xgns"

	en "gno.land/r/gnoswap/v2/emission"
	pf "gno.land/r/gnoswap/v2/protocol_fee"

	"gno.land/r/gnoswap/v2/consts"

	u256 "gno.land/p/gnoswap/uint256"
)

var (
	q96                  = u256.MustFromDecimal(consts.Q96)
	lastCalculatedHeight uint64 // flag to prevent same block calculation
)

var (
	gotGnsForEmission uint64
	//
	leftGnsEmissionFromLast      uint64
	alreadyCalculatedGnsEmission uint64
	//
	leftProtocolFeeFromLast      = make(map[string]uint64) // tokenPath -> tokenAmount
	alreadyCalculatedProtocolFee = make(map[string]uint64) // tokenPath -> tokenAmount
)

var (
	userXGnsRatio         = make(map[std.Address]*u256.Uint)        // address -> ratioX96
	userEmissionReward    = make(map[std.Address]uint64)            // address -> gnsAmount
	userProtocolFeeReward = make(map[std.Address]map[string]uint64) // address -> tokenPath -> tokenAmount
)

// === LAUNCHPAD DEPOSIT
var (
	// totalAmountByLaunchpad == xgns.BalanceOf(consts.LAUNCHPAD_ADDR)
	amountByProjectWallet = make(map[std.Address]uint64) // (project's) recipient wallet => amount
	rewardByProjectWallet = make(map[std.Address]uint64) // (project's) recipient wallet => reward
)

func GetRewardByProjectWallet(addr std.Address) uint64 {
	return rewardByProjectWallet[addr]
}

func SetAmountByProjectWallet(addr std.Address, amount uint64, add bool) {
	prev := std.PrevRealm().PkgPath()
	if prev != consts.LAUNCHPAD_PATH {
		panic(ufmt.Sprintf("only launchpad can set amountByProjectWallet, called from %s", prev))
	}

	calculateReward()

	if add {
		amountByProjectWallet[addr] = amount
	} else {
		amountByProjectWallet[addr] -= amount
	}
} // LAUCNHAPD DEPOSIT ===

func calculateReward() {
	println("[START START] calculateReward")
	height := uint64(std.GetHeight())
	if height <= lastCalculatedHeight {
		println("[XXX] ALREADY_CALCULATED, height:", height)
		return
	}

	// transfer protocol_fee to gov_staker
	pf.DistributeProtocolFee()

	// calculate user's xGNS ratio
	xGnsTotalSupply := xgns.TotalSupply()
	xGnsX96 := new(u256.Uint).Mul(u256.NewUint(xGnsTotalSupply), q96)

	for delegator, amount := range delegatorAmount {
		xGnsUserX96 := new(u256.Uint).Mul(u256.NewUint(amount), q96)
		xGnsUserX96 = new(u256.Uint).Mul(xGnsUserX96, u256.NewUint(1_000_000_000))

		ratio := new(u256.Uint).Div(xGnsUserX96, xGnsX96)
		ratio = ratio.Mul(ratio, q96)
		ratio = ratio.Div(ratio, u256.NewUint(1_000_000_000))

		userXGnsRatio[delegator] = ratio
	}

	// calculate project's recipient's xGNS ratio
	// to calculate protocol fee
	for recipient, amount := range amountByProjectWallet {
		println("LAUNCHPAD_recipient:", recipient)
		println("LAUNCHPAD_amount:", amount)
		xGnsRecipientX96 := new(u256.Uint).Mul(u256.NewUint(amount), q96)
		xGnsRecipientX96 = new(u256.Uint).Mul(xGnsRecipientX96, u256.NewUint(1_000_000_000))
		ratio := new(u256.Uint).Div(xGnsRecipientX96, xGnsX96)
		ratio = ratio.Mul(ratio, q96)
		ratio = ratio.Div(ratio, u256.NewUint(1_000_000_000))
		userXGnsRatio[recipient] = ratio
		println("LAUNCHPAD_ratio:", ratio.ToString())
	}

	calculateGNSEmission()
	calculateProtocolFee()

	lastCalculatedHeight = height
}

func calculateGNSEmission() {
	println("[START START START] calculateGNSEmission")

	// gov_staker received xgns
	// but no gns has been staked, left amount will be used next time
	if len(delegatedTo) == 0 {
		println("gns emission no user")
		return
	}

	gotGnsForEmission = en.GetAccuDistributedAmountForGovStaker()
	en.ClearAccuDistributedAmountForGovStaker()
	println(" > EN_gotGnsForEmission", gotGnsForEmission)
	println(" > leftGnsEmissionFromLast", leftGnsEmissionFromLast)
	gotGnsForEmission += leftGnsEmissionFromLast
	println(" > [SUM] gotGnsForEmission", gotGnsForEmission)

	if gotGnsForEmission == uint64(0) {
		println(" [RETURN] ZERO GNS EMISSION")
		println()
		return
	}

	calculated := uint64(0)
	for delegator, ratio := range userXGnsRatio {
		emissionRewardX96 := new(u256.Uint).Mul(u256.NewUint(gotGnsForEmission), ratio)
		emissionRewardX := new(u256.Uint).Div(emissionRewardX96, q96)
		emissionReward := emissionRewardX.Uint64()
		if emissionReward == uint64(0) {
			continue
		}

		println(" > before:\t", delegator, userEmissionReward[delegator])
		userEmissionReward[delegator] += emissionReward
		println(" > after:\t", delegator, userEmissionReward[delegator])
		println("  > emissionReward:", emissionReward)

		calculated += emissionReward
	}

	alreadyCalculatedGnsEmission += gotGnsForEmission
	leftGnsEmissionFromLast = gotGnsForEmission - calculated
	println("FINAL LEFT:", leftGnsEmissionFromLast)
	println()

	return
}

func calculateProtocolFee() {
	println("[START START START] calculateProtocolFee")

	// gov_staker received protocol_fee
	// but no gns has been staked, left amount will be used next time
	if len(userXGnsRatio) == 0 {
		println("protocol_fee no user")
		return
	}

	accuProtocolFee := pf.GetAccuTransferToGovStaker()
	println("accuProtocolFee:", accuProtocolFee)
	pf.ClearAccuTransferToGovStaker()

	// get gov staker's grc20 balance
	for tokenPath, _ := range registered {
		println(" > PF tokenPath:", tokenPath)

		tokenBalance := accuProtocolFee[tokenPath]
		println(" > tokenBalance:", tokenBalance)
		leftFromLast := leftProtocolFeeFromLast[tokenPath]
		println(" > leftFromLast:", leftFromLast)
		tokenBalance += leftFromLast
		println(" > [SUM] tokenBalance:", tokenBalance)

		if tokenBalance == uint64(0) {
			println(" > [XXX] NO PROTOCOL FEE")
			println()
			continue
		}

		calculated := uint64(0)
		for delegator, ratio := range userXGnsRatio {
			protocolFeeX96 := new(u256.Uint).Mul(u256.NewUint(tokenBalance), ratio)
			println("  > PF tokenBalance:", tokenBalance)
			protocolFeeX := new(u256.Uint).Div(protocolFeeX96, q96)
			protocolFee := protocolFeeX.Uint64()
			println("  > PF protocolFee:", protocolFee)
			if protocolFee == uint64(0) {
				continue
			}

			if userProtocolFeeReward[delegator] == nil {
				userProtocolFeeReward[delegator] = make(map[string]uint64)
			}

			userProtocolFeeReward[delegator][tokenPath] += protocolFee
			calculated += protocolFee
		}

		alreadyCalculatedProtocolFee[tokenPath] += tokenBalance
		leftProtocolFeeFromLast[tokenPath] = tokenBalance - calculated
		println("FINAL LEFT TOKEN:", tokenPath, "AMOUNT:", leftProtocolFeeFromLast[tokenPath])
		println()
	}
}

func getGovStakerGnsWithoutXGns() uint64 {
	gnsGovStaker := gns.BalanceOf(a2u(consts.GOV_STAKER_ADDR))
	totalXGns := xgns.TotalSupply()
	println("getGovStakerGnsWithoutXGns()_gnsGovStaker:\t\t", gnsGovStaker)
	println("getGovStakerGnsWithoutXGns()_totalXGns:\t\t\t", totalXGns)

	if gnsGovStaker < totalXGns {
		panic(ufmt.Sprintf("gnsGovStaker(%d) < totalXGns(%d)", gnsGovStaker, totalXGns))
	}
	return gnsGovStaker - totalXGns
}
