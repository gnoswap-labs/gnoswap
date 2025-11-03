package gnft

import (
	"testing"

	"gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
)

func setHalted(halted bool) {
	adminAddr, _ := access.GetAddress(rbac.ROLE_ADMIN.String())
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	halt.SetOperationStatus(cross, halt.OpTypePosition, halted)
}
