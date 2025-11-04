// Simplified test implementation for gov/staker contract upgrade testing
package v2_invalid

import (
	"gno.land/r/gnoswap/gov/staker"
)

func init() {
	staker.RegisterInitializer(cross, func(store staker.IGovStakerStore) staker.IGovStaker {
		return &TestGovStaker{}
	})
}

// TestGovStaker is a minimal test implementation that panics on all methods
type TestGovStaker struct{}

// IGovStakerDelegation interface
func (t *TestGovStaker) Delegate(to address, amount int64, referrer string) int64 {
	panic("test implementation: Delegate not supported")
}

func (t *TestGovStaker) Undelegate(from address, amount int64) int64 {
	panic("test implementation: Undelegate not supported")
}

func (t *TestGovStaker) Redelegate(delegatee, newDelegatee address, amount int64) int64 {
	panic("test implementation: Redelegate not supported")
}

func (t *TestGovStaker) CollectUndelegatedGns() int64 {
	panic("test implementation: CollectUndelegatedGns not supported")
}

// IGovStakerReward interface
func (t *TestGovStaker) CollectReward() {
	panic("test implementation: CollectReward not supported")
}

func (t *TestGovStaker) CollectRewardFromLaunchPad(to address) {
	panic("test implementation: CollectRewardFromLaunchPad not supported")
}

func (t *TestGovStaker) SetAmountByProjectWallet(addr address, amount int64, add bool) {
	panic("test implementation: SetAmountByProjectWallet not supported")
}

// IGovStakerGetter interface
func (t *TestGovStaker) GetTotalxGnsSupply() int64 {
	panic("test implementation: GetTotalxGnsSupply not supported")
}

func (t *TestGovStaker) GetTotalVoteWeight() int64 {
	panic("test implementation: GetTotalVoteWeight not supported")
}

func (t *TestGovStaker) GetTotalDelegated() int64 {
	panic("test implementation: GetTotalDelegated not supported")
}

func (t *TestGovStaker) GetTotalLockedAmount() int64 {
	panic("test implementation: GetTotalLockedAmount not supported")
}

func (t *TestGovStaker) GetLockedAmount() int64 {
	panic("test implementation: GetLockedAmount not supported")
}

func (t *TestGovStaker) GetDelegationSnapshots(snapshotTime int64) (staker.DelegationSnapshot, bool) {
	panic("test implementation: GetDelegationSnapshots not supported")
}

func (t *TestGovStaker) GetClaimableRewardByAddress(addr address) string {
	panic("test implementation: GetClaimableRewardByAddress not supported")
}

func (t *TestGovStaker) GetClaimableRewardByLaunchpad(addr address) string {
	panic("test implementation: GetClaimableRewardByLaunchpad not supported")
}

func (t *TestGovStaker) GetClaimableRewardByRewardID(rewardID string) string {
	panic("test implementation: GetClaimableRewardByRewardID not supported")
}

// IGovStakerAdmin interface
func (t *TestGovStaker) CleanStakerDelegationSnapshotByAdmin(threshold int64) {
	panic("test implementation: CleanStakerDelegationSnapshotByAdmin not supported")
}

func (t *TestGovStaker) SetUnDelegationLockupPeriodByAdmin(period int64) {
	panic("test implementation: SetUnDelegationLockupPeriodByAdmin not supported")
}
