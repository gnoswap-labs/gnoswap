package mock

type MockRouterStore struct {
	swapFee uint64
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

func (s *MockRouterStore) Clear() {
	s.swapFee = 0
}

func NewMockRouterStore() *MockRouterStore {
	return &MockRouterStore{swapFee: 15} // 0.15%
}
