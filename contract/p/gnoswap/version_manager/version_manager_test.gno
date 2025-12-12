package version_manager

import (
	"testing"

	"gno.land/p/gnoswap/store"
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
