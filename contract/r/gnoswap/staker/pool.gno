package staker

import (
	"errors"
	"strconv"
	"time"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

const AllTierCount = 4 // 0, 1, 2, 3

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

// RewardCache returns the reward cache tree
func (p *Pool) RewardCache() *UintTree {
	return p.rewardCache
}

// SetRewardCache sets the reward cache tree
func (p *Pool) SetRewardCache(rewardCache *UintTree) {
	p.rewardCache = rewardCache
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

// GlobalRewardRatioAccumulation returns the global reward ratio accumulation tree
func (p *Pool) GlobalRewardRatioAccumulation() *UintTree {
	return p.globalRewardRatioAccumulation
}

// SetGlobalRewardRatioAccumulation sets the global reward ratio accumulation tree
func (p *Pool) SetGlobalRewardRatioAccumulation(globalRewardRatioAccumulation *UintTree) {
	p.globalRewardRatioAccumulation = globalRewardRatioAccumulation
}

// HistoricalTick returns the historical tick tree
func (p *Pool) HistoricalTick() *UintTree {
	return p.historicalTick
}

// SetHistoricalTick sets the historical tick tree
func (p *Pool) SetHistoricalTick(historicalTick *UintTree) {
	p.historicalTick = historicalTick
}

// NewPool creates a new pool with the given poolPath and currentHeight.
func NewPool(poolPath string, currentTime int64) *Pool {
	pool := &Pool{
		poolPath:        poolPath,
		stakedLiquidity: NewUintTree(),
		// lastUnclaimableTime is initialized to 0, which means "tracking not started yet".
		// When the pool receives a tier assignment (or external incentive), `cacheReward` will be called,
		// which will automatically call `startUnclaimablePeriod` if the pool has zero liquidity.
		// This ensures proper unclaimable period tracking from the moment rewards start emitting.
		lastUnclaimableTime:           0,
		unclaimableAcc:                0,
		rewardCache:                   NewUintTree(),
		incentives:                    NewIncentives(poolPath),
		ticks:                         NewTicks(),
		globalRewardRatioAccumulation: NewUintTree(),
		historicalTick:                NewUintTree(),
	}

	pool.GlobalRewardRatioAccumulation().Set(currentTime, u256.Zero())

	// Initialize rewardCache to 0 to ensure `cacheReward` will trigger on first tier assignment
	pool.RewardCache().Set(currentTime, int64(0))
	pool.StakedLiquidity().Set(currentTime, u256.Zero())

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
//   - unclaimablePeriods: Tree storing periods when rewards cannot be claimed
//     Maps start timestamp (key) to end timestamp (value)
//     An end timestamp of 0 indicates an ongoing unclaimable period
//     Used to track intervals when staking rewards are not claimable
type Incentives struct {
	incentives *avl.Tree // (incentiveId) => ExternalIncentive

	targetPoolPath string // The target pool path for this incentive collection

	unclaimablePeriods *UintTree // blockTimestamp -> any
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

// UnclaimablePeriods returns the unclaimable periods tree
func (i *Incentives) UnclaimablePeriods() *UintTree {
	return i.unclaimablePeriods
}

// SetUnclaimablePeriods sets the unclaimable periods tree
func (i *Incentives) SetUnclaimablePeriods(unclaimablePeriods *UintTree) {
	i.unclaimablePeriods = unclaimablePeriods
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
	result := &Incentives{
		targetPoolPath:     targetPoolPath,
		unclaimablePeriods: NewUintTree(),
		incentives:         avl.NewTree(),
	}

	// initial unclaimable period starts, as there cannot be any staked positions yet.
	currentTimestamp := time.Now().Unix()
	result.unclaimablePeriods.Set(currentTimestamp, int64(0))
	return result
}

type ExternalIncentive struct {
	incentiveId             string  // incentive id
	startTimestamp          int64   // start time for external reward
	endTimestamp            int64   // end time for external reward
	createdHeight           int64   // block height when the incentive was created
	depositGnsAmount        int64   // deposited gns amount
	targetPoolPath          string  // external reward target pool path
	rewardToken             string  // external reward token path
	totalRewardAmount       int64   // total reward amount
	rewardAmount            int64   // to be distributed reward amount
	rewardPerSecond         int64   // reward per second
	distributedRewardAmount int64   // distributed reward amount, when un-staked and refunded
	refundee                address // refundee address

	refunded        bool // whether incentive has been refunded (includes GNS deposit and unclaimed rewards)
	isRequestUnwrap bool // whether the original deposit was native GNOT (needs unwrap on refund)
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

// IsRequestUnwrap returns the request unwrap status
func (e *ExternalIncentive) IsRequestUnwrap() bool {
	return e.isRequestUnwrap
}

// SetIsRequestUnwrap sets the request unwrap status
func (e *ExternalIncentive) SetIsRequestUnwrap(isRequestUnwrap bool) {
	e.isRequestUnwrap = isRequestUnwrap
}

func (e *ExternalIncentive) Clone() *ExternalIncentive {
	return &ExternalIncentive{
		incentiveId:             e.incentiveId,
		startTimestamp:          e.startTimestamp,
		endTimestamp:            e.endTimestamp,
		createdHeight:           e.createdHeight,
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
	isRequestUnwrap bool, // whether original deposit was native GNOT
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
		depositGnsAmount:        depositGnsAmount,
		refunded:                false,
		isRequestUnwrap:         isRequestUnwrap,
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
			stakedLiquidityGross: u256.Zero(),
			stakedLiquidityDelta: i256.Zero(),
			outsideAccumulation:  NewUintTree(),
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
	if tick.stakedLiquidityGross.IsZero() {
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

func NewTicks() Ticks {
	return Ticks{
		tree: avl.NewTree(),
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
	outsideAccumulation *UintTree // timestamp -> *u256.Uint
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
	return t.stakedLiquidityGross
}

// SetStakedLiquidityGross sets the staked liquidity gross
func (t *Tick) SetStakedLiquidityGross(stakedLiquidityGross *u256.Uint) {
	t.stakedLiquidityGross = stakedLiquidityGross
}

// StakedLiquidityDelta returns the staked liquidity delta
func (t *Tick) StakedLiquidityDelta() *i256.Int {
	return t.stakedLiquidityDelta
}

// SetStakedLiquidityDelta sets the staked liquidity delta
func (t *Tick) SetStakedLiquidityDelta(stakedLiquidityDelta *i256.Int) {
	t.stakedLiquidityDelta = stakedLiquidityDelta
}

// OutsideAccumulation returns the outside accumulation tree
func (t *Tick) OutsideAccumulation() *UintTree {
	return t.outsideAccumulation
}

// SetOutsideAccumulation sets the outside accumulation tree
func (t *Tick) SetOutsideAccumulation(outsideAccumulation *UintTree) {
	t.outsideAccumulation = outsideAccumulation
}

func NewTick(tickId int32) *Tick {
	return &Tick{
		id:                   tickId,
		stakedLiquidityGross: u256.Zero(),
		stakedLiquidityDelta: i256.Zero(),
		outsideAccumulation:  NewUintTree(),
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
