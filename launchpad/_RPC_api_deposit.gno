package launchpad

import (
	"std"
	"strings"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
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

		reward := rewardStates.Get(deposit.projectId, deposit.tier).Claim(depositId, uint64(std.GetHeight()))

		gnsToUser += reward
	}

	return gnsToUser
}

func ApiGetDepositByDepositId(depositId string) string {
    calculateDepositReward()

    deposit, exist := deposits[depositId]
    if !exist {
        return ""
    }

    builder := MetaBuilder().
        WriteString("depositId", depositId)
    DepositBuilder(builder, deposit)

    return marshal(builder.Build())
}

func ApiGetDepositFullByDepositId(depositId string) string {
    calculateDepositReward()

    deposit, exist := deposits[depositId]
    if !exist {
        return ""
    }

    project, exist := projects[deposit.projectId]
    if !exist {
        return ""
    }

    var tier Tier
    switch deposit.tier {
    case "30":
        tier = project.tiers[30]
    case "90":
        tier = project.tiers[90]
    case "180":
        tier = project.tiers[180]
    }

    builder := MetaBuilder().
        WriteString("depositId", depositId)

    // Add project info
    ProjectBuilder(builder, project)

    // Add tier info
    TierBuilder(builder, "", tier)

    // Add deposit info
    DepositBuilder(builder, deposit)

    return marshal(builder.Build())
}

func makeConditionsToStr(conditions map[string]Condition) (string, string) {
	var tokenPathList string
	var amountList string

	for tokenPath, condition := range conditions {
		// append with *PAD*, except last one
		tokenPathList += tokenPath + "*PAD*"
		amountList += ufmt.Sprintf("%d", condition.minAmount) + "*PAD*"
	}

	// remove last *PAD*
	tokenPathList = strings.TrimSuffix(tokenPathList, "*PAD*")
	amountList = strings.TrimSuffix(amountList, "*PAD*")

	return tokenPathList, amountList
}
