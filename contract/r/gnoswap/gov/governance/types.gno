package governance

import (
	rotree "gno.land/p/nt/bptree/rotree/v0"
	bptree "gno.land/p/nt/bptree/v0"
)

type IGovernance interface {
	IGovernanceManager
	IGovernanceGetter
	Render(path string) string
}

type IGovernanceManager interface {
	// Proposal management
	// ProposeText creates a non-executable proposal for community discussion.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the governance proxy.
	//   - title: short, non-empty title describing the proposal.
	//   - description: non-empty proposal rationale and discussion text.
	//
	// Returns:
	//   - int64: ID assigned to the newly created text proposal.
	ProposeText(
		_ int, rlm realm,
		title string,
		description string,
	) int64

	// ProposeCommunityPoolSpend creates a proposal to transfer registered tokens from the community pool.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the governance proxy.
	//   - title: short title describing the requested disbursement.
	//   - description: rationale and budget details for the disbursement.
	//   - to: recipient address for the community-pool transfer.
	//   - tokenPath: registered token realm path to transfer.
	//   - amount: positive transfer amount in the token's smallest unit.
	//
	// Returns:
	//   - int64: ID assigned to the newly created community-pool-spend proposal.
	ProposeCommunityPoolSpend(
		_ int, rlm realm,
		title string,
		description string,
		to address,
		tokenPath string,
		amount int64,
	) int64

	// ProposeParameterChange creates a proposal containing registered parameter-handler executions.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the governance proxy.
	//   - title: short title describing the parameter changes.
	//   - description: rationale and impact details for the changes.
	//   - numToExecute: number of encoded parameter-change executions expected.
	//   - executions: execution messages encoded with the governance execution delimiters.
	//
	// Returns:
	//   - int64: ID assigned to the newly created parameter-change proposal.
	ProposeParameterChange(
		_ int, rlm realm,
		title string,
		description string,
		numToExecute int64,
		executions string,
	) int64

	// Voting
	// Vote records the caller's final yes or no vote on a proposal.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the governance proxy.
	//   - proposalId: ID of the proposal to vote on.
	//   - yes: true to cast an affirmative vote, false to cast a negative vote.
	//
	// Returns:
	//   - string: caller's applied voting weight formatted as a decimal string.
	Vote(
		_ int, rlm realm,
		proposalId int64,
		yes bool,
	) string

	// Execution
	// Execute applies an approved executable proposal within its delay and execution window.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the governance proxy.
	//   - proposalId: ID of the proposal to execute.
	//
	// Returns:
	//   - int64: ID of the proposal successfully executed.
	Execute(
		_ int, rlm realm,
		proposalId int64,
	) int64

	// Cancel marks an upcoming proposal as cancelled at the request of its proposer.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the governance proxy.
	//   - proposalId: ID of the proposal to cancel.
	//
	// Returns:
	//   - int64: ID of the proposal successfully cancelled.
	Cancel(
		_ int, rlm realm,
		proposalId int64,
	) int64

	// RemoveInactiveProposalFromIndex removes an inactive proposal from the snapshot index.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the governance proxy.
	//   - proposalID: ID of the inactive proposal index entry to remove.
	RemoveInactiveProposalFromIndex(_ int, rlm realm, proposalID int64)

	// Configuration
	// Reconfigure validates and stores a new governance configuration version.
	//
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the governance proxy.
	//   - votingStartDelay: seconds from proposal creation until voting opens.
	//   - votingPeriod: seconds for which voting remains open.
	//   - votingWeightSmoothingDuration: seconds used to smooth delegation history for voting weight.
	//   - quorum: required approval percentage of total xGNS supply, from 0 through 100.
	//   - proposalCreationThreshold: minimum xGNS amount, in six-decimal base units, required to create a proposal
	//   - executionDelay: seconds required between approval and execution.
	//   - executionWindow: seconds after the delay during which execution is allowed.
	//
	// Returns:
	//   - int64: newly stored governance configuration version.
	Reconfigure(
		_ int, rlm realm,
		votingStartDelay int64,
		votingPeriod int64,
		votingWeightSmoothingDuration int64,
		quorum int64,
		proposalCreationThreshold int64,
		executionDelay int64,
		executionWindow int64,
	) int64
}

