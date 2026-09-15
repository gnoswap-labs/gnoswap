package staker

import (
	"errors"
	"time"

	"gno.land/p/gnoswap/consts"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/gnoswap/utils"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

const AllTierCount = 4 // 0, 1, 2, 3

// Pool is a struct for storing an incentivized pool information
// Each pool stores Incentives and Ticks associated with it.
//
// Fields:
// - poolPath: The path of the pool.
//
//   - stakedLiquidity:
//     The current total staked liquidity of the in-range positions for the pool.
//     Updated when tick cross happens or stake/unstake happens.
//     Used to calculate the global reward ratio accumulation or
//     decide whether to enter/exit unclaimable period.
//
//   - lastUnclaimableTime:
//     The time at which the unclaimable period started.
//     Set to 0 when the pool is not in an unclaimable period.
//
//   - unclaimableAcc:
//     The accumulated undistributed unclaimable reward.
//     Reset to 0 when processUnclaimableReward is called and sent to community pool.
//
//   - rewardCache:
//     The cached per-second reward emitted for this pool.
//     Stores new entry only when the reward is changed.
//     PoolTier.cacheReward() updates this.
//
// - incentives: The external incentives associated with the pool.
//
// - ticks: The Ticks associated with the pool.
//
//   - globalRewardRatioAccumulation:
//     Global ratio of Time / TotalStake accumulation(since the pool creation)
//     Stores new entry only when tick cross or stake/unstake happens.
//     It is used to calculate the reward for a staked position at certain time.
//
//   - historicalTick:
//     The historical tick for the pool at a given time.
//     It does not reflect the exact tick at the timestamp,
//     but it provides correct ordering for the staked position's ticks.
//     Therefore, you should not compare it for equality, only for ordering.
//     Set when tick cross happens or a new position is created.
type Pool struct {
	poolPath string

	stakedLiquidity *UintTree // uint64 timestamp -> *u256.Uint(Q128)

	lastUnclaimableTime int64
	unclaimableAcc      int64

	rewardCache *UintTree // uint64 timestamp -> int64 gnsReward

	incentives *Incentives

	ticks Ticks // int32 tickId -> Tick tick

	globalRewardRatioAccumulation *UintTree // uint64 timestamp -> *u256.Uint(Q128) rewardRatioAccumulation

	historicalTick *UintTree // uint64 timestamp -> int32 tickId
}

// Pool Getter/Setter methods

// PoolPath returns the pool path
//
// Returns:
//   - path: Pool identifier used to associate this state with a liquidity pool.
func (p *Pool) PoolPath() string {
	return p.poolPath
}

// SetPoolPath sets the pool path
//
// Parameters:
//   - poolPath: Pool identifier to store.
func (p *Pool) SetPoolPath(poolPath string) {
	p.poolPath = poolPath
}

// StakedLiquidity returns the staked liquidity tree
//
// Returns:
//   - tree: Historical staked-liquidity tree keyed by Unix timestamp, with Q128-scaled liquidity values.
func (p *Pool) StakedLiquidity() *UintTree {
	return p.stakedLiquidity
}

// SetStakedLiquidity sets the staked liquidity tree
//
// Parameters:
//   - stakedLiquidity: Tree of historical total staked liquidity snapshots.
func (p *Pool) SetStakedLiquidity(stakedLiquidity *UintTree) {
	p.stakedLiquidity = stakedLiquidity
}

// SetStakedLiquidityAt records the current total staked liquidity at a timestamp.
//
// Parameters:
//   - currentTime: Nonnegative Unix timestamp in seconds used as the snapshot key.
//   - delta: Total staked liquidity at currentTime, stored as a copied Q128-scaled uint value.
func (p *Pool) SetStakedLiquidityAt(currentTime int64, delta *u256.Uint) {
	p.StakedLiquidity().Set(currentTime, u256.Zero().Set(delta))
}

// LastUnclaimableTime returns the last unclaimable time
//
// Returns:
//   - timestamp: Unix timestamp in seconds at which the pool entered its current unclaimable period, or 0 when tracking has not started.
func (p *Pool) LastUnclaimableTime() int64 {
	return p.lastUnclaimableTime
}

// SetLastUnclaimableTime sets the last unclaimable time
//
// Parameters:
//   - lastUnclaimableTime: Unix timestamp in seconds marking the start of the current unclaimable period; use 0 when no period is active.
func (p *Pool) SetLastUnclaimableTime(lastUnclaimableTime int64) {
	p.lastUnclaimableTime = lastUnclaimableTime
}

// UnclaimableAcc returns the unclaimable accumulation
//
// Returns:
//   - amount: Accumulated undistributed unclaimable reward amount in the pool's int64 reward units.
func (p *Pool) UnclaimableAcc() int64 {
	return p.unclaimableAcc
}

// SetUnclaimableAcc sets the unclaimable accumulation
//
// Parameters:
//   - unclaimableAcc: Accumulated undistributed unclaimable reward amount in the pool's int64 reward units.
func (p *Pool) SetUnclaimableAcc(unclaimableAcc int64) {
	p.unclaimableAcc = unclaimableAcc
}

// RewardCache returns the reward cache tree
//
// Returns:
//   - tree: Historical per-second GNS reward cache keyed by Unix timestamp.
func (p *Pool) RewardCache() *UintTree {
	return p.rewardCache
}

// SetRewardCache sets the reward cache tree
//
// Parameters:
//   - rewardCache: Tree containing the pool's per-second GNS reward snapshots.
func (p *Pool) SetRewardCache(rewardCache *UintTree) {
	p.rewardCache = rewardCache
}

// SetRewardCacheAt records the per-second reward rate for a timestamp.
//
// Parameters:
//   - currentTime: Nonnegative Unix timestamp in seconds used as the cache key.
//   - reward: GNS reward emitted per second from currentTime until the next cached change.
func (p *Pool) SetRewardCacheAt(currentTime int64, reward int64) {
	p.RewardCache().Set(currentTime, reward)
}

// Incentives returns the incentives
//
// Returns:
//   - incentives: External-incentive collection associated with this pool.
func (p *Pool) Incentives() *Incentives {
	return p.incentives
}

// SetIncentives sets the incentives
//
// Parameters:
//   - incentives: External-incentive collection to associate with the pool.
func (p *Pool) SetIncentives(incentives *Incentives) {
	p.incentives = incentives
}

// Ticks returns the ticks
//
// Returns:
//   - ticks: Addressable tick mapping for this pool's staked positions.
func (p *Pool) Ticks() *Ticks {
	return &p.ticks
}

// SetTicks sets the ticks
//
// Parameters:
//   - ticks: Tick mapping value to store in the pool.
func (p *Pool) SetTicks(ticks Ticks) {
	p.ticks = ticks
}

// GlobalRewardRatioAccumulation returns the global reward ratio accumulation tree
//
// Returns:
//   - tree: Historical global time-per-total-stake accumulation keyed by Unix timestamp.
func (p *Pool) GlobalRewardRatioAccumulation() *UintTree {
	return p.globalRewardRatioAccumulation
}

// SetGlobalRewardRatioAccumulation sets the global reward ratio accumulation tree
//
// Parameters:
//   - globalRewardRatioAccumulation: Tree of serialized Q128-scaled reward-ratio accumulation snapshots.
func (p *Pool) SetGlobalRewardRatioAccumulation(globalRewardRatioAccumulation *UintTree) {
	p.globalRewardRatioAccumulation = globalRewardRatioAccumulation
}

// SetGlobalRewardRatioAccumulationAt records a serialized global reward-ratio accumulation snapshot.
//
// Parameters:
//   - currentTime: Nonnegative Unix timestamp in seconds used as the snapshot key.
//   - acc: Serialized Q128-scaled global reward-ratio accumulation value.
func (p *Pool) SetGlobalRewardRatioAccumulationAt(currentTime int64, acc string) {
	p.GlobalRewardRatioAccumulation().Set(currentTime, acc)
}

// HistoricalTick returns the historical tick tree
//
// Returns:
//   - tree: Historical tick-ID ordering snapshots keyed by Unix timestamp.
func (p *Pool) HistoricalTick() *UintTree {
	return p.historicalTick
}

// SetHistoricalTick sets the historical tick tree
//
// Parameters:
//   - historicalTick: Tree of tick IDs representing the ordering history of staked positions.
func (p *Pool) SetHistoricalTick(historicalTick *UintTree) {
	p.historicalTick = historicalTick
}

// SetHistoricalTickAt records the tick ordering snapshot for a timestamp.
//
// Parameters:
//   - currentTime: Nonnegative Unix timestamp in seconds used as the snapshot key.
//   - tick: Tick ID representing the pool's historical ordering at currentTime.
func (p *Pool) SetHistoricalTickAt(currentTime int64, tick int32) {
	p.HistoricalTick().Set(currentTime, tick)
}

// Clone returns a pool copy of the scalar state with a fresh tick container.
//
// Returns:
//   - pool: Pool copy carrying scalar state and a fresh tick container; backing trees and incentives are nil, and nil receiver yields nil.
func (p *Pool) Clone() *Pool {
	if p == nil {
		return nil
	}

	return &Pool{
		poolPath:                      p.poolPath,
		stakedLiquidity:               nil,
		lastUnclaimableTime:           p.lastUnclaimableTime,
		unclaimableAcc:                p.unclaimableAcc,
		rewardCache:                   nil,
		incentives:                    nil,
		ticks:                         NewTicks(),
		globalRewardRatioAccumulation: nil,
		historicalTick:                nil,
	}
}

// NewPool creates pool reward state initialized at currentTime (Unix seconds).
//
// Parameters:
//   - poolPath: Pool identifier to store in the new reward-state object.
//   - currentTime: Unix timestamp in seconds used to seed the initial accumulation, reward-cache, and liquidity snapshots.
//
// Returns:
//   - pool: Initialized pool with empty backing structures and zero initial reward/liquidity snapshots at currentTime.
func NewPool(poolPath string, currentTime int64) *Pool {
	pool := &Pool{
		poolPath:        poolPath,
		stakedLiquidity: NewUintTreeN(64),
		// lastUnclaimableTime is initialized to 0, which means "tracking not started yet".
		// When the pool receives a tier assignment (or external incentive), `cacheReward` will be called,
		// which will automatically call `startUnclaimablePeriod` if the pool has zero liquidity.
		// This ensures proper unclaimable period tracking from the moment rewards start emitting.
		lastUnclaimableTime:           0,
		unclaimableAcc:                0,
		rewardCache:                   NewUintTreeN(64),
		incentives:                    NewIncentives(poolPath),
		ticks:                         NewTicks(),
		globalRewardRatioAccumulation: NewUintTreeN(64),
		historicalTick:                NewUintTreeN(64),
	}

	pool.SetGlobalRewardRatioAccumulationAt(currentTime, "0")

	// Initialize rewardCache to 0 to ensure `cacheReward` will trigger on first tier assignment
	pool.SetRewardCacheAt(currentTime, int64(0))
	pool.SetStakedLiquidityAt(currentTime, u256.Zero())

	return pool
}

// Incentives represents a collection of external incentives for a specific pool.
//
// Fields:
//
//   - incentives: BPTree storing ExternalIncentive objects indexed by incentiveId
//     The incentiveId serves as the key to efficiently lookup incentive details
//
//   - targetPoolPath: String identifier for the pool this incentive collection belongs to
//     Used to associate incentives with their corresponding liquidity pool
//
//   - unclaimablePeriods: Tree storing periods when rewards cannot be claimed
//     Maps start timestamp (key) to end timestamp (value)
//     An end timestamp of 0 indicates an ongoing unclaimable period
//     Used to track intervals when staking rewards are not claimable
//
//   - byStartTime: Per-pool start-time index mapping an incentive's start
//     timestamp (key) to the incentive IDs that start at that timestamp
//     (value). This mirrors the lazy-discovery lookup previously served by a
//     global creation-time index, but scoped to this pool's own incentives, so
//     discovery cost is bounded by this pool's incentives instead of growing
//     with the total number of incentives system-wide.
type Incentives struct {
	incentives *bptree.BPTree // (incentiveId) => ExternalIncentive

	targetPoolPath string // The target pool path for this incentive collection

	unclaimablePeriods *UintTree // blockTimestamp -> any

	byStartTime *UintTree // startTimestamp -> []incentiveId
}

// Incentives Getter/Setter methods

// Incentives returns the incentives tree
//
// Returns:
//   - tree: Mutable B+ tree mapping incentive IDs to ExternalIncentive records.
func (i *Incentives) IncentiveTrees() *bptree.BPTree {
	return i.incentives
}

// SetIncentives sets the incentives tree
//
// Parameters:
//   - incentives: B+ tree to use for incentive ID lookups and storage.
func (i *Incentives) SetIncentives(incentives *bptree.BPTree) {
	i.incentives = incentives
}

// TargetPoolPath returns the target pool path
//
// Returns:
//   - path: Pool path to which this incentive collection belongs.
func (i *Incentives) TargetPoolPath() string {
	return i.targetPoolPath
}

// SetTargetPoolPath sets the target pool path
//
// Parameters:
//   - targetPoolPath: Pool path to associate with this incentive collection.
func (i *Incentives) SetTargetPoolPath(targetPoolPath string) {
	i.targetPoolPath = targetPoolPath
}

// UnclaimablePeriods returns the unclaimable periods tree
//
// Returns:
//   - periods: Tree mapping unclaimable-period start timestamps to end timestamps; end 0 denotes an open period.
func (i *Incentives) UnclaimablePeriods() *UintTree {
	return i.unclaimablePeriods
}

// SetUnclaimablePeriods sets the unclaimable periods tree
//
// Parameters:
//   - unclaimablePeriods: Tree of reward-unclaimable intervals keyed by their start timestamps.
func (i *Incentives) SetUnclaimablePeriods(unclaimablePeriods *UintTree) {
	i.unclaimablePeriods = unclaimablePeriods
}

// Incentive returns an incentive by ID
//
// Parameters:
//   - incentiveId: Identifier used to look up the external incentive record.
//
// Returns:
//   - incentive: Matching ExternalIncentive pointer, or nil when no value is stored for incentiveId.
//   - found: True only when the stored value has ExternalIncentive type; false for a missing or mismatched value.
func (i *Incentives) Incentive(incentiveId string) (*ExternalIncentive, bool) {
	value := i.incentives.Get(incentiveId)
	if value == nil {
		return nil, false
	}
	incentive, ok := value.(*ExternalIncentive)
	return incentive, ok
}

// SetIncentive sets an incentive by ID
//
// Parameters:
//   - incentiveId: Identifier under which to store the incentive.
//   - incentive: ExternalIncentive record to store for incentiveId.
func (i *Incentives) SetIncentive(incentiveId string, incentive *ExternalIncentive) {
	i.incentives.Set(incentiveId, incentive)
}

// RemoveIncentive deletes an incentive by ID.
//
// Only an incentive that never started may be removed: once rewards begin
// accruing, deposits and the refund accounting reference the record, so an
// ended incentive is marked refunded instead of removed.
//
// Parameters:
//   - incentiveId: Identifier of the external incentive record to remove.
func (i *Incentives) RemoveIncentive(incentiveId string) {
	i.incentives.Remove(incentiveId)
}

// SetUnclaimablePeriod records an interval during which staking rewards cannot be claimed.
//
// Parameters:
//   - startTimestamp: Nonnegative Unix timestamp in seconds at which the interval begins.
//   - endTimestamp: Unix timestamp in seconds at which the interval ends; 0 records an ongoing interval.
func (i *Incentives) SetUnclaimablePeriod(startTimestamp int64, endTimestamp int64) {
	i.unclaimablePeriods.Set(startTimestamp, endTimestamp)
}

// RemoveUnclaimablePeriod removes the interval keyed by its start timestamp.
//
// Parameters:
//   - startTimestamp: Nonnegative Unix timestamp in seconds identifying the interval to remove.
func (i *Incentives) RemoveUnclaimablePeriod(startTimestamp int64) {
	i.unclaimablePeriods.Remove(startTimestamp)
}

// IterateIncentives iterates over all incentives
//
// Parameters:
//   - fn: Callback receiving each incentive ID and record; returning true requests that iteration stop.
func (i *Incentives) IterateIncentives(fn func(incentiveId string, incentive *ExternalIncentive) bool) {
	i.incentives.Iterate("", "", func(key string, value interface{}) bool {
		if incentive, ok := value.(*ExternalIncentive); ok {
			return fn(key, incentive)
		}
		return false
	})
}

// AddIncentiveByStartTime registers an incentive ID under its start timestamp
// in the per-pool start-time index. Multiple incentives starting at the same
// timestamp are accumulated as a list.
//
// Parameters:
//   - startTimestamp: Nonnegative Unix timestamp in seconds used as the start-time index key.
//   - incentiveId: Incentive identifier to append to that timestamp's bucket.
func (i *Incentives) AddIncentiveByStartTime(startTimestamp int64, incentiveId string) {
	var incentiveIds []string
	if value, ok := i.byStartTime.Get(startTimestamp); ok {
		if ids, ok := value.([]string); ok {
			incentiveIds = ids
		}
	}
	incentiveIds = append(incentiveIds, incentiveId)
	i.byStartTime.Set(startTimestamp, incentiveIds)
}

// RemoveIncentiveByStartTime unregisters an incentive ID from the per-pool
// start-time index. The bucket itself is dropped once its last ID is removed,
// so the index never keeps an empty entry that discovery would still visit.
//
// Parameters:
//   - startTimestamp: Nonnegative Unix timestamp in seconds identifying the start-time bucket.
//   - incentiveId: Incentive identifier to remove from that bucket; all matching entries are omitted.
func (i *Incentives) RemoveIncentiveByStartTime(startTimestamp int64, incentiveId string) {
	value, ok := i.byStartTime.Get(startTimestamp)
	if !ok {
		return
	}

	ids, ok := value.([]string)
	if !ok {
		return
	}

	remaining := make([]string, 0, len(ids))
	for _, id := range ids {
		if id == incentiveId {
			continue
		}
		remaining = append(remaining, id)
	}

	if len(remaining) == 0 {
		i.byStartTime.Remove(startTimestamp)
		return
	}

	i.byStartTime.Set(startTimestamp, remaining)
}

// IterateIncentiveIdsByTime iterates over the incentive IDs that start within
// the inclusive [startTime, endTime] range, visiting only the buckets that
// fall in the range. ReverseIterate is used because it is inclusive on both
// ends, matching the discovery semantics previously implemented as
// (startTimestamp >= startTime && startTimestamp <= endTime).
//
// Parameters:
//   - startTime: Inclusive lower Unix timestamp bound for incentive starts.
//   - endTime: Inclusive upper Unix timestamp bound for incentive starts.
//   - fn: Callback receiving each matching incentive ID; returning true requests that iteration stop.
func (i *Incentives) IterateIncentiveIdsByTime(startTime, endTime int64, fn func(incentiveId string) bool) {
	i.byStartTime.ReverseIterate(startTime, endTime, func(_ int64, value any) bool {
		incentiveIds, ok := value.([]string)
		if !ok {
			return false
		}
		for _, incentiveId := range incentiveIds {
			if fn(incentiveId) {
				return true
			}
		}
		return false
	})
}

// NewIncentives creates an incentive collection for a pool and starts an open unclaimable period at the current time.
//
// Parameters:
//   - targetPoolPath: Pool path to associate with the new incentive collection.
//
// Returns:
//   - incentives: Collection with initialized incentive, start-time, and unclaimable-period trees.
func NewIncentives(targetPoolPath string) *Incentives {
	result := &Incentives{
		targetPoolPath:     targetPoolPath,
		unclaimablePeriods: NewUintTreeN(64),
		incentives:         bptree.NewBPTreeN(16),
		byStartTime:        NewUintTreeN(64),
	}

	// initial unclaimable period starts, as there cannot be any staked positions yet.
	currentTimestamp := time.Now().Unix()
	result.SetUnclaimablePeriod(currentTimestamp, int64(0))
	return result
}

type ExternalIncentive struct {
	incentiveId              string     // incentive id
	startTimestamp           int64      // start time for external reward
	endTimestamp             int64      // end time for external reward
	createdHeight            int64      // block height when the incentive was created
	createdTimestamp         int64      // timestamp when the incentive was created
	depositGnsAmount         int64      // deposited gns amount
	targetPoolPath           string     // external reward target pool path
	rewardToken              string     // external reward token path
	totalRewardAmount        int64      // total reward amount
	rewardAmount             int64      // mutable remaining reward amount
	rewardPerSecondX128      *u256.Uint // reward per second, scaled by 2^128 to preserve sub-second precision
	distributedRewardAmount  int64      // reward amount delivered to positions or refunded at incentive end
	accumulatedPenaltyAmount int64      // accumulated warmup penalty from CollectReward
	creator                  address    // creator address

	refunded bool // whether EndExternalIncentive finalized the incentive and returned its refundable portion and GNS deposit

	unclaimableSeconds int64 // accumulated seconds of unclaimable periods overlapping the incentive window
}

// ExternalIncentive Getter/Setter methods

// IncentiveId returns the incentive ID
//
// Returns:
//   - id: Identifier assigned to this external incentive.
func (e *ExternalIncentive) IncentiveId() string {
	return e.incentiveId
}

// SetIncentiveId sets the incentive ID
//
// Parameters:
//   - incentiveId: Identifier to store on the incentive record.
func (e *ExternalIncentive) SetIncentiveId(incentiveId string) {
	e.incentiveId = incentiveId
}

// StartTimestamp returns the start timestamp.
//
// It keys the byStartTime discovery index and must stay immutable after the
// incentive is registered, so no setter is exposed.
//
// Returns:
//   - timestamp: Unix timestamp in seconds at which reward distribution starts.
func (e *ExternalIncentive) StartTimestamp() int64 {
	return e.startTimestamp
}

// EndTimestamp returns the end timestamp
//
// Returns:
//   - timestamp: Unix timestamp in seconds at which the incentive window ends.
func (e *ExternalIncentive) EndTimestamp() int64 {
	return e.endTimestamp
}

// SetEndTimestamp sets the end timestamp
//
// Parameters:
//   - endTimestamp: Unix timestamp in seconds at which the incentive window ends.
func (e *ExternalIncentive) SetEndTimestamp(endTimestamp int64) {
	e.endTimestamp = endTimestamp
}

// CreatedHeight returns the created height
//
// Returns:
//   - height: Block height at which the incentive record was created.
func (e *ExternalIncentive) CreatedHeight() int64 {
	return e.createdHeight
}

// SetCreatedHeight sets the created height
//
// Parameters:
//   - createdHeight: Block height to record as the incentive's creation height.
func (e *ExternalIncentive) SetCreatedHeight(createdHeight int64) {
	e.createdHeight = createdHeight
}

// CreatedTimestamp returns the created timestamp
//
// Returns:
//   - timestamp: Unix timestamp in seconds at which the incentive record was created.
func (e *ExternalIncentive) CreatedTimestamp() int64 {
	return e.createdTimestamp
}

// SetCreatedTimestamp sets the created timestamp
//
// Parameters:
//   - createdTimestamp: Unix timestamp in seconds to record as the incentive creation time.
func (e *ExternalIncentive) SetCreatedTimestamp(createdTimestamp int64) {
	e.createdTimestamp = createdTimestamp
}

// DepositGnsAmount returns the deposit GNS amount
//
// Returns:
//   - amount: GNS amount deposited to back this external incentive.
func (e *ExternalIncentive) DepositGnsAmount() int64 {
	return e.depositGnsAmount
}

// SetDepositGnsAmount sets the deposit GNS amount
//
// Parameters:
//   - depositGnsAmount: GNS amount deposited to back this external incentive.
func (e *ExternalIncentive) SetDepositGnsAmount(depositGnsAmount int64) {
	e.depositGnsAmount = depositGnsAmount
}

// TargetPoolPath returns the target pool path
//
// Returns:
//   - path: Pool path targeted by this external incentive.
func (e *ExternalIncentive) TargetPoolPath() string {
	return e.targetPoolPath
}

// SetTargetPoolPath sets the target pool path
//
// Parameters:
//   - targetPoolPath: Pool path to target with this external incentive.
func (e *ExternalIncentive) SetTargetPoolPath(targetPoolPath string) {
	e.targetPoolPath = targetPoolPath
}

// RewardToken returns the reward token
//
// Returns:
//   - token: Reward-token path distributed by this incentive.
func (e *ExternalIncentive) RewardToken() string {
	return e.rewardToken
}

// SetRewardToken sets the reward token
//
// Parameters:
//   - rewardToken: Token path of the reward asset distributed by this incentive.
func (e *ExternalIncentive) SetRewardToken(rewardToken string) {
	e.rewardToken = rewardToken
}

// TotalRewardAmount returns the total reward amount
//
// Returns:
//   - amount: Total reward amount configured when the incentive was created.
func (e *ExternalIncentive) TotalRewardAmount() int64 {
	return e.totalRewardAmount
}

// SetTotalRewardAmount sets the total reward amount
//
// Parameters:
//   - totalRewardAmount: Total reward amount to record for the incentive.
func (e *ExternalIncentive) SetTotalRewardAmount(totalRewardAmount int64) {
	e.totalRewardAmount = totalRewardAmount
}

// RewardAmount returns the reward amount
//
// Returns:
//   - amount: Mutable reward amount remaining after distributions and refunds.
func (e *ExternalIncentive) RewardAmount() int64 {
	return e.rewardAmount
}

// SetRewardAmount sets the reward amount
//
// Parameters:
//   - rewardAmount: Remaining reward amount to store after accounting adjustments.
func (e *ExternalIncentive) SetRewardAmount(rewardAmount int64) {
	e.rewardAmount = rewardAmount
}

// RewardPerSecondX128 returns the Q128-scaled reward per second.
// The underlying value is (rewardAmount << 128) / duration.
//
// Returns:
//   - rate: Reward emitted per second, scaled by 2^128 for fixed-point accounting.
func (e *ExternalIncentive) RewardPerSecondX128() *u256.Uint {
	return e.rewardPerSecondX128
}

// SetRewardPerSecondX128 sets the Q128-scaled reward per second.
//
// Parameters:
//   - rewardPerSecondX128: Q128-scaled per-second reward rate; the value is copied before storage.
func (e *ExternalIncentive) SetRewardPerSecondX128(rewardPerSecondX128 *u256.Uint) {
	e.rewardPerSecondX128 = u256.Zero().Set(rewardPerSecondX128)
}

// DistributedRewardAmount returns the distributed reward amount
//
// Returns:
//   - amount: Reward amount already delivered to positions or refunded at incentive end.
func (e *ExternalIncentive) DistributedRewardAmount() int64 {
	return e.distributedRewardAmount
}

// SetDistributedRewardAmount sets the distributed reward amount
//
// Parameters:
//   - distributedRewardAmount: Reward amount delivered to positions or refunded at incentive end.
func (e *ExternalIncentive) SetDistributedRewardAmount(distributedRewardAmount int64) {
	e.distributedRewardAmount = distributedRewardAmount
}

// AccumulatedPenaltyAmount returns the accumulated warmup penalty amount
//
// Returns:
//   - amount: Warm-up penalty accumulated from reward collections for this incentive.
func (e *ExternalIncentive) AccumulatedPenaltyAmount() int64 {
	return e.accumulatedPenaltyAmount
}

// SetAccumulatedPenaltyAmount sets the accumulated warmup penalty amount
//
// Parameters:
//   - accumulatedPenaltyAmount: Warm-up penalty amount to store in the incentive's accumulated accounting.
func (e *ExternalIncentive) SetAccumulatedPenaltyAmount(accumulatedPenaltyAmount int64) {
	e.accumulatedPenaltyAmount = accumulatedPenaltyAmount
}

// Creator returns the creator address
//
// Returns:
//   - creator: Address that created and funded the incentive.
func (e *ExternalIncentive) Creator() address {
	return e.creator
}

// SetCreator sets the creator address
//
// Parameters:
//   - creator: Address to record as the incentive creator and refund recipient.
func (e *ExternalIncentive) SetCreator(creator address) {
	e.creator = creator
}

// Refunded returns the refunded status
//
// Returns:
//   - refunded: True when incentive finalization has marked its refundable balances as returned.
func (e *ExternalIncentive) Refunded() bool {
	return e.refunded
}

// SetRefunded sets the refunded status
//
// Parameters:
//   - refunded: Finalization status to store for the incentive.
func (e *ExternalIncentive) SetRefunded(refunded bool) {
	e.refunded = refunded
}

// UnclaimableSeconds returns the accumulated seconds of unclaimable periods
// that overlap the incentive window. It is updated whenever an unclaimable
// period closes and is backfilled once from the historical unclaimable
// periods tree after an upgrade.
//
// Returns:
//   - seconds: Accumulated seconds of unclaimable periods overlapping the incentive window.
func (e *ExternalIncentive) UnclaimableSeconds() int64 {
	return e.unclaimableSeconds
}

// SetUnclaimableSeconds sets the accumulated unclaimable seconds.
//
// Parameters:
//   - unclaimableSeconds: Overlapping unclaimable duration in seconds to store.
func (e *ExternalIncentive) SetUnclaimableSeconds(unclaimableSeconds int64) {
	e.unclaimableSeconds = unclaimableSeconds
}

// Clone returns an independent ExternalIncentive value with scalar fields copied and its fixed-point rate duplicated.
//
// Returns:
//   - incentive: Copied external incentive record; its fixed-point rate is cloned when present and otherwise initialized to zero.
func (e *ExternalIncentive) Clone() *ExternalIncentive {
	rewardPerSecondX128 := u256.Zero()

	if e.rewardPerSecondX128 != nil {
		rewardPerSecondX128 = e.rewardPerSecondX128.Clone()
	}

	return &ExternalIncentive{
		incentiveId:              e.incentiveId,
		startTimestamp:           e.startTimestamp,
		endTimestamp:             e.endTimestamp,
		createdHeight:            e.createdHeight,
		createdTimestamp:         e.createdTimestamp,
		depositGnsAmount:         e.depositGnsAmount,
		targetPoolPath:           e.targetPoolPath,
		rewardToken:              e.rewardToken,
		totalRewardAmount:        e.totalRewardAmount,
		rewardAmount:             e.rewardAmount,
		rewardPerSecondX128:      rewardPerSecondX128,
		creator:                  e.creator,
		refunded:                 e.refunded,
		unclaimableSeconds:       e.unclaimableSeconds,
		distributedRewardAmount:  e.distributedRewardAmount,
		accumulatedPenaltyAmount: e.accumulatedPenaltyAmount,
	}
}

// NewExternalIncentive creates a new external incentive
//
// Parameters:
//   - incentiveId: Unique identifier assigned to the external incentive.
//   - targetPoolPath: Pool path whose staked positions may receive this incentive.
//   - rewardToken: Token path of the asset deposited for distribution.
//   - rewardAmount: Total reward amount, also used as the initial remaining reward balance.
//   - startTimestamp: Unix timestamp in seconds when reward distribution starts.
//   - endTimestamp: Unix timestamp in seconds when reward distribution ends; duration is endTimestamp-startTimestamp and must be nonzero for the rate calculation.
//   - creator: Address that funds the incentive and receives refunds at finalization.
//   - depositGnsAmount: GNS amount deposited as the incentive's required collateral.
//   - createdHeight: Block height to record for incentive creation.
//   - currentTime: Unix timestamp in seconds recorded as the incentive creation time.
//
// Returns:
//   - incentive: New incentive with a Q128-scaled per-second rate and zeroed distribution, penalty, and unclaimable counters.
func NewExternalIncentive(
	incentiveId string,
	targetPoolPath string,
	rewardToken string,
	rewardAmount int64,
	startTimestamp int64, // timestamp is in unix time(seconds)
	endTimestamp int64,
	creator address,
	depositGnsAmount int64,
	createdHeight int64,
	currentTime int64, // current time in unix time(seconds)
) *ExternalIncentive {
	incentiveDuration := endTimestamp - startTimestamp

	// Compute reward per second scaled by 2^128 to preserve sub-second precision.
	// rewardPerSecondX128 = (rewardAmount << 128) / incentiveDuration.
	// Consumers must divide by 2^128 when materializing back to a plain integer.
	rewardPerSecondX128 := u256.MulDiv(
		u256.NewUintFromInt64(rewardAmount),
		consts.Q128(),
		u256.NewUintFromInt64(incentiveDuration),
	)

	return &ExternalIncentive{
		incentiveId:              incentiveId,
		targetPoolPath:           targetPoolPath,
		rewardToken:              rewardToken,
		totalRewardAmount:        rewardAmount,
		rewardAmount:             rewardAmount,
		startTimestamp:           startTimestamp,
		endTimestamp:             endTimestamp,
		rewardPerSecondX128:      rewardPerSecondX128,
		distributedRewardAmount:  0,
		accumulatedPenaltyAmount: 0,
		creator:                  creator,
		createdHeight:            createdHeight,
		createdTimestamp:         currentTime,
		depositGnsAmount:         depositGnsAmount,
		refunded:                 false,
		unclaimableSeconds:       0,
	}
}

// Tick mapping for each pool
type Ticks struct {
	tree *bptree.BPTree // int32 tickId -> tick
}

// Ticks Getter/Setter methods

// Tree returns the ticks tree
//
// Returns:
//   - tree: Mutable B+ tree mapping encoded int32 tick IDs to Tick records.
func (t *Ticks) Tree() *bptree.BPTree {
	return t.tree
}

// SetTree sets the ticks tree
//
// Parameters:
//   - tree: B+ tree to use for tick storage.
func (t *Ticks) SetTree(tree *bptree.BPTree) {
	t.tree = tree
}

// Get returns the tick for the given tickId, or nil if it does not exist.
//
// Parameters:
//   - tickId: Tick index to look up.
//
// Returns:
//   - tick: Matching Tick record, or nil when the encoded ID is absent; panics if a stored value has the wrong type.
func (t *Ticks) Get(tickId int32) *Tick {
	v := t.tree.Get(utils.EncodeInt32(tickId))
	if v == nil {
		return nil
	}

	tick, ok := v.(*Tick)
	if !ok {
		panic("failed to cast value to *Tick")
	}
	return tick
}

// Has reports whether a tick ID is present in the underlying tree.
//
// Parameters:
//   - tickId: Tick index whose encoded key is tested.
//
// Returns:
//   - present: True when the encoded tick ID exists in the underlying tree.
func (self *Ticks) Has(tickId int32) bool {
	return self.tree.Has(utils.EncodeInt32(tickId))
}

// SetTick sets a tick by ID
//
// Parameters:
//   - tickId: Tick index under which to store the record.
//   - tick: Non-nil Tick record to store; a zero gross staked liquidity removes the tick instead, while nil input panics during the gross-liquidity check.
func (t *Ticks) SetTick(tickId int32, tick *Tick) {
	if tick.stakedLiquidityGross.IsZero() {
		t.tree.Remove(utils.EncodeInt32(tickId))
		return
	}

	t.tree.Set(utils.EncodeInt32(tickId), tick)
}

// IterateTicks iterates over all ticks
//
// Parameters:
//   - fn: Callback receiving each stored Tick and decoded tick ID; returning true requests that iteration stop.
func (t *Ticks) IterateTicks(fn func(tickId int32, tick *Tick) bool) {
	t.tree.Iterate("", "", func(key string, value interface{}) bool {
		tick, ok := value.(*Tick)
		if !ok {
			return false
		}

		return fn(utils.DecodeInt32(key), tick)
	})
}

// Clone returns a deep copy of ticks.
//
// Returns:
//   - ticks: New Ticks value with cloned Tick records in a fresh fanout-16 tree.
func (t Ticks) Clone() Ticks {
	cloned := bptree.NewBPTreeN(16)
	t.tree.Iterate("", "", func(key string, value any) bool {
		tick, ok := value.(*Tick)
		if !ok {
			panic("failed to cast value to *Tick")
		}
		cloned.Set(key, tick.Clone())
		return false
	})
	return Ticks{tree: cloned}
}

// NewTicks creates an empty tick mapping with a fanout-16 B+ tree.
//
// Returns:
//   - ticks: Empty Ticks value ready to store pool tick records.
func NewTicks() Ticks {
	return Ticks{
		tree: bptree.NewBPTreeN(16),
	}
}

// Tick represents the state of a specific tick in a pool.
//
// Fields:
// - id (int32): The ID of the tick.
// - stakedLiquidityGross (*u256.Uint): Total gross staked liquidity at this tick.
// - stakedLiquidityDelta (*i256.Int): Net change in staked liquidity at this tick.
// - outsideAccumulation (*UintTree): RewardRatioAccumulation outside the tick.
type Tick struct {
	id int32

	// conceptually equal with Pool.liquidityGross but only for the staked positions
	stakedLiquidityGross *u256.Uint

	// conceptually equal with Pool.liquidityNet but only for the staked positions
	stakedLiquidityDelta *i256.Int

	// currentOutsideAccumulation is the accumulation of the time / TotalStake outside the tick.
	// It is calculated by subtracting the current tick's currentOutsideAccumulation from the global reward ratio accumulation.
	outsideAccumulation *UintTree // timestamp -> fixed 32-byte big-endian string
}

// Tick Getter/Setter methods

// Id returns the tick ID
//
// Returns:
//   - id: Tick index represented by this record.
func (t *Tick) Id() int32 {
	return t.id
}

// SetId sets the tick ID
//
// Parameters:
//   - id: Tick index to store in the record.
func (t *Tick) SetId(id int32) {
	t.id = id
}

// StakedLiquidityGross returns the staked liquidity gross
//
// Returns:
//   - liquidity: Total gross staked liquidity currently associated with this tick.
func (t *Tick) StakedLiquidityGross() *u256.Uint {
	return t.stakedLiquidityGross
}

// SetStakedLiquidityGross sets the staked liquidity gross
//
// Parameters:
//   - stakedLiquidityGross: New total gross staked liquidity; the value is copied before storage.
func (t *Tick) SetStakedLiquidityGross(stakedLiquidityGross *u256.Uint) {
	t.stakedLiquidityGross = u256.Zero().Set(stakedLiquidityGross)
}

// StakedLiquidityDelta returns the staked liquidity delta
//
// Returns:
//   - delta: Net staked liquidity change associated with this tick.
func (t *Tick) StakedLiquidityDelta() *i256.Int {
	return t.stakedLiquidityDelta
}

// SetStakedLiquidityDelta sets the staked liquidity delta
//
// Parameters:
//   - stakedLiquidityDelta: New net staked liquidity delta; the value is copied before storage.
func (t *Tick) SetStakedLiquidityDelta(stakedLiquidityDelta *i256.Int) {
	t.stakedLiquidityDelta = i256.Zero().Set(stakedLiquidityDelta)
}

// OutsideAccumulation returns the outside accumulation tree
//
// Returns:
//   - tree: Historical reward-ratio accumulation observed outside this tick.
func (t *Tick) OutsideAccumulation() *UintTree {
	return t.outsideAccumulation
}

// SetOutsideAccumulation sets the outside accumulation tree
//
// Parameters:
//   - outsideAccumulation: UintTree of outside-accumulation snapshots keyed by Unix timestamp.
func (t *Tick) SetOutsideAccumulation(outsideAccumulation *UintTree) {
	t.outsideAccumulation = outsideAccumulation
}

// SetOutsideAccumulationAt sets the outside accumulation at the timestamp.
// SetOutsideAccumulationAt records the Q128-scaled outside accumulation at a timestamp.
//
// Parameters:
//   - timestamp: Nonnegative Unix timestamp in seconds used as the snapshot key.
//   - acc: Q128-scaled accumulation value encoded into the tree.
func (t *Tick) SetOutsideAccumulationAt(timestamp int64, acc *u256.Uint) {
	t.outsideAccumulation.Set(timestamp, utils.EncodeUint256(acc))
}

// Clone returns a deep copy of the tick.
//
// Returns:
//   - tick: Deep copy of the tick and its outside-accumulation tree, or nil when the receiver is nil.
func (t *Tick) Clone() *Tick {
	if t == nil {
		return nil
	}

	return &Tick{
		id:                   t.id,
		stakedLiquidityGross: t.stakedLiquidityGross.Clone(),
		stakedLiquidityDelta: t.stakedLiquidityDelta.Clone(),
		outsideAccumulation:  t.outsideAccumulation.Clone(),
	}
}

// NewTick creates a tick with zero staked liquidity and an empty fanout-4 outside-accumulation tree.
//
// Parameters:
//   - tickId: Tick index to assign to the new record.
//
// Returns:
//   - tick: Initialized tick record.
func NewTick(tickId int32) *Tick {
	return &Tick{
		id:                   tickId,
		stakedLiquidityGross: u256.Zero(),
		stakedLiquidityDelta: i256.Zero(),
		outsideAccumulation:  NewUintTreeN(4),
	}
}

// 100%, 0%, 0% if no tier2 and tier3
// 80%, 0%, 20% if no tier2
// 70%, 30%, 0% if no tier3
// 50%, 30%, 20% if has tier2 and tier3
type TierRatio struct {
	Tier1 uint64
	Tier2 uint64
	Tier3 uint64
}

// NewTierRatio constructs the reward-share ratio for tiers 1 through 3.
//
// Parameters:
//   - tier1: Tier-1 share scaled by 100 (for example, 70 means 70%).
//   - tier2: Tier-2 share scaled by 100.
//   - tier3: Tier-3 share scaled by 100.
//
// Returns:
//   - ratio: TierRatio containing the supplied scaled shares.
func NewTierRatio(tier1, tier2, tier3 uint64) TierRatio {
	return TierRatio{
		Tier1: tier1,
		Tier2: tier2,
		Tier3: tier3,
	}
}

// Get returns the ratio(scaled up by 100) for the given tier.
//
// Parameters:
//   - tier: Tier number to query; only tiers 1, 2, and 3 are supported.
//
// Returns:
//   - ratio: Requested tier share scaled by 100.
//   - err: Non-nil when tier is not 1, 2, or 3; nil for a supported tier.
func (ratio *TierRatio) Get(tier uint64) (uint64, error) {
	switch tier {
	case 1:
		return ratio.Tier1, nil
	case 2:
		return ratio.Tier2, nil
	case 3:
		return ratio.Tier3, nil
	default:
		return 0, errors.New(ufmt.Sprintf("unsupported tier(%d)", tier))
	}
}

// SwapBatchProcessor processes tick crosses in batch for a swap
// This processor accumulates all tick crosses that occur during a single swap
// and processes them together at the end, reducing redundant calculations
// and state updates that would occur with individual tick processing
type SwapBatchProcessor struct {
	poolPath  string           // The pool path identifier for this swap
	pool      *Pool            // Reference to the pool being swapped in
	crosses   []*SwapTickCross // Accumulated tick crosses during the swap
	timestamp int64            // Timestamp when the swap started
	isActive  bool             // Flag to prevent accumulation after swap ends
}

// PoolPath returns the pool path associated with this swap batch.
//
// Returns:
//   - path: Pool identifier for the swap being processed.
func (s *SwapBatchProcessor) PoolPath() string {
	return s.poolPath
}

// SetPoolPath stores the pool identifier associated with this swap batch.
//
// Parameters:
//   - poolPath: Pool identifier to associate with the swap batch.
func (s *SwapBatchProcessor) SetPoolPath(poolPath string) {
	s.poolPath = poolPath
}

// Pool returns the pool referenced by this swap batch.
//
// Returns:
//   - pool: Pool state used to process the accumulated tick crosses.
func (s *SwapBatchProcessor) Pool() *Pool {
	return s.pool
}

// SetPool replaces the pool reference used by this swap batch.
//
// Parameters:
//   - pool: Pool state to reference while processing tick crosses.
func (s *SwapBatchProcessor) SetPool(pool *Pool) {
	s.pool = pool
}

// Crosses returns the tick crosses accumulated by this batch.
//
// Returns:
//   - crosses: Slice of tick-cross records in the order they were added.
func (s *SwapBatchProcessor) Crosses() []*SwapTickCross {
	return s.crosses
}

// SetCrosses replaces the batch's accumulated tick-cross sequence.
//
// Parameters:
//   - crosses: Tick-cross records to store as the batch's accumulated sequence.
func (s *SwapBatchProcessor) SetCrosses(crosses []*SwapTickCross) {
	s.crosses = crosses
}

// Timestamp returns the Unix timestamp in seconds recorded when the swap started.
//
// Returns:
//   - timestamp: Swap-start timestamp in Unix seconds.
func (s *SwapBatchProcessor) Timestamp() int64 {
	return s.timestamp
}

// SetTimestamp stores the swap-start timestamp for this batch.
//
// Parameters:
//   - timestamp: Unix timestamp in seconds to record for the swap batch.
func (s *SwapBatchProcessor) SetTimestamp(timestamp int64) {
	s.timestamp = timestamp
}

// IsActive reports the processor's stored active flag.
//
// Returns:
//   - active: True when the batch is marked active for the swap lifecycle.
func (s *SwapBatchProcessor) IsActive() bool {
	return s.isActive
}

// SetIsActive stores the processor's active lifecycle flag.
//
// Parameters:
//   - isActive: Active flag to store for the swap lifecycle.
func (s *SwapBatchProcessor) SetIsActive(isActive bool) {
	s.isActive = isActive
}

// LastCross returns the most recently appended tick cross.
//
// Returns:
//   - cross: Last tick-cross record, or nil when no crosses have been added.
func (s *SwapBatchProcessor) LastCross() *SwapTickCross {
	if len(s.crosses) == 0 {
		return nil
	}

	return s.crosses[len(s.crosses)-1]
}

// AddCross appends a tick-cross record to the batch sequence.
//
// Parameters:
//   - tickCross: Tick-cross record to append.
func (s *SwapBatchProcessor) AddCross(tickCross *SwapTickCross) {
	s.crosses = append(s.crosses, tickCross)
}

// NewSwapBatchProcessor creates an active batch for collecting tick crosses in a pool swap.
//
// Parameters:
//   - poolPath: Pool identifier associated with the swap.
//   - pool: Pool state whose tick crosses are being collected.
//   - timestamp: Unix timestamp in seconds when the swap began.
//
// Returns:
//   - processor: Active processor with an empty cross sequence.
func NewSwapBatchProcessor(poolPath string, pool *Pool, timestamp int64) *SwapBatchProcessor {
	return &SwapBatchProcessor{
		poolPath:  poolPath,
		pool:      pool,
		crosses:   make([]*SwapTickCross, 0),
		timestamp: timestamp,
		isActive:  true,
	}
}

// SwapTickCross stores information about a tick cross during a swap
// This struct is used to accumulate tick cross events during a single swap transaction
// for batch processing to optimize gas usage and computational efficiency
type SwapTickCross struct {
	tickID     int32     // The tick index that was crossed
	zeroForOne bool      // Direction of the swap (true: token0->token1, false: token1->token0)
	delta      *i256.Int // Pre-calculated liquidity delta for this tick cross
}

// TickID returns the index of the crossed tick.
//
// Returns:
//   - tickID: Tick index represented by this cross.
func (s *SwapTickCross) TickID() int32 {
	return s.tickID
}

// ZeroForOne reports the swap direction represented by this cross.
//
// Returns:
//   - zeroForOne: True for token0-to-token1 swaps; false for token1-to-token0 swaps.
func (s *SwapTickCross) ZeroForOne() bool {
	return s.zeroForOne
}

// Delta returns the precomputed net staked-liquidity change for the crossed tick.
//
// Returns:
//   - delta: Signed liquidity delta to apply at the crossed tick.
func (s *SwapTickCross) Delta() *i256.Int {
	return s.delta
}

// NewSwapTickCross creates a tick-cross record for a swap batch.
//
// Parameters:
//   - tickID: Index of the tick crossed during the swap.
//   - zeroForOne: Swap direction; true means token0-to-token1 and false means token1-to-token0.
//   - delta: Precomputed signed staked-liquidity change for this tick cross.
//
// Returns:
//   - cross: Tick-cross record containing the supplied index, direction, and delta.
func NewSwapTickCross(tickID int32, zeroForOne bool, delta *i256.Int) *SwapTickCross {
	return &SwapTickCross{
		tickID:     tickID,
		zeroForOne: zeroForOne,
		delta:      delta,
	}
}
