package common

import (
	"strings"
	"testing"

	"gno.land/p/nt/grc20/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/common"
	"gno.land/r/nt/grc20reg/v0"
)

func TestRenderRegistryCount(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/common/v1"))
	before := grc20reg.GetRegistry().Size()
	uassert.True(t, strings.Contains(common.Render(""), ufmt.Sprintf("| Registry entries (network-wide) | %d |", before)))

	token, _ := grc20.NewToken("Render registry test", "RENDER", 6, 0, cur)
	grc20reg.Register(cross(cur), token, "")
	uassert.True(t, strings.Contains(common.Render(""), ufmt.Sprintf("| Registry entries (network-wide) | %d |", before+1)))
	uassert.Equal(t, "404\n", common.Render("tokens"))
}
