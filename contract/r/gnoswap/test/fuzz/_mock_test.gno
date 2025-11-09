package fuzz

import (
	"strconv"
	"testing"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"
	sr "gno.land/r/gnoswap/staker"
)

type mockPoolStore struct {
	pools                *avl.Tree
	feeAmountTickSpacing *avl.Tree
	slot0FeeProtocol     uint8
	poolCreationFee      int64
	withdrawalFeeBPS     uint64
	swapStartHook        func(cur realm, poolPath string, timestamp int64)
	swapEndHook          func(cur realm, poolPath string) error
	tickCrossHook        func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)
}

func (s *mockPoolStore) HasPools() bool {
	return s.pools != nil
}

// GetPools retrieves the AVL tree containing all pool data.
// This is the main data structure that stores all pool instances.
func (s *mockPoolStore) GetPools() *avl.Tree {
	return s.pools
}

// SetPools stores the AVL tree containing all pool data.
func (s *mockPoolStore) SetPools(pools *avl.Tree) error {
	s.pools = pools
	return nil
}

func (s *mockPoolStore) HasFeeAmountTickSpacing() bool {
	return s.feeAmountTickSpacing != nil
}

// GetFeeAmountTickSpacing retrieves the mapping between fee amounts and tick spacing.
// This mapping determines the tick spacing for each supported fee tier.
func (s *mockPoolStore) GetFeeAmountTickSpacing() *avl.Tree {
	return s.feeAmountTickSpacing
}

// SetFeeAmountTickSpacing stores the mapping between fee amounts and tick spacing.
func (s *mockPoolStore) SetFeeAmountTickSpacing(feeAmountTickSpacing *avl.Tree) error {
	s.feeAmountTickSpacing = feeAmountTickSpacing
	return nil
}

func (s *mockPoolStore) HasSlot0FeeProtocol() bool {
	return true
}

// GetSlot0FeeProtocol retrieves the protocol fee percentage for slot0.
func (s *mockPoolStore) GetSlot0FeeProtocol() uint8 {
	return s.slot0FeeProtocol
}

// SetSlot0FeeProtocol stores the protocol fee percentage for slot0.
func (s *mockPoolStore) SetSlot0FeeProtocol(slot0FeeProtocol uint8) error {
	s.slot0FeeProtocol = slot0FeeProtocol
	return nil
}

func (s *mockPoolStore) HasPoolCreationFee() bool {
	return true
}

// GetPoolCreationFee retrieves the pool creation fee amount.
func (s *mockPoolStore) GetPoolCreationFee() int64 {
	return s.poolCreationFee
}

// SetPoolCreationFee stores the pool creation fee amount.
func (s *mockPoolStore) SetPoolCreationFee(poolCreationFee int64) error {
	s.poolCreationFee = poolCreationFee
	return nil
}

func (s *mockPoolStore) HasWithdrawalFeeBPS() bool {
	return true
}

// GetWithdrawalFeeBPS retrieves the withdrawal fee in basis points.
func (s *mockPoolStore) GetWithdrawalFeeBPS() uint64 {
	return s.withdrawalFeeBPS
}

// SetWithdrawalFeeBPS stores the withdrawal fee in basis points.
func (s *mockPoolStore) SetWithdrawalFeeBPS(withdrawalFeeBPS uint64) error {
	s.withdrawalFeeBPS = withdrawalFeeBPS
	return nil
}

// HasSwapStartHook checks if the swap start hook is set.
func (s *mockPoolStore) HasSwapStartHook() bool {
	return s.swapStartHook != nil
}

// GetSwapStartHook retrieves the swap start hook function.
func (s *mockPoolStore) GetSwapStartHook() func(cur realm, poolPath string, timestamp int64) {
	return s.swapStartHook
}

// SetSwapStartHook stores the swap start hook function.
func (s *mockPoolStore) SetSwapStartHook(swapStartHook func(cur realm, poolPath string, timestamp int64)) error {
	s.swapStartHook = swapStartHook
	return nil
}

