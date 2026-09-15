package staker

// StakeToken stakes a position NFT to earn rewards.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - positionId: LP position NFT token ID to stake.
//   - referrer: Optional referral address string used for referral tracking.
//
// Returns:
//   - string: Pool path where the position was staked.
//
// Halt check: reverts while the Staker halt scope is active.
func StakeToken(cur realm, positionId uint64, referrer string) string {
	return getImplementation().StakeToken(0, cur, positionId, referrer)
}

// UnStakeToken unstakes a position NFT and creates an exit checkpoint for its rewards.
//
// The NFT is returned to its owner without calculating or paying rewards. Use a Collect* entry
// point afterward; collection of an exit checkpoint is permissionless and pays its pinned owner.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - positionId: LP position NFT token ID to unstake.
//
// Returns:
//   - string: Pool path where the position was staked.
//
// Halt check: reverts while the Withdraw halt scope is active.
func UnStakeToken(cur realm, positionId uint64) string {
	return getImplementation().UnStakeToken(0, cur, positionId)
}

// CollectReward collects both the GNS emission and external incentive rewards for a live staked
// deposit or an exit checkpoint left by UnStakeToken.
//
// A live-deposit collect requires the depositor/owner. An exit-checkpoint collect is permissionless
// and pays the owner pinned in the checkpoint.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - positionId: Staked position NFT token ID or position with an exit checkpoint.
//
// Returns:
//   - string: GNS emission amount sent to the user.
//   - string: GNS emission penalty amount sent to the community pool.
//   - map[string]int64: Gross external reward amount per reward token, before the staking-reward fee.
//   - map[string]int64: External penalty amount per reward token.
//
// Halt check: reverts while the Withdraw halt scope is active.
func CollectReward(cur realm, positionId uint64) (string, string, map[string]int64, map[string]int64) {
	emissionToUser, emissionPenalty, externalRewards, externalPenalties := getImplementation().CollectReward(0, cur, positionId)
	return emissionToUser, emissionPenalty, cloneStringInt64Map(externalRewards), cloneStringInt64Map(externalPenalties)
}

// CollectEmissionReward collects only the GNS emission reward for a live staked deposit or an exit
// checkpoint left by UnStakeToken.
//
// A live-deposit collect requires the depositor/owner. An exit-checkpoint collect is permissionless
// and pays the owner pinned in the checkpoint.
//
// External incentive rewards keep accruing; collect them with CollectExternalIncentiveReward.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - positionId: Staked position NFT token ID or position with an exit checkpoint.
//
// Returns:
//   - int64: GNS emission amount sent to the user.
//   - int64: GNS emission penalty amount sent to the community pool.
//
// Halt check: reverts while the Withdraw halt scope is active.
func CollectEmissionReward(cur realm, positionId uint64) (int64, int64) {
	return getImplementation().CollectEmissionReward(0, cur, positionId)
}

// CollectExternalIncentiveReward collects one external incentive reward for a live staked deposit
// or an exit checkpoint left by UnStakeToken.
//
// A live-deposit collect requires the depositor/owner. An exit-checkpoint collect is permissionless
// and pays the owner pinned in the checkpoint.
//
// The GNS emission reward and every other incentive keep accruing; collect the emission reward with
// CollectEmissionReward and the other incentives by calling this with their own incentive id.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - positionId: Staked position NFT token ID or position with an exit checkpoint.
//   - incentiveId: External incentive identifier to collect.
//
// Returns:
//   - int64: Gross reward amount before the staking-reward fee.
//   - int64: Penalty amount retained by the incentive.
//
// Halt check: reverts while the Withdraw halt scope is active.
func CollectExternalIncentiveReward(cur realm, positionId uint64, incentiveId string) (int64, int64) {
	return getImplementation().CollectExternalIncentiveReward(0, cur, positionId, incentiveId)
}

