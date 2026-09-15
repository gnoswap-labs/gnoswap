package pool

import (
	"chain"

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

	return ufmt.Sprintf(
		`# Gnoswap Pool

Pool creation fees are charged in GNS. GNS amounts use the token's six-decimal
base units; pool token amounts use each token's own base units. Withdrawal fees
apply to collected swap fees and are expressed in basis points. Protocol fee
denominators apply to swap fees; zero disables the corresponding token's fee.

| Field | Value |
| --- | --- |
| Realm address | %s |
| Active implementation | %s |
| Pool operations halted | %t |
| Protocol-fee operations halted | %t |
| Withdrawals halted | %t |

| Field | Value |
| --- | --- |
| Stored pool records | %d |
| Pool creation fee (GNS base units; 6 decimals) | %d |
| Withdrawal fee | %d bps |
| Fee tiers (pips) | 100 (0.01%%) / 500 (0.05%%) / 3000 (0.30%%) / 10000 (1.00%%) |
| Tick spacing (ticks; same tier order) | %d / %d / %d / %d |
| Protocol fee denominators (token0 / token1) | %d / %d |
`,
		chain.PackageAddress("gno.land/r/gnoswap/pool"),
		poolRoot.GetImplementationPackagePath(),
		halt.IsHaltedPool(),
		halt.IsHaltedProtocolFee(),
		halt.IsHaltedWithdraw(),
		p.store.GetPools().Size(),
		p.store.GetPoolCreationFee(),
		p.store.GetWithdrawalFeeBPS(),
		feeAmountTickSpacing[100],
		feeAmountTickSpacing[500],
		feeAmountTickSpacing[3000],
		feeAmountTickSpacing[10000],
		protocolFee&15,
		protocolFee>>4,
	)
}
