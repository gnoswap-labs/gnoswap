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
	reservedTokens       []string
	accrualPendingTokens []string
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
	s.reservedTokens = []string{}
	return nil
}

func (s *mockProtocolFeeStore) GetReservedTokens() []string {
	return s.reservedTokens
}

func (s *mockProtocolFeeStore) SetReservedTokens(_ int, rlm realm, reservedTokens []string) error {
	s.reservedTokens = reservedTokens
	return nil
}

func (s *mockProtocolFeeStore) AddReservedToken(_ int, rlm realm, tokenPath string) error {
	for _, reservedToken := range s.reservedTokens {
		if reservedToken == tokenPath {
			return nil
		}
	}
	s.reservedTokens = append(s.reservedTokens, tokenPath)
	return nil
}

func (s *mockProtocolFeeStore) RemoveReservedToken(_ int, rlm realm, tokenPath string) error {
	filteredReservedTokens := make([]string, 0, len(s.reservedTokens))
	for _, reservedToken := range s.reservedTokens {
		if reservedToken != tokenPath {
			filteredReservedTokens = append(filteredReservedTokens, reservedToken)
		}
	}

	return s.SetReservedTokens(0, rlm, filteredReservedTokens)
}

// handle accrualPendingTokens store data
func (s *mockProtocolFeeStore) HasAccrualPendingTokensStoreKey() bool {
	return true
}

func (s *mockProtocolFeeStore) InitializeAccrualPendingTokens(_ int, rlm realm) error {
	s.accrualPendingTokens = []string{}
	return nil
}

func (s *mockProtocolFeeStore) GetAccrualPendingTokens() []string {
	return s.accrualPendingTokens
}

func (s *mockProtocolFeeStore) SetAccrualPendingTokens(_ int, rlm realm, accrualPendingTokens []string) error {
	s.accrualPendingTokens = accrualPendingTokens
	return nil
}

func (s *mockProtocolFeeStore) AddAccrualPendingToken(_ int, rlm realm, tokenPath string) error {
	for _, accrualPendingToken := range s.accrualPendingTokens {
		if accrualPendingToken == tokenPath {
			return nil
		}
	}
	s.accrualPendingTokens = append(s.accrualPendingTokens, tokenPath)
	return nil
}

func (s *mockProtocolFeeStore) RemoveAccrualPendingToken(_ int, rlm realm, tokenPath string) error {
	filtered := make([]string, 0, len(s.accrualPendingTokens))
	listed := false
	for _, accrualPendingToken := range s.accrualPendingTokens {
		if accrualPendingToken == tokenPath {
			listed = true
			continue
		}

		filtered = append(filtered, accrualPendingToken)
	}

	if !listed {
		return nil
	}

	return s.SetAccrualPendingTokens(0, rlm, filtered)
}

func (s *mockProtocolFeeStore) ClearAccrualPendingTokens(_ int, rlm realm) error {
	return s.SetAccrualPendingTokens(0, rlm, []string{})
}

func newMockProtocolFeeStore() protocol_fee.IProtocolFeeStore {
	return &mockProtocolFeeStore{
		devOpsPct:                     0,
		accuToGovStaker:               protocol_fee.NewBPTreeN(16),
		accuToDevOps:                  protocol_fee.NewBPTreeN(16),
		distributedToGovStakerHistory: protocol_fee.NewBPTreeN(16),
		distributedToDevOpsHistory:    protocol_fee.NewBPTreeN(16),
		reservedTokens:                []string{},
		accrualPendingTokens:          []string{},
	}
}
