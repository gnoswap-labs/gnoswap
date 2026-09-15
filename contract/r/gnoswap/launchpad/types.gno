package launchpad

import (
	"gno.land/p/gnoswap/uint256"
	rotree "gno.land/p/nt/bptree/rotree/v0"
	bptree "gno.land/p/nt/bptree/v0"
)

type ILaunchpad interface {
	ILaunchpadProject
	ILaunchpadDeposit
	ILaunchpadGetter
}

type ILaunchpadProject interface {
	// CreateProject creates a project and its reward tiers in the current launchpad realm.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the launchpad proxy.
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
	//   - projectID: identifier assigned to the newly created project.
	CreateProject(
		_ int,
		rlm realm,
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
	) string
	// TransferLeftFromProjectByAdmin transfers unreserved reward tokens from an ended project.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the launchpad proxy.
	//   - projectID: identifier of the ended project whose remaining balance is transferred.
	//   - recipient: destination address for the transferable balance.
	//
	// Returns:
	//   - amount: number of reward tokens transferred after active claims are reserved.
	TransferLeftFromProjectByAdmin(_ int, rlm realm, projectID string, recipient address) int64
	// CollectProtocolFee collects protocol-fee rewards allocated to the project recipient.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the launchpad proxy.
	CollectProtocolFee(_ int, rlm realm)
	// CollectEmissionReward collects accumulated launchpad emission rewards.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the launchpad proxy.
	CollectEmissionReward(_ int, rlm realm)
	// CollectProtocolFeeReward collects accumulated protocol-fee rewards for one token path.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the launchpad proxy.
	//   - tokenPath: token path whose accumulated protocol-fee reward is collected.
	CollectProtocolFeeReward(_ int, rlm realm, tokenPath string)
}

type ILaunchpadDeposit interface {
	// DepositGns creates a GNS deposit in the selected project tier.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the launchpad proxy.
	//   - targetProjectTierID: project-tier identifier in `{projectID}:{tierDuration}` form.
	//   - depositAmount: amount of GNS to stake in the selected tier.
	//   - referrer: optional referral address associated with the deposit.
	//
	// Returns:
	//   - depositID: identifier assigned to the newly created deposit.
	DepositGns(_ int, rlm realm, targetProjectTierID string, depositAmount int64, referrer string) string
	// CollectDepositGns withdraws a deposit's staked GNS after its tier permits withdrawal.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the launchpad proxy.
	//   - depositID: identifier of the deposit whose GNS is collected.
	//
	// Returns:
	//   - amount: GNS amount withdrawn from the deposit.
	//   - err: non-nil when the deposit cannot be collected.
	CollectDepositGns(_ int, rlm realm, depositID string) (int64, error)
	// CollectRewardByDepositId collects the project-token reward earned by a deposit.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the launchpad proxy.
	//   - depositID: identifier of the deposit whose reward is collected.
	//
	// Returns:
	//   - amount: project-token reward amount transferred to the depositor.
	CollectRewardByDepositId(_ int, rlm realm, depositID string) int64
}

