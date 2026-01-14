package launchpad

// CreateProject creates a new launchpad project with tiered allocations.
//
// Parameters:
//   - name: project name
//   - tokenPath: path of the project token
//   - recipient: recipient address for collected funds
//   - depositAmount: total deposit amount for the project
//   - conditionTokens: comma-separated token paths for conditions
//   - conditionAmounts: comma-separated amounts for conditions
//   - tier30Ratio: allocation ratio for 30-day tier
//   - tier90Ratio: allocation ratio for 90-day tier
//   - tier180Ratio: allocation ratio for 180-day tier
//   - startTime: project start timestamp
//
// Returns:
//   - projectId: created project ID
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
//
// Parameters:
//   - projectID: ID of the project
//   - recipient: recipient address for remaining rewards
//
// Returns:
//   - amount: transferred amount
func TransferLeftFromProjectByAdmin(cur realm, projectID string, recipient address) int64 {
	return getImplementation().TransferLeftFromProjectByAdmin(projectID, recipient)
}

// DepositGns deposits GNS tokens to a launchpad project tier.
//
// Parameters:
//   - targetProjectTierID: ID of the target project tier
//   - depositAmount: amount of GNS to deposit
//   - referrer: referrer address for reward tracking
//
// Returns:
//   - depositId: created deposit ID
func DepositGns(cur realm, targetProjectTierID string, depositAmount int64, referrer string) string {
	return getImplementation().DepositGns(targetProjectTierID, depositAmount, referrer)
}

// CollectDepositGns collects rewards from a deposit.
//
// Parameters:
//   - depositID: ID of the deposit
//
// Returns:
//   - amount: collected reward amount
//   - err: error if collection fails
func CollectDepositGns(cur realm, depositID string) (int64, error) {
	return getImplementation().CollectDepositGns(depositID)
}

// CollectRewardByDepositId collects rewards from a deposit.
//
// Parameters:
//   - depositID: ID of the deposit
//
// Returns:
//   - amount: collected reward amount
func CollectRewardByDepositId(cur realm, depositID string) int64 {
	return getImplementation().CollectRewardByDepositId(depositID)
}
