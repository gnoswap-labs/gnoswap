package launchpad

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

func ApiGetProjectAndTierStatisticsByProjectId(projectId string) string {
	project, exist := projects[projectId]
	if !exist {
		return ""
	}

	actualDeposit := project.stats.actualDeposit

	totalParticipant := project.stats.totalParticipant

	projectObj := metaNode()
	projectObj.AppendObject("projectId", json.StringNode("projectId", projectId))
	projectObj.AppendObject("name", json.StringNode("name", project.name))
	projectObj.AppendObject("tokenPath", json.StringNode("tokenPath", project.tokenPath))
	projectObj.AppendObject("depositAmount", json.StringNode("depositAmount", ufmt.Sprintf("%d", project.depositAmount)))
	projectObj.AppendObject("recipient", json.StringNode("recipient", project.recipient.String()))

	tokenPathList, amountList := makeConditionsToStr(project.conditions)
	projectObj.AppendObject("conditionsToken", json.StringNode("conditionsToken", tokenPathList))
	projectObj.AppendObject("conditionsAmount", json.StringNode("conditionsAmount", amountList))

	projectObj.AppendObject("tier30Ratio", json.StringNode("tier30Ratio", ufmt.Sprintf("%d", project.tiersRatios[30])))
	projectObj.AppendObject("tier90Ratio", json.StringNode("tier90Ratio", ufmt.Sprintf("%d", project.tiersRatios[90])))
	projectObj.AppendObject("tier180Ratio", json.StringNode("tier180Ratio", ufmt.Sprintf("%d", project.tiersRatios[180])))

	projectObj.AppendObject("createdHeight", json.StringNode("createdHeight", ufmt.Sprintf("%d", project.created.height)))
	projectObj.AppendObject("createdTime", json.StringNode("createdTime", ufmt.Sprintf("%d", project.created.time)))
	projectObj.AppendObject("startHeight", json.StringNode("startHeight", ufmt.Sprintf("%d", project.started.height)))
	projectObj.AppendObject("startTime", json.StringNode("startTime", ufmt.Sprintf("%d", project.started.time)))
	projectObj.AppendObject("endHeight", json.StringNode("endHeight", ufmt.Sprintf("%d", project.ended.height)))
	projectObj.AppendObject("endTime", json.StringNode("endTime", ufmt.Sprintf("%d", project.ended.time)))

	projectObj.AppendObject("totalDeposit", json.StringNode("totalDeposit", ufmt.Sprintf("%d", project.stats.totalDeposit)))
	projectObj.AppendObject("actualDeposit", json.StringNode("actualDeposit", ufmt.Sprintf("%d", actualDeposit)))

	projectObj.AppendObject("totalParticipant", json.StringNode("totalParticipant", ufmt.Sprintf("%d", totalParticipant)))
	projectObj.AppendObject("actualParticipant", json.StringNode("actualParticipant", ufmt.Sprintf("%d", project.stats.actualParticipant)))

	projectObj.AppendObject("totalCollected", json.StringNode("totalCollected", ufmt.Sprintf("%d", project.stats.totalCollected)))

	projectObj.AppendObject("refundedAmount", json.StringNode("refundedAmount", ufmt.Sprintf("%d", project.refund.amount)))
	projectObj.AppendObject("refundedHeight", json.StringNode("refundedHeight", ufmt.Sprintf("%d", project.refund.height)))
	projectObj.AppendObject("refundedTime", json.StringNode("refundedTime", ufmt.Sprintf("%d", project.refund.time)))

	projectObj.AppendObject("tier30StartHeight", json.StringNode("tier30StartHeight", ufmt.Sprintf("%d", project.tiers[30].started.height)))
	projectObj.AppendObject("tier30StartTime", json.StringNode("tier30StartTime", ufmt.Sprintf("%d", project.tiers[30].started.time)))
	projectObj.AppendObject("tier30EndHeight", json.StringNode("tier30EndHeight", ufmt.Sprintf("%d", project.tiers[30].ended.height)))
	projectObj.AppendObject("tier30EndTime", json.StringNode("tier30EndTime", ufmt.Sprintf("%d", project.tiers[30].ended.time)))
	projectObj.AppendObject("tier30TotalDepositAmount", json.StringNode("tier30TotalDepositAmount", ufmt.Sprintf("%d", project.tiers[30].totalDepositAmount)))
	projectObj.AppendObject("tier30ActualDepositAmount", json.StringNode("tier30ActualDepositAmount", ufmt.Sprintf("%d", project.tiers[30].actualDepositAmount)))
	projectObj.AppendObject("tier30TotalParticipant", json.StringNode("tier30TotalParticipant", ufmt.Sprintf("%d", project.tiers[30].totalParticipant)))
	projectObj.AppendObject("tier30ActualParticipant", json.StringNode("tier30ActualParticipant", ufmt.Sprintf("%d", project.tiers[30].actualParticipant)))
	projectObj.AppendObject("tier30UserCollectedAmount", json.StringNode("tier30UserCollectedAmount", ufmt.Sprintf("%d", project.tiers[30].userCollectedAmount)))
	projectObj.AppendObject("tier30CalculatedAmount", json.StringNode("tier30CalculatedAmount", ufmt.Sprintf("%d", project.tiers[30].calculatedAmount)))

	projectObj.AppendObject("tier90StartHeight", json.StringNode("tier90StartHeight", ufmt.Sprintf("%d", project.tiers[90].started.height)))
	projectObj.AppendObject("tier90StartTime", json.StringNode("tier90StartTime", ufmt.Sprintf("%d", project.tiers[90].started.time)))
	projectObj.AppendObject("tier90EndHeight", json.StringNode("tier90EndHeight", ufmt.Sprintf("%d", project.tiers[90].ended.height)))
	projectObj.AppendObject("tier90EndTime", json.StringNode("tier90EndTime", ufmt.Sprintf("%d", project.tiers[90].ended.time)))
	projectObj.AppendObject("tier90TotalDepositAmount", json.StringNode("tier90TotalDepositAmount", ufmt.Sprintf("%d", project.tiers[90].totalDepositAmount)))
	projectObj.AppendObject("tier90ActualDepositAmount", json.StringNode("tier90ActualDepositAmount", ufmt.Sprintf("%d", project.tiers[90].actualDepositAmount)))
	projectObj.AppendObject("tier90TotalParticipant", json.StringNode("tier90TotalParticipant", ufmt.Sprintf("%d", project.tiers[90].totalParticipant)))
	projectObj.AppendObject("tier90ActualParticipant", json.StringNode("tier90ActualParticipant", ufmt.Sprintf("%d", project.tiers[90].actualParticipant)))
	projectObj.AppendObject("tier90UserCollectedAmount", json.StringNode("tier90UserCollectedAmount", ufmt.Sprintf("%d", project.tiers[90].userCollectedAmount)))
	projectObj.AppendObject("tier90CalculatedAmount", json.StringNode("tier90CalculatedAmount", ufmt.Sprintf("%d", project.tiers[90].calculatedAmount)))

	projectObj.AppendObject("tier180StartHeight", json.StringNode("tier180StartHeight", ufmt.Sprintf("%d", project.tiers[180].started.height)))
	projectObj.AppendObject("tier180StartTime", json.StringNode("tier180StartTime", ufmt.Sprintf("%d", project.tiers[180].started.time)))
	projectObj.AppendObject("tier180EndHeight", json.StringNode("tier180EndHeight", ufmt.Sprintf("%d", project.tiers[180].ended.height)))
	projectObj.AppendObject("tier180EndTime", json.StringNode("tier180EndTime", ufmt.Sprintf("%d", project.tiers[180].ended.time)))
	projectObj.AppendObject("tier180TotalDepositAmount", json.StringNode("tier180TotalDepositAmount", ufmt.Sprintf("%d", project.tiers[180].totalDepositAmount)))
	projectObj.AppendObject("tier180ActualDepositAmount", json.StringNode("tier180ActualDepositAmount", ufmt.Sprintf("%d", project.tiers[180].actualDepositAmount)))
	projectObj.AppendObject("tier180TotalParticipant", json.StringNode("tier180TotalParticipant", ufmt.Sprintf("%d", project.tiers[180].totalParticipant)))
	projectObj.AppendObject("tier180ActualParticipant", json.StringNode("tier180ActualParticipant", ufmt.Sprintf("%d", project.tiers[180].actualParticipant)))
	projectObj.AppendObject("tier180UserCollectedAmount", json.StringNode("tier180UserCollectedAmount", ufmt.Sprintf("%d", project.tiers[180].userCollectedAmount)))
	projectObj.AppendObject("tier180CalculatedAmount", json.StringNode("tier180CalculatedAmount", ufmt.Sprintf("%d", project.tiers[180].calculatedAmount)))

	return marshal(projectObj)
}

