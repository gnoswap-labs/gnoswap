package protocol_fee

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/protocol_fee"
)

type mockProtocolFeeStore struct {
	devOpsPct            int64
	accuToGovStaker      *bptree.BPTree
	accuToDevOps         *bptree.BPTree
	distributedToGovStakerHistory *bptree.BPTree
	distributedToDevOpsHistory    *bptree.BPTree
	reservedTokens       *bptree.BPTree
	accrualEpoch         int64
	accrualBuckets       map[string]map[int64]int64
	accrualPendingTokens *bptree.BPTree
}

// handle devOpsPct store data
func (s *mockProtocolFeeStore) HasDevOpsPctStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeDevOpsPct(_ int, rlm realm) error {
	s.devOpsPct = 0
	return nil
}

func (s *mockProtocolFeeStore) GetDevOpsPct() int64 {
	return s.devOpsPct
}

func (s *mockProtocolFeeStore) SetDevOpsPct(_ int, rlm realm, pct int64) error {
	s.devOpsPct = pct
	return nil
}

// handle accuToGovStaker store data
func (s *mockProtocolFeeStore) HasAccuToGovStakerStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeAccuToGovStaker(_ int, rlm realm) error {
	s.accuToGovStaker = protocol_fee.NewBPTreeN(16)
	return nil
}

func (s *mockProtocolFeeStore) GetAccuToGovStaker() *bptree.BPTree {
	return s.accuToGovStaker
}

func (s *mockProtocolFeeStore) GetAccuToGovStakerItem(tokenPath string) (int64, bool) {
	result := s.accuToGovStaker.Get(tokenPath)
	if result == nil {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		return 0, false
	}

	return amount, true
}

func (s *mockProtocolFeeStore) SetAccuToGovStakerItem(_ int, rlm realm, tokenPath string, amount int64) error {
	s.accuToGovStaker.Set(tokenPath, amount)

	return nil
}

// handle accuToDevOps store data
func (s *mockProtocolFeeStore) HasAccuToDevOpsStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeAccuToDevOps(_ int, rlm realm) error {
	s.accuToDevOps = protocol_fee.NewBPTreeN(16)
	return nil
}

func (s *mockProtocolFeeStore) GetAccuToDevOps() *bptree.BPTree {
	return s.accuToDevOps
}

