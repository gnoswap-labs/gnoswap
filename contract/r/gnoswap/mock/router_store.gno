package mock

type MockRouterStore struct {
	swapFee             uint64
	pendingProtocolFees map[string]int64
}

func (s *MockRouterStore) HasSwapFeeKey() bool {
	return s.swapFee != 0
}

// GetSwapFee retrieves the swap fee.
func (s *MockRouterStore) GetSwapFee() uint64 {
	return s.swapFee
}

// SetSwapFee stores the swap fee.
func (s *MockRouterStore) SetSwapFee(swapFee uint64) error {
	s.swapFee = swapFee
	return nil
}

func (s *MockRouterStore) HasPendingProtocolFeesKey() bool {
	return s.pendingProtocolFees != nil
}

func (s *MockRouterStore) GetPendingProtocolFees() map[string]int64 {
	return s.pendingProtocolFees
}

func (s *MockRouterStore) SetPendingProtocolFees(fees map[string]int64) error {
	s.pendingProtocolFees = fees
	return nil
}

func (s *MockRouterStore) Clear() {
	s.swapFee = 0
	s.pendingProtocolFees = make(map[string]int64)
}

func NewMockRouterStore() *MockRouterStore {
	return &MockRouterStore{swapFee: 15, pendingProtocolFees: make(map[string]int64)} // 0.15%
}
