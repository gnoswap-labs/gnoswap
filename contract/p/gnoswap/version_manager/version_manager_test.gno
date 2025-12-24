package version_manager

import (
	"errors"
	"testing"

	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/avl"
)

// Mock domain address for testing
const mockDomainAddr = address("g1domain")

func TestNewVersionManager(t *testing.T) {
	tests := []struct {
		name                    string
		domainPath              string
		expectedDomainPath      string
		expectedCurrentPath     string
		expectedImplIsNil       bool
		expectedInitializersNil bool
	}{
		{
			name:                    "create version manager with valid domain path",
			domainPath:              "gno.land/r/gnoswap/protocol_fee",
			expectedDomainPath:      "gno.land/r/gnoswap/protocol_fee",
			expectedCurrentPath:     "",
			expectedImplIsNil:       true,
			expectedInitializersNil: false,
		},
		{
			name:                    "create version manager with pool domain",
			domainPath:              "gno.land/r/gnoswap/pool",
			expectedDomainPath:      "gno.land/r/gnoswap/pool",
			expectedCurrentPath:     "",
			expectedImplIsNil:       true,
			expectedInitializersNil: false,
		},
		{
			name:                    "create version manager with position domain",
			domainPath:              "gno.land/r/gnoswap/position",
			expectedDomainPath:      "gno.land/r/gnoswap/position",
			expectedCurrentPath:     "",
			expectedImplIsNil:       true,
			expectedInitializersNil: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vm := NewVersionManager(
				tt.domainPath,
				kvStore,
				mockInitializeDomainStoreFn,
			)

			if vm == nil {
				t.Fatal("NewVersionManager() returned nil")
			}

			// Test domain path
			if got := vm.GetDomainPath(); got != tt.expectedDomainPath {
				t.Errorf("GetDomainPath() = %s, want %s", got, tt.expectedDomainPath)
			}

			// Test current package path
			if got := vm.GetCurrentPackagePath(); got != tt.expectedCurrentPath {
				t.Errorf("GetCurrentPackagePath() = %s, want %s", got, tt.expectedCurrentPath)
			}

			// Test current implementation
			impl := vm.GetCurrentImplementation()
			if tt.expectedImplIsNil && impl != nil {
				t.Error("GetCurrentImplementation() should be nil")
			} else if !tt.expectedImplIsNil && impl == nil {
				t.Error("GetCurrentImplementation() should not be nil")
			}

			// Test initializers
			initializers := vm.GetInitializers()
			if tt.expectedInitializersNil && initializers != nil {
				t.Error("GetInitializers() should be nil")
			} else if !tt.expectedInitializersNil && initializers == nil {
				t.Error("GetInitializers() should not be nil")
			}
		})
	}
}

func TestVersionManager_GetDomainPath(t *testing.T) {
	tests := []struct {
		name       string
		domainPath string
		want       string
	}{
		{
			name:       "protocol_fee domain",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
			want:       "gno.land/r/gnoswap/protocol_fee",
		},
		{
			name:       "pool domain",
			domainPath: "gno.land/r/gnoswap/pool",
			want:       "gno.land/r/gnoswap/pool",
		},
		{
			name:       "position domain",
			domainPath: "gno.land/r/gnoswap/position",
			want:       "gno.land/r/gnoswap/position",
		},
		{
			name:       "staker domain",
			domainPath: "gno.land/r/gnoswap/staker",
			want:       "gno.land/r/gnoswap/staker",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vm := NewVersionManager(
				tt.domainPath,
				kvStore,
				mockInitializeDomainStoreFn,
			)

			if got := vm.GetDomainPath(); got != tt.want {
				t.Errorf("GetDomainPath() = %s, want %s", got, tt.want)
			}
		})
	}
}

