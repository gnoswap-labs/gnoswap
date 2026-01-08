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

// GetProjectCount returns the total number of projects.
func GetProjectCount() int64 {
	return getImplementation().GetProjectCount()
}

// GetDepositCount returns the total number of deposits.
func GetDepositCount() int64 {
	return getImplementation().GetDepositCount()
}

// GetRewardManagerCount returns the total number of reward managers.
func GetRewardManagerCount() int64 {
	return getImplementation().GetRewardManagerCount()
}

// GetCurrentDepositId returns the current deposit counter value.
func GetCurrentDepositId() int64 {
	return getImplementation().GetCurrentDepositId()
}

// GetProject retrieves a project by its ID.
// Returns a cloned project to prevent external modification.
func GetProject(projectId string) (*Project, error) {
	return getImplementation().GetProject(projectId)
}

// GetDeposit retrieves a deposit by its ID.
// Returns a cloned deposit to prevent external modification.
func GetDeposit(depositId string) (*Deposit, error) {
	return getImplementation().GetDeposit(depositId)
}

// GetProjectTier retrieves a specific tier of a project.
// Returns a cloned tier to prevent external modification.
func GetProjectTier(projectId string, tier int64) (*ProjectTier, error) {
	return getImplementation().GetProjectTier(projectId, tier)
}

// GetProjectCondition retrieves a specific condition of a project.
// Returns a cloned condition to prevent external modification.
func GetProjectCondition(projectId string, tokenPath string) (*ProjectCondition, error) {
	return getImplementation().GetProjectCondition(projectId, tokenPath)
}

// GetRewardManager retrieves a reward manager by project tier ID.
// Returns a cloned reward manager to prevent external modification.
func GetRewardManager(projectTierId string) (*RewardManager, error) {
	return getImplementation().GetRewardManager(projectTierId)
}

// GetRewardState retrieves a reward state by project tier ID and deposit ID.
// Returns a cloned reward state to prevent external modification.
func GetRewardState(projectTierId string, depositId string) (*RewardState, error) {
	return getImplementation().GetRewardState(projectTierId, depositId)
}

// GetClaimableRewardByProjectId returns the claimable reward for a project's recipient.
func GetClaimableRewardByProjectId(projectId string) (string, error) {
	return getImplementation().GetClaimableRewardByProjectId(projectId)
}

// GetClaimableRewardByAddress returns the claimable reward for a specific address.
func GetClaimableRewardByAddress(addr address) string {
	return getImplementation().GetClaimableRewardByAddress(addr)
}

// GetProjectActiveStatus returns whether a project is currently active.
func GetProjectActiveStatus(projectId string) (bool, error) {
	return getImplementation().GetProjectActiveStatus(projectId)
}

// GetProjects returns a paginated list of project IDs.
func GetProjects(offset, limit int64) []string {
	return getImplementation().GetProjects(offset, limit)
}

// GetDeposits returns a paginated list of deposit IDs.
func GetDeposits(offset, limit int64) []string {
	return getImplementation().GetDeposits(offset, limit)
}

// GetRewardManagers returns a paginated list of project tier IDs (reward manager keys).
func GetRewardManagers(offset, limit int64) []string {
	return getImplementation().GetRewardManagers(offset, limit)
}
