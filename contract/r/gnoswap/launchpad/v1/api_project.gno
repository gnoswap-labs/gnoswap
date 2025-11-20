package v1

import (
	"chain/runtime"
	"strconv"
	"time"

	"gno.land/p/nt/ufmt"
)

// ApiGetProjectAndTierStatisticsByProjectId retrieves project and tier statistics by project ID.
func (lp *launchpadV1) ApiGetProjectAndTierStatisticsByProjectId(projectId string) string {
	project, err := lp.getProject(projectId)
	if err != nil {
		return ""
	}

	builder := metaBuilder().WriteString("projectId", projectId)
	projectBuilder(builder, project)

	for _, duration := range []int64{30, 90, 180} {
		if tier, err := getProjectTier(project, duration); err == nil {
			tierBuilder(builder, ufmt.Sprintf("tier%d", duration), tier)
		}
	}

	return marshal(builder.Node())
}

// ApiGetProjectStatisticsByProjectId retrieves project statistics by project ID.
func (lp *launchpadV1) ApiGetProjectStatisticsByProjectId(projectId string) string {
	project, err := lp.getProject(projectId)
	if err != nil {
		return ""
	}

	builder := metaBuilder().WriteString("projectId", projectId)
	projectBuilder(builder, project)

	return marshal(builder.Node())
}

// ApiGetTierStatisticsByProjectId retrieves tier statistics by project ID.
func (lp *launchpadV1) ApiGetTierStatisticsByProjectId(projectId string) string {
	project, err := lp.getProject(projectId)
	if err != nil {
		return ""
	}

	builder := metaBuilder().WriteString("projectId", projectId)

	for _, duration := range []int64{30, 90, 180} {
		if tier, err := getProjectTier(project, duration); err == nil {
			tierBuilder(builder, ufmt.Sprintf("tier%d", duration), tier)
		}
	}

	return marshal(builder.Node())
}

// ApiGetProjectStatisticsByProjectTierId retrieves project statistics by project tier ID.
func (lp *launchpadV1) ApiGetProjectStatisticsByProjectTierId(tierId string) string {
	projectId, duration := parseProjectTierID(tierId)
	project, err := lp.getProject(projectId)
	if err != nil {
		return ""
	}

	tier, err := getProjectTier(project, duration)
	if err != nil {
		return ""
	}

	builder := metaBuilder().WriteString("projectId", projectId)
	tierBuilder(builder, "tier", tier)

	return marshal(builder.Node())
}

// ApiGetProjectActiveOf retrieves project active status by project ID.
func (lp *launchpadV1) ApiGetProjectActiveOf(projectId string) string {
	project, err := lp.getProject(projectId)
	if err != nil {
		return ""
	}
	currentTime := time.Now().Unix()
	projectActiveResult := isProjectActive(project, currentTime)
	builder := (metaBuilder().
		WriteString("projectId", project.ID()).
		WriteString("isActive", strconv.FormatBool(projectActiveResult)).
		WriteString("currentHeight", strconv.FormatInt(runtime.ChainHeight(), 10))).
		WriteString("startTime", strconv.FormatInt(getStandardTier(project).StartTime(), 10))
	return marshal(builder.Node())
}
