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
func (s *MockRouterStore) SetSwapFee(_ int, rlm realm, swapFee uint64) error {
	s.swapFee = swapFee
	return nil
}

func (s *MockRouterStore) HasPendingProtocolFeesKey() bool {
	return s.pendingProtocolFees != nil
}

func (s *MockRouterStore) GetPendingProtocolFees() map[string]int64 {
	return s.pendingProtocolFees
}

func (s *MockRouterStore) SetPendingProtocolFees(_ int, rlm realm, fees map[string]int64) error {
	s.pendingProtocolFees = fees
	return nil
}

func (s *MockRouterStore) GetPendingProtocolFee(tokenPath string) int64 {
	return s.pendingProtocolFees[tokenPath]
}

func (s *MockRouterStore) SetPendingProtocolFee(_ int, rlm realm, tokenPath string, amount int64) error {
	s.pendingProtocolFees[tokenPath] = amount
	return nil
}

func (s *MockRouterStore) RemovePendingProtocolFee(_ int, rlm realm, tokenPath string) error {
	delete(s.pendingProtocolFees, tokenPath)
	return nil
}

func (s *MockRouterStore) Clear() {
	s.swapFee = 0
	s.pendingProtocolFees = make(map[string]int64)
}

func NewMockRouterStore() *MockRouterStore {
	return &MockRouterStore{swapFee: 15, pendingProtocolFees: make(map[string]int64)} // 0.15%
}
