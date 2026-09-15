package community_pool

import (
	prbac "gno.land/p/gnoswap/rbac/v1"
	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/mdtable/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/halt/v1"
)

// Render shows the authorities and withdrawal gate used by treasury transfers.
func Render(path string) string {
	if path != "" {
		return "404\n"
	}

	out := md.H1("Gnoswap Community Pool") +
		"\n" +
		md.Paragraph(
			"The community treasury holds tokens for ecosystem funding.\n"+
				"Balances are queried per token; this page does not report a total treasury value.",
		) +
		md.H2("Transfers") +
		"\n" +
		md.Paragraph("Transfers require the admin or governance role and are blocked when withdrawals are halted.")

	statusTable := mdtable.Table{
		Headers: []string{"Restriction", "Enabled"},
		Rows: [][]string{
			{"Withdrawals halted", ufmt.Sprintf("%t", halt.IsHaltedWithdraw())},
		},
	}
	out += statusTable.String() + "\n"

	out += md.H2("Transfer authorities") + "\n"
	authorityTable := mdtable.Table{
		Headers: []string{"Role", "Address"},
	}
	for _, role := range []prbac.SystemRole{prbac.ROLE_ADMIN, prbac.ROLE_GOVERNANCE} {
		value := "Unassigned"
		if addr, ok := access.GetAddress(role.String()); ok {
			value = md.InlineCode(addr.String())
		}
		authorityTable.Append([]string{role.String(), value})
	}
	return out + authorityTable.String()
}
