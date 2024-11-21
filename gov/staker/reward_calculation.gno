package staker

import (
	"std"

	"gno.land/r/gnoswap/v1/gov/xgns"

	en "gno.land/r/gnoswap/v1/emission"
	pf "gno.land/r/gnoswap/v1/protocol_fee"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

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
	caller := std.PrevRealm().Addr()
	if err := common.LaunchpadOnly(caller); err != nil {
		panic(err)
	}

	common.IsHalted()
	en.MintAndDistributeGns()

	calculateReward()

	if add {
		amountByProjectWallet[addr] += amount
	} else {
		amountByProjectWallet[addr] -= amount
	}
}
// LAUCNHAPD DEPOSIT ===

func calculateReward() {
	height := uint64(std.GetHeight())
	if height <= lastCalculatedHeight {
		return
	}

	atLeastOneDelegated := false
	atLeastOneLaunchpadRecipient := false

	if len(delegatedTo) > 0 {
		atLeastOneDelegated = true
	}

	if len(amountByProjectWallet) > 0 {
		atLeastOneLaunchpadRecipient = true
	}

	if !atLeastOneDelegated && !atLeastOneLaunchpadRecipient {
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
		xGnsRecipientX96 := new(u256.Uint).Mul(u256.NewUint(amount), q96)
		xGnsRecipientX96 = new(u256.Uint).Mul(xGnsRecipientX96, u256.NewUint(1_000_000_000))
		ratio := new(u256.Uint).Div(xGnsRecipientX96, xGnsX96)
		ratio = ratio.Mul(ratio, q96)
		ratio = ratio.Div(ratio, u256.NewUint(1_000_000_000))
		userXGnsRatio[recipient] = ratio
	}

	calculateGNSEmission()
	calculateProtocolFee()

	lastCalculatedHeight = height
}

func calculateGNSEmission() {
	// gov_staker received xgns
	// but no gns has been staked, left amount will be used next time
	if len(delegatedTo) == 0 {
		return
	}

	gotGnsForEmission = en.GetAccuDistributedAmountForGovStaker()
	en.ClearAccuDistributedAmountForGovStaker()
	gotGnsForEmission += leftGnsEmissionFromLast

	if gotGnsForEmission == uint64(0) {
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

		userEmissionReward[delegator] += emissionReward

		calculated += emissionReward
	}

	alreadyCalculatedGnsEmission += gotGnsForEmission
	leftGnsEmissionFromLast = gotGnsForEmission - calculated

	return
}

func calculateProtocolFee() {
	// gov_staker received protocol_fee
	// but no gns has been staked, left amount will be used next time
	if len(userXGnsRatio) == 0 {
		return
	}

	accuProtocolFee := pf.GetAccuTransferToGovStaker()
	pf.ClearAccuTransferToGovStaker()
	if len(accuProtocolFee) == 0 {
		return
	}

	// get gov staker's grc20 balance
	for tokenPath, _ := range registered {

		tokenBalance := accuProtocolFee[tokenPath]

		leftFromLast := leftProtocolFeeFromLast[tokenPath]
		tokenBalance += leftFromLast

		if tokenBalance == uint64(0) {
			continue
		}

		calculated := uint64(0)
		for delegator, ratio := range userXGnsRatio {
			protocolFeeX96 := new(u256.Uint).Mul(u256.NewUint(tokenBalance), ratio)
			protocolFeeX := new(u256.Uint).Div(protocolFeeX96, q96)
			protocolFee := protocolFeeX.Uint64()
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
	}
}
