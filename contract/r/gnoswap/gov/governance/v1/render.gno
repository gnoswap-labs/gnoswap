package governance

import (
	"strings"

	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/mdtable/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/gov/governance"
)

func (g *governanceV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	implementation := governance.GetImplementationPackagePath()

	out := md.H1("Gnoswap Governance")
	out += md.H2("Governance configuration")
	configurationTable := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Active implementation", md.Link(implementation, strings.TrimPrefix(implementation, "gno.land"))},
			{"Latest configuration version", ufmt.Sprintf("%d", governance.GetLatestConfigVersion())},
			{"Current proposal ID", ufmt.Sprintf("%d", governance.GetCurrentProposalID())},
			{"Maximum smoothing period", ufmt.Sprintf("%d", governance.GetMaxSmoothingPeriod())},
		},
	}
	out += configurationTable.String()

	return out
}