// HasSwapEndHook checks if the swap end hook is set.
func (s *mockPoolStore) HasSwapEndHook() bool {
	return s.swapEndHook != nil
}

// GetSwapEndHook retrieves the swap end hook function.
func (s *mockPoolStore) GetSwapEndHook() func(cur realm, poolPath string) error {
	return s.swapEndHook
}

// SetSwapEndHook stores the swap end hook function.
func (s *mockPoolStore) SetSwapEndHook(swapEndHook func(cur realm, poolPath string) error) error {
	s.swapEndHook = swapEndHook
	return nil
}

// HasTickCrossHook checks if the tick cross hook is set.
func (s *mockPoolStore) HasTickCrossHook() bool {
	return s.tickCrossHook != nil
}

// GetTickCrossHook retrieves the tick cross hook function.
func (s *mockPoolStore) GetTickCrossHook() func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
	return s.tickCrossHook
}

// SetTickCrossHook stores the tick cross hook function.
func (s *mockPoolStore) SetTickCrossHook(tickCrossHook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) error {
	s.tickCrossHook = tickCrossHook
	return nil
}

func NewMockPoolStoreWithHook(
	swapStartHook func(cur realm, poolPath string, timestamp int64),
	swapEndHook func(cur realm, poolPath string) error,
	tickCrossHook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64),
) *mockPoolStore {
	feeAmountTickSpacing := avl.NewTree()
	feeAmountTickSpacing.Set("100", int32(1))
	feeAmountTickSpacing.Set("500", int32(10))
	feeAmountTickSpacing.Set("3000", int32(60))
	feeAmountTickSpacing.Set("10000", int32(200))

	return &mockPoolStore{
		pools:                avl.NewTree(),
		feeAmountTickSpacing: feeAmountTickSpacing,
		slot0FeeProtocol:     0,
		poolCreationFee:      100_000_000,
		withdrawalFeeBPS:     100,
		swapStartHook:        swapStartHook,
		swapEndHook:          swapEndHook,
		tickCrossHook:        tickCrossHook,
	}
}

// Mock Position Store
type mockPositionStore struct {
	positions *avl.Tree
	nextID    uint64
}

func (s *mockPositionStore) HasPositionsStoreKey() bool {
	return false
}

func (s *mockPositionStore) GetPositions() *avl.Tree {
	return s.positions
}

func (s *mockPositionStore) SetPositions(positions *avl.Tree) error {
	s.positions = positions
	return nil
}

func (s *mockPositionStore) HasPositionNextIDStoreKey() bool {
	return false
}

func (s *mockPositionStore) GetPositionNextID() uint64 {
	return s.nextID
}

func (s *mockPositionStore) SetPositionNextID(nextID uint64) error {
	s.nextID = nextID
	return nil
}

func (s *mockPositionStore) HasPosition(positionId uint64) bool {
	return s.positions.Has(strconv.FormatUint(positionId, 10))
}

func (s *mockPositionStore) GetPosition(positionId uint64) (position.Position, bool) {
	value, exists := s.positions.Get(strconv.FormatUint(positionId, 10))
	if !exists {
		return position.Position{}, false
	}
	return value.(position.Position), true
}

func (s *mockPositionStore) SetPosition(positionId uint64, position position.Position) error {
	s.positions.Set(strconv.FormatUint(positionId, 10), position)
	return nil
}

func (s *mockPositionStore) RemovePosition(positionId uint64) error {
	s.positions.Remove(strconv.FormatUint(positionId, 10))
	return nil
}

// Mock Router Store
type mockRouterStore struct {
	data map[string]any
}

func (r *mockRouterStore) HasSwapFeeKey() bool {
	return r.data[router.StoreKeySwapFee.String()] != nil
}

func (r *mockRouterStore) GetSwapFee() uint64 {
	return r.data[router.StoreKeySwapFee.String()].(uint64)
}

func (r *mockRouterStore) SetSwapFee(fee uint64) error {
	r.data[router.StoreKeySwapFee.String()] = fee
	return nil
}

// Mock NFT Accessor
type mockNFTAccessor struct {
	approved map[grc721.TokenID]map[address]bool
	owners   map[grc721.TokenID]address
}