type ILaunchpadGetter interface {
	// GetProjects returns a read-only tree containing projects keyed by project ID.
	//
	// Returns:
	//   - projects: read-only project tree for iteration without mutating stored state.
	GetProjects() *rotree.ReadOnlyTree
	// GetProjectName returns the human-readable name of a project.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//
	// Returns:
	//   - name: stored project name, or an empty string when lookup fails.
	//   - err: non-nil when projectId does not identify a stored project.
	GetProjectName(projectId string) (string, error)
	// GetProjectTokenPath returns the reward-token path configured for a project.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//
	// Returns:
	//   - tokenPath: configured project reward-token path, or an empty string on lookup failure.
	//   - err: non-nil when projectId does not identify a stored project.
	GetProjectTokenPath(projectId string) (string, error)
	// GetProjectDepositAmount returns the total reward-token allocation configured for a project.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//
	// Returns:
	//   - amount: configured project reward-token amount, or zero on lookup failure.
	//   - err: non-nil when projectId does not identify a stored project.
	GetProjectDepositAmount(projectId string) (int64, error)
	// GetProjectRecipient returns the address configured to receive a project's rewards.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//
	// Returns:
	//   - recipient: configured project recipient address, or the zero address on lookup failure.
	//   - err: non-nil when projectId does not identify a stored project.
	GetProjectRecipient(projectId string) (address, error)
	// GetProjectCondition returns the deposit condition for one token path in a project.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//   - tokenPath: token path whose required balance condition is requested.
	//
	// Returns:
	//   - condition: configured token condition, or nil when lookup fails.
	//   - err: non-nil when the project or token condition is not found.
	GetProjectCondition(projectId string, tokenPath string) (*ProjectCondition, error)
	// GetProjectTiersRatios returns reward allocation ratios keyed by tier duration.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//
	// Returns:
	//   - ratios: map from tier duration to its reward allocation ratio.
	//   - err: non-nil when projectId does not identify a stored project.
	GetProjectTiersRatios(projectId string) (map[int64]int64, error)
	// GetProjectCreatedHeight returns the block height at which a project was created.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//
	// Returns:
	//   - height: creation block height, or zero on lookup failure.
	//   - err: non-nil when projectId does not identify a stored project.
	GetProjectCreatedHeight(projectId string) (int64, error)
	// GetProjectCreatedAt returns the Unix timestamp at which a project was created.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//
	// Returns:
	//   - time: creation Unix timestamp, or zero on lookup failure.
	//   - err: non-nil when projectId does not identify a stored project.
	GetProjectCreatedAt(projectId string) (int64, error)

	// GetProjectTier returns one tier of a project by its duration.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//   - tier: tier duration in seconds.
	//
	// Returns:
	//   - projectTier: requested tier, or nil when lookup fails.
	//   - err: non-nil when the project or requested tier is not found.
	GetProjectTier(projectId string, tier int64) (*ProjectTier, error)
	// GetProjectTierDistributeAmountPerSecondX128 returns a tier's Q128-scaled reward rate.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//   - tier: tier duration in seconds.
	//
	// Returns:
	//   - amountPerSecondX128: reward tokens per second scaled by 2^128.
	//   - err: non-nil when the project or requested tier is not found.
	GetProjectTierDistributeAmountPerSecondX128(projectId string, tier int64) (*uint256.Uint, error)
	// GetProjectTierTotalDistributeAmount returns the total reward allocation for a tier.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//   - tier: tier duration in seconds.
	//
	// Returns:
	//   - amount: total reward-token amount allocated to the tier.
	//   - err: non-nil when the project or requested tier is not found.
	GetProjectTierTotalDistributeAmount(projectId string, tier int64) (int64, error)
	// GetProjectTierTotalDepositAmount returns the cumulative GNS deposited into a tier.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//   - tier: tier duration in seconds.
	//
	// Returns:
	//   - amount: cumulative GNS amount deposited into the tier.
	//   - err: non-nil when the project or requested tier is not found.
	GetProjectTierTotalDepositAmount(projectId string, tier int64) (int64, error)
	// GetProjectTierTotalWithdrawAmount returns the cumulative GNS withdrawn from a tier.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//   - tier: tier duration in seconds.
	//
	// Returns:
	//   - amount: cumulative GNS amount withdrawn from the tier.
	//   - err: non-nil when the project or requested tier is not found.
	GetProjectTierTotalWithdrawAmount(projectId string, tier int64) (int64, error)
	// GetProjectTierTotalDepositCount returns the cumulative number of tier deposits.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//   - tier: tier duration in seconds.
	//
	// Returns:
	//   - count: cumulative number of deposits recorded for the tier.
	//   - err: non-nil when the project or requested tier is not found.
	GetProjectTierTotalDepositCount(projectId string, tier int64) (int64, error)
	// GetProjectTierTotalWithdrawCount returns the cumulative number of tier withdrawals.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//   - tier: tier duration in seconds.
	//
	// Returns:
	//   - count: cumulative number of withdrawals recorded for the tier.
	//   - err: non-nil when the project or requested tier is not found.
	GetProjectTierTotalWithdrawCount(projectId string, tier int64) (int64, error)
	// GetProjectTierTotalCollectedAmount returns the cumulative reward amount collected from a tier.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//   - tier: tier duration in seconds.
	//
	// Returns:
	//   - amount: cumulative project-token reward amount collected from the tier.
	//   - err: non-nil when the project or requested tier is not found.
	GetProjectTierTotalCollectedAmount(projectId string, tier int64) (int64, error)
	// GetProjectTierStartTime returns the Unix timestamp when a tier starts distributing rewards.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//   - tier: tier duration in seconds.
	//
	// Returns:
	//   - time: tier distribution start Unix timestamp.
	//   - err: non-nil when the project or requested tier is not found.
	GetProjectTierStartTime(projectId string, tier int64) (int64, error)
	// GetProjectTierEndTime returns the Unix timestamp when a tier stops distributing rewards.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//   - tier: tier duration in seconds.
	//
	// Returns:
	//   - time: tier distribution end Unix timestamp.
	//   - err: non-nil when the project or requested tier is not found.
	GetProjectTierEndTime(projectId string, tier int64) (int64, error)

	// GetDepositCount returns the number of deposits currently stored.
	//
	// Returns:
	//   - count: number of stored deposits.
	GetDepositCount() int
	// GetCurrentDepositId returns the latest allocated deposit identifier.
	//
	// Returns:
	//   - depositID: latest numeric deposit identifier.
	GetCurrentDepositId() int64
	// GetProjectTierRewards returns a read-only reward-state tree for a project tier.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//   - tier: tier duration in seconds.
	//
	// Returns:
	//   - rewards: read-only tree of reward states keyed by deposit ID.
	GetProjectTierRewards(projectId string, tier int64) *rotree.ReadOnlyTree

	// GetDeposit returns the stored deposit identified by depositId.
	//
	// Parameters:
	//   - depositId: identifier of the deposit to inspect.
	//
	// Returns:
	//   - deposit: stored deposit, or its zero value when lookup fails.
	//   - err: non-nil when depositId does not identify a stored deposit.
	GetDeposit(depositId string) (Deposit, error)
	// GetDepositProjectID returns the project identifier associated with a deposit.
	//
	// Parameters:
	//   - depositId: identifier of the deposit to inspect.
	//
	// Returns:
	//   - projectID: project identifier recorded in the deposit.
	//   - err: non-nil when depositId does not identify a stored deposit.
	GetDepositProjectID(depositId string) (string, error)
	// GetDepositTier returns the tier duration recorded in a deposit.
	//
	// Parameters:
	//   - depositId: identifier of the deposit to inspect.
	//
	// Returns:
	//   - tier: deposit tier duration in seconds.
	//   - err: non-nil when depositId does not identify a stored deposit.
	GetDepositTier(depositId string) (int64, error)
	// GetDepositProjectTierID returns the combined project-tier identifier for a deposit.
	//
	// Parameters:
	//   - depositId: identifier of the deposit to inspect.
	//
	// Returns:
	//   - projectTierID: identifier in `{projectID}:{tierDuration}` form.
	//   - err: non-nil when depositId does not identify a stored deposit.
	GetDepositProjectTierID(depositId string) (string, error)
	// GetDepositAmount returns the currently staked GNS amount in a deposit.
	//
	// Parameters:
	//   - depositId: identifier of the deposit to inspect.
	//
	// Returns:
	//   - amount: current GNS amount held by the deposit.
	//   - err: non-nil when depositId does not identify a stored deposit.
	GetDepositAmount(depositId string) (int64, error)
	// GetDepositWithdrawnHeight returns the block height at which a deposit was withdrawn.
	//
	// Parameters:
	//   - depositId: identifier of the deposit to inspect.
	//
	// Returns:
	//   - height: withdrawal block height, or the stored zero value if not withdrawn.
	//   - err: non-nil when depositId does not identify a stored deposit.
	GetDepositWithdrawnHeight(depositId string) (int64, error)
	// GetDepositWithdrawnTime returns the Unix timestamp at which a deposit was withdrawn.
	//
	// Parameters:
	//   - depositId: identifier of the deposit to inspect.
	//
	// Returns:
	//   - time: withdrawal Unix timestamp, or the stored zero value if not withdrawn.
	//   - err: non-nil when depositId does not identify a stored deposit.
	GetDepositWithdrawnTime(depositId string) (int64, error)
	// GetDepositCreatedHeight returns the block height at which a deposit was created.
	//
	// Parameters:
	//   - depositId: identifier of the deposit to inspect.
	//
	// Returns:
	//   - height: deposit creation block height.
	//   - err: non-nil when depositId does not identify a stored deposit.
	GetDepositCreatedHeight(depositId string) (int64, error)
	// GetDepositCreatedAt returns the Unix timestamp at which a deposit was created.
	//
	// Parameters:
	//   - depositId: identifier of the deposit to inspect.
	//
	// Returns:
	//   - time: deposit creation Unix timestamp.
	//   - err: non-nil when depositId does not identify a stored deposit.
	GetDepositCreatedAt(depositId string) (int64, error)
	// GetDepositEndTime returns the Unix timestamp when a deposit's tier ends.
	//
	// Parameters:
	//   - depositId: identifier of the deposit to inspect.
	//
	// Returns:
	//   - time: deposit tier end Unix timestamp.
	//   - err: non-nil when depositId does not identify a stored deposit.
	GetDepositEndTime(depositId string) (int64, error)
	// GetTotalGNSStakedAmount returns the current GNS amount staked across all deposits.
	//
	// Returns:
	//   - amount: aggregate currently staked GNS amount.
	GetTotalGNSStakedAmount() int64

	// GetProjectTierRewardManagerCount returns the number of stored tier reward managers.
	//
	// Returns:
	//   - count: number of project-tier reward managers.
	GetProjectTierRewardManagerCount() int
	// GetProjectTierRewardManager returns the reward manager for a project tier.
	//
	// Parameters:
	//   - projectTierId: identifier of the project tier.
	//
	// Returns:
	//   - manager: reward manager for the project tier, or nil on lookup failure.
	//   - err: non-nil when projectTierId does not identify a stored manager.
	GetProjectTierRewardManager(projectTierId string) (*RewardManager, error)
	// GetProjectTierRewardDistributeAmountPerSecondX128 returns a tier manager's Q128 reward rate.
	//
	// Parameters:
	//   - projectTierId: identifier of the project tier.
	//
	// Returns:
	//   - amountPerSecondX128: reward tokens per second scaled by 2^128.
	//   - err: non-nil when projectTierId does not identify a stored manager.
	GetProjectTierRewardDistributeAmountPerSecondX128(projectTierId string) (*uint256.Uint, error)
	// GetProjectTierRewardAccumulatedRewardPerDepositX128 returns accumulated Q128 reward per deposit.
	//
	// Parameters:
	//   - projectTierId: identifier of the project tier.
	//
	// Returns:
	//   - accumulatedX128: accumulated reward-per-deposit value scaled by 2^128.
	//   - err: non-nil when projectTierId does not identify a stored manager.
	GetProjectTierRewardAccumulatedRewardPerDepositX128(projectTierId string) (*uint256.Uint, error)
	// GetProjectTierRewardTotalDistributeAmount returns total reward tokens allocated to a tier.
	//
	// Parameters:
	//   - projectTierId: identifier of the project tier.
	//
	// Returns:
	//   - amount: total reward-token allocation.
	//   - err: non-nil when projectTierId does not identify a stored manager.
	GetProjectTierRewardTotalDistributeAmount(projectTierId string) (int64, error)
	// GetProjectTierRewardTotalClaimedAmount returns total reward tokens claimed from a tier.
	//
	// Parameters:
	//   - projectTierId: identifier of the project tier.
	//
	// Returns:
	//   - amount: cumulative claimed reward-token amount.
	//   - err: non-nil when projectTierId does not identify a stored manager.
	GetProjectTierRewardTotalClaimedAmount(projectTierId string) (int64, error)
	// GetProjectTierRewardDistributeStartTime returns a tier manager's distribution start time.
	//
	// Parameters:
	//   - projectTierId: identifier of the project tier.
	//
	// Returns:
	//   - time: distribution start Unix timestamp.
	//   - err: non-nil when projectTierId does not identify a stored manager.
	GetProjectTierRewardDistributeStartTime(projectTierId string) (int64, error)
	// GetProjectTierRewardDistributeEndTime returns a tier manager's distribution end time.
	//
	// Parameters:
	//   - projectTierId: identifier of the project tier.
	//
	// Returns:
	//   - time: distribution end Unix timestamp.
	//   - err: non-nil when projectTierId does not identify a stored manager.
	GetProjectTierRewardDistributeEndTime(projectTierId string) (int64, error)
	// GetProjectTierRewardAccumulatedDistributeAmount returns the accumulated distributed reward amount.
	//
	// Parameters:
	//   - projectTierId: identifier of the project tier.
	//
	// Returns:
	//   - amount: accumulated reward-token amount accounted for distribution.
	//   - err: non-nil when projectTierId does not identify a stored manager.
	GetProjectTierRewardAccumulatedDistributeAmount(projectTierId string) (int64, error)
	// GetProjectTierRewardAccumulatedTime returns the timestamp through which rewards are accumulated.
	//
	// Parameters:
	//   - projectTierId: identifier of the project tier.
	//
	// Returns:
	//   - time: accumulated Unix timestamp.
	//   - err: non-nil when projectTierId does not identify a stored manager.
	GetProjectTierRewardAccumulatedTime(projectTierId string) (int64, error)
	// GetProjectTierRewardClaimableDuration returns the delay before rewards become claimable.
	//
	// Parameters:
	//   - projectTierId: identifier of the project tier.
	//
	// Returns:
	//   - duration: claimable delay in seconds.
	//   - err: non-nil when projectTierId does not identify a stored manager.
	GetProjectTierRewardClaimableDuration(projectTierId string) (int64, error)

	// GetRewardState returns the reward state for one deposit in a project tier.
	//
	// Parameters:
	//   - projectTierId: identifier of the project tier.
	//   - depositId: identifier of the deposit whose reward state is requested.
	//
	// Returns:
	//   - rewardState: stored reward state, or nil on lookup failure.
	//   - err: non-nil when the project tier or deposit reward state is missing.
	GetRewardState(projectTierId string, depositId string) (*RewardState, error)
	// GetProjectActiveStatus reports whether a project is active at the current time.
	//
	// Parameters:
	//   - projectId: identifier of the project to inspect.
	//
	// Returns:
	//   - active: true when the project is currently active; false otherwise.
	//   - err: non-nil when projectId does not identify a stored project.
	GetProjectActiveStatus(projectId string) (bool, error)
}