func ApiGetProjectStatisticsByProjectId(projectId string) string {
	project, exist := projects[projectId]
	if !exist {
		return ""
	}

	totalDeposit := project.stats.totalDeposit
	actualDeposit := project.stats.actualDeposit

	totalParticipant := project.stats.totalParticipant
	actualParticipant := project.stats.actualParticipant

	totalCollected := project.stats.totalCollected

	projectObj := metaNode()
	projectObj.AppendObject("projectId", json.StringNode("projectId", projectId))
	projectObj.AppendObject("name", json.StringNode("name", project.name))
	projectObj.AppendObject("tokenPath", json.StringNode("tokenPath", project.tokenPath))
	projectObj.AppendObject("depositAmount", json.StringNode("depositAmount", ufmt.Sprintf("%d", project.depositAmount)))
	projectObj.AppendObject("recipient", json.StringNode("recipient", project.recipient.String()))

	tokenPathList, amountList := makeConditionsToStr(project.conditions)
	projectObj.AppendObject("conditionsToken", json.StringNode("conditionsToken", tokenPathList))
	projectObj.AppendObject("conditionsAmount", json.StringNode("conditionsAmount", amountList))

	projectObj.AppendObject("tier30Ratio", json.StringNode("tier30Ratio", ufmt.Sprintf("%d", project.tiers[30].tierAmount)))
	projectObj.AppendObject("tier90Ratio", json.StringNode("tier90Ratio", ufmt.Sprintf("%d", project.tiers[90].tierAmount)))
	projectObj.AppendObject("tier180Ratio", json.StringNode("tier180Ratio", ufmt.Sprintf("%d", project.tiers[180].tierAmount)))

	projectObj.AppendObject("createdHeight", json.StringNode("createdHeight", ufmt.Sprintf("%d", project.created.height)))
	projectObj.AppendObject("createdTime", json.StringNode("createdTime", ufmt.Sprintf("%d", project.created.time)))
	projectObj.AppendObject("startHeight", json.StringNode("startHeight", ufmt.Sprintf("%d", project.started.height)))
	projectObj.AppendObject("startTime", json.StringNode("startTime", ufmt.Sprintf("%d", project.started.time)))
	projectObj.AppendObject("endHeight", json.StringNode("endHeight", ufmt.Sprintf("%d", project.ended.height)))
	projectObj.AppendObject("endTime", json.StringNode("endTime", ufmt.Sprintf("%d", project.ended.time)))

	projectObj.AppendObject("totalDepositAmount", json.StringNode("totalDepositAmount", ufmt.Sprintf("%d", totalDeposit)))
	projectObj.AppendObject("actualDepositAmount", json.StringNode("actualDepositAmount", ufmt.Sprintf("%d", actualDeposit)))

	projectObj.AppendObject("totalParticipant", json.StringNode("totalParticipant", ufmt.Sprintf("%d", totalParticipant)))
	projectObj.AppendObject("actualParticipant", json.StringNode("actualParticipant", ufmt.Sprintf("%d", actualParticipant)))

	projectObj.AppendObject("totalCollectedAmount", json.StringNode("totalCollectedAmount", ufmt.Sprintf("%d", totalCollected)))

	projectObj.AppendObject("refundedAmount", json.StringNode("refundedAmount", ufmt.Sprintf("%d", project.refund.amount)))
	projectObj.AppendObject("refundedHeight", json.StringNode("refundedHeight", ufmt.Sprintf("%d", project.refund.height)))
	projectObj.AppendObject("refundedTime", json.StringNode("refundedTime", ufmt.Sprintf("%d", project.refund.time)))

	return marshal(projectObj)
}

