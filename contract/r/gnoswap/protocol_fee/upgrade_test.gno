package protocol_fee

import (
	"chain/runtime"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestRegisterInitializer(cur realm, t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(cur realm, t *testing.T)
		initializer          func(_ int, rlm realm, s IProtocolFeeStore) IProtocolFee
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
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
			},
			callerRealm:     testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/new_version"),
			initializer:     makeMockInitializer("new_version"),
			expectedVersion: "v1",
		},
		{
			name: "register initializer is failed by duplicate registration",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)

			if tt.setup != nil {
				tt.setup(cur, t)
			}

			testing.SetRealm(tt.callerRealm)

			if tt.expectedHasAbort {
				uassert.AbortsContains(t, cur, tt.expectedAbortMessage, func() {
					RegisterInitializer(cross(cur), tt.initializer)
				})
			} else {
				RegisterInitializer(cross(cur), tt.initializer)

				impl := implementation.(*MockProtocolFee)
				uassert.Equal(t, impl.Version, tt.expectedVersion)
			}
		})
	}
}

func TestUpgradeImpl(cur realm, t *testing.T) {
	tests := []struct {
		name                 string
		setup                func(cur realm, t *testing.T)
		packagePath          string
		callerRealm          runtime.Realm
		expectedVersion      string
		expectedHasAbort     bool
		expectedAbortMessage string
	}{
		{
			name: "upgrade impl is success",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v2"))
				RegisterInitializer(cross(cur), makeMockInitializer("v2"))
			},
			packagePath:     "gno.land/r/gnoswap/protocol_fee/v2",
			callerRealm:     testing.NewUserRealm(adminAddr),
			expectedVersion: "v2",
		},
		{
			name: "upgrade impl is failed by non-admin caller",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v2"))
				RegisterInitializer(cross(cur), makeMockInitializer("v2"))
			},
			packagePath:          "gno.land/r/gnoswap/protocol_fee/v2",
			callerRealm:          testing.NewUserRealm("g1test"),
			expectedVersion:      "v1",
			expectedHasAbort:     true,
			expectedAbortMessage: "unauthorized: caller g1test is not admin",
		},
		{
			name: "upgrade impl is failed by non-registered version",
			setup: func(cur realm, t *testing.T) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
				RegisterInitializer(cross(cur), makeMockInitializer("v1"))
			},
			packagePath:          "gno.land/r/gnoswap/protocol_fee/v2",
			callerRealm:          testing.NewUserRealm(adminAddr),
			expectedVersion:      "v1",
			expectedHasAbort:     true,
			expectedAbortMessage: "version_manager: initializer not found for package path:gno.land/r/gnoswap/protocol_fee/v2",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)

			if tt.setup != nil {
				tt.setup(cur, t)
			}

			testing.SetRealm(tt.callerRealm)

			if tt.expectedHasAbort {
				uassert.AbortsContains(t, cur, tt.expectedAbortMessage, func() {
					UpgradeImpl(cross(cur), tt.packagePath)
				})
			} else {
				UpgradeImpl(cross(cur), tt.packagePath)
			}

			impl := implementation.(*MockProtocolFee)
			uassert.Equal(t, impl.Version, tt.expectedVersion)
		})
	}
}

func TestDistributeProtocolFee(cur realm, t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "distribute protocol fee is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross(cur), makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))

			// Action
			DistributeProtocolFee(cross(cur))

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("DistributeProtocolFee") != 1 {
				t.Error("DistributeProtocolFee was not called on the implementation")
			}
		})
	}
}

func TestSetDevOpsPct(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross(cur), makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))

			// Action
			SetDevOpsPct(cross(cur), tt.pct)

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("SetDevOpsPct") != 1 {
				t.Error("SetDevOpsPct was not called on the implementation")
			}
		})
	}
}

func TestSetGovStakerPct(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross(cur), makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))

			// Action
			SetGovStakerPct(cross(cur), tt.pct)

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("SetGovStakerPct") != 1 {
				t.Error("SetGovStakerPct was not called on the implementation")
			}
		})
	}
}

func TestAddToProtocolFee(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross(cur), makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))

			// Action
			AddToProtocolFee(cross(cur), tt.tokenPath, tt.amount)

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("AddToProtocolFee") != 1 {
				t.Error("AddToProtocolFee was not called on the implementation")
			}
		})
	}
}

func TestGetDevOpsPct(cur realm, t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get dev ops pct is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross(cur), makeMockInitializer("v1"))

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

func TestGetGovStakerPct(cur realm, t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get gov staker pct is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross(cur), makeMockInitializer("v1"))

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

func TestGetReservedTokens(cur realm, t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get reserved tokens is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross(cur), makeMockInitializer("v1"))

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))

			// Action
			GetReservedTokens()

			// Assert
			mockProtocolFee := implementation.(*MockProtocolFee)
			if mockProtocolFee.Response.CallCount("GetReservedTokens") != 1 {
				t.Error("GetReservedTokens was not called on the implementation")
			}
		})
	}
}

func TestGetAccuTransfersToGovStaker(cur realm, t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get accu transfers to gov staker is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross(cur), makeMockInitializer("v1"))

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

func TestGetAccuTransfersToDevOps(cur realm, t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "get accu transfers to dev ops is success",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross(cur), makeMockInitializer("v1"))

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

func TestGetAccuTransferToGovStakerByTokenPath(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross(cur), makeMockInitializer("v1"))

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

func TestGetAccuTransferToDevOpsByTokenPath(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1"))
			RegisterInitializer(cross(cur), makeMockInitializer("v1"))

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
