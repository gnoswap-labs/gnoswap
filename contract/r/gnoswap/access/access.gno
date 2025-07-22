package access

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/rbac"
)

// event types
const (
	roleSet     = "RoleSet"
	roleUpdated = "RoleUpdated"
	roleCreated = "RoleCreated"
	roleDeleted = "RoleDeleted"
)

var currentConfig *config

// set up the default roles and current config
func init() {
	cfg, err := initializeDefaultRoles()
	if err != nil {
		panic(err)
	}
	currentConfig = cfg
}

// config contains all the addresses needed for access control
type config struct {
	roles map[string]std.Address
}

// newConfig returns an empty config with zero addresses
func newConfig() *config {
	return &config{
		roles: make(map[string]std.Address),
	}
}

// validateConfig checks if the configuration state is valid
func validateConfig() error {
	if currentConfig == nil {
		return ufmt.Errorf(errNotInitialized)
	}
	return nil
}

// validateRoleName checks if the role name is valid
func validateRoleName(roleName string) error {
	if roleName == "" {
		return ufmt.Errorf(errEmptyRole)
	}
	return nil
}

// setConfig sets the current configuration
func setConfig(cfg *config) error {
	if cfg == nil {
		return ufmt.Errorf(errConfigNil)
	}
	currentConfig = cfg
	return nil
}

// initialize registers all roles and permissions to the global RBAC manager
func initialize(cfg *config) error {
	if cfg == nil {
		return ufmt.Errorf(errConfigNil)
	}

	for roleName, addr := range cfg.roles {
		err := declareNewRole(roleName, addr)
		if err == nil {
			continue
		}

		errStr := err.Error()
		if ufmt.Sprintf("%s", errStr) == ufmt.Sprintf(errDeclareRole, roleName, "role "+roleName+" already exists") {
			// role already exists, skip
			continue
		}
		return err
	}

	return setConfig(cfg)
}

// declareNewRole declares a new role
func declareNewRole(roleName string, addr std.Address) error {
	if err := rbac.DeclareRole(cross, roleName); err != nil {
		return ufmt.Errorf(errDeclareRole, roleName, err)
	}
	return nil
}

// getCurrentConfig returns the current configuration
func getCurrentConfig() *config {
	if currentConfig == nil {
		return nil
	}

	return currentConfig
}

func GetAddress(roleName string) (std.Address, error) {
	if currentConfig == nil {
		return std.Address(""), ufmt.Errorf(errNotInitialized)
	}
	return currentConfig.roles[roleName], nil
}

// RoleExists checks if a role exists in the current configuration
func RoleExists(roleName string) bool {
	if currentConfig == nil {
		return false
	}
	_, exists := currentConfig.roles[roleName]
	return exists
}

// GetRoles returns all registered role names
func GetRoles() []string {
	if currentConfig == nil {
		return []string{}
	}
	roles := make([]string, 0, len(currentConfig.roles))
	for role := range currentConfig.roles {
		roles = append(roles, role)
	}
	return roles
}

// UpdateRoleAddress updates the address for a specific role's permission checker
func UpdateRoleAddress(cur realm, roleName string, newAddress std.Address) error {
	if !isAdmin() {
		return ufmt.Errorf("only admin can update roles")
	}

	if err := validateConfig(); err != nil {
		return err
	}

	prevAddress := currentConfig.roles[roleName]
	currentConfig.roles[roleName] = newAddress

	std.Emit(
		roleUpdated,
		"roleName", roleName,
		"prevAddress", prevAddress.String(),
		"newAddress", newAddress.String(),
	)
	return nil
}

// CreateRole creates a new role with the given address
func CreateRole(cur realm, roleName string, address std.Address) error {
	if !isAdmin() {
		return ufmt.Errorf("only admin can create roles")
	}

	if err := validateConfig(); err != nil {
		return err
	}

	if err := validateRoleName(roleName); err != nil {
		return err
	}

	if RoleExists(roleName) {
		return ufmt.Errorf(errRoleExists, roleName)
	}

	if err := declareNewRole(roleName, address); err != nil {
		return err
	}

	currentConfig.roles[roleName] = address

	std.Emit(
		roleCreated,
		"roleName", roleName,
		"address", address.String(),
	)
	return nil
}

func isAdmin() bool {
	caller := std.PreviousRealm().Address()
	adminAddr, err := GetAddress(ROLE_ADMIN)
	if err != nil {
		return false
	}
	return caller == adminAddr
}

func isGovernance() bool {
	caller := std.PreviousRealm().Address()
	govAddr, err := GetAddress(ROLE_GOVERNANCE)
	if err != nil {
		return false
	}
	return caller == govAddr
}

func isAdminOrGovernance() bool {
	return isAdmin() || isGovernance()
}

// isCriticalRole checks if a role is critical and should only be modified by admin
func isCriticalRole(roleName string) bool {
	return roleName == ROLE_ADMIN || roleName == ROLE_DEVOPS
}