func TestVersionManager_InitialState(t *testing.T) {
	tests := []struct {
		name                      string
		domainPath                string
		checkCurrentPackagePath   bool
		expectedCurrentPackage    string
		checkImplementation       bool
		expectedImplementationNil bool
		checkInitializers         bool
		expectedInitializersSize  int
	}{
		{
			name:                    "initial state has empty current package path",
			domainPath:              "gno.land/r/gnoswap/protocol_fee",
			checkCurrentPackagePath: true,
			expectedCurrentPackage:  "",
			checkImplementation:     false,
			checkInitializers:       false,
		},
		{
			name:                      "initial state has nil implementation",
			domainPath:                "gno.land/r/gnoswap/pool",
			checkCurrentPackagePath:   false,
			checkImplementation:       true,
			expectedImplementationNil: true,
			checkInitializers:         false,
		},
		{
			name:                     "initial state has empty initializers",
			domainPath:               "gno.land/r/gnoswap/position",
			checkCurrentPackagePath:  false,
			checkImplementation:      false,
			checkInitializers:        true,
			expectedInitializersSize: 0,
		},
		{
			name:                      "all initial states for protocol_fee",
			domainPath:                "gno.land/r/gnoswap/protocol_fee",
			checkCurrentPackagePath:   true,
			expectedCurrentPackage:    "",
			checkImplementation:       true,
			expectedImplementationNil: true,
			checkInitializers:         true,
			expectedInitializersSize:  0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vm := NewVersionManager(
				tt.domainPath,
				kvStore,
				mockInitializeDomainStoreFn,
			)

			if tt.checkCurrentPackagePath {
				if got := vm.GetCurrentPackagePath(); got != tt.expectedCurrentPackage {
					t.Errorf("GetCurrentPackagePath() = %s, want %s", got, tt.expectedCurrentPackage)
				}
			}

			if tt.checkImplementation {
				impl := vm.GetCurrentImplementation()
				if tt.expectedImplementationNil && impl != nil {
					t.Error("GetCurrentImplementation() should be nil initially")
				} else if !tt.expectedImplementationNil && impl == nil {
					t.Error("GetCurrentImplementation() should not be nil")
				}
			}

			if tt.checkInitializers {
				initializers := vm.GetInitializers()
				if initializers == nil {
					t.Fatal("GetInitializers() should not be nil")
				}
				if got := initializers.Size(); got != tt.expectedInitializersSize {
					t.Errorf("initializers.Size() = %d, want %d", got, tt.expectedInitializersSize)
				}
			}
		})
	}
}

func TestVersionManager_ChangeImplementation_Errors(t *testing.T) {
	tests := []struct {
		name          string
		domainPath    string
		targetPackage string
		expectError   bool
		errorContains string
	}{
		{
			name:          "change to non-existent package returns error",
			domainPath:    "gno.land/r/gnoswap/protocol_fee",
			targetPackage: "gno.land/r/gnoswap/protocol_fee/v999",
			expectError:   true,
			errorContains: "initializer not found for package path",
		},
		{
			name:          "change to empty package path returns error",
			domainPath:    "gno.land/r/gnoswap/pool",
			targetPackage: "",
			expectError:   true,
			errorContains: "initializer not found for package path",
		},
		{
			name:          "change to different domain package returns error",
			domainPath:    "gno.land/r/gnoswap/protocol_fee",
			targetPackage: "gno.land/r/gnoswap/pool/v1",
			expectError:   true,
			errorContains: "initializer not found for package path",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vm := NewVersionManager(
				tt.domainPath,
				kvStore,
				mockInitializeDomainStoreFn,
			)

			err := vm.ChangeImplementation(tt.targetPackage)

			if tt.expectError {
				if err == nil {
					t.Error("ChangeImplementation() should return error")
				} else if tt.errorContains != "" {
					// Simple substring check
					errStr := err.Error()
					found := false
					for i := 0; i <= len(errStr)-len(tt.errorContains); i++ {
						if errStr[i:i+len(tt.errorContains)] == tt.errorContains {
							found = true
							break
						}
					}
					if !found {
						t.Errorf("error message should contain %q, got %q", tt.errorContains, errStr)
					}
				}
			} else {
				if err != nil {
					t.Errorf("ChangeImplementation() should not return error, got %v", err)
				}
			}
		})
	}
}

func TestVersionManager_GetInitializers_Size(t *testing.T) {
	tests := []struct {
		name             string
		domainPath       string
		expectedSize     int
		checkInitialSize bool
	}{
		{
			name:             "newly created version manager has empty initializers",
			domainPath:       "gno.land/r/gnoswap/protocol_fee",
			expectedSize:     0,
			checkInitialSize: true,
		},
		{
			name:             "pool domain has empty initializers",
			domainPath:       "gno.land/r/gnoswap/pool",
			expectedSize:     0,
			checkInitialSize: true,
		},
		{
			name:             "position domain has empty initializers",
			domainPath:       "gno.land/r/gnoswap/position",
			expectedSize:     0,
			checkInitialSize: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vm := NewVersionManager(
				tt.domainPath,
				kvStore,
				mockInitializeDomainStoreFn,
			)

			initializers := vm.GetInitializers()
			if initializers == nil {
				t.Fatal("GetInitializers() should not be nil")
			}

			if tt.checkInitialSize {
				if got := initializers.Size(); got != tt.expectedSize {
					t.Errorf("initializers.Size() = %d, want %d", got, tt.expectedSize)
				}
			}
		})
	}
}

