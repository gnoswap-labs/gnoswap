package governance

import (
	"errors"
	"testing"
	"time"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"
)

func TestParameterRegistry_Register(t *testing.T) {
	registry := NewParameterRegistry()

	testHandler := NewFunctionHandler(func(params []string) error {
		return nil
	})

	tests := []struct {
		name     string
		pkgPath  string
		function string
		handler  ParameterHandler
	}{
		{
			name:     "pass",
			pkgPath:  "test/pkg",
			function: "testFunc",
			handler:  testHandler,
		},
		{
			name:     "empty pass",
			pkgPath:  "",
			function: "testFunc",
			handler:  testHandler,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			registry.Register(tt.pkgPath, tt.function, tt.handler)

			handler, err := registry.Handler(tt.pkgPath, tt.function)
			uassert.NoError(t, err)

			if handler == nil {
				t.Errorf("handler is nil")
			}

			expectedKey := makeHandlerKey(tt.pkgPath, tt.function)
			if _, exists := registry.handlers.Get(expectedKey); !exists {
				t.Errorf("expected key %s not found", expectedKey)
			}
		})
	}
}

func TestParameterRegistry(t *testing.T) {
	tests := []struct {
		name       string
		pkgPath    string
		function   string
		handler    ParameterHandler
		wantErr    bool
		errMessage string
	}{
		{
			name:     "should register and retrieve handler successfully",
			pkgPath:  "test/pkg",
			function: "testFunc",
			handler: NewFunctionHandler(func(params []string) error {
				return nil
			}),
			wantErr:    false,
			errMessage: "",
		},
		{
			name:       "should return error for non-existent handler",
			pkgPath:    "non/existent",
			function:   "missing",
			handler:    nil,
			wantErr:    true,
			errMessage: "handler not found for non/existent:missing",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			registry := NewParameterRegistry()

			// Register handler if provided
			if tt.handler != nil {
				registry.Register(tt.pkgPath, tt.function, tt.handler)
			}

			// Try to retrieve handler
			handler, err := registry.Handler(tt.pkgPath, tt.function)

			if tt.wantErr {
				uassert.Error(t, err, tt.errMessage)
				uassert.Equal(t, err.Error(), tt.errMessage)
			} else {
				uassert.NoError(t, err)
				if handler == nil {
					t.Error("expected handler to be non-nil")
				}
			}
		})
	}
}

func TestExecuteParameterChange(t *testing.T) {
	registry := NewParameterRegistry()

	registry.Register("test/pkg", "TestFunc", NewFunctionHandler(func(params []string) error {
		if len(params) != 2 {
			return errors.New("invalid params length")
		}
		return nil
	}))

	tests := []struct {
		name    string
		msgs    []string
		wantErr bool
	}{
		{
			name: "Pass: Valid message",
			msgs: []string{
				"test/pkg*EXE*TestFunc*EXE*param1,param2",
			},
			wantErr: false,
		},
		{
			name: "Fail: Missing separator",
			msgs: []string{
				"test/pkg*EXE*TestFunc",
			},
			wantErr: true,
		},
		{
			name: "Fail: Non-existent handler",
			msgs: []string{
				"unknown/pkg*EXE*UnknownFunc*EXE*param1",
			},
			wantErr: true,
		},
		{
			name: "Fail: Not enough parameters",
			msgs: []string{
				"test/pkg*EXE*TestFunc*EXE*param1",
			},
			wantErr: true,
		},
		{
			name: "handle multiple messages",
			msgs: []string{
				"test/pkg*EXE*TestFunc*EXE*param1,param2",
				"test/pkg*EXE*TestFunc*EXE*param2,param3",
			},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := executeParameterChange(tt.msgs, registry)
			if !tt.wantErr {
				uassert.NoError(t, err)
			} else {
				uassert.Error(t, err)
			}
		})
	}
}

