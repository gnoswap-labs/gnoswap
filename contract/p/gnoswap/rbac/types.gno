package rbac

// SystemRole represents a reserved system-role name that cannot be removed once registered.
type SystemRole string

const (
	ROLE_ADMIN          SystemRole = "admin"
	ROLE_DEVOPS         SystemRole = "devops"
	ROLE_COMMUNITY_POOL SystemRole = "community_pool"
	ROLE_GOVERNANCE     SystemRole = "governance"
	ROLE_GOV_STAKER     SystemRole = "gov_staker"
	ROLE_XGNS           SystemRole = "xgns"
	ROLE_POOL           SystemRole = "pool"
	ROLE_POSITION       SystemRole = "position"
	ROLE_ROUTER         SystemRole = "router"
	ROLE_STAKER         SystemRole = "staker"
	ROLE_EMISSION       SystemRole = "emission"
	ROLE_LAUNCHPAD      SystemRole = "launchpad"
	ROLE_PROTOCOL_FEE   SystemRole = "protocol_fee"
)

// MUST BE IMMUTABLE, DO NOT MODIFY.
// _systemRoleNames is a map of system role names to SystemRole values by performance.
var _systemRoleNames = map[string]SystemRole{
	"admin":          ROLE_ADMIN,
	"devops":         ROLE_DEVOPS,
	"community_pool": ROLE_COMMUNITY_POOL,
	"governance":     ROLE_GOVERNANCE,
	"gov_staker":     ROLE_GOV_STAKER,
	"xgns":           ROLE_XGNS,
	"pool":           ROLE_POOL,
	"position":       ROLE_POSITION,
	"router":         ROLE_ROUTER,
	"staker":         ROLE_STAKER,
	"emission":       ROLE_EMISSION,
	"launchpad":      ROLE_LAUNCHPAD,
	"protocol_fee":   ROLE_PROTOCOL_FEE,
}

// String returns the string representation of the SystemRole.
// Returns "Unknown" if the role is not a valid system role.
//
// Returns:
//   - string: Registered system-role name, or "Unknown" when r is not in the system-role registry.
func (r SystemRole) String() string {
	roleName := string(r)
	if _, ok := _systemRoleNames[roleName]; !ok {
		return "Unknown"
	}

	return roleName
}

// IsSystemRole returns true if roleName is a system role.
//
// Parameters:
//   - roleName: Exact string key to check against the reserved system-role registry.
//
// Returns:
//   - bool: true when roleName names a registered system role; false otherwise.
func IsSystemRole(roleName string) bool {
	_, ok := _systemRoleNames[roleName]

	return ok
}
