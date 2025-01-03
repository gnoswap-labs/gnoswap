package launchpad

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

func ApiGetProjectAndTierStatisticsByProjectId(projectId string) string {
    calculateDepositReward()

    project, exist := projects[projectId]
    if !exist {
        return ""
    }

    builder := MetaBuilder().
        WriteString("projectId", projectId)
    ProjectBuilder(builder, project)

    return marshal(builder.Node())
}

func ApiGetProjectStatisticsByProjectId(projectId string) string {
	project, exist := projects[projectId]
	if !exist {
		return ""
	}

	builder := MetaBuilder().
		WriteString("projectId", projectId)
	ProjectBuilder(builder, project)

	return marshal(builder.Node())
}

func ApiGetProjectStatisticsByProjectTierId(tierId string) string {
    calculateDepositReward()

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

    builder := MetaBuilder().
        WriteString("projectId", projectId).
        WriteString("tierId", tierId).
        WriteString("tierAmount", ufmt.Sprintf("%d", tier.tierAmount)).
        WriteString("tierTotalDepositAmount", ufmt.Sprintf("%d", tier.totalDepositAmount)).
        WriteString("tierActualDepositAmount", ufmt.Sprintf("%d", tier.actualDepositAmount)).
        WriteString("tierTotalParticipant", ufmt.Sprintf("%d", tier.totalParticipant)).
        WriteString("tierActualParticipant", ufmt.Sprintf("%d", tier.actualParticipant))

    return marshal(builder.Node())
}

func metaNode() *json.Node {
	height := std.GetHeight()
	now := time.Now().Unix()

	metaObj := json.ObjectNode("", nil)
	metaObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", height)))
	metaObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", now)))
	return metaObj
}
