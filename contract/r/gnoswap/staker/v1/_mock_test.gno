package v1

import (
	"testing"

	"gno.land/p/demo/tokens/grc721"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/pool"
	sr "gno.land/r/gnoswap/staker"
)

type MockStakerStore struct {
	depositGnsAmount                 int64
	minimumRewardAmount              int64
	deposits                         *bptree.BPTree
	externalIncentives               *bptree.BPTree
	totalEmissionSent                int64
	allowedTokens                    []string
	incentiveCounter                 *sr.Counter
	tokenSpecificMinimumRewards      map[string]int64
	unstakingFee                     uint64
	pendingProtocolFees              map[string]int64
	pools                            *bptree.BPTree
	poolTierMemberships              *bptree.BPTree
	poolTierRatio                    sr.TierRatio
	poolTierCounts                   [sr.AllTierCount]uint64
	poolTierLastRewardCacheTimestamp int64
	poolTierCurrentEmission          int64
	poolTierGetEmission              func() int64
	poolTierGetHalvingBlocksInRange  func(start, end int64) ([]int64, []int64)
	warmupTemplate                   []sr.Warmup
	currentSwapBatch                 *sr.SwapBatchProcessor
	externalIncentivesByCreationTime *sr.UintTree
}

// DepositGnsAmount
func (s *MockStakerStore) HasDepositGnsAmountStoreKey() bool {
	return s.depositGnsAmount != 0
}

func (s *MockStakerStore) GetDepositGnsAmount() int64 {
	return s.depositGnsAmount
}

