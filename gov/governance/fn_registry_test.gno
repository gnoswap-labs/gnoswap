package governance

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/consts"

	cn "gno.land/r/gnoswap/v1/common"
	en "gno.land/r/gnoswap/v1/emission"
	gs "gno.land/r/gnoswap/v1/gov/staker"
	pl "gno.land/r/gnoswap/v1/pool"
	pf "gno.land/r/gnoswap/v1/protocol_fee"
	rr "gno.land/r/gnoswap/v1/router"
	sr "gno.land/r/gnoswap/v1/staker"
)

func TestCreateParameterHandlers(t *testing.T) {
	registry := createParameterHandlers()

	if registry == nil {
		t.Fatal("registry is nil")
	}

	tests := []struct {
		name     string
		path     string
		function string
		params   []string
		wantErr  bool
		callFn   func(t *testing.T)
	}{
		{
			name: "Emission_ChangeDistributionPct",
			path: consts.EMISSION_PATH,
			function: "ChangeDistributionPct",
			params: []string{"1", "7000", "2", "1500", "3", "1000", "4", "500"},
			wantErr: false,
			callFn: func(t *testing.T) {
				uassert.Equal(t, en.GetDistributionBpsPct(1), uint64(7000))
				uassert.Equal(t, en.GetDistributionBpsPct(2), uint64(1500))
				uassert.Equal(t, en.GetDistributionBpsPct(3), uint64(1000))
				uassert.Equal(t, en.GetDistributionBpsPct(4), uint64(500))
			},
		},
		{
			name:     "Router SetSwapFee: Pass",
			path:     consts.ROUTER_PATH,
			function: "SetSwapFee",
			params:   []string{"1000"},
			wantErr:  false,
			callFn: func(t *testing.T) {
				uassert.Equal(t, rr.GetSwapFee(), uint64(1000))
			},
		},
		{
			name: "set deposit gns amount",
			path: consts.STAKER_PATH,
			function: "SetDepositGnsAmount",
			params: []string{"1000"},
			wantErr: false,
			callFn: func(t *testing.T) {
				uassert.Equal(t, sr.GetDepositGnsAmount(), uint64(1000))
			},
		},
		{
			name: "set pool creation fee",
			path: consts.POOL_PATH,
			function: "SetPoolCreationFee",
			params: []string{"500"},
			wantErr: false,
			callFn: func(t *testing.T) {
				uassert.Equal(t, pl.GetPoolCreationFee(), uint64(500))
			},
		},
		{
			name: "SetWithdrawalFee",
			path: consts.POOL_PATH,
			function: "SetWithdrawalFee",
			params: []string{"600"},
			wantErr: false,
			callFn: func(t *testing.T) {
				uassert.Equal(t, pl.GetWithdrawalFee(), uint64(600))
			},
		},
		{
			name: "ProtocolFee_SetDevOpsPct",
			path: consts.PROTOCOL_FEE_PATH,
			function: "SetDevOpsPct",
			params: []string{"900"},
			wantErr: false,
			callFn: func(t *testing.T) {
				uassert.Equal(t, pf.GetDevOpsPct(), uint64(900))
			},
		},
		{
			name: "Router_SetSwapFee",
			path: consts.ROUTER_PATH,
			function: "SetSwapFee",
			params: []string{"400"},
			wantErr: false,
			callFn: func(t *testing.T) {
				uassert.Equal(t, rr.GetSwapFee(), uint64(400))
			},
		},
		{
			name: "Staker_SetDepositGnsAmount",
			path: consts.STAKER_PATH,
			function: "SetDepositGnsAmount",
			params: []string{"400"},
			wantErr: false,
			callFn: func(t *testing.T) {
				uassert.Equal(t, sr.GetDepositGnsAmount(), uint64(400))
			},
		},
		{
			name: "Staker_SetUnstakingFee",
			path: consts.STAKER_PATH,
			function: "SetUnstakingFee",
			params: []string{"100"},
			wantErr: false,
			callFn: func(t *testing.T) {
				uassert.Equal(t, sr.GetUnstakingFee(), uint64(100))
			},
		},
		{
			name: "Staker_RemovePoolTier",
			path: consts.STAKER_PATH,
			function: "RemovePoolTier",
			params: []string{"100"},
			wantErr: false,
			callFn: func(t *testing.T) {
				after := sr.GetPoolsWithTier()
				uassert.Equal(t, len(after), 1)
				uassert.Equal(t, after[0], "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000_1")
			},
		},
		{
			name: "ProtocolFee_SetDevOpsPct",
			path: consts.PROTOCOL_FEE_PATH,
			function: "SetDevOpsPct",
			params: []string{"900"},
			wantErr: false,
			callFn: func(t *testing.T) {
				uassert.Equal(t, pf.GetDevOpsPct(), uint64(900))
			},
		},
		{
			name: "Router_SetSwapFee",
			path: consts.ROUTER_PATH,
			function: "SetSwapFee",
			params: []string{"400"},
			wantErr: false,
			callFn: func(t *testing.T) {
				uassert.Equal(t, rr.GetSwapFee(), uint64(400))
			},
		},
		{
			name: "Staker_SetDepositGnsAmount",
			path: consts.STAKER_PATH,
			function: "SetDepositGnsAmount",
			params: []string{"400"},
			wantErr: false,
			callFn: func(t *testing.T) {
				uassert.Equal(t, sr.GetDepositGnsAmount(), uint64(400))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler, _ := registry.Get(tt.path, tt.function)

			err := handler(tt.params)
			if (err != nil) != tt.wantErr {
				t.Errorf("unexpected error: %v", err)
			}

			tt.callFn(t)
		})
	}
}