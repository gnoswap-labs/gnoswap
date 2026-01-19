package v1

import (
	"math"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	pl "gno.land/r/gnoswap/pool"
	sr "gno.land/r/gnoswap/staker"
)

// Test pctToIndex function
func TestPctToIndex(t *testing.T) {
	tests := []struct {
		name        string
		pct         int64
		expected    int
		expectPanic bool
		panicMsg    string
	}{
		{
			name:        "30% converts to index 0",
			pct:         30,
			expected:    0,
			expectPanic: false,
		},
		{
			name:        "50% converts to index 1",
			pct:         50,
			expected:    1,
			expectPanic: false,
		},
		{
			name:        "70% converts to index 2",
			pct:         70,
			expected:    2,
			expectPanic: false,
		},
		{
			name:        "100% converts to index 3",
			pct:         100,
			expected:    3,
			expectPanic: false,
		},
		{
			name:        "invalid percentage 40",
			pct:         40,
			expectPanic: true,
			panicMsg:    "pct is not valid",
		},
		{
			name:        "invalid percentage 0",
			pct:         0,
			expectPanic: true,
			panicMsg:    "pct is not valid",
		},
		{
			name:        "invalid percentage 200",
			pct:         200,
			expectPanic: true,
			panicMsg:    "pct is not valid",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				uassert.PanicsContains(t, tt.panicMsg, func() {
					pctToIndex(tt.pct)
				})
			} else {
				result := pctToIndex(tt.pct)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

// Test setPoolTier internal function
func TestSetPoolTier(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	// Create a test pool
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	pool := sr.NewPool(poolPath, 100)
	instance.getPools().set(poolPath, pool)

	tests := []struct {
		name        string
		poolPath    string
		tier        uint64
		expectPanic bool
	}{
		{
			name:        "set tier 1",
			poolPath:    poolPath,
			tier:        1,
			expectPanic: false,
		},
		{
			name:        "set tier 2",
			poolPath:    poolPath,
			tier:        2,
			expectPanic: false,
		},
		{
			name:        "set tier 3",
			poolPath:    poolPath,
			tier:        3,
			expectPanic: false,
		},
		{
			name:        "set tier 0 (NOT_EMISSION_TARGET_TIER)",
			poolPath:    poolPath,
			tier:        NOT_EMISSION_TARGET_TIER,
			expectPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			currentTime := int64(100)
			if tt.expectPanic {
				uassert.PanicsContains(t, "panic", func() {
					instance.setPoolTier(tt.poolPath, tt.tier, currentTime)
				})
			} else {
				uassert.NotPanics(t, func() {
					instance.setPoolTier(tt.poolPath, tt.tier, currentTime)
				})

				// Verify tier was set
				poolTier := instance.getPoolTier()
				currentTier := poolTier.CurrentTier(tt.poolPath)
				uassert.Equal(t, tt.tier, currentTier)
			}
		})
	}
}

// Test changePoolTier internal function
func TestChangePoolTier(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	// Create a test pool
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	pool := sr.NewPool(poolPath, 100)
	instance.getPools().set(poolPath, pool)

	currentTime := int64(100)

	// Set initial tier
	instance.setPoolTier(poolPath, 1, currentTime)

	tests := []struct {
		name         string
		newTier      uint64
		expectedPrev uint64
		expectedNew  uint64
	}{
		{
			name:         "change from tier 1 to tier 2",
			newTier:      2,
			expectedPrev: 1,
			expectedNew:  2,
		},
		{
			name:         "change from tier 2 to tier 3",
			newTier:      3,
			expectedPrev: 2,
			expectedNew:  3,
		},
		{
			name:         "change from tier 3 to tier 0",
			newTier:      NOT_EMISSION_TARGET_TIER,
			expectedPrev: 3,
			expectedNew:  NOT_EMISSION_TARGET_TIER,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			prevTier, newTier := instance.changePoolTier(poolPath, tt.newTier, currentTime)

			uassert.Equal(t, tt.expectedPrev, prevTier)
			uassert.Equal(t, tt.expectedNew, newTier)

			// Verify tier was changed in pool tier structure
			poolTier := instance.getPoolTier()
			currentTier := poolTier.CurrentTier(poolPath)
			uassert.Equal(t, tt.expectedNew, currentTier)
		})
	}
}

// Test removePoolTier internal function
func TestRemovePoolTier(t *testing.T) {
	initStakerTest(t)
	instance := getMockInstance()

	// Create a test pool
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"
	pool := sr.NewPool(poolPath, 100)
	instance.getPools().set(poolPath, pool)

	currentTime := int64(100)

	// Set initial tier
	instance.setPoolTier(poolPath, 2, currentTime)

	// Verify tier was set
	poolTier := instance.getPoolTier()
	currentTier := poolTier.CurrentTier(poolPath)
	uassert.Equal(t, uint64(2), currentTier)

	// Remove tier
	instance.removePoolTier(poolPath, currentTime)

	// Verify tier was set to NOT_EMISSION_TARGET_TIER
	poolTier = instance.getPoolTier()
	currentTier = poolTier.CurrentTier(poolPath)
	uassert.Equal(t, NOT_EMISSION_TARGET_TIER, currentTier)
}

// Test setWarmUp internal function
func TestSetWarmUp(t *testing.T) {
	tests := []struct {
		name           string
		pct            int64
		timeDuration   int64
		expectPanic    bool
		expectPanicMsg string
	}{
		{
			name:         "set 30% warmup with 86400 duration",
			pct:          30,
			timeDuration: 86400,
			expectPanic:  false,
		},
		{
			name:         "set 50% warmup with 172800 duration",
			pct:          50,
			timeDuration: 172800,
			expectPanic:  false,
		},
		{
			name:         "set 70% warmup with 259200 duration",
			pct:          70,
			timeDuration: 259200,
			expectPanic:  false,
		},
		{
			name:         "set 100% warmup with maxInt64 duration",
			pct:          100,
			timeDuration: math.MaxInt64,
			expectPanic:  false,
		},
		{
			name:           "set 30% warmup with negative duration",
			pct:            100,
			timeDuration:   -1,
			expectPanic:    true,
			expectPanicMsg: "warmup duration cannot be negative",
		},
		{
			name:         "set 30% warmup with exactly one year duration",
			pct:          30,
			timeDuration: 365 * 86400,
			expectPanic:  false,
		},
		{
			name:           "set 30% warmup with greater than one year duration",
			pct:            30,
			timeDuration:   365*86400 + 1,
			expectPanic:    true,
			expectPanicMsg: "warmup duration cannot exceed 1 year (365 days)",
		},
		{
			name:           "set 100% warmup with invalid duration 345600",
			pct:            100,
			timeDuration:   345600,
			expectPanic:    true,
			expectPanicMsg: "last warmup tier must have duration of math.MaxInt64",
		},
		{
			name:           "invalid percentage 40",
			pct:            40,
			timeDuration:   86400,
			expectPanic:    true,
			expectPanicMsg: "pct is not valid",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)
			instance := getMockInstance()

			if tt.expectPanic {
				uassert.PanicsContains(t, tt.expectPanicMsg, func() {
					instance.setWarmUp(tt.pct, tt.timeDuration)
				})
			} else {
				uassert.NotPanics(t, func() {
					instance.setWarmUp(tt.pct, tt.timeDuration)
				})

				// Verify warmup was set
				warmupTemplate := instance.store.GetWarmupTemplate()
				uassert.NotNil(t, warmupTemplate)

				idx := pctToIndex(tt.pct)
				// Use TimeDuration instead of Duration
				uassert.Equal(t, tt.timeDuration, warmupTemplate[idx].TimeDuration)
			}
		})
	}
}