func (s *MockStakerStore) SetDepositGnsAmount(_ int, rlm realm, amount int64) error {
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

func (s *MockStakerStore) SetMinimumRewardAmount(_ int, rlm realm, amount int64) error {
	s.minimumRewardAmount = amount
	return nil
}

// Deposits
func (s *MockStakerStore) HasDepositsStoreKey() bool {
	return s.deposits != nil
}

func (s *MockStakerStore) GetDeposits() *bptree.BPTree {
	return s.deposits
}

func (s *MockStakerStore) SetDeposits(_ int, rlm realm, deposits *bptree.BPTree) error {
	s.deposits = deposits
	return nil
}

// ExternalIncentives
func (s *MockStakerStore) HasExternalIncentivesStoreKey() bool {
	return s.externalIncentives != nil
}

func (s *MockStakerStore) GetExternalIncentives() *bptree.BPTree {
	return s.externalIncentives
}

func (s *MockStakerStore) SetExternalIncentives(_ int, rlm realm, incentives *bptree.BPTree) error {
	s.externalIncentives = incentives
	return nil
}

// TotalEmissionSent
func (s *MockStakerStore) HasTotalEmissionSentStoreKey() bool {
	return s.totalEmissionSent != 0
}

func (s *MockStakerStore) GetTotalEmissionSent() int64 {
	return s.totalEmissionSent
}

func (s *MockStakerStore) SetTotalEmissionSent(_ int, rlm realm, amount int64) error {
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

func (s *MockStakerStore) SetAllowedTokens(_ int, rlm realm, tokens []string) error {
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

func (s *MockStakerStore) SetIncentiveCounter(_ int, rlm realm, counter *sr.Counter) error {
	s.incentiveCounter = counter
	return nil
}

func (s *MockStakerStore) NextIncentiveID(addr address, timestamp int64) string {
	id := s.incentiveCounter.Next()
	return ufmt.Sprintf("%s:%d:%d", addr, timestamp, id)
}

// TokenSpecificMinimumRewards
func (s *MockStakerStore) HasTokenSpecificMinimumRewardsStoreKey() bool {
	return s.tokenSpecificMinimumRewards != nil
}

func (s *MockStakerStore) GetTokenSpecificMinimumRewards() map[string]int64 {
	return s.tokenSpecificMinimumRewards
}

func (s *MockStakerStore) SetTokenSpecificMinimumRewards(_ int, rlm realm, rewards map[string]int64) error {
	s.tokenSpecificMinimumRewards = rewards
	return nil
}

func (s *MockStakerStore) SetTokenSpecificMinimumRewardItem(_ int, rlm realm, tokenPath string, amount int64) error {
	if s.tokenSpecificMinimumRewards == nil {
		s.tokenSpecificMinimumRewards = make(map[string]int64)
	}
	s.tokenSpecificMinimumRewards[tokenPath] = amount
	return nil
}

func (s *MockStakerStore) RemoveTokenSpecificMinimumRewardItem(_ int, rlm realm, tokenPath string) error {
	delete(s.tokenSpecificMinimumRewards, tokenPath)
	return nil
}

// UnstakingFee
func (s *MockStakerStore) HasUnstakingFeeStoreKey() bool {
	return s.unstakingFee != 0
}

func (s *MockStakerStore) GetUnstakingFee() uint64 {
	return s.unstakingFee
}

func (s *MockStakerStore) SetUnstakingFee(_ int, rlm realm, fee uint64) error {
	s.unstakingFee = fee
	return nil
}

func (s *MockStakerStore) HasPendingProtocolFeesStoreKey() bool {
	return s.pendingProtocolFees != nil
}

func (s *MockStakerStore) GetPendingProtocolFees() map[string]int64 {
	return s.pendingProtocolFees
}

func (s *MockStakerStore) SetPendingProtocolFees(_ int, rlm realm, fees map[string]int64) error {
	s.pendingProtocolFees = fees
	return nil
}

// Pools
func (s *MockStakerStore) HasPoolsStoreKey() bool {
	return s.pools != nil
}

func (s *MockStakerStore) GetPools() *bptree.BPTree {
	return s.pools
}

func (s *MockStakerStore) SetPools(_ int, rlm realm, pools *bptree.BPTree) error {
	s.pools = pools
	return nil
}

// PoolTierMemberships
func (s *MockStakerStore) HasPoolTierMembershipsStoreKey() bool {
	return s.poolTierMemberships != nil
}

func (s *MockStakerStore) GetPoolTierMemberships() *bptree.BPTree {
	return s.poolTierMemberships
}

func (s *MockStakerStore) SetPoolTierMemberships(_ int, rlm realm, memberships *bptree.BPTree) error {
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

func (s *MockStakerStore) SetPoolTierRatio(_ int, rlm realm, ratio sr.TierRatio) error {
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

func (s *MockStakerStore) SetPoolTierCounts(_ int, rlm realm, counts [sr.AllTierCount]uint64) error {
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

func (s *MockStakerStore) SetPoolTierLastRewardCacheTimestamp(_ int, rlm realm, timestamp int64) error {
	s.poolTierLastRewardCacheTimestamp = timestamp
	return nil
}

// PoolTierCurrentEmission
func (s *MockStakerStore) HasPoolTierCurrentEmissionStoreKey() bool {
	return s.poolTierCurrentEmission != 0
}

func (s *MockStakerStore) GetPoolTierCurrentEmission() int64 {
	return s.poolTierCurrentEmission
}

func (s *MockStakerStore) SetPoolTierCurrentEmission(_ int, rlm realm, emission int64) error {
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

func (s *MockStakerStore) SetPoolTierGetEmission(_ int, rlm realm, fn func() int64) error {
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

func (s *MockStakerStore) SetPoolTierGetHalvingBlocksInRange(_ int, rlm realm, fn func(start, end int64) ([]int64, []int64)) error {
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

func (s *MockStakerStore) SetWarmupTemplate(_ int, rlm realm, warmups []sr.Warmup) error {
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

func (s *MockStakerStore) SetCurrentSwapBatch(_ int, rlm realm, batch *sr.SwapBatchProcessor) error {
	s.currentSwapBatch = batch
	return nil
}

// ExternalIncentivesByCreationTime
func (s *MockStakerStore) HasExternalIncentivesByCreationTimeStoreKey() bool {
	return s.externalIncentivesByCreationTime != nil
}

func (s *MockStakerStore) GetExternalIncentivesByCreationTime() *sr.UintTree {
	return s.externalIncentivesByCreationTime
}

func (s *MockStakerStore) SetExternalIncentivesByCreationTime(_ int, rlm realm, tree *sr.UintTree) error {
	s.externalIncentivesByCreationTime = tree
	return nil
}

func newMockStakerStore() *MockStakerStore {
	swapBatch := sr.NewSwapBatchProcessor("", nil, 0)
	swapBatch.SetIsActive(false)
	return &MockStakerStore{
		depositGnsAmount:                 1_000_000_000,
		minimumRewardAmount:              1_000_000_000,
		deposits:                         sr.NewBPTreeN(16),
		externalIncentives:               sr.NewBPTreeN(16),
		totalEmissionSent:                0,
		allowedTokens:                    []string{"ugnot", "gno.land/r/gnoswap/gns"},
		incentiveCounter:                 sr.NewCounter(),
		tokenSpecificMinimumRewards:      make(map[string]int64),
		unstakingFee:                     0,
		pendingProtocolFees:              make(map[string]int64),
		pools:                            sr.NewBPTreeN(16),
		poolTierMemberships:              sr.NewBPTreeN(16),
		poolTierRatio:                    sr.NewTierRatio(0, 0, 0),
		poolTierCounts:                   [sr.AllTierCount]uint64{},
		poolTierLastRewardCacheTimestamp: 0,
		poolTierCurrentEmission:          0,
		poolTierGetEmission:              func() int64 { return 0 },
		poolTierGetHalvingBlocksInRange:  func(start, end int64) ([]int64, []int64) { return nil, nil },
		warmupTemplate:                   sr.DefaultWarmupTemplate(),
		currentSwapBatch:                 swapBatch,
		externalIncentivesByCreationTime: sr.NewUintTree(),
	}
}

type mockPoolAccessor struct{}

func (p *mockPoolAccessor) ExistsPoolPath(poolPath string) bool {
	testing.SetRealm(adminRealm)
	return pool.ExistsPoolPath(poolPath)
}

func (p *mockPoolAccessor) GetSlot0Tick(poolPath string) int32 {
	testing.SetRealm(adminRealm)
	return pool.GetSlot0Tick(poolPath)
}

func (p *mockPoolAccessor) GetSlot0SqrtPriceX96(poolPath string) string {
	testing.SetRealm(adminRealm)
	return pool.GetSlot0SqrtPriceX96(poolPath)
}

func (p *mockPoolAccessor) SetTickCrossHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	if !rlm.IsCurrent() {
		panic(sr.ErrSpoofedRealm)
	}

	pool.SetTickCrossHook(cross(rlm), func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
		hook(0, cur, poolPath, tickId, zeroForOne, timestamp)
	})
}

func (p *mockPoolAccessor) SetSwapStartHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string, timestamp int64)) {
	if !rlm.IsCurrent() {
		panic(sr.ErrSpoofedRealm)
	}

	pool.SetSwapStartHook(cross(rlm), func(cur realm, poolPath string, timestamp int64) {
		hook(0, cur, poolPath, timestamp)
	})
}

func (p *mockPoolAccessor) SetSwapEndHook(_ int, rlm realm, hook func(_ int, rlm realm, poolPath string) error) {
	if !rlm.IsCurrent() {
		panic(sr.ErrSpoofedRealm)
	}

	pool.SetSwapEndHook(cross(rlm), func(cur realm, poolPath string) error {
		return hook(0, cur, poolPath)
	})
}

func newMockPoolAccessor() sr.PoolAccessor {
	return &mockPoolAccessor{}
}

type mockEmissionAccessor struct{}

func (e *mockEmissionAccessor) MintAndDistributeGns(_ int, rlm realm) (int64, bool) {
	if !rlm.IsCurrent() {
		panic(sr.ErrSpoofedRealm)
	}

	return emission.MintAndDistributeGns(cross(rlm))
}

func (e *mockEmissionAccessor) GetStakerEmissionAmountPerSecond() int64 {
	return emission.GetStakerEmissionAmountPerSecond()
}

func (e *mockEmissionAccessor) GetStakerEmissionAmountPerSecondInRange(start, end int64) ([]int64, []int64) {
	return emission.GetStakerEmissionAmountPerSecondInRange(start, end)
}

func (e *mockEmissionAccessor) SetOnDistributionPctChangeCallback(_ int, rlm realm, callback func(_ int, rlm realm, emissionAmountPerSecond int64)) {
	if !rlm.IsCurrent() {
		panic(sr.ErrSpoofedRealm)
	}

	emission.SetOnDistributionPctChangeCallback(cross(rlm), func(cur realm, emissionAmountPerSecond int64) {
		callback(0, cur, emissionAmountPerSecond)
	})
}

func newMockEmissionAccessor() sr.EmissionAccessor {
	return &mockEmissionAccessor{}
}

// Mock NFT Accessor
type mockNFTAccessor struct {
	approved map[grc721.TokenID]map[address]bool
	owners   map[grc721.TokenID]address
}

func (n *mockNFTAccessor) Approve(_ int, rlm realm, approved address, tid grc721.TokenID) error {
	if _, ok := n.approved[tid]; !ok {
		n.approved[tid] = make(map[address]bool)
	}
	n.approved[tid][approved] = true
	return nil
}

func (n *mockNFTAccessor) Mint(_ int, rlm realm, to address, tid grc721.TokenID) grc721.TokenID {
	n.owners[tid] = to
	n.approved[tid] = make(map[address]bool)
	return tid
}

func (n *mockNFTAccessor) Burn(_ int, rlm realm, tid grc721.TokenID) {
	delete(n.owners, tid)
	delete(n.approved, tid)
}

func (n *mockNFTAccessor) TotalSupply() int64 {
	return int64(len(n.owners))
}

func (n *mockNFTAccessor) Exists(tid grc721.TokenID) bool {
	return n.owners[tid] != ""
}

func (n *mockNFTAccessor) OwnerOf(tid grc721.TokenID) (address, error) {
	if _, ok := n.owners[tid]; !ok {
		return "", grc721.ErrCallerIsNotOwner
	}

	return n.owners[tid], nil
}

func (n *mockNFTAccessor) MustOwnerOf(tid grc721.TokenID) address {
	return n.owners[tid]
}

func (n *mockNFTAccessor) TransferFrom(_ int, rlm realm, _ address, to address, tid grc721.TokenID) error {
	n.owners[tid] = to
	return nil
}

func newMockNFTAccessor() *mockNFTAccessor {
	return &mockNFTAccessor{approved: make(map[grc721.TokenID]map[address]bool), owners: make(map[grc721.TokenID]address)}
}
