package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/protocol_fee"
)

func TestNewProtocolFeeV1(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func() protocol_fee.IProtocolFeeStore
		verifyFn func(t *testing.T, pf protocol_fee.IProtocolFee)
	}{
		{
			name: "success - create new protocol fee v1 instance",
			setupFn: func() protocol_fee.IProtocolFeeStore {
				return newMockProtocolFeeStore()
			},
			verifyFn: func(t *testing.T, pf protocol_fee.IProtocolFee) {
				uassert.NotNil(t, pf)
				_, ok := pf.(*protocolFeeV1)
				uassert.True(t, ok, "expected *protocolFeeV1 type")
			},
		},
		{
			name: "success - instance can access store",
			setupFn: func() protocol_fee.IProtocolFeeStore {
				store := newMockProtocolFeeStore()
				return store
			},
			verifyFn: func(t *testing.T, pf protocol_fee.IProtocolFee) {
				uassert.NotNil(t, pf)
				pfv1, ok := pf.(*protocolFeeV1)
				uassert.True(t, ok)
				uassert.NotNil(t, pfv1.store)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := tt.setupFn()
			pf := NewProtocolFeeV1(store)
			tt.verifyFn(t, pf)
		})
	}
}

func TestGetProtocolFeeState(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func() *protocolFeeV1
		verifyFn func(t *testing.T, state *protocolFeeState)
	}{
		{
			name: "success - get protocol fee state",
			setupFn: func() *protocolFeeV1 {
				return createTestProtocolFee(t)
			},
			verifyFn: func(t *testing.T, state *protocolFeeState) {
				uassert.NotNil(t, state)
				uassert.NotNil(t, state.store)
			},
		},
		{
			name: "success - state reflects store data",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetDevOpsPct(2500)
				return pf
			},
			verifyFn: func(t *testing.T, state *protocolFeeState) {
				uassert.NotNil(t, state)
				uassert.Equal(t, state.DevOpsPct(), int64(2500))
				uassert.Equal(t, state.GovStakerPct(), int64(7500))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pf := tt.setupFn()
			state := pf.getProtocolFeeState()
			tt.verifyFn(t, state)
		})
	}
}
