package access

import (
	"std"

	"gno.land/p/nt/ufmt"
	prbac "gno.land/p/gnoswap/rbac"
)

// Router whitelist storage
var swapWhitelist map[std.Address]bool

func init() {
	swapWhitelist = make(map[std.Address]bool)
}

// UpdateSwapWhiteList adds a router address to the swap whitelist.
// Panics if router address is invalid.
// Only admin or governance can call this function.
func UpdateSwapWhiteList(cur realm, router std.Address) {
	caller := std.PreviousRealm().Address()
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
func RemoveFromSwapWhiteList(cur realm, router std.Address) {
	caller := std.PreviousRealm().Address()
	AssertIsAdminOrGovernance(caller)

	delete(swapWhitelist, router)
}

// IsSwapWhitelisted returns true if the address is either the official router
// or is in the swap whitelist. Returns false otherwise.
func IsSwapWhitelisted(addr std.Address) bool {
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
func GetWhitelistedSwaps() []std.Address {
	routers := make([]std.Address, 0, len(swapWhitelist)+1)

	// Include official router
	officialRouter, ok := GetAddress(prbac.ROLE_ROUTER.String())
	if ok {
		routers = append(routers, officialRouter)
	}

	// Add whitelisted routers
	for router := range swapWhitelist {
		routers = append(routers, router)
	}

	return routers
}
