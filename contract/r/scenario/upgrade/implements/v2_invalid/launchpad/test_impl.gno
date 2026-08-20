// Simplified test implementation for launchpad contract upgrade testing.
//
// Every method panics unless it has been explicitly activated, which is what
// the upgrade filetests use to prove that switching the implementation really
// does route traffic to the new version.
package v2_invalid

import (
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/launchpad"
	v1 "gno.land/r/gnoswap/launchpad/v1"
)

func NewV2InvalidLaunchpad(store launchpad.ILaunchpadStore) launchpad.ILaunchpad {
	return &TestLaunchpad{
		instance:      v1.NewLaunchpadV1(store),
		activeMethods: make(map[string]bool),
	}
}

func init(cur realm) {
	launchpad.RegisterInitializer(cross(cur), func(_ int, rlm realm, store launchpad.ILaunchpadStore) launchpad.ILaunchpad {
		return NewV2InvalidLaunchpad(store)
	})
}

// TestLaunchpad delegates to v1 only when the method has been activated.
type TestLaunchpad struct {
	instance      launchpad.ILaunchpad
	activeMethods map[string]bool
}

func (t *TestLaunchpad) SetActiveMethod(fnName string, activated bool) {
	t.activeMethods[fnName] = activated
}

func (t *TestLaunchpad) isActive(fnName string) bool {
	active, ok := t.activeMethods[fnName]
	return ok && active
}

// ILaunchpadProject interface
func (t *TestLaunchpad) CreateProject(_ int, rlm realm, name string, tokenPath string, recipient address, depositAmount int64, conditionTokens string, conditionAmounts string, tier30Ratio int64, tier90Ratio int64, tier180Ratio int64, startTime int64) string {
	if !t.isActive("CreateProject") {
		panic("test implementation: CreateProject not supported")
	}
	return t.instance.CreateProject(0, rlm, name, tokenPath, recipient, depositAmount, conditionTokens, conditionAmounts, tier30Ratio, tier90Ratio, tier180Ratio, startTime)
}

func (t *TestLaunchpad) TransferLeftFromProjectByAdmin(_ int, rlm realm, projectID string, recipient address) int64 {
	if !t.isActive("TransferLeftFromProjectByAdmin") {
		panic("test implementation: TransferLeftFromProjectByAdmin not supported")
	}
	return t.instance.TransferLeftFromProjectByAdmin(0, rlm, projectID, recipient)
}

func (t *TestLaunchpad) CollectProtocolFee(_ int, rlm realm) {
	if !t.isActive("CollectProtocolFee") {
		panic("test implementation: CollectProtocolFee not supported")
	}
	t.instance.CollectProtocolFee(0, rlm)
}

func (t *TestLaunchpad) CollectEmissionReward(_ int, rlm realm) {
	if !t.isActive("CollectEmissionReward") {
		panic("test implementation: CollectEmissionReward not supported")
	}
	t.instance.CollectEmissionReward(0, rlm)
}

func (t *TestLaunchpad) CollectProtocolFeeReward(_ int, rlm realm, tokenPath string) {
	if !t.isActive("CollectProtocolFeeReward") {
		panic("test implementation: CollectProtocolFeeReward not supported")
	}
	t.instance.CollectProtocolFeeReward(0, rlm, tokenPath)
}

// ILaunchpadDeposit interface
func (t *TestLaunchpad) DepositGns(_ int, rlm realm, targetProjectTierID string, depositAmount int64, referrer string) string {
	if !t.isActive("DepositGns") {
		panic("test implementation: DepositGns not supported")
	}
	return t.instance.DepositGns(0, rlm, targetProjectTierID, depositAmount, referrer)
}

func (t *TestLaunchpad) CollectDepositGns(_ int, rlm realm, depositID string) (int64, error) {
	if !t.isActive("CollectDepositGns") {
		panic("test implementation: CollectDepositGns not supported")
	}
	return t.instance.CollectDepositGns(0, rlm, depositID)
}