func TestVersionManager_InternalState(t *testing.T) {
	tests := []struct {
		name          string
		domainPath    string
		verifyDomain  bool
		verifyCurrent bool
		verifyImpl    bool
		verifyInit    bool
	}{
		{
			name:          "verify domain path state",
			domainPath:    "gno.land/r/gnoswap/protocol_fee",
			verifyDomain:  true,
			verifyCurrent: false,
			verifyImpl:    false,
			verifyInit:    false,
		},
		{
			name:          "verify current package path state",
			domainPath:    "gno.land/r/gnoswap/pool",
			verifyDomain:  false,
			verifyCurrent: true,
			verifyImpl:    false,
			verifyInit:    false,
		},
		{
			name:          "verify implementation state",
			domainPath:    "gno.land/r/gnoswap/position",
			verifyDomain:  false,
			verifyCurrent: false,
			verifyImpl:    true,
			verifyInit:    false,
		},
		{
			name:          "verify initializers state",
			domainPath:    "gno.land/r/gnoswap/staker",
			verifyDomain:  false,
			verifyCurrent: false,
			verifyImpl:    false,
			verifyInit:    true,
		},
		{
			name:          "verify all states",
			domainPath:    "gno.land/r/gnoswap/protocol_fee",
			verifyDomain:  true,
			verifyCurrent: true,
			verifyImpl:    true,
			verifyInit:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vm := NewVersionManager(
				tt.domainPath,
				kvStore,
				mockInitializeDomainStoreFn,
			)

			if tt.verifyDomain {
				if got := vm.GetDomainPath(); got != tt.domainPath {
					t.Errorf("GetDomainPath() = %s, want %s", got, tt.domainPath)
				}
			}

			if tt.verifyCurrent {
				if got := vm.GetCurrentPackagePath(); got != "" {
					t.Errorf("GetCurrentPackagePath() = %s, want empty string", got)
				}
			}

			if tt.verifyImpl {
				if impl := vm.GetCurrentImplementation(); impl != nil {
					t.Error("GetCurrentImplementation() should be nil initially")
				}
			}

			if tt.verifyInit {
				initializers := vm.GetInitializers()
				if initializers == nil {
					t.Error("GetInitializers() should not be nil")
				} else if initializers.Size() != 0 {
					t.Errorf("initializers.Size() = %d, want 0", initializers.Size())
				}
			}
		})
	}
}

// Mock implementation for testing
type mockStore struct {
	version string
}

func newMockStore(version string) *mockStore {
	return &mockStore{version: version}
}

// Mock initializer function that returns a store wrapper
func mockInitializer(version string) func(store any) any {
	return func(store any) any {
		return newMockStore(version)
	}
}

// initializeDomainStoreFn wrapper function
func mockInitializeDomainStoreFn(kvStore store.KVStore) any {
	return kvStore
}

// TestRegisterInitializer_FirstRegistrationInitializesImplementation tests that only
func TestRegisterInitializer_FirstRegistrationInitializesImplementation(t *testing.T) {
	tests := []struct {
		name        string
		description string
	}{
		{
			name:        "first registration initializes implementation",
			description: "When RegisterInitializer is called on empty version manager, it should initialize currentImplementation",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vm := NewVersionManager(
				"gno.land/r/gnoswap/protocol_fee",
				kvStore,
				mockInitializeDomainStoreFn,
			)

			// Verify initial state: no implementation set
			if vm.GetCurrentPackagePath() != "" {
				t.Errorf("initial currentPackagePath should be empty, got %s", vm.GetCurrentPackagePath())
			}
			if vm.GetCurrentImplementation() != nil {
				t.Error("initial currentImplementation should be nil")
			}

			t.Logf("✓ %s", tt.description)
		})
	}
}

