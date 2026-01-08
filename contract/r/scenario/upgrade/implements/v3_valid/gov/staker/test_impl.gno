// Simplified test implementation for gov/staker contract upgrade testing
package v3_valid

import (
	"gno.land/r/gnoswap/gov/staker"
	v1 "gno.land/r/gnoswap/gov/staker/v1"
)

func NewV3ValidGovStaker(store staker.IGovStakerStore) staker.IGovStaker {
	return &TestGovStaker{
		instance: v1.NewGovStakerV1(store),
	}
}

func init() {
	staker.RegisterInitializer(cross, func(store staker.IGovStakerStore) staker.IGovStaker {
		return NewV3ValidGovStaker(store)
	})
}

// TestGovStaker is a minimal test implementation that delegates to v1
type TestGovStaker struct {
	instance staker.IGovStaker
}

// IGovStakerDelegation interface
func (t *TestGovStaker) Delegate(to address, amount int64, referrer string) int64 {
	return t.instance.Delegate(to, amount, referrer)
}

func (t *TestGovStaker) Undelegate(from address, amount int64) int64 {
	return t.instance.Undelegate(from, amount)
}

func (t *TestGovStaker) Redelegate(delegatee, newDelegatee address, amount int64) int64 {
	return t.instance.Redelegate(delegatee, newDelegatee, amount)
}

func (t *TestGovStaker) CollectUndelegatedGns() int64 {
	return t.instance.CollectUndelegatedGns()
}

// IGovStakerReward interface
func (t *TestGovStaker) CollectReward() {
	t.instance.CollectReward()
}

func (t *TestGovStaker) CollectRewardFromLaunchPad(to address) {
	t.instance.CollectRewardFromLaunchPad(to)
}

func (t *TestGovStaker) SetAmountByProjectWallet(addr address, amount int64, add bool) {
	t.instance.SetAmountByProjectWallet(addr, amount, add)
}

// IGovStakerGetter interface
func (t *TestGovStaker) GetTotalxGnsSupply() int64 {
	return t.instance.GetTotalxGnsSupply()
}

func (t *TestGovStaker) GetTotalVoteWeight() int64 {
	return t.instance.GetTotalVoteWeight()
}

func (t *TestGovStaker) GetTotalDelegated() int64 {
	return t.instance.GetTotalDelegated()
}

func (t *TestGovStaker) GetTotalLockedAmount() int64 {
	return t.instance.GetTotalLockedAmount()
}

func (t *TestGovStaker) GetLockedAmount() int64 {
	return t.instance.GetLockedAmount()
}

func (t *TestGovStaker) GetTotalDelegationAmountAtSnapshot(snapshotTime int64) (int64, bool) {
	return t.instance.GetTotalDelegationAmountAtSnapshot(snapshotTime)
}

func (t *TestGovStaker) GetUserDelegationAmountAtSnapshot(userAddr address, snapshotTime int64) (int64, bool) {
	return t.instance.GetUserDelegationAmountAtSnapshot(userAddr, snapshotTime)
}

func (t *TestGovStaker) GetClaimableRewardByAddress(addr address) (int64, map[string]int64) {
	return t.instance.GetClaimableRewardByAddress(addr)
}

func (t *TestGovStaker) GetClaimableRewardByLaunchpad(addr address) (int64, map[string]int64) {
	return t.instance.GetClaimableRewardByLaunchpad(addr)
}

func (t *TestGovStaker) GetClaimableRewardByRewardID(rewardID string) (int64, map[string]int64) {
	return t.instance.GetClaimableRewardByRewardID(rewardID)
}

// IGovStakerAdmin interface
func (t *TestGovStaker) CleanStakerDelegationSnapshotByAdmin(threshold int64) {
	t.instance.CleanStakerDelegationSnapshotByAdmin(threshold)
}

func (t *TestGovStaker) SetUnDelegationLockupPeriodByAdmin(period int64) {
	t.instance.SetUnDelegationLockupPeriodByAdmin(period)
}