// Test NOT_EMISSION_TARGET_TIER constant
func TestNotEmissionTargetTier(t *testing.T) {
	uassert.Equal(t, uint64(0), NOT_EMISSION_TARGET_TIER)
}

// Test ChangePoolTier with permission
func TestChangePoolTierWithPermission(t *testing.T) {
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"

	tests := []struct {
		name             string
		caller           address
		tier             uint64
		expectedHasAbort bool
		expectedAbortMsg string
	}{
		{
			name:             "admin can change pool tier",
			caller:           getAdminAddress(t),
			tier:             1,
			expectedHasAbort: false,
			expectedAbortMsg: "",
		},
		{
			name:             "governance can change pool tier",
			caller:           getGovernanceAddress(t),
			tier:             1,
			expectedHasAbort: false,
			expectedAbortMsg: "",
		},
		{
			name:             "non-admin cannot change pool tier",
			caller:           testutils.TestAddress("non-admin"),
			tier:             2,
			expectedHasAbort: true,
			expectedAbortMsg: "unauthorized: caller g1dehkuttpv3kkjmjlta047h6lta047h6lj8fjdj is not admin or governance",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)

			testing.SetRealm(adminRealm)
			pl.SetPoolCreationFee(cross, 0)
			CreatePool(barPath, fooPath, fee3000, "79228162514264337593543950336", adminAddr)

			// Create pool in staker
			pool := sr.NewPool(poolPath, 100)
			getMockInstance().getPools().set(poolPath, pool)

			testing.SetRealm(testing.NewUserRealm(tt.caller))

			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
					mockInstanceSetPoolTier(poolPath, tt.tier)
				})
			} else {
				uassert.NotPanics(t, func() {
					mockInstanceSetPoolTier(poolPath, tt.tier)
				})
			}
		})
	}
}

