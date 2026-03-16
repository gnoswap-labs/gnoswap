package staker

import (
	"math"

	u256 "gno.land/p/gnoswap/uint256"
	avl "gno.land/p/nt/avl/v0"
)

// ExternalIncentiveState holds the collected reward and last collect time
// for a single external incentive within a deposit.
type ExternalIncentiveState struct {
	CollectedReward int64
	LastCollectTime int64
}

type Deposit struct {
	warmups                        []Warmup   // warmup information
	liquidity                      *u256.Uint // liquidity
	targetPoolPath                 string     // staked position's pool path
	owner                          address    // owner address
	stakeTime                      int64      // staked time
	internalRewardLastCollectTime  int64      // last collect time for internal reward
	collectedInternalReward        int64      // collected internal reward
	externalIncentives             *avl.Tree  // incentiveID → *ExternalIncentiveState
	lastExternalIncentiveUpdatedAt int64      // last time when external incentive ids were synced
	tickLower                      int32      // tick lower
	tickUpper                      int32      // tick upper
}

func (d *Deposit) Owner() address {
	return d.owner
}

func (d *Deposit) SetOwner(owner address) {
	d.owner = owner
}

func (d *Deposit) TargetPoolPath() string {
	return d.targetPoolPath
}

func (d *Deposit) SetTargetPoolPath(targetPoolPath string) {
	d.targetPoolPath = targetPoolPath
}

func (d *Deposit) Liquidity() *u256.Uint {
	return d.liquidity
}

func (d *Deposit) SetLiquidity(liquidity *u256.Uint) {
	d.liquidity = liquidity
}

func (d *Deposit) StakeTime() int64 {
	return d.stakeTime
}

func (d *Deposit) SetStakeTime(stakeTime int64) {
	d.stakeTime = stakeTime
}

func (d *Deposit) InternalRewardLastCollectTime() int64 {
	return d.internalRewardLastCollectTime
}

func (d *Deposit) SetInternalRewardLastCollectTime(internalRewardLastCollectTime int64) {
	d.internalRewardLastCollectTime = internalRewardLastCollectTime
}

func (d *Deposit) CollectedInternalReward() int64 {
	return d.collectedInternalReward
}

func (d *Deposit) SetCollectedInternalReward(collectedInternalReward int64) {
	d.collectedInternalReward = collectedInternalReward
}

// getOrCreateIncentiveState returns the state for the given incentive ID,
// creating a new entry if one does not exist.
func (d *Deposit) getOrCreateIncentiveState(incentiveID string) *ExternalIncentiveState {
	if d.externalIncentives == nil {
		d.externalIncentives = avl.NewTree()
	}
	v, ok := d.externalIncentives.Get(incentiveID)
	if !ok {
		state := &ExternalIncentiveState{}
		d.externalIncentives.Set(incentiveID, state)
		return state
	}
	return v.(*ExternalIncentiveState)
}

// getIncentiveState returns the state for the given incentive ID, or nil if not found.
func (d *Deposit) getIncentiveState(incentiveID string) *ExternalIncentiveState {
	if d.externalIncentives == nil {
		return nil
	}
	v, ok := d.externalIncentives.Get(incentiveID)
	if !ok {
		return nil
	}
	return v.(*ExternalIncentiveState)
}

// GetCollectedExternalReward returns the collected external reward for the given incentive ID.
// Returns 0 if the incentive ID does not exist.
func (d *Deposit) GetCollectedExternalReward(incentiveID string) (int64, bool) {
	state := d.getIncentiveState(incentiveID)
	if state == nil {
		return 0, false
	}
	return state.CollectedReward, true
}

func (d *Deposit) SetCollectedExternalReward(incentiveID string, reward int64) {
	d.getOrCreateIncentiveState(incentiveID).CollectedReward = reward
}

// GetExternalRewardLastCollectTime returns the last collect time for the given incentive ID.
// Returns 0 if the incentive ID does not exist.
func (d *Deposit) GetExternalRewardLastCollectTime(incentiveID string) (int64, bool) {
	state := d.getIncentiveState(incentiveID)
	if state == nil {
		return 0, false
	}
	return state.LastCollectTime, true
}

func (d *Deposit) SetExternalRewardLastCollectTime(incentiveID string, currentTime int64) {
	d.getOrCreateIncentiveState(incentiveID).LastCollectTime = currentTime
}

func (d *Deposit) TickLower() int32 {
	return d.tickLower
}

func (d *Deposit) SetTickLower(tickLower int32) {
	d.tickLower = tickLower
}

func (d *Deposit) TickUpper() int32 {
	return d.tickUpper
}

func (d *Deposit) SetTickUpper(tickUpper int32) {
	d.tickUpper = tickUpper
}

// AddExternalIncentiveId adds an external incentive id to the deposit.
func (d *Deposit) AddExternalIncentiveId(incentiveId string) {
	d.getOrCreateIncentiveState(incentiveId)
}

// HasExternalIncentiveId checks if the deposit has the given external incentive id.
func (d *Deposit) HasExternalIncentiveId(incentiveId string) bool {
	if d.externalIncentives == nil {
		return false
	}
	return d.externalIncentives.Has(incentiveId)
}

