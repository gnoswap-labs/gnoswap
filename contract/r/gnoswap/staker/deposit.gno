package staker

import (
	"math"

	u256 "gno.land/p/gnoswap/uint256"
)

type Deposit struct {
	warmups                        []Warmup         // warmup information
	liquidity                      *u256.Uint       // liquidity
	targetPoolPath                 string           // staked position's pool path
	owner                          address          // owner address
	stakeTime                      int64            // staked time
	internalRewardLastCollectTime  int64            // last collect time for internal reward
	collectedInternalReward        int64            // collected internal reward
	collectedExternalRewards       map[string]int64 // collected external reward by incentive id (incentiveID -> int64)
	externalRewardLastCollectTimes map[string]int64 // last collect time for external rewards by incentive id (incentiveID -> int64)
	externalIncentiveIds           map[string]bool  // external incentive ids for this deposit (incentiveID -> bool)
	lastExternalIncentiveUpdatedAt int64            // last time when external incentive ids were synced
	tickLower                      int32            // tick lower
	tickUpper                      int32            // tick upper
}

// Owner returns the address that owns the staked position.
//
// Returns:
//   - owner: Address recorded as the deposit owner.
func (d *Deposit) Owner() address {
	return d.owner
}

// SetOwner updates the address recorded as the deposit owner.
//
// Parameters:
//   - owner: Address that should own the deposit.
func (d *Deposit) SetOwner(owner address) {
	d.owner = owner
}

// TargetPoolPath returns the pool path associated with the staked position.
//
// Returns:
//   - targetPoolPath: Pool identifier used to resolve the position's pool.
func (d *Deposit) TargetPoolPath() string {
	return d.targetPoolPath
}

// SetTargetPoolPath updates the pool path associated with the staked position.
//
// Parameters:
//   - targetPoolPath: Pool identifier to associate with the deposit.
func (d *Deposit) SetTargetPoolPath(targetPoolPath string) {
	d.targetPoolPath = targetPoolPath
}

// Liquidity returns the LP liquidity recorded for the deposit.
//
// Returns:
//   - liquidity: Liquidity amount represented by the staked position.
func (d *Deposit) Liquidity() *u256.Uint {
	return d.liquidity
}

// SetLiquidity replaces the LP liquidity recorded for the deposit.
//
// Parameters:
//   - liquidity: New liquidity amount; the setter copies this value into the deposit.
func (d *Deposit) SetLiquidity(liquidity *u256.Uint) {
	d.liquidity = u256.Zero().Set(liquidity)
}

// StakeTime returns the Unix timestamp at which the position was staked.
//
// Returns:
//   - stakeTime: Stake start time in Unix seconds.
func (d *Deposit) StakeTime() int64 {
	return d.stakeTime
}

// SetStakeTime updates the Unix timestamp at which the position was staked.
//
// Parameters:
//   - stakeTime: Stake start time in Unix seconds.
func (d *Deposit) SetStakeTime(stakeTime int64) {
	d.stakeTime = stakeTime
}

// InternalRewardLastCollectTime returns the internal-reward collection cursor.
//
// Returns:
//   - internalRewardLastCollectTime: Last internal reward collection time in Unix seconds.
func (d *Deposit) InternalRewardLastCollectTime() int64 {
	return d.internalRewardLastCollectTime
}

// SetInternalRewardLastCollectTime updates the internal-reward collection cursor.
//
// Parameters:
//   - internalRewardLastCollectTime: New last internal reward collection time in Unix seconds.
func (d *Deposit) SetInternalRewardLastCollectTime(internalRewardLastCollectTime int64) {
	d.internalRewardLastCollectTime = internalRewardLastCollectTime
}

// CollectedInternalReward returns the cumulative internal reward recorded for the deposit.
//
// Returns:
//   - collectedInternalReward: Accumulated internal reward amount in the reward token's smallest units.
func (d *Deposit) CollectedInternalReward() int64 {
	return d.collectedInternalReward
}

// SetCollectedInternalReward replaces the cumulative internal reward recorded for the deposit.
//
// Parameters:
//   - collectedInternalReward: Cumulative internal reward amount in the reward token's smallest units.
func (d *Deposit) SetCollectedInternalReward(collectedInternalReward int64) {
	d.collectedInternalReward = collectedInternalReward
}

// CollectedExternalRewards returns cumulative external rewards keyed by incentive ID.
//
// Returns:
//   - collectedExternalRewards: Map from incentive ID to the amount collected for that incentive.
func (d *Deposit) CollectedExternalRewards() map[string]int64 {
	return d.collectedExternalRewards
}