// IGovernanceGetter provides read-only access to governance data.
type IGovernanceGetter interface {
	// Store data getters
	// GetLatestConfigVersion returns the version number of the current governance configuration.
	//
	// Returns:
	//   - int64: current configuration version used for new proposals.
	GetLatestConfigVersion() int64
	// GetCurrentProposalID returns the current proposal ID counter value.
	//
	// Returns:
	//   - int64: current proposal identifier counter value.
	GetCurrentProposalID() int64
	// GetMaxSmoothingPeriod returns the upper bound for the voting-weight smoothing period.
	//
	// Returns:
	//   - int64: fixed maximum smoothing duration of 30 days (2,592,000 seconds).
	GetMaxSmoothingPeriod() int64

	// Config getters
	// GetLatestConfig returns the current governance configuration.
	//
	// Returns:
	//   - Config: latest stored configuration, or a zero configuration when unavailable.
	//   - error: nil when found; otherwise an error indicating that the configuration is unavailable.
	GetLatestConfig() (Config, error)
	// GetConfig returns a governance configuration by version.
	//
	// Parameters:
	//   - configVersion: configuration version to retrieve.
	//
	// Returns:
	//   - Config: configuration stored at the requested version, or a zero configuration when absent.
	//   - error: nil when found; otherwise an error identifying the missing version.
	GetConfig(configVersion int64) (Config, error)

	// GetProposals returns a read-only view of stored proposals keyed by decimal proposal ID.
	//
	// Returns:
	//   - *rotree.ReadOnlyTree: read-only proposal tree with cloned proposal values.
	GetProposals() *rotree.ReadOnlyTree
	// ExistsProposal reports whether a proposal is stored for an ID.
	//
	// Parameters:
	//   - proposalID: proposal identifier to look up.
	//
	// Returns:
	//   - bool: true when a proposal exists for proposalID.
	ExistsProposal(proposalID int64) bool
	// GetProposerByProposalId returns the address that created a proposal.
	//
	// Parameters:
	//   - proposalId: proposal identifier to look up.
	//
	// Returns:
	//   - address: proposer address recorded on the proposal.
	//   - error: nil when found; otherwise an error indicating the proposal is missing.
	GetProposerByProposalId(proposalId int64) (address, error)
	// GetProposalTypeByProposalId returns the type discriminator of a proposal.
	//
	// Parameters:
	//   - proposalId: proposal identifier to look up.
	//
	// Returns:
	//   - ProposalType: proposal type stored on the proposal.
	//   - error: nil when found; otherwise an error indicating the proposal is missing.
	GetProposalTypeByProposalId(proposalId int64) (ProposalType, error)
	// GetProposalCreatedAt returns a proposal's creation timestamp.
	//
	// Parameters:
	//   - proposalId: proposal identifier to look up.
	//
	// Returns:
	//   - int64: creation time as a Unix timestamp in seconds.
	//   - error: nil when found; otherwise an error indicating the proposal is missing.
	GetProposalCreatedAt(proposalId int64) (int64, error)
	// GetProposalCreatedHeight returns the block height at which a proposal was created.
	//
	// Parameters:
	//   - proposalId: proposal identifier to look up.
	//
	// Returns:
	//   - int64: creation block height.
	//   - error: nil when found; otherwise an error indicating the proposal is missing.
	GetProposalCreatedHeight(proposalId int64) (int64, error)
	// GetProposalCommunityPoolSpendInfo returns the treasury-transfer payload of a proposal.
	//
	// Parameters:
	//   - proposalID: proposal identifier to look up.
	//
	// Returns:
	//   - *CommunityPoolSpendInfo: spend payload, or nil when the proposal is absent or another type.
	//   - error: nil for a community-pool-spend proposal; otherwise a not-found or wrong-type error.
	GetProposalCommunityPoolSpendInfo(proposalID int64) (*CommunityPoolSpendInfo, error)
	// GetProposalExecutionInfo returns the parameter-execution payload of a proposal.
	//
	// Parameters:
	//   - proposalID: proposal identifier to look up.
	//
	// Returns:
	//   - *ExecutionInfo: execution payload, or nil when the proposal is absent or another type.
	//   - error: nil for a parameter-change proposal; otherwise a not-found or wrong-type error.
	GetProposalExecutionInfo(proposalID int64) (*ExecutionInfo, error)
	// GetYeaByProposalId returns the affirmative vote weight recorded on a proposal.
	//
	// Parameters:
	//   - proposalId: proposal identifier to look up.
	//
	// Returns:
	//   - int64: total yes-vote weight.
	//   - error: nil when found; otherwise an error indicating the proposal is missing.
	GetYeaByProposalId(proposalId int64) (int64, error)
	// GetNayByProposalId returns the negative vote weight recorded on a proposal.
	//
	// Parameters:
	//   - proposalId: proposal identifier to look up.
	//
	// Returns:
	//   - int64: total no-vote weight.
	//   - error: nil when found; otherwise an error indicating the proposal is missing.
	GetNayByProposalId(proposalId int64) (int64, error)
	// GetConfigVersionByProposalId returns the configuration version captured by a proposal.
	//
	// Parameters:
	//   - proposalId: proposal identifier to look up.
	//
	// Returns:
	//   - int64: configuration version used to create the proposal.
	//   - error: nil when found; otherwise an error indicating the proposal is missing.
	GetConfigVersionByProposalId(proposalId int64) (int64, error)
	// GetQuorumAmountByProposalId returns the proposal's stored quorum requirement.
	//
	// Parameters:
	//   - proposalId: proposal identifier to look up.
	//
	// Returns:
	//   - int64: minimum vote weight required for quorum.
	//   - error: nil when found; otherwise an error indicating the proposal is missing.
	GetQuorumAmountByProposalId(proposalId int64) (int64, error)
	// GetTitleByProposalId returns a proposal's title.
	//
	// Parameters:
	//   - proposalId: proposal identifier to look up.
	//
	// Returns:
	//   - string: title stored in proposal metadata.
	//   - error: nil when found; otherwise an error indicating the proposal is missing.
	GetTitleByProposalId(proposalId int64) (string, error)
	// GetDescriptionByProposalId returns a proposal's full description.
	//
	// Parameters:
	//   - proposalId: proposal identifier to look up.
	//
	// Returns:
	//   - string: description stored in proposal metadata.
	//   - error: nil when found; otherwise an error indicating the proposal is missing.
	GetDescriptionByProposalId(proposalId int64) (string, error)
	// GetProposalStatusByProposalId returns the current status string for a proposal.
	//
	// Parameters:
	//   - proposalId: proposal identifier to look up.
	//
	// Returns:
	//   - string: status computed from the proposal state and current time.
	//   - error: nil when found; otherwise an error indicating the proposal is missing.
	GetProposalStatusByProposalId(proposalId int64) (string, error)

	// Vote getters
	// GetVoteStatus returns the quorum and vote tallies stored for a proposal.
	//
	// Parameters:
	//   - proposalId: proposal identifier to look up.
	//
	// Returns:
	//   - quorum: minimum vote weight required for quorum.
	//   - maxVotingWeight: maximum voting weight captured at proposal creation.
	//   - yesWeight: total affirmative vote weight.
	//   - noWeight: total negative vote weight.
	//   - err: nil when found; otherwise an error indicating the proposal is missing.
	GetVoteStatus(proposalId int64) (quorum, maxVotingWeight, yesWeight, noWeight int64, err error)
	// GetVotingInfos returns a read-only view of a proposal's voter records.
	//
	// Parameters:
	//   - proposalID: proposal identifier whose voting records should be viewed.
	//
	// Returns:
	//   - *rotree.ReadOnlyTree: read-only voter-info tree, or nil when its stored tree is absent.
	GetVotingInfos(proposalID int64) *rotree.ReadOnlyTree
	// ExistsVotingInfo reports whether an address has a voting record for a proposal.
	//
	// Parameters:
	//   - proposalID: proposal identifier to inspect.
	//   - addr: voter address to look up.
	//
	// Returns:
	//   - bool: true when a voting record exists for the proposal and address.
	ExistsVotingInfo(proposalID int64, addr address) bool
	// GetVoteWeight returns the recorded voting weight for an address.
	//
	// Parameters:
	//   - proposalID: proposal identifier to inspect.
	//   - addr: voter address to look up.
	//
	// Returns:
	//   - int64: weight applied to the address's vote.
	//   - error: nil when a voting record exists; otherwise an error identifying the missing record.
	GetVoteWeight(proposalID int64, addr address) (int64, error)
	// GetVotedHeight returns the block height at which an address voted.
	//
	// Parameters:
	//   - proposalID: proposal identifier to inspect.
	//   - addr: voter address to look up.
	//
	// Returns:
	//   - int64: block height recorded for the vote.
	//   - error: nil when a voting record exists; otherwise an error identifying the missing record.
	GetVotedHeight(proposalID int64, addr address) (int64, error)
	// GetVotedAt returns the timestamp at which an address voted.
	//
	// Parameters:
	//   - proposalID: proposal identifier to inspect.
	//   - addr: voter address to look up.
	//
	// Returns:
	//   - int64: vote timestamp as Unix seconds.
	//   - error: nil when a voting record exists; otherwise an error identifying the missing record.
	GetVotedAt(proposalID int64, addr address) (int64, error)

	// GetUserProposals returns a read-only view of proposal IDs grouped by creator address.
	//
	// Returns:
	//   - *rotree.ReadOnlyTree: read-only creator-to-proposal-ID tree with copied ID slices.
	GetUserProposals() *rotree.ReadOnlyTree

	// Active proposal query
	// GetOldestActiveProposalSnapshotTime inspects the first timestamp-ordered active-proposal index entry.
	//
	// Returns:
	//   - snapshotTime: snapshot timestamp of the oldest active proposal.
	//   - hasActive: true when an active indexed proposal was found; false when the index is empty.
	//   - error: nil on success; otherwise an error when the index entry is missing or needs cleanup.
	GetOldestActiveProposalSnapshotTime() (int64, bool, error)

	// Voting weight snapshot getters
	// GetCurrentVotingWeightSnapshot computes the current total voting weight and its smoothed timestamp anchor.
	//
	// Returns:
	//   - totalVotingWeight: total delegation weight at the computed snapshot.
	//   - snapshotTime: Unix timestamp used as the snapshot anchor.
	//   - error: nil when the current configuration and snapshot are available; otherwise the lookup error.
	GetCurrentVotingWeightSnapshot() (int64, int64, error)
}

