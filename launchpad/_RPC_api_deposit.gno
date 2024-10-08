package launchpad

import (
	"std"
)

func ApiGetClaimableDepositByAddress(address std.Address) uint64 {
	if !address.IsValid() {
		return 0
	}

	gnsToUser := uint64(0)
	for _, depositId := range depositsByUser[address] {
		deposit := deposits[depositId]

		project, exist := projects[deposit.projectId]
		if !exist {
			continue
		}

		tier := getTier(project, deposit.tier)
		if checkTierActive(project, tier) {
			continue
		}

		if deposit.depositCollectHeight != 0 {
			continue
		}

		gnsToUser += deposit.amount // not reward amount, but deposit amount
	}

	return gnsToUser
}