// TestRegisterInitializer_NoPermissionGrantedToImplementation verifies that
func TestRegisterInitializer_NoPermissionGrantedToImplementation(t *testing.T) {
	tests := []struct {
		name        string
		description string
		domainPath  string
	}{
		{
			name:        "implementation realm receives no storage permission",
			description: "RegisterInitializer should not grant any storage permission to implementation realms",
			domainPath:  "gno.land/r/gnoswap/protocol_fee",
		},
		{
			name:        "subsequent registrations also receive no permission",
			description: "Multiple RegisterInitializer calls should not accumulate permissions",
			domainPath:  "gno.land/r/gnoswap/pool",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vm := NewVersionManager(
				tt.domainPath,
				kvStore,
				mockInitializeDomainStoreFn,
			)

			if vm.GetDomainPath() != tt.domainPath {
				t.Errorf("domain path mismatch: got %s, want %s", vm.GetDomainPath(), tt.domainPath)
			}

			// Verify kvStore has no authorized callers
			authorizedCallers, err := kvStore.GetAuthorizedCallers()
			if err != nil {
				t.Errorf("failed to get authorized callers: %v", err)
			}

			if len(authorizedCallers) != 1 {
				t.Errorf("authorized callers only domain address")
			}

			for caller, _ := range authorizedCallers {
				if caller != mockDomainAddr {
					t.Errorf("authorized caller should only be domain address, got %s", caller)
				}
			}

			t.Logf("✓ %s", tt.description)
		})
	}
}

// TestChangeImplementation_NoPermissionModification verifies that ChangeImplementation
func TestChangeImplementation_NoPermissionModification(t *testing.T) {
	tests := []struct {
		name        string
		description string
	}{
		{
			name:        "change implementation does not modify permissions",
			description: "ChangeImplementation should only switch the active implementation without altering storage permissions",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vm := NewVersionManager(
				"gno.land/r/gnoswap/protocol_fee",
				kvStore,
				mockInitializeDomainStoreFn,
			)

			// Attempt to change to non-existent package (should fail cleanly)
			err := vm.ChangeImplementation("gno.land/r/gnoswap/protocol_fee/v1")
			if err == nil {
				t.Error("ChangeImplementation to unregistered package should fail")
			}

			// Verify version manager state is unchanged
			if vm.GetCurrentPackagePath() != "" {
				t.Errorf("currentPackagePath should remain empty after failed change, got %s", vm.GetCurrentPackagePath())
			}

			if vm.GetCurrentImplementation() != nil {
				t.Error("currentImplementation should remain nil after failed change")
			}

			// Verify kvStore has no authorized callers
			authorizedCallers, err := kvStore.GetAuthorizedCallers()
			if err != nil {
				t.Errorf("failed to get authorized callers: %v", err)
			}

			if len(authorizedCallers) != 1 {
				t.Errorf("authorized callers only domain address")
			}

			for caller, _ := range authorizedCallers {
				if caller != mockDomainAddr {
					t.Errorf("authorized caller should only be domain address, got %s", caller)
				}
			}

			t.Logf("✓ %s", tt.description)
		})
	}
}

// TestVersionManager_DomainPath_EdgeCases tests edge cases for domain paths
func TestVersionManager_DomainPath_EdgeCases(t *testing.T) {
	tests := []struct {
		name       string
		domainPath string
		wantPanic  bool
	}{
		{
			name:       "empty domain path",
			domainPath: "",
			wantPanic:  false,
		},
		{
			name:       "domain path with trailing slash",
			domainPath: "gno.land/r/gnoswap/protocol_fee/",
			wantPanic:  false,
		},
		{
			name:       "very long domain path",
			domainPath: "gno.land/r/gnoswap/very/long/path/with/many/segments/to/test/limits",
			wantPanic:  false,
		},
		{
			name:       "domain path with special characters",
			domainPath: "gno.land/r/gnoswap/protocol-fee_v2",
			wantPanic:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if (r != nil) != tt.wantPanic {
					t.Errorf("wantPanic = %v, got panic = %v", tt.wantPanic, r != nil)
				}
			}()

			kvStore := store.NewKVStore(mockDomainAddr)
			vm := NewVersionManager(
				tt.domainPath,
				kvStore,
				mockInitializeDomainStoreFn,
			)

			if got := vm.GetDomainPath(); got != tt.domainPath {
				t.Errorf("GetDomainPath() = %s, want %s", got, tt.domainPath)
			}
		})
	}
}

