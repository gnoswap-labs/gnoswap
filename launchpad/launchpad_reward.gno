package launchpad

import (
	"std"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
)

// BELOW LOGIC is for each project's recipient
/*
	`launchpad` contract will have xGNS because of deposit
	Therefore when claiming reward from protocol fee, launchpad will get some
	These rewards should be distributed to the recipients of the projects


	# re-use gov'stakers reward calculation logic
	https://github.com/gnoswap-labs/gnoswap/blob/8efa646a76024af74f3920d5b15a01f8ab1d937c/gov/staker/reward_calculation.gno#L40-L69

*/

// BELOW LOGIC is for users who made deposit
var (
	lastCalculatedHeight uint64
)

func init() {
	lastCalculatedHeight = uint64(std.GetHeight())
}

// claim reward for all projects, most likely won't be used
// `ClaimRewardByProjectId` will be used
func ClaimReward() {
	calculateDepositReward()

	callerStr := std.GetOrigCaller().String()
	depositIds, exist := depositsByUser[callerStr]
	if !exist {
		println("NO DEPOSIT FOR THIS USER", callerStr)
		return
	}

	// project token -> reward amount
	toUser := make(map[string]uint64)

	for _, depositId := range depositIds {
		deposit := deposits[depositId]
		if deposit.rewardAmount == 0 {
			println("NO REWARD FOR THIS DEPOSIT", depositId)
			continue
		}

		project := projects[deposit.projectId]
		projectToken := project.tokenPath

		if deposit.rewardAmount > 0 { // deposit has some reward
			if deposit.rewardClaimAt != 0 { // this claim is not first claim
				println("(N)th claim")
				toUser[projectToken] += deposit.rewardAmount
			} else {
				// if fisrt claim, then check tier's claim wait duration
				claimableAfter := uint64(0)
				switch deposit.tier {
				case "30":
					claimableAfter = project.startTime + project.tier30.claimWaitDuration
				case "90":
					claimableAfter = project.startTime + project.tier90.claimWaitDuration
				case "180":
					claimableAfter = project.startTime + project.tier180.claimWaitDuration
				}

				if uint64(time.Now().Unix()) < claimableAfter {
					println("NOT CLAIMABLE YET")
					continue
				}

				println("token:", projectToken, "reward:", deposit.rewardAmount)
				toUser[projectToken] += deposit.rewardAmount
			}
		}

		// update project
		project.totalClaimedAmount += deposit.rewardAmount
		projects[deposit.projectId] = project

		// update deposit
		deposit.rewardAmount = 0
		deposit.rewardClaimHeight = uint64(std.GetHeight())
		deposit.rewardClaimAt = uint64(time.Now().Unix())
		deposits[depositId] = deposit
	}

	// transfer reward to user
	for tokenPath, amount := range toUser {
		// println("tokenPath:", tokenPath)
		// println("amount:", amount)
		transferByRegisterCall(tokenPath, std.GetOrigCaller(), amount)
	}

	// XXX: emit event
}

func ClaimRewardByProjectId(projectId string) uint64 {
	project, exist := projects[projectId]
	if !exist {
		println("NO PROJECT FOR THIS ID", projectId)
		return 0
	}

	calculateDepositReward()

	callerStr := std.GetOrigCaller().String()
	if _, exist := depositsByUserByProject[callerStr]; !exist {
		println("NO DEPOSIT FOR THIS USER", callerStr)
		return 0
	}
	depositIds, exist := depositsByUserByProject[callerStr][projectId]
	if !exist {
		println("NO DEPOSIT FOR THIS PROJECT", projectId)
		return 0
	}

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
			if deposit.rewardClaimAt != 0 {
				println("(N)th claim")
				toUser += deposit.rewardAmount
			} else {
				claimableAfter := uint64(0)
				switch deposit.tier {
				case "30":
					claimableAfter = project.startTime + project.tier30.claimWaitDuration
				case "90":
					claimableAfter = project.startTime + project.tier90.claimWaitDuration
				case "180":
					claimableAfter = project.startTime + project.tier180.claimWaitDuration
				}

				if uint64(time.Now().Unix()) < claimableAfter {
					println("NOT CLAIMABLE YET")
					continue
				}

				println("token:", project.tokenPath, "reward:", deposit.rewardAmount)
				toUser += deposit.rewardAmount
			}
		}

		// update project
		project.totalClaimedAmount += deposit.rewardAmount
		projects[deposit.projectId] = project

		// update deposit
		deposit.rewardAmount = 0
		deposit.rewardClaimHeight = uint64(std.GetHeight())
		deposit.rewardClaimAt = uint64(time.Now().Unix())
		deposits[depositId] = deposit
	}

	// transfer reward to user
	transferByRegisterCall(project.tokenPath, std.GetOrigCaller(), toUser)

	// XXX: emit event

	return toUser
}

