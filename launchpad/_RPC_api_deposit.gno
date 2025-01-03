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
	deposit, exist := deposits[depositId]
	if !exist {
		return ""
	}

	depositObj := metaNode()
	depositObj.AppendObject("depositId", json.StringNode("depositId", depositId))
	depositObj.AppendObject("projectId", json.StringNode("projectId", deposit.projectId))
	depositObj.AppendObject("tier", json.StringNode("tier", deposit.tier))
	depositObj.AppendObject("depositor", json.StringNode("depositor", deposit.depositor.String()))
	// depositObj.AppendObject("amount", json.StringNode("amount", ufmt.Sprintf("%d", deposit.amount)))
	depositObj.AppendObject("depositHeight", json.StringNode("depositHeight", ufmt.Sprintf("%d", deposit.depositHeight)))
	depositObj.AppendObject("depositTime", json.StringNode("depositTime", ufmt.Sprintf("%d", deposit.depositTime)))
	depositObj.AppendObject("depositCollectHeight", json.StringNode("depositCollectHeight", ufmt.Sprintf("%d", deposit.depositCollectHeight)))
	depositObj.AppendObject("depositCollectTime", json.StringNode("depositCollectTime", ufmt.Sprintf("%d", deposit.depositCollectTime)))
	depositObj.AppendObject("claimableHeight", json.StringNode("claimableHeight", ufmt.Sprintf("%d", deposit.claimableHeight)))
	depositObj.AppendObject("claimableTime", json.StringNode("claimableTime", ufmt.Sprintf("%d", deposit.claimableTime)))
	depositObj.AppendObject("rewardAmount", json.StringNode("rewardAmount", ufmt.Sprintf("%d", deposit.rewardAmount)))
	depositObj.AppendObject("rewardCollected", json.StringNode("rewardCollected", ufmt.Sprintf("%d", deposit.rewardCollected)))
	depositObj.AppendObject("rewardCollectHeight", json.StringNode("rewardCollectHeight", ufmt.Sprintf("%d", deposit.rewardCollectHeight)))
	depositObj.AppendObject("rewardCollectTime", json.StringNode("rewardCollectTime", ufmt.Sprintf("%d", deposit.rewardCollectTime)))

	return marshal(depositObj)
}