type IGovernanceStore interface {
	// Counter methods
	// HasConfigCounterStoreKey reports whether the configuration counter key exists.
	//
	// Returns:
	//   - bool: true when the configuration counter is present in persistent storage.
	HasConfigCounterStoreKey() bool
	// GetConfigCounter returns the persisted configuration-version counter.
	//
	// Returns:
	//   - *Counter: stored configuration counter; underlying storage/type failures panic.
	GetConfigCounter() *Counter
	// SetConfigCounter persists the configuration-version counter.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the internal store method; callers pass 0.
	//   - rlm: forwarded realm context for the persistent write; the store validates it as current.
	//   - counter: counter value to store.
	//
	// Returns:
	//   - error: nil when persisted; otherwise a spoofed-realm or key-value store error.
	SetConfigCounter(_ int, rlm realm, counter *Counter) error

	// HasProposalCounterStoreKey reports whether the proposal counter key exists.
	//
	// Returns:
	//   - bool: true when the proposal counter is present in persistent storage.
	HasProposalCounterStoreKey() bool
	// GetProposalCounter returns the persisted proposal-ID counter.
	//
	// Returns:
	//   - *Counter: stored proposal counter; underlying storage/type failures panic.
	GetProposalCounter() *Counter
	// SetProposalCounter persists the proposal-ID counter.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the internal store method; callers pass 0.
	//   - rlm: forwarded realm context for the persistent write; the store validates it as current.
	//   - counter: counter value to store.
	//
	// Returns:
	//   - error: nil when persisted; otherwise a spoofed-realm or key-value store error.
	SetProposalCounter(_ int, rlm realm, counter *Counter) error

	// Config methods
	// HasConfigsStoreKey reports whether the configurations tree key exists.
	//
	// Returns:
	//   - bool: true when the configurations tree is present in persistent storage.
	HasConfigsStoreKey() bool
	// SetConfigs replaces the persisted configuration-version tree.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the internal store method; callers pass 0.
	//   - rlm: forwarded realm context for the persistent write; the store validates it as current.
	//   - configs: configuration-version tree to store.
	//
	// Returns:
	//   - error: nil when persisted; otherwise a spoofed-realm or key-value store error.
	SetConfigs(_ int, rlm realm, configs *bptree.BPTree) error
	// SetConfig stores one configuration under its version key.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the internal store method; callers pass 0.
	//   - rlm: forwarded realm context for the persistent write; the store validates it as current.
	//   - version: configuration version key.
	//   - config: configuration value to store.
	//
	// Returns:
	//   - error: nil when persisted; otherwise a spoofed-realm, missing-tree, or key-value store error.
	SetConfig(_ int, rlm realm, version int64, config Config) error
	// GetConfig retrieves one configuration from the persisted version tree.
	//
	// Parameters:
	//   - version: configuration version key to look up.
	//
	// Returns:
	//   - Config: stored configuration, or its zero value when absent; wrong stored types panic.
	//   - bool: true when a configuration exists for version.
	GetConfig(version int64) (Config, bool)

	// Proposal methods
	// HasProposalsStoreKey reports whether the proposals tree key exists.
	//
	// Returns:
	//   - bool: true when the proposals tree is present in persistent storage.
	HasProposalsStoreKey() bool
	// GetProposals returns the mutable domain-owned proposals tree.
	//
	// Returns:
	//   - *bptree.BPTree: stored proposal tree keyed by proposal ID string; storage/type failures panic.
	GetProposals() *bptree.BPTree
	// GetProposal retrieves a proposal by numeric ID.
	//
	// Parameters:
	//   - proposalID: proposal identifier used as the tree key.
	//
	// Returns:
	//   - *Proposal: stored proposal when present and correctly typed.
	//   - bool: true when a valid proposal exists for proposalID.
	GetProposal(proposalID int64) (*Proposal, bool)
	// SetProposal stores a proposal under its matching numeric ID.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the internal store method; callers pass 0.
	//   - rlm: forwarded realm context for the persistent write; the store validates it as current.
	//   - proposalID: storage key that must match proposal.ID().
	//   - proposal: proposal value to persist.
	//
	// Returns:
	//   - error: nil when persisted; otherwise a spoofed-realm, missing-tree, or ID-mismatch error.
	SetProposal(_ int, rlm realm, proposalID int64, proposal *Proposal) error
	// SetProposals replaces the persisted proposals tree.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the internal store method; callers pass 0.
	//   - rlm: forwarded realm context for the persistent write; the store validates it as current.
	//   - proposals: proposal tree to persist.
	//
	// Returns:
	//   - error: nil when persisted; otherwise a spoofed-realm or key-value store error.
	SetProposals(_ int, rlm realm, proposals *bptree.BPTree) error

	// HasActiveProposalsBySnapshotStoreKey reports whether the active-proposal snapshot index exists.
	//
	// Returns:
	//   - bool: true when the timestamp-ordered active-proposal index is present.
	HasActiveProposalsBySnapshotStoreKey() bool
	// GetActiveProposalsBySnapshot returns the domain-owned active-proposal snapshot index.
	//
	// Returns:
	//   - *bptree.BPTree: index keyed by snapshot timestamp and containing proposal IDs; storage/type failures panic.
	GetActiveProposalsBySnapshot() *bptree.BPTree
	// SetActiveProposalsBySnapshot replaces the active-proposal snapshot index.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the internal store method; callers pass 0.
	//   - rlm: forwarded realm context for the persistent write; the store validates it as current.
	//   - tree: timestamp-ordered active-proposal index to persist.
	//
	// Returns:
	//   - error: nil when persisted; otherwise a spoofed-realm or key-value store error.
	SetActiveProposalsBySnapshot(_ int, rlm realm, tree *bptree.BPTree) error

	// Proposal voting info methods
	// HasProposalUserVotingInfosStoreKey reports whether the root voting-info tree exists.
	//
	// Returns:
	//   - bool: true when proposal voting-info storage is present.
	HasProposalUserVotingInfosStoreKey() bool
	// GetProposalUserVotingInfos returns the root proposal-to-voter-info tree.
	//
	// Returns:
	//   - *bptree.BPTree: stored tree containing one voter-info tree per proposal; storage/type failures panic.
	GetProposalUserVotingInfos() *bptree.BPTree
	// SetProposalUserVotingInfos replaces the root proposal-to-voter-info tree.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the internal store method; callers pass 0.
	//   - rlm: forwarded realm context for the persistent write; the store validates it as current.
	//   - votingInfos: root proposal-to-voter-info tree to persist.
	//
	// Returns:
	//   - error: nil when persisted; otherwise a spoofed-realm or key-value store error.
	SetProposalUserVotingInfos(_ int, rlm realm, votingInfos *bptree.BPTree) error
	// GetProposalVotingInfos returns the voter-info tree for one proposal.
	//
	// Parameters:
	//   - proposalID: proposal identifier used as the root-tree key.
	//
	// Returns:
	//   - *bptree.BPTree: voter-address-to-voting-info tree when present.
	//   - bool: true when the proposal has a correctly typed voter-info tree.
	GetProposalVotingInfos(proposalID int64) (*bptree.BPTree, bool)
	// SetProposalVotingInfos stores one proposal's voter-info tree.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the internal store method; callers pass 0.
	//   - rlm: forwarded realm context for the persistent write; the store validates it as current.
	//   - proposalID: proposal identifier used as the root-tree key.
	//   - votingInfos: voter-address-to-voting-info tree to persist.
	//
	// Returns:
	//   - error: nil when persisted; otherwise a spoofed-realm, missing-tree, or key-value store error.
	SetProposalVotingInfos(_ int, rlm realm, proposalID int64, votingInfos *bptree.BPTree) error

	// User proposals methods
	// HasUserProposalsStoreKey reports whether the user-to-proposal index exists.
	//
	// Returns:
	//   - bool: true when user proposal storage is present.
	HasUserProposalsStoreKey() bool
	// GetUserProposals returns the domain-owned user-to-proposal index tree.
	//
	// Returns:
	//   - *bptree.BPTree: tree mapping user strings to proposal-ID slices; storage/type failures panic.
	GetUserProposals() *bptree.BPTree
	// GetUserProposalIDs returns proposal IDs currently indexed for a user.
	//
	// Parameters:
	//   - user: user-string key in the user-to-proposals index.
	//
	// Returns:
	//   - []int64: proposal IDs indexed for user, or nil when absent; wrong stored types panic.
	//   - bool: true when the user has an index entry.
	GetUserProposalIDs(user string) ([]int64, bool)
	// SetUserProposals replaces the persisted user-to-proposal index.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the internal store method; callers pass 0.
	//   - rlm: forwarded realm context for the persistent write; the store validates it as current.
	//   - userProposals: user-to-proposal index tree to persist.
	//
	// Returns:
	//   - error: nil when persisted; otherwise a spoofed-realm or key-value store error.
	SetUserProposals(_ int, rlm realm, userProposals *bptree.BPTree) error
	// AddUserProposal appends a proposal ID to a user's indexed list.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the internal store method; callers pass 0.
	//   - rlm: forwarded realm context for the persistent write; the store validates it as current.
	//   - user: user-string key whose proposal list is updated.
	//   - proposalID: proposal identifier to append.
	//
	// Returns:
	//   - error: nil when persisted; otherwise a spoofed-realm, missing-key, or key-value store error.
	AddUserProposal(_ int, rlm realm, user string, proposalID int64) error
	// RemoveUserProposal removes every occurrence of a proposal ID from a user's list.
	// A missing user entry is treated as an already-complete no-op.
	//
	// Parameters:
	//   - _: leading realm-call discriminator for the internal store method; callers pass 0.
	//   - rlm: forwarded realm context for the persistent write; the store validates it as current.
	//   - user: user-string key whose proposal list is updated.
	//   - proposalID: proposal identifier to remove.
	//
	// Returns:
	//   - error: nil when removed or already absent; otherwise a spoofed-realm, missing-key, or key-value store error.
	RemoveUserProposal(_ int, rlm realm, user string, proposalID int64) error
}

// GovStakerAccessor provides an interface for accessing gov staker functionality.
// This abstraction allows for easier testing by enabling mock implementations.
type GovStakerAccessor interface {
	// GetTotalDelegationAmountAtSnapshot returns the total delegation amount at a specific snapshot time.
	//
	// Parameters:
	//   - snapshotTime: Unix timestamp at which delegation history is sampled.
	//
	// Returns:
	//   - int64: total delegated amount at snapshotTime.
	//   - bool: true when a snapshot value exists at that timestamp.
	GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool)

	// GetUserDelegationAmountAtSnapshot returns a delegatee's delegated amount at a specific snapshot time.
	//
	// Parameters:
	//   - userAddr: delegatee/voting-power holder address whose delegated amount is sampled.
	//   - snapshotTime: Unix timestamp at or before which the delegatee's history is sampled.
	//
	// Returns:
	//   - int64: delegatee's delegated amount at the requested snapshot time.
	//   - bool: true when a qualifying delegatee-history value exists at or before the timestamp.
	GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool)

	// GetTotalxGnsSupply returns the total xGNS supply used as the quorum base.
	//
	// Returns:
	//   - int64: total xGNS supply used as the governance quorum base.
	GetTotalxGnsSupply() int64
}
