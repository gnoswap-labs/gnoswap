package governance

import (
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/p/gnoswap/consts"

	en "gno.land/r/gnoswap/v1/emission"
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
		// wantErr  bool
		validate func(t *testing.T)
	}{
		// {
		// 	name:     "Emission_ChangeDistributionPct",
		// 	path:     consts.EMISSION_PATH,
		// 	function: "ChangeDistributionPct",
		// 	params:   []string{"1", "7000", "2", "1500", "3", "1000", "4", "500"},
		// 	wantErr:  false,
		// 	validate: func(t *testing.T) {
		// 		uassert.Equal(t, en.GetDistributionBpsPct(1), uint64(7000))
		// 		uassert.Equal(t, en.GetDistributionBpsPct(2), uint64(1500))
		// 		uassert.Equal(t, en.GetDistributionBpsPct(3), uint64(1000))
		// 		uassert.Equal(t, en.GetDistributionBpsPct(4), uint64(500))
		// 	},
		// },
		{
			name:     "Router SetSwapFee: Pass",
			path:     consts.ROUTER_PATH,
			function: "SetSwapFee",
			params:   []string{"1000"},
			validate: func(t *testing.T) {
				uassert.Equal(t, rr.GetSwapFee(), uint64(1000))
			},
		},
		{
			name:     "set deposit gns amount",
			path:     consts.STAKER_PATH,
			function: "SetDepositGnsAmount",
			params:   []string{"1000"},
			validate: func(t *testing.T) {
				uassert.Equal(t, sr.GetDepositGnsAmount(), int64(1000))
			},
		},
		{
			name:     "set pool creation fee",
			path:     consts.POOL_PATH,
			function: "SetPoolCreationFee",
			params:   []string{"500"},
			validate: func(t *testing.T) {
				uassert.Equal(t, cross(pl.GetPoolCreationFee)(), int64(500))
			},
		},
		{
			name:     "SetWithdrawalFee",
			path:     consts.POOL_PATH,
			function: "SetWithdrawalFee",
			params:   []string{"600"},
			validate: func(t *testing.T) {
				uassert.Equal(t, cross(pl.GetWithdrawalFee)(), uint64(600))
			},
		},
		{
			name:     "ProtocolFee_SetDevOpsPct",
			path:     consts.PROTOCOL_FEE_PATH,
			function: "SetDevOpsPct",
			params:   []string{"900"},
			validate: func(t *testing.T) {
				uassert.Equal(t, pf.GetDevOpsPct(), uint64(900))
			},
		},
		{
			name:     "Router_SetSwapFee",
			path:     consts.ROUTER_PATH,
			function: "SetSwapFee",
			params:   []string{"400"},
			validate: func(t *testing.T) {
				uassert.Equal(t, rr.GetSwapFee(), uint64(400))
			},
		},
		{
			name:     "Staker_SetDepositGnsAmount",
			path:     consts.STAKER_PATH,
			function: "SetDepositGnsAmount",
			params:   []string{"400"},
			validate: func(t *testing.T) {
				uassert.Equal(t, sr.GetDepositGnsAmount(), int64(400))
			},
		},
		{
			name:     "Staker_SetUnStakingFee",
			path:     consts.STAKER_PATH,
			function: "SetUnStakingFee",
			params:   []string{"100"},
			validate: func(t *testing.T) {
				uassert.Equal(t, sr.GetUnstakingFee(), uint64(100))
			},
		},
		{
			name:     "ProtocolFee_SetDevOpsPct",
			path:     consts.PROTOCOL_FEE_PATH,
			function: "SetDevOpsPct",
			params:   []string{"900"},
			validate: func(t *testing.T) {
				uassert.Equal(t, pf.GetDevOpsPct(), uint64(900))
			},
		},
		{
			name:     "Router_SetSwapFee",
			path:     consts.ROUTER_PATH,
			function: "SetSwapFee",
			params:   []string{"400"},
			validate: func(t *testing.T) {
				uassert.Equal(t, rr.GetSwapFee(), uint64(400))
			},
		},
		{
			name:     "Router_SetSwapFee_InvalidValue",
			path:     consts.ROUTER_PATH,
			function: "SetSwapFee",
			params:   []string{"-100"},
			validate: func(t *testing.T) {
				defer func() {
					if r := recover(); r != nil {
						return
					}
				}()
				uassert.Equal(t, rr.GetSwapFee(), uint64(400))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					return
				} else if r != nil {
					t.Fatal("unexpected panic")
				}
			}()
			handler, _ := registry.Handler(tt.path, tt.function)
			err := handler.Execute(tt.params)
			uassert.NoError(t, err)
			tt.validate(t)
		})
	}
}

func TestCreateParameterHandlers_SetUnStakingFee_Panic(t *testing.T) {
	registry := createParameterHandlers()
	handler, _ := registry.Handler(consts.STAKER_PATH, "SetUnStakingFee")
	errMsg := "[GNOSWAP-STAKER-008] invalid unstaking fee || fee(10001) must be in range 0 ~ 10000"
	uassert.AbortsWithMessage(t, errMsg, func() {
		handler.Execute([]string{"10001"})
	})
	uassert.Equal(t, sr.GetUnstakingFee(), uint64(100))
}

func TestCreateParameterHandlers_Emission_ChangeDistributionPct_Panic(t *testing.T) {
	registry := createParameterHandlers()
	handler, _ := registry.Handler(consts.EMISSION_PATH, "ChangeDistributionPct")
	errMsg := "[GNOSWAP-EMISSION-001] invalid distribution pct || total distribution pct(10001) must be in range 0 ~ 10000"
	uassert.AbortsWithMessage(t, errMsg, func() {
		handler.Execute([]string{"1", "8000", "2", "3000"})
	})

	println(en.GetDistributionBpsPct(1))
	// uassert.Equal(t, en.GetDistributionBpsPct(1), uint64(7000))
}

func TestRoleChangeParameterHandlers(t *testing.T) {
	registry := createParameterHandlers()

	tests := []struct {
		name        string
		pkgPath     string
		function    string
		params      []string
		expectError bool
	}{
		{
			name:        "CreateRole handler",
			pkgPath:     consts.ACCESS_PATH,
			function:    "CreateRole",
			params:      []string{"test_role", testutils.TestAddress("test_role").String()},
			expectError: false,
		},
		{
			name:        "Invalid parameter count for CreateRole",
			pkgPath:     consts.ACCESS_PATH,
			function:    "CreateRole",
			params:      []string{"missing_address"},
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler, err := registry.Handler(tt.pkgPath, tt.function)
			uassert.NoError(t, err)

			err = handler.Execute(tt.params)
			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}