// RemoveExternalIncentiveId removes an external incentive id from the deposit.
func (d *Deposit) RemoveExternalIncentiveId(incentiveId string) {
	if d.externalIncentives == nil {
		return
	}
	d.externalIncentives.Remove(incentiveId)
}

// GetExternalIncentiveIdList returns a list of external incentive ids for the deposit.
func (d *Deposit) GetExternalIncentiveIdList() []string {
	if d.externalIncentives == nil {
		return []string{}
	}

	ids := make([]string, 0, d.externalIncentives.Size())
	d.externalIncentives.Iterate("", "", func(key string, _ any) bool {
		ids = append(ids, key)
		return false
	})
	return ids
}

// IterateExternalIncentiveIds iterates over external incentive IDs without allocating a slice.
// The callback function receives each incentive ID and should return false to continue iteration,
// or true to stop early.
func (d *Deposit) IterateExternalIncentiveIds(fn func(incentiveId string) bool) {
	if d.externalIncentives == nil {
		return
	}
	d.externalIncentives.Iterate("", "", func(key string, _ any) bool {
		return fn(key)
	})
}

func (d *Deposit) Warmups() []Warmup {
	return d.warmups
}

func (d *Deposit) SetWarmups(warmups []Warmup) {
	d.warmups = warmups
}

func (d *Deposit) LastExternalIncentiveUpdatedAt() int64 {
	return d.lastExternalIncentiveUpdatedAt
}

func (d *Deposit) SetLastExternalIncentiveUpdatedAt(timestamp int64) {
	d.lastExternalIncentiveUpdatedAt = timestamp
}

// Clone returns a deep copy of the deposit.
func (d *Deposit) Clone() *Deposit {
	if d == nil {
		return nil
	}

	return &Deposit{
		warmups:                        cloneWarmups(d.warmups),
		liquidity:                      d.liquidity.Clone(),
		targetPoolPath:                 d.targetPoolPath,
		owner:                          d.owner,
		stakeTime:                      d.stakeTime,
		internalRewardLastCollectTime:  d.internalRewardLastCollectTime,
		collectedInternalReward:        d.collectedInternalReward,
		externalIncentives:             cloneExternalIncentives(d.externalIncentives),
		lastExternalIncentiveUpdatedAt: d.lastExternalIncentiveUpdatedAt,
		tickLower:                      d.tickLower,
		tickUpper:                      d.tickUpper,
	}
}

func NewDeposit(
	owner address,
	targetPoolPath string,
	liquidity *u256.Uint,
	currentTime int64,
	tickLower, tickUpper int32,
	warmups []Warmup,
) *Deposit {
	return &Deposit{
		owner:                          owner,
		targetPoolPath:                 targetPoolPath,
		liquidity:                      liquidity,
		warmups:                        warmups,
		stakeTime:                      currentTime,
		tickLower:                      tickLower,
		tickUpper:                      tickUpper,
		internalRewardLastCollectTime:  currentTime,
		collectedInternalReward:        0,
		externalIncentives:             avl.NewTree(),
		lastExternalIncentiveUpdatedAt: 0,
	}
}

type Warmup struct {
	Index          int
	TimeDuration   int64
	NextWarmupTime int64 // time when this warmup period ends
	WarmupRatio    uint64
}

func (w *Warmup) SetNextWarmupTime(nextWarmupTime int64) {
	w.NextWarmupTime = nextWarmupTime
}

func (w *Warmup) SetWarmupRatio(warmupRatio uint64) {
	w.WarmupRatio = warmupRatio
}

func (w *Warmup) SetTimeDuration(timeDuration int64) {
	w.TimeDuration = timeDuration
}

func DefaultWarmupTemplate() []Warmup {
	secondsInDay := int64(86400)
	secondsIn5Days := int64(5 * secondsInDay)
	secondsIn10Days := int64(10 * secondsInDay)
	secondsIn30Days := int64(30 * secondsInDay)

	// NextWarmupTime is set to 0 for template.
	// They will be set by InstantiateWarmup()
	return []Warmup{
		{
			Index:        0,
			TimeDuration: secondsIn5Days,
			// NextWarmupTime will be set based on currentTime
			// NextWarmupTime: currentTime + secondsIn5Days,
			WarmupRatio: 30,
		},
		{
			Index:        1,
			TimeDuration: secondsIn10Days,
			// NextWarmupTime will be set based on currentTime
			// NextWarmupTime: currentTime + secondsIn10Days,
			WarmupRatio: 50,
		},
		{
			Index:        2,
			TimeDuration: secondsIn30Days,
			// NextWarmupTime will be set based on currentTime
			// NextWarmupTime: currentTime + secondsIn30Days,
			WarmupRatio: 70,
		},
		{
			Index:        3,
			TimeDuration: math.MaxInt64,
			// NextWarmupTime will be set to math.MaxInt64
			// NextWarmupTime: math.MaxInt64,
			WarmupRatio: 100,
		},
	}
}