type ILaunchpadStore interface {
	// HasProjectsKey reports whether the projects tree has a persisted store key.
	//
	// Returns:
	//   - exists: true when the projects store key is present.
	HasProjectsKey() bool
	// GetProjects returns the persisted project tree.
	//
	// Returns:
	//   - projects: tree containing projects keyed by project ID.
	GetProjects() *bptree.BPTree
	// SetProjects persists the project tree in the current store realm.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: current realm context forwarded for current-realm validation.
	//   - projects: project tree to persist.
	//
	// Returns:
	//   - err: non-nil when the realm context fails store validation or persistence fails.
	SetProjects(_ int, rlm realm, projects *bptree.BPTree) error

	// HasProjectRecipientsKey reports whether the project-recipient tree has a persisted key.
	//
	// Returns:
	//   - exists: true when the project-recipient store key is present.
	HasProjectRecipientsKey() bool
	// GetProjectRecipients returns the persisted project-recipient membership tree.
	//
	// Returns:
	//   - recipients: tree mapping project identifiers to recipient membership data.
	GetProjectRecipients() *bptree.BPTree
	// SetProjectRecipients persists the project-recipient membership tree.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: current realm context forwarded for current-realm validation.
	//   - recipients: project-recipient membership tree to persist.
	//
	// Returns:
	//   - err: non-nil when the realm context fails store validation or persistence fails.
	SetProjectRecipients(_ int, rlm realm, recipients *bptree.BPTree) error

	// HasProjectTierRewardManagersKey reports whether tier reward managers have a persisted key.
	//
	// Returns:
	//   - exists: true when the reward-manager store key is present.
	HasProjectTierRewardManagersKey() bool
	// GetProjectTierRewardManagers returns the persisted tier reward-manager tree.
	//
	// Returns:
	//   - managers: tree keyed by project-tier identifier.
	GetProjectTierRewardManagers() *bptree.BPTree
	// SetProjectTierRewardManagers persists the tier reward-manager tree.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: current realm context forwarded for current-realm validation.
	//   - managers: tier reward-manager tree to persist.
	//
	// Returns:
	//   - err: non-nil when the realm context fails store validation or persistence fails.
	SetProjectTierRewardManagers(_ int, rlm realm, managers *bptree.BPTree) error

	// DepositCounter
	// HasDepositCounterStoreKey reports whether the deposit counter has a persisted key.
	//
	// Returns:
	//   - exists: true when the deposit-counter store key is present.
	HasDepositCounterStoreKey() bool
	// GetDepositCounter returns the persisted counter used to allocate deposit IDs.
	//
	// Returns:
	//   - counter: deposit ID counter.
	GetDepositCounter() *Counter
	// SetDepositCounter persists the counter used to allocate deposit IDs.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: current realm context forwarded for current-realm validation.
	//   - counter: counter state to persist.
	//
	// Returns:
	//   - err: non-nil when the realm context fails store validation or persistence fails.
	SetDepositCounter(_ int, rlm realm, counter *Counter) error
	// NextDepositID advances the deposit counter and returns its new identifier.
	//
	// Returns:
	//   - depositID: newly allocated deposit identifier.
	NextDepositID() string

	// HasDepositsKey reports whether the deposits tree has a persisted store key.
	//
	// Returns:
	//   - exists: true when the deposits store key is present.
	HasDepositsKey() bool
	// GetDeposits returns the persisted deposit tree.
	//
	// Returns:
	//   - deposits: tree containing deposits keyed by deposit ID.
	GetDeposits() *bptree.BPTree
	// SetDeposits persists the deposit tree in the current store realm.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: current realm context forwarded for current-realm validation.
	//   - deposits: deposit tree to persist.
	//
	// Returns:
	//   - err: non-nil when the realm context fails store validation or persistence fails.
	SetDeposits(_ int, rlm realm, deposits *bptree.BPTree) error

	// HasTotalGNSStakedAmountKey reports whether the aggregate GNS stake has a persisted key.
	//
	// Returns:
	//   - exists: true when the total-stake store key is present.
	HasTotalGNSStakedAmountKey() bool
	// GetTotalGNSStakedAmount returns the aggregate GNS amount currently staked.
	//
	// Returns:
	//   - amount: total GNS amount currently held in deposits.
	GetTotalGNSStakedAmount() int64
	// SetTotalGNSStakedAmount persists the aggregate current GNS stake.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: current realm context forwarded for current-realm validation.
	//   - amount: aggregate GNS amount currently staked.
	//
	// Returns:
	//   - err: non-nil when the realm context fails store validation or persistence fails.
	SetTotalGNSStakedAmount(_ int, rlm realm, amount int64) error
}
