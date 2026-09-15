package launchpad

// CreateProject creates a new launchpad project callable by the administrator or governance.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm.
//   - name: human-readable project name.
//   - tokenPath: token path whose tokens are distributed as project rewards.
//   - recipient: address authorized to receive project rewards and project proceeds.
//   - depositAmount: total reward-token amount allocated to the project.
//   - conditionTokens: optional `*PAD*`-separated token paths required for deposits.
//   - conditionAmounts: optional `*PAD*`-separated required amounts matching conditionTokens.
//   - tier30Ratio: reward allocation ratio for the 30-day tier.
//   - tier90Ratio: reward allocation ratio for the 90-day tier.
//   - tier180Ratio: reward allocation ratio for the 180-day tier.
//   - startTime: Unix timestamp at which project reward distribution starts.
//
// Returns:
//   - projectId: identifier assigned to the newly created project.
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
		0,
		cur,
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

// CollectProtocolFee collects protocol-fee rewards allocated to project recipients.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm.
func CollectProtocolFee(cur realm) {
	getImplementation().CollectProtocolFee(0, cur)
}

// CollectEmissionReward collects accumulated launchpad emission rewards.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm.
func CollectEmissionReward(cur realm) {
	getImplementation().CollectEmissionReward(0, cur)
}

// CollectProtocolFeeReward collects accumulated launchpad protocol-fee rewards for a token path.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm.
//   - tokenPath: token path whose accumulated protocol-fee reward is collected.
func CollectProtocolFeeReward(cur realm, tokenPath string) {
	getImplementation().CollectProtocolFeeReward(0, cur, tokenPath)
}

// TransferLeftFromProjectByAdmin transfers unreserved reward tokens from an ended project.
// Active depositor claims remain reserved and are excluded; only the administrator may call it.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm.
//   - projectID: identifier of the ended project whose remaining balance is transferred.
//   - recipient: destination address for the transferable balance.
//
// Returns:
//   - amount: number of reward tokens transferred after active claims are reserved.
func TransferLeftFromProjectByAdmin(cur realm, projectID string, recipient address) int64 {
	return getImplementation().TransferLeftFromProjectByAdmin(0, cur, projectID, recipient)
}

// DepositGns deposits GNS into a selected launchpad project tier.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm.
//   - targetProjectTierID: project-tier identifier in `{projectID}:{tierDuration}` form.
//   - depositAmount: amount of GNS to stake in the selected tier.
//   - referrer: optional referral address associated with the deposit.
//
// Returns:
//   - depositId: identifier assigned to the newly created deposit.
func DepositGns(cur realm, targetProjectTierID string, depositAmount int64, referrer string) string {
	return getImplementation().DepositGns(0, cur, targetProjectTierID, depositAmount, referrer)
}

// CollectDepositGns withdraws the GNS amount recorded by a deposit.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm.
//   - depositID: identifier of the deposit whose GNS is collected.
//
// Returns:
//   - amount: GNS amount withdrawn from the deposit.
//   - err: non-nil when the deposit cannot be collected.
func CollectDepositGns(cur realm, depositID string) (int64, error) {
	return getImplementation().CollectDepositGns(0, cur, depositID)
}

// CollectRewardByDepositId collects the project-token reward earned by a deposit.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm.
//   - depositID: identifier of the deposit whose reward is collected.
//
// Returns:
//   - amount: project-token reward amount transferred to the depositor.
func CollectRewardByDepositId(cur realm, depositID string) int64 {
	return getImplementation().CollectRewardByDepositId(0, cur, depositID)
}
