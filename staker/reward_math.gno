package staker

import (
	"std"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/consts"

	pos "gno.land/r/gnoswap/position"
)

type warmUpAmount struct {
	full30 uint64
	give30 uint64
	left30 uint64

	full50 uint64
	give50 uint64
	left50 uint64

	full70 uint64
	give70 uint64
	left70 uint64

	full100 uint64
	give100 uint64 // doesn't need this I think
	left100 uint64 // doesn't need this I think
}

var positionsWarmUpAmount = make(map[uint64]warmUpAmount) // positionId => warmUpAmount

func rewardMathComputeInternalRewardAmount(tokenId uint64) (uint64, uint64) {

	// 변경점이 생겼으니 계산 들어가야 함
	if positionGns[tokenId] != positionLastGns[tokenId] {
		// panic("ITS HAPPENING") // 패닉 뜨면 변경되었다는 뜻이니 기존에 쌓였던 리워드에 대해서 분배 필요

		/*
			current 6431934755
			last 		0


			current 19295804265
			last     6431934755
		*/
	}

	println("[ START ] REWARD__rewardMathComputeInternalRewardAmount_TOKEN_ID:", tokenId)
	deposit := deposits[tokenId]

	// using block
	stakeHeight := deposit.stakeHeight
	currentHeight := std.GetHeight()
	stakedDuration := currentHeight - stakeHeight
	durationRatio := getRewardRatio(stakedDuration)

	println(" > REWARD__rewardMathComputeInternalRewardAmount_HEIGHT:", currentHeight)

	// 과거 계산 시점부터 현재 블록까지 쌓인 리워드에 대해 각 가중치별로 분배
	toDistribute := positionGns[tokenId] - positionLastGns[tokenId]
	println(" > REWARD__positionGns[tokenId]", positionGns[tokenId])
	println(" > REWARD__positionLastGns[tokenId]", positionLastGns[tokenId])

	until30 := uint64(stakeHeight + warmUp[50] - 1)  // 150
	until50 := uint64(stakeHeight + warmUp[70] - 1)  // 300
	until70 := uint64(stakeHeight + warmUp[100] - 1) // 900
	begin100 := uint64(stakeHeight + warmUp[100])    // 901~

	lastCalculatedHeightU64 := uint64(lastCalculatedHeight)

	q96 := u256.MustFromDecimal(consts.Q96)
	toDistributeX96 := new(u256.Uint).Mul(u256.NewUint(toDistribute), q96)
	avgGnsBlockAmountX96 := new(u256.Uint).Div(toDistributeX96, u256.NewUint(uint64(currentHeight)-lastCalculatedHeightU64))
	println(" > REWARD__toDistribute:", toDistribute)
	println(" > REWARD__uint64(currentHeight)-lastCalculatedHeightU64):", uint64(currentHeight)-lastCalculatedHeightU64)
	println(" > REWARD__avgGnsBlockAmountX96:", avgGnsBlockAmountX96.ToString())

	positionWarmUpAmount, exist := positionsWarmUpAmount[tokenId]
	if !exist {
		panic("THIS SHOULD NOT HAPPEN")
	}
	println(" > REWARD__BEFORE_positionWarmUpAmount.full100", positionWarmUpAmount.full100)
	println(" > REWARD__BEFORE_positionWarmUpAmount.give100", positionWarmUpAmount.give100)
	println(" > REWARD__BEFORE_positionWarmUpAmount.left100", positionWarmUpAmount.left100)
	println()
	println(" > REWARD__BEFORE_positionWarmUpAmount.full70", positionWarmUpAmount.full70)
	println(" > REWARD__BEFORE_positionWarmUpAmount.give70", positionWarmUpAmount.give70)
	println(" > REWARD__BEFORE_positionWarmUpAmount.left70", positionWarmUpAmount.left70)
	println()
	println(" > REWARD__BEFORE_positionWarmUpAmount.full50", positionWarmUpAmount.full50)
	println(" > REWARD__BEFORE_positionWarmUpAmount.give50", positionWarmUpAmount.give50)
	println(" > REWARD__BEFORE_positionWarmUpAmount.left50", positionWarmUpAmount.left50)
	println()
	println(" > REWARD__BEFORE_positionWarmUpAmount.full30", positionWarmUpAmount.full30)
	println(" > REWARD__BEFORE_positionWarmUpAmount.give30", positionWarmUpAmount.give30)
	println(" > REWARD__BEFORE_positionWarmUpAmount.left30", positionWarmUpAmount.left30)
	println()

	switch durationRatio {
	case 100:
		if lastCalculatedHeightU64 > begin100 {
			println(" > REWARD__REWARD ONLY 100%")
			// 100%
			dur100 := uint64(currentHeight) - lastCalculatedHeightU64
			println("  > REWARD__DUR100", dur100)
			full, toGive := calcAmount(avgGnsBlockAmountX96, dur100, 100)
			// println("  > REWARD__AMOUNT100", amount)
			positionWarmUpAmount.full100 += full
			positionWarmUpAmount.give100 += toGive
			positionWarmUpAmount.left100 += full - toGive
			// gnsAmountToGive += amount // UPDATE EACH PERIOD
			// println("  > REWARD__100%", gnsAmountToGive)
		} else {
			if lastCalculatedHeightU64 > until50 {
				println(" > REWARD__REWARD 100% AND 70%")
				// 100%
				dur100 := uint64(currentHeight) - until70
				println("  > REWARD__DUR100", dur100)
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur100, 100)
				positionWarmUpAmount.full100 += full
				positionWarmUpAmount.give100 += toGive
				positionWarmUpAmount.left100 += full - toGive
				// println("  > REWARD__AMOUNT100", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__100%", gnsAmountToGive)

				// 70%
				dur70 := until70 - lastCalculatedHeightU64
				println("  > REWARD__DUR70", dur70)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive
				// println("  > REWARD__AMOUNT70", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__70%", gnsAmountToGive)
			} else if lastCalculatedHeightU64 > until30 {
				println(" > REWARD__REWARD 100% AND 70% AND 50%")
				// 100%
				dur100 := uint64(currentHeight) - until70
				println("  > REWARD__DUR100", dur100)
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur100, 100)
				positionWarmUpAmount.full100 += full
				positionWarmUpAmount.give100 += toGive
				positionWarmUpAmount.left100 += full - toGive
				// println("  > REWARD__AMOUNT100", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__100%", gnsAmountToGive)

				// 70%
				dur70 := until70 - until50
				println("  > REWARD__DUR70", dur70)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive
				// println("  > REWARD__AMOUNT70", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__70%", gnsAmountToGive)

				// 50%
				dur50 := until50 - lastCalculatedHeightU64
				println("  > REWARD__DUR50", dur50)
				// println("  > REWARD__50%", gnsAmountToGive)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur50, 50)
				positionWarmUpAmount.full50 += full
				positionWarmUpAmount.give50 += toGive
				positionWarmUpAmount.left50 += full - toGive
				// println("  > REWARD__AMOUNT50", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
			} else {
				println(" > REWARD__REWARD 100% AND 70% AND 50% AND 30%")
				// 100%
				dur100 := uint64(currentHeight) - until70
				println("  > REWARD__DUR100", dur100)
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur100, 100)
				positionWarmUpAmount.full100 += full
				positionWarmUpAmount.give100 += toGive
				positionWarmUpAmount.left100 += full - toGive
				// println("  > REWARD__AMOUNT100", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__100%", gnsAmountToGive)

				// 70%
				dur70 := until70 - until50
				println("  > REWARD__DUR70", dur70)
				// println("  > REWARD__70%", gnsAmountToGive)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive
				// println("  > REWARD__AMOUNT70", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD

				// 50%
				dur50 := until50 - until30
				println("  > REWARD__DUR50", dur50)
				// println("  > REWARD__50%", gnsAmountToGive)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur50, 50)
				positionWarmUpAmount.full50 += full
				positionWarmUpAmount.give50 += toGive
				positionWarmUpAmount.left50 += full - toGive
				// println("  > REWARD__AMOUNT50", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD

				// 30%
				dur30 := until30 - lastCalculatedHeightU64
				println("  > REWARD__DUR30", dur30)
				// println("  > REWARD__30%", gnsAmountToGive)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur30, 30)
				positionWarmUpAmount.full30 += full
				positionWarmUpAmount.give30 += toGive
				positionWarmUpAmount.left30 += full - toGive
				// println("  > REWARD__AMOUNT30", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
			}
		}

	case 70:
		if lastCalculatedHeightU64 > until50 {
			println(" > REWARD__REWARD ONLY 70%")
			// 70%
			dur70 := uint64(currentHeight) - lastCalculatedHeightU64
			println("  > REWARD__DUR70", dur70)
			full, toGive := calcAmount(avgGnsBlockAmountX96, dur70, 70)
			positionWarmUpAmount.full70 += full
			positionWarmUpAmount.give70 += toGive
			positionWarmUpAmount.left70 += full - toGive
			// println("  > REWARD__AMOUNT70", amount)
			// gnsAmountToGive += amount // UPDATE EACH PERIOD
			// println("  > REWARD__70%", gnsAmountToGive)
		} else {
			if lastCalculatedHeightU64 > until30 {
				println(" > REWARD__REWAWRD 70% AND 50%")
				// 70%
				dur70 := uint64(currentHeight) - until50
				println("  > REWARD__DUR70", dur70)
				// println("  > REWARD__70%", gnsAmountToGive)
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive
				// println("  > REWARD__AMOUNT70", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD

				// 50%
				dur50 := until50 - lastCalculatedHeightU64
				println("  > REWARD__DUR50", dur50)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur50, 50)
				positionWarmUpAmount.full50 += full
				positionWarmUpAmount.give50 += toGive
				positionWarmUpAmount.left50 += full - toGive
				// println("  > REWARD__AMOUNT50", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__50%", gnsAmountToGive)
			} else {
				println(" > REWARD__REWARD 70% AND 50% AND 30%")
				// 70%
				dur70 := uint64(currentHeight) - until50
				println("  > REWARD__DUR70", dur70)
				full, toGive := calcAmount(avgGnsBlockAmountX96, dur70, 70)
				positionWarmUpAmount.full70 += full
				positionWarmUpAmount.give70 += toGive
				positionWarmUpAmount.left70 += full - toGive
				// println("  > REWARD__AMOUNT70", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__70%", gnsAmountToGive)

				// 50%
				dur50 := until50 - until30
				println("  > REWARD__DUR50", dur50)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur50, 50)
				positionWarmUpAmount.full50 += full
				positionWarmUpAmount.give50 += toGive
				positionWarmUpAmount.left50 += full - toGive
				// println("  > REWARD__AMOUNT50", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__50%", gnsAmountToGive)

				// 30%
				dur30 := until30 - lastCalculatedHeightU64
				println("  > REWARD__DUR30", dur30)
				full, toGive = calcAmount(avgGnsBlockAmountX96, dur30, 30)
				positionWarmUpAmount.full30 += full
				positionWarmUpAmount.give30 += toGive
				positionWarmUpAmount.left30 += full - toGive
				// println("  > REWARD__AMOUNT30", amount)
				// gnsAmountToGive += amount // UPDATE EACH PERIOD
				// println("  > REWARD__30%", gnsAmountToGive)
			}
		}

	case 50:
		if lastCalculatedHeightU64 > until30 {
			println(" > REWARD__REWARD ONLY 50%")
			// 50%
			dur50 := uint64(currentHeight) - lastCalculatedHeightU64
			println("  > REWARD__DUR50", dur50)
			full, toGive := calcAmount(avgGnsBlockAmountX96, dur50, 50)
			positionWarmUpAmount.full50 += full
			positionWarmUpAmount.give50 += toGive
			positionWarmUpAmount.left50 += full - toGive
			// println("  > REWARD__AMOUNT50", amount)
			// gnsAmountToGive += amount // UPDATE EACH PERIOD
			// println("  > REWARD__50%", gnsAmountToGive)
		} else {
			println(" > REWARD__REWAD 50% AND 30%")
			dur50 := uint64(currentHeight) - until30
			println("  > REWARD__DUR50", dur50)
			full, toGive := calcAmount(avgGnsBlockAmountX96, dur50, 50)
			positionWarmUpAmount.full50 += full
			positionWarmUpAmount.give50 += toGive
			positionWarmUpAmount.left50 += full - toGive
			// println("  > REWARD__AMOUNT50", amount)
			// gnsAmountToGive += amount // UPDATE EACH PERIOD
			// println("  > REWARD__50%", gnsAmountToGive)

			// 30%
			dur30 := until30 - lastCalculatedHeightU64
			full, toGive = calcAmount(avgGnsBlockAmountX96, dur30, 30)
			positionWarmUpAmount.full30 += full
			positionWarmUpAmount.give30 += toGive
			positionWarmUpAmount.left30 += full - toGive
			// println("  > REWARD__AMOUNT30", amount)
			// gnsAmountToGive += amount // UPDATE EACH PERIOD
			println("  > REWARD__DUR30", dur30)
			// println("  > REWARD__30%", gnsAmountToGive)
		}

	case 30:
		println(" > REWARD__REWARD 30%")
		dur30 := uint64(currentHeight) - lastCalculatedHeightU64
		full, toGive := calcAmount(avgGnsBlockAmountX96, dur30, 30)
		positionWarmUpAmount.full30 += full
		positionWarmUpAmount.give30 += toGive
		positionWarmUpAmount.left30 += full - toGive
		// gnsAmountToGive += amount // UPDATE EACH PERIOD
		// println("  > REWARD__AMOUNT30", amount)
		println("  > REWARD__DUR30", dur30)
		// println("  > REWARD__30%", amount)

	default:
		println(" > REWARD__0 REWARD RATIO")
	}

	println(" > REWARD__STAKER", gnsBalance(consts.STAKER_ADDR))
	println(" > REWARD__tokenId:", tokenId)
	println(" > REWARD__toDistribute:", toDistribute)
	// println(" > REWARD__gnsAmountToGive", gnsAmountToGive)

	println(" > REWARD__stakedDuration:", stakedDuration)
	println(" > REWARD__durationRatio:", durationRatio)
	println(" > REWARD__stakeHeight:", stakeHeight)
	println(" > REWARD__currentHeight:", currentHeight)
	println(" > REWARD__[?] lastCalculatedHeight:", lastCalculatedHeight)
	println(" > REWARD__until30:", until30)
	println(" > REWARD__until50:", until50)
	println(" > REWARD__until70:", until70)
	println(" > REWARD__begin100:", begin100)

	println(" > REWARD__full30:", positionWarmUpAmount.full30)
	println(" > REWARD__give30:", positionWarmUpAmount.give30)

	println(" > REWARD__full50:", positionWarmUpAmount.full50)
	println(" > REWARD__give50:", positionWarmUpAmount.give50)

	println(" > REWARD__full70:", positionWarmUpAmount.full70)
	println(" > REWARD__give70:", positionWarmUpAmount.give70)

	println(" > REWARD__full100:", positionWarmUpAmount.full100)
	println(" > REWARD__give100:", positionWarmUpAmount.give100)

	accuFull := uint64(0)
	accuGive := uint64(0)

	accuFull += positionWarmUpAmount.full30 + positionWarmUpAmount.full50 + positionWarmUpAmount.full70 + positionWarmUpAmount.full100
	accuGive += positionWarmUpAmount.give30 + positionWarmUpAmount.give50 + positionWarmUpAmount.give70 + positionWarmUpAmount.give100

	positionsWarmUpAmount[tokenId] = positionWarmUpAmount
	println(" > REWARD__positionsWarmUpAmount[tokenId]:", positionsWarmUpAmount[tokenId])

	println("[ END ] REWARD__rewardMathComputeInternalRewardAmount_TOKEN_ID:", tokenId)
	println()
	return accuFull, accuGive
}

