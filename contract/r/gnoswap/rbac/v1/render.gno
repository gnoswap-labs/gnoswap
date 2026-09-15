package rbac

import (
	prbac "gno.land/p/gnoswap/rbac/v1"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// Render returns ownership and assignments for the protocol's fixed system roles.
func Render(path string) string {
	if path != "" {
		return "404\n"
	}

	roles := []prbac.SystemRole{
		prbac.ROLE_ADMIN, prbac.ROLE_DEVOPS, prbac.ROLE_COMMUNITY_POOL,
		prbac.ROLE_GOVERNANCE, prbac.ROLE_GOV_STAKER, prbac.ROLE_XGNS,
		prbac.ROLE_POOL, prbac.ROLE_POSITION, prbac.ROLE_ROUTER,
		prbac.ROLE_STAKER, prbac.ROLE_EMISSION, prbac.ROLE_LAUNCHPAD,
		prbac.ROLE_PROTOCOL_FEE,
	}

	result := ufmt.Sprintf(`# Gnoswap RBAC

## Ownership

| Field | Address |
| --- | --- |
| Owner | %s |
| Pending owner | %s |

## System roles

| Role | Address |
| --- | --- |
`, renderOwnershipAddress(GetOwner()), renderOwnershipAddress(GetPendingOwner()))
	for _, role := range roles {
		result += ufmt.Sprintf("| %s | %s |\n", role.String(), renderRoleAddress(role))
	}
	return result
}

func renderOwnershipAddress(addr address) string {
	if addr == address("") {
		return "None"
	}
	return addr.String()
}

func renderRoleAddress(role prbac.SystemRole) string {
	addr, err := GetRoleAddress(role.String())
	if err != nil || addr == address("") {
		return "Unassigned"
	}
	return "`" + addr.String() + "`"
}
