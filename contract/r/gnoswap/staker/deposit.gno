package staker

import (
	"math"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
)

type Deposit struct {
	warmups                        []Warmup   // warmup information
	liquidity                      *u256.Uint // liquidity
	targetPoolPath                 string     // staked position's pool path
	owner                          address    // owner address
	stakeTime                      int64      // staked time
	internalRewardLastCollectTime  int64      // last collect time for internal reward
	collectedInternalReward        int64      // collected internal reward
	collectedExternalRewards       *avl.Tree  // collected external reward by incentive id (incentiveID -> int64)
	externalRewardLastCollectTimes *avl.Tree  // last collect time for external rewards by incentive id (incentiveID -> int64)
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

func (d *Deposit) CollectedExternalRewards() *avl.Tree {
	return d.collectedExternalRewards
}

func (d *Deposit) SetCollectedExternalRewards(collectedExternalRewards *avl.Tree) {
	d.collectedExternalRewards = collectedExternalRewards
}

// GetCollectedExternalReward returns the collected external reward for the given incentive ID.
// Returns 0 if the incentive ID does not exist.
func (d *Deposit) GetCollectedExternalReward(incentiveID string) (int64, bool) {
	if d.collectedExternalRewards == nil {
		return 0, false
	}

	value, exists := d.collectedExternalRewards.Get(incentiveID)
	if !exists {
		return 0, false
	}

	return value.(int64), true
}

func (d *Deposit) SetCollectedExternalReward(incentiveID string, reward int64) {
	if d.collectedExternalRewards == nil {
		d.collectedExternalRewards = avl.NewTree()
	}
	d.collectedExternalRewards.Set(incentiveID, reward)
}

func (d *Deposit) ExternalRewardLastCollectTimes() *avl.Tree {
	return d.externalRewardLastCollectTimes
}

func (d *Deposit) SetExternalRewardLastCollectTimes(externalRewardLastCollectTimes *avl.Tree) {
	d.externalRewardLastCollectTimes = externalRewardLastCollectTimes
}

// GetExternalRewardLastCollectTime returns the last collect time for the given incentive ID.
// Returns 0 if the incentive ID does not exist.
func (d *Deposit) GetExternalRewardLastCollectTime(incentiveID string) (int64, bool) {
	if d.externalRewardLastCollectTimes == nil {
		return 0, false
	}

	value, exists := d.externalRewardLastCollectTimes.Get(incentiveID)
	if !exists {
		return 0, false
	}

	return value.(int64), true
}

func (d *Deposit) SetExternalRewardLastCollectTime(incentiveID string, currentTime int64) {
	if d.externalRewardLastCollectTimes == nil {
		d.externalRewardLastCollectTimes = avl.NewTree()
	}
	d.externalRewardLastCollectTimes.Set(incentiveID, currentTime)
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

func (d *Deposit) Warmups() []Warmup {
	return d.warmups
}

func (d *Deposit) SetWarmups(warmups []Warmup) {
	d.warmups = warmups
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
		externalRewardLastCollectTimes: avl.NewTree(),
		collectedInternalReward:        0,
		collectedExternalRewards:       avl.NewTree(),
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
