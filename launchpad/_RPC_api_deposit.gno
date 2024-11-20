package launchpad

import (
	"std"
	"strings"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

func ApiGetClaimableDepositByAddress(address std.Address) uint64 {
	calculateDepositReward()

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

func ApiGetDepositByDepositId(depositId string) string {
	calculateDepositReward()

	deposit, exist := deposits[depositId]
	if !exist {
		return ""
	}

	depositObj := metaNode()
	depositObj.AppendObject("depositId", json.StringNode("depositId", depositId))
	depositObj.AppendObject("projectId", json.StringNode("projectId", deposit.projectId))
	depositObj.AppendObject("tier", json.StringNode("tier", deposit.tier))
	depositObj.AppendObject("depositor", json.StringNode("depositor", deposit.depositor.String()))
	depositObj.AppendObject("amount", json.StringNode("amount", ufmt.Sprintf("%d", deposit.amount)))
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
	tierStr := deposit.tier
	switch tierStr {
	case "30":
		tier = project.tier30
	case "90":
		tier = project.tier90
	case "180":
		tier = project.tier180
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

	depositObj.AppendObject("tier30Ratio", json.StringNode("tier30Ratio", ufmt.Sprintf("%d", project.tier30Ratio)))
	depositObj.AppendObject("tier90Ratio", json.StringNode("tier90Ratio", ufmt.Sprintf("%d", project.tier90Ratio)))
	depositObj.AppendObject("tier180Ratio", json.StringNode("tier180Ratio", ufmt.Sprintf("%d", project.tier180Ratio)))

	depositObj.AppendObject("createdHeight", json.StringNode("createdHeight", ufmt.Sprintf("%d", project.createdHeight)))
	depositObj.AppendObject("createdTime", json.StringNode("createdTime", ufmt.Sprintf("%d", project.createdTime)))
	depositObj.AppendObject("startHeight", json.StringNode("startHeight", ufmt.Sprintf("%d", project.startHeight)))
	depositObj.AppendObject("startTime", json.StringNode("startTime", ufmt.Sprintf("%d", project.startTime)))
	depositObj.AppendObject("endHeight", json.StringNode("endHeight", ufmt.Sprintf("%d", project.endHeight)))
	depositObj.AppendObject("endTime", json.StringNode("endTime", ufmt.Sprintf("%d", project.endTime)))

	depositObj.AppendObject("totalDepositAmount", json.StringNode("totalDepositAmount", ufmt.Sprintf("%d", project.totalDepositAmount)))
	depositObj.AppendObject("actualDepositAmount", json.StringNode("actualDepositAmount", ufmt.Sprintf("%d", project.actualDepositAmount)))

	depositObj.AppendObject("totalParticipant", json.StringNode("totalParticipant", ufmt.Sprintf("%d", project.totalParticipant)))
	depositObj.AppendObject("actualParticipant", json.StringNode("actualParticipant", ufmt.Sprintf("%d", project.actualParticipant)))

	depositObj.AppendObject("totalCollectedAmount", json.StringNode("totalCollectedAmount", ufmt.Sprintf("%d", project.totalCollectedAmount)))

	depositObj.AppendObject("refundedAmount", json.StringNode("refundedAmount", ufmt.Sprintf("%d", project.refundedAmount)))
	depositObj.AppendObject("refundedHeight", json.StringNode("refundedHeight", ufmt.Sprintf("%d", project.refundedHeight)))
	depositObj.AppendObject("refundedTime", json.StringNode("refundedTime", ufmt.Sprintf("%d", project.refundedTime)))

	// tier info
	depositObj.AppendObject("tier", json.StringNode("tier", deposit.tier))
	depositObj.AppendObject("collectWaitDuration", json.StringNode("collectWaitDuration", ufmt.Sprintf("%d", tier.collectWaitDuration)))
	depositObj.AppendObject("tierAmount", json.StringNode("tierAmount", ufmt.Sprintf("%d", tier.tierAmount)))
	depositObj.AppendObject("tierAmountPerBlockX96", json.StringNode("tierAmountPerBlockX96", tier.tierAmountPerBlockX96.ToString()))
	depositObj.AppendObject("startHeight", json.StringNode("startHeight", ufmt.Sprintf("%d", tier.startHeight)))
	depositObj.AppendObject("startTime", json.StringNode("startTime", ufmt.Sprintf("%d", tier.startTime)))
	depositObj.AppendObject("endHeight", json.StringNode("endHeight", ufmt.Sprintf("%d", tier.endHeight)))
	depositObj.AppendObject("endTime", json.StringNode("endTime", ufmt.Sprintf("%d", tier.endTime)))

	depositObj.AppendObject("totalDepositAmount", json.StringNode("totalDepositAmount", ufmt.Sprintf("%d", tier.totalDepositAmount)))
	depositObj.AppendObject("actualDepositAmount", json.StringNode("actualDepositAmount", ufmt.Sprintf("%d", tier.actualDepositAmount)))

	depositObj.AppendObject("totalParticipant", json.StringNode("totalParticipant", ufmt.Sprintf("%d", tier.totalParticipant)))
	depositObj.AppendObject("actualParticipant", json.StringNode("actualParticipant", ufmt.Sprintf("%d", tier.actualParticipant)))

	depositObj.AppendObject("userCollectedAmount", json.StringNode("userCollectedAmount", ufmt.Sprintf("%d", tier.userCollectedAmount)))
	depositObj.AppendObject("calculatedAmount", json.StringNode("calculatedAmount", ufmt.Sprintf("%d", tier.calculatedAmount)))

	// deposit info
	depositObj.AppendObject("depositor", json.StringNode("depositor", deposit.depositor.String()))
	depositObj.AppendObject("amount", json.StringNode("amount", ufmt.Sprintf("%d", deposit.amount)))
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
