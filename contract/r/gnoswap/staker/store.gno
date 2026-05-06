package staker

import (
	"strconv"

	"gno.land/p/gnoswap/store"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeyDepositGnsAmount                 StoreKey = "depositGnsAmount"
	StoreKeyMinimumRewardAmount              StoreKey = "minimumRewardAmount"
	StoreKeyDeposits                         StoreKey = "deposits"
	StoreKeyExternalIncentives               StoreKey = "externalIncentives"
	StoreKeyTotalEmissionSent                StoreKey = "totalEmissionSent"
	StoreKeyAllowedTokens                    StoreKey = "allowedTokens"
	StoreKeyIncentiveCounter                 StoreKey = "incentiveCounter"
	StoreKeyTokenSpecificMinimumRewards      StoreKey = "tokenSpecificMinimumRewards"
	StoreKeyUnstakingFee                     StoreKey = "unstakingFee"
	StoreKeyPools                            StoreKey = "pools"
	StoreKeyPoolTierMemberships              StoreKey = "poolTierMemberships"
	StoreKeyPoolTierRatio                    StoreKey = "poolTierRatio"
	StoreKeyPoolTierCounts                   StoreKey = "poolTierCounts"
	StoreKeyPoolTierLastRewardCacheTimestamp StoreKey = "poolTierLastRewardCacheTimestamp"
	StoreKeyPoolTierCurrentEmission          StoreKey = "poolTierCurrentEmission"
	StoreKeyPoolTierGetEmission              StoreKey = "poolTierGetEmission"
	StoreKeyPoolTierGetHalvingBlocksInRange  StoreKey = "poolTierGetHalvingBlocksInRange"
	StoreKeyWarmupTemplate                   StoreKey = "warmupTemplate"
	StoreKeyCurrentSwapBatch                 StoreKey = "currentSwapBatch"
	StoreKeyExternalIncentivesByCreationTime StoreKey = "externalIncentivesByCreationTime"
)

type stakerStore struct {
	kvStore store.KVStore
}

// DepositGnsAmount
func (s *stakerStore) HasDepositGnsAmountStoreKey() bool {
	return s.kvStore.Has(StoreKeyDepositGnsAmount.String())
}

func (s *stakerStore) GetDepositGnsAmount() int64 {
	result, err := s.kvStore.Get(StoreKeyDepositGnsAmount.String())
	if err != nil {
		panic(err)
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return amount
}

func (s *stakerStore) SetDepositGnsAmount(amount int64) error {
	return s.kvStore.Set(StoreKeyDepositGnsAmount.String(), amount)
}

// MinimumRewardAmount
func (s *stakerStore) HasMinimumRewardAmountStoreKey() bool {
	return s.kvStore.Has(StoreKeyMinimumRewardAmount.String())
}

func (s *stakerStore) GetMinimumRewardAmount() int64 {
	result, err := s.kvStore.Get(StoreKeyMinimumRewardAmount.String())
	if err != nil {
		panic(err)
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return amount
}

func (s *stakerStore) SetMinimumRewardAmount(amount int64) error {
	return s.kvStore.Set(StoreKeyMinimumRewardAmount.String(), amount)
}

// Deposits
func (s *stakerStore) HasDepositsStoreKey() bool {
	return s.kvStore.Has(StoreKeyDeposits.String())
}

func (s *stakerStore) GetDeposits() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyDeposits.String())
	if err != nil {
		panic(err)
	}

	deposits, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return deposits
}

func (s *stakerStore) SetDeposits(deposits *bptree.BPTree) error {
	return s.kvStore.Set(StoreKeyDeposits.String(), deposits)
}

// ExternalIncentives
func (s *stakerStore) HasExternalIncentivesStoreKey() bool {
	return s.kvStore.Has(StoreKeyExternalIncentives.String())
}

func (s *stakerStore) GetExternalIncentives() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyExternalIncentives.String())
	if err != nil {
		panic(err)
	}

	incentives, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return incentives
}

