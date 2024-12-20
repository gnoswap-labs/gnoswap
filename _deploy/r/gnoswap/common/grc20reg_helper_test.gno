package common

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/foo20"
)

var (
	tokenPath = "gno.land/r/demo/foo20"
)

func TestGetToken(t *testing.T) {
	t.Run("get regsitered token", func(t *testing.T) {
		token := GetToken(tokenPath)
		if token == nil {
			t.Error("Expected non-nil token for foo20")
		}
	})

	t.Run("get non registered token", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Expected panic for non-registered token")
			}
		}()
		GetToken("not_registered_token")
	})
}

func TestTokenMethod(t *testing.T) {
	token := GetToken(tokenPath)

	t.Run("GetName()", func(t *testing.T) {
		uassert.Equal(t, "Foo", token.GetName())
	})

	t.Run("GetSymbol()", func(t *testing.T) {
		uassert.Equal(t, "FOO", token.GetSymbol())
	})

	t.Run("GetDecimals()", func(t *testing.T) {
		uassert.Equal(t, uint(4), token.GetDecimals())
	})

	t.Run("TotalSupply()", func(t *testing.T) {
		uassert.Equal(t, uint64(10000000000), token.TotalSupply())
	})

	t.Run("KnownAccounts()", func(t *testing.T) {
		uassert.Equal(t, int(1), token.KnownAccounts())
	})

	t.Run("BalanceOf()", func(t *testing.T) {
		uassert.Equal(t, uint64(10000000000), token.BalanceOf(std.Address("g1manfred47kzduec920z88wfr64ylksmdcedlf5")))
	})

	t.Run("Allowance()", func(t *testing.T) {
		uassert.Equal(t, uint64(0), token.Allowance(std.Address("g1manfred47kzduec920z88wfr64ylksmdcedlf5"), std.Address("g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6")))
	})

	t.Run("RenderHome()", func(t *testing.T) {
		expected := ""
		expected += ufmt.Sprintf("# %s ($%s)\n\n", "Foo", "FOO")
		expected += ufmt.Sprintf("* **Decimals**: %d\n", 4)
		expected += ufmt.Sprintf("* **Total supply**: %d\n", 10000000000)
		expected += ufmt.Sprintf("* **Known accounts**: %d\n", 1)
		uassert.Equal(t, expected, token.RenderHome())
	})
}

func TestGetTokenTeller(t *testing.T) {
	t.Run("get registered token teller", func(t *testing.T) {
		teller := GetTokenTeller(tokenPath)
		if teller == nil {
			t.Error("Expected non-nil teller for foo20")
		}
	})

	t.Run("get non registered token teller", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Expected panic for non-registered token teller")
			}
		}()
		GetTokenTeller("not_registered_teller")
	})
}

func TestTellerMethod(t *testing.T) {
	teller := GetTokenTeller(tokenPath)
	token := GetToken(tokenPath)
	defaultHolder := std.Address("g1manfred47kzduec920z88wfr64ylksmdcedlf5")
	addr01 := testutils.TestAddress("addr01")

	t.Run("Transfer()", func(t *testing.T) {
		std.TestSetRealm(std.NewUserRealm(defaultHolder))

		uassert.Equal(t, uint64(10000000000), token.BalanceOf(defaultHolder))

		uassert.NoError(t, teller.Transfer(addr01, uint64(10000000000))) // transfer all balance to addr01

		uassert.Equal(t, uint64(0), token.BalanceOf(defaultHolder))
		uassert.Equal(t, uint64(10000000000), token.BalanceOf(addr01))

		uassert.Error(t, teller.Transfer(addr01, uint64(10000000000))) // not enough balance
	})

	t.Run("Approve()", func(t *testing.T) {
		std.TestSetRealm(std.NewUserRealm(addr01))
		uassert.NoError(t, teller.Approve(defaultHolder, uint64(500)))
		uassert.Equal(t, uint64(500), token.Allowance(addr01, defaultHolder))
	})

	t.Run("TransferFrom()", func(t *testing.T) {
		std.TestSetRealm(std.NewUserRealm(defaultHolder))
		uassert.NoError(t, teller.TransferFrom(addr01, defaultHolder, uint64(500)))
		uassert.Equal(t, uint64(9999999500), token.BalanceOf(addr01))
		uassert.Equal(t, uint64(500), token.BalanceOf(defaultHolder))
		uassert.Equal(t, uint64(0), token.Allowance(addr01, defaultHolder))

		uassert.Error(t, teller.TransferFrom(addr01, defaultHolder, uint64(500))) // not enough allowance
	})
}

func TestIsRegistered(t *testing.T) {
	t.Run("check if token is registered", func(t *testing.T) {
		uassert.NoError(t, IsRegistered(tokenPath))
	})

	t.Run("check if token is not registered", func(t *testing.T) {
		uassert.Error(t, IsRegistered("not_registered_token"))
	})
}

func TestMustRegistered(t *testing.T) {
	t.Run("must be registered", func(t *testing.T) {
		MustRegistered(tokenPath)
	})

	t.Run("panic for non registered token", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Expected panic for non-registered token")
			}
		}()
		MustRegistered("not_registered")
	})
}

func TestTotalSupply(t *testing.T) {
	// result from grc2reg and (direct import/call) should be the same
	uassert.Equal(t, foo20.TotalSupply(), TotalSupply(tokenPath))
}

func TestBalanceOf(t *testing.T) {
	defaultHolder := std.Address("g1manfred47kzduec920z88wfr64ylksmdcedlf5")

	// result from grc2reg and (direct import/call) should be the same
	uassert.Equal(t, foo20.BalanceOf(AddrToUser(defaultHolder)), BalanceOf(tokenPath, defaultHolder))
}

func TestAllowance(t *testing.T) {
	owner := std.Address("g1manfred47kzduec920z88wfr64ylksmdcedlf5")
	spender := std.Address("g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6")

	// result from grc2reg and (direct import/call) should be the same
	uassert.Equal(t, foo20.Allowance(AddrToUser(owner), AddrToUser(spender)), Allowance(tokenPath, owner, spender))
}
