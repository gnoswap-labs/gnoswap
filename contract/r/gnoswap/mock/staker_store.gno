package mock

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
	sr "gno.land/r/gnoswap/staker"
)

var _ sr.IStakerStore = (*MockStakerStore)(nil)

type MockStakerStore struct {
	depositGnsAmount                 int64
	minimumRewardAmount              int64
	deposits                         *avl.Tree
	externalIncentives               *avl.Tree
	stakers                          *avl.Tree
	totalEmissionSent                int64
	allowedTokens                    []string
	incentiveCounter                 *sr.Counter
	tokenSpecificMinimumRewards      *avl.Tree
	unstakingFee                     int64
	pools                            *avl.Tree
	poolTierMemberships              *avl.Tree
	poolTierRatio                    sr.TierRatio
	poolTierCounts                   [sr.AllTierCount]uint64
	poolTierLastRewardCacheTimestamp int64
	poolTierLastRewardCacheHeight    int64
	poolTierCurrentEmission          int64
	poolTierGetEmission              func() int64
	poolTierGetHalvingBlocksInRange  func(start, end int64) ([]int64, []int64)
	warmupTemplate                   []sr.Warmup
	currentSwapBatch                 *sr.SwapBatchProcessor
}

// DepositGnsAmount
func (s *MockStakerStore) HasDepositGnsAmountStoreKey() bool {
	return s.depositGnsAmount != 0
}

func (s *MockStakerStore) GetDepositGnsAmount() int64 {
	return s.depositGnsAmount
}

func (s *MockStakerStore) SetDepositGnsAmount(amount int64) error {
	s.depositGnsAmount = amount
	return nil
}

// MinimumRewardAmount
func (s *MockStakerStore) HasMinimumRewardAmountStoreKey() bool {
	return s.minimumRewardAmount != 0
}

func (s *MockStakerStore) GetMinimumRewardAmount() int64 {
	return s.minimumRewardAmount
}

func (s *MockStakerStore) SetMinimumRewardAmount(amount int64) error {
	s.minimumRewardAmount = amount
	return nil
}

// Deposits
func (s *MockStakerStore) HasDepositsStoreKey() bool {
	return s.deposits != nil
}

func (s *MockStakerStore) GetDeposits() *avl.Tree {
	return s.deposits
}

func (s *MockStakerStore) SetDeposits(deposits *avl.Tree) error {
	s.deposits = deposits
	return nil
}

// ExternalIncentives
func (s *MockStakerStore) HasExternalIncentivesStoreKey() bool {
	return s.externalIncentives != nil
}

func (s *MockStakerStore) GetExternalIncentives() *avl.Tree {
	return s.externalIncentives
}

func (s *MockStakerStore) SetExternalIncentives(incentives *avl.Tree) error {
	s.externalIncentives = incentives
	return nil
}

// Stakers
func (s *MockStakerStore) HasStakersStoreKey() bool {
	return s.stakers != nil
}

func (s *MockStakerStore) GetStakers() *avl.Tree {
	return s.stakers
}

func (s *MockStakerStore) SetStakers(stakers *avl.Tree) error {
	s.stakers = stakers
	return nil
}

// TotalEmissionSent
func (s *MockStakerStore) HasTotalEmissionSentStoreKey() bool {
	return s.totalEmissionSent != 0
}

func (s *MockStakerStore) GetTotalEmissionSent() int64 {
	return s.totalEmissionSent
}
func (s *MockStakerStore) SetTotalEmissionSent(amount int64) error {
	s.totalEmissionSent = amount
	return nil
}

// AllowedTokens
func (s *MockStakerStore) HasAllowedTokensStoreKey() bool {
	return s.allowedTokens != nil
}

func (s *MockStakerStore) GetAllowedTokens() []string {
	return s.allowedTokens
}

func (s *MockStakerStore) SetAllowedTokens(tokens []string) error {
	s.allowedTokens = tokens
	return nil
}