func (t *TestLaunchpad) CollectRewardByDepositId(_ int, rlm realm, depositID string) int64 {
	if !t.isActive("CollectRewardByDepositId") {
		panic("test implementation: CollectRewardByDepositId not supported")
	}
	return t.instance.CollectRewardByDepositId(0, rlm, depositID)
}

// ILaunchpadGetter interface
func (t *TestLaunchpad) GetProjectCount() int {
	if !t.isActive("GetProjectCount") {
		panic("test implementation: GetProjectCount not supported")
	}
	return t.instance.GetProjectCount()
}

func (t *TestLaunchpad) GetProjectIDs(offset, count int) []string {
	if !t.isActive("GetProjectIDs") {
		panic("test implementation: GetProjectIDs not supported")
	}
	return t.instance.GetProjectIDs(offset, count)
}

func (t *TestLaunchpad) GetProject(projectId string) (*launchpad.Project, error) {
	if !t.isActive("GetProject") {
		panic("test implementation: GetProject not supported")
	}
	return t.instance.GetProject(projectId)
}

func (t *TestLaunchpad) GetProjectName(projectId string) (string, error) {
	if !t.isActive("GetProjectName") {
		panic("test implementation: GetProjectName not supported")
	}
	return t.instance.GetProjectName(projectId)
}

func (t *TestLaunchpad) GetProjectTokenPath(projectId string) (string, error) {
	if !t.isActive("GetProjectTokenPath") {
		panic("test implementation: GetProjectTokenPath not supported")
	}
	return t.instance.GetProjectTokenPath(projectId)
}

func (t *TestLaunchpad) GetProjectDepositAmount(projectId string) (int64, error) {
	if !t.isActive("GetProjectDepositAmount") {
		panic("test implementation: GetProjectDepositAmount not supported")
	}
	return t.instance.GetProjectDepositAmount(projectId)
}

func (t *TestLaunchpad) GetProjectRecipient(projectId string) (address, error) {
	if !t.isActive("GetProjectRecipient") {
		panic("test implementation: GetProjectRecipient not supported")
	}
	return t.instance.GetProjectRecipient(projectId)
}

func (t *TestLaunchpad) GetProjectCondition(projectId string, tokenPath string) (*launchpad.ProjectCondition, error) {
	if !t.isActive("GetProjectCondition") {
		panic("test implementation: GetProjectCondition not supported")
	}
	return t.instance.GetProjectCondition(projectId, tokenPath)
}

func (t *TestLaunchpad) GetProjectTiersRatios(projectId string) (map[int64]int64, error) {
	if !t.isActive("GetProjectTiersRatios") {
		panic("test implementation: GetProjectTiersRatios not supported")
	}
	return t.instance.GetProjectTiersRatios(projectId)
}

func (t *TestLaunchpad) GetProjectCreatedHeight(projectId string) (int64, error) {
	if !t.isActive("GetProjectCreatedHeight") {
		panic("test implementation: GetProjectCreatedHeight not supported")
	}
	return t.instance.GetProjectCreatedHeight(projectId)
}

func (t *TestLaunchpad) GetProjectCreatedAt(projectId string) (int64, error) {
	if !t.isActive("GetProjectCreatedAt") {
		panic("test implementation: GetProjectCreatedAt not supported")
	}
	return t.instance.GetProjectCreatedAt(projectId)
}

func (t *TestLaunchpad) GetProjectTier(projectId string, tier int64) (*launchpad.ProjectTier, error) {
	if !t.isActive("GetProjectTier") {
		panic("test implementation: GetProjectTier not supported")
	}
	return t.instance.GetProjectTier(projectId, tier)
}

func (t *TestLaunchpad) GetProjectTierDistributeAmountPerSecondX128(projectId string, tier int64) (*u256.Uint, error) {
	if !t.isActive("GetProjectTierDistributeAmountPerSecondX128") {
		panic("test implementation: GetProjectTierDistributeAmountPerSecondX128 not supported")
	}
	return t.instance.GetProjectTierDistributeAmountPerSecondX128(projectId, tier)
}

