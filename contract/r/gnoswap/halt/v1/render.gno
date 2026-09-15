package halt

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

// Render returns the current halt status for every operation.
func Render(path string) string {
	if path != "" {
		return "404\n"
	}

	return ufmt.Sprintf(`# Gnoswap Halt Status

| Operation | Halted |
| --- | --- |
| Pool | %t |
| Position | %t |
| Protocol fee | %t |
| Router | %t |
| Staker | %t |
| Launchpad | %t |
| Governance | %t |
| Governance staker | %t |
| xGNS | %t |
| Community pool | %t |
| Emission | %t |
| Withdraw | %t |
`,
		IsHaltedPool(),
		IsHaltedPosition(),
		IsHaltedProtocolFee(),
		IsHaltedRouter(),
		IsHaltedStaker(),
		IsHaltedLaunchpad(),
		IsHaltedGovernance(),
		IsHaltedGovStaker(),
		IsHaltedXGns(),
		IsHaltedCommunityPool(),
		IsHaltedEmission(),
		IsHaltedWithdraw(),
	)
}