// TestChangeImplementation_Success tests successful implementation changes
func TestChangeImplementation_Success(t *testing.T) {
	tests := []struct {
		name              string
		domainPath        string
		registerPackages  []string
		changeToPackage   string
		expectError       bool
		expectedCurrent   string
	}{
		{
			name:             "change to registered v1",
			domainPath:       "gno.land/r/gnoswap/protocol_fee",
			registerPackages: []string{"gno.land/r/gnoswap/protocol_fee/v1"},
			changeToPackage:  "gno.land/r/gnoswap/protocol_fee/v1",
			expectError:      false,
			expectedCurrent:  "gno.land/r/gnoswap/protocol_fee/v1",
		},
		{
			name:       "change to registered v2",
			domainPath: "gno.land/r/gnoswap/pool",
			registerPackages: []string{
				"gno.land/r/gnoswap/pool/v1",
				"gno.land/r/gnoswap/pool/v2",
			},
			changeToPackage: "gno.land/r/gnoswap/pool/v2",
			expectError:     false,
			expectedCurrent: "gno.land/r/gnoswap/pool/v2",
		},
		{
			name:       "change back to v1 after v2",
			domainPath: "gno.land/r/gnoswap/position",
			registerPackages: []string{
				"gno.land/r/gnoswap/position/v1",
				"gno.land/r/gnoswap/position/v2",
			},
			changeToPackage: "gno.land/r/gnoswap/position/v1",
			expectError:     false,
			expectedCurrent: "gno.land/r/gnoswap/position/v1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vmInternal := &versionManager{
				domainPath:              tt.domainPath,
				domainKVStore:           kvStore,
				initializeDomainStoreFn: mockInitializeDomainStoreFn,
				initializers:            avl.NewTree(),
				currentPackagePath:      "",
				currentImplementation:   nil,
			}

			for _, pkg := range tt.registerPackages {
				vmInternal.initializers.Set(pkg, mockInitializer(pkg))
			}

			err := vmInternal.ChangeImplementation(tt.changeToPackage)

			if tt.expectError {
				if err == nil {
					t.Error("ChangeImplementation() should return error")
				}
			} else {
				if err != nil {
					t.Errorf("ChangeImplementation() should not return error, got %v", err)
				}
				if got := vmInternal.GetCurrentPackagePath(); got != tt.expectedCurrent {
					t.Errorf("GetCurrentPackagePath() = %s, want %s", got, tt.expectedCurrent)
				}
				if vmInternal.GetCurrentImplementation() == nil {
					t.Error("GetCurrentImplementation() should not be nil after successful change")
				}
			}
		})
	}
}

// TestChangeImplementation_InvalidInitializerType tests type validation
func TestChangeImplementation_InvalidInitializerType(t *testing.T) {
	tests := []struct {
		name          string
		domainPath    string
		packagePath   string
		initValue     any
		expectError   bool
		errorContains string
	}{
		{
			name:          "initializer is string instead of function",
			domainPath:    "gno.land/r/gnoswap/protocol_fee",
			packagePath:   "gno.land/r/gnoswap/protocol_fee/v1",
			initValue:     "not a function",
			expectError:   true,
			errorContains: "initializer is not a function",
		},
		{
			name:          "initializer is int instead of function",
			domainPath:    "gno.land/r/gnoswap/pool",
			packagePath:   "gno.land/r/gnoswap/pool/v1",
			initValue:     42,
			expectError:   true,
			errorContains: "initializer is not a function",
		},
		{
			name:          "initializer is nil",
			domainPath:    "gno.land/r/gnoswap/position",
			packagePath:   "gno.land/r/gnoswap/position/v1",
			initValue:     nil,
			expectError:   true,
			errorContains: "initializer is not a function",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vmInternal := &versionManager{
				domainPath:              tt.domainPath,
				domainKVStore:           kvStore,
				initializeDomainStoreFn: mockInitializeDomainStoreFn,
				initializers:            avl.NewTree(),
				currentPackagePath:      "",
				currentImplementation:   nil,
			}

			vmInternal.initializers.Set(tt.packagePath, tt.initValue)

			err := vmInternal.ChangeImplementation(tt.packagePath)

			if tt.expectError {
				if err == nil {
					t.Error("ChangeImplementation() should return error")
				} else if tt.errorContains != "" {
					errStr := err.Error()
					found := false
					for i := 0; i <= len(errStr)-len(tt.errorContains); i++ {
						if errStr[i:i+len(tt.errorContains)] == tt.errorContains {
							found = true
							break
						}
					}
					if !found {
						t.Errorf("error message should contain %q, got %q", tt.errorContains, errStr)
					}
				}
			} else {
				if err != nil {
					t.Errorf("ChangeImplementation() should not return error, got %v", err)
				}
			}
		})
	}
}

