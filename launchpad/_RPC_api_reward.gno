package launchpad

import (
	"std"

	gs "gno.land/r/gnoswap/v2/gov/staker"
)

// protocol_fee reward for project's recipient
func ApiGetProjectRecipientRewardByProjectId(projectId string) string {
	project, exist := projects[projectId]
	if !exist {
		return "0"
	}

	return gs.GetClaimableRewardByAddress(project.recipient.String())
}

func ApiGetProjectRecipientRewardByAddress(address string) string {
	addr := std.Address(address)
	if !addr.IsValid() {
		return "0"
	}

	return gs.GetClaimableRewardByAddress(address)
}

// project reward for deposit
func ApiGetDepositRewardByDepositId(depositId string) uint64 {
	deposit, exist := deposits[depositId]
	if !exist {
		return 0
	}

	calculateDepositReward()
	return deposit.rewardAmount
}

func ApiGetDepositRewardByAddress(address string) uint64 {
	addr := std.Address(address)
	if !addr.IsValid() {
		return 0
	}

	depositIds, exist := depositsByUser[address]
	if !exist {
		return 0
	}

	calculateDepositReward()

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
