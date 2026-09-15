package router

import (
	"chain"

	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/router"
)

const maxSwapFeeBPS uint64 = 1000

func (r *routerV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	swapFee := r.GetSwapFee()

	return ufmt.Sprintf(
		"# Gnoswap Router\n\n"+
			"| Field | Value |\n"+
			"| --- | --- |\n"+
			"| Realm address | %s |\n"+
			"| Active implementation | %s |\n"+
			"| Swap fee | %d bps |\n"+
			"| Maximum swap fee | %d bps (10%%) |\n"+
			"| Fee unit | 1 bps = 0.01%% of the output-token amount; amounts use token base units |\n"+
			"| Router halted | %t |\n",
		chain.PackageAddress("gno.land/r/gnoswap/router"),
		router.GetImplementationPackagePath(),
		swapFee,
		maxSwapFeeBPS,
		halt.IsHaltedRouter(),
	)
}
