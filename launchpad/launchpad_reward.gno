package launchpad

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	gs "gno.land/r/gnoswap/v2/gov/staker"
)

// CollectProtocolFee collects protocol fee from gov/staker
// each project's recipient wallet will be rewarded
func CollectProtocolFee() {
	caller := std.PrevRealm().Addr()
	gs.CollectRewardFromLaunchPad(caller)

	// event will be emitted in gov/staker CollectRewardFromLaunchPad()
}

var (
	lastCalculatedHeight uint64
)

func init() {
	lastCalculatedHeight = uint64(std.GetHeight())
}

// CollectRewardByProjectId collects reward from entire deposit of certain project by caller
//
// returns collected reward amount
func CollectRewardByProjectId(projectId string) uint64 {
	project, exist := projects[projectId]
	if !exist {
		println("NO PROJECT FOR THIS ID", projectId)
		return 0
	}

	calculateDepositReward()

	caller := std.PrevRealm().Addr()
	if _, exist := depositsByUserByProject[caller]; !exist {
		println("NO DEPOSIT FOR THIS USER", caller)
		return 0
	}
	depositIds, exist := depositsByUserByProject[caller][projectId]
	if !exist {
		println("NO DEPOSIT FOR THIS PROJECT", projectId)
		return 0
	}

	prevAddr, prevRealm := getPrev()

	toUser := uint64(0)
	for _, depositId := range depositIds {
		deposit := deposits[depositId]
		if deposit.rewardAmount == 0 {
			println("NO REWARD FOR THIS DEPOSIT", depositId)
			continue
		}

		project := projects[deposit.projectId]
		if project.id != projectId {
			println("PROJECT ID MISMATCH", project.id, projectId)
			continue
		}

		if deposit.rewardAmount > 0 {
			if deposit.rewardCollectTime != 0 {
				println("(N)th collect")
				toUser += deposit.rewardAmount
			} else {
				collectableAfter := uint64(0)
				switch deposit.tier {
				case "30":
					collectableAfter = project.startHeight + project.tier30.collectWaitDuration
				case "90":
					collectableAfter = project.startHeight + project.tier90.collectWaitDuration
				case "180":
					collectableAfter = project.startHeight + project.tier180.collectWaitDuration
				}

				if uint64(std.GetHeight()) < collectableAfter {
					println("NOT CLAIMABLE YET")
					continue
				}

				println("token:", project.tokenPath, "reward:", deposit.rewardAmount)
				toUser += deposit.rewardAmount
			}

			std.Emit(
				"CollectRewardByProjectId",
				"prevAddr", prevAddr,
				"prevRealm", prevRealm,
				"projectId", projectId,
				"internal_depositId", depositId,
				"internal_amount", ufmt.Sprintf("%d", deposit.rewardAmount),
			)
		}

		// update project
		project.totalCollectedAmount += deposit.rewardAmount
		projects[deposit.projectId] = project

		// update deposit
		deposit.rewardAmount = 0
		deposit.rewardCollectHeight = uint64(std.GetHeight())
		deposit.rewardCollectTime = uint64(time.Now().Unix())
		deposits[depositId] = deposit
	}

	// transfer reward to user
	transferByRegisterCall(project.tokenPath, std.PrevRealm().Addr(), toUser)

	return toUser
}

