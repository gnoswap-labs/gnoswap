package staker

import (
	"std"

	"gno.land/r/gnoswap/v1/gov/xgns"

	en "gno.land/r/gnoswap/v1/emission"
	pf "gno.land/r/gnoswap/v1/protocol_fee"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/p/demo/avl"
	u256 "gno.land/p/gnoswap/uint256"
)

var (
	q96                  = u256.MustFromDecimal(consts.Q96)
	lastCalculatedHeight uint64 // flag to prevent same block calculation
)

var (
	gotGnsForEmission            uint64
	leftGnsEmissionFromLast      uint64
	alreadyCalculatedGnsEmission uint64

	leftProtocolFeeFromLast      = avl.NewTree() // tokenPath -> tokenAmount
	alreadyCalculatedProtocolFee = avl.NewTree() // tokenPath -> tokenAmount
)

var (
	userXGnsRatio         = avl.NewTree() // address -> ratioX96
	userEmissionReward    = avl.NewTree() // address -> gnsAmount
	userProtocolFeeReward = avl.NewTree() // address -> tokenPath -> tokenAmount
)

// === LAUNCHPAD DEPOSIT
var (
	amountByProjectWallet = avl.NewTree() // recipient wallet => amount
	rewardByProjectWallet = avl.NewTree() // recipient wallet => reward
)

func GetRewardByProjectWallet(addr std.Address) uint64 {
	value, exists := rewardByProjectWallet.Get(addr.String())
	if !exists {
		return 0
	}
	return value.(uint64)
}

func getAmountByProjectWallet(addr std.Address) uint64 {
	value, exists := amountByProjectWallet.Get(addr.String())
	if !exists {
		return 0
	}
	return value.(uint64)
}

func SetAmountByProjectWallet(addr std.Address, amount uint64, add bool) {
	caller := std.PrevRealm().Addr()
	if err := common.LaunchpadOnly(caller); err != nil {
		panic(err)
	}

	common.IsHalted()
	en.MintAndDistributeGns()
	calculateReward()

	currentAmount := getAmountByProjectWallet(addr)
	if add {
		amountByProjectWallet.Set(addr.String(), currentAmount+amount)
	} else {
		amountByProjectWallet.Set(addr.String(), currentAmount-amount)
	}
}

// LAUCNHAPD DEPOSIT ===

func calculateReward() {
	height := uint64(std.GetHeight())
	if height <= lastCalculatedHeight {
		return
	}

	atLeastOneDelegated := delegatedTo.Size() > 0
	atLeastOneLaunchpadRecipient := amountByProjectWallet.Size() > 0

	if !atLeastOneDelegated && !atLeastOneLaunchpadRecipient {
		return
	}

	// transfer protocol_fee to gov_staker
	pf.DistributeProtocolFee()

	// calculate user's xGNS ratio
	xGnsTotalSupply := xgns.TotalSupply()
	xGnsX96 := new(u256.Uint).Mul(u256.NewUint(xGnsTotalSupply), q96)

	// calculate delegator ratio
	delegatorAmount.Iterate("", "", func(key string, value interface{}) bool {
		amount := value.(uint64)
		ratio := calculateXGnsRatio(amount, xGnsX96)

		userXGnsRatio.Set(key, ratio)
		return false
	})

	// calculate project's recipient's xGNS ratio
	amountByProjectWallet.Iterate("", "", func(key string, value interface{}) bool {
		amount := value.(uint64)
		ratio := calculateXGnsRatio(amount, xGnsX96)

		userXGnsRatio.Set(key, ratio)
		return false
	})

	calculateGNSEmission()
	calculateProtocolFee()

	lastCalculatedHeight = height
}

