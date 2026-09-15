package router

import (
	"strings"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/halt"
)

func TestRenderReflectsSwapFeeAndHalt(cur realm, t *testing.T) {
	r := mockRouter()

	testing.SetRealm(adminRealm)
	previousHalt := halt.IsHaltedRouter()
	defer func() {
		testing.SetRealm(adminRealm)
		halt.SetOperationStatus(cross(cur), halt.OpTypeRouter, previousHalt)
	}()

	func(cur realm) {
		r.SetSwapFee(0, cur, 275)
	}(cross(cur))
	halt.SetOperationStatus(cross(cur), halt.OpTypeRouter, true)

	rendered := r.Render("")
	uassert.True(t, strings.Contains(rendered, "| Swap fee | 275 bps |"))
	uassert.True(t, strings.Contains(rendered, "| Router halted | true |"))
	uassert.Equal(t, "404\n", r.Render("fees"))
}

func TestRenderUnsupportedPathAvoidsStateAccess(cur realm, t *testing.T) {
	testing.SetRealm(adminRealm)
	r := &routerV1{store: &mockRouterStore{data: make(map[string]any)}}

	uassert.Equal(t, "404\n", r.Render("unsupported"))
}