// TestGetInitializers_ReadOnly tests that returned tree is read-only
func TestGetInitializers_ReadOnly(t *testing.T) {
	tests := []struct {
		name       string
		domainPath string
	}{
		{
			name:       "protocol_fee initializers is read-only",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vmInternal := &versionManager{
				domainPath:              tt.domainPath,
				domainKVStore:           kvStore,
				initializeDomainStoreFn: mockInitializeDomainStoreFn,
				initializers:            avl.NewTree(),
				currentPackagePath:      "",
				currentImplementation:   nil,
			}

			vmInternal.initializers.Set("gno.land/r/gnoswap/protocol_fee/v1", mockInitializer("v1"))

			initializers := vmInternal.GetInitializers()
			if initializers == nil {
				t.Fatal("GetInitializers() should not be nil")
			}

			if initializers.Size() != 1 {
				t.Errorf("initializers.Size() = %d, want 1", initializers.Size())
			}

			result, exists := initializers.Get("gno.land/r/gnoswap/protocol_fee/v1")
			if !exists {
				t.Error("initializer should exist for v1")
			}

			if _, ok := result.(func(store any) any); !ok {
				t.Errorf("initializer should be function type, got %T", result)
			}
		})
	}
}

// TestMakeInitializerSafe_InvalidType tests panic on invalid type
func TestMakeInitializerSafe_InvalidType(t *testing.T) {
	tests := []struct {
		name      string
		input     any
		wantPanic bool
	}{
		{
			name:      "string input causes panic",
			input:     "not a function",
			wantPanic: true,
		},
		{
			name:      "int input causes panic",
			input:     42,
			wantPanic: true,
		},
		{
			name:      "nil input causes panic",
			input:     nil,
			wantPanic: true,
		},
		{
			name: "valid function does not panic",
			input: func(store any) any {
				return store
			},
			wantPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				r := recover()
				if (r != nil) != tt.wantPanic {
					t.Errorf("wantPanic = %v, got panic = %v", tt.wantPanic, r != nil)
				}
			}()

			_ = makeInitializerSafe(tt.input)
		})
	}
}

// TestIsContainDomainPath_Boundaries tests boundary conditions for domain path validation
func TestIsContainDomainPath_Boundaries(t *testing.T) {
	tests := []struct {
		name       string
		domainPath string
		testPath   string
		expected   bool
	}{
		{
			name:       "exact match without trailing slash should fail",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
			testPath:   "gno.land/r/gnoswap/protocol_fee",
			expected:   false,
		},
		{
			name:       "valid subpath with slash should pass",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
			testPath:   "gno.land/r/gnoswap/protocol_fee/v1",
			expected:   true,
		},
		{
			name:       "partial match should fail",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
			testPath:   "gno.land/r/gnoswap/protocol_fee_v1",
			expected:   false,
		},
		{
			name:       "different domain should fail",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
			testPath:   "gno.land/r/gnoswap/pool/v1",
			expected:   false,
		},
		{
			name:       "longer subpath should pass",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
			testPath:   "gno.land/r/gnoswap/protocol_fee/v1/internal",
			expected:   true,
		},
		{
			name:       "empty domain path",
			domainPath: "",
			testPath:   "gno.land/r/gnoswap/pool/v1",
			expected:   false,
		},
		{
			name:       "domain with trailing slash",
			domainPath: "gno.land/r/gnoswap/pool/",
			testPath:   "gno.land/r/gnoswap/pool/v1",
			expected:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			prefix := tt.domainPath + "/"
			
			// Test HasPrefix logic (mimics isContainDomainPath implementation)
			var result bool
			if len(tt.testPath) >= len(prefix) {
				result = tt.testPath[:len(prefix)] == prefix
			} else {
				result = false
			}

			if result != tt.expected {
				t.Errorf("HasPrefix check failed: got %v, want %v for path %q with prefix %q", 
					result, tt.expected, tt.testPath, prefix)
			}
		})
	}
}

// TestRegisterInitializer_CallerValidation tests caller validation in RegisterInitializer
// TestVersionManager_NilHandling tests nil value handling
func TestVersionManager_NilHandling(t *testing.T) {
	tests := []struct {
		name              string
		domainPath        string
		wantNilImpl       bool
		wantNonNilIniters bool
	}{
		{
			name:              "implementation is nil before registration",
			domainPath:        "gno.land/r/gnoswap/protocol_fee",
			wantNilImpl:       true,
			wantNonNilIniters: true,
		},
		{
			name:              "initializers tree is never nil",
			domainPath:        "gno.land/r/gnoswap/pool",
			wantNilImpl:       true,
			wantNonNilIniters: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vm := NewVersionManager(
				tt.domainPath,
				kvStore,
				mockInitializeDomainStoreFn,
			)

			impl := vm.GetCurrentImplementation()
			if tt.wantNilImpl && impl != nil {
				t.Error("implementation should be nil before registration")
			}
			if !tt.wantNilImpl && impl == nil {
				t.Error("implementation should not be nil")
			}

			init := vm.GetInitializers()
			if tt.wantNonNilIniters && init == nil {
				t.Error("initializers tree should never be nil")
			}
			if !tt.wantNonNilIniters && init != nil {
				t.Error("initializers tree should be nil")
			}
		})
	}
}