func (s *stakerStore) SetExternalIncentives(incentives *bptree.BPTree) error {
	return s.kvStore.Set(StoreKeyExternalIncentives.String(), incentives)
}

// TotalEmissionSent
func (s *stakerStore) HasTotalEmissionSentStoreKey() bool {
	return s.kvStore.Has(StoreKeyTotalEmissionSent.String())
}

func (s *stakerStore) GetTotalEmissionSent() int64 {
	result, err := s.kvStore.Get(StoreKeyTotalEmissionSent.String())
	if err != nil {
		panic(err)
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return amount
}

func (s *stakerStore) SetTotalEmissionSent(amount int64) error {
	return s.kvStore.Set(StoreKeyTotalEmissionSent.String(), amount)
}

// AllowedTokens
func (s *stakerStore) HasAllowedTokensStoreKey() bool {
	return s.kvStore.Has(StoreKeyAllowedTokens.String())
}

func (s *stakerStore) GetAllowedTokens() []string {
	result, err := s.kvStore.Get(StoreKeyAllowedTokens.String())
	if err != nil {
		panic(err)
	}

	tokens, ok := result.([]string)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to []string: %T", result))
	}

	return tokens
}

func (s *stakerStore) SetAllowedTokens(tokens []string) error {
	return s.kvStore.Set(StoreKeyAllowedTokens.String(), tokens)
}

// IncentiveCounter
func (s *stakerStore) HasIncentiveCounterStoreKey() bool {
	return s.kvStore.Has(StoreKeyIncentiveCounter.String())
}

func (s *stakerStore) GetIncentiveCounter() *Counter {
	result, err := s.kvStore.Get(StoreKeyIncentiveCounter.String())
	if err != nil {
		panic(err)
	}

	counter, ok := result.(*Counter)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *Counter: %T", result))
	}

	return counter
}

func (s *stakerStore) SetIncentiveCounter(counter *Counter) error {
	return s.kvStore.Set(StoreKeyIncentiveCounter.String(), counter)
}

func (s *stakerStore) NextIncentiveID(creator address, timestamp int64) string {
	counter := s.GetIncentiveCounter()
	return makeIncentiveID(creator, timestamp, counter.Next())
}

// TokenSpecificMinimumRewards
func (s *stakerStore) HasTokenSpecificMinimumRewardsStoreKey() bool {
	return s.kvStore.Has(StoreKeyTokenSpecificMinimumRewards.String())
}

func (s *stakerStore) GetTokenSpecificMinimumRewards() map[string]int64 {
	result, err := s.kvStore.Get(StoreKeyTokenSpecificMinimumRewards.String())
	if err != nil {
		panic(err)
	}

	rewards, ok := result.(map[string]int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to map[string]int64: %T", result))
	}

	return rewards
}

func (s *stakerStore) SetTokenSpecificMinimumRewards(rewards map[string]int64) error {
	return s.kvStore.Set(StoreKeyTokenSpecificMinimumRewards.String(), rewards)
}

// UnstakingFee
func (s *stakerStore) HasUnstakingFeeStoreKey() bool {
	return s.kvStore.Has(StoreKeyUnstakingFee.String())
}

func (s *stakerStore) GetUnstakingFee() uint64 {
	result, err := s.kvStore.Get(StoreKeyUnstakingFee.String())
	if err != nil {
		panic(err)
	}

	fee, ok := result.(uint64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to uint64: %T", result))
	}

	return fee
}

func (s *stakerStore) SetUnstakingFee(fee uint64) error {
	return s.kvStore.Set(StoreKeyUnstakingFee.String(), fee)
}

// Pools
func (s *stakerStore) HasPoolsStoreKey() bool {
	return s.kvStore.Has(StoreKeyPools.String())
}

func (s *stakerStore) GetPools() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyPools.String())
	if err != nil {
		panic(err)
	}

	pools, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return pools
}

