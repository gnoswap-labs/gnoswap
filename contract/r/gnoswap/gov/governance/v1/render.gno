package governance

import (
	"strings"

	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/gov/governance"
)

func (g *governanceV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	implementation := governance.GetImplementationPackagePath()

	return ufmt.Sprintf(
		"# Gnoswap Governance\n\n"+
			"## Governance configuration\n\n"+
			"| Field | Value |\n"+
			"| --- | ---: |\n"+
			"| Active implementation | [%s](%s) |\n"+
			"| Latest configuration version | %d |\n"+
			"| Current proposal ID | %d |\n"+
			"| Maximum smoothing period | %d |\n",
		implementation,
		strings.TrimPrefix(implementation, "gno.land"),
		governance.GetLatestConfigVersion(),
		governance.GetCurrentProposalID(),
		governance.GetMaxSmoothingPeriod(),
	)
}