func ClaimRewardByProjectTier(tierId string) uint64 {
	projectId, tierStr := getProjectIdAndTierFromTierId(tierId)
	project, exist := projects[projectId]
	if !exist {
		println("NO PROJECT FOR THIS ID", projectId)
		return 0
	}

	callerStr := std.GetOrigCaller().String()
	if _, exist := depositsByUserByProject[callerStr]; !exist {
		println("NO DEPOSIT FOR THIS USER", callerStr)
		return 0
	}
	depositIds, exist := depositsByUserByProject[callerStr][projectId]
	if !exist {
		println("NO DEPOSIT FOR THIS PROJECT", projectId)
		return 0
	}

	calculateDepositReward()

	toUser := uint64(0)
	for _, depositId := range depositIds {
		deposit := deposits[depositId]

		// matching tier
		if deposit.projectId == projectId && deposit.tier == tierStr {
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
				if deposit.rewardClaimAt != 0 {
					println("(N)th claim")
					toUser += deposit.rewardAmount
				} else {
					claimableAfter := uint64(0)
					switch deposit.tier {
					case "30":
						claimableAfter = project.startTime + project.tier30.claimWaitDuration
					case "90":
						claimableAfter = project.startTime + project.tier90.claimWaitDuration
					case "180":
						claimableAfter = project.startTime + project.tier180.claimWaitDuration
					}

					if uint64(time.Now().Unix()) < claimableAfter {
						println("NOT CLAIMABLE YET")
						continue
					}

					println("token:", project.tokenPath, "reward:", deposit.rewardAmount)
					toUser += deposit.rewardAmount
				}
			}
		}

		// update project
		project.totalClaimedAmount += deposit.rewardAmount
		projects[deposit.projectId] = project

		// update deposit
		deposit.rewardAmount = 0
		deposit.rewardClaimHeight = uint64(std.GetHeight())
		deposit.rewardClaimAt = uint64(time.Now().Unix())
		deposits[depositId] = deposit
	}

	// transfer reward to user
	transferByRegisterCall(project.tokenPath, std.GetOrigCaller(), toUser)

	// XXX: emit event

	return toUser
}

func ClaimRewardByDepositId(depositId string) uint64 {
	deposit, exist := deposits[depositId]
	if !exist {
		panic("deposit not found")
	}

	project, exist := projects[deposit.projectId]
	if !exist {
		println("NO PROJECT FOR THIS ID", deposit.projectId)
		return 0
	}

	callerStr := std.GetOrigCaller().String()
	if _, exist := depositsByUserByProject[callerStr]; !exist {
		println("NO DEPOSIT FOR THIS USER", callerStr)
		return 0
	}

	calculateDepositReward()

	toUser := uint64(0)

	if deposit.rewardAmount > 0 {
		if deposit.rewardClaimAt != 0 {
			println("(N)th claim")
			toUser += deposit.rewardAmount
		} else {
			claimableAfter := uint64(0)
			switch deposit.tier {
			case "30":
				claimableAfter = project.startTime + project.tier30.claimWaitDuration
			case "90":
				claimableAfter = project.startTime + project.tier90.claimWaitDuration
			case "180":
				claimableAfter = project.startTime + project.tier180.claimWaitDuration
			}

			if uint64(time.Now().Unix()) < claimableAfter {
				println("NOT CLAIMABLE YET")
				continue
			}

			println("token:", project.tokenPath, "reward:", deposit.rewardAmount)
			toUser += deposit.rewardAmount
		}

		// update project
		project.totalClaimedAmount += deposit.rewardAmount
		projects[deposit.projectId] = project

		// update deposit
		deposit.rewardAmount = 0
		deposit.rewardClaimHeight = uint64(std.GetHeight())
		deposit.rewardClaimAt = uint64(time.Now().Unix())
		deposits[depositId] = deposit
	}

	// transfer reward to user
	transferByRegisterCall(project.tokenPath, std.GetOrigCaller(), toUser)

	// XXX: emit event

	return toUser
}

var lastCalculateHeightForProjectTier = make(map[string]uint64)    // using height
var lastCalculateTimestampForProjectTier = make(map[string]uint64) // using time

