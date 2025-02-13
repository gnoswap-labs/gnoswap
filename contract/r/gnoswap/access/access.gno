package access

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/rbac"
)

// contract state
var (
	// admin address that can manage roles and permissions
	admin std.Address

	// registered addresses mapped to their roles
	addressRegistry = avl.NewTree()

	// path registry for contract paths
	pathRegistry = avl.NewTree()
)

// Init initializes the contract with the admin address
func Init(adminAddr std.Address) {
	admin = adminAddr

	// Register basic roles
	must(rbac.RegisterRole(ROLE_ADMIN))
	must(rbac.RegisterRole(ROLE_GOVERNANCE))
	must(rbac.RegisterRole(ROLE_ROUTER))
	must(rbac.RegisterRole(ROLE_POOL))
	must(rbac.RegisterRole(ROLE_POSITION))
	must(rbac.RegisterRole(ROLE_STAKER))
	must(rbac.RegisterRole(ROLE_LAUNCHPAD))
	must(rbac.RegisterRole(ROLE_EMISSION))

	// Register admin permissions
	must(rbac.RegisterPermission(ROLE_ADMIN, "register_address", adminOnly))
	must(rbac.RegisterPermission(ROLE_ADMIN, "update_address", adminOnly))
	must(rbac.RegisterPermission(ROLE_ADMIN, "register_path", adminOnly))
}

// RegisterAddress registers a new address for a specific role
func RegisterAddress(caller std.Address, role string, addr std.Address, path string) error {
	// check admin permission
	if err := rbac.CheckPermission(ROLE_ADMIN, "register_address", caller); err != nil {
		return err
	}

	// verify role exists
	if err := rbac.CheckPermission(role, "", addr); err != nil {
		return ufmt.Errorf("invalid role: %s", role)
	}

	addrStr := addr.String()
	// check if address is already registered
	if addressRegistry.Has(addrStr) {
		return ufmt.Errorf("address already registered: %s", addrStr)
	}

	// register address
	addressRegistry.Set(addrStr, role)
	if path != "" {
		pathRegistry.Set(path, addrStr)
	}

	EmitAddressRegistered(role, addr, path)

	return nil
}

func UpdateAddress(caller std.Address, role string, oldAddr, newAddr std.Address, path string) error {
	// check admin permission
	if err := rbac.CheckPermission(ROLE_ADMIN, "update_address", caller); err != nil {
		return err
	}

	oldAddrStr := oldAddr.String()
	newAddrStr := newAddr.String()

	// checks if old address is already registered
	if !addressRegistry.Has(oldAddrStr) {
		return ufmt.Errorf("address not registered: %s", oldAddrStr)
	}

	// check if new address is already registered
	if addressRegistry.Has(newAddrStr) {
		return ufmt.Errorf("address already registered: %s", newAddrStr)
	}

	// update registry
	addressRegistry.Remove(oldAddrStr)
	addressRegistry.Set(newAddrStr, role)

	// update path registry
	if path != "" {
		pathRegistry.Set(path, newAddrStr)
	}

	EmitAddressUpdated(role, oldAddr, newAddr, path)

	return nil
}

func CheckCaller(role string, caller std.Address) error {
	rv, exists := addressRegistry.Get(caller.String())
	if !exists {
		return ufmt.Errorf("caller(%s) not registered", caller.String())
	}

	if rv != role {
		return ufmt.Errorf("caller(%s) does not have role(%s)", caller.String(), role)
	}

	return nil
}

func adminOnly(caller std.Address) error {
	if caller != admin {
		return ufmt.Errorf("caller(%s) is not admin", caller)
	}
	return nil
}
