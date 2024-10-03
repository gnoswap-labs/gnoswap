package launchpad

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

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
	projectObj.AppendObject("totalDepositAmount", json.StringNode("totalDepositAmount", ufmt.Sprintf("%d", totalDepositAmount)))
	projectObj.AppendObject("actualDepositAmount", json.StringNode("actualDepositAmount", ufmt.Sprintf("%d", actualDepositAmount)))
	projectObj.AppendObject("totalParticipant", json.StringNode("totalParticipant", ufmt.Sprintf("%d", totalParticipant)))
	projectObj.AppendObject("actualParticipant", json.StringNode("actualParticipant", ufmt.Sprintf("%d", actualParticipant)))
	projectObj.AppendObject("totalCollectedAmount", json.StringNode("totalCollectedAmount", ufmt.Sprintf("%d", totalCollectedAmount)))

	return marshal(projectObj)
}

func metaNode() *json.Node {
	height := std.GetHeight()
	now := time.Now().Unix()

	metaObj := json.ObjectNode("", nil)
	metaObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", height)))
	metaObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", now)))
	return metaObj
}
