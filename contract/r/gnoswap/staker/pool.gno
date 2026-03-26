package staker

import (
	"errors"
	"strconv"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	avl "gno.land/p/nt/avl/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

const AllTierCount = 4 // 0, 1, 2, 3

// PoolTimeSeries holds time-series data for a pool that is updated frequently.
// It is stored separately from Pool so that updates to these trees do not dirty
// the Pool object in GnoVM's persistent store, reducing storage writes per tx.
//
// Fields:
//
//   - globalRewardRatioAccumulation:
//     Global ratio of Time / TotalStake accumulation(since the pool creation)
//     Stores new entry only when tick cross or stake/unstake happens.
//     It is used to calculate the reward for a staked position at certain time.
//
//   - rewardCache:
//     The cached per-second reward emitted for this pool.
//     Stores new entry only when the reward is changed.
//     PoolTier.cacheReward() updates this.
//
//   - unclaimablePeriods:
//     Periods when external incentive rewards cannot be claimed (zero staked liquidity).
//     Maps start timestamp -> end timestamp (0 means ongoing).
//     Moved from Incentives to avoid dirtying Pool on every tick cross.
//
//   - tickAccumulations:
//     Per-tick outside accumulation trees, keyed by EncodeInt(tickId).
//     Each value is a *UintTree mapping timestamp -> string (u256.Uint in Q128).
//     Moved from Tick.outsideAccumulation to avoid dirtying Pool on every tick cross.
type PoolTimeSeries struct {
	globalRewardRatioAccumulation *UintTree  // uint64 timestamp -> string (u256.Uint in Q128)
	rewardCache                   *UintTree  // uint64 timestamp -> int64 gnsReward
	unclaimablePeriods            *UintTree  // int64 timestamp -> int64 (0=ongoing, >0=end time)
	tickAccumulations             *avl.Tree  // EncodeInt(int32 tickId) -> *UintTree (timestamp -> string)
}

// GlobalRewardRatioAccumulation returns the global reward ratio accumulation tree
func (ts *PoolTimeSeries) GlobalRewardRatioAccumulation() *UintTree {
	return ts.globalRewardRatioAccumulation
}

// SetGlobalRewardRatioAccumulation sets the global reward ratio accumulation tree
func (ts *PoolTimeSeries) SetGlobalRewardRatioAccumulation(tree *UintTree) {
	ts.globalRewardRatioAccumulation = tree
}

// RewardCache returns the reward cache tree
func (ts *PoolTimeSeries) RewardCache() *UintTree {
	return ts.rewardCache
}

// SetRewardCache sets the reward cache tree
func (ts *PoolTimeSeries) SetRewardCache(tree *UintTree) {
	ts.rewardCache = tree
}

// UnclaimablePeriods returns the unclaimable periods tree.
// Maps start timestamp -> end timestamp (0 means ongoing).
func (ts *PoolTimeSeries) UnclaimablePeriods() *UintTree {
	return ts.unclaimablePeriods
}

// TickAccumulationFor returns the outside accumulation tree for the given tick ID,
// creating a new empty tree if one does not yet exist.
// The returned tree maps int64 timestamp -> string (u256.Uint in Q128).
func (ts *PoolTimeSeries) TickAccumulationFor(tickId int32) *UintTree {
	key := EncodeInt(tickId)
	v, ok := ts.tickAccumulations.Get(key)
	if ok {
		if ut, ok := v.(*UintTree); ok {
			return ut
		}
	}
	ut := NewUintTree()
	ts.tickAccumulations.Set(key, ut)
	return ut
}

// NewPoolTimeSeries creates a new PoolTimeSeries initialized at the given time.
// An initial unclaimable period is recorded because a newly created pool has no
// staked positions yet.
func NewPoolTimeSeries(currentTime int64) *PoolTimeSeries {
	ts := &PoolTimeSeries{
		globalRewardRatioAccumulation: NewUintTree(),
		rewardCache:                   NewUintTree(),
		unclaimablePeriods:            NewUintTree(),
		tickAccumulations:             avl.NewTree(),
	}
	ts.globalRewardRatioAccumulation.Set(currentTime, "0")
	ts.rewardCache.Set(currentTime, int64(0))
	// Initial unclaimable period: no staked positions exist when the pool is first created.
	ts.unclaimablePeriods.Set(currentTime, int64(0))
	return ts
}

// Pool is a struct for storing an incentivized pool information
// Each pool stores Incentives and Ticks associated with it.
//
// Fields:
// - poolPath: The path of the pool.
//
//   - currentStakedLiquidity:
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
//     The accumulated undisributed unclaimable reward.
//     Reset to 0 when processUnclaimableReward is called and sent to community pool.
//
// - incentives: The external incentives associated with the pool.
//
// - ticks: The Ticks associated with the pool.
//
//   - historicalTick:
//     The historical tick for the pool at a given time.
//     It does not reflect the exact tick at the timestamp,
//     but it provides correct ordering for the staked position's ticks.
//     Therefore, you should not compare it for equality, only for ordering.
//     Set when tick cross happens or a new position is created.
//
// Note: globalRewardRatioAccumulation and rewardCache have been moved to
// PoolTimeSeries to avoid dirtying Pool when these time-series are updated.
type Pool struct {
	poolPath string

	stakedLiquidity *UintTree // uint64 timestamp -> string (u256.Uint)

	lastUnclaimableTime int64
	unclaimableAcc      int64

	incentives *Incentives

	ticks Ticks // int32 tickId -> Tick tick

	historicalTick *UintTree // uint64 timestamp -> int32 tickId
}

// Pool Getter/Setter methods

// PoolPath returns the pool path
func (p *Pool) PoolPath() string {
	return p.poolPath
}

// SetPoolPath sets the pool path
func (p *Pool) SetPoolPath(poolPath string) {
	p.poolPath = poolPath
}

// StakedLiquidity returns the staked liquidity tree
func (p *Pool) StakedLiquidity() *UintTree {
	return p.stakedLiquidity
}

// SetStakedLiquidity sets the staked liquidity tree
func (p *Pool) SetStakedLiquidity(stakedLiquidity *UintTree) {
	p.stakedLiquidity = stakedLiquidity
}

// LastUnclaimableTime returns the last unclaimable time
func (p *Pool) LastUnclaimableTime() int64 {
	return p.lastUnclaimableTime
}

// SetLastUnclaimableTime sets the last unclaimable time
func (p *Pool) SetLastUnclaimableTime(lastUnclaimableTime int64) {
	p.lastUnclaimableTime = lastUnclaimableTime
}

// UnclaimableAcc returns the unclaimable accumulation
func (p *Pool) UnclaimableAcc() int64 {
	return p.unclaimableAcc
}

// SetUnclaimableAcc sets the unclaimable accumulation
func (p *Pool) SetUnclaimableAcc(unclaimableAcc int64) {
	p.unclaimableAcc = unclaimableAcc
}

// Incentives returns the incentives
func (p *Pool) Incentives() *Incentives {
	return p.incentives
}

// SetIncentives sets the incentives
func (p *Pool) SetIncentives(incentives *Incentives) {
	p.incentives = incentives
}

// Ticks returns the ticks
func (p *Pool) Ticks() *Ticks {
	return &p.ticks
}

// SetTicks sets the ticks
func (p *Pool) SetTicks(ticks Ticks) {
	p.ticks = ticks
}

// HistoricalTick returns the historical tick tree
func (p *Pool) HistoricalTick() *UintTree {
	return p.historicalTick
}

// SetHistoricalTick sets the historical tick tree
func (p *Pool) SetHistoricalTick(historicalTick *UintTree) {
	p.historicalTick = historicalTick
}

// Clone returns a deep copy of the pool.
func (p *Pool) Clone() *Pool {
	if p == nil {
		return nil
	}

	return &Pool{
		poolPath:            p.poolPath,
		stakedLiquidity:     nil,
		lastUnclaimableTime: p.lastUnclaimableTime,
		unclaimableAcc:      p.unclaimableAcc,
		incentives:          nil,
		ticks:               NewTicks(),
		historicalTick:      nil,
	}
}

// NewPool creates a new pool with the given poolPath and currentHeight.
// The caller must also create a companion PoolTimeSeries via NewPoolTimeSeries(currentTime)
// and store it in the Pools.timeSeries tree.
func NewPool(poolPath string, currentTime int64) *Pool {
	pool := &Pool{
		poolPath: poolPath,
		// lastUnclaimableTime is initialized to 0, which means "tracking not started yet".
		// When the pool receives a tier assignment (or external incentive), `cacheReward` will be called,
		// which will automatically call `startUnclaimablePeriod` if the pool has zero liquidity.
		// This ensures proper unclaimable period tracking from the moment rewards start emitting.
		lastUnclaimableTime: 0,
		unclaimableAcc:      0,
		stakedLiquidity:     NewUintTree(),
		incentives:          NewIncentives(poolPath),
		ticks:               NewTicks(),
		historicalTick:      NewUintTree(),
	}
	pool.StakedLiquidity().Set(currentTime, "0")
	return pool
}

// Incentives represents a collection of external incentives for a specific pool.
//
// Fields:
//
//   - incentives: AVL tree storing ExternalIncentive objects indexed by incentiveId
//     The incentiveId serves as the key to efficiently lookup incentive details
//
//   - targetPoolPath: String identifier for the pool this incentive collection belongs to
//     Used to associate incentives with their corresponding liquidity pool
//
// Note: unclaimablePeriods has been moved to PoolTimeSeries to avoid dirtying
// Pool when these time-series are updated during tick crosses.
type Incentives struct {
	incentives *avl.Tree // (incentiveId) => ExternalIncentive

	targetPoolPath string // The target pool path for this incentive collection
}

// Incentives Getter/Setter methods

// Incentives returns the incentives tree
func (i *Incentives) IncentiveTrees() *avl.Tree {
	return i.incentives
}

// SetIncentives sets the incentives tree
func (i *Incentives) SetIncentives(incentives *avl.Tree) {
	i.incentives = incentives
}

// TargetPoolPath returns the target pool path
func (i *Incentives) TargetPoolPath() string {
	return i.targetPoolPath
}

// SetTargetPoolPath sets the target pool path
func (i *Incentives) SetTargetPoolPath(targetPoolPath string) {
	i.targetPoolPath = targetPoolPath
}

// Incentive returns an incentive by ID
func (i *Incentives) Incentive(incentiveId string) (*ExternalIncentive, bool) {
	value, exists := i.incentives.Get(incentiveId)
	if !exists {
		return nil, false
	}
	incentive, ok := value.(*ExternalIncentive)
	return incentive, ok
}

// SetIncentive sets an incentive by ID
func (i *Incentives) SetIncentive(incentiveId string, incentive *ExternalIncentive) {
	i.incentives.Set(incentiveId, incentive)
}

// IterateIncentives iterates over all incentives
func (i *Incentives) IterateIncentives(fn func(incentiveId string, incentive *ExternalIncentive) bool) {
	i.incentives.Iterate("", "", func(key string, value interface{}) bool {
		if incentive, ok := value.(*ExternalIncentive); ok {
			return fn(key, incentive)
		}
		return false
	})
}

func NewIncentives(targetPoolPath string) *Incentives {
	return &Incentives{
		targetPoolPath: targetPoolPath,
		incentives:     avl.NewTree(),
	}
}

type ExternalIncentive struct {
	incentiveId             string  // incentive id
	startTimestamp          int64   // start time for external reward
	endTimestamp            int64   // end time for external reward
	createdHeight           int64   // block height when the incentive was created
	createdTimestamp        int64   // timestamp when the incentive was created
	depositGnsAmount        int64   // deposited gns amount
	targetPoolPath          string  // external reward target pool path
	rewardToken             string  // external reward token path
	totalRewardAmount       int64   // total reward amount
	rewardAmount            int64   // to be distributed reward amount
	rewardPerSecond         int64   // reward per second
	distributedRewardAmount int64   // distributed reward amount, when un-staked and refunded
	refundee                address // refundee address

	refunded bool // whether incentive has been refunded (includes GNS deposit and unclaimed rewards)
}

// ExternalIncentive Getter/Setter methods

// IncentiveId returns the incentive ID
func (e *ExternalIncentive) IncentiveId() string {
	return e.incentiveId
}

// SetIncentiveId sets the incentive ID
func (e *ExternalIncentive) SetIncentiveId(incentiveId string) {
	e.incentiveId = incentiveId
}

// StartTimestamp returns the start timestamp
func (e *ExternalIncentive) StartTimestamp() int64 {
	return e.startTimestamp
}

// SetStartTimestamp sets the start timestamp
func (e *ExternalIncentive) SetStartTimestamp(startTimestamp int64) {
	e.startTimestamp = startTimestamp
}

// EndTimestamp returns the end timestamp
func (e *ExternalIncentive) EndTimestamp() int64 {
	return e.endTimestamp
}

// SetEndTimestamp sets the end timestamp
func (e *ExternalIncentive) SetEndTimestamp(endTimestamp int64) {
	e.endTimestamp = endTimestamp
}

// CreatedHeight returns the created height
func (e *ExternalIncentive) CreatedHeight() int64 {
	return e.createdHeight
}

// SetCreatedHeight sets the created height
func (e *ExternalIncentive) SetCreatedHeight(createdHeight int64) {
	e.createdHeight = createdHeight
}

// CreatedTimestamp returns the created timestamp
func (e *ExternalIncentive) CreatedTimestamp() int64 {
	return e.createdTimestamp
}

// SetCreatedTimestamp sets the created timestamp
func (e *ExternalIncentive) SetCreatedTimestamp(createdTimestamp int64) {
	e.createdTimestamp = createdTimestamp
}

// DepositGnsAmount returns the deposit GNS amount
func (e *ExternalIncentive) DepositGnsAmount() int64 {
	return e.depositGnsAmount
}

// SetDepositGnsAmount sets the deposit GNS amount
func (e *ExternalIncentive) SetDepositGnsAmount(depositGnsAmount int64) {
	e.depositGnsAmount = depositGnsAmount
}

// TargetPoolPath returns the target pool path
func (e *ExternalIncentive) TargetPoolPath() string {
	return e.targetPoolPath
}

// SetTargetPoolPath sets the target pool path
func (e *ExternalIncentive) SetTargetPoolPath(targetPoolPath string) {
	e.targetPoolPath = targetPoolPath
}

// RewardToken returns the reward token
func (e *ExternalIncentive) RewardToken() string {
	return e.rewardToken
}

// SetRewardToken sets the reward token
func (e *ExternalIncentive) SetRewardToken(rewardToken string) {
	e.rewardToken = rewardToken
}

// TotalRewardAmount returns the total reward amount
func (e *ExternalIncentive) TotalRewardAmount() int64 {
	return e.totalRewardAmount
}

// SetTotalRewardAmount sets the total reward amount
func (e *ExternalIncentive) SetTotalRewardAmount(totalRewardAmount int64) {
	e.totalRewardAmount = totalRewardAmount
}

// RewardAmount returns the reward amount
func (e *ExternalIncentive) RewardAmount() int64 {
	return e.rewardAmount
}

// SetRewardAmount sets the reward amount
func (e *ExternalIncentive) SetRewardAmount(rewardAmount int64) {
	e.rewardAmount = rewardAmount
}

// RewardPerSecond returns the reward per second
func (e *ExternalIncentive) RewardPerSecond() int64 {
	return e.rewardPerSecond
}

// SetRewardPerSecond sets the reward per second
func (e *ExternalIncentive) SetRewardPerSecond(rewardPerSecond int64) {
	e.rewardPerSecond = rewardPerSecond
}

// DistributedRewardAmount returns the distributed reward amount
func (e *ExternalIncentive) DistributedRewardAmount() int64 {
	return e.distributedRewardAmount
}

// SetDistributedRewardAmount sets the distributed reward amount
func (e *ExternalIncentive) SetDistributedRewardAmount(distributedRewardAmount int64) {
	e.distributedRewardAmount = distributedRewardAmount
}

// Refundee returns the refundee address
func (e *ExternalIncentive) Refundee() address {
	return e.refundee
}

// SetRefundee sets the refundee address
func (e *ExternalIncentive) SetRefundee(refundee address) {
	e.refundee = refundee
}

// Refunded returns the refunded status
func (e *ExternalIncentive) Refunded() bool {
	return e.refunded
}

// SetRefunded sets the refunded status
func (e *ExternalIncentive) SetRefunded(refunded bool) {
	e.refunded = refunded
}

func (e *ExternalIncentive) Clone() *ExternalIncentive {
	return &ExternalIncentive{
		incentiveId:             e.incentiveId,
		startTimestamp:          e.startTimestamp,
		endTimestamp:            e.endTimestamp,
		createdHeight:           e.createdHeight,
		createdTimestamp:        e.createdTimestamp,
		depositGnsAmount:        e.depositGnsAmount,
		targetPoolPath:          e.targetPoolPath,
		rewardToken:             e.rewardToken,
		totalRewardAmount:       e.totalRewardAmount,
		rewardAmount:            e.rewardAmount,
		rewardPerSecond:         e.rewardPerSecond,
		refundee:                e.refundee,
		refunded:                e.refunded,
		distributedRewardAmount: e.distributedRewardAmount,
	}
}

// NewExternalIncentive creates a new external incentive
func NewExternalIncentive(
	incentiveId string,
	targetPoolPath string,
	rewardToken string,
	rewardAmount int64,
	startTimestamp int64, // timestamp is in unix time(seconds)
	endTimestamp int64,
	refundee address,
	depositGnsAmount int64,
	createdHeight int64,
	currentTime int64, // current time in unix time(seconds)
) *ExternalIncentive {
	incentiveDuration := endTimestamp - startTimestamp
	rewardPerSecond := rewardAmount / incentiveDuration

	return &ExternalIncentive{
		incentiveId:             incentiveId,
		targetPoolPath:          targetPoolPath,
		rewardToken:             rewardToken,
		totalRewardAmount:       rewardAmount,
		rewardAmount:            rewardAmount,
		startTimestamp:          startTimestamp,
		endTimestamp:            endTimestamp,
		rewardPerSecond:         rewardPerSecond,
		distributedRewardAmount: 0,
		refundee:                refundee,
		createdHeight:           createdHeight,
		createdTimestamp:        currentTime,
		depositGnsAmount:        depositGnsAmount,
		refunded: false,
	}
}

// Tick mapping for each pool
type Ticks struct {
	tree *avl.Tree // int32 tickId -> tick
}

// Ticks Getter/Setter methods

// Tree returns the ticks tree
func (t *Ticks) Tree() *avl.Tree {
	return t.tree
}

// SetTree sets the ticks tree
func (t *Ticks) SetTree(tree *avl.Tree) {
	t.tree = tree
}

func (t *Ticks) Get(tickId int32) *Tick {
	v, ok := t.tree.Get(EncodeInt(tickId))
	if !ok {
		tick := &Tick{
			id:                   tickId,
			stakedLiquidityGross: "0",
			stakedLiquidityDelta: i256.Zero(),
		}
		t.tree.Set(EncodeInt(tickId), tick)
		return tick
	}

	tick, ok := v.(*Tick)
	if !ok {
		panic("failed to cast value to *Tick")
	}
	return tick
}

func (self *Ticks) Has(tickId int32) bool {
	return self.tree.Has(EncodeInt(tickId))
}

// SetTick sets a tick by ID
func (t *Ticks) SetTick(tickId int32, tick *Tick) {
	if tick.StakedLiquidityGross().IsZero() {
		t.tree.Remove(EncodeInt(tickId))
		return
	}

	t.tree.Set(EncodeInt(tickId), tick)
}

// IterateTicks iterates over all ticks
func (t *Ticks) IterateTicks(fn func(tickId int32, tick *Tick) bool) {
	t.tree.Iterate("", "", func(key string, value interface{}) bool {
		tick, ok := value.(*Tick)
		if !ok {
			return false
		}

		// Convert string key back to int32
		tickId, err := strconv.Atoi(key)
		if err != nil {
			return false // skip invalid keys
		}

		return fn(int32(tickId), tick)
	})
}

// Clone returns a deep copy of ticks.
func (t Ticks) Clone() Ticks {
	cloned := avl.NewTree()
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

func NewTicks() Ticks {
	return Ticks{
		tree: avl.NewTree(),
	}
}

// Tick represents the state of a specific tick in a pool.
//
// Fields:
// - id (int32): The ID of the tick.
// - stakedLiquidityGross (string): Total gross staked liquidity at this tick (stored as decimal string, use StakedLiquidityGross() for *u256.Uint).
// - stakedLiquidityDelta (*i256.Int): Net change in staked liquidity at this tick.
//
// Note: outsideAccumulation has been moved to PoolTimeSeries.tickAccumulations to avoid
// dirtying Pool on every tick cross during swap execution.
type Tick struct {
	id int32

	// conceptually equal with Pool.liquidityGross but only for the staked positions
	stakedLiquidityGross string

	// conceptually equal with Pool.liquidityNet but only for the staked positions
	stakedLiquidityDelta *i256.Int
}

// Tick Getter/Setter methods

// Id returns the tick ID
func (t *Tick) Id() int32 {
	return t.id
}

// SetId sets the tick ID
func (t *Tick) SetId(id int32) {
	t.id = id
}

// StakedLiquidityGross returns the staked liquidity gross
func (t *Tick) StakedLiquidityGross() *u256.Uint {
	return u256.MustFromDecimal(t.stakedLiquidityGross)
}

// SetStakedLiquidityGross sets the staked liquidity gross
func (t *Tick) SetStakedLiquidityGross(stakedLiquidityGross *u256.Uint) {
	t.stakedLiquidityGross = stakedLiquidityGross.ToString()
}

// StakedLiquidityDelta returns the staked liquidity delta
func (t *Tick) StakedLiquidityDelta() *i256.Int {
	return t.stakedLiquidityDelta
}

// SetStakedLiquidityDelta sets the staked liquidity delta
func (t *Tick) SetStakedLiquidityDelta(stakedLiquidityDelta *i256.Int) {
	t.stakedLiquidityDelta = stakedLiquidityDelta
}

// Clone returns a deep copy of the tick.
func (t *Tick) Clone() *Tick {
	if t == nil {
		return nil
	}

	return &Tick{
		id:                   t.id,
		stakedLiquidityGross: t.stakedLiquidityGross,
		stakedLiquidityDelta: t.stakedLiquidityDelta.Clone(),
	}
}

func NewTick(tickId int32) *Tick {
	return &Tick{
		id:                   tickId,
		stakedLiquidityGross: "0",
		stakedLiquidityDelta: i256.Zero(),
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

// Get returns the ratio(scaled up by 100) for the given tier.
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

func (s *SwapBatchProcessor) PoolPath() string {
	return s.poolPath
}

func (s *SwapBatchProcessor) SetPoolPath(poolPath string) {
	s.poolPath = poolPath
}

func (s *SwapBatchProcessor) Pool() *Pool {
	return s.pool
}

func (s *SwapBatchProcessor) SetPool(pool *Pool) {
	s.pool = pool
}

func (s *SwapBatchProcessor) Crosses() []*SwapTickCross {
	return s.crosses
}

func (s *SwapBatchProcessor) SetCrosses(crosses []*SwapTickCross) {
	s.crosses = crosses
}

func (s *SwapBatchProcessor) Timestamp() int64 {
	return s.timestamp
}

func (s *SwapBatchProcessor) SetTimestamp(timestamp int64) {
	s.timestamp = timestamp
}

func (s *SwapBatchProcessor) IsActive() bool {
	return s.isActive
}

func (s *SwapBatchProcessor) SetIsActive(isActive bool) {
	s.isActive = isActive
}

func (s *SwapBatchProcessor) LastCross() *SwapTickCross {
	if len(s.crosses) == 0 {
		return nil
	}

	return s.crosses[len(s.crosses)-1]
}

func (s *SwapBatchProcessor) AddCross(tickCross *SwapTickCross) {
	s.crosses = append(s.crosses, tickCross)
}

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

func (s *SwapTickCross) TickID() int32 {
	return s.tickID
}

func (s *SwapTickCross) ZeroForOne() bool {
	return s.zeroForOne
}

func (s *SwapTickCross) Delta() *i256.Int {
	return s.delta
}

func NewSwapTickCross(tickID int32, zeroForOne bool, delta *i256.Int) *SwapTickCross {
	return &SwapTickCross{
		tickID:     tickID,
		zeroForOne: zeroForOne,
		delta:      delta,
	}
}