// SetCollectedExternalRewards replaces the cumulative external-reward map.
//
// Parameters:
//   - collectedExternalRewards: Map from incentive ID to its collected reward amount.
func (d *Deposit) SetCollectedExternalRewards(collectedExternalRewards map[string]int64) {
	d.collectedExternalRewards = collectedExternalRewards
}

// GetCollectedExternalReward returns the collected external reward for the given incentive ID.
// Returns 0 if the incentive ID does not exist.
//
// Parameters:
//   - incentiveID: External incentive ID whose collected amount should be looked up.
//
// Returns:
//   - reward: Collected amount for the incentive, or 0 when the ID is absent.
//   - exists: True when the map contains incentiveID; false when it is absent.
func (d *Deposit) GetCollectedExternalReward(incentiveID string) (int64, bool) {
	reward, exists := d.collectedExternalRewards[incentiveID]
	if !exists {
		return 0, false
	}

	return reward, true
}

// SetCollectedExternalReward records the cumulative amount collected for one incentive.
//
// Parameters:
//   - incentiveID: External incentive ID whose collected amount should be set.
//   - reward: Cumulative collected amount for incentiveID.
func (d *Deposit) SetCollectedExternalReward(incentiveID string, reward int64) {
	if d.collectedExternalRewards == nil {
		d.collectedExternalRewards = make(map[string]int64)
	}

	d.collectedExternalRewards[incentiveID] = reward
}

// ExternalRewardLastCollectTimes returns per-incentive external collection cursors.
//
// Returns:
//   - externalRewardLastCollectTimes: Map from incentive ID to its last collection time in Unix seconds.
func (d *Deposit) ExternalRewardLastCollectTimes() map[string]int64 {
	return d.externalRewardLastCollectTimes
}

// SetExternalRewardLastCollectTimes replaces the per-incentive external collection cursors.
//
// Parameters:
//   - externalRewardLastCollectTimes: Map from incentive ID to its last collection time in Unix seconds.
func (d *Deposit) SetExternalRewardLastCollectTimes(externalRewardLastCollectTimes map[string]int64) {
	d.externalRewardLastCollectTimes = externalRewardLastCollectTimes
}

// GetExternalRewardLastCollectTime returns the last collect time for the given incentive ID.
// Returns 0 if the incentive ID does not exist.
//
// Parameters:
//   - incentiveID: External incentive ID whose collection cursor should be looked up.
//
// Returns:
//   - time: Last collection time for the incentive in Unix seconds, or 0 when the ID is absent.
//   - exists: True when the map contains incentiveID; false when it is absent.
func (d *Deposit) GetExternalRewardLastCollectTime(incentiveID string) (int64, bool) {
	time, exists := d.externalRewardLastCollectTimes[incentiveID]
	if !exists {
		return 0, false
	}

	return time, true
}

// SetExternalRewardLastCollectTime records the collection cursor for one incentive.
//
// Parameters:
//   - incentiveID: External incentive ID whose cursor should be set.
//   - currentTime: New collection time for incentiveID in Unix seconds.
func (d *Deposit) SetExternalRewardLastCollectTime(incentiveID string, currentTime int64) {
	if d.externalRewardLastCollectTimes == nil {
		d.externalRewardLastCollectTimes = make(map[string]int64)
	}

	d.externalRewardLastCollectTimes[incentiveID] = currentTime
}

// TickLower returns the lower signed tick boundary of the staked position.
//
// Returns:
//   - tickLower: Lower tick boundary used by the position's price range.
func (d *Deposit) TickLower() int32 {
	return d.tickLower
}

// SetTickLower updates the lower signed tick boundary of the staked position.
//
// Parameters:
//   - tickLower: Lower tick boundary to store for the position's price range.
func (d *Deposit) SetTickLower(tickLower int32) {
	d.tickLower = tickLower
}

// TickUpper returns the upper signed tick boundary of the staked position.
//
// Returns:
//   - tickUpper: Upper tick boundary used by the position's price range.
func (d *Deposit) TickUpper() int32 {
	return d.tickUpper
}

// SetTickUpper updates the upper signed tick boundary of the staked position.
//
// Parameters:
//   - tickUpper: Upper tick boundary to store for the position's price range.
func (d *Deposit) SetTickUpper(tickUpper int32) {
	d.tickUpper = tickUpper
}

// ExternalIncentiveIds returns the deposit's indexed external incentive IDs.
//
// Returns:
//   - externalIncentiveIds: Map from each indexed incentive ID to its membership flag.
func (d *Deposit) ExternalIncentiveIds() map[string]bool {
	return d.externalIncentiveIds
}

