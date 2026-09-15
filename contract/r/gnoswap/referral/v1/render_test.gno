package referral

import (
	"strings"
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestRenderUnknownPath(cur realm, t *testing.T) {
	uassert.Equal(t, "404\n", Render("address"))
	uassert.Equal(t, "404\n", Render("address/not-an-address"))
}

func TestRenderReferralTracksRegistrationAndRemoval(cur realm, t *testing.T) {
	previousKeeper := gReferralKeeper
	defer func() { gReferralKeeper = previousKeeper }()
	gReferralKeeper = NewKeeper()
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

	user := testutils.TestAddress("render-user")
	referrer := testutils.TestAddress("render-referrer")
	path := "address/" + user.String()
	uassert.Equal(t, "404\n", Render(path))

	TryRegister(cross(cur), user, referrer.String())
	uassert.Equal(t, "404\n", Render("referral/"+user.String()))
	page := Render(path)
	uassert.True(t, strings.Contains(page, user.String()))
	uassert.True(t, strings.Contains(page, referrer.String()))
	uassert.True(t, strings.Contains(page, time.Now().UTC().Format("2006-01-02 15:04:05")))

	TryRegister(cross(cur), user, ContractAddress())
	uassert.Equal(t, "404\n", Render(path))
}
