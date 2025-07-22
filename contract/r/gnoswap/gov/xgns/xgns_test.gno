package xgns

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"
	prbac "gno.land/p/gnoswap/rbac"
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
	testing.SetRealm(std.NewUserRealm(adminAddr))
	uassert.AbortsWithMessage(t, "[GNOSWAP-XGNS-001] caller has no permission || only gov/staker(g17e3ykyqk9jmqe2y9wxe9zhep3p7cw56davjqwa) or launchpad(g122mau2lp2rc0scs8d27pkkuys4w54mdy2tuer3) contract can call Mint, called from g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", func() {
		Mint(cross, govStakerAddress, amount)
	})
	uassert.AbortsWithMessage(t, "unauthorized: caller g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d is not launchpad", func() {
		MintByLaunchPad(cross, govStakerAddress, amount)
	})
}

func TestBurn(t *testing.T) {
	mintAmount := int64(1000)
	burnAmount := int64(200)

	testing.SetRealm(std.NewCodeRealm(consts.LAUNCHPAD_PATH))

	testing.SetRealm(std.NewCodeRealm(consts.LAUNCHPAD_PATH))
	Mint(cross, launchpadAddress, mintAmount)
	BurnByLaunchPad(cross, launchpadAddress, burnAmount)
	expectedBalance := mintAmount - burnAmount
	actualBalance := BalanceOf(launchpadAddress)
	if actualBalance != expectedBalance {
		t.Errorf("Burn() failed. Expected %d, got %d", expectedBalance, actualBalance)
	}

	// reset state by burn all
	Burn(cross, launchpadAddress, actualBalance)
}

func TestVotingSupply(t *testing.T) {
	initialSupply := int64(1000)
	launchpadBalance := int64(200)

	testing.SetRealm(std.NewCodeRealm(consts.LAUNCHPAD_PATH))

	func(cur realm) {
		testing.SetRealm(std.NewCodeRealm(consts.GOV_STAKER_PATH))
		Mint(cur, govStakerAddress, initialSupply-launchpadBalance)
	}(cross)

	func(cur realm) {
		testing.SetRealm(std.NewCodeRealm(consts.LAUNCHPAD_PATH))
		MintByLaunchPad(cur, launchpadAddress, launchpadBalance)
	}(cross)

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
	testing.SetRealm(std.NewUserRealm(adminAddr))
	uassert.AbortsWithMessage(t, "[GNOSWAP-XGNS-001] caller has no permission || only gov/staker(g17e3ykyqk9jmqe2y9wxe9zhep3p7cw56davjqwa) or launchpad(g122mau2lp2rc0scs8d27pkkuys4w54mdy2tuer3) contract can call Burn, called from g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", func() {
		Burn(cross, govStakerAddress, amount)
	})
	uassert.AbortsWithMessage(t, "unauthorized: caller g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d is not launchpad", func() {
		BurnByLaunchPad(cross, govStakerAddress, amount)
	})
}