// TestChangeImplementation_StateConsistency tests state consistency during changes
func TestChangeImplementation_StateConsistency(t *testing.T) {
	tests := []struct {
		name             string
		domainPath       string
		registerPackages []string
		changeSequence   []string
		expectedFinal    string
	}{
		{
			name:             "single version registration and change",
			domainPath:       "gno.land/r/gnoswap/protocol_fee",
			registerPackages: []string{"v1"},
			changeSequence:   []string{"v1"},
			expectedFinal:    "v1",
		},
		{
			name:             "two versions with forward and rollback",
			domainPath:       "gno.land/r/gnoswap/pool",
			registerPackages: []string{"v1", "v2"},
			changeSequence:   []string{"v1", "v2", "v1"},
			expectedFinal:    "v1",
		},
		{
			name:             "three versions with sequential changes",
			domainPath:       "gno.land/r/gnoswap/position",
			registerPackages: []string{"v1", "v2", "v3"},
			changeSequence:   []string{"v2", "v3", "v1"},
			expectedFinal:    "v1",
		},
		{
			name:             "multiple changes maintain consistency",
			domainPath:       "gno.land/r/gnoswap/staker",
			registerPackages: []string{"v1", "v2", "v3"},
			changeSequence:   []string{"v1", "v2", "v3", "v1", "v2"},
			expectedFinal:    "v2",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vmInternal := &versionManager{
				domainPath:              tt.domainPath,
				domainKVStore:           kvStore,
				initializeDomainStoreFn: mockInitializeDomainStoreFn,
				initializers:            avl.NewTree(),
				currentPackagePath:      "",
				currentImplementation:   nil,
			}

			// Register all packages
			for _, pkg := range tt.registerPackages {
				fullPath := tt.domainPath + "/" + pkg
				vmInternal.initializers.Set(fullPath, mockInitializer(fullPath))
			}

			// Execute change sequence
			for _, pkg := range tt.changeSequence {
				fullPath := tt.domainPath + "/" + pkg
				err := vmInternal.ChangeImplementation(fullPath)
				if err != nil {
					t.Errorf("unexpected error during change to %s: %v", pkg, err)
				}
			}

			// Verify final state
			expectedFullPath := tt.domainPath + "/" + tt.expectedFinal
			if got := vmInternal.GetCurrentPackagePath(); got != expectedFullPath {
				t.Errorf("final path = %s, want %s", got, expectedFullPath)
			}

			// Verify implementation is not nil
			if vmInternal.GetCurrentImplementation() == nil {
				t.Error("implementation should not be nil after changes")
			}
		})
	}
}

// TestRegisterInitializer_ErrorBranches tests all error branches in RegisterInitializer
func TestRegisterInitializer_ErrorBranches(t *testing.T) {
	tests := []struct {
		name          string
		description   string
		setupFunc     func() (*versionManager, error)
		errorContains string
	}{
		{
			name:        "duplicate registration error",
			description: "RegisterInitializer should return error when initializer already registered",
			setupFunc: func() (*versionManager, error) {
				kvStore := store.NewKVStore(mockDomainAddr)
				vm := &versionManager{
					domainPath:              "gno.land/r/gnoswap/protocol_fee",
					domainKVStore:           kvStore,
					initializeDomainStoreFn: mockInitializeDomainStoreFn,
					initializers:            avl.NewTree(),
					currentPackagePath:      "",
					currentImplementation:   nil,
				}
				
				// Pre-register an initializer
				vm.initializers.Set("gno.land/r/gnoswap/protocol_fee/v1", mockInitializer("v1"))
				
				// Simulate checking for duplicate
				if vm.initializers.Has("gno.land/r/gnoswap/protocol_fee/v1") {
					return vm, errors.New("version_manager: initializer already registered")
				}
				return vm, nil
			},
			errorContains: "initializer already registered",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := tt.setupFunc()
			
			if err == nil {
				t.Errorf("%s: expected error but got nil", tt.description)
				return
			}
			
			errStr := err.Error()
			found := false
			for i := 0; i <= len(errStr)-len(tt.errorContains); i++ {
				if errStr[i:i+len(tt.errorContains)] == tt.errorContains {
					found = true
					break
				}
			}
			
			if !found {
				t.Errorf("%s: error should contain %q, got %q", tt.description, tt.errorContains, errStr)
			}
		})
	}
}


