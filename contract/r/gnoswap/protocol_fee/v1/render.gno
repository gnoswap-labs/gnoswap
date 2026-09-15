package protocol_fee

import (
	"chain"
	"strings"

	prbac "gno.land/p/gnoswap/rbac/v1"
	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/mdtable/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/halt/v1"
	"gno.land/r/gnoswap/protocol_fee"
)

func (pf *protocolFeeV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	devOpsPct := pf.GetDevOpsPct()
	govStakerPct := pf.GetGovStakerPct()
	implementation := protocol_fee.GetImplementationPackagePath()
	table := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Realm address", md.InlineCode(chain.PackageAddress("gno.land/r/gnoswap/protocol_fee").String())},
			{"Active implementation", md.Link(implementation, strings.TrimPrefix(implementation, "gno.land"))},
			{"DevOps allocation", ufmt.Sprintf("%d bps", devOpsPct)},
			{"Governance-staker allocation", ufmt.Sprintf("%d bps", govStakerPct)},
			{"Distribution-rate unit", "1 bps = 0.01%; 10,000 bps = 100%"},
			{"DevOps recipient", md.InlineCode(access.MustGetAddress(prbac.ROLE_DEVOPS.String()).String())},
			{"Governance-staker recipient", md.InlineCode(access.MustGetAddress(prbac.ROLE_GOV_STAKER.String()).String())},
			{"Current accrual epoch", ufmt.Sprintf("%d", pf.GetAccrualEpoch())},
			{"Protocol-fee halted", ufmt.Sprintf("%t", halt.IsHaltedProtocolFee())},
			{"Withdrawals halted", ufmt.Sprintf("%t", halt.IsHaltedWithdraw())},
		},
	}

	out := md.H1("Gnoswap Protocol Fee") + "\n"
	out += md.H2("Configuration and distribution") + "\n"
	out += table.String()
	return out
}
