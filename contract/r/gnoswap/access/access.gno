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
	AdminAddr      std.Address
	GovernanceAddr std.Address
	GovStakerAddr  std.Address
	RouterAddr     std.Address
	PoolAddr       std.Address
	PositionAddr   std.Address
	StakerAddr     std.Address
	LaunchpadAddr  std.Address
	EmissionAddr   std.Address
}

// DefaultConfig returns an empty config with zero addresses
func DefaultConfig() *Config {
	return &Config{}
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

	// Define role configurations
	roles := []struct {
		name    string
		address std.Address
	}{
		{ROLE_ADMIN, cfg.AdminAddr},
		{ROLE_GOVERNANCE, cfg.GovernanceAddr},
		{ROLE_GOV_STAKER, cfg.GovStakerAddr},
		{ROLE_ROUTER, cfg.RouterAddr},
		{ROLE_POOL, cfg.PoolAddr},
		{ROLE_POSITION, cfg.PositionAddr},
		{ROLE_STAKER, cfg.StakerAddr},
		{ROLE_LAUNCHPAD, cfg.LaunchpadAddr},
		{ROLE_EMISSION, cfg.EmissionAddr},
	}

	// Register roles with their respective permission checkers
	for _, role := range roles {
		checker := createAddressChecker(role.address, role.name)
		err := rbac.DeclareRole(role.name, prbac.WithPermission(PERM_ACCESS, checker))
		if err != nil {
			return ufmt.Errorf("failed to declare role %s: %v", role.name, err)
		}
	}

	currentConfig = cfg

	return nil
}

func GetCurrentConfig() *Config {
	if currentConfig == nil {
		return nil
	}
	return &Config{
		AdminAddr:      currentConfig.AdminAddr,
		GovernanceAddr: currentConfig.GovernanceAddr,
		GovStakerAddr:  currentConfig.GovStakerAddr,
		RouterAddr:     currentConfig.RouterAddr,
		PoolAddr:       currentConfig.PoolAddr,
		PositionAddr:   currentConfig.PositionAddr,
		StakerAddr:     currentConfig.StakerAddr,
		LaunchpadAddr:  currentConfig.LaunchpadAddr,
		EmissionAddr:   currentConfig.EmissionAddr,
	}
}

// UpdateRoleAddress updates the address for a specific role's permission checker
func UpdateRoleAddress(roleName string, newAddress std.Address) error {
	if currentConfig == nil {
		return ufmt.Errorf("access control not initialized")
	}

	// Update the config
	switch roleName {
	case ROLE_ADMIN:
		currentConfig.AdminAddr = newAddress
	case ROLE_GOVERNANCE:
		currentConfig.GovernanceAddr = newAddress
	case ROLE_GOV_STAKER:
		currentConfig.GovStakerAddr = newAddress
	case ROLE_ROUTER:
		currentConfig.RouterAddr = newAddress
	case ROLE_POOL:
		currentConfig.PoolAddr = newAddress
	case ROLE_POSITION:
		currentConfig.PositionAddr = newAddress
	case ROLE_STAKER:
		currentConfig.StakerAddr = newAddress
	case ROLE_LAUNCHPAD:
		currentConfig.LaunchpadAddr = newAddress
	case ROLE_EMISSION:
		currentConfig.EmissionAddr = newAddress
	default:
		return ufmt.Errorf("unknown role: %s", roleName)
	}

	// Update the permission checker
	newChecker := createAddressChecker(newAddress, roleName)
	return rbac.UpdatePermission(roleName, PERM_ACCESS, newChecker)
}
