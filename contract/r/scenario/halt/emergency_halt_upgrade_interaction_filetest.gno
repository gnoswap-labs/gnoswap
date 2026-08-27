// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"

	"gno.land/r/gnoswap/pool"
	_ "gno.land/r/gnoswap/pool/v1"

	"gno.land/r/gnoswap/staker"
	_ "gno.land/r/gnoswap/staker/v1"
)

var (
	t          = &testing.T{}
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)
)

const (
	poolV1Path   = "gno.land/r/gnoswap/pool/v1"
	stakerV1Path = "gno.land/r/gnoswap/staker/v1"
)

func main(cur realm) {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
	staker.UpgradeImpl(cross(cur), stakerV1Path)
	uassert.Equal(t, stakerV1Path, staker.GetImplementationPackagePath())
	println("[EXPECTED] staker upgrade succeeds without halt")

	halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)
	haltConfigBefore := halt.GetHaltConfigJson()
	staker.UpgradeImpl(cross(cur), stakerV1Path)
	uassert.Equal(t, stakerV1Path, staker.GetImplementationPackagePath())
	uassert.Equal(t, haltConfigBefore, halt.GetHaltConfigJson())
	println("[EXPECTED] emergency halt allows staker upgrade")

	pool.UpgradeImpl(cross(cur), poolV1Path)
	uassert.Equal(t, poolV1Path, pool.GetImplementationPackagePath())
	uassert.Equal(t, haltConfigBefore, halt.GetHaltConfigJson())
	println("[EXPECTED] emergency halt allows pool upgrade")
}

// Output:
// [EXPECTED] staker upgrade succeeds without halt
// [EXPECTED] emergency halt allows staker upgrade
// [EXPECTED] emergency halt allows pool upgrade
