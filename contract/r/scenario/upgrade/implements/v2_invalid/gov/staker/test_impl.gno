// Simplified test implementation for gov/staker contract upgrade testing
package v2_invalid

import (
	u256 "gno.land/p/gnoswap/uint256"
	staker "gno.land/r/gnoswap/gov/staker"
	v1 "gno.land/r/gnoswap/gov/staker/v1"
)

func NewV2InvalidGovStaker(store staker.IGovStakerStore) staker.IGovStaker {
	instance := v1.NewGovStakerV1(store)

	return &TestGovStaker{
		instance:      instance,
		activeMethods: make(map[string]bool),
	}
}

func init() {
	staker.RegisterInitializer(cross, func(store staker.IGovStakerStore) staker.IGovStaker {
		return NewV2InvalidGovStaker(store)
	})
}

// TestGovStaker is a minimal test implementation that delegates to v1 only when method is activated
type TestGovStaker struct {
	instance      staker.IGovStaker
	activeMethods map[string]bool
}

func (t *TestGovStaker) SetActiveMethod(fnName string, activated bool) {
	t.activeMethods[fnName] = activated
}

func (t *TestGovStaker) isActive(fnName string) bool {
	active, ok := t.activeMethods[fnName]
	return ok && active
}

// IGovStakerDelegation interface
func (t *TestGovStaker) Delegate(to address, amount int64, referrer string) int64 {
	if !t.isActive("Delegate") {
		panic("test implementation: Delegate not supported")
	}
	return t.instance.Delegate(to, amount, referrer)
}

func (t *TestGovStaker) Undelegate(from address, amount int64) int64 {
	if !t.isActive("Undelegate") {
		panic("test implementation: Undelegate not supported")
	}
	return t.instance.Undelegate(from, amount)
}

func (t *TestGovStaker) Redelegate(delegatee, newDelegatee address, amount int64) int64 {
	if !t.isActive("Redelegate") {
		panic("test implementation: Redelegate not supported")
	}
	return t.instance.Redelegate(delegatee, newDelegatee, amount)
}

func (t *TestGovStaker) CollectUndelegatedGns() int64 {
	if !t.isActive("CollectUndelegatedGns") {
		panic("test implementation: CollectUndelegatedGns not supported")
	}
	return t.instance.CollectUndelegatedGns()
}

// IGovStakerReward interface
func (t *TestGovStaker) CollectReward() {
	if !t.isActive("CollectReward") {
		panic("test implementation: CollectReward not supported")
	}
	t.instance.CollectReward()
}

func (t *TestGovStaker) CollectRewardFromLaunchPad(to address) {
	if !t.isActive("CollectRewardFromLaunchPad") {
		panic("test implementation: CollectRewardFromLaunchPad not supported")
	}
	t.instance.CollectRewardFromLaunchPad(to)
}

func (t *TestGovStaker) SetAmountByProjectWallet(addr address, amount int64, add bool) {
	if !t.isActive("SetAmountByProjectWallet") {
		panic("test implementation: SetAmountByProjectWallet not supported")
	}
	t.instance.SetAmountByProjectWallet(addr, amount, add)
}

// IGovStakerGetter interface
func (t *TestGovStaker) GetUnDelegationLockupPeriod() int64 {
	if !t.isActive("GetUnDelegationLockupPeriod") {
		panic("test implementation: GetUnDelegationLockupPeriod not supported")
	}
	return t.instance.GetUnDelegationLockupPeriod()
}

func (t *TestGovStaker) GetEmissionRewardBalance() int64 {
	if !t.isActive("GetEmissionRewardBalance") {
		panic("test implementation: GetEmissionRewardBalance not supported")
	}
	return t.instance.GetEmissionRewardBalance()
}

func (t *TestGovStaker) GetTotalxGnsSupply() int64 {
	if !t.isActive("GetTotalxGnsSupply") {
		panic("test implementation: GetTotalxGnsSupply not supported")
	}
	return t.instance.GetTotalxGnsSupply()
}

func (t *TestGovStaker) GetTotalVoteWeight() int64 {
	if !t.isActive("GetTotalVoteWeight") {
		panic("test implementation: GetTotalVoteWeight not supported")
	}
	return t.instance.GetTotalVoteWeight()
}

