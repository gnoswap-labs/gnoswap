package gnft

import (
	"testing"

	prabc "gno.land/p/gnoswap/rbac"
	ownable "gno.land/p/nt/ownable"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
)

var (
	positionAddr = access.MustGetAddress(prabc.ROLE_POSITION.String())
	owner        = ownable.NewWithAddress(positionAddr)
)

func setHalted(halted bool) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	halt.SetOperationStatus(cross, halt.OpTypePosition, halted)
}
