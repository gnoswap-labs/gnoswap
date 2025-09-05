package access

import (
	"std"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestUpdateSwapWhiteList(t *testing.T) {
	tests := []struct {
		name        string
		caller      std.Address
		router      std.Address
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "admin can add valid router",
			caller:      testutils.TestAddress("admin"),
			router:      testutils.TestAddress("router1"),
			shouldPanic: false,
		},
		{
			name:        "governance can add valid router",
			caller:      testutils.TestAddress("governance"),
			router:      testutils.TestAddress("router2"),
			shouldPanic: false,
		},
		{
			name:        "non-authorized user cannot add router",
			caller:      testutils.TestAddress("user"),
			router:      testutils.TestAddress("router3"),
			shouldPanic: true,
			panicMsg:    "unauthorized: caller g1w4ek2ujlta047h6lta047h6lta047h6lkvk347 is not admin or governance",
		},
		{
			name:        "cannot add invalid address",
			caller:      testutils.TestAddress("admin"),
			router:      std.Address(""),
			shouldPanic: true,
			panicMsg:    "invalid router address: ",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			swapWhitelist = make(map[std.Address]bool)
			roleAddresses[prbac.ROLE_ADMIN.String()] = testutils.TestAddress("admin")
			roleAddresses[prbac.ROLE_GOVERNANCE.String()] = testutils.TestAddress("governance")

			// std.TestSetPrevRealm(std.NewUserRealm(tt.caller))
			testing.SetOriginCaller(tt.caller)

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					UpdateSwapWhiteList(cross, tt.router)
				})
			} else {
				UpdateSwapWhiteList(cross, tt.router)
				if !IsSwapWhitelisted(tt.router) {
					t.Errorf("Expected router to be whitelisted")
				}
			}
		})
	}
}

func TestRemoveFromSwapWhiteList(t *testing.T) {
	tests := []struct {
		name        string
		caller      std.Address
		router      std.Address
		shouldPanic bool
	}{
		{
			name:        "admin can remove router",
			caller:      testutils.TestAddress("admin"),
			router:      testutils.TestAddress("router1"),
			shouldPanic: false,
		},
		{
			name:        "governance can remove router",
			caller:      testutils.TestAddress("governance"),
			router:      testutils.TestAddress("router2"),
			shouldPanic: false,
		},
		{
			name:        "non-authorized user cannot remove router",
			caller:      testutils.TestAddress("user"),
			router:      testutils.TestAddress("router1"),
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			swapWhitelist = make(map[std.Address]bool)
			roleAddresses[prbac.ROLE_ADMIN.String()] = testutils.TestAddress("admin")
			roleAddresses[prbac.ROLE_GOVERNANCE.String()] = testutils.TestAddress("governance")

			// Pre-add router
			swapWhitelist[tt.router] = true

			testing.SetRealm(std.NewUserRealm(tt.caller))
			if tt.shouldPanic {
				expectedPanicMsg := ufmt.Sprintf("unauthorized: caller %s is not admin or governance", tt.caller.String())
				uassert.AbortsWithMessage(t, expectedPanicMsg, func() {
					RemoveFromSwapWhiteList(cross, tt.router)
				})
			} else {
				RemoveFromSwapWhiteList(cross, tt.router)
				if IsSwapWhitelisted(tt.router) {
					t.Errorf("Expected router to be removed from whitelist")
				}
			}
		})
	}
}

func TestIsSwapWhitelisted(t *testing.T) {
	officialRouter := testutils.TestAddress("official_router")
	whitelistedRouter := testutils.TestAddress("whitelisted")
	nonWhitelistedRouter := testutils.TestAddress("non_whitelisted")

	tests := []struct {
		name     string
		router   std.Address
		expected bool
	}{
		{
			name:     "official router is whitelisted",
			router:   officialRouter,
			expected: true,
		},
		{
			name:     "whitelisted router returns true",
			router:   whitelistedRouter,
			expected: true,
		},
		{
			name:     "non-whitelisted router returns false",
			router:   nonWhitelistedRouter,
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			swapWhitelist = make(map[std.Address]bool)
			roleAddresses[prbac.ROLE_ROUTER.String()] = officialRouter
			swapWhitelist[whitelistedRouter] = true

			result := IsSwapWhitelisted(tt.router)
			uassert.Equal(t, result, tt.expected, ufmt.Sprintf("expected %v, got %v", tt.expected, result))
		})
	}
}

func TestGetWhitelistedSwaps(t *testing.T) {
	tests := []struct {
		name             string
		officialRouter   std.Address
		whitelistRouters []std.Address
		expectedCount    int
	}{
		{
			name:             "only official router",
			officialRouter:   testutils.TestAddress("official"),
			whitelistRouters: []std.Address{},
			expectedCount:    1,
		},
		{
			name:           "official router plus whitelisted",
			officialRouter: testutils.TestAddress("official"),
			whitelistRouters: []std.Address{
				testutils.TestAddress("router1"),
				testutils.TestAddress("router2"),
			},
			expectedCount: 3,
		},
		{
			name:             "no official router",
			officialRouter:   std.Address(""),
			whitelistRouters: []std.Address{testutils.TestAddress("router1")},
			expectedCount:    1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			swapWhitelist = make(map[std.Address]bool)
			if tt.officialRouter.IsValid() {
				roleAddresses[prbac.ROLE_ROUTER.String()] = tt.officialRouter
			} else {
				delete(roleAddresses, prbac.ROLE_ROUTER.String())
			}

			for _, router := range tt.whitelistRouters {
				swapWhitelist[router] = true
			}

			routers := GetWhitelistedSwaps()
			uassert.Equal(t, len(routers), tt.expectedCount)
		})
	}
}