func (t *TestGovStaker) GetTotalDelegated() int64 {
	if !t.isActive("GetTotalDelegated") {
		panic("test implementation: GetTotalDelegated not supported")
	}
	return t.instance.GetTotalDelegated()
}

func (t *TestGovStaker) GetTotalLockedAmount() int64 {
	if !t.isActive("GetTotalLockedAmount") {
		panic("test implementation: GetTotalLockedAmount not supported")
	}
	return t.instance.GetTotalLockedAmount()
}

func (t *TestGovStaker) GetLockedAmount() int64 {
	if !t.isActive("GetLockedAmount") {
		panic("test implementation: GetLockedAmount not supported")
	}
	return t.instance.GetLockedAmount()
}

func (t *TestGovStaker) GetDelegationCount() int {
	if !t.isActive("GetDelegationCount") {
		panic("test implementation: GetDelegationCount not supported")
	}
	return t.instance.GetDelegationCount()
}

func (t *TestGovStaker) GetDelegationIDs(offset, count int) []int64 {
	if !t.isActive("GetDelegationIDs") {
		panic("test implementation: GetDelegationIDs not supported")
	}
	return t.instance.GetDelegationIDs(offset, count)
}

func (t *TestGovStaker) ExistsDelegation(delegationID int64) bool {
	if !t.isActive("ExistsDelegation") {
		panic("test implementation: ExistsDelegation not supported")
	}
	return t.instance.ExistsDelegation(delegationID)
}

func (t *TestGovStaker) GetDelegation(delegationID int64) (*staker.Delegation, error) {
	if !t.isActive("GetDelegation") {
		panic("test implementation: GetDelegation not supported")
	}
	return t.instance.GetDelegation(delegationID)
}

func (t *TestGovStaker) GetDelegatorDelegationCount(delegator address) int {
	if !t.isActive("GetDelegatorDelegationCount") {
		panic("test implementation: GetDelegatorDelegationCount not supported")
	}
	return t.instance.GetDelegatorDelegationCount(delegator)
}

func (t *TestGovStaker) GetDelegatorDelegationIDs(delegator address, offset, count int) []int64 {
	if !t.isActive("GetDelegatorDelegationIDs") {
		panic("test implementation: GetDelegatorDelegationIDs not supported")
	}
	return t.instance.GetDelegatorDelegationIDs(delegator, offset, count)
}

func (t *TestGovStaker) HasDelegationSnapshotsKey() bool {
	if !t.isActive("HasDelegationSnapshotsKey") {
		panic("test implementation: HasDelegationSnapshotsKey not supported")
	}
	return t.instance.HasDelegationSnapshotsKey()
}

func (t *TestGovStaker) GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool) {
	if !t.isActive("GetTotalDelegationAmountAtSnapshot") {
		panic("test implementation: GetTotalDelegationAmountAtSnapshot not supported")
	}
	return t.instance.GetTotalDelegationAmountAtSnapshot(snapshotTime)
}

func (t *TestGovStaker) GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool) {
	if !t.isActive("GetUserDelegationAmountAtSnapshot") {
		panic("test implementation: GetDelegationSnapshots not supported")
	}
	return t.instance.GetUserDelegationAmountAtSnapshot(userAddr, snapshotTime)
}

func (t *TestGovStaker) GetClaimableRewardByAddress(addr address) (int64, map[string]int64, error) {
	if !t.isActive("GetClaimableRewardByAddress") {
		panic("test implementation: GetClaimableRewardByAddress not supported")
	}
	return t.instance.GetClaimableRewardByAddress(addr)
}

func (t *TestGovStaker) GetClaimableRewardByLaunchpad(addr address) (int64, map[string]int64, error) {
	if !t.isActive("GetClaimableRewardByLaunchpad") {
		panic("test implementation: GetClaimableRewardByLaunchpad not supported")
	}
	return t.instance.GetClaimableRewardByLaunchpad(addr)
}

func (t *TestGovStaker) GetClaimableRewardByRewardID(rewardID string) (int64, map[string]int64, error) {
	if !t.isActive("GetClaimableRewardByRewardID") {
		panic("test implementation: GetClaimableRewardByRewardID not supported")
	}
	return t.instance.GetClaimableRewardByRewardID(rewardID)
}

