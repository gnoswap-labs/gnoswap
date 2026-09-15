package staker

import (
	"strings"

	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/gov/staker"
)

func (g *govStakerV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	implementation := staker.GetImplementationPackagePath()

	return ufmt.Sprintf(
		"# Gnoswap Governance Staker\n\n"+
			"## Staking overview\n\n"+
			"| Field | Value |\n"+
			"| --- | ---: |\n"+
			"| Active implementation | [%s](%s) |\n"+
			"| Total xGNS supply | %d |\n"+
			"| Total delegated GNS | %d |\n"+
			"| Total locked GNS | %d |\n"+
			"| Undelegation lockup period | %d |\n"+
			"| Protocol-fee accumulation timestamp | %d |\n",
		implementation,
		strings.TrimPrefix(implementation, "gno.land"),
		staker.GetTotalxGnsSupply(),
		staker.GetTotalDelegated(),
		staker.GetTotalLockedAmount(),
		staker.GetUnDelegationLockupPeriod(),
		staker.GetProtocolFeeAccumulatedTimestamp(),
	)
}
