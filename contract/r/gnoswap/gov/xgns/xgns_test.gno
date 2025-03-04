package xgns

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
)

var adminAddr = getContractAddress(access.ROLE_ADMIN)

func TestTotalSupply(t *testing.T) {
	expectedSupply := uint64(0)
	actualSupply := TotalSupply()
	if actualSupply != expectedSupply {
		t.Errorf("TotalSupply() failed. Expected %d, got %d", expectedSupply, actualSupply)
	}
}

func TestVotingSupply(t *testing.T) {
	initialSupply := uint64(1000)
	launchpadBalance := uint64(200)

	std.TestSetRealm(std.NewCodeRealm(consts.GOV_STAKER_PATH))
	Mint(govStakerAddr, initialSupply-launchpadBalance)

	std.TestSetRealm(std.NewCodeRealm(consts.LAUNCHPAD_PATH))
	MintByLaunchPad(launchpadAddr, launchpadBalance)

	expectedVotingSupply := initialSupply - launchpadBalance
	actualVotingSupply := VotingSupply()
	if actualVotingSupply != expectedVotingSupply {
		t.Errorf("VotingSupply() failed. Expected %d, got %d", expectedVotingSupply, actualVotingSupply)
	}

	expectedBalance := launchpadBalance
	actualBalance := BalanceOf(launchpadAddr)
	if actualBalance != expectedBalance {
		t.Errorf("BalanceOf() failed. Expected %d, got %d", expectedBalance, actualBalance)
	}
}

func TestMintFail(t *testing.T) {
	amount := uint64(100)
	std.TestSetRealm(std.NewUserRealm(adminAddr))
	uassert.PanicsWithMessage(t, "[GNOSWAP-XGNS-001] caller has no permission || only gov/staker(g17e3ykyqk9jmqe2y9wxe9zhep3p7cw56davjqwa) or launchpad(g122mau2lp2rc0scs8d27pkkuys4w54mdy2tuer3) contract can call Mint, called from g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", func() {
		Mint(govStakerAddr, amount)
	})
	uassert.PanicsWithMessage(t, "[GNOSWAP-XGNS-001] caller has no permission || only launchpad(g122mau2lp2rc0scs8d27pkkuys4w54mdy2tuer3) contract can call MintByLaunchPad, called from g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", func() {
		MintByLaunchPad(govStakerAddr, amount)
	})
}

func TestBurn(t *testing.T) {
	burnAmount := uint64(200)

	std.TestSetRealm(std.NewCodeRealm(consts.LAUNCHPAD_PATH))
	BurnByLaunchPad(launchpadAddr, burnAmount)
	expectedBalance := uint64(0)
	actualBalance := BalanceOf(launchpadAddr)
	if actualBalance != expectedBalance {
		t.Errorf("Burn() failed. Expected %d, got %d", expectedBalance, actualBalance)
	}
}

func TestBurnFail(t *testing.T) {
	amount := uint64(100)
	std.TestSetRealm(std.NewUserRealm(adminAddr))
	uassert.PanicsWithMessage(t, "[GNOSWAP-XGNS-001] caller has no permission || only gov/staker(g17e3ykyqk9jmqe2y9wxe9zhep3p7cw56davjqwa) or launchpad(g122mau2lp2rc0scs8d27pkkuys4w54mdy2tuer3) contract can call Burn, called from g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", func() {
		Burn(govStakerAddr, amount)
	})
	uassert.PanicsWithMessage(t, "[GNOSWAP-XGNS-001] caller has no permission || only launchpad(g122mau2lp2rc0scs8d27pkkuys4w54mdy2tuer3) contract can call BurnByLaunchPad, called from g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", func() {
		BurnByLaunchPad(govStakerAddr, amount)
	})
}
