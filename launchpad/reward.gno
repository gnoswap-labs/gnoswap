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
	caller := getPrevAddr()
	gs.CollectRewardFromLaunchPad(caller)
}

// CollectRewardByProjectId collects reward from entire deposit of certain project by caller
// Returns collected reward amount
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_reward.gno#collectrewardbyprojectid
func CollectRewardByProjectId(projectId string) uint64 {
	assertOnlyNotHalted()
	en.MintAndDistributeGns()

	project, exists := projects[projectId]
	if !exists {
		panic(addDetailToError(
			errInvalidProjectId, ufmt.Sprintf("projectId(%s) not found", projectId)))
	}

	caller := getPrevAddr()
	depositIds, exists := depositsByUserByProject[caller][projectId]
	if !exists {
		panic(addDetailToError(
			errNotExistDeposit, ufmt.Sprintf("depositId (%s) not found", projectId)))
	}

	currentHeight := uint64(std.GetHeight())
	totalReward := uint64(0) // toUser
	prevAddr, prevPkgPath := getPrev()

	for _, depositId := range depositIds {
		deposit, ok := deposits[depositId]
		if !ok {
			//continue
			panic(addDetailToError(
				errNotExistDeposit, ufmt.Sprintf("depositId (%s) not found", depositId)))
		}

		rewardState, err := rewardStates.Get(deposit.projectId, deposit.tier)
		if err != nil {
			continue
		}

		reward := rewardState.Claim(depositId, currentHeight)
		if reward == 0 {
			println("E: continue")
			continue
		}

		pjt := projects[deposit.projectId]
		if pjt.id != projectId {
			panic(addDetailToError(
				errInvalidProjectId, ufmt.Sprintf("projectId(%s) not matched", projectId)))
		}

		if err = validateRewardCollection(deposit, currentHeight); err != nil {
			panic(err.Error())
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
			tier = project.tiers[TIER30]
			tier.userCollectedAmount += reward
		case "90":
			tier = project.tiers[TIER90]
			tier.userCollectedAmount += reward
		case "180":
			tier = project.tiers[TIER180]
			tier.userCollectedAmount += reward
		}
		project = setTier(project, deposit.tier, tier)

		// Update deposit
		deposit.rewardCollected += reward
		deposit.rewardCollectHeight = currentHeight
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
	assertOnlyNotHalted()

	deposit, exists := deposits[depositId]
	if !exists {
		panic(ufmt.Sprintf("depositId(%s) not found", depositId))
	}
	en.MintAndDistributeGns()

	project, exists := projects[deposit.projectId]
	if !exists {
		panic(addDetailToError(errInvalidProjectId, ufmt.Sprintf("projectId(%s) not found", deposit.projectId)))
	}

	caller := getPrevAddr()
	if _, exists := depositsByUserByProject[caller]; !exists {
		panic(addDetailToError(errInvalidCaller, ufmt.Sprintf("caller(%s) not found", caller)))
	}

	project = projects[deposit.projectId]
	deposit = deposits[depositId]

	height := uint64(std.GetHeight())
	if err := validateRewardCollection(deposit, height); err != nil {
		panic(err.Error())
	}

	rewardState, err := rewardStates.Get(deposit.projectId, deposit.tier)
	if err != nil {
		panic(addDetailToError(
			errInvalidInput, err.Error()))
	}
	reward := rewardState.Claim(deposit.id, height)

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
		t := project.tiers[TIER30]
		t.userCollectedAmount += reward
	case "90":
		t := project.tiers[TIER90]
		t.userCollectedAmount += reward
	case "180":
		t := project.tiers[TIER180]
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

// validateRewardCollection validates if reward can be collected
func validateRewardCollection(deposit Deposit, height uint64) error {
	caller := getPrevAddr()
	if err := validateRewardOwner(deposit.id, caller); err != nil {
		return err
	}

	if err := validateRewardClaimable(deposit, height); err != nil {
		return err
	}
	return nil
}

// calculateTierRewards calculates rewards for each tier
func calculateTierRewards(tier Tier, currentHeight uint64, lastCalcHeight uint64) (*u256.Uint, uint64, error) {
	if tier.tierAmountPerBlockX128 == nil {
		return u256.Zero(), 0, nil
	}

	if tier.tierAmountPerBlockX128.IsZero() {
		return u256.Zero(), 0, nil
	}

	endHeight := minU64(currentHeight, tier.ended.height)
	sinceLast := endHeight - minU64(endHeight, lastCalcHeight)

	if sinceLast == 0 {
		return u256.Zero(), 0, nil
	}

	rewardX128 := new(u256.Uint).Mul(tier.tierAmountPerBlockX128.NilToZero().Clone(), u256.NewUint(sinceLast))
	reward := new(u256.Uint).Div(rewardX128, q128).Uint64()

	return rewardX128, reward, nil
}

// calcDepositRatioX128 calculates the deposit ratio with Q128 precision
func calcDepositRatioX128(tierAmount uint64, amount uint64) *u256.Uint {
	println("tierAmount", tierAmount)
	amountX128 := new(u256.Uint).Mul(u256.NewUint(amount), q128.Clone())
	amountX128x := new(u256.Uint).Mul(amountX128, u256.NewUint(1_000_000_000))
	println("amountX128x", amountX128x.ToString())

	tierAmountX128 := new(u256.Uint).Mul(u256.NewUint(tierAmount), q128.Clone())
	println("tierAmountX128", tierAmountX128.ToString())

	depositRatioX96 := new(u256.Uint).Div(amountX128x, tierAmountX128)
	println("depositRatioX96", depositRatioX96.ToString())
	depositRatioX96 = new(u256.Uint).Mul(depositRatioX96, q128.Clone())
	depositRatioX96 = new(u256.Uint).Div(depositRatioX96, u256.NewUint(1_000_000_000))
	println("depositRatioX96", depositRatioX96.ToString())

	return depositRatioX96
}

// calcProjectTiersRewardPerBlockX96 calculates the reward per block with Q96 precision
func calcProjectTiersRewardPerBlockX128(tier Tier) *u256.Uint {
	tierAmountX128 := new(u256.Uint).Mul(u256.NewUint(tier.tierAmount), q128)
	return new(u256.Uint).Div(tierAmountX128, u256.NewUint(tier.ended.height-tier.started.height))
}

// calcRewardPerBlockX128 calculates the reward per block with Q128 precision
func calcRewardPerBlockX128(tierAmount uint64, duration uint64) *u256.Uint {
	tierAmountX128 := new(u256.Uint).Mul(u256.NewUint(tierAmount), q128)
	return new(u256.Uint).Div(tierAmountX128, u256.NewUint(duration))
}

// validateRewardOwner checks if the deposit is truly owned by `caller`.
func validateRewardOwner(depositId string, caller std.Address) error {
	dep, ok := deposits[depositId]
	if !ok {
		return errors.New(addDetailToError(errNotExistDeposit, ufmt.Sprintf("depositId(%s)", depositId)))
	}
	projMap, userHasProject := depositsByUserByProject[caller]
	if !userHasProject {
		return errors.New(addDetailToError(errInvalidCaller, ufmt.Sprintf("caller(%s) not found", caller)))
	}
	depositIds, userHasDeposits := projMap[dep.projectId]
	if !userHasDeposits {
		return errors.New(addDetailToError(errNotExistDeposit, ufmt.Sprintf("caller(%s) no deposit for project(%s)", caller, dep.projectId)))
	}
	if !containsString(depositIds, depositId) {
		return errors.New(addDetailToError(errInvalidOwner, ufmt.Sprintf("caller(%s) does not own depositId(%s)", caller, depositId)))
	}
	return nil
}

// validateRewardClaimable checks if reward can be claimed
// e.g. deposit.claimableHeight, deposit.claimableTime
func validateRewardClaimable(deposit Deposit, currentHeight uint64) error {
	if deposit.rewardCollectTime == 0 {
		if currentHeight < deposit.claimableHeight {
			return errors.New(addDetailToError(errNotYetClaimReward, ufmt.Sprintf("need block >= %d, current=%d", deposit.claimableHeight, currentHeight)))
		}
	}
	return nil
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
