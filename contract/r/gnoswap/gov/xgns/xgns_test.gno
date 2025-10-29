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

var (
	adminAddr        = getContractAddress(prbac.ROLE_ADMIN.String())
	govStakerAddress = getContractAddress(prbac.ROLE_GOV_STAKER.String())
	launchpadAddress = getContractAddress(prbac.ROLE_LAUNCHPAD.String())
)

func TestTotalSupply(t *testing.T) {
	expectedSupply := int64(0)
	actualSupply := TotalSupply()
	if actualSupply != expectedSupply {
		t.Errorf("TotalSupply() failed. Expected %d, got %d", expectedSupply, actualSupply)
	}
}

func TestMintFail(t *testing.T) {
	amount := int64(100)
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	uassert.AbortsWithMessage(t, "unauthorized: caller g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d is not gov_staker", func() {
		Mint(cross, govStakerAddress, amount)
	})
	uassert.AbortsWithMessage(t, "unauthorized: caller g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d is not launchpad", func() {
		MintByLaunchPad(cross, govStakerAddress, amount)
	})
}

func TestBurn(t *testing.T) {
	mintAmount := int64(1000)
	burnAmount := int64(200)

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

	MintByLaunchPad(cross, launchpadAddress, mintAmount)
	BurnByLaunchPad(cross, launchpadAddress, burnAmount)
	expectedBalance := mintAmount - burnAmount
	actualBalance := BalanceOf(launchpadAddress)
	if actualBalance != expectedBalance {
		t.Errorf("Burn() failed. Expected %d, got %d", expectedBalance, actualBalance)
	}

	// reset state by burn all
	BurnByLaunchPad(cross, launchpadAddress, actualBalance)
}

func TestVotingSupply(t *testing.T) {
	initialSupply := int64(1000)
	launchpadBalance := int64(200)

	testing.SetRealm(testing.NewUserRealm(govStakerAddress))
	Mint(cross, govStakerAddress, initialSupply-launchpadBalance)

	testing.SetRealm(testing.NewUserRealm(launchpadAddress))
	MintByLaunchPad(cross, launchpadAddress, launchpadBalance)

	expectedVotingSupply := initialSupply - launchpadBalance
	actualVotingSupply := VotingSupply()
	if actualVotingSupply != expectedVotingSupply {
		t.Errorf("VotingSupply() failed. Expected %d, got %d", expectedVotingSupply, actualVotingSupply)
	}

	expectedBalance := launchpadBalance
	actualBalance := BalanceOf(launchpadAddress)
	if actualBalance != expectedBalance {
		t.Errorf("BalanceOf() failed. Expected %d, got %d", expectedBalance, actualBalance)
	}
}

func TestBurnFail(t *testing.T) {
	amount := int64(100)
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	uassert.AbortsWithMessage(t, "unauthorized: caller g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d is not gov_staker", func() {
		Burn(cross, govStakerAddress, amount)
	})
	uassert.AbortsWithMessage(t, "unauthorized: caller g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d is not launchpad", func() {
		BurnByLaunchPad(cross, govStakerAddress, amount)
	})
}

func TestRender(t *testing.T) {
	// Test empty path - should return token home
	result := Render("")
	if result == "" {
		t.Errorf("Render('') should return token home, got empty string")
	}

	// Setup: mint some tokens to test balance rendering
	testing.SetRealm(testing.NewUserRealm(govStakerAddress))
	testAddr := govStakerAddress
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

// getContractAddress retrieves the address which registered the role
func getContractAddress(roleName string) address {
	addr, exists := access.GetAddress(roleName)
	if !exists {
		return rbac.DefaultRoleAddresses[prbac.SystemRole(roleName)]
	}

	return addr
}

func cleanup(t *testing.T) {
	admin = ownable.NewWithAddress(testutils.TestAddress("admin"))
	token, ledger = grc20.NewToken("XGNS", "xGNS", 6)
}