// SetExternalIncentiveIds replaces the deposit's indexed external incentive IDs.
//
// Parameters:
//   - externalIncentiveIds: Map of incentive IDs to their membership flags.
func (d *Deposit) SetExternalIncentiveIds(externalIncentiveIds map[string]bool) {
	d.externalIncentiveIds = externalIncentiveIds
}

// AddExternalIncentiveId adds an external incentive id to the deposit.
//
// Parameters:
//   - incentiveId: External incentive ID to add to the deposit's index.
func (d *Deposit) AddExternalIncentiveId(incentiveId string) {
	if d.externalIncentiveIds == nil {
		d.externalIncentiveIds = make(map[string]bool)
	}

	d.externalIncentiveIds[incentiveId] = true
}

// HasExternalIncentiveId checks if the deposit has the given external incentive id.
//
// Parameters:
//   - incentiveId: External incentive ID whose membership should be checked.
//
// Returns:
//   - hasIncentive: True when incentiveId is indexed on the deposit; false otherwise.
func (d *Deposit) HasExternalIncentiveId(incentiveId string) bool {
	if d.externalIncentiveIds == nil {
		return false
	}

	return d.externalIncentiveIds[incentiveId]
}

// RemoveExternalIncentiveId removes an external incentive id from the deposit.
//
// Parameters:
//   - incentiveId: External incentive ID to remove from the deposit's index.
func (d *Deposit) RemoveExternalIncentiveId(incentiveId string) {
	if d.externalIncentiveIds == nil {
		return
	}

	delete(d.externalIncentiveIds, incentiveId)
}

// GetExternalIncentiveIdList returns a list of external incentive ids for the deposit.
//
// Returns:
//   - incentiveIds: Slice containing the incentive IDs currently indexed on the deposit; order follows map iteration and is not guaranteed.
func (d *Deposit) GetExternalIncentiveIdList() []string {
	if d.externalIncentiveIds == nil {
		return []string{}
	}

	ids := make([]string, 0, len(d.externalIncentiveIds))

	for incentiveId := range d.externalIncentiveIds {
		ids = append(ids, incentiveId)
	}

	return ids
}

// IterateExternalIncentiveIds iterates over external incentive IDs without allocating a slice.
// The callback function receives each incentive ID and should return false to continue iteration,
// or true to stop early. This method is more memory-efficient than GetExternalIncentiveIdList
// for cases where you only need to process IDs sequentially.
//
// Parameters:
//   - fn: Callback invoked with each indexed incentive ID; return true to stop iteration early or false to continue.
func (d *Deposit) IterateExternalIncentiveIds(fn func(incentiveId string) bool) {
	if d.externalIncentiveIds == nil {
		return
	}

	for incentiveId := range d.externalIncentiveIds {
		if fn(incentiveId) {
			return
		}
	}
}

// Warmups returns a copy of the deposit's warmup schedule.
//
// Returns:
//   - warmups: Warmup tiers applied to rewards for this deposit, or nil when no schedule is stored.
func (d *Deposit) Warmups() []Warmup {
	return cloneWarmups(d.warmups)
}

// SetWarmups replaces the deposit's warmup schedule with a copied slice.
//
// Parameters:
//   - warmups: Warmup tiers to use for subsequent reward calculations.
func (d *Deposit) SetWarmups(warmups []Warmup) {
	d.warmups = cloneWarmups(warmups)
}

// LastExternalIncentiveUpdatedAt returns the timestamp of the last external-incentive index refresh.
//
// Returns:
//   - timestamp: Last refresh time in Unix seconds.
func (d *Deposit) LastExternalIncentiveUpdatedAt() int64 {
	return d.lastExternalIncentiveUpdatedAt
}

// SetLastExternalIncentiveUpdatedAt updates the external-incentive index refresh timestamp.
//
// Parameters:
//   - timestamp: Refresh time to record in Unix seconds.
func (d *Deposit) SetLastExternalIncentiveUpdatedAt(timestamp int64) {
	d.lastExternalIncentiveUpdatedAt = timestamp
}

// Clone returns a deep copy of the deposit.
//
// Returns:
//   - deposit: Deep copy of the deposit, or nil when the receiver is nil.
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
		collectedExternalRewards:       cloneStringInt64Map(d.collectedExternalRewards),
		externalRewardLastCollectTimes: cloneStringInt64Map(d.externalRewardLastCollectTimes),
		externalIncentiveIds:           cloneStringBoolMap(d.externalIncentiveIds),
		lastExternalIncentiveUpdatedAt: d.lastExternalIncentiveUpdatedAt,
		tickLower:                      d.tickLower,
		tickUpper:                      d.tickUpper,
	}
}