func (t *TestGovStaker) GetLaunchpadProjectDeposit(projectAddr string) (int64, bool) {
	if !t.isActive("GetLaunchpadProjectDeposit") {
		panic("test implementation: GetLaunchpadProjectDeposit not supported")
	}
	return t.instance.GetLaunchpadProjectDeposit(projectAddr)
}

func (t *TestGovStaker) GetDelegationWithdrawCount(delegationID int64) int {
	if !t.isActive("GetDelegationWithdrawCount") {
		panic("test implementation: GetDelegationWithdrawCount not supported")
	}
	return t.instance.GetDelegationWithdrawCount(delegationID)
}

func (t *TestGovStaker) GetDelegationWithdraws(delegationID int64, offset, count int) ([]*staker.DelegationWithdraw, error) {
	if !t.isActive("GetDelegationWithdraws") {
		panic("test implementation: GetDelegationWithdraws not supported")
	}
	return t.instance.GetDelegationWithdraws(delegationID, offset, count)
}

func (t *TestGovStaker) GetCollectableWithdrawAmount(delegationID int64) int64 {
	if !t.isActive("GetCollectableWithdrawAmount") {
		panic("test implementation: GetCollectableWithdrawAmount not supported")
	}
	return t.instance.GetCollectableWithdrawAmount(delegationID)
}

func (t *TestGovStaker) GetProtocolFeeAccumulatedX128PerStake(tokenPath string) *u256.Uint {
	if !t.isActive("GetProtocolFeeAccumulatedX128PerStake") {
		panic("test implementation: GetProtocolFeeAccumulatedX128PerStake not supported")
	}
	return t.instance.GetProtocolFeeAccumulatedX128PerStake(tokenPath)
}

func (t *TestGovStaker) GetProtocolFeeAmount(tokenPath string) int64 {
	if !t.isActive("GetProtocolFeeAmount") {
		panic("test implementation: GetProtocolFeeAmount not supported")
	}
	return t.instance.GetProtocolFeeAmount(tokenPath)
}

func (t *TestGovStaker) GetProtocolFeeAccumulatedTimestamp() int64 {
	if !t.isActive("GetProtocolFeeAccumulatedTimestamp") {
		panic("test implementation: GetProtocolFeeAccumulatedTimestamp not supported")
	}
	return t.instance.GetProtocolFeeAccumulatedTimestamp()
}

func (t *TestGovStaker) GetEmissionAccumulatedX128PerStake() *u256.Uint {
	if !t.isActive("GetEmissionAccumulatedX128PerStake") {
		panic("test implementation: GetEmissionAccumulatedX128PerStake not supported")
	}
	return t.instance.GetEmissionAccumulatedX128PerStake()
}

func (t *TestGovStaker) GetEmissionDistributedAmount() int64 {
	if !t.isActive("GetEmissionDistributedAmount") {
		panic("test implementation: GetEmissionDistributedAmount not supported")
	}
	return t.instance.GetEmissionDistributedAmount()
}

func (t *TestGovStaker) GetEmissionAccumulatedTimestamp() int64 {
	if !t.isActive("GetEmissionAccumulatedTimestamp") {
		panic("test implementation: GetEmissionAccumulatedTimestamp not supported")
	}
	return t.instance.GetEmissionAccumulatedTimestamp()
}

// IGovStakerAdmin interface
func (t *TestGovStaker) CleanStakerDelegationSnapshotByAdmin(threshold int64) {
	if !t.isActive("CleanStakerDelegationSnapshotByAdmin") {
		panic("test implementation: CleanStakerDelegationSnapshotByAdmin not supported")
	}
	t.instance.CleanStakerDelegationSnapshotByAdmin(threshold)
}

func (t *TestGovStaker) SetUnDelegationLockupPeriodByAdmin(period int64) {
	if !t.isActive("SetUnDelegationLockupPeriodByAdmin") {
		panic("test implementation: SetUnDelegationLockupPeriodByAdmin not supported")
	}
	t.instance.SetUnDelegationLockupPeriodByAdmin(period)
}