// CollectRewardByDepositId collects reward from certain deposit by caller
//
// returns collected reward amount
func CollectRewardByDepositId(depositId string) uint64 {
	deposit, exist := deposits[depositId]
	if !exist {
		panic("deposit not found")
	}

	project, exist := projects[deposit.projectId]
	if !exist {
		println("NO PROJECT FOR THIS ID", deposit.projectId)
		return 0
	}

	caller := std.PrevRealm().Addr()
	if _, exist := depositsByUserByProject[caller]; !exist {
		println("NO DEPOSIT FOR THIS USER", caller)
		return 0
	}

	calculateDepositReward()
	deposit = deposits[depositId] // get updated deposit

	toUser := uint64(0)

	if deposit.rewardAmount > 0 {
		if deposit.rewardCollectTime != 0 {
			println("(N)th collect")
			toUser += deposit.rewardAmount
		} else {
			collectableAfter := uint64(0)
			switch deposit.tier {
			case "30":
				collectableAfter = project.startHeight + project.tier30.collectWaitDuration
			case "90":
				collectableAfter = project.startHeight + project.tier90.collectWaitDuration
			case "180":
				collectableAfter = project.startHeight + project.tier180.collectWaitDuration
			}

			if uint64(std.GetHeight()) < collectableAfter {
				println("NOT CLAIMABLE YET")
				return 0
			}

			toUser += deposit.rewardAmount
		}

		std.Emit(
			"CollectRewardByDepositId",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"depositId", depositId,
			"internal_amount", ufmt.Sprintf("%d", deposit.rewardAmount),
		)

		// update project
		project.totalCollectedAmount += deposit.rewardAmount
		projects[deposit.projectId] = project

		// update deposit
		deposit.rewardAmount = 0
		deposit.rewardCollectHeight = uint64(std.GetHeight())
		deposit.rewardCollectTime = uint64(time.Now().Unix())
		deposits[depositId] = deposit
	}

	// transfer reward to user
	transferByRegisterCall(project.tokenPath, std.PrevRealm().Addr(), toUser)

	// XXX: emit event

	return toUser
}

var lastCalculateHeightForProjectTier = make(map[string]uint64) // using height

