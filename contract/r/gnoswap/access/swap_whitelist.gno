package access

import (
	"chain/runtime"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"
)

// Router whitelist storage
var swapWhitelist map[address]bool

func init() {
	swapWhitelist = make(map[address]bool)
}

// UpdateSwapWhiteList adds a router address to the swap whitelist.
// Panics if router address is invalid.
// Only admin or governance can call this function.
func UpdateSwapWhiteList(cur realm, router address) {
	caller := runtime.PreviousRealm().Address()
	AssertIsAdminOrGovernance(caller)

	if !router.IsValid() {
		panic(ufmt.Errorf("invalid router address: %s", router))
	}

	// Add or update the router in the whitelist
	swapWhitelist[router] = true
}

// RemoveFromSwapWhiteList removes a router address from the swap whitelist.
// Does nothing if the router is not in the whitelist.
// Only admin or governance can call this function.
func RemoveFromSwapWhiteList(cur realm, router address) {
	caller := runtime.PreviousRealm().Address()
	AssertIsAdminOrGovernance(caller)

	delete(swapWhitelist, router)
}

// IsSwapWhitelisted returns true if the address is either the official router
// or is in the swap whitelist. Returns false otherwise.
func IsSwapWhitelisted(addr address) bool {
	// Check if it's the official router first
	//
	// Note: While it's a common pattern to store the router's address
	// in a global variable to prevent unnecessary function calls,
	// this function is called infrequently and retrieves the address internally
	// to respond to address changes.
	officialRouter, ok := GetAddress(prbac.ROLE_ROUTER.String())
	if ok && addr == officialRouter {
		return true
	}

	// Then check whitelist
	return swapWhitelist[addr]
}

// GetWhitelistedSwaps returns all whitelisted router addresses including
// the official router address if it exists.
func GetWhitelistedSwaps() []address {
	routers := make([]address, 0, len(swapWhitelist)+1)

	// Include official router
	officialRouter, ok := GetAddress(prbac.ROLE_ROUTER.String())
	if ok {
		routers = append(routers, officialRouter)
	}

	// Add whitelisted routers (skip if already added as official router)
	for router := range swapWhitelist {
		if ok && router == officialRouter {
			continue // Skip duplicate
		}
		routers = append(routers, router)
	}

	return routers
}