// SetPoolTier assigns a pool to an internal GNS emission reward tier.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - poolPath: Pool path whose emission tier is assigned.
//   - tier: Target tier number from 0 through 3; zero removes the pool from emission targeting.
//
// Halt check: reverts while the Staker halt scope is active.
func SetPoolTier(cur realm, poolPath string, tier uint64) {
	getImplementation().SetPoolTier(0, cur, poolPath, tier)
}

// ChangePoolTier changes the internal GNS emission tier assigned to a pool.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - poolPath: Pool path whose emission tier is changed.
//   - tier: New tier number from 0 through 3; zero means no internal-emission target.
//
// Halt check: reverts while the Staker halt scope is active.
func ChangePoolTier(cur realm, poolPath string, tier uint64) {
	getImplementation().ChangePoolTier(0, cur, poolPath, tier)
}

// RemovePoolTier removes a pool from the internal GNS emission tier system.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - poolPath: Pool path to remove from emission-tier membership.
//
// Halt check: reverts while the Staker halt scope is active.
func RemovePoolTier(cur realm, poolPath string) {
	getImplementation().RemovePoolTier(0, cur, poolPath)
}

// CreateExternalIncentive creates an external reward incentive for a pool.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - targetPoolPath: Pool path whose liquidity providers will receive the incentive.
//   - rewardToken: Registered token path used to pay the incentive.
//   - rewardAmount: Total reward amount deposited, in reward-token units.
//   - startTimestamp: Incentive start time as an inclusive Unix timestamp.
//   - endTimestamp: Incentive end time as an inclusive Unix timestamp.
//
// Any caller may create an incentive after satisfying the token, duration, start-time,
// reward-minimum, and GNS-deposit checks.
//
// Halt check: reverts while the Staker halt scope is active.
func CreateExternalIncentive(
	cur realm,
	targetPoolPath string,
	rewardToken string,
	rewardAmount int64,
	startTimestamp int64,
	endTimestamp int64,
) {
	getImplementation().CreateExternalIncentive(
		0,
		cur,
		targetPoolPath,
		rewardToken,
		rewardAmount,
		startTimestamp,
		endTimestamp,
	)
}

// EndExternalIncentive finalizes an external incentive once its end timestamp has passed,
// sending the unclaimable/remainder reward portion and GNS deposit to the explicit refundAddress.
// Only the incentive creator or admin may call it; an outstanding exit checkpoint for this
// incentive must be collected or forfeited first.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - targetPoolPath: Pool path containing the incentive.
//   - incentiveId: Unique incentive identifier to finalize.
//   - refundAddress: Address receiving the refundable reward tokens and GNS deposit.
//
// Halt check: reverts while the Withdraw halt scope is active.
func EndExternalIncentive(cur realm, targetPoolPath, incentiveId string, refundAddress address) {
	getImplementation().EndExternalIncentive(0, cur, targetPoolPath, incentiveId, refundAddress)
}

// CancelExternalIncentive cancels an external incentive that has not started yet,
// removing it and refunding the reward tokens and the GNS deposit to the creator.
// Callable by admin, governance, or the incentive creator.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - targetPoolPath: Pool path containing the incentive.
//   - incentiveId: Unique incentive identifier to cancel.
//
// Halt check: reverts while the Withdraw halt scope is active.
func CancelExternalIncentive(cur realm, targetPoolPath, incentiveId string) {
	getImplementation().CancelExternalIncentive(0, cur, targetPoolPath, incentiveId)
}

// CollectExternalIncentivePenalty collects accumulated warm-up penalties after
// EndExternalIncentive has finalized the incentive, sending them to refundAddress.
// Only the incentive creator or admin may call it.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - targetPoolPath: Pool path containing the incentive.
//   - incentiveId: Unique incentive identifier whose penalty is collected.
//   - refundAddress: Address receiving the collected penalty amount.
//
// Returns:
//   - int64: Penalty amount transferred, capped by the staker's available reward-token balance.
//
// Halt check: reverts while the Withdraw halt scope is active.
func CollectExternalIncentivePenalty(cur realm, targetPoolPath, incentiveId string, refundAddress address) int64 {
	return getImplementation().CollectExternalIncentivePenalty(0, cur, targetPoolPath, incentiveId, refundAddress)
}

