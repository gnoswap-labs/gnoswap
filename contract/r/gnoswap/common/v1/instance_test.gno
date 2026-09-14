package common

import (
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/demo/defi/foo20"
)

const fooKey = "gno.land/r/demo/defi/foo20.FOO"

func TestCommonV1_Queries(cur realm, t *testing.T) {
	impl := NewCommonV1()

	uassert.True(t, impl.IsRegistered(fooKey))
	uassert.Equal(t, foo20.TotalSupply(), impl.TotalSupply(fooKey))
	uassert.Equal(t, foo20.BalanceOf(foo20.Ownable.Owner()), impl.BalanceOf(fooKey, foo20.Ownable.Owner()))

	for _, key := range []string{"", "gno.land/r/demo/defi/foo20", "not_registered"} {
		uassert.False(t, impl.IsRegistered(key), key)
		uassert.PanicsContains(t, cur, "unknown token", func() {
			impl.TotalSupply(key)
		})
	}
}

func TestCommonV1_TransferBindsCaller(cur realm, t *testing.T) {
	holder := foo20.Ownable.Owner()
	bob := testutils.TestAddress("bob")
	impl := NewCommonV1()

	testing.SetRealm(testing.NewUserRealm(holder))
	before := impl.BalanceOf(fooKey, bob)

	uassert.NoError(t, impl.Transfer(0, cur, fooKey, bob, 100))
	uassert.Equal(t, before+100, impl.BalanceOf(fooKey, bob))

	uassert.NoError(t, impl.Approve(0, cur, fooKey, bob, 50))
	uassert.Equal(t, int64(50), impl.Allowance(fooKey, holder, bob))
}