// IncentiveCounter
func (s *MockStakerStore) HasIncentiveCounterStoreKey() bool {
	return s.incentiveCounter != nil
}

func (s *MockStakerStore) GetIncentiveCounter() *sr.Counter {
	return s.incentiveCounter
}

func (s *MockStakerStore) SetIncentiveCounter(counter *sr.Counter) error {
	s.incentiveCounter = counter
	return nil
}

func (s *MockStakerStore) NextIncentiveID(addr address, timestamp int64) string {
	id := s.incentiveCounter.Next()
	return ufmt.Sprintf("%s:%d:%s", addr, timestamp, id)
}

// TokenSpecificMinimumRewards
func (s *MockStakerStore) HasTokenSpecificMinimumRewardsStoreKey() bool {
	return s.tokenSpecificMinimumRewards != nil
}

func (s *MockStakerStore) GetTokenSpecificMinimumRewards() *avl.Tree {
	return s.tokenSpecificMinimumRewards
}

func (s *MockStakerStore) SetTokenSpecificMinimumRewards(rewards *avl.Tree) error {
	s.tokenSpecificMinimumRewards = rewards
	return nil
}

// UnstakingFee
func (s *MockStakerStore) HasUnstakingFeeStoreKey() bool {
	return s.unstakingFee != 0
}

func (s *MockStakerStore) GetUnstakingFee() int64 {
	return s.unstakingFee
}

func (s *MockStakerStore) SetUnstakingFee(fee int64) error {
	s.unstakingFee = fee
	return nil
}

// Pools
func (s *MockStakerStore) HasPoolsStoreKey() bool {
	return s.pools != nil
}

func (s *MockStakerStore) GetPools() *avl.Tree {
	return s.pools
}

func (s *MockStakerStore) SetPools(pools *avl.Tree) error {
	s.pools = pools
	return nil
}

// PoolTierMemberships
func (s *MockStakerStore) HasPoolTierMembershipsStoreKey() bool {
	return s.poolTierMemberships != nil
}

func (s *MockStakerStore) GetPoolTierMemberships() *avl.Tree {
	return s.poolTierMemberships
}

func (s *MockStakerStore) SetPoolTierMemberships(memberships *avl.Tree) error {
	s.poolTierMemberships = memberships
	return nil
}

// PoolTierRatio
func (s *MockStakerStore) HasPoolTierRatioStoreKey() bool {
	return true
}

func (s *MockStakerStore) GetPoolTierRatio() sr.TierRatio {
	return s.poolTierRatio
}

func (s *MockStakerStore) SetPoolTierRatio(ratio sr.TierRatio) error {
	s.poolTierRatio = ratio
	return nil
}

// PoolTierCounts
func (s *MockStakerStore) HasPoolTierCountsStoreKey() bool {
	return s.poolTierCounts != [sr.AllTierCount]uint64{}
}

func (s *MockStakerStore) GetPoolTierCounts() [sr.AllTierCount]uint64 {
	return s.poolTierCounts
}

func (s *MockStakerStore) SetPoolTierCounts(counts [sr.AllTierCount]uint64) error {
	s.poolTierCounts = counts
	return nil
}

// PoolTierLastRewardCacheTimestamp
func (s *MockStakerStore) HasPoolTierLastRewardCacheTimestampStoreKey() bool {
	return s.poolTierLastRewardCacheTimestamp != 0
}

func (s *MockStakerStore) GetPoolTierLastRewardCacheTimestamp() int64 {
	return s.poolTierLastRewardCacheTimestamp
}

func (s *MockStakerStore) SetPoolTierLastRewardCacheTimestamp(timestamp int64) error {
	s.poolTierLastRewardCacheTimestamp = timestamp
	return nil
}

// PoolTierLastRewardCacheHeight
func (s *MockStakerStore) HasPoolTierLastRewardCacheHeightStoreKey() bool {
	return s.poolTierLastRewardCacheHeight != 0
}

func (s *MockStakerStore) GetPoolTierLastRewardCacheHeight() int64 {
	return s.poolTierLastRewardCacheHeight
}