func (t *TestLaunchpad) GetProjectTierTotalDistributeAmount(projectId string, tier int64) (int64, error) {
	if !t.isActive("GetProjectTierTotalDistributeAmount") {
		panic("test implementation: GetProjectTierTotalDistributeAmount not supported")
	}
	return t.instance.GetProjectTierTotalDistributeAmount(projectId, tier)
}

func (t *TestLaunchpad) GetProjectTierTotalDepositAmount(projectId string, tier int64) (int64, error) {
	if !t.isActive("GetProjectTierTotalDepositAmount") {
		panic("test implementation: GetProjectTierTotalDepositAmount not supported")
	}
	return t.instance.GetProjectTierTotalDepositAmount(projectId, tier)
}

func (t *TestLaunchpad) GetProjectTierTotalWithdrawAmount(projectId string, tier int64) (int64, error) {
	if !t.isActive("GetProjectTierTotalWithdrawAmount") {
		panic("test implementation: GetProjectTierTotalWithdrawAmount not supported")
	}
	return t.instance.GetProjectTierTotalWithdrawAmount(projectId, tier)
}

func (t *TestLaunchpad) GetProjectTierTotalDepositCount(projectId string, tier int64) (int64, error) {
	if !t.isActive("GetProjectTierTotalDepositCount") {
		panic("test implementation: GetProjectTierTotalDepositCount not supported")
	}
	return t.instance.GetProjectTierTotalDepositCount(projectId, tier)
}

func (t *TestLaunchpad) GetProjectTierTotalWithdrawCount(projectId string, tier int64) (int64, error) {
	if !t.isActive("GetProjectTierTotalWithdrawCount") {
		panic("test implementation: GetProjectTierTotalWithdrawCount not supported")
	}
	return t.instance.GetProjectTierTotalWithdrawCount(projectId, tier)
}

func (t *TestLaunchpad) GetProjectTierTotalCollectedAmount(projectId string, tier int64) (int64, error) {
	if !t.isActive("GetProjectTierTotalCollectedAmount") {
		panic("test implementation: GetProjectTierTotalCollectedAmount not supported")
	}
	return t.instance.GetProjectTierTotalCollectedAmount(projectId, tier)
}

func (t *TestLaunchpad) GetProjectTierStartTime(projectId string, tier int64) (int64, error) {
	if !t.isActive("GetProjectTierStartTime") {
		panic("test implementation: GetProjectTierStartTime not supported")
	}
	return t.instance.GetProjectTierStartTime(projectId, tier)
}

func (t *TestLaunchpad) GetProjectTierEndTime(projectId string, tier int64) (int64, error) {
	if !t.isActive("GetProjectTierEndTime") {
		panic("test implementation: GetProjectTierEndTime not supported")
	}
	return t.instance.GetProjectTierEndTime(projectId, tier)
}

func (t *TestLaunchpad) GetDepositCount() int {
	if !t.isActive("GetDepositCount") {
		panic("test implementation: GetDepositCount not supported")
	}
	return t.instance.GetDepositCount()
}

func (t *TestLaunchpad) GetCurrentDepositId() int64 {
	if !t.isActive("GetCurrentDepositId") {
		panic("test implementation: GetCurrentDepositId not supported")
	}
	return t.instance.GetCurrentDepositId()
}

func (t *TestLaunchpad) GetProjectTierDepositCount(projectId string, tier int64) int {
	if !t.isActive("GetProjectTierDepositCount") {
		panic("test implementation: GetProjectTierDepositCount not supported")
	}
	return t.instance.GetProjectTierDepositCount(projectId, tier)
}

func (t *TestLaunchpad) GetProjectTierDepositIDs(projectId string, tier int64, offset, count int) []string {
	if !t.isActive("GetProjectTierDepositIDs") {
		panic("test implementation: GetProjectTierDepositIDs not supported")
	}
	return t.instance.GetProjectTierDepositIDs(projectId, tier, offset, count)
}