func (s *stakerStore) SetPools(pools *bptree.BPTree) error {
	return s.kvStore.Set(StoreKeyPools.String(), pools)
}

// PoolTierMemberships
func (s *stakerStore) HasPoolTierMembershipsStoreKey() bool {
	return s.kvStore.Has(StoreKeyPoolTierMemberships.String())
}

func (s *stakerStore) GetPoolTierMemberships() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyPoolTierMemberships.String())
	if err != nil {
		panic(err)
	}

	memberships, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return memberships
}

func (s *stakerStore) SetPoolTierMemberships(memberships *bptree.BPTree) error {
	return s.kvStore.Set(StoreKeyPoolTierMemberships.String(), memberships)
}

// PoolTierRatio
func (s *stakerStore) HasPoolTierRatioStoreKey() bool {
	return s.kvStore.Has(StoreKeyPoolTierRatio.String())
}

func (s *stakerStore) GetPoolTierRatio() TierRatio {
	result, err := s.kvStore.Get(StoreKeyPoolTierRatio.String())
	if err != nil {
		panic(err)
	}

	ratio, ok := result.(TierRatio)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to TierRatio: %T", result))
	}

	return ratio
}

func (s *stakerStore) SetPoolTierRatio(ratio TierRatio) error {
	return s.kvStore.Set(StoreKeyPoolTierRatio.String(), ratio)
}

// PoolTierCounts
func (s *stakerStore) HasPoolTierCountsStoreKey() bool {
	return s.kvStore.Has(StoreKeyPoolTierCounts.String())
}

func (s *stakerStore) GetPoolTierCounts() [AllTierCount]uint64 {
	result, err := s.kvStore.Get(StoreKeyPoolTierCounts.String())
	if err != nil {
		panic(err)
	}

	counts, ok := result.([AllTierCount]uint64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to [AllTierCount]uint64: %T", result))
	}

	return counts
}

func (s *stakerStore) SetPoolTierCounts(counts [AllTierCount]uint64) error {
	return s.kvStore.Set(StoreKeyPoolTierCounts.String(), counts)
}

// PoolTierLastRewardCacheTimestamp
func (s *stakerStore) HasPoolTierLastRewardCacheTimestampStoreKey() bool {
	return s.kvStore.Has(StoreKeyPoolTierLastRewardCacheTimestamp.String())
}

func (s *stakerStore) GetPoolTierLastRewardCacheTimestamp() int64 {
	result, err := s.kvStore.Get(StoreKeyPoolTierLastRewardCacheTimestamp.String())
	if err != nil {
		panic(err)
	}

	timestamp, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return timestamp
}

func (s *stakerStore) SetPoolTierLastRewardCacheTimestamp(timestamp int64) error {
	return s.kvStore.Set(StoreKeyPoolTierLastRewardCacheTimestamp.String(), timestamp)
}

// PoolTierCurrentEmission
func (s *stakerStore) HasPoolTierCurrentEmissionStoreKey() bool {
	return s.kvStore.Has(StoreKeyPoolTierCurrentEmission.String())
}

func (s *stakerStore) GetPoolTierCurrentEmission() int64 {
	result, err := s.kvStore.Get(StoreKeyPoolTierCurrentEmission.String())
	if err != nil {
		panic(err)
	}

	emission, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return emission
}

func (s *stakerStore) SetPoolTierCurrentEmission(emission int64) error {
	return s.kvStore.Set(StoreKeyPoolTierCurrentEmission.String(), emission)
}

// PoolTierGetEmission
func (s *stakerStore) HasPoolTierGetEmissionStoreKey() bool {
	return s.kvStore.Has(StoreKeyPoolTierGetEmission.String())
}

func (s *stakerStore) GetPoolTierGetEmission() func() int64 {
	result, err := s.kvStore.Get(StoreKeyPoolTierGetEmission.String())
	if err != nil {
		panic(err)
	}

	fn, ok := result.(func() int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to func() int64: %T", result))
	}

	return fn
}

