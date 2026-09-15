package common

import (
	"chain"
	"strings"

	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/mdtable/v0"
	"gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/common"
	"gno.land/r/nt/grc20reg/v0"
)

func (c *commonV1) Render(path string) string {
	if path != "" {
		return "404\n"
	}

	implementation := common.GetImplementationPackagePath()
	table := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Realm address", md.InlineCode(chain.PackageAddress("gno.land/r/gnoswap/common").String())},
			{"Active implementation", md.Link(implementation, strings.TrimPrefix(implementation, "gno.land"))},
			{"Token registry", md.Link("gno.land/r/nt/grc20reg/v0", "/r/nt/grc20reg/v0")},
			{"Registry entries (network-wide)", ufmt.Sprintf("%d", grc20reg.GetRegistry().Size())},
		},
	}

	out := md.H1("Gnoswap Common") + "\n"
	out += md.H2("Registry configuration") + "\n"
	out += table.String() + "\n"
	out += md.Paragraph(
		"Token operations resolve a registered " + md.InlineCode("realm-path.SYMBOL") + " key. " +
			"The registry count includes tokens outside Gnoswap; it is not a trading whitelist.",
	)
	out += md.Paragraph(
		"Native coins are not accepted by token operations. " +
			"Query balances and allowances per token; amounts use that token's base units.",
	)
	return out
}
