package launchpad

// CreateProject creates a new launchpad project with tiered allocations.
func CreateProject(
	cur realm,
	name string,
	tokenPath string,
	recipient address,
	depositAmount int64,
	conditionTokens string,
	conditionAmounts string,
	tier30Ratio int64,
	tier90Ratio int64,
	tier180Ratio int64,
	startTime int64,
) string {
	return getImplementation().CreateProject(
		name,
		tokenPath,
		recipient,
		depositAmount,
		conditionTokens,
		conditionAmounts,
		tier30Ratio,
		tier90Ratio,
		tier180Ratio,
		startTime,
	)
}

func CollectProtocolFee(cur realm) {
	getImplementation().CollectProtocolFee()
}

// TransferLeftFromProjectByAdmin transfers the remaining rewards of a project to a specified recipient.
func TransferLeftFromProjectByAdmin(cur realm, projectID string, recipient address) int64 {
	return getImplementation().TransferLeftFromProjectByAdmin(projectID, recipient)
}

// DepositGns deposits GNS tokens to a launchpad project tier.
func DepositGns(cur realm, targetProjectTierID string, depositAmount int64, referrer string) string {
	return getImplementation().DepositGns(targetProjectTierID, depositAmount, referrer)
}

// CollectDepositGns collects rewards from a deposit.
func CollectDepositGns(cur realm, depositID string) (int64, error) {
	return getImplementation().CollectDepositGns(depositID)
}

// ApiGetProjectAndTierStatisticsByProjectId retrieves project and tier statistics by project ID.
func ApiGetProjectAndTierStatisticsByProjectId(projectId string) string {
	return getImplementation().ApiGetProjectAndTierStatisticsByProjectId(projectId)
}

// ApiGetProjectStatisticsByProjectId retrieves project statistics by project ID.
func ApiGetProjectStatisticsByProjectId(projectId string) string {
	return getImplementation().ApiGetProjectStatisticsByProjectId(projectId)
}

// ApiGetTierStatisticsByProjectId retrieves tier statistics by project ID.
func ApiGetTierStatisticsByProjectId(projectId string) string {
	return getImplementation().ApiGetTierStatisticsByProjectId(projectId)
}

// ApiGetProjectStatisticsByProjectTierId retrieves project statistics by project tier ID.
func ApiGetProjectStatisticsByProjectTierId(tierId string) string {
	return getImplementation().ApiGetProjectStatisticsByProjectTierId(tierId)
}

// ApiGetProjectActiveOf retrieves project active status by project ID.
func ApiGetProjectActiveOf(projectId string) string {
	return getImplementation().ApiGetProjectActiveOf(projectId)
}

// ApiGetDepositByDepositId retrieves deposit information by deposit ID.
func ApiGetDepositByDepositId(depositId string) string {
	return getImplementation().ApiGetDepositByDepositId(depositId)
}

// ApiGetProjectRecipientRewardByProjectId retrieves the claimable reward for a project recipient by project ID.
func ApiGetProjectRecipientRewardByProjectId(projectId string) string {
	return getImplementation().ApiGetProjectRecipientRewardByProjectId(projectId)
}

// ApiGetProjectRecipientRewardByAddress retrieves the claimable reward for a recipient by address.
func ApiGetProjectRecipientRewardByAddress(address address) string {
	return getImplementation().ApiGetProjectRecipientRewardByAddress(address)
}
