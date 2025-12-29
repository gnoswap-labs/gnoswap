package version_manager

import (
	"errors"
	"testing"

	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
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

// TestChangeImplementation_Errors tests all error cases in ChangeImplementation
func TestChangeImplementation_Errors(t *testing.T) {
	tests := []struct {
		name          string
		setupFunc     func() (*versionManager, string)
		errorContains string
	}{
		// Package not found cases
		{
			name: "non-existent package",
			setupFunc: func() (*versionManager, string) {
				kvStore := store.NewKVStore(mockDomainAddr)
				vm := &versionManager{
					domainPath:              "gno.land/r/gnoswap/protocol_fee",
					domainKVStore:           kvStore,
					initializeDomainStoreFn: mockInitializeDomainStoreFn,
					initializers:            avl.NewTree(),
				}
				return vm, "gno.land/r/gnoswap/protocol_fee/v999"
			},
			errorContains: "initializer not found for package path",
		},
		{
			name: "empty package path",
			setupFunc: func() (*versionManager, string) {
				kvStore := store.NewKVStore(mockDomainAddr)
				vm := &versionManager{
					domainPath:              "gno.land/r/gnoswap/pool",
					domainKVStore:           kvStore,
					initializeDomainStoreFn: mockInitializeDomainStoreFn,
					initializers:            avl.NewTree(),
				}
				return vm, ""
			},
			errorContains: "initializer not found for package path",
		},
		// Invalid initializer type cases
		{
			name: "initializer is string",
			setupFunc: func() (*versionManager, string) {
				kvStore := store.NewKVStore(mockDomainAddr)
				vm := &versionManager{
					domainPath:              "gno.land/r/gnoswap/protocol_fee",
					domainKVStore:           kvStore,
					initializeDomainStoreFn: mockInitializeDomainStoreFn,
					initializers:            avl.NewTree(),
				}
				vm.initializers.Set("gno.land/r/gnoswap/protocol_fee/v1", "not a function")
				return vm, "gno.land/r/gnoswap/protocol_fee/v1"
			},
			errorContains: "initializer is not a function",
		},
		{
			name: "initializer is int",
			setupFunc: func() (*versionManager, string) {
				kvStore := store.NewKVStore(mockDomainAddr)
				vm := &versionManager{
					domainPath:              "gno.land/r/gnoswap/pool",
					domainKVStore:           kvStore,
					initializeDomainStoreFn: mockInitializeDomainStoreFn,
					initializers:            avl.NewTree(),
				}
				vm.initializers.Set("gno.land/r/gnoswap/pool/v1", 42)
				return vm, "gno.land/r/gnoswap/pool/v1"
			},
			errorContains: "initializer is not a function",
		},
		{
			name: "initializer is nil",
			setupFunc: func() (*versionManager, string) {
				kvStore := store.NewKVStore(mockDomainAddr)
				vm := &versionManager{
					domainPath:              "gno.land/r/gnoswap/position",
					domainKVStore:           kvStore,
					initializeDomainStoreFn: mockInitializeDomainStoreFn,
					initializers:            avl.NewTree(),
				}
				vm.initializers.Set("gno.land/r/gnoswap/position/v1", nil)
				return vm, "gno.land/r/gnoswap/position/v1"
			},
			errorContains: "initializer is not a function",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			vm, packagePath := tt.setupFunc()
			err := vm.ChangeImplementation(packagePath)
			uassert.ErrorContains(t, err, tt.errorContains)
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

// TestVersionManager_StoragePermission verifies that only domain address has storage permission
func TestVersionManager_StoragePermission(t *testing.T) {
	kvStore := store.NewKVStore(mockDomainAddr)
	vm := NewVersionManager(
		"gno.land/r/gnoswap/protocol_fee",
		kvStore,
		mockInitializeDomainStoreFn,
	)

	// Attempt to change to non-existent package (should fail)
	_ = vm.ChangeImplementation("gno.land/r/gnoswap/protocol_fee/v1")

	// Verify kvStore has only domain address as authorized caller
	authorizedCallers, err := kvStore.GetAuthorizedCallers()
	if err != nil {
		t.Fatalf("failed to get authorized callers: %v", err)
	}

	if len(authorizedCallers) != 1 {
		t.Errorf("expected 1 authorized caller, got %d", len(authorizedCallers))
	}

	for caller := range authorizedCallers {
		if caller != mockDomainAddr {
			t.Errorf("authorized caller should only be domain address, got %s", caller)
		}
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
		name             string
		domainPath       string
		registerPackages []string
		changeToPackage  string
		expectError      bool
		expectedCurrent  string
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

// TestGetInitializers_ReadOnly tests that returned tree is read-only
func TestGetInitializers_ReadOnly(t *testing.T) {
	kvStore := store.NewKVStore(mockDomainAddr)
	vm := &versionManager{
		domainPath:              "gno.land/r/gnoswap/protocol_fee",
		domainKVStore:           kvStore,
		initializeDomainStoreFn: mockInitializeDomainStoreFn,
		initializers:            avl.NewTree(),
	}

	vm.initializers.Set("gno.land/r/gnoswap/protocol_fee/v1", mockInitializer("v1"))

	initializers := vm.GetInitializers()
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

// TestIsContainDomainPath tests boundary conditions for domain path validation
//
// Note: The previousRealm.IsUser() check in RegisterInitializer is tested in integration test:
// tests/integration/testdata/upgradable/realm_can_register_initializer.txtar
func TestIsContainDomainPath(t *testing.T) {
	tests := []struct {
		name       string
		domainPath string
		testPath   string
		expected   bool
	}{
		// Valid cases
		{
			name:       "valid subpath",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
			testPath:   "gno.land/r/gnoswap/protocol_fee/v1",
			expected:   true,
		},
		{
			name:       "nested subpath",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
			testPath:   "gno.land/r/gnoswap/protocol_fee/v1/internal",
			expected:   true,
		},
		// Invalid cases - exact match
		{
			name:       "exact match without slash",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
			testPath:   "gno.land/r/gnoswap/protocol_fee",
			expected:   false,
		},
		// Invalid cases - partial match
		{
			name:       "partial match with suffix",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
			testPath:   "gno.land/r/gnoswap/protocol_fee_v1",
			expected:   false,
		},
		{
			name:       "partial match malicious suffix",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
			testPath:   "gno.land/r/gnoswap/protocol_fee_malicious",
			expected:   false,
		},
		// Invalid cases - different domain
		{
			name:       "different domain same org",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
			testPath:   "gno.land/r/gnoswap/pool/v1",
			expected:   false,
		},
		{
			name:       "completely different org",
			domainPath: "gno.land/r/gnoswap/protocol_fee",
			testPath:   "gno.land/r/attacker/malicious",
			expected:   false,
		},
		// Edge cases
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
			kvStore := store.NewKVStore(mockDomainAddr)
			vm := &versionManager{
				domainPath:              tt.domainPath,
				domainKVStore:           kvStore,
				initializeDomainStoreFn: mockInitializeDomainStoreFn,
				initializers:            avl.NewTree(),
			}

			result := vm.isContainDomainPath(tt.testPath)

			if result != tt.expected {
				t.Errorf("isContainDomainPath(%q) = %v, want %v", tt.testPath, result, tt.expected)
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

// tests all error branches in RegisterInitializer
func TestRegisterInitializer_ErrorBranches(t *testing.T) {
	tests := []struct {
		name          string
		setupFunc     func() error
		errorContains string
	}{
		{
			name: "nil initializer",
			setupFunc: func() error {
				kvStore := store.NewKVStore(mockDomainAddr)
				vm := NewVersionManager(
					"gno.land/r/gnoswap/protocol_fee",
					kvStore,
					mockInitializeDomainStoreFn,
				)
				return vm.RegisterInitializer(nil)
			},
			errorContains: "initializer cannot be nil",
		},
		{
			name: "duplicate registration",
			setupFunc: func() error {
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
					return errors.New("version_manager: initializer already registered")
				}
				return nil
			},
			errorContains: "initializer already registered",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.setupFunc()
			uassert.ErrorContains(t, err, tt.errorContains)
		})
	}
}

