package launchpad

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/common"

	en "gno.land/r/gnoswap/v1/emission"
	gs "gno.land/r/gnoswap/v1/gov/staker"
)

// CollectProtocolFee collects protocol fee from gov/staker
// each project's recipient wallet will be rewarded
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_reward.gno#collectprotocolfee
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
// Returns collected reward amount
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_reward.gno#collectrewardbyprojectid
func CollectRewardByProjectId(projectId string) uint64 {
	common.IsHalted()
	en.MintAndDistributeGns()

	project, exist := projects[projectId]
	if !exist {
		return 0
	}

	calculateDepositReward()
	project = projects[projectId] // get updates project

	caller := std.PrevRealm().Addr()
	if _, exist := depositsByUserByProject[caller]; !exist {
		return 0
	}
	depositIds, exist := depositsByUserByProject[caller][projectId]
	if !exist {
		return 0
	}

	prevAddr, prevRealm := getPrev()

	toUser := uint64(0)
	for _, depositId := range depositIds {
		deposit := deposits[depositId]
		if deposit.rewardAmount == 0 {
			continue
		}

		project := projects[deposit.projectId]
		if project.id != projectId {
			continue
		}

		if deposit.rewardAmount > 0 {
			if deposit.rewardCollectTime != 0 {
				toUser += deposit.rewardAmount
			} else {
				if uint64(std.GetHeight()) < deposit.claimableHeight {
					continue
				}
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

			// update project
			project.totalCollectedAmount += deposit.rewardAmount

			var tier Tier
			switch deposit.tier {
			case "30":
				tier = project.tier30
				tier.userCollectedAmount += deposit.rewardAmount
			case "90":
				tier = project.tier90
				tier.userCollectedAmount += deposit.rewardAmount
			case "180":
				tier = project.tier180
				tier.userCollectedAmount += deposit.rewardAmount
			}
			project = setTier(project, deposit.tier, tier)

			// update deposit
			deposit.rewardCollected += deposit.rewardAmount
			deposit.rewardAmount = 0
			deposit.rewardCollectHeight = uint64(std.GetHeight())
			deposit.rewardCollectTime = uint64(time.Now().Unix())
			deposits[depositId] = deposit

			// save updated project
			projects[projectId] = project
		}
	}

	// transfer reward to user
	transferByRegisterCall(project.tokenPath, std.PrevRealm().Addr(), toUser)

	return toUser
}

// CollectRewardByDepositId collects reward from certain deposit by caller
// Returns collected reward amount
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_reward.gno#collectrewardbydepositid
func CollectRewardByDepositId(depositId string) uint64 {
	deposit, exist := deposits[depositId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("launchpad_reward.gno__CollectRewardByDepositId() || depositId(%s) not found", depositId),
		))
	}

	common.IsHalted()
	en.MintAndDistributeGns()

	project, exist := projects[deposit.projectId]
	if !exist {
		return 0
	}

	caller := std.PrevRealm().Addr()
	if _, exist := depositsByUserByProject[caller]; !exist {
		return 0
	}

	calculateDepositReward()
	project = projects[deposit.projectId] // get updates project
	deposit = deposits[depositId]         // get updated deposit

	toUser := uint64(0)

	if deposit.rewardAmount > 0 {
		if deposit.rewardCollectTime != 0 {
			toUser += deposit.rewardAmount
		} else {
			if uint64(std.GetHeight()) < deposit.claimableHeight {
				return 0
			}

			toUser += deposit.rewardAmount
		}

		prevAddr, prevRealm := getPrev()
		std.Emit(
			"CollectRewardByDepositId",
			"prevAddr", prevAddr,
			"prevRealm", prevRealm,
			"depositId", depositId,
			"internal_amount", ufmt.Sprintf("%d", deposit.rewardAmount),
		)

		// update project
		project.totalCollectedAmount += deposit.rewardAmount
		tierStr := deposit.tier
		switch tierStr {
		case "30":
			project.tier30.userCollectedAmount += deposit.rewardAmount
		case "90":
			project.tier90.userCollectedAmount += deposit.rewardAmount
		case "180":
			project.tier180.userCollectedAmount += deposit.rewardAmount
		}

		projects[deposit.projectId] = project

		// update deposit
		deposit.rewardCollected += deposit.rewardAmount
		deposit.rewardAmount = 0
		deposit.rewardCollectHeight = uint64(std.GetHeight())
		deposit.rewardCollectTime = uint64(time.Now().Unix())
		deposits[depositId] = deposit
	}

	// transfer reward to user
	transferByRegisterCall(project.tokenPath, std.PrevRealm().Addr(), toUser)

	return toUser
}

var lastCalculateHeightForProjectTier = make(map[string]uint64) // using height

