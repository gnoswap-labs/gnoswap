// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath/v1"
	prbac "gno.land/p/gnoswap/rbac/v1"
	"gno.land/p/nt/testutils/v0"
	"gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/access/v1"
	_ "gno.land/r/gnoswap/common/v1"
	"gno.land/r/gnoswap/gns"
	lo "gno.land/r/gnoswap/limit_order"
	_ "gno.land/r/gnoswap/limit_order/v1"
	"gno.land/r/gnoswap/pool"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

func main(cur realm) {
	t := &testing.T{}
	admin := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	alice := testutils.TestAddress("query-alice")
	bob := testutils.TestAddress("query-bob")
	fooPath := "gno.land/r/onbloc/foo.FOO"
	barPath := "gno.land/r/onbloc/bar.BAR"
	poolAddr := access.MustGetAddress(prbac.ROLE_POOL.String())
	testing.SetRealm(testing.NewUserRealm(admin))
	gns.Approve(cross(cur), poolAddr, pool.GetPoolCreationFee())
	pool.CreatePool(cross(cur), barPath, fooPath, 500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	foo.Transfer(cross(cur), alice, 20000)
	foo.Transfer(cross(cur), bob, 20000)
	path := pool.GetPoolPath(barPath, fooPath, 500)
	expiry := time.Now().Unix() + 3600

	testing.SetRealm(testing.NewUserRealm(alice))
	foo.Approve(cross(cur), lo.Address(), 20000)
	for i := uint64(0); i < 12; i++ {
		lo.CreateOrder(cross(cur), path, address(fooPath), address(barPath), 1000, 900, 0, expiry)
	}
	lo.CancelOrder(cross(cur), 2)
	cancelled, ok := lo.GetOrder(2)
	uassert.True(t, ok)
	uassert.Equal(t, lo.OrderStatusCancelled, cancelled.Status)
	uassert.Equal(t, uint64(1000), cancelled.RefundedInput)
	uassert.Equal(t, uint64(0), cancelled.RemainingInput)

	testing.SetRealm(testing.NewUserRealm(bob))
	foo.Approve(cross(cur), lo.Address(), 1000)
	lo.CreateOrder(cross(cur), path, address(fooPath), address(barPath), 1000, 900, 0, expiry)

	first, cursor := lo.GetOrders(0, 10)
	uassert.Equal(t, uint64(10), cursor)
	uassert.Equal(t, uint64(2), first[1].ID)
	uassert.Equal(t, uint64(9), first[8].ID)
	uassert.Equal(t, uint64(10), first[9].ID)
	last, cursor := lo.GetOrders(cursor, 10)
	uassert.Equal(t, uint64(11), last[0].ID)
	uassert.Equal(t, uint64(13), last[2].ID)
	uassert.Equal(t, uint64(0), cursor)
	owned, cursor := lo.GetOrdersByOwner(alice, 0, 10)
	uassert.Equal(t, lo.OrderStatusCancelled, owned[1].Status)
	uassert.Equal(t, uint64(10), cursor)
	owned, cursor = lo.GetOrdersByOwner(alice, cursor, 10)
	uassert.Equal(t, uint64(11), owned[0].ID)
	uassert.Equal(t, uint64(12), owned[1].ID)
	uassert.Equal(t, 2, len(owned))
	uassert.Equal(t, uint64(0), cursor)
	owned, cursor = lo.GetOrdersByOwner(bob, 0, 10)
	uassert.Equal(t, uint64(13), owned[0].ID)
	uassert.Equal(t, bob, owned[0].Owner)
	uassert.Equal(t, uint64(0), cursor)
	_, exists := lo.GetOrder(999)
	uassert.False(t, exists)
	pastEnd, cursor := lo.GetOrders(13, 10)
	uassert.Equal(t, 0, len(pastEnd))
	uassert.Equal(t, uint64(0), cursor)
}
