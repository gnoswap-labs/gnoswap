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

	totalDepositAmount := project.totalDepositAmount
	actualDepositAmount := project.actualDepositAmount

	totalParticipant := project.totalParticipant
	actualParticipant := project.actualParticipant

	totalCollectedAmount := project.totalCollectedAmount

	projectObj := metaNode()
	projectObj.AppendObject("projectId", json.StringNode("projectId", projectId))
	projectObj.AppendObject("totalDepositAmount", json.StringNode("totalDepositAmount", ufmt.Sprintf("%d", totalDepositAmount)))
	projectObj.AppendObject("actualDepositAmount", json.StringNode("actualDepositAmount", ufmt.Sprintf("%d", actualDepositAmount)))
	projectObj.AppendObject("totalParticipant", json.StringNode("totalParticipant", ufmt.Sprintf("%d", totalParticipant)))
	projectObj.AppendObject("actualParticipant", json.StringNode("actualParticipant", ufmt.Sprintf("%d", actualParticipant)))
	projectObj.AppendObject("totalCollectedAmount", json.StringNode("totalCollectedAmount", ufmt.Sprintf("%d", totalCollectedAmount)))

	projectObj.AppendObject("tier30TotalDepositAmount", json.StringNode("tier30TotalDepositAmount", ufmt.Sprintf("%d", project.tier30.totalDepositAmount)))
	projectObj.AppendObject("tier30ActualDepositAmount", json.StringNode("tier30ActualDepositAmount", ufmt.Sprintf("%d", project.tier30.actualDepositAmount)))
	projectObj.AppendObject("tier30TotalParticipant", json.StringNode("tier30TotalParticipant", ufmt.Sprintf("%d", project.tier30.totalParticipant)))
	projectObj.AppendObject("tier30ActualParticipant", json.StringNode("tier30ActualParticipant", ufmt.Sprintf("%d", project.tier30.actualParticipant)))

	projectObj.AppendObject("tier90TotalDepositAmount", json.StringNode("tier90TotalDepositAmount", ufmt.Sprintf("%d", project.tier90.totalDepositAmount)))
	projectObj.AppendObject("tier90ActualDepositAmount", json.StringNode("tier90ActualDepositAmount", ufmt.Sprintf("%d", project.tier90.actualDepositAmount)))
	projectObj.AppendObject("tier90TotalParticipant", json.StringNode("tier90TotalParticipant", ufmt.Sprintf("%d", project.tier90.totalParticipant)))
	projectObj.AppendObject("tier90ActualParticipant", json.StringNode("tier90ActualParticipant", ufmt.Sprintf("%d", project.tier90.actualParticipant)))

	projectObj.AppendObject("tier180TotalDepositAmount", json.StringNode("tier180TotalDepositAmount", ufmt.Sprintf("%d", project.tier180.totalDepositAmount)))
	projectObj.AppendObject("tier180ActualDepositAmount", json.StringNode("tier180ActualDepositAmount", ufmt.Sprintf("%d", project.tier180.actualDepositAmount)))
	projectObj.AppendObject("tier180TotalParticipant", json.StringNode("tier180TotalParticipant", ufmt.Sprintf("%d", project.tier180.totalParticipant)))
	projectObj.AppendObject("tier180ActualParticipant", json.StringNode("tier180ActualParticipant", ufmt.Sprintf("%d", project.tier180.actualParticipant)))

	return marshal(projectObj)
}

func ApiGetProjectStatisticsByProjectId(projectId string) string {
	project, exist := projects[projectId]
	if !exist {
		return ""
	}

	totalDepositAmount := project.totalDepositAmount
	actualDepositAmount := project.actualDepositAmount

	totalParticipant := project.totalParticipant
	actualParticipant := project.actualParticipant

	totalCollectedAmount := project.totalCollectedAmount

	projectObj := metaNode()
	projectObj.AppendObject("projectId", json.StringNode("projectId", projectId))
	projectObj.AppendObject("totalDepositAmount", json.StringNode("totalDepositAmount", ufmt.Sprintf("%d", totalDepositAmount)))
	projectObj.AppendObject("actualDepositAmount", json.StringNode("actualDepositAmount", ufmt.Sprintf("%d", actualDepositAmount)))
	projectObj.AppendObject("totalParticipant", json.StringNode("totalParticipant", ufmt.Sprintf("%d", totalParticipant)))
	projectObj.AppendObject("actualParticipant", json.StringNode("actualParticipant", ufmt.Sprintf("%d", actualParticipant)))
	projectObj.AppendObject("totalCollectedAmount", json.StringNode("totalCollectedAmount", ufmt.Sprintf("%d", totalCollectedAmount)))

	return marshal(projectObj)
}

func ApiGetProjectStatisticsByProjectTierId(tierId string) string {
	projectId, tierStr := getProjectIdAndTierFromTierId(tierId)
	project, exist := projects[projectId]
	if !exist {
		println("NO PROJECT FOR THIS ID", projectId)
		return ""
	}

	var tier Tier
	switch tierStr {
	case "30":
		tier = project.tier30
	case "90":
		tier = project.tier90
	case "180":
		tier = project.tier180
	default:
		println("NO TIER FOR THIS ID", tierId)
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
