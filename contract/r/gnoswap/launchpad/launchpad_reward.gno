package launchpad

import (
	"std"

	"gno.land/p/demo/ufmt"
)

// CollectRewardByDepositId collects reward from certain deposit by caller
//
// Parameters:
// - depositID (string): The ID of the deposit to collect reward from.
//
// Returns:
// - int64: The amount of reward collected.
//
// Panics:
// - If the system is halted.
// - If the deposit is not found.
// - If the caller is not the owner of the deposit.
// - If the reward collection fails.
//
// ref: https://docs.gnoswap.io/contracts/launchpad/launchpad_reward.gno#collectrewardbydepositid
func CollectRewardByDepositId(cur realm, depositID string) int64 {
	previousAddress := std.PreviousRealm().Address()
	previousPkgPath := std.PreviousRealm().PkgPath()

	assertOnlyNotHalted()

	deposit, err := getDeposit(depositID)
	if err != nil {
		panic(err.Error())
	}

	if !deposit.IsOwner(previousAddress) {
		panic(makeErrorWithDetails(errInvalidOwner, ufmt.Sprintf("(%s)", previousAddress.String())).Error())
	}

	rewardAmount, err := collectDepositReward(deposit, std.ChainHeight())
	if err != nil {
		panic(err.Error())
	}

	std.Emit(
		"CollectRewardByDepositId",
		"prevAddr", previousAddress.String(),
		"prevRealm", previousPkgPath,
		"depositId", depositID,
		"amount", formatInt(rewardAmount),
	)

	return rewardAmount
}

// collectDepositReward collects reward from certain deposit
//
// Parameters:
// - deposit (Deposit): The deposit to collect reward from.
// - currentHeight (int64): The current height of the chain.
//
// Returns:
// - int64: The amount of reward collected.
// - error: If the reward collection fails, returns an error.
//
// Panics:
// - If the deposit is not found.
// - If the project tier is not found.
// - If the reward manager is not found.
// - If the reward collection fails.
func collectDepositReward(deposit *Deposit, currentHeight int64) (int64, error) {
	projectTier, err := getProjectTier(deposit.ProjectID(), deposit.Tier())
	if err != nil {
		return 0, err
	}

	rewardManager, err := getProjectTierRewardManager(projectTier.ID())
	if err != nil {
		return 0, err
	}

	err = rewardManager.updateRewardPerDepositX128(projectTier.CurrentDepositAmount(), currentHeight)
	if err != nil {
		return 0, err
	}

	rewardAmount, err := rewardManager.collectReward(deposit.ID(), currentHeight)
	if err != nil {
		return 0, err
	}

	return rewardAmount, nil
}