// amount of project token for each deposit will be calculated
func calculateDepositReward() {
	// println(">>> calculateDepositReward")
	height := uint64(std.GetHeight())

	if height == lastCalculatedHeight {
		println("THIS BLOCK ALREADY CALCULATED", height)
		return
	}
	lastCalculatedHeight = height

	for _, project := range projects {
		// // loop with project
		// println("projectIdx", projectIdx)
		// println("project.id", project.id)

		// // early return if not active
		// println("project.startHeight\t", project.startHeight)
		// println("now\t\t\t", now)
		if project.startHeight > height {
			println("PROJECT NOT STARTED")
			continue
		}

		// println("LAST CALC PROJECT TIER 30", project.tier30.id)
		// println("lastCalculateHeightForProjectTier[project.tier30.id]", lastCalculateHeightForProjectTier[project.tier30.id])
		if lastCalculateHeightForProjectTier[project.tier30.id] == 0 {
			// println(" > INIT TO `project.startHeight`", project.startHeight)
			lastCalculateHeightForProjectTier[project.tier30.id] = project.startHeight
		}

		// println("LAST CALC PROJECT TIER 90", project.tier90.id)
		// println("lastCalculateHeightForProjectTier[project.tier90.id]", lastCalculateHeightForProjectTier[project.tier90.id])
		if lastCalculateHeightForProjectTier[project.tier90.id] == 0 {
			// println(" > INIT TO `project.startHeight`", project.startHeight)
			lastCalculateHeightForProjectTier[project.tier90.id] = project.startHeight
		}

		// println("LAST CALC PROJECT TIER 180", project.tier180.id)
		// println("lastCalculateHeightForProjectTier[project.tier180.id]", lastCalculateHeightForProjectTier[project.tier180.id])
		if lastCalculateHeightForProjectTier[project.tier180.id] == 0 {
			// println(" > INIT TO `project.startHeight`", project.startHeight)
			lastCalculateHeightForProjectTier[project.tier180.id] = project.startHeight
		}

		// if current height is greater than endHeight, then use endHeight as project's each tier's endHeight
		endHeightFor30 := minU64(height, project.tier30.endHeight)
		endHeightFor90 := minU64(height, project.tier90.endHeight)
		endHeightFor180 := minU64(height, project.tier180.endHeight)

		// if last calculate height is greater than endHeight, then use endHeight to calculate duration
		sinceLast30 := endHeightFor30 - minU64(endHeightFor30, lastCalculateHeightForProjectTier[project.tier30.id])
		sinceLast90 := endHeightFor90 - minU64(endHeightFor90, lastCalculateHeightForProjectTier[project.tier90.id])
		sinceLast180 := endHeightFor180 - minU64(endHeightFor180, lastCalculateHeightForProjectTier[project.tier180.id])

		// update for next calc
		lastCalculateHeightForProjectTier[project.tier30.id] = height
		lastCalculateHeightForProjectTier[project.tier90.id] = height
		lastCalculateHeightForProjectTier[project.tier180.id] = height

		rewardX96_30 := new(u256.Uint).Mul(project.tier30.tierAmountPerBlockX96, u256.NewUint(sinceLast30))
		rewardX96_90 := new(u256.Uint).Mul(project.tier90.tierAmountPerBlockX96, u256.NewUint(sinceLast90))
		rewardX96_180 := new(u256.Uint).Mul(project.tier180.tierAmountPerBlockX96, u256.NewUint(sinceLast180))

		// calculate deposit ratio
		// loop with each tier (30 90 180)
		tier30Deposit := project.tier30.actualDepositAmount
		tier90Deposit := project.tier90.actualDepositAmount
		tier180Deposit := project.tier180.actualDepositAmount
		// println("tier30.id", project.tier30.id)
		// println("tier30Deposit", tier30Deposit)
		// println("tier90Deposit", tier90Deposit)
		// println("tier180Deposit", tier180Deposit)

		// iterate deposit (by project)
		depositWithTier, exist := depositsByProject[project.id]
		if !exist {
			println("NO DEPOSIT FOR THIS PROJECT", project.id)
			return
		}

		for tierStr, depositIds := range depositWithTier {
			println("tierStr", tierStr)
			tierAmount := uint64(0)
			var rewardX96 *u256.Uint

			switch tierStr {
			case "30":
				tierAmount = tier30Deposit
			case "90":
				tierAmount = tier90Deposit
			case "180":
				tierAmount = tier180Deposit
			}

			for _, depositId := range depositIds {
				deposit := deposits[depositId]

				sinceLast := uint64(0)
				switch deposit.tier {
				case "30":
					sinceLast = sinceLast30
					rewardX96 = rewardX96_30.Clone()
				case "90":
					sinceLast = sinceLast90
					rewardX96 = rewardX96_90.Clone()
				case "180":
					sinceLast = sinceLast180
					rewardX96 = rewardX96_180.Clone()
				default:
					panic("INVALID TIER")
				}
				if sinceLast == 0 {
					println("NO BLOCK PASSED SINCE LAST CALCULATION")
					continue
				}

				// calculate reward
				ratioX96 := calcDepositRatioX96(tierAmount, deposit.amount)
				println("ratioX96:", ratioX96.ToString())

				depositRewardX96X96 := u256.Zero().Mul(rewardX96, ratioX96)
				println("depositRewardX96X96:", depositRewardX96X96.ToString())

				depositRewardX96 := u256.Zero().Div(depositRewardX96X96, q96)
				println("depositRewardX96:", depositRewardX96.ToString())

				depositRewardX := u256.Zero().Div(depositRewardX96, q96)
				println("depositRewardX:", depositRewardX.ToString())

				depoistReward := depositRewardX.Uint64()
				println("depoistReward:", depoistReward)

				println("B_deposit.rewardAmount", deposit.rewardAmount)
				deposit.rewardAmount += depoistReward
				println("A_deposit.rewardAmount", deposit.rewardAmount)

				// update deposit
				deposits[depositId] = deposit
			}
		}
	}
}

func calcDepositRatioX96(tierAmount uint64, amount uint64) *u256.Uint {
	amountX96 := new(u256.Uint).Mul(u256.NewUint(amount), q96)
	amountX96x := new(u256.Uint).Mul(amountX96, u256.NewUint(1_000_000_000))

	tierAmountX96 := new(u256.Uint).Mul(u256.NewUint(tierAmount), q96)

	depositRatioX96 := new(u256.Uint).Div(amountX96x, tierAmountX96)
	depositRatioX96 = depositRatioX96.Mul(depositRatioX96, q96)
	depositRatioX96 = depositRatioX96.Div(depositRatioX96, u256.NewUint(1_000_000_000))

	return depositRatioX96
}