// Test SetWarmUp with permission
func TestSetWarmUpWithPermission(t *testing.T) {
	initStakerTest(t)

	tests := []struct {
		name             string
		caller           address
		pct              int64
		duration         int64
		expectedHasAbort bool
		expectedAbortMsg string
	}{
		{
			name:             "admin can set warmup",
			caller:           getAdminAddress(t),
			pct:              30,
			duration:         86400,
			expectedHasAbort: false,
			expectedAbortMsg: "",
		},
		{
			name:             "governance can set warmup",
			caller:           getGovernanceAddress(t),
			pct:              30,
			duration:         86400,
			expectedHasAbort: false,
			expectedAbortMsg: "",
		},
		{
			name:             "non-admin cannot set warmup",
			caller:           testutils.TestAddress("non-admin"),
			pct:              50,
			duration:         172800,
			expectedHasAbort: true,
			expectedAbortMsg: "unauthorized: caller g1dehkuttpv3kkjmjlta047h6lta047h6lj8fjdj is not admin or governance",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(testing.NewUserRealm(tt.caller))

			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
						getMockInstance().SetWarmUp(tt.pct, tt.duration)
					}(cross)
				})
			} else {
				uassert.NotPanics(t, func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
						getMockInstance().SetWarmUp(tt.pct, tt.duration)
					}(cross)
				})
			}
		})
	}
}

// Test RemovePoolTier with permission
func TestRemovePoolTierWithPermission(t *testing.T) {
	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"

	tests := []struct {
		name             string
		caller           address
		expectedHasAbort bool
		expectedAbortMsg string
	}{
		{
			name:             "admin can remove pool tier",
			caller:           getAdminAddress(t),
			expectedHasAbort: false,
			expectedAbortMsg: "",
		},
		{
			name:             "governance can remove pool tier",
			caller:           getGovernanceAddress(t),
			expectedHasAbort: false,
			expectedAbortMsg: "",
		},
		{
			name:             "non-admin cannot remove pool tier",
			caller:           testutils.TestAddress("non-admin"),
			expectedHasAbort: true,
			expectedAbortMsg: "unauthorized: caller g1dehkuttpv3kkjmjlta047h6lta047h6lj8fjdj is not admin or governance",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initStakerTest(t)

			testing.SetRealm(adminRealm)
			pl.SetPoolCreationFee(cross, 0)
			CreatePool(barPath, fooPath, fee3000, "79228162514264337593543950336", adminAddr)

			// Create pool in staker
			pool := sr.NewPool(poolPath, 100)
			getMockInstance().getPools().set(poolPath, pool)

			// Reset tier before each test
			testing.SetRealm(adminRealm)
			mockInstanceSetPoolTier(poolPath, 2)

			testing.SetRealm(testing.NewUserRealm(tt.caller))

			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
						getMockInstance().RemovePoolTier(poolPath)
					}(cross)
				})
			} else {
				uassert.NotPanics(t, func() {
					func(cur realm) {
						testing.SetRealm(testing.NewCodeRealm(stakerPackagePath))
						getMockInstance().RemovePoolTier(poolPath)
					}(cross)
				})

				// Verify tier was removed
				poolTier := getMockInstance().getPoolTier()
				currentTier := poolTier.CurrentTier(poolPath)
				uassert.Equal(t, NOT_EMISSION_TARGET_TIER, currentTier)
			}
		})
	}
}