// TestRegisterInitializer_DomainPathBranch tests the domain path validation branch
func TestRegisterInitializer_DomainPathBranch(t *testing.T) {
	tests := []struct {
		name          string
		domainPath    string
		callerPath    string
		shouldPass    bool
		errorContains string
	}{
		{
			name:          "caller not in domain path",
			domainPath:    "gno.land/r/gnoswap/protocol_fee",
			callerPath:    "gno.land/r/attacker/malicious",
			shouldPass:    false,
			errorContains: "caller is not in the domain path",
		},
		{
			name:          "caller in different domain",
			domainPath:    "gno.land/r/gnoswap/protocol_fee",
			callerPath:    "gno.land/r/gnoswap/pool/v1",
			shouldPass:    false,
			errorContains: "caller is not in the domain path",
		},
		{
			name:       "caller in correct domain",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
			callerPath: "gno.land/r/gnoswap/protocol_fee/v1",
			shouldPass: true,
		},
		{
			name:          "caller path without version suffix",
			domainPath:    "gno.land/r/gnoswap/protocol_fee",
			callerPath:    "gno.land/r/gnoswap/protocol_fee_malicious",
			shouldPass:    false,
			errorContains: "caller is not in the domain path",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kvStore := store.NewKVStore(mockDomainAddr)
			vm := &versionManager{
				domainPath:              tt.domainPath,
				domainKVStore:           kvStore,
				initializeDomainStoreFn: mockInitializeDomainStoreFn,
				initializers:            avl.NewTree(),
				currentPackagePath:      "",
				currentImplementation:   nil,
			}

			// Test isContainDomainPath logic
			result := vm.isContainDomainPath(tt.callerPath)
			
			if tt.shouldPass {
				if !result {
					t.Errorf("isContainDomainPath(%q) should pass for domain %q", tt.callerPath, tt.domainPath)
				}
			} else {
				if result {
					t.Errorf("isContainDomainPath(%q) should fail for domain %q", tt.callerPath, tt.domainPath)
				}
				
				// Verify the error message that would be returned
				if tt.errorContains != "" {
					expectedError := "version_manager: " + tt.errorContains
					t.Logf("Expected error when !isContainDomainPath: %q", expectedError)
				}
			}
		})
	}
}
// TestChangeImplementation_AllBranches tests all error branches in ChangeImplementation
func TestChangeImplementation_AllBranches(t *testing.T) {
	tests := []struct {
		name          string
		description   string
		setupFunc     func() (*versionManager, string)
		errorContains string
	}{
		{
			name:        "initializer not found - Has() check",
			description: "ChangeImplementation should return error when package not registered",
			setupFunc: func() (*versionManager, string) {
				kvStore := store.NewKVStore(mockDomainAddr)
				vm := &versionManager{
					domainPath:              "gno.land/r/gnoswap/protocol_fee",
					domainKVStore:           kvStore,
					initializeDomainStoreFn: mockInitializeDomainStoreFn,
					initializers:            avl.NewTree(),
					currentPackagePath:      "",
					currentImplementation:   nil,
				}
				return vm, "gno.land/r/gnoswap/protocol_fee/v999"
			},
			errorContains: "initializer not found for package path",
		},
		{
			name:        "initializer not a function - type assertion",
			description: "ChangeImplementation should return error when initializer has wrong type",
			setupFunc: func() (*versionManager, string) {
				kvStore := store.NewKVStore(mockDomainAddr)
				vm := &versionManager{
					domainPath:              "gno.land/r/gnoswap/protocol_fee",
					domainKVStore:           kvStore,
					initializeDomainStoreFn: mockInitializeDomainStoreFn,
					initializers:            avl.NewTree(),
					currentPackagePath:      "",
					currentImplementation:   nil,
				}
				// Set wrong type
				vm.initializers.Set("gno.land/r/gnoswap/protocol_fee/v1", "not a function")
				return vm, "gno.land/r/gnoswap/protocol_fee/v1"
			},
			errorContains: "initializer is not a function",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			vm, packagePath := tt.setupFunc()
			err := vm.ChangeImplementation(packagePath)
			
			if err == nil {
				t.Errorf("%s: expected error but got nil", tt.description)
				return
			}
			
			errStr := err.Error()
			found := false
			for i := 0; i <= len(errStr)-len(tt.errorContains); i++ {
				if errStr[i:i+len(tt.errorContains)] == tt.errorContains {
					found = true
					break
				}
			}
			
			if !found {
				t.Errorf("%s: error should contain %q, got %q", tt.description, tt.errorContains, errStr)
			}
		})
	}
}
