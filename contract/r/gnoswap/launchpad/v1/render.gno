package launchpad

import (
	"chain"

	prbac "gno.land/p/gnoswap/rbac/v1"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/halt/v1"
	launchpadRoot "gno.land/r/gnoswap/launchpad"
)

func (l *launchpadV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	return ufmt.Sprintf(
		`# Gnoswap Launchpad

All GNS amounts use the token's six-decimal base units. Project reward amounts
use the project token's own base units.

| Field | Value |
| --- | --- |
| Realm address | %s |
| Active implementation | %s |
| Launchpad operations halted | %t |
| Withdrawal operations halted | %t |
| Project creation role (admin) | %s |
| Project creation role (governance) | %s |

| Field | Value |
| --- | --- |
| Stored project records | %d |
| Stored unique project-recipient records | %d |
| Stored project-tier reward-manager records | %d |
| Stored deposit records (including withdrawn) | %d |
| Deposit ID counter (allocated IDs) | %d |
| Current GNS staked amount (base units; 6 decimals) | %d |
| Minimum GNS deposit (base units; 6 decimals) | %d |
| Minimum project start delay (seconds) | %d |
| Project tiers (days) | 30 / 90 / 180 |
| Reward claimable duration (seconds) | %d |
`,
		chain.PackageAddress("gno.land/r/gnoswap/launchpad"),
		launchpadRoot.GetImplementationPackagePath(),
		halt.IsHaltedLaunchpad(),
		halt.IsHaltedWithdraw(),
		renderLaunchpadRole(prbac.ROLE_ADMIN),
		renderLaunchpadRole(prbac.ROLE_GOVERNANCE),
		l.store.GetProjects().Size(),
		l.store.GetProjectRecipients().Size(),
		l.store.GetProjectTierRewardManagers().Size(),
		l.store.GetDeposits().Size(),
		l.store.GetDepositCounter().Get(),
		l.store.GetTotalGNSStakedAmount(),
		minimumDepositAmount,
		projectMinimumStartDelayTime,
		projectTierRewardCollectableDuration[projectTier30],
	)
}

func renderLaunchpadRole(role prbac.SystemRole) string {
	addr, ok := access.GetAddress(role.String())
	if !ok || addr == address("") {
		return "Unassigned"
	}
	return addr.String()
}
