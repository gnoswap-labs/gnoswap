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
		expectedVersion      string
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name:            "register initializer is success",
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"),
			initializer:     makeMockInitializer("v1"),
			expectedVersion: "v1",
		},
		{
			name: "register multiple different initializers",
			setup: func(t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
				RegisterInitializer(cross, makeMockInitializer("v1"))
			},
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/new_version"),
			initializer:     makeMockInitializer("new_version"),
			expectedVersion: "v1",
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

				impl := implementation.(*MockProtocolFee)
				uassert.Equal(t, impl.Version, tt.expectedVersion)
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
		expectedVersion      string
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
			packagePath:     "gno.land/r/gnoswap/protocol_fee/v2",
			callerRealm:     testing.NewUserRealm(adminAddr),
			expectedVersion: "v2",
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
			expectedVersion:      "v1",
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
			expectedVersion:      "v1",
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

			impl := implementation.(*MockProtocolFee)
			uassert.Equal(t, impl.Version, tt.expectedVersion)
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

			// Action
			DistributeProtocolFee(cross)

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("DistributeProtocolFee") != 1 {
				t.Error("DistributeProtocolFee was not called on the implementation")
			}
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

			// Action
			SetDevOpsPct(cross, tt.pct)

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("SetDevOpsPct") != 1 {
				t.Error("SetDevOpsPct was not called on the implementation")
			}
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

			// Action
			SetGovStakerPct(cross, tt.pct)

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("SetGovStakerPct") != 1 {
				t.Error("SetGovStakerPct was not called on the implementation")
			}
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

			// Action
			AddToProtocolFee(cross, tt.tokenPath, tt.amount)

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("AddToProtocolFee") != 1 {
				t.Error("AddToProtocolFee was not called on the implementation")
			}
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

			// Action
			ClearTokenListWithAmount(cross)

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("ClearTokenListWithAmount") != 1 {
				t.Error("ClearTokenListWithAmount was not called on the implementation")
			}
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

			// Action
			ClearAccuTransferToGovStaker(cross)

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("ClearAccuTransferToGovStaker") != 1 {
				t.Error("ClearAccuTransferToGovStaker was not called on the implementation")
			}
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

			// Action
			GetDevOpsPct()

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("GetDevOpsPct") != 1 {
				t.Error("GetDevOpsPct was not called on the implementation")
			}
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

			// Action
			GetGovStakerPct()

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("GetGovStakerPct") != 1 {
				t.Error("GetGovStakerPct was not called on the implementation")
			}
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

			// Action
			GetTokenListWithAmount()

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("GetTokenListWithAmount") != 1 {
				t.Error("GetTokenListWithAmount was not called on the implementation")
			}
		})
	}
}

func TestGetTokenList(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get token list is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))

			// Action
			GetTokenList()

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("GetTokenList") != 1 {
				t.Error("GetTokenList was not called on the implementation")
			}
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

			// Action
			GetAmountOfToken(tt.tokenPath)

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("GetAmountOfToken") != 1 {
				t.Error("GetAmountOfToken was not called on the implementation")
			}
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

			// Action
			GetAccuTransfersToGovStaker()

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("GetAccuTransfersToGovStaker") != 1 {
				t.Error("GetAccuTransfersToGovStaker was not called on the implementation")
			}
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

			// Action
			GetAccuTransfersToDevOps()

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("GetAccuTransfersToDevOps") != 1 {
				t.Error("GetAccuTransfersToDevOps was not called on the implementation")
			}
		})
	}
}

func TestGetTotalAccuTransfersToGovStaker(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get total accu transfers to gov staker is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))

			// Action
			GetTotalAccuTransfersToGovStaker()

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("GetTotalAccuTransfersToGovStaker") != 1 {
				t.Error("GetTotalAccuTransfersToGovStaker was not called on the implementation")
			}
		})
	}
}

func TestGetTotalAccuTransfersToDevOps(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get total accu transfers to dev ops is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross, makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))

			// Action
			GetTotalAccuTransfersToDevOps()

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("GetTotalAccuTransfersToDevOps") != 1 {
				t.Error("GetTotalAccuTransfersToDevOps was not called on the implementation")
			}
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

			// Action
			GetAccuTransferToGovStakerByTokenPath(tt.tokenPath)

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("GetAccuTransferToGovStakerByTokenPath") != 1 {
				t.Error("GetAccuTransferToGovStakerByTokenPath was not called on the implementation")
			}
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

			// Action
			GetAccuTransferToDevOpsByTokenPath(tt.tokenPath)

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("GetAccuTransferToDevOpsByTokenPath") != 1 {
				t.Error("GetAccuTransferToDevOpsByTokenPath was not called on the implementation")
			}
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

			// Action
			GetHistoryOfDistributedToGovStakerByTokenPath(tt.tokenPath)

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("GetHistoryOfDistributedToGovStakerByTokenPath") != 1 {
				t.Error("GetHistoryOfDistributedToGovStakerByTokenPath was not called on the implementation")
			}
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

			// Action
			GetHistoryOfDistributedToDevOpsByTokenPath(tt.tokenPath)

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("GetHistoryOfDistributedToDevOpsByTokenPath") != 1 {
				t.Error("GetHistoryOfDistributedToDevOpsByTokenPath was not called on the implementation")
			}
		})
	}
}
