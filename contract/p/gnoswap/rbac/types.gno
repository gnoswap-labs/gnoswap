package rbac

type SystemRole string

var (
	ROLE_ADMIN         SystemRole = "admin"
	ROLE_DEVOPS        SystemRole = "devops"
	ROLE_COMMUNITY_POOL SystemRole = "community_pool"
	ROLE_GOVERNANCE    SystemRole = "governance"
	ROLE_GOV_STAKER     SystemRole = "gov_staker"
	ROLE_XGNS          SystemRole = "xgns"
	ROLE_POOL          SystemRole = "pool"
	ROLE_POSITION      SystemRole = "position"
	ROLE_ROUTER        SystemRole = "router"
	ROLE_STAKER        SystemRole = "staker"
	ROLE_EMISSION      SystemRole = "emission"
	ROLE_LAUNCHPAD     SystemRole = "launchpad"
	ROLE_PROTOCOL_FEE   SystemRole = "protocol_fee"
)

var systemRoleNames = map[string]SystemRole{
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

func (r SystemRole) String() string {
	roleName := string(r)
	if _, ok := systemRoleNames[roleName]; !ok {
		return "Unknown"
	}

	return roleName
}

func IsSystemRole(roleName string) bool {
_, ok := systemRoleNames[roleName]

	return ok
}