func (t *TestLaunchpad) GetDeposit(depositId string) (*launchpad.Deposit, error) {
	if !t.isActive("GetDeposit") {
		panic("test implementation: GetDeposit not supported")
	}
	return t.instance.GetDeposit(depositId)
}

func (t *TestLaunchpad) GetDepositProjectID(depositId string) (string, error) {
	if !t.isActive("GetDepositProjectID") {
		panic("test implementation: GetDepositProjectID not supported")
	}
	return t.instance.GetDepositProjectID(depositId)
}

func (t *TestLaunchpad) GetDepositTier(depositId string) (int64, error) {
	if !t.isActive("GetDepositTier") {
		panic("test implementation: GetDepositTier not supported")
	}
	return t.instance.GetDepositTier(depositId)
}

func (t *TestLaunchpad) GetDepositProjectTierID(depositId string) (string, error) {
	if !t.isActive("GetDepositProjectTierID") {
		panic("test implementation: GetDepositProjectTierID not supported")
	}
	return t.instance.GetDepositProjectTierID(depositId)
}

func (t *TestLaunchpad) GetDepositAmount(depositId string) (int64, error) {
	if !t.isActive("GetDepositAmount") {
		panic("test implementation: GetDepositAmount not supported")
	}
	return t.instance.GetDepositAmount(depositId)
}

func (t *TestLaunchpad) GetDepositWithdrawnHeight(depositId string) (int64, error) {
	if !t.isActive("GetDepositWithdrawnHeight") {
		panic("test implementation: GetDepositWithdrawnHeight not supported")
	}
	return t.instance.GetDepositWithdrawnHeight(depositId)
}

func (t *TestLaunchpad) GetDepositWithdrawnTime(depositId string) (int64, error) {
	if !t.isActive("GetDepositWithdrawnTime") {
		panic("test implementation: GetDepositWithdrawnTime not supported")
	}
	return t.instance.GetDepositWithdrawnTime(depositId)
}

func (t *TestLaunchpad) GetDepositCreatedHeight(depositId string) (int64, error) {
	if !t.isActive("GetDepositCreatedHeight") {
		panic("test implementation: GetDepositCreatedHeight not supported")
	}
	return t.instance.GetDepositCreatedHeight(depositId)
}

func (t *TestLaunchpad) GetDepositCreatedAt(depositId string) (int64, error) {
	if !t.isActive("GetDepositCreatedAt") {
		panic("test implementation: GetDepositCreatedAt not supported")
	}
	return t.instance.GetDepositCreatedAt(depositId)
}

func (t *TestLaunchpad) GetDepositEndTime(depositId string) (int64, error) {
	if !t.isActive("GetDepositEndTime") {
		panic("test implementation: GetDepositEndTime not supported")
	}
	return t.instance.GetDepositEndTime(depositId)
}

func (t *TestLaunchpad) GetTotalGNSStakedAmount() int64 {
	if !t.isActive("GetTotalGNSStakedAmount") {
		panic("test implementation: GetTotalGNSStakedAmount not supported")
	}
	return t.instance.GetTotalGNSStakedAmount()
}

func (t *TestLaunchpad) GetProjectTierRewardManagerCount() int {
	if !t.isActive("GetProjectTierRewardManagerCount") {
		panic("test implementation: GetProjectTierRewardManagerCount not supported")
	}
	return t.instance.GetProjectTierRewardManagerCount()
}

func (t *TestLaunchpad) GetProjectTierRewardManager(projectTierId string) (*launchpad.RewardManager, error) {
	if !t.isActive("GetProjectTierRewardManager") {
		panic("test implementation: GetProjectTierRewardManager not supported")
	}
	return t.instance.GetProjectTierRewardManager(projectTierId)
}

