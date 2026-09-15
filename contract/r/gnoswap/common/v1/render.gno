package common

import (
	"chain"

	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/common"
	"gno.land/r/nt/grc20reg/v0"
)

func (c *commonV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	return ufmt.Sprintf(
		"# Gnoswap Common\n\n"+
			"| Field | Value |\n"+
			"| --- | --- |\n"+
			"| Realm address | %s |\n"+
			"| Active implementation | %s |\n"+
			"| Token registry | gno.land/r/nt/grc20reg/v0 |\n"+
			"| Registry entries (network-wide) | %d |\n\n"+
			"Token operations resolve a registered `realm-path.SYMBOL` key. "+
			"The registry count includes tokens outside Gnoswap; it is not a trading whitelist.\n\n"+
			"Native coins are not accepted by token operations. "+
			"Query balances and allowances per token; amounts use that token's base units.\n",
		chain.PackageAddress("gno.land/r/gnoswap/common"),
		common.GetImplementationPackagePath(),
		grc20reg.GetRegistry().Size(),
	)
}
