package rbac

import (
	prbac "gno.land/p/gnoswap/rbac/v1"
	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/mdtable/v0"
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

	ownershipTable := mdtable.Table{
		Headers: []string{"Field", "Address"},
		Rows: [][]string{
			{"Owner", renderOwnershipAddress(GetOwner())},
			{"Pending owner", renderOwnershipAddress(GetPendingOwner())},
		},
	}
	out := md.H1("Gnoswap RBAC") +
		"\n" +
		md.H2("Ownership") +
		"\n" +
		ownershipTable.String() +
		"\n" +
		md.H2("System roles")

	roleTable := mdtable.Table{
		Headers: []string{"Role", "Address"},
	}
	for _, role := range roles {
		roleTable.Append([]string{role.String(), renderRoleAddress(role)})
	}
	return out + "\n" + roleTable.String()
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
	return md.InlineCode(addr.String())
}