// amount of project token for each deposit will be calculated
func calculateDepositReward() {
	// println(">>> calculateDepositReward")
	height := uint64(std.GetHeight())
	now := uint64(time.Now().Unix())

	if height == lastCalculatedHeight {
		println("THIS BLOCK ALREADY CALCULATED", height)
		return
	}
	lastCalculatedHeight = height

	for projectIdx, project := range projects {
		// // loop with project
		// println("projectIdx", projectIdx)
		// println("project.id", project.id)

		// // early return if not active
		// println("project.startTime\t", project.startTime)
		// println("now\t\t\t", now)
		if project.startTime > now {
			// println("PROJECT NOT STARTED")
			continue
		}

		// println("LAST CALC PROJECT TIER 30", project.tier30.id)
		// println("lastCalculateTimestampForProjectTier[project.tier30.id]", lastCalculateTimestampForProjectTier[project.tier30.id])
		if lastCalculateTimestampForProjectTier[project.tier30.id] == 0 {
			// println(" > INIT TO `project.startTime`", project.startTime)
			lastCalculateTimestampForProjectTier[project.tier30.id] = project.startTime
		}

		// println("LAST CALC PROJECT TIER 90", project.tier90.id)
		// println("lastCalculateTimestampForProjectTier[project.tier90.id]", lastCalculateTimestampForProjectTier[project.tier90.id])
		if lastCalculateTimestampForProjectTier[project.tier90.id] == 0 {
			// println(" > INIT TO `project.startTime`", project.startTime)
			lastCalculateTimestampForProjectTier[project.tier90.id] = project.startTime
		}

		// println("LAST CALC PROJECT TIER 180", project.tier180.id)
		// println("lastCalculateTimestampForProjectTier[project.tier180.id]", lastCalculateTimestampForProjectTier[project.tier180.id])
		if lastCalculateTimestampForProjectTier[project.tier180.id] == 0 {
			// println(" > INIT TO `project.startTime`", project.startTime)
			lastCalculateTimestampForProjectTier[project.tier180.id] = project.startTime
		}

		// if current time is greater than endTime, then use endTime
		endTimeFor30 := minU64(now, project.startTime+TIMESTAMP_30DAYS)
		endTimeFor90 := minU64(now, project.startTime+TIMESTAMP_90DAYS)
		endTimeFor180 := minU64(now, project.startTime+TIMESTAMP_180DAYS)

		sinceLast30 := endTimeFor30 - lastCalculateTimestampForProjectTier[project.tier30.id]
		sinceLast90 := endTimeFor90 - lastCalculateTimestampForProjectTier[project.tier90.id]
		sinceLast180 := endTimeFor180 - lastCalculateTimestampForProjectTier[project.tier180.id]
		lastCalculateTimestampForProjectTier[project.tier30.id] = now
		lastCalculateTimestampForProjectTier[project.tier90.id] = now
		lastCalculateTimestampForProjectTier[project.tier180.id] = now

		rewardX96_30 := new(u256.Uint).Mul(project.tier30.tierAmountPerSecondX96, u256.NewUint(sinceLast30))
		rewardX96_90 := new(u256.Uint).Mul(project.tier90.tierAmountPerSecondX96, u256.NewUint(sinceLast90))
		rewardX96_180 := new(u256.Uint).Mul(project.tier180.tierAmountPerSecondX96, u256.NewUint(sinceLast180))

		// calculate deposit ratio
		// loop with each tier (30 90 180)
		tier30Deposit := project.tier30.depositAmount
		tier90Deposit := project.tier90.depositAmount
		tier180Deposit := project.tier180.depositAmount
		// println("tier30.id", project.tier30.id)
		// println("tier30Deposit", tier30Deposit)
		// println("tier90Deposit", tier90Deposit)
		// println("tier180Deposit", tier180Deposit)

		// iterate deposit (by project)
		depositWithTier, exist := depositsByProject[project.id]
		if !exist {
			// println("NO DEPOSIT FOR THIS PROJECT", project.id)
			return
		}

		for tierStr, depositIds := range depositWithTier {
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
				}
				if sinceLast == 0 {
					// println("NO BLOCK PASSED SINCE LAST CALCULATION")
					continue
				}

				// calculate reward
				ratioX96 := calcDepositRatioX96(tierAmount, deposit.amount)
				depositRewardX96X96 := u256.Zero().Mul(rewardX96, ratioX96)
				depositRewardX96 := u256.Zero().Div(depositRewardX96X96, q96)
				depositRewardX := u256.Zero().Div(depositRewardX96, q96)
				depoistReward := depositRewardX.Uint64()
				// println("depoistReward:", depoistReward)

				// println("B_deposit.rewardAmount", deposit.rewardAmount)
				deposit.rewardAmount += depoistReward
				// println("A_deposit.rewardAmount", deposit.rewardAmount)

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

func GetClaimableReward() string { // return in json format
	// for each deposit
	panic("TODO")
}
