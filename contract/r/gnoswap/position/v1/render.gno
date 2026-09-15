package position

import (
	"chain"

	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/halt"
	positionRoot "gno.land/r/gnoswap/position"
)

func (p *positionV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	return ufmt.Sprintf(
		`# Gnoswap Position

Position records remain stored after burning. The record count includes burned
positions and is not a count of active liquidity positions.

| Field | Value |
| --- | --- |
| Realm address | %s |
| Active implementation | %s |
| Position operations halted | %t |
| Withdrawals halted | %t |

| Field | Value |
| --- | --- |
| Stored position records (including burned) | %d |
| Next position ID | %d |
`,
		chain.PackageAddress("gno.land/r/gnoswap/position"),
		positionRoot.GetImplementationPackagePath(),
		halt.IsHaltedPosition(),
		halt.IsHaltedWithdraw(),
		p.store.GetPositions().Size(),
		p.store.GetPositionNextID(),
	)
}
