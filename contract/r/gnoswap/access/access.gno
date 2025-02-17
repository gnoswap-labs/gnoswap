package access

import (
	"std"

	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/rbac"
)

var currentConfig *Config

// Config contains all the addresses needed for access control
type Config struct {
	Roles map[string]std.Address
}

// DefaultConfig returns an empty config with zero addresses
func DefaultConfig() *Config {
	return &Config{
		Roles: make(map[string]std.Address),
	}
}

// createAddressChecker creates a permission checker for a specific address
func createAddressChecker(addr std.Address, roleName string) prbac.PermissionChecker {
	return func(caller std.Address) error {
		if caller != addr {
			return ufmt.Errorf("caller(%s) is not authorized for role %s", caller.String(), roleName)
		}
		return nil
	}
}

// Initialize registers all roles and permissions to the global RBAC manager
func Initialize(cfg *Config) error {
	if cfg == nil {
		return ufmt.Errorf("config cannot be nil")
	}

	for rn, addr := range cfg.Roles {
		checker := createAddressChecker(addr, rn)
		err := rbac.DeclareRole(rn, prbac.WithPermission(PERM_ACCESS, checker))
		if err != nil {
			return ufmt.Errorf("failed to declare role %s: %v", rn, err)
		}
	}

	currentConfig = cfg
	return nil
}

func GetCurrentConfig() *Config {
	if currentConfig == nil {
		return nil
	}
	return currentConfig
}

// UpdateRoleAddress updates the address for a specific role's permission checker
func UpdateRoleAddress(roleName string, newAddress std.Address) error {
	if currentConfig == nil {
		return ufmt.Errorf("access control not initialized")
	}

	currentConfig.Roles[roleName] = newAddress

	newChecker := createAddressChecker(newAddress, roleName)
	return rbac.UpdatePermission(roleName, PERM_ACCESS, newChecker)
}

func CreateRole(roleName string, address std.Address) error {
	if currentConfig == nil {
		return ufmt.Errorf("access control not initialized")
	}

	// Check if role already exists
	if _, exists := currentConfig.Roles[roleName]; exists {
		return ufmt.Errorf("role %s already exists", roleName)
	}

	// Create new role with permission
	checker := createAddressChecker(address, roleName)
	err := rbac.DeclareRole(roleName, prbac.WithPermission(PERM_ACCESS, checker))
	if err != nil {
		return ufmt.Errorf("failed to declare role %s: %v", roleName, err)
	}

	currentConfig.Roles[roleName] = address
	return nil
}
