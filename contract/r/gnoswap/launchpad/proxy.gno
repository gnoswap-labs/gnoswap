package launchpad

// CreateProject creates a new launchpad project (only callable by the admin).
//
// Parameters:
//   - name: The name of a project.
//   - tokenPath: The token path to distribute as reward.
//   - recipient: The address of the project's to receive reward.
//   - depositAmount: The amount of token to distribute as reward.
//   - conditionTokens: A list of token paths to use as a condition when depositing (It's optional, and for multiple tokens, use `*PAD*` as separator).
//   - conditionAmounts: A list of tokens' amount to use as condition when depositing (It's optional, and for multiple tokens, use `*PAD*` as separator).
//   - tier30Ratio: The distribution ratio of the 30 days pool.
//   - tier90Ratio: The distribution ratio of the 90 days pool.
//   - tier180Ratio: The distribution ratio of the 180 days pool.
//   - startTime: The start time of the project.
//
// Returns:
//   - projectId: The ID of the created project.
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

// CollectProtocolFee collects the protocol fees from the governance contract. The reward is for projects, not for users, and it occurs based on the xGNS holdings that users deposited via launchpad to receive the project tokens.
func CollectProtocolFee(cur realm) {
	getImplementation().CollectProtocolFee()
}

// TransferLeftFromProjectByAdmin transfers the remaining amount from the ended project to the recipient.
//
// Parameters:
//   - projectID: The ID of the ended project.
//   - recipient: The recipient address to receive the remaining tokens.
//
// Returns:
//   - amount: The amount of transferred tokens.
func TransferLeftFromProjectByAdmin(cur realm, projectID string, recipient address) int64 {
	return getImplementation().TransferLeftFromProjectByAdmin(projectID, recipient)
}

// DepositGns deposits GNS to a launchpad project pool.
//
// Parameters:
//   - targetProjectTierID: The pool tier ID to deposit.
//   - depositAmount: The amount of GNS token to deposit.
//   - referrer: The referrer address for reward tracking.
//
// Returns:
//   - depositId: The ID of the deposit.
func DepositGns(cur realm, targetProjectTierID string, depositAmount int64, referrer string) string {
	return getImplementation().DepositGns(targetProjectTierID, depositAmount, referrer)
}

// CollectDepositGns collects the deposited GNS using a depositID.
//
// Parameters:
//   - depositID: The ID of a deposit to collect GNS.
//
// Returns:
//   - amount: The collected amount of GNS.
//   - err: Error if collection fails.
func CollectDepositGns(cur realm, depositID string) (int64, error) {
	return getImplementation().CollectDepositGns(depositID)
}

// CollectRewardByDepositId collects the project token reward for users using a depositId.
//
// Parameters:
//   - depositID: The ID of a deposit to collect reward token.
//
// Returns:
//   - amount: The amount of collected reward token.
func CollectRewardByDepositId(cur realm, depositID string) int64 {
	return getImplementation().CollectRewardByDepositId(depositID)
}