// amount of project token for each deposit will be calculated
func calculateDepositReward() {
	height := uint64(std.GetHeight())

	if height == lastCalculatedHeight {
		return
	}
	lastCalculatedHeight = height

	for _, project := range projects {
		// early return if not active
		if project.startHeight > height {
			continue
		}

		// skip project if no deposit
		if project.actualParticipant == 0 {
			continue
		}

		// iterate deposit (by project)
		depositWithTier, exist := depositsByProject[project.id]
		if !exist {
			return
		}

		tier30AmountPerBlockX96 := project.tier30.tierAmountPerBlockX96.NilToZero().Clone()
		tier90AmountPerBlockX96 := project.tier90.tierAmountPerBlockX96.NilToZero().Clone()
		tier180AmountPerBlockX96 := project.tier180.tierAmountPerBlockX96.NilToZero().Clone()

		if (lastCalculateHeightForProjectTier[project.tier30.id] == 0) && (!tier30AmountPerBlockX96.IsZero()) {
			lastCalculateHeightForProjectTier[project.tier30.id] = project.tier30.startHeight
		}
		if (lastCalculateHeightForProjectTier[project.tier90.id] == 0) && (!tier90AmountPerBlockX96.IsZero()) {
			lastCalculateHeightForProjectTier[project.tier90.id] = project.tier90.startHeight
		}
		if (lastCalculateHeightForProjectTier[project.tier180.id] == 0) && (!tier180AmountPerBlockX96.IsZero()) {
			lastCalculateHeightForProjectTier[project.tier180.id] = project.tier180.startHeight
		}

		// if current height is greater than endHeight, then use endHeight as project's each tier's endHeight
		endHeightFor30 := minU64(height, project.tier30.endHeight)
		endHeightFor90 := minU64(height, project.tier90.endHeight)
		endHeightFor180 := minU64(height, project.tier180.endHeight)

		// if last calculate height is greater than endHeight, then use endHeight to calculate duration
		sinceLast30 := endHeightFor30 - minU64(endHeightFor30, lastCalculateHeightForProjectTier[project.tier30.id])
		sinceLast90 := endHeightFor90 - minU64(endHeightFor90, lastCalculateHeightForProjectTier[project.tier90.id])
		sinceLast180 := endHeightFor180 - minU64(endHeightFor180, lastCalculateHeightForProjectTier[project.tier180.id])

		// update for next calc ( only when tier is started )
		if project.tier30.startHeight != 0 {
			lastCalculateHeightForProjectTier[project.tier30.id] = height
		}
		if project.tier90.startHeight != 0 {
			lastCalculateHeightForProjectTier[project.tier90.id] = height
		}
		if project.tier180.startHeight != 0 {
			lastCalculateHeightForProjectTier[project.tier180.id] = height
		}

		// reward for each tier
		rewardX96_30 := new(u256.Uint).Mul(project.tier30.tierAmountPerBlockX96.NilToZero(), u256.NewUint(sinceLast30))
		rewardX96_90 := new(u256.Uint).Mul(project.tier90.tierAmountPerBlockX96.NilToZero(), u256.NewUint(sinceLast90))
		rewardX96_180 := new(u256.Uint).Mul(project.tier180.tierAmountPerBlockX96.NilToZero(), u256.NewUint(sinceLast180))

		// update each tier's calculated amount
		reward_30 := new(u256.Uint).Div(rewardX96_30, q96).Uint64()
		reward_90 := new(u256.Uint).Div(rewardX96_90, q96).Uint64()
		reward_180 := new(u256.Uint).Div(rewardX96_180, q96).Uint64()

		project.tier30.calculatedAmount += reward_30
		project.tier90.calculatedAmount += reward_90
		project.tier180.calculatedAmount += reward_180

		tier30Deposit := project.tier30.actualDepositAmount
		tier90Deposit := project.tier90.actualDepositAmount
		tier180Deposit := project.tier180.actualDepositAmount

		for tierStr, depositIds := range depositWithTier {
			tierAmount := uint64(0)
			var rewardX96 *u256.Uint

			switch tierStr {
			case "30":
				if tier30AmountPerBlockX96.IsZero() {
					continue
				}
				tierAmount = tier30Deposit
			case "90":
				if tier90AmountPerBlockX96.IsZero() {
					continue
				}
				tierAmount = tier90Deposit
			case "180":
				if tier180AmountPerBlockX96.IsZero() {
					continue
				}
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
					panic(addDetailToError(
						errInvalidTier,
						ufmt.Sprintf("launchpad_reward.gno__calculateDepositReward() || invalid tier(%s)", deposit.tier),
					))
				}
				if sinceLast == 0 {
					continue
				}

				// calculate reward
				ratioX96 := calcDepositRatioX96(tierAmount, deposit.amount)
				depositRewardX96X96 := u256.Zero().Mul(rewardX96, ratioX96)
				depositRewardX96 := u256.Zero().Div(depositRewardX96X96, q96)
				depositRewardX := u256.Zero().Div(depositRewardX96, q96)
				depoistReward := depositRewardX.Uint64()
				deposit.rewardAmount += depoistReward

				// update deposit
				deposits[depositId] = deposit
			}
		}

		// update project
		projects[project.id] = project
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

func calcProjectTiersRewardPerBlockX96(tier Tier) *u256.Uint {
	tierAmountX96 := new(u256.Uint).Mul(u256.NewUint(tier.tierAmount), q96)
	tierAmountPerBlockX96 := new(u256.Uint).Div(tierAmountX96, u256.NewUint(tier.endHeight-tier.startHeight))

	return tierAmountPerBlockX96
}
