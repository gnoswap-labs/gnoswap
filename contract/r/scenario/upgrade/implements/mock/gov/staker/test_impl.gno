// Simplified test implementation for gov/staker contract upgrade testing
package mock

import (
	"gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/gov/staker/v1"
)

func NewV3ValidGovStaker(store staker.IGovStakerStore) staker.IGovStaker {
	instance := v1.NewGovStakerV1(store)

	return &TestGovStaker{
		instance: instance,
		mockFns:  make(map[string]func(args ...any) any),
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
	mockFns  map[string]func(args ...any) any
}

func (t *TestGovStaker) SetMockFn(fnName string, fn func(args ...any) any) {
	t.mockFns[fnName] = fn
}

func (t *TestGovStaker) ExecuteFn(fnName string, actualFn func(args ...any) any, args ...any) any {
	fn, ok := t.mockFns[fnName]
	if !ok {
		return actualFn(args...)
	}

	return fn(args...)
}

// IGovStakerDelegation interface
func (t *TestGovStaker) Delegate(to address, amount int64, referrer string) int64 {
	return t.ExecuteFn(
		"Delegate",
		func(args ...any) any {
			return t.instance.Delegate(args[0].(address), args[1].(int64), args[2].(string))
		},
		to, amount, referrer,
	).(int64)
}

func (t *TestGovStaker) Undelegate(from address, amount int64) int64 {
	return t.ExecuteFn(
		"Undelegate",
		func(args ...any) any { return t.instance.Undelegate(args[0].(address), args[1].(int64)) },
		from, amount,
	).(int64)
}

func (t *TestGovStaker) Redelegate(delegatee, newDelegatee address, amount int64) int64 {
	return t.ExecuteFn(
		"Redelegate",
		func(args ...any) any {
			return t.instance.Redelegate(args[0].(address), args[1].(address), args[2].(int64))
		},
		delegatee, newDelegatee, amount,
	).(int64)
}

func (t *TestGovStaker) CollectUndelegatedGns() int64 {
	return t.ExecuteFn(
		"CollectUndelegatedGns",
		func(args ...any) any { return t.instance.CollectUndelegatedGns() },
	).(int64)
}

// IGovStakerReward interface
func (t *TestGovStaker) CollectReward() {
	t.ExecuteFn(
		"CollectReward",
		func(args ...any) any { t.instance.CollectReward(); return nil },
	)
}

func (t *TestGovStaker) CollectRewardFromLaunchPad(to address) {
	t.ExecuteFn(
		"CollectRewardFromLaunchPad",
		func(args ...any) any { t.instance.CollectRewardFromLaunchPad(args[0].(address)); return nil },
		to,
	)
}

func (t *TestGovStaker) SetAmountByProjectWallet(addr address, amount int64, add bool) {
	t.ExecuteFn(
		"SetAmountByProjectWallet",
		func(args ...any) any {
			t.instance.SetAmountByProjectWallet(args[0].(address), args[1].(int64), args[2].(bool))
			return nil
		},
		addr, amount, add,
	)
}

// IGovStakerGetter interface
func (t *TestGovStaker) GetTotalxGnsSupply() int64 {
	return t.ExecuteFn(
		"GetTotalxGnsSupply",
		func(args ...any) any { return t.instance.GetTotalxGnsSupply() },
	).(int64)
}

func (t *TestGovStaker) GetTotalDelegated() int64 {
	return t.ExecuteFn(
		"GetTotalDelegated",
		func(args ...any) any { return t.instance.GetTotalDelegated() },
	).(int64)
}

func (t *TestGovStaker) GetTotalLockedAmount() int64 {
	return t.ExecuteFn(
		"GetTotalLockedAmount",
		func(args ...any) any { return t.instance.GetTotalLockedAmount() },
	).(int64)
}

func (t *TestGovStaker) GetLockedAmount() int64 {
	return t.ExecuteFn(
		"GetLockedAmount",
		func(args ...any) any { return t.instance.GetLockedAmount() },
	).(int64)
}

func (t *TestGovStaker) GetDelegationSnapshots(snapshotTime int64) (staker.DelegationSnapshot, bool) {
	result := t.ExecuteFn(
		"GetDelegationSnapshots",
		func(args ...any) any {
			snap, ok := t.instance.GetDelegationSnapshots(args[0].(int64))
			return []any{snap, ok}
		},
		snapshotTime,
	).([]any)
	return result[0].(staker.DelegationSnapshot), result[1].(bool)
}

func (t *TestGovStaker) GetClaimableRewardByAddress(addr address) (int64, map[string]int64, error) {
	result := t.ExecuteFn(
		"GetClaimableRewardByAddress",
		func(args ...any) any {
			emission, fees, err := t.instance.GetClaimableRewardByAddress(args[0].(address))
			return []any{emission, fees, err}
		},
		addr,
	).([]any)
	if result[2] != nil {
		return result[0].(int64), result[1].(map[string]int64), result[2].(error)
	}
	return result[0].(int64), result[1].(map[string]int64), nil
}

func (t *TestGovStaker) GetClaimableRewardByLaunchpad(addr address) (int64, map[string]int64, error) {
	result := t.ExecuteFn(
		"GetClaimableRewardByLaunchpad",
		func(args ...any) any {
			emission, fees, err := t.instance.GetClaimableRewardByLaunchpad(args[0].(address))
			return []any{emission, fees, err}
		},
		addr,
	).([]any)
	if result[2] != nil {
		return result[0].(int64), result[1].(map[string]int64), result[2].(error)
	}
	return result[0].(int64), result[1].(map[string]int64), nil
}

func (t *TestGovStaker) GetClaimableRewardByRewardID(rewardID string) (int64, map[string]int64, error) {
	result := t.ExecuteFn(
		"GetClaimableRewardByRewardID",
		func(args ...any) any {
			emission, fees, err := t.instance.GetClaimableRewardByRewardID(args[0].(string))
			return []any{emission, fees, err}
		},
		rewardID,
	).([]any)
	if result[2] != nil {
		return result[0].(int64), result[1].(map[string]int64), result[2].(error)
	}
	return result[0].(int64), result[1].(map[string]int64), nil
}

// IGovStakerAdmin interface
func (t *TestGovStaker) CleanStakerDelegationSnapshotByAdmin(threshold int64) {
	t.ExecuteFn(
		"CleanStakerDelegationSnapshotByAdmin",
		func(args ...any) any { t.instance.CleanStakerDelegationSnapshotByAdmin(args[0].(int64)); return nil },
		threshold,
	)
}

func (t *TestGovStaker) SetUnDelegationLockupPeriodByAdmin(period int64) {
	t.ExecuteFn(
		"SetUnDelegationLockupPeriodByAdmin",
		func(args ...any) any { t.instance.SetUnDelegationLockupPeriodByAdmin(args[0].(int64)); return nil },
		period,
	)
}