func rewardMathComputeExternalRewardAmount(tokenId uint64, incentiveId string, durationRatio uint64) uint64 {
	externals := positionExternal[tokenId]
	for _, external := range externals {
		if external.incentiveId == incentiveId {
			tokenAmount := external.tokenAmount

			if tokenAmount == 0 {
				return 0
			}

			amountToGive := (tokenAmount * durationRatio) / 100
			return amountToGive
		}
	}

	return 0
}

func getPoolTotalStakedLiquidity(poolPath string) *u256.Uint {
	poolStakedLiquidity := u256.Zero()
	// get all staked liquidity
	for tokenId, deposit := range deposits { // key is tokenId // used in this range loop only
		if deposit.targetPoolPath == poolPath {
			isInRange := pos.PositionIsInRange(tokenId)
			if isInRange == false {
				continue
			}

			positionLiquidity := pos.PositionGetPositionLiquidity(tokenId)
			poolStakedLiquidity = new(u256.Uint).Add(poolStakedLiquidity, positionLiquidity)
		}
	}

	return poolStakedLiquidity
}

func getMyLiquidityRatio(poolPath string, tokenId uint64) *u256.Uint {
	_q96 := u256.MustFromDecimal(consts.Q96)

	poolStakedLiquidity := getPoolTotalStakedLiquidity(poolPath)
	// XXX REMOVE AFTER QA
	// println()
	// println("tokenId:", tokenId)
	// println("POOL_LIQ:", poolStakedLiquidity.ToString())

	// my(current tokenId) liquidity
	myLiquidity := pos.PositionGetPositionLiquidity(tokenId)

	// XXX REMOVE AFTER QA
	// println("MY_LIQ:", myLiquidity.ToString())

	isInRange := pos.PositionIsInRange(tokenId)
	if isInRange == false {
		return u256.Zero()
	}

	myLiquidityX96 := new(u256.Uint).Mul(myLiquidity, _q96)
	myLiquidityX96X10000000 := new(u256.Uint).Mul(myLiquidityX96, u256.NewUint(1_000_000_000))

	poolStakedLiquidityX96 := new(u256.Uint).Mul(poolStakedLiquidity, _q96)

	myLiquidityRatio := new(u256.Uint).Div(myLiquidityX96X10000000, poolStakedLiquidityX96) // this value needs to be divided by 1_000_000_000
	myLiquidityRatio = new(u256.Uint).Mul(myLiquidityRatio, _q96)                           // so first mul consts.Q96
	myLiquidityRatio = new(u256.Uint).Div(myLiquidityRatio, u256.NewUint(1_000_000_000))    // then divided by 1_000_000_000

	// XXX REMOVE AFTER QA
	// println("myLiquidityRatio:", myLiquidityRatio.ToString())
	return myLiquidityRatio
}

