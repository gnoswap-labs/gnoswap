package staker

import (
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/gov/staker"
)

func (g *govStakerV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	return ufmt.Sprintf(
		"# Gnoswap Governance Staker\n\n"+
			"| Field | Value |\n"+
			"| --- | ---: |\n"+
			"| Active implementation | %s |\n"+
			"| Total xGNS supply | %d |\n"+
			"| Total delegated GNS | %d |\n"+
			"| Total locked GNS | %d |\n"+
			"| Undelegation lockup period | %d |\n"+
			"| Protocol-fee accumulation timestamp | %d |\n",
		staker.GetImplementationPackagePath(),
		staker.GetTotalxGnsSupply(),
		staker.GetTotalDelegated(),
		staker.GetTotalLockedAmount(),
		staker.GetUnDelegationLockupPeriod(),
		staker.GetProtocolFeeAccumulatedTimestamp(),
	)
}
