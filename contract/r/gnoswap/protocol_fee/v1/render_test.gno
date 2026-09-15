package protocol_fee

import (
	"strings"
	"testing"

	prbac "gno.land/p/gnoswap/rbac/v1"
	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/access/v1"
)

func TestRenderReflectsDistributionConfigAndEpoch(cur realm, t *testing.T) {
	testing.SetRealm(adminRealm)
	pf := createTestProtocolFee(t)

	if err := pf.store.SetDevOpsPct(0, cur, 2500); err != nil {
		panic(err)
	}
	if err := pf.store.SetAccrualEpoch(0, cur, 7); err != nil {
		panic(err)
	}

	rendered := pf.Render("")
	uassert.True(t, strings.Contains(rendered, "| DevOps allocation | 2500 bps |"))
	uassert.True(t, strings.Contains(rendered, "| Governance-staker allocation | 7500 bps |"))
	uassert.True(t, strings.Contains(rendered, "| DevOps recipient | "+access.MustGetAddress(prbac.ROLE_DEVOPS.String()).String()+" |"))
	uassert.True(t, strings.Contains(rendered, "| Governance-staker recipient | "+access.MustGetAddress(prbac.ROLE_GOV_STAKER.String()).String()+" |"))
	uassert.True(t, strings.Contains(rendered, "| Current accrual epoch | 7 |"))
	uassert.Equal(t, "404\n", pf.Render("distribution"))
}

func TestRenderUnsupportedPathAvoidsStateAccess(cur realm, t *testing.T) {
	testing.SetRealm(adminRealm)
	pf := &protocolFeeV1{store: &mockProtocolFeeStore{}}

	uassert.Equal(t, "404\n", pf.Render("unsupported"))
}
