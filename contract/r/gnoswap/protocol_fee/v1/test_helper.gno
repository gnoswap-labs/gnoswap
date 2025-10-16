package v1

import (
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/protocol_fee"
)

// Test helper functions. These functions are only compiled in test builds

// newProtocolFeeStateInternal creates a new protocolFeeState instance for testing
// This returns the concrete type instead of the interface
func newProtocolFeeStateInternal() *protocolFeeState {
	return &protocolFeeState{
		devOpsPct:                     0,
		accuToGovStaker:               avl.NewTree(),
		accuToDevOps:                  avl.NewTree(),
		distributedToGovStakerHistory: avl.NewTree(),
		distributedToDevOpsHistory:    avl.NewTree(),
		tokenListWithAmount:           make(map[string]int64),
	}
}

// ResetProtocolFeeState resets the protocol fee state for testing
// This should only be used in tests
func ResetProtocolFeeState(pf protocol_fee.IProtocolFee) {
	impl, ok := pf.(*protocolFeeV1)
	if !ok {
		panic("invalid protocol fee implementation")
	}

	impl.setProtocolFeeState(newProtocolFeeStateInternal())
}

// GetProtocolFeeStateForTest returns the protocol fee state for testing
// This should only be used in tests
func GetProtocolFeeStateForTest(pf protocol_fee.IProtocolFee) *protocolFeeState {
	impl, ok := pf.(*protocolFeeV1)
	if !ok {
		panic("invalid protocol fee implementation")
	}

	return impl.getProtocolFeeState()
}

// SetProtocolFeeStateForTest sets the protocol fee state for testing
// This should only be used in tests
func SetProtocolFeeStateForTest(pf protocol_fee.IProtocolFee, state *protocolFeeState) {
	impl, ok := pf.(*protocolFeeV1)
	if !ok {
		panic("invalid protocol fee implementation")
	}

	impl.setProtocolFeeState(state)
}

/* Mock type */

type mockProtocolFeeStore struct {
	state *protocolFeeState
}

func (m *mockProtocolFeeStore) GetProtocolFeeState() protocol_fee.ProtocolFeeState { return m.state }
func (m *mockProtocolFeeStore) SetProtocolFeeState(state protocol_fee.ProtocolFeeState) error {
	if pfs, ok := state.(*protocolFeeState); ok {
		m.state = pfs
		return nil
	}
	panic("invalid protocol fee state type")
}