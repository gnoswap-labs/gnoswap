package xgns

import (
	"testing"

	"gno.land/p/demo/tokens/grc20"
	"gno.land/p/nt/ownable"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/access"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/rbac"
)

func TestXgns_TotalSupply(t *testing.T) {
	expectedSupply := int64(0)
	actualSupply := TotalSupply()
	if actualSupply != expectedSupply {
		t.Errorf("TotalSupply() failed. Expected %d, got %d", expectedSupply, actualSupply)
	}
}

func TestXgns_Mint(t *testing.T) {
	amount := int64(1000)
	initialSupply := TotalSupply()

	// Test Mint success
	testing.SetRealm(testing.NewUserRealm(getGovStakerAddress()))
	Mint(cross, getGovStakerAddress(), amount)

	expectedSupply := initialSupply + amount
	actualSupply := TotalSupply()
	if actualSupply != expectedSupply {
		t.Errorf("Mint() failed. Expected total supply %d, got %d", expectedSupply, actualSupply)
	}

	expectedBalance := amount
	actualBalance := BalanceOf(getGovStakerAddress())
	if actualBalance < expectedBalance {
		t.Errorf("Mint() failed. Expected balance at least %d, got %d", expectedBalance, actualBalance)
	}

	// Cleanup
	Burn(cross, getGovStakerAddress(), amount)
}

func TestXgns_MintByLaunchPad(t *testing.T) {
	amount := int64(500)
	initialSupply := TotalSupply()

	// Test MintByLaunchPad success
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))
	MintByLaunchPad(cross, getLaunchpadAddress(), amount)

	expectedSupply := initialSupply + amount
	actualSupply := TotalSupply()
	if actualSupply != expectedSupply {
		t.Errorf("MintByLaunchPad() failed. Expected total supply %d, got %d", expectedSupply, actualSupply)
	}

	// Cleanup
	BurnByLaunchPad(cross, getLaunchpadAddress(), amount)
}

func TestXgns_MintUnauthorized(t *testing.T) {
	amount := int64(100)
	testing.SetRealm(testing.NewUserRealm(getAdminAddress()))
	uassert.AbortsWithMessage(t, "unauthorized: caller g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d is not gov_staker", func() {
		Mint(cross, getGovStakerAddress(), amount)
	})
	uassert.AbortsWithMessage(t, "unauthorized: caller g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d is not launchpad", func() {
		MintByLaunchPad(cross, getGovStakerAddress(), amount)
	})
}

func TestXgns_Burn(t *testing.T) {
	mintAmount := int64(1000)
	burnAmount := int64(200)
	initialSupply := TotalSupply()

	// Test Burn by gov staker
	testing.SetRealm(testing.NewUserRealm(getGovStakerAddress()))
	Mint(cross, getGovStakerAddress(), mintAmount)

	initialBalance := BalanceOf(getGovStakerAddress())
	Burn(cross, getGovStakerAddress(), burnAmount)

	expectedBalance := initialBalance - burnAmount
	actualBalance := BalanceOf(getGovStakerAddress())
	if actualBalance != expectedBalance {
		t.Errorf("Burn() failed. Expected balance %d, got %d", expectedBalance, actualBalance)
	}

	expectedSupply := initialSupply + mintAmount - burnAmount
	actualSupply := TotalSupply()
	if actualSupply != expectedSupply {
		t.Errorf("Burn() failed. Expected total supply %d, got %d", expectedSupply, actualSupply)
	}

	// Cleanup
	remainingBalance := BalanceOf(getGovStakerAddress())
	if remainingBalance > 0 {
		Burn(cross, getGovStakerAddress(), mintAmount-burnAmount)
	}
}

func TestXgns_BurnByLaunchPad(t *testing.T) {
	mintAmount := int64(1000)
	burnAmount := int64(200)

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

	MintByLaunchPad(cross, getLaunchpadAddress(), mintAmount)
	BurnByLaunchPad(cross, getLaunchpadAddress(), burnAmount)
	expectedBalance := mintAmount - burnAmount
	actualBalance := BalanceOf(getLaunchpadAddress())
	if actualBalance < expectedBalance {
		t.Errorf("BurnByLaunchPad() failed. Expected at least %d, got %d", expectedBalance, actualBalance)
	}

	// reset state by burn all
	currentBalance := BalanceOf(getLaunchpadAddress())
	BurnByLaunchPad(cross, getLaunchpadAddress(), currentBalance)
}

func TestXgns_VotingSupply(t *testing.T) {
	initialSupply := int64(1000)
	launchpadBalance := int64(200)

	testing.SetRealm(testing.NewUserRealm(getGovStakerAddress()))
	Mint(cross, getGovStakerAddress(), initialSupply-launchpadBalance)

	testing.SetRealm(testing.NewUserRealm(getLaunchpadAddress()))
	MintByLaunchPad(cross, getLaunchpadAddress(), launchpadBalance)

	expectedVotingSupply := initialSupply - launchpadBalance
	actualVotingSupply := VotingSupply()
	if actualVotingSupply != expectedVotingSupply {
		t.Errorf("VotingSupply() failed. Expected %d, got %d", expectedVotingSupply, actualVotingSupply)
	}

	expectedBalance := launchpadBalance
	actualBalance := BalanceOf(getLaunchpadAddress())
	if actualBalance != expectedBalance {
		t.Errorf("BalanceOf() failed. Expected %d, got %d", expectedBalance, actualBalance)
	}
}

