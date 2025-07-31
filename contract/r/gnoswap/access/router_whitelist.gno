package access

import (
	"std"

	"gno.land/p/demo/ufmt"
	prbac "gno.land/p/gnoswap/rbac"
)

// Router whitelist storage
var routerWhitelist map[std.Address]bool

func init() {
	routerWhitelist = make(map[std.Address]bool)
}

// AddRouter adds a router address to the whitelist
// Only admin or governance can add routers
func AddRouter(cur realm, router std.Address) {
	caller := std.PreviousRealm().Address()
	AssertIsAdminOrGovernance(caller)

	if !router.IsValid() {
		panic(ufmt.Errorf("invalid router address: %s", router))
	}

	routerWhitelist[router] = true
}

// RemoveRouter removes a router address from the whitelist
// Only admin or governance can remove routers
func RemoveRouter(cur realm, router std.Address) {
	caller := std.PreviousRealm().Address()
	AssertIsAdminOrGovernance(caller)

	delete(routerWhitelist, router)
}

// IsRouterWhitelisted checks if an address is in the router whitelist
func IsRouterWhitelisted(addr std.Address) bool {
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
	return routerWhitelist[addr]
}

// GetWhitelistedRouters returns all whitelisted router addresses
func GetWhitelistedRouters() []std.Address {
	routers := make([]std.Address, 0, len(routerWhitelist)+1)

	// Include official router
	officialRouter, ok := GetAddress(prbac.ROLE_ROUTER.String())
	if ok {
		routers = append(routers, officialRouter)
	}

	// Add whitelisted routers
	for router := range routerWhitelist {
		routers = append(routers, router)
	}

	return routers
}

// AssertIsWhitelistedRouter checks if the caller is a whitelisted router
// This replaces the old AssertIsRouter for multi-router support
func AssertIsWhitelistedRouter(caller std.Address) {
	if !IsRouterWhitelisted(caller) {
		panic(ufmt.Errorf("unauthorized: caller %s is not a whitelisted router", caller))
	}
}