func (t *TestLaunchpad) GetProjectTierRewardDistributeAmountPerSecondX128(projectTierId string) (*u256.Uint, error) {
	if !t.isActive("GetProjectTierRewardDistributeAmountPerSecondX128") {
		panic("test implementation: GetProjectTierRewardDistributeAmountPerSecondX128 not supported")
	}
	return t.instance.GetProjectTierRewardDistributeAmountPerSecondX128(projectTierId)
}

func (t *TestLaunchpad) GetProjectTierRewardAccumulatedRewardPerDepositX128(projectTierId string) (*u256.Uint, error) {
	if !t.isActive("GetProjectTierRewardAccumulatedRewardPerDepositX128") {
		panic("test implementation: GetProjectTierRewardAccumulatedRewardPerDepositX128 not supported")
	}
	return t.instance.GetProjectTierRewardAccumulatedRewardPerDepositX128(projectTierId)
}

func (t *TestLaunchpad) GetProjectTierRewardTotalDistributeAmount(projectTierId string) (int64, error) {
	if !t.isActive("GetProjectTierRewardTotalDistributeAmount") {
		panic("test implementation: GetProjectTierRewardTotalDistributeAmount not supported")
	}
	return t.instance.GetProjectTierRewardTotalDistributeAmount(projectTierId)
}

func (t *TestLaunchpad) GetProjectTierRewardTotalClaimedAmount(projectTierId string) (int64, error) {
	if !t.isActive("GetProjectTierRewardTotalClaimedAmount") {
		panic("test implementation: GetProjectTierRewardTotalClaimedAmount not supported")
	}
	return t.instance.GetProjectTierRewardTotalClaimedAmount(projectTierId)
}

func (t *TestLaunchpad) GetProjectTierRewardDistributeStartTime(projectTierId string) (int64, error) {
	if !t.isActive("GetProjectTierRewardDistributeStartTime") {
		panic("test implementation: GetProjectTierRewardDistributeStartTime not supported")
	}
	return t.instance.GetProjectTierRewardDistributeStartTime(projectTierId)
}

func (t *TestLaunchpad) GetProjectTierRewardDistributeEndTime(projectTierId string) (int64, error) {
	if !t.isActive("GetProjectTierRewardDistributeEndTime") {
		panic("test implementation: GetProjectTierRewardDistributeEndTime not supported")
	}
	return t.instance.GetProjectTierRewardDistributeEndTime(projectTierId)
}

func (t *TestLaunchpad) GetProjectTierRewardAccumulatedDistributeAmount(projectTierId string) (int64, error) {
	if !t.isActive("GetProjectTierRewardAccumulatedDistributeAmount") {
		panic("test implementation: GetProjectTierRewardAccumulatedDistributeAmount not supported")
	}
	return t.instance.GetProjectTierRewardAccumulatedDistributeAmount(projectTierId)
}

func (t *TestLaunchpad) GetProjectTierRewardAccumulatedTime(projectTierId string) (int64, error) {
	if !t.isActive("GetProjectTierRewardAccumulatedTime") {
		panic("test implementation: GetProjectTierRewardAccumulatedTime not supported")
	}
	return t.instance.GetProjectTierRewardAccumulatedTime(projectTierId)
}

func (t *TestLaunchpad) GetProjectTierRewardClaimableDuration(projectTierId string) (int64, error) {
	if !t.isActive("GetProjectTierRewardClaimableDuration") {
		panic("test implementation: GetProjectTierRewardClaimableDuration not supported")
	}
	return t.instance.GetProjectTierRewardClaimableDuration(projectTierId)
}

func (t *TestLaunchpad) GetRewardState(projectTierId string, depositId string) (*launchpad.RewardState, error) {
	if !t.isActive("GetRewardState") {
		panic("test implementation: GetRewardState not supported")
	}
	return t.instance.GetRewardState(projectTierId, depositId)
}

func (t *TestLaunchpad) GetProjectActiveStatus(projectId string) (bool, error) {
	if !t.isActive("GetProjectActiveStatus") {
		panic("test implementation: GetProjectActiveStatus not supported")
	}
	return t.instance.GetProjectActiveStatus(projectId)
}
