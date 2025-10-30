package protocol_fee

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/uassert"
)

func TestRegisterInitializer(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(t *testing.T)
		initializer          func(s IProtocolFeeStore) IProtocolFee
		callerRealm          runtime.Realm
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:        "register initializer is success",
			callerRealm: testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"),
			initializer: makeMockInitializer("v1"),
		},
		{
			name: "register initializer is failed by duplicate registration",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"),
			initializer:          makeMockInitializer("v1"),
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: initializer already registered",
		},
		{
			name:                 "register initializer is failed by invalid domain path",
			callerRealm:          testing.NewCodeRealm("gno.land/r/gnoswap/invalid"),
			initializer:          makeMockInitializer("v1"),
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: caller is not in the domain path",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)

			if tt.setup != nil {
				tt.setup(t)
			}

			testing.SetRealm(tt.callerRealm)

			if tt.expectedHasAbort {
				uassert.AbortsContains(t, tt.expectedAbortMessage, func() {
					RegisterInitializer(cross, tt.initializer)
				})
			} else {
				RegisterInitializer(cross, tt.initializer)
			}
		})
	}
}

func TestUpgradeImpl(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(t *testing.T)
		packagePath          string
		callerRealm          runtime.Realm
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name: "upgrade impl is success",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v2"))
				RegisterInitializer(cross, makeMockInitializer("v2"))
			},
			packagePath: "gno.land/r/gnoswap/protocol_fee/v2",
			callerRealm: testing.NewUserRealm(adminAddr),
		},
		{
			name: "upgrade impl is failed by non-admin caller",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v2"))
				RegisterInitializer(cross, makeMockInitializer("v2"))
			},
			packagePath:          "gno.land/r/gnoswap/protocol_fee/v2",
			callerRealm:          testing.NewUserRealm("g1test"),
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1test is not admin",
		},
		{
			name: "upgrade impl is failed by non-registered version",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			packagePath:          "gno.land/r/gnoswap/protocol_fee/v2",
			callerRealm:          testing.NewUserRealm(adminAddr),
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: initializer not found for package path:gno.land/r/gnoswap/protocol_fee/v2",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)

			if tt.setup != nil {
				tt.setup(t)
			}

			testing.SetRealm(tt.callerRealm)

			if tt.expectedHasAbort {
				uassert.AbortsContains(t, tt.expectedAbortMessage, func() {
					UpgradeImpl(cross, tt.packagePath)
				})
			} else {
				UpgradeImpl(cross, tt.packagePath)
			}
		})
	}
}

func TestDistributeProtocolFee(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "distribute protocol fee is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := DistributeProtocolFee(cross)
			_ = result
		})
	}
}

func TestSetDevOpsPct(t *testing.T) {
	tests := []struct {
		name string
		pct  int64
	}{
		{
			name: "set dev ops pct is success",
			pct:  50,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			SetDevOpsPct(cross, tt.pct)
		})
	}
}

func TestSetGovStakerPct(t *testing.T) {
	tests := []struct {
		name string
		pct  int64
	}{
		{
			name: "set gov staker pct is success",
			pct:  50,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			SetGovStakerPct(cross, tt.pct)
		})
	}
}

func TestAddToProtocolFee(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
		amount    int64
	}{
		{
			name:      "add to protocol fee is success",
			tokenPath: "gno.land/r/demo/gns",
			amount:    1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			AddToProtocolFee(cross, tt.tokenPath, tt.amount)
		})
	}
}

func TestClearTokenListWithAmount(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "clear token list with amount is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			ClearTokenListWithAmount(cross)
		})
	}
}

func TestClearAccuTransferToGovStaker(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "clear accu transfer to gov staker is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			ClearAccuTransferToGovStaker(cross)
		})
	}
}

func TestGetDevOpsPct(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get dev ops pct is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := GetDevOpsPct()
			_ = result
		})
	}
}

func TestGetGovStakerPct(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get gov staker pct is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := GetGovStakerPct()
			_ = result
		})
	}
}

func TestGetTokenListWithAmount(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get token list with amount is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := GetTokenListWithAmount()
			_ = result
		})
	}
}

func TestGetAmountOfToken(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
	}{
		{
			name:      "get amount of token is success",
			tokenPath: "gno.land/r/demo/gns",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := GetAmountOfToken(tt.tokenPath)
			_ = result
		})
	}
}

func TestGetAccuTransfersToGovStaker(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get accu transfers to gov staker is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := GetAccuTransfersToGovStaker()
			_ = result
		})
	}
}

func TestGetAccuTransfersToDevOps(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get accu transfers to dev ops is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := GetAccuTransfersToDevOps()
			_ = result
		})
	}
}

func TestGetAccuTransferToGovStakerByTokenPath(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
	}{
		{
			name:      "get accu transfer to gov staker by token path is success",
			tokenPath: "gno.land/r/demo/gns",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := GetAccuTransferToGovStakerByTokenPath(tt.tokenPath)
			_ = result
		})
	}
}

func TestGetAccuTransferToDevOpsByTokenPath(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
	}{
		{
			name:      "get accu transfer to dev ops by token path is success",
			tokenPath: "gno.land/r/demo/gns",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := GetAccuTransferToDevOpsByTokenPath(tt.tokenPath)
			_ = result
		})
	}
}

func TestGetHistoryOfDistributedToGovStakerByTokenPath(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
	}{
		{
			name:      "get history of distributed to gov staker by token path is success",
			tokenPath: "gno.land/r/demo/gns",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := GetHistoryOfDistributedToGovStakerByTokenPath(tt.tokenPath)
			_ = result
		})
	}
}

func TestGetHistoryOfDistributedToDevOpsByTokenPath(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
	}{
		{
			name:      "get history of distributed to dev ops by token path is success",
			tokenPath: "gno.land/r/demo/gns",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := GetHistoryOfDistributedToDevOpsByTokenPath(tt.tokenPath)
			_ = result
		})
	}
}

func TestApiGetAccuTransferToGovStaker(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "api get accu transfer to gov staker is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := ApiGetAccuTransferToGovStaker()
			_ = result
		})
	}
}

func TestApiGetAccuTransferToDevOps(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "api get accu transfer to dev ops is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := ApiGetAccuTransferToDevOps()
			_ = result
		})
	}
}

func TestApiGetHistoryTransferToGovStaker(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "api get history transfer to gov staker is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := ApiGetHistoryTransferToGovStaker()
			_ = result
		})
	}
}

func TestApiGetHistoryTransferToDevOps(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "api get history transfer to dev ops is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := ApiGetHistoryTransferToDevOps()
			_ = result
		})
	}
}

func TestApiGetActualBalance(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "api get actual balance is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := ApiGetActualBalance()
			_ = result
		})
	}
}

func TestApiGetRecordedBalance(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "api get recorded balance is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := ApiGetRecordedBalance()
			_ = result
		})
	}
}

func TestApiGetUnrecordedBalance(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "api get unrecorded balance is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))
			result := ApiGetUnrecordedBalance()
			_ = result
		})
	}
}
