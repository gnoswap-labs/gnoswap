package v1

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/access"
)

func TestAssertIsAdminOrGovStaker(t *testing.T) {
	tests := []struct {
		name        string
		setupFn     func() address
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "success - admin caller",
			setupFn: func() address {
				addr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
				return addr
			},
			shouldPanic: false,
		},
		{
			name: "success - gov/staker caller",
			setupFn: func() address {
				addr, _ := access.GetAddress(prbac.ROLE_GOV_STAKER.String())
				return addr
			},
			shouldPanic: false,
		},
		{
			name: "fail - unauthorized caller (regular user)",
			setupFn: func() address {
				return testutils.TestAddress("random_user")
			},
			shouldPanic: true,
			panicMsg:    "unauthorized: caller",
		},
		{
			name: "fail - pool caller (not admin or gov/staker)",
			setupFn: func() address {
				addr, _ := access.GetAddress(prbac.ROLE_POOL.String())
				return addr
			},
			shouldPanic: true,
			panicMsg:    "unauthorized: caller",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			caller := tt.setupFn()

			if tt.shouldPanic {
				defer func() {
					r := recover()
					if r == nil {
						t.Errorf("expected panic but got none")
						return
					}

					panicMsg := ""
					switch v := r.(type) {
					case string:
						panicMsg = v
					case error:
						panicMsg = v.Error()
					}

					if tt.panicMsg != "" {
						uassert.True(t, contains(panicMsg, tt.panicMsg),
							"expected panic message to contain '"+tt.panicMsg+"', got: "+panicMsg)
					}
				}()
			}

			assertIsAdminOrGovStaker(caller)
		})
	}
}

func TestAssertIsPoolOrPositionOrRouterOrStaker(t *testing.T) {
	tests := []struct {
		name        string
		setupFn     func() address
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "success - pool caller",
			setupFn: func() address {
				addr, _ := access.GetAddress(prbac.ROLE_POOL.String())
				return addr
			},
			shouldPanic: false,
		},
		{
			name: "success - position caller",
			setupFn: func() address {
				addr, _ := access.GetAddress(prbac.ROLE_POSITION.String())
				return addr
			},
			shouldPanic: false,
		},
		{
			name: "success - router caller",
			setupFn: func() address {
				addr, _ := access.GetAddress(prbac.ROLE_ROUTER.String())
				return addr
			},
			shouldPanic: false,
		},
		{
			name: "success - staker caller",
			setupFn: func() address {
				addr, _ := access.GetAddress(prbac.ROLE_STAKER.String())
				return addr
			},
			shouldPanic: false,
		},
		{
			name: "fail - unauthorized caller",
			setupFn: func() address {
				return testutils.TestAddress("unauthorized_user")
			},
			shouldPanic: true,
			panicMsg:    "unauthorized: caller",
		},
		{
			name: "fail - admin caller (not pool/position/router/staker)",
			setupFn: func() address {
				addr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
				return addr
			},
			shouldPanic: true,
			panicMsg:    "unauthorized: caller",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			caller := tt.setupFn()

			if tt.shouldPanic {
				defer func() {
					r := recover()
					if r == nil {
						t.Errorf("expected panic but got none")
						return
					}

					panicMsg := ""
					switch v := r.(type) {
					case string:
						panicMsg = v
					case error:
						panicMsg = v.Error()
					}

					if tt.panicMsg != "" {
						uassert.True(t, contains(panicMsg, tt.panicMsg),
							"expected panic message to contain '"+tt.panicMsg+"', got: "+panicMsg)
					}
				}()
			}

			assertIsPoolOrPositionOrRouterOrStaker(caller)
		})
	}
}

func TestAssertIsValidPercent(t *testing.T) {
	tests := []struct {
		name        string
		pct         int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "success - valid 0%",
			pct:         0,
			shouldPanic: false,
		},
		{
			name:        "success - valid 50%",
			pct:         5000,
			shouldPanic: false,
		},
		{
			name:        "success - valid 100%",
			pct:         10000,
			shouldPanic: false,
		},
		{
			name:        "fail - negative percentage",
			pct:         -1,
			shouldPanic: true,
			panicMsg:    "should not be smaller than 0",
		},
		{
			name:        "fail - percentage > 10000",
			pct:         10001,
			shouldPanic: true,
			panicMsg:    "should not be bigger than 10000",
		},
		{
			name:        "fail - large negative",
			pct:         -100,
			shouldPanic: true,
			panicMsg:    "should not be smaller than 0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					r := recover()
					if r == nil {
						t.Errorf("expected panic but got none")
						return
					}

					panicMsg := ""
					switch v := r.(type) {
					case string:
						panicMsg = v
					case error:
						panicMsg = v.Error()
					}

					if tt.panicMsg != "" {
						uassert.True(t, contains(panicMsg, tt.panicMsg),
							"expected panic message to contain '"+tt.panicMsg+"', got: "+panicMsg)
					}
				}()
			}

			assertIsValidPercent(tt.pct)
		})
	}
}

// Helper function to check if a string contains a substring
func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(substr) == 0 ||
		(len(s) > 0 && len(substr) > 0 && findSubstring(s, substr)))
}

func findSubstring(s, substr string) bool {
	if len(substr) == 0 {
		return true
	}
	if len(s) < len(substr) {
		return false
	}

	for i := 0; i <= len(s)-len(substr); i++ {
		match := true
		for j := 0; j < len(substr); j++ {
			if s[i+j] != substr[j] {
				match = false
				break
			}
		}
		if match {
			return true
		}
	}
	return false
}