func (s *MockStakerStore) SetPoolTierLastRewardCacheHeight(height int64) error {
	s.poolTierLastRewardCacheHeight = height
	return nil
}

// PoolTierCurrentEmission
func (s *MockStakerStore) HasPoolTierCurrentEmissionStoreKey() bool {
	return s.poolTierCurrentEmission != 0
}

func (s *MockStakerStore) GetPoolTierCurrentEmission() int64 {
	return s.poolTierCurrentEmission
}

func (s *MockStakerStore) SetPoolTierCurrentEmission(emission int64) error {
	s.poolTierCurrentEmission = emission
	return nil
}

// PoolTierGetEmission
func (s *MockStakerStore) HasPoolTierGetEmissionStoreKey() bool {
	return s.poolTierGetEmission != nil
}

func (s *MockStakerStore) GetPoolTierGetEmission() func() int64 {
	return s.poolTierGetEmission
}

func (s *MockStakerStore) SetPoolTierGetEmission(fn func() int64) error {
	s.poolTierGetEmission = fn
	return nil
}

// PoolTierGetHalvingBlocksInRange
func (s *MockStakerStore) HasPoolTierGetHalvingBlocksInRangeStoreKey() bool {
	return s.poolTierGetHalvingBlocksInRange != nil
}

func (s *MockStakerStore) GetPoolTierGetHalvingBlocksInRange() func(start, end int64) ([]int64, []int64) {
	return s.poolTierGetHalvingBlocksInRange
}

func (s *MockStakerStore) SetPoolTierGetHalvingBlocksInRange(fn func(start, end int64) ([]int64, []int64)) error {
	s.poolTierGetHalvingBlocksInRange = fn
	return nil
}

// WarmupTemplate
func (s *MockStakerStore) HasWarmupTemplateStoreKey() bool {
	return s.warmupTemplate != nil
}

func (s *MockStakerStore) GetWarmupTemplate() []sr.Warmup {
	return s.warmupTemplate
}

func (s *MockStakerStore) SetWarmupTemplate(warmups []sr.Warmup) error {
	s.warmupTemplate = warmups
	return nil
}

// CurrentSwapBatch
func (s *MockStakerStore) HasCurrentSwapBatchStoreKey() bool {
	return s.currentSwapBatch != nil
}

func (s *MockStakerStore) GetCurrentSwapBatch() *sr.SwapBatchProcessor {
	return s.currentSwapBatch
}

func (s *MockStakerStore) SetCurrentSwapBatch(batch *sr.SwapBatchProcessor) error {
	s.currentSwapBatch = batch
	return nil
}

func NewMockStakerStore() *MockStakerStore {
	return &MockStakerStore{
		depositGnsAmount:            1_000_000_000,
		minimumRewardAmount:         0,
		deposits:                    avl.NewTree(),
		externalIncentives:          avl.NewTree(),
		stakers:                     avl.NewTree(),
		totalEmissionSent:           0,
		allowedTokens:               []string{},
		incentiveCounter:            sr.NewCounter(),
		tokenSpecificMinimumRewards: avl.NewTree(),
		unstakingFee:                0,
		pools:                       avl.NewTree(),
		poolTierMemberships:         avl.NewTree(),
		poolTierRatio: sr.TierRatio{
			Tier1: 0,
			Tier2: 0,
			Tier3: 0,
		},
		poolTierCounts:                   [sr.AllTierCount]uint64{},
		poolTierLastRewardCacheTimestamp: 0,
		poolTierLastRewardCacheHeight:    0,
		poolTierCurrentEmission:          0,
		poolTierGetEmission:              func() int64 { return 0 },
		poolTierGetHalvingBlocksInRange:  func(start, end int64) ([]int64, []int64) { return nil, nil },
		warmupTemplate:                   sr.DefaultWarmupTemplate(),
		currentSwapBatch:                 &sr.SwapBatchProcessor{},
	}
}
