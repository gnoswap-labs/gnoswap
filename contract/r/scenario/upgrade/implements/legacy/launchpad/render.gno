package launchpad

import (
	"chain"
	"strings"

	prbac "gno.land/p/gnoswap/rbac/v1"
	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/mdtable/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/halt/v1"
	launchpadRoot "gno.land/r/gnoswap/launchpad"
)

func (l *launchpadV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	implementation := launchpadRoot.GetImplementationPackagePath()

	out := md.H1("Gnoswap Launchpad")
	out += md.Paragraph(
		"All GNS amounts use the token's six-decimal base units. Project reward amounts\n" +
			"use the project token's own base units.",
	)

	out += md.H2("Implementation and access")
	implementationTable := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Realm address", md.InlineCode(chain.PackageAddress("gno.land/r/gnoswap/launchpad").String())},
			{"Active implementation", md.Link(implementation, strings.TrimPrefix(implementation, "gno.land"))},
			{"Launchpad operations halted", ufmt.Sprintf("%t", halt.IsHaltedLaunchpad())},
			{"Withdrawal operations halted", ufmt.Sprintf("%t", halt.IsHaltedWithdraw())},
			{"Project creation role (admin)", renderLaunchpadRole(prbac.ROLE_ADMIN)},
			{"Project creation role (governance)", renderLaunchpadRole(prbac.ROLE_GOVERNANCE)},
		},
	}
	out += implementationTable.String()

	out += md.H2("Deposit accounting and configuration")
	accountingTable := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Stored project records", ufmt.Sprintf("%d", l.store.GetProjects().Size())},
			{"Stored unique project-recipient records", ufmt.Sprintf("%d", l.store.GetProjectRecipients().Size())},
			{"Stored project-tier reward-manager records", ufmt.Sprintf("%d", l.store.GetProjectTierRewardManagers().Size())},
			{"Stored deposit records (including withdrawn)", ufmt.Sprintf("%d", l.store.GetDeposits().Size())},
			{"Deposit ID counter (allocated IDs)", ufmt.Sprintf("%d", l.store.GetDepositCounter().Get())},
			{"Current GNS staked amount (base units; 6 decimals)", ufmt.Sprintf("%d", l.store.GetTotalGNSStakedAmount())},
			{"Minimum GNS deposit (base units; 6 decimals)", ufmt.Sprintf("%d", minimumDepositAmount)},
			{"Minimum project start delay (seconds)", ufmt.Sprintf("%d", projectMinimumStartDelayTime)},
			{"Project tiers (days)", "30 / 90 / 180"},
			{"Reward claimable duration (seconds)", ufmt.Sprintf("%d", projectTierRewardCollectableDuration[projectTier30])},
		},
	}
	out += accountingTable.String()

	return out
}

func renderLaunchpadRole(role prbac.SystemRole) string {
	addr, ok := access.GetAddress(role.String())
	if !ok || addr == address("") {
		return "Unassigned"
	}
	return md.InlineCode(addr.String())
}
