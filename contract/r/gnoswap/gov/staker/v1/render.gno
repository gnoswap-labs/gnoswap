package staker

import (
	"strings"

	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/mdtable/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/gov/staker"
)

func (g *govStakerV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	implementation := staker.GetImplementationPackagePath()

	out := md.H1("Gnoswap Governance Staker")
	out += md.H2("Staking overview")
	overviewTable := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Active implementation", md.Link(implementation, strings.TrimPrefix(implementation, "gno.land"))},
			{"Total xGNS supply", ufmt.Sprintf("%d", staker.GetTotalxGnsSupply())},
			{"Total delegated GNS", ufmt.Sprintf("%d", staker.GetTotalDelegated())},
			{"Total locked GNS", ufmt.Sprintf("%d", staker.GetTotalLockedAmount())},
			{"Undelegation lockup period", ufmt.Sprintf("%d", staker.GetUnDelegationLockupPeriod())},
			{"Protocol-fee accumulation timestamp", ufmt.Sprintf("%d", staker.GetProtocolFeeAccumulatedTimestamp())},
		},
	}
	out += overviewTable.String()

	return out
}