// get current pool tier and reward ratio
func getPoolTierAndRatio(poolPath string) (uint64, *u256.Uint) {
	_q96 := u256.MustFromDecimal(consts.Q96)

	// current pool's tier
	internal, ok := poolTiers[poolPath]
	if !ok {
		return 0, u256.Zero()
	}
	tier := internal.tier

	// that tiers ratio
	ratio := getTierRatio(tier)
	ratioX96 := new(u256.Uint).Mul(u256.NewUint(ratio), _q96) // first consts.Q96

	// finally current pools ratio
	numTier1, numTier2, numTier3 := getNumPoolTiers()

	var weight *u256.Uint
	switch tier {
	case 1:
		weight = new(u256.Uint).Div(ratioX96, u256.NewUint(numTier1))
	case 2:
		weight = new(u256.Uint).Div(ratioX96, u256.NewUint(numTier2))
	case 3:
		weight = new(u256.Uint).Div(ratioX96, u256.NewUint(numTier3))
	default:
		panic(ufmt.Sprintf("[STAKER] reward_math.gno__getPoolTierAndRatio() || invalid tier(%d)", tier))
	}

	return tier, weight
}

// get number of pools for each tier
func getNumPoolTiers() (uint64, uint64, uint64) {
	var tier1, tier2, tier3 uint64

	for _, v := range poolTiers {
		switch v.tier {
		case 1:
			tier1++
		case 2:
			tier2++
		case 3:
			tier3++
		default:
			panic(ufmt.Sprintf("[STAKER] reward_math.gno__getNumPoolTiers() || invalid tier(%d)", v))
		}
	}

	return tier1, tier2, tier3
}