func (s *mockProtocolFeeStore) GetAccuToDevOpsItem(tokenPath string) (int64, bool) {
	result := s.accuToDevOps.Get(tokenPath)
	if result == nil {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

func (s *mockProtocolFeeStore) SetAccuToDevOpsItem(_ int, rlm realm, tokenPath string, amount int64) error {
	s.accuToDevOps.Set(tokenPath, amount)

	return nil
}

func (s *mockProtocolFeeStore) HasDistributedToGovStakerHistoryStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeDistributedToGovStakerHistory(_ int, rlm realm) error {
	s.distributedToGovStakerHistory = protocol_fee.NewBPTreeN(16)
	return nil
}

func (s *mockProtocolFeeStore) GetDistributedToGovStakerHistory() *bptree.BPTree {
	return s.distributedToGovStakerHistory
}

func (s *mockProtocolFeeStore) GetDistributedToGovStakerHistoryItem(tokenPath string) (int64, bool) {
	result := s.distributedToGovStakerHistory.Get(tokenPath)
	if result == nil {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

func (s *mockProtocolFeeStore) SetDistributedToGovStakerHistoryItem(_ int, rlm realm, tokenPath string, amount int64) error {
	s.distributedToGovStakerHistory.Set(tokenPath, amount)
	return nil
}

func (s *mockProtocolFeeStore) HasDistributedToDevOpsHistoryStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeDistributedToDevOpsHistory(_ int, rlm realm) error {
	s.distributedToDevOpsHistory = protocol_fee.NewBPTreeN(16)
	return nil
}

func (s *mockProtocolFeeStore) GetDistributedToDevOpsHistory() *bptree.BPTree {
	return s.distributedToDevOpsHistory
}

func (s *mockProtocolFeeStore) GetDistributedToDevOpsHistoryItem(tokenPath string) (int64, bool) {
	result := s.distributedToDevOpsHistory.Get(tokenPath)
	if result == nil {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

func (s *mockProtocolFeeStore) SetDistributedToDevOpsHistoryItem(_ int, rlm realm, tokenPath string, amount int64) error {
	s.distributedToDevOpsHistory.Set(tokenPath, amount)
	return nil
}

// handle reservedTokens store data
func (s *mockProtocolFeeStore) HasReservedTokensStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeReservedTokens(_ int, rlm realm) error {
	s.reservedTokens = protocol_fee.NewBPTreeN(16)
	return nil
}

func (s *mockProtocolFeeStore) GetReservedTokens() []string {
	return mockTreeKeys(s.reservedTokens)
}

func (s *mockProtocolFeeStore) HasReservedToken(tokenPath string) bool {
	return s.reservedTokens.Has(tokenPath)
}

func (s *mockProtocolFeeStore) AddReservedToken(_ int, rlm realm, tokenPath string) error {
	s.reservedTokens.Set(tokenPath, true)
	return nil
}

func (s *mockProtocolFeeStore) RemoveReservedToken(_ int, rlm realm, tokenPath string) error {
	s.reservedTokens.Remove(tokenPath)
	return nil
}

// handle accrualEpoch store data
func (s *mockProtocolFeeStore) HasAccrualEpochStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeAccrualEpoch(_ int, rlm realm) error {
	s.accrualEpoch = 0
	return nil
}

func (s *mockProtocolFeeStore) GetAccrualEpoch() int64 {
	return s.accrualEpoch
}

func (s *mockProtocolFeeStore) SetAccrualEpoch(_ int, rlm realm, accrualEpoch int64) error {
	s.accrualEpoch = accrualEpoch
	return nil
}

// handle accrualBuckets store data
func (s *mockProtocolFeeStore) HasAccrualBucketsStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeAccrualBuckets(_ int, rlm realm) error {
	s.accrualBuckets = map[string]map[int64]int64{}
	return nil
}

func (s *mockProtocolFeeStore) GetAccrualBuckets(tokenPath string, limit int) ([]int64, []int64) {
	epochs := []int64{}
	amounts := []int64{}
	tokenBuckets, ok := s.accrualBuckets[tokenPath]
	if !ok {
		return epochs, amounts
	}

	for epoch := range tokenBuckets {
		epochs = append(epochs, epoch)
	}
	// insertion sort keeps the mock dependency-free
	for i := 1; i < len(epochs); i++ {
		for j := i; j > 0 && epochs[j-1] > epochs[j]; j-- {
			epochs[j-1], epochs[j] = epochs[j], epochs[j-1]
		}
	}
	if limit > 0 && len(epochs) > limit {
		epochs = epochs[:limit]
	}
	for _, epoch := range epochs {
		amounts = append(amounts, tokenBuckets[epoch])
	}

	return epochs, amounts
}

func (s *mockProtocolFeeStore) AddAccrualBucket(_ int, rlm realm, tokenPath string, epoch int64, amount int64) error {
	tokenBuckets, ok := s.accrualBuckets[tokenPath]
	if !ok {
		tokenBuckets = map[int64]int64{}
		s.accrualBuckets[tokenPath] = tokenBuckets
	}
	tokenBuckets[epoch] += amount
	return nil
}

func (s *mockProtocolFeeStore) RemoveAccrualBuckets(_ int, rlm realm, tokenPath string, epochs []int64) error {
	tokenBuckets, ok := s.accrualBuckets[tokenPath]
	if !ok {
		return nil
	}
	for _, epoch := range epochs {
		delete(tokenBuckets, epoch)
	}
	if len(tokenBuckets) == 0 {
		delete(s.accrualBuckets, tokenPath)
	}
	return nil
}

// handle accrualPendingTokens store data
func (s *mockProtocolFeeStore) HasAccrualPendingTokensStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeAccrualPendingTokens(_ int, rlm realm) error {
	s.accrualPendingTokens = protocol_fee.NewBPTreeN(16)
	return nil
}

func (s *mockProtocolFeeStore) GetAccrualPendingTokens() []string {
	return mockTreeKeys(s.accrualPendingTokens)
}

func (s *mockProtocolFeeStore) AddAccrualPendingToken(_ int, rlm realm, tokenPath string) error {
	s.accrualPendingTokens.Set(tokenPath, true)
	return nil
}

func (s *mockProtocolFeeStore) RemoveAccrualPendingToken(_ int, rlm realm, tokenPath string) error {
	s.accrualPendingTokens.Remove(tokenPath)
	return nil
}

func mockTreeKeys(tree *bptree.BPTree) []string {
	keys := []string{}
	tree.Iterate("", "", func(key string, _ any) bool {
		keys = append(keys, key)
		return false
	})
	return keys
}

func newMockProtocolFeeStore() protocol_fee.IProtocolFeeStore {
	return &mockProtocolFeeStore{
		devOpsPct:                     0,
		accuToGovStaker:               protocol_fee.NewBPTreeN(16),
		accuToDevOps:                  protocol_fee.NewBPTreeN(16),
		distributedToGovStakerHistory: protocol_fee.NewBPTreeN(16),
		distributedToDevOpsHistory:    protocol_fee.NewBPTreeN(16),
		reservedTokens:                protocol_fee.NewBPTreeN(16),
		accrualEpoch:                  0,
		accrualBuckets:                map[string]map[int64]int64{},
		accrualPendingTokens:          protocol_fee.NewBPTreeN(16),
	}
}
