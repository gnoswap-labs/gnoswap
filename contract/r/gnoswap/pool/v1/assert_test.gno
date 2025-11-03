package v1

import (
	"chain/runtime"
	"testing"

	"gno.land/p/nt/uassert"
)

func TestAssertIsNotAllowedEOA(t *testing.T) {
	tests := []struct {
		name         string
		currentRealm runtime.Realm
		shouldPanic  bool
		panicMsg     string
	}{
		{
			name:         "success - called from realm (not EOA)",
			currentRealm: testing.NewCodeRealm("gno.land/r/gnoswap/pool/v1"),
			shouldPanic:  false,
		},
		{
			name:         "fail - called from EOA",
			currentRealm: testing.NewUserRealm(adminAddr),
			shouldPanic:  true,
			panicMsg:     "[GNOSWAP-POOL-029] not access EOA || previousRealm(g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d) is EOA",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(tt.currentRealm)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					assertIsNotAllowedEOA(tt.currentRealm)
				})
			} else {
				assertIsNotAllowedEOA(tt.currentRealm)
			}
		})
	}
}

func TestAssertIsNotEqualsTokens(t *testing.T) {
	tests := []struct {
		name        string
		token0Path  string
		token1Path  string
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "success - different tokens",
			token0Path:  barPath,
			token1Path:  fooPath,
			shouldPanic: false,
		},
		{
			name:        "fail - same tokens",
			token0Path:  barPath,
			token1Path:  barPath,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-011] same token used in single pool || expected token0Path(gno.land/r/onbloc/bar) != token1Path(gno.land/r/onbloc/bar)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					assertIsNotEqualsTokens(tt.token0Path, tt.token1Path)
				})
			} else {
				assertIsNotEqualsTokens(tt.token0Path, tt.token1Path)
			}
		})
	}
}

func TestAssertIsSupportedFeeTier(t *testing.T) {
	tests := []struct {
		name        string
		fee         uint32
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "success - fee tier 100",
			fee:         100,
			shouldPanic: false,
		},
		{
			name:        "success - fee tier 500",
			fee:         500,
			shouldPanic: false,
		},
		{
			name:        "success - fee tier 3000",
			fee:         3000,
			shouldPanic: false,
		},
		{
			name:        "success - fee tier 10000",
			fee:         10000,
			shouldPanic: false,
		},
		{
			name:        "fail - unsupported fee tier 1000",
			fee:         1000,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-002] unsupported fee tier || expected fee(1000) to be one of 100, 500, 3000, 10000",
		},
		{
			name:        "fail - unsupported fee tier 0",
			fee:         0,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-002] unsupported fee tier || expected fee(0) to be one of 100, 500, 3000, 10000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					assertIsSupportedFeeTier(tt.fee)
				})
			} else {
				assertIsSupportedFeeTier(tt.fee)
			}
		})
	}
}

func TestAssertIsNotExistsPoolPath(t *testing.T) {
	tests := []struct {
		name        string
		setupFn     func(t *testing.T)
		token0Path  string
		token1Path  string
		fee         uint32
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "success - pool does not exist",
			setupFn: func(t *testing.T) {
				initPoolTest(t)
			},
			token0Path:  barPath,
			token1Path:  fooPath,
			fee:         fee3000,
			shouldPanic: false,
		},
		{
			name: "fail - pool already exists",
			setupFn: func(t *testing.T) {
				initPoolTest(t)
				testing.SetRealm(testing.NewUserRealm(adminAddr))
				mockInstanceSetPoolCreationFee(0)

				testing.SetRealm(testing.NewUserRealm(adminAddr))
				mockInstanceCreatePool(barPath, fooPath, fee3000, "4295128740")
			},
			token0Path:  barPath,
			token1Path:  fooPath,
			fee:         fee3000,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-003] pool already created || expected poolPath(gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000) not to exist",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setupFn != nil {
				tt.setupFn(t)
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					assertIsNotExistsPoolPath(getMockInstance(), tt.token0Path, tt.token1Path, tt.fee)
				})
			} else {
				assertIsNotExistsPoolPath(getMockInstance(), tt.token0Path, tt.token1Path, tt.fee)
			}
		})
	}
}

func TestAssertAmountSpecifiedIsNotZero(t *testing.T) {
	tests := []struct {
		name            string
		amountSpecified string
		shouldPanic     bool
		panicMsg        string
	}{
		{
			name:            "success - positive amount",
			amountSpecified: "1000",
			shouldPanic:     false,
		},
		{
			name:            "success - negative amount",
			amountSpecified: "-1000",
			shouldPanic:     false,
		},
		{
			name:            "fail - zero amount",
			amountSpecified: "0",
			shouldPanic:     true,
			panicMsg:        "[GNOSWAP-POOL-015] invalid swap amount || amountSpecified == 0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					assertAmountSpecifiedIsNotZero(tt.amountSpecified)
				})
			} else {
				assertAmountSpecifiedIsNotZero(tt.amountSpecified)
			}
		})
	}
}

func TestAssertIsValidTokenOrder(t *testing.T) {
	tests := []struct {
		name        string
		token0Path  string
		token1Path  string
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "success - tokens in correct order",
			token0Path:  barPath,
			token1Path:  fooPath,
			shouldPanic: false,
		},
		{
			name:        "fail - tokens not in order (equal)",
			token0Path:  barPath,
			token1Path:  barPath,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-006] invalid input data || expected token0Path(gno.land/r/onbloc/bar) < token1Path(gno.land/r/onbloc/bar)",
		},
		{
			name:        "fail - tokens in reverse order",
			token0Path:  fooPath,
			token1Path:  barPath,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-POOL-006] invalid input data || expected token0Path(gno.land/r/onbloc/foo) < token1Path(gno.land/r/onbloc/bar)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					assertIsValidTokenOrder(tt.token0Path, tt.token1Path)
				})
			} else {
				assertIsValidTokenOrder(tt.token0Path, tt.token1Path)
			}
		})
	}
}