func TestValidateProposalState(t *testing.T) {
	tests := []struct {
		name     string
		proposal *ProposalInfo
		want     ExecutionValidator
	}{
		{
			name: "Pass: Text proposal",
			proposal: &ProposalInfo{
				ProposalType: Text,
				State: ProposalStateInfo{
					State:     StatePassed,
					Timestamp: 0,
				},
			},
			want: ExecutionValidator{
				isTextProposal:    true,
				isAlreadyExecuted: false,
				isAlreadyCanceled: false,
				isAlreadyRejected: false,
				hasPassed:         true,
			},
		},
		{
			name: "Pass: Already executed",
			proposal: &ProposalInfo{
				ProposalType: ParameterChange,
				State: ProposalStateInfo{
					State:     StateExecuted | StatePassed,
					Timestamp: 0,
				},
			},
			want: ExecutionValidator{
				isTextProposal:    false,
				isAlreadyExecuted: true,
				isAlreadyCanceled: false,
				isAlreadyRejected: false,
				hasPassed:         true,
			},
		},
		{
			name: "Pass: Canceled",
			proposal: &ProposalInfo{
				ProposalType: ParameterChange,
				State: ProposalStateInfo{
					State:     StateCanceled,
					Timestamp: 0,
				},
			},
			want: ExecutionValidator{
				isTextProposal:    false,
				isAlreadyExecuted: false,
				isAlreadyCanceled: true,
				isAlreadyRejected: false,
				hasPassed:         false,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := validateProposalState(tt.proposal)
			if got != tt.want {
				t.Errorf("validateProposalState() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestCheckProposalValidation(t *testing.T) {
	// TODO: change error message after error code is defined
	tests := []struct {
		name      string
		validator ExecutionValidator
		wantErr   bool
		errMsg    string
	}{
		{
			name: "Pass: Valid proposal",
			validator: ExecutionValidator{
				isTextProposal:    false,
				isAlreadyExecuted: false,
				isAlreadyCanceled: false,
				isAlreadyRejected: false,
				hasPassed:         true,
			},
			wantErr: false,
		},
		{
			name: "Fail: Text proposal is not executable",
			validator: ExecutionValidator{
				isTextProposal:    true,
				isAlreadyExecuted: false,
				isAlreadyCanceled: false,
				isAlreadyRejected: false,
				hasPassed:         true,
			},
			wantErr: true,
			errMsg:  "[GNOSWAP-GOVERNANCE-011] can not execute text proposal",
		},
		{
			name: "Fail: Already executed, canceled, or rejected",
			validator: ExecutionValidator{
				isTextProposal:    false,
				isAlreadyExecuted: true,
				isAlreadyCanceled: false,
				isAlreadyRejected: false,
				hasPassed:         true,
			},
			wantErr: true,
			errMsg:  "proposal already executed, canceled, or rejected",
		},
		{
			name: "Fail: Proposal has not passed",
			validator: ExecutionValidator{
				isTextProposal:    false,
				isAlreadyExecuted: false,
				isAlreadyCanceled: false,
				isAlreadyRejected: false,
				hasPassed:         false,
			},
			wantErr: true,
			errMsg:  "[GNOSWAP-GOVERNANCE-016] proposal not passed",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := checkProposalValidation(tt.validator)
			if tt.wantErr {
				uassert.Error(t, err, tt.errMsg)
				uassert.Equal(t, err.Error(), tt.errMsg)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestParameterRegistry2(t *testing.T) {
	tests := []struct {
		name        string
		pkgPath     string
		function    string
		params      []string
		setupMock   func(*ParameterRegistry)
		expectError bool
	}{
		{
			name:     "valid handler",
			pkgPath:  consts.POOL_PATH,
			function: "SetFeeProtocol",
			params:   []string{"1", "2"},
			setupMock: func(r *ParameterRegistry) {
				r.Register(consts.POOL_PATH, "SetFeeProtocol", NewFunctionHandler(func(p []string) error {
					return nil
				}))
			},
			expectError: false,
		},
		{
			name:        "invalid handler",
			pkgPath:     "invalid",
			function:    "invalid",
			params:      []string{},
			setupMock:   func(r *ParameterRegistry) {},
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			registry := NewParameterRegistry()
			tt.setupMock(registry)

			handler, err := registry.Handler(tt.pkgPath, tt.function)
			if tt.expectError {
				uassert.Error(t, err)
				return
			}

			err = handler.Execute(tt.params)
			if err != nil {
				t.Errorf("handler returned error: %v", err)
			}
		})
	}
}

func TestAtomicExecution(t *testing.T) {
	tests := []struct {
		name        string
		msgs        []string
		setupMock   func(*ParameterRegistry)
		expectError bool
		validate    func(*testing.T, *ProposalInfo)
	}{
		{
			name: "Should rollback state when second message fails",
			msgs: []string{
				"gno.land/r/gnoswap/v1/gns*EXE*SetAvgBlockTimeInMs*EXE*123",
				"gno.land/r/gnoswap/v1/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/v1/gns,g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d,905",
			},
			setupMock: func(r *ParameterRegistry) {
				// 1st message should succeed
				r.Register("gno.land/r/gnoswap/v1/gns", "SetAvgBlockTimeInMs", NewFunctionHandler(func(params []string) error {
					return nil
				}))
				// 2nd message should fail
				r.Register("gno.land/r/gnoswap/v1/community_pool", "TransferToken", NewFunctionHandler(func(params []string) error {
					return errors.New("insufficient balance")
				}))
			},
			expectError: true,
			validate: func(t *testing.T, proposal *ProposalInfo) {
				// state should be rolled back
				uassert.False(t, proposal.State.State.HasState(StateExecuted))
				uassert.True(t, proposal.State.State.HasState(StatePassed)) // voting should still be passed
			},
		},
		{
			name: "Should execute all messages atomically when all succeed",
			msgs: []string{
				"gno.land/r/gnoswap/v1/gns*EXE*SetAvgBlockTimeInMs*EXE*123",
				"gno.land/r/gnoswap/v1/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/v1/gns,g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d,905",
			},
			setupMock: func(r *ParameterRegistry) {
				// all messages should succeed
				r.Register("gno.land/r/gnoswap/v1/gns", "SetAvgBlockTimeInMs", NewFunctionHandler(func(params []string) error {
					return nil
				}))
				r.Register("gno.land/r/gnoswap/v1/community_pool", "TransferToken", NewFunctionHandler(func(params []string) error {
					return nil
				}))
			},
			expectError: false,
			validate: func(t *testing.T, proposal *ProposalInfo) {
				// all messages should succeed
				uassert.True(t, proposal.State.State.HasState(StateExecuted))
				uassert.True(t, proposal.State.State.HasState(StatePassed))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// create a test proposal
			proposal := &ProposalInfo{
				ProposalType: ParameterChange,
				State: ProposalStateInfo{
					State:     StatePassed,
					Timestamp: 0,
				},
				Execution: ExecutionInfo{
					Msgs: tt.msgs,
				},
			}

			// setup registry
			registry := NewParameterRegistry()
			tt.setupMock(registry)

			// save original state
			originalState := *proposal

			// create execution context
			ctx := &ExecutionContext{
				ProposalId: 1,
				Now:        uint64(time.Now().Unix()),
				Config:     &Config{},
				Proposal:   proposal,
			}

			// try to execute
			err := executeProposal(ctx, registry)

			if tt.expectError {
				uassert.Error(t, err)
				// check if state is rolled back
				if proposal.State.State != originalState.State.State {
					t.Errorf("state is not rolled back")
				}
				uassert.Equal(t, proposal.State.Timestamp, originalState.State.Timestamp)
			} else {
				uassert.NoError(t, err)
				// check if state is updated
				uassert.True(t, proposal.State.State.HasState(StateExecuted))
				uassert.True(t, proposal.State.State.HasState(StatePassed))
			}

			if tt.validate != nil {
				tt.validate(t, proposal)
			}
		})
	}
}

func TestRollbackSystem(t *testing.T) {
	// trace the state change
	type stateChange struct {
		pkgPath  string
		function string
		value    any
	}

	tests := []struct {
		name        string
		msgs        []string
		setupMock   func(*ParameterRegistry) ([]stateChange, func())
		expectError bool
		validate    func(*testing.T, []stateChange)
	}{
		{
			name: "Should rollback when second message fails",
			msgs: []string{
				"gno.land/r/gnoswap/v1/gns*EXE*SetAvgBlockTimeInMs*EXE*123",
				"gno.land/r/gnoswap/v1/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/v1/gns,g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d,905",
			},
			setupMock: func(r *ParameterRegistry) ([]stateChange, func()) {
				initialStates := []stateChange{
					{
						pkgPath:  "gno.land/r/gnoswap/v1/gns",
						function: "SetAvgBlockTimeInMs",
						value:    int64(0),
					},
				}

				// track the state change
				blockTime := int64(0)

				// first message should succeed
				r.Register("gno.land/r/gnoswap/v1/gns", "SetAvgBlockTimeInMs", NewFunctionHandler(func(params []string) error {
					blockTime = int64(123)
					initialStates[0].value = blockTime
					return nil
				}))
				// second message should fail
				r.Register("gno.land/r/gnoswap/v1/community_pool", "TransferToken", NewFunctionHandler(func(params []string) error {
					return errors.New("insufficient balance")
				}))

				// rollback the state
				rollback := func() {
					blockTime = int64(0)
					initialStates[0].value = blockTime
				}

				return initialStates, rollback
			},
			expectError: true,
			validate: func(t *testing.T, states []stateChange) {
				// should be rolled back to initial value
				uassert.Equal(t, states[0].value, int64(0))
			},
		},
		{
			name: "Should not rollback when all messages succeed",
			msgs: []string{
				"gno.land/r/gnoswap/v1/gns*EXE*SetAvgBlockTimeInMs*EXE*123",
				"gno.land/r/gnoswap/v1/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/v1/gns,g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d,905",
			},
			setupMock: func(r *ParameterRegistry) ([]stateChange, func()) {
				initialStates := []stateChange{
					{
						pkgPath:  "gno.land/r/gnoswap/v1/gns",
						function: "SetAvgBlockTimeInMs",
						value:    int64(0),
					},
					{
						pkgPath:  "gno.land/r/gnoswap/v1/community_pool",
						function: "TransferToken",
						value:    uint64(0),
					},
				}

				// track the state change
				blockTime := int64(0)
				transferAmount := uint64(0)

				// all messages should succeed
				r.Register("gno.land/r/gnoswap/v1/gns", "SetAvgBlockTimeInMs", NewFunctionHandler(func(params []string) error {
					blockTime = int64(123)
					initialStates[0].value = blockTime
					return nil
				}))
				r.Register("gno.land/r/gnoswap/v1/community_pool", "TransferToken", NewFunctionHandler(func(params []string) error {
					transferAmount = uint64(905)
					initialStates[1].value = transferAmount
					return nil
				}))

				// rollback function (not used in this case)
				rollback := func() {
					blockTime = int64(0)
					transferAmount = uint64(0)
					initialStates[0].value = blockTime
					initialStates[1].value = transferAmount
				}

				return initialStates, rollback
			},
			expectError: false,
			validate: func(t *testing.T, states []stateChange) {
				// should be changed
				uassert.Equal(t, states[0].value, int64(123))
				uassert.Equal(t, states[1].value, uint64(905))
			},
		},
		{
			name: "Should not rollback when first message fails",
			msgs: []string{
				"gno.land/r/gnoswap/v1/gns*EXE*SetAvgBlockTimeInMs*EXE*invalid",
				"gno.land/r/gnoswap/v1/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/v1/gns,g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d,905",
			},
			setupMock: func(r *ParameterRegistry) ([]stateChange, func()) {
				initialStates := []stateChange{
					{
						pkgPath:  "gno.land/r/gnoswap/v1/gns",
						function: "SetAvgBlockTimeInMs",
						value:    int64(0),
					},
					{
						pkgPath:  "gno.land/r/gnoswap/v1/community_pool",
						function: "TransferToken",
						value:    uint64(0),
					},
				}

				// track the state change
				blockTime := int64(0)
				transferAmount := uint64(0)

				// first message should fail
				r.Register("gno.land/r/gnoswap/v1/gns", "SetAvgBlockTimeInMs", NewFunctionHandler(func(params []string) error {
					return errors.New("invalid parameter")
				}))
				// second message should not be executed
				r.Register("gno.land/r/gnoswap/v1/community_pool", "TransferToken", NewFunctionHandler(func(params []string) error {
					transferAmount = uint64(905)
					initialStates[1].value = transferAmount
					return nil
				}))

				// rollback function (not used in this case)
				rollback := func() {
					blockTime = int64(0)
					transferAmount = uint64(0)
					initialStates[0].value = blockTime
					initialStates[1].value = transferAmount
				}

				return initialStates, rollback
			},
			expectError: true,
			validate: func(t *testing.T, states []stateChange) {
				// should not be changed
				uassert.Equal(t, states[0].value, int64(0))
				uassert.Equal(t, states[1].value, uint64(0))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// create a test registry
			registry := NewParameterRegistry()
			initialStates, rollback := tt.setupMock(registry)

			// create a test proposal
			proposal := &ProposalInfo{
				ProposalType: ParameterChange,
				State: ProposalStateInfo{
					State:     StatePassed,
					Timestamp: 0,
				},
				Execution: ExecutionInfo{
					Msgs: tt.msgs,
				},
			}

			// create an execution context
			ctx := &ExecutionContext{
				ProposalId: 1,
				Now:        uint64(time.Now().Unix()),
				Config:     &Config{},
				Proposal:   proposal,
			}

			err := executeProposal(ctx, registry)
			// if error occurs, execute rollback
			if err != nil {
				rollback()
			}

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}

			// validate state
			if tt.validate != nil {
				tt.validate(t, initialStates)
			}
		})
	}
}