// NewDeposit creates a deposit for a staked LP position and initializes its reward cursors and maps.
//
// Parameters:
//   - owner: Address that owns the staked position.
//   - targetPoolPath: Pool identifier associated with the position.
//   - liquidity: LP liquidity amount represented by the position.
//   - currentTime: Staking and initial reward-cursor time in Unix seconds.
//   - tickLower: Lower signed tick boundary of the position's range.
//   - tickUpper: Upper signed tick boundary of the position's range.
//   - warmups: Warmup schedule to apply to this position's rewards.
//
// Returns:
//   - deposit: Newly initialized deposit containing the supplied position and warmup state.
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
		externalRewardLastCollectTimes: make(map[string]int64),
		collectedInternalReward:        0,
		collectedExternalRewards:       make(map[string]int64),
		externalIncentiveIds:           make(map[string]bool),
		lastExternalIncentiveUpdatedAt: 0,
	}
}

type Warmup struct {
	TimeDuration   int64
	NextWarmupTime int64 // time when this warmup period ends
	WarmupRatio    uint64
}

// NewWarmup creates one warmup tier.
//
// Parameters:
//   - timeDuration: Duration of this tier in seconds.
//   - nextWarmupTime: Unix timestamp at which this tier ends.
//   - warmupRatio: Percentage of the calculated reward credited to the position, from 0 to 100.
//
// Returns:
//   - warmup: Warmup tier initialized with the supplied duration, end time, and ratio.
func NewWarmup(timeDuration, nextWarmupTime int64, warmupRatio uint64) Warmup {
	return Warmup{
		TimeDuration:   timeDuration,
		NextWarmupTime: nextWarmupTime,
		WarmupRatio:    warmupRatio,
	}
}

// SetNextWarmupTime updates the Unix timestamp at which this warmup tier ends.
//
// Parameters:
//   - nextWarmupTime: Tier end time in Unix seconds.
func (w *Warmup) SetNextWarmupTime(nextWarmupTime int64) {
	w.NextWarmupTime = nextWarmupTime
}

// SetWarmupRatio updates the percentage of calculated reward credited to the position.
//
// Parameters:
//   - warmupRatio: Reward percentage for this tier, expressed from 0 to 100.
func (w *Warmup) SetWarmupRatio(warmupRatio uint64) {
	w.WarmupRatio = warmupRatio
}

// SetTimeDuration updates the duration of this warmup tier.
//
// Parameters:
//   - timeDuration: Tier duration in seconds.
func (w *Warmup) SetTimeDuration(timeDuration int64) {
	w.TimeDuration = timeDuration
}

// DefaultWarmupTemplate returns the built-in four-tier warmup schedule.
//
// Returns:
//   - warmups: Template with 5-day, 10-day, 30-day, and final-unbounded tiers using 30%, 50%, 70%, and 100% ratios; NextWarmupTime values are zero until instantiated.
func DefaultWarmupTemplate() []Warmup {
	secondsInDay := int64(86400)
	secondsIn5Days := int64(5 * secondsInDay)
	secondsIn10Days := int64(10 * secondsInDay)
	secondsIn30Days := int64(30 * secondsInDay)

	// NextWarmupTime is set to 0 for template.
	// They will be set by InstantiateWarmup()
	return []Warmup{
		{
			TimeDuration: secondsIn5Days,
			// NextWarmupTime will be set based on currentTime
			// NextWarmupTime: currentTime + secondsIn5Days,
			WarmupRatio: 30,
		},
		{
			TimeDuration: secondsIn10Days,
			// NextWarmupTime will be set based on currentTime
			// NextWarmupTime: currentTime + secondsIn10Days,
			WarmupRatio: 50,
		},
		{
			TimeDuration: secondsIn30Days,
			// NextWarmupTime will be set based on currentTime
			// NextWarmupTime: currentTime + secondsIn30Days,
			WarmupRatio: 70,
		},
		{
			TimeDuration: math.MaxInt64,
			// NextWarmupTime will be set to math.MaxInt64
			// NextWarmupTime: math.MaxInt64,
			WarmupRatio: 100,
		},
	}
}

const (
	GNS_PATH    string = "gno.land/r/gnoswap/gns.GNS"
	WUGNOT_PATH string = "gno.land/r/gnoland/wugnot.wugnot"
)

// DefaultAllowedTokens returns the token paths accepted by the staker's default configuration.
//
// Returns:
//   - tokenPaths: Slice containing the GNS and wrapped-GNOT token paths.
func DefaultAllowedTokens() []string {
	return []string{GNS_PATH, WUGNOT_PATH}
}
