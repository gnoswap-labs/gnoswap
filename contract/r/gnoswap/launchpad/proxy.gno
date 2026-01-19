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

// CollectProtocolFee collects accumulated protocol fees from launchpad operations.
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

// CollectRewardByDepositId collects rewards from a deposit.
func CollectRewardByDepositId(cur realm, depositID string) int64 {
	return getImplementation().CollectRewardByDepositId(depositID)
}
