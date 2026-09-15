package governance

import (
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/gov/governance"
)

func (g *governanceV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	return ufmt.Sprintf(
		"# Gnoswap Governance\n\n"+
			"| Field | Value |\n"+
			"| --- | ---: |\n"+
			"| Active implementation | %s |\n"+
			"| Latest configuration version | %d |\n"+
			"| Current proposal ID | %d |\n"+
			"| Maximum smoothing period | %d |\n",
		governance.GetImplementationPackagePath(),
		governance.GetLatestConfigVersion(),
		governance.GetCurrentProposalID(),
		governance.GetMaxSmoothingPeriod(),
	)
}