func ApiGetProjectStatisticsByProjectTierId(tierId string) string {
	projectId, tierStr := getProjectIdAndTierFromTierId(tierId)
	project, exist := projects[projectId]
	if !exist {
		return ""
	}

	var tier Tier
	switch tierStr {
	case "30":
		tier = project.tiers[30]
	case "90":
		tier = project.tiers[90]
	case "180":
		tier = project.tiers[180]
	default:
		return ""
	}

	tierAmount := tier.tierAmount // project token allocation

	tierTotalDepositAmount := tier.totalDepositAmount
	tierActualDepositAmount := tier.actualDepositAmount

	tierTotalParticipant := tier.totalParticipant
	tierActualParticipant := tier.actualParticipant

	projectTierObj := metaNode()
	projectTierObj.AppendObject("projectId", json.StringNode("projectId", projectId))
	projectTierObj.AppendObject("tierId", json.StringNode("tierId", tierId))
	projectTierObj.AppendObject("tierAmount", json.StringNode("tierAmount", ufmt.Sprintf("%d", tierAmount)))
	projectTierObj.AppendObject("tierTotalDepositAmount", json.StringNode("tierTotalDepositAmount", ufmt.Sprintf("%d", tierTotalDepositAmount)))
	projectTierObj.AppendObject("tierActualDepositAmount", json.StringNode("tierActualDepositAmount", ufmt.Sprintf("%d", tierActualDepositAmount)))
	projectTierObj.AppendObject("tierTotalParticipant", json.StringNode("tierTotalParticipant", ufmt.Sprintf("%d", tierTotalParticipant)))
	projectTierObj.AppendObject("tierActualParticipant", json.StringNode("tierActualParticipant", ufmt.Sprintf("%d", tierActualParticipant)))

	return marshal(projectTierObj)
}

func metaNode() *json.Node {
	height := std.GetHeight()
	now := time.Now().Unix()

	metaObj := json.ObjectNode("", nil)
	metaObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", height)))
	metaObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", now)))
	return metaObj
}
