package access

import (
	"std"

	"gno.land/p/demo/ufmt"
	prbac "gno.land/p/gnoswap/rbac"
)

// Router whitelist storage
var swapWhitelist map[std.Address]bool

func init() {
	swapWhitelist = make(map[std.Address]bool)
}

// UpdateSwapWhiteList adds a address to the whitelist
// Only admin or governance can add custom routers
func UpdateSwapWhiteList(cur realm, router std.Address) {
	caller := std.PreviousRealm().Address()
	AssertIsAdminOrGovernance(caller)

	if !router.IsValid() {
		panic(ufmt.Errorf("invalid router address: %s", router))
	}

	swapWhitelist[router] = true
}

// RemoveFromSwapWhiteList removes a router address from the whitelist
// Only admin or governance can remove routers
func RemoveFromSwapWhiteList(cur realm, router std.Address) {
	caller := std.PreviousRealm().Address()
	AssertIsAdminOrGovernance(caller)

	delete(swapWhitelist, router)
}

// IsSwapWhitelisted checks if an address is in the swap whitelist
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

// GetWhitelistedSwaps returns all whitelisted router addresses
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

// AssertIsWhitelistedSwap checks if the caller is a whitelisted router
// This replaces the old AssertIsRouter for multi-router support
func AssertIsWhitelistedSwap(caller std.Address) {
	if !IsSwapWhitelisted(caller) {
		panic(ufmt.Errorf("unauthorized: caller %s is not a whitelisted router", caller))
	}
}