func (n *mockNFTAccessor) Approve(approved address, tid grc721.TokenID) error {
	n.approved[tid][approved] = true
	return nil
}

func (n *mockNFTAccessor) Mint(to address, tid grc721.TokenID) grc721.TokenID {
	n.owners[tid] = to
	n.approved[tid] = make(map[address]bool)
	return tid
}

func (n *mockNFTAccessor) Burn(tid grc721.TokenID) {
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

func (n *mockNFTAccessor) TransferFrom(_ address, to address, tid grc721.TokenID) error {
	n.owners[tid] = to
	return nil
}

func newMockPoolStore() *mockPoolStore {
	return NewMockPoolStoreWithHook(nil, nil, nil)
}

func newMockPositionStore() *mockPositionStore {
	return &mockPositionStore{positions: avl.NewTree(), nextID: 1}
}

// Initialize Mock Instances
func newMockRouterStore() *mockRouterStore {
	data := make(map[string]any)
	data[router.StoreKeySwapFee.String()] = uint64(15) // 0.15%

	return &mockRouterStore{data: data}
}

func newMockNFTAccessor() *mockNFTAccessor {
	return &mockNFTAccessor{approved: make(map[grc721.TokenID]map[address]bool), owners: make(map[grc721.TokenID]address)}
}

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
	return ufmt.Sprintf("%s:%d:%d", addr, timestamp, id)
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

func newMockStakerStore() *MockStakerStore {
	return &MockStakerStore{
		depositGnsAmount:            0,
		minimumRewardAmount:         1_000_000_000,
		deposits:                    avl.NewTree(),
		externalIncentives:          avl.NewTree(),
		stakers:                     avl.NewTree(),
		totalEmissionSent:           0,
		allowedTokens:               []string{"gnot", "gno.land/r/gnoswap/gns", oblPath},
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

type mockPoolAccessor struct{}

func (p *mockPoolAccessor) ExistsPoolPath(poolPath string) bool {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	return func(cur realm) bool {
		testing.SetRealm(testing.NewUserRealm(adminAddr))
		return pool.ExistsPoolPath(poolPath)
	}(cross)
}

func (p *mockPoolAccessor) GetSlot0Tick(poolPath string) int32 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	return func(cur realm) int32 {
		testing.SetRealm(testing.NewUserRealm(adminAddr))
		return pool.GetSlot0Tick(poolPath)
	}(cross)
}

func (p *mockPoolAccessor) SetTickCrossHook(hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	func(cur realm) {
		pool.SetTickCrossHook(cross, hook)
	}(cross)
}

func (p *mockPoolAccessor) SetSwapStartHook(hook func(cur realm, poolPath string, timestamp int64)) {
	func(cur realm) {
		pool.SetSwapStartHook(cross, hook)
	}(cross)
}

func (p *mockPoolAccessor) SetSwapEndHook(hook func(cur realm, poolPath string) error) {
	func(cur realm) {
		pool.SetSwapEndHook(cross, hook)
	}(cross)
}

func newMockPoolAccessor() sr.PoolAccessor {
	return &mockPoolAccessor{}
}

type mockEmissionAccessor struct{}

func (e *mockEmissionAccessor) MintAndDistributeGns() {
	func(cur realm) {
		emission.MintAndDistributeGns(cross)
	}(cross)
}

func (e *mockEmissionAccessor) GetStakerEmissionAmountPerSecond() int64 {
	return emission.GetStakerEmissionAmountPerSecond()
}

func (e *mockEmissionAccessor) GetStakerEmissionAmountPerSecondInRange(start, end int64) ([]int64, []int64) {
	return emission.GetStakerEmissionAmountPerSecondInRange(start, end)
}

func (e *mockEmissionAccessor) SetOnDistributionPctChangeCallback(callback func(emissionAmountPerSecond int64)) {
	func(cur realm) {
		emission.SetOnDistributionPctChangeCallback(cross, callback)
	}(cross)
}

func newMockEmissionAccessor() sr.EmissionAccessor {
	return &mockEmissionAccessor{}
}