// calculateXGnsRatio calculates the ratio of user's xGNS amount to total xGNS supply
func calculateXGnsRatio(amount uint64, xGnsX96 *u256.Uint) *u256.Uint {
	xGnsAmountX96 := new(u256.Uint).Mul(u256.NewUint(amount), q96)
	xGnsAmountX96 = new(u256.Uint).Mul(xGnsAmountX96, u256.NewUint(1_000_000_000))

	ratio := new(u256.Uint).Div(xGnsAmountX96, xGnsX96)
	ratio = ratio.Mul(ratio, q96)
	return ratio.Div(ratio, u256.NewUint(1_000_000_000))
}

func calculateGNSEmission() {
	// gov_staker received xgns
	// but no gns has been staked, left amount will be used next time
	if delegatedTo.Size() == 0 {
		return
	}

	gotGnsForEmission = en.GetDistributedToGovStaker()
	en.ClearDistributedToGovStaker()
	gotGnsForEmission += leftGnsEmissionFromLast

	if gotGnsForEmission == uint64(0) {
		return
	}

	calculated := uint64(0)
	userXGnsRatio.Iterate("", "", func(key string, value interface{}) bool {
		ratio := value.(*u256.Uint)
		emissionRewardX96 := new(u256.Uint).Mul(u256.NewUint(gotGnsForEmission), ratio)
		emissionRewardX := new(u256.Uint).Div(emissionRewardX96, q96)
		emissionReward := emissionRewardX.Uint64()
		if emissionReward == uint64(0) {
			return false
		}

		currentReward := uint64(0)
		if val, exists := userEmissionReward.Get(key); exists {
			currentReward = val.(uint64)
		}
		userEmissionReward.Set(key, currentReward+emissionReward)

		calculated += emissionReward
		return false
	})

	alreadyCalculatedGnsEmission += gotGnsForEmission
	leftGnsEmissionFromLast = gotGnsForEmission - calculated
}

func calculateProtocolFee() {
	// gov_staker received protocol_fee
	// but no gns has been staked, left amount will be used next time
	if userXGnsRatio.Size() == 0 {
		return
	}

	accuProtocolFee := pf.GetAccuTransferToGovStaker()
	pf.ClearAccuTransferToGovStaker()
	if len(accuProtocolFee) == 0 {
		return
	}

	registered := common.ListRegisteredTokens()
	// get gov staker's grc20 balance
	for _, tokenPath := range registered {
		tokenBalance, exists := accuProtocolFee.Get(tokenPath)
		if !exists || tokenBalance == uint64(0) {
			continue
		}

		leftValue, exists := leftProtocolFeeFromLast.Get(tokenPath)
		leftFromLast := uint64(0)
		if exists {
			leftFromLast = leftValue.(uint64)
		}
		tokenBalance = tokenBalance.(uint64) + leftFromLast

		if tokenBalance.(uint64) == uint64(0) {
			continue
		}

		calculated := uint64(0)
		userXGnsRatio.Iterate("", "", func(key string, value interface{}) bool {
			ratio := value.(*u256.Uint)
			protocolFeeX96 := new(u256.Uint).Mul(u256.NewUint(tokenBalance.(uint64)), ratio)
			protocolFeeX := new(u256.Uint).Div(protocolFeeX96, q96)
			protocolFee := protocolFeeX.Uint64()
			if protocolFee == uint64(0) {
				return false
			}

			var userFees *avl.Tree
			if val, exists := userProtocolFeeReward.Get(key); exists {
				userFees = val.(*avl.Tree)
			} else {
				userFees = avl.NewTree()
				userProtocolFeeReward.Set(key, userFees)
			}

			currentFee := uint64(0)
			if val, exists := userFees.Get(tokenPath); exists {
				currentFee = val.(uint64)
			}
			userFees.Set(tokenPath, currentFee+protocolFee)

			calculated += protocolFee
			return false
		})

		current := uint64(0)
		if val, exists := alreadyCalculatedProtocolFee.Get(tokenPath); exists {
			current = val.(uint64)
		}
		alreadyCalculatedProtocolFee.Set(tokenPath, current+tokenBalance.(uint64))
		leftProtocolFeeFromLast.Set(tokenPath, tokenBalance.(uint64)-calculated)
	}
}