// get reward ratio by staking duration height
func getRewardRatio(height int64) uint64 {
	switch {
	case height >= warmUp[100]:
		return 100
	case height >= warmUp[70]:
		return 70
	case height >= warmUp[50]:
		return 50
	case height >= warmUp[30]:
		return 30
	default:
		return 0
	}
}

func getTierRatio(tier uint64) uint64 {
	if tier < 1 || tier > 3 {
		panic(ufmt.Sprintf("[STAKER] reward_math.gno__getTierRatio() || tier(%d) must be 1 ~ 3", tier))
	}

	ratio1, ratio2, ratio3 := listTierRatio()
	switch tier {
	case 1:
		return ratio1 // default 50
	case 2:
		return ratio2 // default 30
	case 3:
		return ratio3 // default 20
	default:
		panic("[STAKER] reward_math.gno__getTierRatio() || invalid ratio")
	}
}

// return all ratio for each tier
func listTierRatio() (uint64, uint64, uint64) {
	// basic
	// tier1 50%
	// tier2 30%
	// tier3 20%

	// since `float` type has determinisim issue, we use `int` instead
	// so instead of return 50%, we return 50
	// we'll divide by 100 later

	numTier1, numTier2, numTier3 := getNumPoolTiers()
	if numTier1 <= 0 {
		panic(ufmt.Sprintf("[STAKER] reward_math.gno__listTierRatio() || at least 1 numTier1 need(%d), [numTier2:(%d), numTier3:(%d)]", numTier1, numTier2, numTier3))
	}

	if numTier2 == 0 && numTier3 == 0 { // only tier 1 exists
		return 100, 0, 0
	} else if numTier2 == 0 && numTier3 >= 1 { // tier 1 and 3 exists ( tier2 ratio goes to tier1 )
		return 80, 0, 20
	} else if numTier2 >= 1 && numTier3 == 0 { // tier 1 and 2 exists ( tier3 ratio goes to tier1 )
		return 70, 30, 0
	} else if numTier2 >= 1 && numTier3 >= 1 { // all tiers exists
		return 50, 30, 20
	} else {
		panic("[STAKER] reward_math.gno__listTierRatio() || invalid tier ratio")
	}
}

func getTiersAmount(amount uint64) (uint64, uint64, uint64) {
	tier1Ratio, tier2Ratio, tier3Ratio := listTierRatio()

	tier1Amount := (amount * tier1Ratio) / 100
	tier2Amount := (amount * tier2Ratio) / 100
	tier3Amount := (amount * tier3Ratio) / 100

	return tier1Amount, tier2Amount, tier3Amount
}

func calcAmount(avgBlockAmountX96 *u256.Uint, dur, pct uint64) (uint64, uint64) {
	durAmountX96 := new(u256.Uint).Mul(avgBlockAmountX96, u256.NewUint(dur))
	fullAmount := new(u256.Uint).Div(durAmountX96, u256.MustFromDecimal(consts.Q96)).Uint64()

	durAmountX96 = new(u256.Uint).Mul(durAmountX96, u256.NewUint(pct))
	durAmountX96 = new(u256.Uint).Div(durAmountX96, u256.NewUint(100))

	durAmount := new(u256.Uint).Div(durAmountX96, u256.MustFromDecimal(consts.Q96)).Uint64()
	return fullAmount, durAmount
}
