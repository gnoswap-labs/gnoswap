package xgns

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
)

var (
	adminAddr        = getContractAddress(access.ROLE_ADMIN)
	govStakerAddress = getContractAddress(access.ROLE_GOV_STAKER)
	launchpadAddress = getContractAddress(access.ROLE_LAUNCHPAD)
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
	uassert.PanicsWithMessage(t, "[GNOSWAP-XGNS-001] caller has no permission || only gov/staker(g17e3ykyqk9jmqe2y9wxe9zhep3p7cw56davjqwa) or launchpad(g122mau2lp2rc0scs8d27pkkuys4w54mdy2tuer3) contract can call Mint, called from g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", func() {
		testing.SetRealm(std.NewCodeRealm(consts.GOV_STAKER_PATH))
		Mint(cross, govStakerAddress, amount)
	})
	uassert.PanicsWithMessage(t, "[GNOSWAP-XGNS-001] caller has no permission || only launchpad(g122mau2lp2rc0scs8d27pkkuys4w54mdy2tuer3) contract can call MintByLaunchPad, called from g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", func() {
		testing.SetRealm(std.NewCodeRealm(consts.GOV_STAKER_PATH))
		MintByLaunchPad(cross, govStakerAddress, amount)
	})
}

func TestBurn(t *testing.T) {
	mintAmount := int64(1000)
	burnAmount := int64(200)

	testing.SetRealm(std.NewCodeRealm(consts.LAUNCHPAD_PATH))

	func(cur realm) {
		testing.SetRealm(std.NewCodeRealm(consts.LAUNCHPAD_PATH))
		Mint(cur, launchpadAddress, mintAmount)
		BurnByLaunchPad(cur, launchpadAddress, burnAmount)
		expectedBalance := mintAmount - burnAmount
		actualBalance := BalanceOf(launchpadAddress)
		if actualBalance != expectedBalance {
			t.Errorf("Burn() failed. Expected %d, got %d", expectedBalance, actualBalance)
		}

		// reset state by burn all
		Burn(cur, launchpadAddress, actualBalance)
	}(cross)
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
	uassert.PanicsWithMessage(t, "[GNOSWAP-XGNS-001] caller has no permission || only gov/staker(g17e3ykyqk9jmqe2y9wxe9zhep3p7cw56davjqwa) or launchpad(g122mau2lp2rc0scs8d27pkkuys4w54mdy2tuer3) contract can call Burn, called from g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", func() {
		testing.SetRealm(std.NewCodeRealm(consts.GOV_STAKER_PATH))
		Burn(cross, govStakerAddress, amount)
	})
	uassert.PanicsWithMessage(t, "[GNOSWAP-XGNS-001] caller has no permission || only launchpad(g122mau2lp2rc0scs8d27pkkuys4w54mdy2tuer3) contract can call BurnByLaunchPad, called from g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", func() {
		testing.SetRealm(std.NewCodeRealm(consts.GOV_STAKER_PATH))
		BurnByLaunchPad(cross, govStakerAddress, amount)
	})
}
