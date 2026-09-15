package pool

import (
	"chain"
	"strings"

	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/mdtable/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/halt/v1"
	poolRoot "gno.land/r/gnoswap/pool"
)

func (p *poolV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	feeAmountTickSpacing := p.store.GetFeeAmountTickSpacing()
	protocolFee := p.store.GetSlot0FeeProtocol()
	implementation := poolRoot.GetImplementationPackagePath()
	implementationTable := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Realm address", md.InlineCode(chain.PackageAddress("gno.land/r/gnoswap/pool").String())},
			{"Active implementation", md.Link(implementation, strings.TrimPrefix(implementation, "gno.land"))},
			{"Pool operations halted", ufmt.Sprintf("%t", halt.IsHaltedPool())},
			{"Protocol-fee operations halted", ufmt.Sprintf("%t", halt.IsHaltedProtocolFee())},
			{"Withdrawals halted", ufmt.Sprintf("%t", halt.IsHaltedWithdraw())},
		},
	}
	feeTable := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Stored pool records", ufmt.Sprintf("%d", p.store.GetPools().Size())},
			{"Pool creation fee (GNS base units; 6 decimals)", ufmt.Sprintf("%d", p.store.GetPoolCreationFee())},
			{"Withdrawal fee", ufmt.Sprintf("%d bps", p.store.GetWithdrawalFeeBPS())},
			{"Fee tiers (pips)", "100 (0.01%) / 500 (0.05%) / 3000 (0.30%) / 10000 (1.00%)"},
			{"Tick spacing (ticks; same tier order)", ufmt.Sprintf("%d / %d / %d / %d",
				feeAmountTickSpacing[100],
				feeAmountTickSpacing[500],
				feeAmountTickSpacing[3000],
				feeAmountTickSpacing[10000],
			)},
			{"Protocol fee denominators (token0 / token1)", ufmt.Sprintf("%d / %d", protocolFee&15, protocolFee>>4)},
		},
	}

	out := md.H1("Gnoswap Pool") + "\n"
	out += md.Paragraph(`Pool creation fees are charged in GNS. GNS amounts use the token's six-decimal
base units; pool token amounts use each token's own base units. Withdrawal fees
apply to collected swap fees and are expressed in basis points. Protocol fee
denominators apply to swap fees; zero disables the corresponding token's fee.`)
	out += md.H2("Implementation and operation status") + "\n"
	out += implementationTable.String() + "\n"
	out += md.H2("Pools and fee configuration") + "\n"
	out += feeTable.String()
	return out
}
