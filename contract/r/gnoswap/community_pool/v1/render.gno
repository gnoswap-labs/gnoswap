package community_pool

import (
	prbac "gno.land/p/gnoswap/rbac/v1"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/halt/v1"
)

// Render shows the authorities and withdrawal gate used by treasury transfers.
func Render(path string) string {
	if path != "" {
		return "404\n"
	}

	result := ufmt.Sprintf(`# Gnoswap Community Pool

The community treasury holds tokens for ecosystem funding.
Balances are queried per token; this page does not report a total treasury value.

## Transfers

Transfers require the admin or governance role and are blocked when withdrawals are halted.

| Restriction | Enabled |
| --- | --- |
| Withdrawals halted | %t |

## Transfer authorities

| Role | Address |
| --- | --- |
`, halt.IsHaltedWithdraw())
	for _, role := range []prbac.SystemRole{prbac.ROLE_ADMIN, prbac.ROLE_GOVERNANCE} {
		value := "Unassigned"
		if addr, ok := access.GetAddress(role.String()); ok {
			value = addr.String()
		}
		result += ufmt.Sprintf("| %s | %s |\n", role.String(), value)
	}
	return result
}
