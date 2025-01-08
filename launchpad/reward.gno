package launchpad

import (
	"errors"
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v1/common"
	en "gno.land/r/gnoswap/v1/emission"
	gs "gno.land/r/gnoswap/v1/gov/staker"
)

var (
	lastCalculatedHeight              uint64
	lastCalculateHeightForProjectTier = make(map[string]uint64) // using height
)

func init() {
	lastCalculatedHeight = uint64(std.GetHeight())
}

// RewardCalculationResult represents the result of reward calculation
type RewardCalculationResult struct {
	Reward       uint64
	UpdatedTiers map[string]Tier
}

// CollectProtocolFee collects protocol fee from gov/staker
// each project's recipient wallet will be rewarded
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_reward.gno#collectprotocolfee
func CollectProtocolFee() {
	caller := std.PrevRealm().Addr()
	gs.CollectRewardFromLaunchPad(caller)
}

// validateRewardCollection validates if reward can be collected
func validateRewardCollection(deposit Deposit, height uint64) error {
	if deposit.rewardCollectTime == 0 && height < deposit.claimableHeight {
		return errors.New("reward not yet claimable")
	}

	return nil
}

// calculateTierRewards calculates rewards for each tier
func calculateTierRewards(tier Tier, currentHeight uint64, lastCalcHeight uint64) (*u256.Uint, uint64, error) {
	if tier.tierAmountPerBlockX96 == nil {
		return u256.Zero(), 0, nil
	}

	if tier.tierAmountPerBlockX96.IsZero() {
		return u256.Zero(), 0, nil
	}

	endHeight := minU64(currentHeight, tier.ended.height)
	sinceLast := endHeight - minU64(endHeight, lastCalcHeight)

	if sinceLast == 0 {
		return u256.Zero(), 0, nil
	}

	rewardX96 := new(u256.Uint).Mul(tier.tierAmountPerBlockX96.NilToZero().Clone(), u256.NewUint(sinceLast))
	reward := new(u256.Uint).Div(rewardX96, q96).Uint64()

	return rewardX96, reward, nil
}

/*
// processDepositReward processes reward for a single deposit
func processDepositReward(deposit Deposit, rewardX96 *u256.Uint, tierAmount uint64) (Deposit, error) {
	if tierAmount == 0 {
		return deposit, errors.New("invalid tier amount")
	}

	ratioX96 := calcDepositRatioX96(tierAmount, deposit.amount)
	depositRewardX96X96 := u256.Zero().Mul(rewardX96.Clone(), ratioX96)
	depositRewardX96 := u256.Zero().Div(depositRewardX96X96, q96)
	depositRewardX := u256.Zero().Div(depositRewardX96, q96)
	depositReward := depositRewardX.Uint64()

	deposit.rewardAmount += depositReward
	return deposit, nil
}
*/
// CollectRewardByProjectId collects reward from entire deposit of certain project by caller
// Returns collected reward amount
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_reward.gno#collectrewardbyprojectid
func CollectRewardByProjectId(projectId string) uint64 {
	common.IsHalted()
	en.MintAndDistributeGns()

	project, exists := projects[projectId]
	if !exists {
		return 0
	}

	project = projects[projectId] // get updated project

	caller := std.PrevRealm().Addr()
	depositIds, exists := depositsByUserByProject[caller][projectId]
	if !exists {
		return 0
	}

	height := uint64(std.GetHeight())
	totalReward := uint64(0) // toUser
	prevAddr, prevPkgPath := getPrev()

	for _, depositId := range depositIds {
		deposit := deposits[depositId]
		reward := rewardStates.Get(deposit.projectId, deposit.tier).Claim(depositId, height)
		if reward == 0 {
			continue
		}

		project := projects[deposit.projectId]
		if project.id != projectId {
			continue
		}

		if err := validateRewardCollection(deposit, height); err != nil {
			continue
		}

		totalReward += reward

		std.Emit(
			"CollectRewardByProjectId",
			"prevAddr", prevAddr,
			"prevRealm", prevPkgPath,
			"projectId", projectId,
			"depositId", depositId,
			"amount", strconv.FormatUint(reward, 10),
		)

		// Update project and tier stats
		project.stats.totalCollected += reward

		var tier Tier
		switch deposit.tier {
		case "30":
			tier = project.tiers[30]
			tier.userCollectedAmount += reward
		case "90":
			tier = project.tiers[90]
			tier.userCollectedAmount += reward
		case "180":
			tier = project.tiers[180]
			tier.userCollectedAmount += reward
		}
		project = setTier(project, deposit.tier, tier)

		// Update deposit
		deposit.rewardCollected += reward
		deposit.rewardCollectHeight = height
		deposit.rewardCollectTime = uint64(time.Now().Unix())
		deposits[depositId] = deposit
	}

	projects[projectId] = project

	if totalReward > 0 {
		tokenTeller := common.GetTokenTeller(project.tokenPath)
		tokenTeller.Transfer(caller, totalReward)
	}

	return totalReward
}

