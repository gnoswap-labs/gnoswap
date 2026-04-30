package v1

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/protocol_fee"
)

type mockProtocolFeeStore struct {
	devOpsPct            int64
	accuToGovStaker      *bptree.BPTree
	accuToDevOps         *bptree.BPTree
	tokenListWithAmounts map[string]int64
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
	s.accuToGovStaker = bptree.NewBPTreeN(16)
	return nil
}

func (s *mockProtocolFeeStore) GetAccuToGovStaker() *bptree.BPTree {
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
	s.accuToDevOps = bptree.NewBPTreeN(16)
	return nil
}

func (s *mockProtocolFeeStore) GetAccuToDevOps() *bptree.BPTree {
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
		devOpsPct:            0,
		accuToGovStaker:      bptree.NewBPTreeN(16),
		accuToDevOps:         bptree.NewBPTreeN(16),
		tokenListWithAmounts: make(map[string]int64),
	}
}