func ApiGetDepositFullByDepositId(depositId string) string {
	deposit, exist := deposits[depositId]
	if !exist {
		return ""
	}

	project, exist := projects[deposit.projectId]
	if !exist {
		return ""
	}

	var tier Tier
	tierStr := deposit.tier
	switch tierStr {
	case "30":
		tier = project.tiers[30]
	case "90":
		tier = project.tiers[90]
	case "180":
		tier = project.tiers[180]
	}

	depositObj := metaNode()
	depositObj.AppendObject("depositId", json.StringNode("depositId", depositId))

	// project info
	depositObj.AppendObject("projectId", json.StringNode("projectId", deposit.projectId))
	depositObj.AppendObject("tokenPath", json.StringNode("tokenPath", project.tokenPath))
	depositObj.AppendObject("depositAmount", json.StringNode("depositAmount", ufmt.Sprintf("%d", project.depositAmount)))
	depositObj.AppendObject("recipient", json.StringNode("recipient", project.recipient.String()))
	tokenPathList, amountList := makeConditionsToStr(project.conditions)
	depositObj.AppendObject("conditionsToken", json.StringNode("conditionsToken", tokenPathList))
	depositObj.AppendObject("conditionsAmount", json.StringNode("conditionsAmount", amountList))

	depositObj.AppendObject("tier30Ratio", json.StringNode("tier30Ratio", ufmt.Sprintf("%d", project.tiers[30].tierAmount)))
	depositObj.AppendObject("tier90Ratio", json.StringNode("tier90Ratio", ufmt.Sprintf("%d", project.tiers[90].tierAmount)))
	depositObj.AppendObject("tier180Ratio", json.StringNode("tier180Ratio", ufmt.Sprintf("%d", project.tiers[180].tierAmount)))

	depositObj.AppendObject("createdHeight", json.StringNode("createdHeight", ufmt.Sprintf("%d", project.created.height)))
	depositObj.AppendObject("createdTime", json.StringNode("createdTime", ufmt.Sprintf("%d", project.created.time)))
	depositObj.AppendObject("startHeight", json.StringNode("startHeight", ufmt.Sprintf("%d", project.started.height)))
	depositObj.AppendObject("startTime", json.StringNode("startTime", ufmt.Sprintf("%d", project.started.time)))
	depositObj.AppendObject("endHeight", json.StringNode("endHeight", ufmt.Sprintf("%d", project.ended.height)))
	depositObj.AppendObject("endTime", json.StringNode("endTime", ufmt.Sprintf("%d", project.ended.time)))

	depositObj.AppendObject("totalDeposit", json.StringNode("totalDeposit", ufmt.Sprintf("%d", project.stats.totalDeposit)))
	depositObj.AppendObject("actualDeposit", json.StringNode("actualDeposit", ufmt.Sprintf("%d", project.stats.actualDeposit)))

	depositObj.AppendObject("totalParticipant", json.StringNode("totalParticipant", ufmt.Sprintf("%d", project.stats.totalParticipant)))
	depositObj.AppendObject("actualParticipant", json.StringNode("actualParticipant", ufmt.Sprintf("%d", project.stats.actualParticipant)))

	depositObj.AppendObject("totalCollected", json.StringNode("totalCollected", ufmt.Sprintf("%d", project.stats.totalCollected)))

	depositObj.AppendObject("refundedAmount", json.StringNode("refundedAmount", ufmt.Sprintf("%d", project.refund.amount)))
	depositObj.AppendObject("refundedHeight", json.StringNode("refundedHeight", ufmt.Sprintf("%d", project.refund.height)))
	depositObj.AppendObject("refundedTime", json.StringNode("refundedTime", ufmt.Sprintf("%d", project.refund.time)))

	// tier info
	depositObj.AppendObject("tier", json.StringNode("tier", deposit.tier))
	depositObj.AppendObject("collectWaitDuration", json.StringNode("collectWaitDuration", ufmt.Sprintf("%d", tier.collectWaitDuration)))
	depositObj.AppendObject("tierAmount", json.StringNode("tierAmount", ufmt.Sprintf("%d", tier.tierAmount)))
	depositObj.AppendObject("tierAmountPerBlockX96", json.StringNode("tierAmountPerBlockX96", tier.tierAmountPerBlockX96.ToString()))
	depositObj.AppendObject("startHeight", json.StringNode("startHeight", ufmt.Sprintf("%d", tier.started.height)))
	depositObj.AppendObject("startTime", json.StringNode("startTime", ufmt.Sprintf("%d", tier.started.time)))
	depositObj.AppendObject("endHeight", json.StringNode("endHeight", ufmt.Sprintf("%d", tier.ended.height)))
	depositObj.AppendObject("endTime", json.StringNode("endTime", ufmt.Sprintf("%d", tier.ended.time)))

	depositObj.AppendObject("totalDepositAmount", json.StringNode("totalDepositAmount", ufmt.Sprintf("%d", tier.totalDepositAmount)))
	depositObj.AppendObject("actualDepositAmount", json.StringNode("actualDepositAmount", ufmt.Sprintf("%d", tier.actualDepositAmount)))

	depositObj.AppendObject("totalParticipant", json.StringNode("totalParticipant", ufmt.Sprintf("%d", tier.totalParticipant)))
	depositObj.AppendObject("actualParticipant", json.StringNode("actualParticipant", ufmt.Sprintf("%d", tier.actualParticipant)))

	depositObj.AppendObject("userCollectedAmount", json.StringNode("userCollectedAmount", ufmt.Sprintf("%d", tier.userCollectedAmount)))
	depositObj.AppendObject("calculatedAmount", json.StringNode("calculatedAmount", ufmt.Sprintf("%d", tier.calculatedAmount)))

	// deposit info
	depositObj.AppendObject("depositor", json.StringNode("depositor", deposit.depositor.String()))
	// depositObj.AppendObject("amount", json.StringNode("amount", ufmt.Sprintf("%d", deposit.amount)))
	depositObj.AppendObject("depositHeight", json.StringNode("depositHeight", ufmt.Sprintf("%d", deposit.depositHeight)))
	depositObj.AppendObject("depositTime", json.StringNode("depositTime", ufmt.Sprintf("%d", deposit.depositTime)))
	depositObj.AppendObject("depositCollectHeight", json.StringNode("depositCollectHeight", ufmt.Sprintf("%d", deposit.depositCollectHeight)))
	depositObj.AppendObject("depositCollectTime", json.StringNode("depositCollectTime", ufmt.Sprintf("%d", deposit.depositCollectTime)))
	depositObj.AppendObject("claimableHeight", json.StringNode("claimableHeight", ufmt.Sprintf("%d", deposit.claimableHeight)))
	depositObj.AppendObject("claimableTime", json.StringNode("claimableTime", ufmt.Sprintf("%d", deposit.claimableTime)))
	depositObj.AppendObject("rewardAmount", json.StringNode("rewardAmount", ufmt.Sprintf("%d", deposit.rewardAmount)))
	depositObj.AppendObject("rewardCollected", json.StringNode("rewardCollected", ufmt.Sprintf("%d", deposit.rewardCollected)))
	depositObj.AppendObject("rewardCollectHeight", json.StringNode("rewardCollectHeight", ufmt.Sprintf("%d", deposit.rewardCollectHeight)))
	depositObj.AppendObject("rewardCollectTime", json.StringNode("rewardCollectTime", ufmt.Sprintf("%d", deposit.rewardCollectTime)))

	return marshal(depositObj)
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