// CollectRewardByDepositId collects reward from certain deposit by caller
// Returns collected reward amount
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_reward.gno#collectrewardbydepositid
func CollectRewardByDepositId(depositId string) uint64 {
	common.IsHalted()

	deposit, exists := deposits[depositId]
	if !exists {
		panic(ufmt.Sprintf("depositId(%s) not found", depositId))
	}
	en.MintAndDistributeGns()

	project, exists := projects[deposit.projectId]
	if !exists {
		return 0
	}

	caller := std.PrevRealm().Addr()
	if _, exists := depositsByUserByProject[caller]; !exists {
		return 0
	}

	project = projects[deposit.projectId]
	deposit = deposits[depositId]

	height := uint64(std.GetHeight())
	if err := validateRewardCollection(deposit, height); err != nil {
		return 0
	}

	reward := rewardStates.Get(deposit.projectId, deposit.tier).Claim(deposit.id, height)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"CollectRewardByDepositId",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"depositId", depositId,
		"amount", strconv.FormatUint(reward, 10),
	)

	// Update project
	project.stats.totalCollected += reward
	switch deposit.tier {
	case "30":
		t := project.tiers[30]
		t.userCollectedAmount += reward
	case "90":
		t := project.tiers[90]
		t.userCollectedAmount += reward
	case "180":
		t := project.tiers[180]
		t.userCollectedAmount += reward
	}
	projects[deposit.projectId] = project

	// Update deposit
	deposit.rewardCollected += reward
	deposit.rewardCollectHeight = height
	deposit.rewardCollectTime = uint64(time.Now().Unix())
	deposits[depositId] = deposit

	// Transfer reward
	if reward > 0 {
		tokenTeller := common.GetTokenTeller(project.tokenPath)
		tokenTeller.Transfer(caller, reward)
	}

	return reward
}

/*
// calculateProjectRewards calculates rewards for a project's deposits
func calculateProjectRewards(project Project, height uint64) (Project, error) {
	if project.started.height > height || project.stats.actualParticipant == 0 {
		return project, nil
	}

	depositWithTier, exists := depositsByProject[project.id]
	if !exists {
		return project, nil
	}

	tier30 := project.tiers[30]
	tier90 := project.tiers[90]
	tier180 := project.tiers[180]

	// Initialize tier calculations
	for _, tier := range []struct {
		id     string
		amount *u256.Uint
		start  uint64
	}{
		{tier30.id, tier30.tierAmountPerBlockX96.NilToZero(), tier30.started.height},
		{tier90.id, tier90.tierAmountPerBlockX96.NilToZero(), tier90.started.height},
		{tier180.id, tier180.tierAmountPerBlockX96.NilToZero(), tier180.started.height},
	} {
		if lastCalculateHeightForProjectTier[tier.id] == 0 && !tier.amount.IsZero() {
			lastCalculateHeightForProjectTier[tier.id] = tier.start
		}
	}

	// Calculate rewards for each tier
	tier30RewardX96, reward30, _ := calculateTierRewards(tier30, height,
		lastCalculateHeightForProjectTier[tier30.id])
	tier90RewardX96, reward90, _ := calculateTierRewards(tier90, height,
		lastCalculateHeightForProjectTier[tier90.id])
	tier180RewardX96, reward180, _ := calculateTierRewards(tier180, height,
		lastCalculateHeightForProjectTier[tier180.id])

	// Update project tiers
	tier30.calculatedAmount += reward30
	tier90.calculatedAmount += reward90
	tier180.calculatedAmount += reward180

	// Process deposits for each tier
	for tierStr, depositIds := range depositWithTier {
		var (
			tierAmount uint64
			rewardX96  *u256.Uint
		)

		switch tierStr {
		case "30":
			tierAmount = tier30.actualDepositAmount
			rewardX96 = tier30RewardX96
		case "90":
			tierAmount = tier90.actualDepositAmount
			rewardX96 = tier90RewardX96
		case "180":
			tierAmount = tier180.actualDepositAmount
			rewardX96 = tier180RewardX96
		}

		for _, depositId := range depositIds {
			deposit := deposits[depositId]
			updatedDeposit, err := processDepositReward(deposit, rewardX96, tierAmount)
			if err != nil {
				continue
			}
			deposits[depositId] = updatedDeposit
		}
	}

	// Update calculation heights
	if tier30.started.height != 0 {
		lastCalculateHeightForProjectTier[tier30.id] = height
	}
	if tier90.started.height != 0 {
		lastCalculateHeightForProjectTier[tier90.id] = height
	}
	if tier180.started.height != 0 {
		lastCalculateHeightForProjectTier[tier180.id] = height
	}

	return project, nil
}

func calculateDepositReward() {
	height := uint64(std.GetHeight())

	if height == lastCalculatedHeight {
		return
	}
	lastCalculatedHeight = height
	for projectId, project := range projects {
		updatedProject, err := calculateProjectRewards(project, height)
		if err != nil {
			continue
		}
		projects[projectId] = updatedProject
	}
}
*/
// calcDepositRatioX96 calculates the deposit ratio with Q96 precision
func calcDepositRatioX96(tierAmount uint64, amount uint64) *u256.Uint {
	amountX96 := new(u256.Uint).Mul(u256.NewUint(amount), q96.Clone())
	amountX96x := new(u256.Uint).Mul(amountX96, u256.NewUint(1_000_000_000))

	tierAmountX96 := new(u256.Uint).Mul(u256.NewUint(tierAmount), q96.Clone())

	depositRatioX96 := new(u256.Uint).Div(amountX96x, tierAmountX96)
	depositRatioX96 = depositRatioX96.Mul(depositRatioX96, q96.Clone())
	depositRatioX96 = depositRatioX96.Div(depositRatioX96, u256.NewUint(1_000_000_000))

	return depositRatioX96
}

// calcProjectTiersRewardPerBlockX96 calculates the reward per block with Q96 precision
func calcProjectTiersRewardPerBlockX96(tier Tier) *u256.Uint {
	tierAmountX96 := new(u256.Uint).Mul(u256.NewUint(tier.tierAmount), q96)
	return new(u256.Uint).Div(tierAmountX96, u256.NewUint(tier.ended.height-tier.started.height))
}
