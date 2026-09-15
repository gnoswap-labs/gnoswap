package protocol_fee

import (
	"chain"

	prbac "gno.land/p/gnoswap/rbac/v1"
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

	return ufmt.Sprintf(
		"# Gnoswap Protocol Fee\n\n"+
			"| Field | Value |\n"+
			"| --- | --- |\n"+
			"| Realm address | %s |\n"+
			"| Active implementation | %s |\n"+
			"| DevOps allocation | %d bps |\n"+
			"| Governance-staker allocation | %d bps |\n"+
			"| Distribution-rate unit | 1 bps = 0.01%%; 10,000 bps = 100%% |\n"+
			"| DevOps recipient | %s |\n"+
			"| Governance-staker recipient | %s |\n"+
			"| Current accrual epoch | %d |\n"+
			"| Protocol-fee halted | %t |\n"+
			"| Withdrawals halted | %t |\n",
		chain.PackageAddress("gno.land/r/gnoswap/protocol_fee"),
		protocol_fee.GetImplementationPackagePath(),
		devOpsPct,
		govStakerPct,
		access.MustGetAddress(prbac.ROLE_DEVOPS.String()).String(),
		access.MustGetAddress(prbac.ROLE_GOV_STAKER.String()).String(),
		pf.GetAccrualEpoch(),
		halt.IsHaltedProtocolFee(),
		halt.IsHaltedWithdraw(),
	)
}
