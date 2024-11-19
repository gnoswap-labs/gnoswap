package launchpad

import (
	"std"

	gs "gno.land/r/gnoswap/v1/gov/staker"
)

// protocol_fee reward for project's recipient
func ApiGetProjectRecipientRewardByProjectId(projectId string) string {
	calculateDepositReward()

	project, exist := projects[projectId]
	if !exist {
		return "0"
	}

	return gs.GetClaimableRewardByAddress(project.recipient)
}

func ApiGetProjectRecipientRewardByAddress(address std.Address) string {
	calculateDepositReward()

	if !address.IsValid() {
		return "0"
	}

	return gs.GetClaimableRewardByAddress(address)
}

// project reward for deposit
func ApiGetDepositRewardByDepositId(depositId string) uint64 {
	calculateDepositReward()

	deposit, exist := deposits[depositId]
	if !exist {
		return 0
	}

	return deposit.rewardAmount
}

func ApiGetDepositRewardByAddress(address std.Address) uint64 {
	calculateDepositReward()

	if !address.IsValid() {
		return 0
	}

	depositIds, exist := depositsByUser[address]
	if !exist {
		return 0
	}

	totalReward := uint64(0)
	for _, depositId := range depositIds {
		deposit, exist := deposits[depositId]
		if !exist {
			continue
		}
		totalReward += deposit.rewardAmount
	}

	return totalReward
}