func (s *stakerStore) SetPoolTierGetEmission(fn func() int64) error {
	return s.kvStore.Set(StoreKeyPoolTierGetEmission.String(), fn)
}

// PoolTierGetHalvingBlocksInRange
func (s *stakerStore) HasPoolTierGetHalvingBlocksInRangeStoreKey() bool {
	return s.kvStore.Has(StoreKeyPoolTierGetHalvingBlocksInRange.String())
}

func (s *stakerStore) GetPoolTierGetHalvingBlocksInRange() func(start, end int64) ([]int64, []int64) {
	result, err := s.kvStore.Get(StoreKeyPoolTierGetHalvingBlocksInRange.String())
	if err != nil {
		panic(err)
	}

	fn, ok := result.(func(start, end int64) ([]int64, []int64))
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to func(start, end int64) ([]int64, []int64): %T", result))
	}

	return fn
}

func (s *stakerStore) SetPoolTierGetHalvingBlocksInRange(fn func(start, end int64) ([]int64, []int64)) error {
	return s.kvStore.Set(StoreKeyPoolTierGetHalvingBlocksInRange.String(), fn)
}

func (s *stakerStore) HasWarmupTemplateStoreKey() bool {
	return s.kvStore.Has(StoreKeyWarmupTemplate.String())
}

func (s *stakerStore) GetWarmupTemplate() []Warmup {
	result, err := s.kvStore.Get(StoreKeyWarmupTemplate.String())
	if err != nil {
		panic(err)
	}

	warmups, ok := result.([]Warmup)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to []Warmup: %T", result))
	}

	return warmups
}

func (s *stakerStore) SetWarmupTemplate(warmups []Warmup) error {
	return s.kvStore.Set(StoreKeyWarmupTemplate.String(), warmups)
}

// CurrentSwapBatch
func (s *stakerStore) HasCurrentSwapBatchStoreKey() bool {
	return s.kvStore.Has(StoreKeyCurrentSwapBatch.String())
}

func (s *stakerStore) GetCurrentSwapBatch() *SwapBatchProcessor {
	result, err := s.kvStore.Get(StoreKeyCurrentSwapBatch.String())
	if err != nil {
		panic(err)
	}

	batch, ok := result.(*SwapBatchProcessor)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *SwapBatchProcessor: %T", result))
	}

	return batch
}

func (s *stakerStore) SetCurrentSwapBatch(batch *SwapBatchProcessor) error {
	return s.kvStore.Set(StoreKeyCurrentSwapBatch.String(), batch)
}

// ExternalIncentivesByCreationTime
// key: timestamp -> value: *bptree.BPTree (poolPath -> []string)
func (s *stakerStore) HasExternalIncentivesByCreationTimeStoreKey() bool {
	return s.kvStore.Has(StoreKeyExternalIncentivesByCreationTime.String())
}

func (s *stakerStore) GetExternalIncentivesByCreationTime() *UintTree {
	result, err := s.kvStore.Get(StoreKeyExternalIncentivesByCreationTime.String())
	if err != nil {
		panic(err)
	}

	tree, ok := result.(*UintTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *UintTree: %T", result))
	}

	return tree
}

func (s *stakerStore) SetExternalIncentivesByCreationTime(tree *UintTree) error {
	return s.kvStore.Set(StoreKeyExternalIncentivesByCreationTime.String(), tree)
}

// NewStakerStore creates a new staker store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewStakerStore(kvStore store.KVStore) IStakerStore {
	return &stakerStore{
		kvStore: kvStore,
	}
}

func uint64ToString(id uint64) string {
	return strconv.FormatUint(id, 10)
}

func makeIncentiveID(creator address, timestamp int64, index int64) string {
	return ufmt.Sprintf("%s:%d:%d", creator.String(), timestamp, index)
}
