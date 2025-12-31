package gnft

import (
	"testing"

	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
)

var positionAddr = access.MustGetAddress(prabc.ROLE_POSITION.String())

func setHalted(halted bool) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	halt.SetOperationStatus(cross, halt.OpTypePosition, halted)
}