func TestXgns_BurnUnauthorized(t *testing.T) {
	amount := int64(100)
	testing.SetRealm(testing.NewUserRealm(getAdminAddress()))
	uassert.AbortsWithMessage(t, "unauthorized: caller g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d is not gov_staker", func() {
		Burn(cross, getGovStakerAddress(), amount)
	})
	uassert.AbortsWithMessage(t, "unauthorized: caller g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d is not launchpad", func() {
		BurnByLaunchPad(cross, getGovStakerAddress(), amount)
	})
}

func TestXgns_BalanceOf(t *testing.T) {
	// Test balance for address with zero balance
	zeroBalance := BalanceOf(getAdminAddress())
	if zeroBalance < 0 {
		t.Errorf("BalanceOf() should not return negative value, got %d", zeroBalance)
	}

	// Test balance after minting
	testing.SetRealm(testing.NewUserRealm(getGovStakerAddress()))
	mintAmount := int64(500)
	initialBalance := BalanceOf(getGovStakerAddress())
	Mint(cross, getGovStakerAddress(), mintAmount)

	newBalance := BalanceOf(getGovStakerAddress())
	expectedBalance := initialBalance + mintAmount
	if newBalance != expectedBalance {
		t.Errorf("BalanceOf() failed after mint. Expected %d, got %d", expectedBalance, newBalance)
	}

	// Cleanup
	Burn(cross, getGovStakerAddress(), mintAmount)
}

func TestXgns_EdgeCases(t *testing.T) {
	testing.SetRealm(testing.NewUserRealm(getGovStakerAddress()))

	// Test minting with negative amount - should panic with "invalid amount"
	uassert.AbortsWithMessage(t, "invalid amount", func() {
		Mint(cross, getGovStakerAddress(), -100)
	})

	// Test burning with negative amount - should panic with "invalid amount"
	uassert.AbortsWithMessage(t, "invalid amount", func() {
		Burn(cross, getGovStakerAddress(), -100)
	})

	// Test burning more than balance - should panic
	Mint(cross, getGovStakerAddress(), 100)
	uassert.AbortsWithMessage(t, "insufficient balance", func() {
		Burn(cross, getGovStakerAddress(), 10000)
	})

	// Cleanup
	currentBalance := BalanceOf(getGovStakerAddress())
	if currentBalance >= 100 {
		Burn(cross, getGovStakerAddress(), 100)
	}
}

func TestXgns_ZeroAmount(t *testing.T) {
	testing.SetRealm(testing.NewUserRealm(getGovStakerAddress()))
	initialSupply := TotalSupply()
	initialBalance := BalanceOf(getGovStakerAddress())

	// Test minting with zero amount - should succeed but not change anything
	Mint(cross, getGovStakerAddress(), 0)

	newSupply := TotalSupply()
	newBalance := BalanceOf(getGovStakerAddress())

	if newSupply != initialSupply {
		t.Errorf("Mint(0) should not change total supply. Expected %d, got %d", initialSupply, newSupply)
	}

	if newBalance != initialBalance {
		t.Errorf("Mint(0) should not change balance. Expected %d, got %d", initialBalance, newBalance)
	}

	// Test burning with zero amount - should succeed but not change anything
	Burn(cross, getGovStakerAddress(), 0)

	finalSupply := TotalSupply()
	finalBalance := BalanceOf(getGovStakerAddress())

	if finalSupply != newSupply {
		t.Errorf("Burn(0) should not change total supply. Expected %d, got %d", newSupply, finalSupply)
	}

	if finalBalance != newBalance {
		t.Errorf("Burn(0) should not change balance. Expected %d, got %d", newBalance, finalBalance)
	}
}

func TestXgns_Render(t *testing.T) {
	// Test empty path - should return token home
	result := Render("")
	if result == "" {
		t.Errorf("Render('') should return token home, got empty string")
	}

	// Setup: mint some tokens to test balance rendering
	testing.SetRealm(testing.NewUserRealm(getGovStakerAddress()))
	testAddr := getGovStakerAddress()
	initialBalance := BalanceOf(testAddr)
	mintAmount := int64(1000)
	Mint(cross, testAddr, mintAmount)

	// Test balance path
	result = Render("balance/" + string(testAddr))
	expectedBalance := initialBalance + mintAmount
	expected := ufmt.Sprintf("%d\n", expectedBalance)
	if result != expected {
		t.Errorf("Render('balance/addr') failed. Expected %s, got %s", expected, result)
	}

	// Test invalid path - should return 404
	result = Render("invalid/path")
	expected = "404\n"
	if result != expected {
		t.Errorf("Render('invalid/path') failed. Expected %s, got %s", expected, result)
	}

	// Cleanup
	Burn(cross, testAddr, mintAmount)
}

// Helper functions

func getAdminAddress() address {
	addr, exists := access.GetAddress(prbac.ROLE_ADMIN.String())
	if !exists {
		return rbac.DefaultRoleAddresses[prbac.ROLE_ADMIN]
	}
	return addr
}

func getGovStakerAddress() address {
	addr, exists := access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	if !exists {
		return rbac.DefaultRoleAddresses[prbac.ROLE_GOV_STAKER]
	}
	return addr
}

func getLaunchpadAddress() address {
	addr, exists := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	if !exists {
		return rbac.DefaultRoleAddresses[prbac.ROLE_LAUNCHPAD]
	}
	return addr
}

func cleanup(t *testing.T) {
	admin = ownable.NewWithAddress(testutils.TestAddress("admin"))
	token, ledger = grc20.NewToken("XGNS", "xGNS", 6)
}
