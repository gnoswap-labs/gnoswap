package v1

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/protocol_fee"
)

type mockProtocolFeeStore struct {
	devOpsPct                     int64
	accuToGovStaker               *avl.Tree
	accuToDevOps                  *avl.Tree
	distributedToGovStakerHistory *avl.Tree
	distributedToDevOpsHistory    *avl.Tree
	tokenListWithAmounts          map[string]int64
}

// handle devOpsPct store data
func (s *mockProtocolFeeStore) HasDevOpsPctStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeDevOpsPct() error {
	s.devOpsPct = 0
	return nil
}

func (s *mockProtocolFeeStore) GetDevOpsPct() int64 {
	return s.devOpsPct
}

func (s *mockProtocolFeeStore) SetDevOpsPct(pct int64) error {
	s.devOpsPct = pct
	return nil
}

// handle accuToGovStaker store data
func (s *mockProtocolFeeStore) HasAccuToGovStakerStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeAccuToGovStaker() error {
	s.accuToGovStaker = avl.NewTree()
	return nil
}

func (s *mockProtocolFeeStore) GetAccuToGovStaker() *avl.Tree {
	return s.accuToGovStaker
}

func (s *mockProtocolFeeStore) GetAccuToGovStakerItem(tokenPath string) (int64, bool) {
	result, ok := s.accuToGovStaker.Get(tokenPath)
	if !ok {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		return 0, false
	}

	return amount, true
}

func (s *mockProtocolFeeStore) SetAccuToGovStakerItem(tokenPath string, amount int64) error {
	s.accuToGovStaker.Set(tokenPath, amount)

	return nil
}

// handle accuToDevOps store data
func (s *mockProtocolFeeStore) HasAccuToDevOpsStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeAccuToDevOps() error {
	s.accuToDevOps = avl.NewTree()
	return nil
}

func (s *mockProtocolFeeStore) GetAccuToDevOps() *avl.Tree {
	return s.accuToDevOps
}

func (s *mockProtocolFeeStore) GetAccuToDevOpsItem(tokenPath string) (int64, bool) {
	result, ok := s.accuToDevOps.Get(tokenPath)
	if !ok {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

func (s *mockProtocolFeeStore) SetAccuToDevOpsItem(tokenPath string, amount int64) error {
	s.accuToDevOps.Set(tokenPath, amount)

	return nil
}

// handle distributedToGovStakerHistory store data
func (s *mockProtocolFeeStore) HasDistributedToGovStakerHistoryStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeDistributedToGovStakerHistory() error {
	s.distributedToGovStakerHistory = avl.NewTree()
	return nil
}

func (s *mockProtocolFeeStore) GetDistributedToGovStakerHistory() *avl.Tree {
	return s.distributedToGovStakerHistory
}

func (s *mockProtocolFeeStore) GetDistributedToGovStakerHistoryItem(tokenPath string) (int64, bool) {
	result, ok := s.distributedToGovStakerHistory.Get(tokenPath)
	if !ok {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		return 0, false
	}

	return amount, true
}

func (s *mockProtocolFeeStore) SetDistributedToGovStakerHistoryItem(tokenPath string, amount int64) error {
	s.distributedToGovStakerHistory.Set(tokenPath, amount)

	return nil
}

// handle distributedToDevOpsHistory store data
func (s *mockProtocolFeeStore) HasDistributedToDevOpsHistoryStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeDistributedToDevOpsHistory() error {
	s.distributedToDevOpsHistory = avl.NewTree()
	return nil
}

func (s *mockProtocolFeeStore) GetDistributedToDevOpsHistory() *avl.Tree {
	return s.distributedToDevOpsHistory
}

func (s *mockProtocolFeeStore) GetDistributedToDevOpsHistoryItem(tokenPath string) (int64, bool) {
	result, ok := s.distributedToDevOpsHistory.Get(tokenPath)
	if !ok {
		return 0, false
	}

	amount, ok := result.(int64)
	if !ok {
		panic(ufmt.Errorf("failed to cast result to int64: %T", result))
	}

	return amount, true
}

func (s *mockProtocolFeeStore) SetDistributedToDevOpsHistoryItem(tokenPath string, amount int64) error {
	s.distributedToDevOpsHistory.Set(tokenPath, amount)

	return nil
}

// handle tokenListWithAmounts store data
func (s *mockProtocolFeeStore) HasTokenListWithAmountsStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeTokenListWithAmount() error {
	s.tokenListWithAmounts = make(map[string]int64)
	return nil
}

func (s *mockProtocolFeeStore) GetTokenListWithAmounts() map[string]int64 {
	return s.tokenListWithAmounts
}

func (s *mockProtocolFeeStore) SetTokenListWithAmounts(tokenListWithAmounts map[string]int64) error {
	s.tokenListWithAmounts = tokenListWithAmounts
	return nil
}

func (s *mockProtocolFeeStore) GetTokenListWithAmountItem(tokenPath string) (int64, bool) {
	amount, ok := s.tokenListWithAmounts[tokenPath]
	if !ok {
		return 0, false
	}

	return amount, true
}

func (s *mockProtocolFeeStore) SetTokenListWithAmountItem(tokenPath string, amount int64) error {
	s.tokenListWithAmounts[tokenPath] = amount

	return nil
}

func newMockProtocolFeeStore() protocol_fee.IProtocolFeeStore {
	return &mockProtocolFeeStore{
		devOpsPct:                     0,
		accuToGovStaker:               &avl.Tree{},
		accuToDevOps:                  &avl.Tree{},
		distributedToGovStakerHistory: &avl.Tree{},
		distributedToDevOpsHistory:    &avl.Tree{},
		tokenListWithAmounts:          make(map[string]int64),
	}
}
