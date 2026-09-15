package halt

import (
	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/mdtable/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// Render returns the current halt status for every operation.
func Render(path string) string {
	if path != "" {
		return "404\n"
	}

	table := mdtable.Table{
		Headers: []string{"Operation", "Halted"},
		Rows: [][]string{
			{"Pool", ufmt.Sprintf("%t", IsHaltedPool())},
			{"Position", ufmt.Sprintf("%t", IsHaltedPosition())},
			{"Protocol fee", ufmt.Sprintf("%t", IsHaltedProtocolFee())},
			{"Router", ufmt.Sprintf("%t", IsHaltedRouter())},
			{"Staker", ufmt.Sprintf("%t", IsHaltedStaker())},
			{"Launchpad", ufmt.Sprintf("%t", IsHaltedLaunchpad())},
			{"Governance", ufmt.Sprintf("%t", IsHaltedGovernance())},
			{"Governance staker", ufmt.Sprintf("%t", IsHaltedGovStaker())},
			{"xGNS", ufmt.Sprintf("%t", IsHaltedXGns())},
			{"Community pool", ufmt.Sprintf("%t", IsHaltedCommunityPool())},
			{"Emission", ufmt.Sprintf("%t", IsHaltedEmission())},
			{"Withdraw", ufmt.Sprintf("%t", IsHaltedWithdraw())},
		},
	}

	return md.H1("Gnoswap Halt Status") +
		"\n" +
		md.H2("Operation status") +
		"\n" +
		table.String()
}