// AddToken adds a token to the reward token whitelist.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - tokenPath: Registered token path to add to the allowed reward-token list.
//
// Halt check: reverts while the Staker halt scope is active.
func AddToken(cur realm, tokenPath string) {
	getImplementation().AddToken(0, cur, tokenPath)
}

// RemoveToken removes a token from the reward token whitelist.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - tokenPath: Token path to remove from the allowed reward-token list.
//
// Halt check: reverts while the Staker halt scope is active.
func RemoveToken(cur realm, tokenPath string) {
	getImplementation().RemoveToken(0, cur, tokenPath)
}

// SetDeniedRewardToken sets or clears the operational deny flag for an external
// incentive reward token. Pool-pair tokens qualify as reward tokens without the
// governance allowlist (by design), so this flag is the only lever to stop NEW
// incentives in a pair token whose issuer turned hostile. Existing incentives
// and their collection are deliberately unaffected; the ledger-level delivery
// guard in the implementation bounds their blast radius instead.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - tokenPath: Reward-token path whose deny status is changed.
//   - denied: True to block new incentives for tokenPath; false to clear that block.
//
// Halt check: reverts while the Staker halt scope is active.
func SetDeniedRewardToken(cur realm, tokenPath string, denied bool) {
	getImplementation().SetDeniedRewardToken(0, cur, tokenPath, denied)
}

// SetWarmUp configures the duration for the warm-up tier selected by its fixed ratio.
// Finite tiers are capped at 365 days; the final 100% tier must retain math.MaxInt64.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - pct: Warm-up payout percentage selecting one of the 30%, 50%, 70%, or 100% tiers.
//   - timeDuration: Warm-up duration in Unix seconds for the selected percentage tier; finite tiers are capped at 365 days and the 100% tier uses math.MaxInt64.
//
// Halt check: reverts while the Staker halt scope is active.
func SetWarmUp(cur realm, pct, timeDuration int64) {
	getImplementation().SetWarmUp(0, cur, pct, timeDuration)
}

// SetDepositGnsAmount sets the GNS deposit required for each external incentive.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - amount: GNS amount required as the per-incentive deposit.
//
// Halt check: reverts while the Staker halt scope is active.
func SetDepositGnsAmount(cur realm, amount int64) {
	getImplementation().SetDepositGnsAmount(0, cur, amount)
}

// SetMinimumRewardAmount sets the default minimum reward amount required to create an external
// incentive. A token-specific override may apply.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - amount: Default minimum reward amount, measured in the reward token's units.
//
// Halt check: reverts while the Staker halt scope is active.
func SetMinimumRewardAmount(cur realm, amount int64) {
	getImplementation().SetMinimumRewardAmount(0, cur, amount)
}

// SetTokenMinimumRewardAmount sets minimum reward amounts per token.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - paramsStr: Colon-delimited token path and minimum amount (`tokenPath:amount`); amount zero removes the override.
//
// Halt check: reverts while the Staker halt scope is active.
func SetTokenMinimumRewardAmount(cur realm, paramsStr string) {
	getImplementation().SetTokenMinimumRewardAmount(0, cur, paramsStr)
}

// SetUnStakingFee sets the unstaking fee rate in basis points (0-1,000; 100 = 1%).
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - fee: Unstaking fee rate in basis points, from 0 through 1,000 inclusive.
//
// Halt check: reverts while the Staker halt scope is active.
func SetUnStakingFee(cur realm, fee uint64) {
	getImplementation().SetUnStakingFee(0, cur, fee)
}
