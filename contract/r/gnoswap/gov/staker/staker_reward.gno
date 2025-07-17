package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/xgns"
)

// CollectReward collects the rewards from the protocol fee contract based on the holdings of xGNS.
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#collectreward
func CollectReward(cur realm) {
	previousRealm := std.PreviousRealm()
	caller := previousRealm.Address()
	from := std.CurrentRealm().Address()
	currentHeight := std.ChainHeight()

	assertIsNotHaltedWithdraw()

	emissionReward, protocolFeeRewards, err := claimRewards(caller.String(), currentHeight)
	if err != nil {
		panic(err)
	}

	if emissionReward > 0 {
		gns.Transfer(cross, caller, emissionReward)

		std.Emit(
			"CollectEmissionReward",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"from", from.String(),
			"to", caller.String(),
			"emissionRewardAmount", formatInt(emissionReward),
		)
	}

	for tokenPath, amount := range protocolFeeRewards {
		if amount > 0 {
			err := transferToken(tokenPath, from, caller, amount)
			if err != nil {
				panic(err)
			}

			std.Emit(
				"CollectProtocolFeeReward",
				"prevAddr", previousRealm.Address().String(),
				"prevRealm", previousRealm.PkgPath(),
				"tokenPath", tokenPath,
				"from", from.String(),
				"to", caller.String(),
				"collectedAmount", formatInt(amount),
			)
		}
	}
}

// CollectRewardFromLaunchPad collects the rewards from the protocol fee contract based on the holdings of xGNS in the launchpad contract.
// Only launchpad contract can call this function
// ref: https://docs.gnoswap.io/contracts/governance/staker.gno#collectrewardfromlaunchpad
func CollectRewardFromLaunchPad(cur realm, to std.Address) {
	previousRealm := std.PreviousRealm()
	from := std.CurrentRealm().Address()
	caller := previousRealm.Address()
	currentHeight := std.ChainHeight()

	assertCallerIsLaunchpad(caller)
	assertIsNotHaltedWithdraw()

	launchpadRewardID := makeLaunchpadRewardID(to.String())
	_, exists := getLaunchpadProjectDeposit(launchpadRewardID)
	if !exists {
		panic(addDetailToError(
			errNoDelegatedAmount,
			ufmt.Sprintf("%s is not project wallet from launchpad", to.String()),
		))
	}

	emissionReward, protocolFeeRewards, err := claimRewardsFromLaunchpad(to.String(), currentHeight)
	if err != nil {
		panic(err)
	}

	if emissionReward > 0 {
		gns.Transfer(cross, to, emissionReward)

		std.Emit(
			"CollectEmissionFromLaunchPad",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"from", from.String(),
			"to", to.String(),
			"emissionRewardAmount", formatInt(emissionReward),
		)
	}

	for tokenPath, amount := range protocolFeeRewards {
		if amount > 0 {
			err := transferToken(tokenPath, from, to, amount)
			if err != nil {
				panic(err)
			}

			std.Emit(
				"CollectProtocolFeeFromLaunchPad",
				"prevAddr", previousRealm.Address().String(),
				"prevRealm", previousRealm.PkgPath(),
				"tokenPath", tokenPath,
				"from", from.String(),
				"to", to.String(),
				"collectedAmount", formatInt(amount),
			)
		}
	}
}

// SetAmountByProjectWallet sets the amount of reward for the project wallet
func SetAmountByProjectWallet(cur realm, addr std.Address, amount int64, add bool) {
	caller := std.PreviousRealm().Address()
	currentHeight := std.ChainHeight()

	assertCallerIsLaunchpad(caller)
	assertIsNotHaltedWithdraw()

	if add {
		addStakeFromLaunchpad(addr.String(), amount, currentHeight)
		xgns.Mint(cross, addr, amount)
	} else {
		removeStakeFromLaunchpad(addr.String(), amount, currentHeight)
		xgns.Burn(cross, addr, amount)
	}
}

func claimRewards(rewardID string, currentHeight int64) (int64, map[string]int64, error) {
	emissionReward, err := claimRewardsEmissionReward(rewardID, currentHeight)
	if err != nil {
		return 0, nil, err
	}

	protocolFeeRewards, err := claimRewardsProtocolFeeReward(rewardID, currentHeight)
	if err != nil {
		return 0, nil, err
	}

	return emissionReward, protocolFeeRewards, nil
}

func claimRewardsFromLaunchpad(address string, currentHeight int64) (int64, map[string]int64, error) {
	launchpadRewardID := makeLaunchpadRewardID(address)

	return claimRewards(launchpadRewardID, currentHeight)
}

func transferToken(
	tokenPath string,
	from, to std.Address,
	amount int64,
) error {
	common.MustRegistered(tokenPath)

	if !to.IsValid() {
		return makeErrorWithDetail(
			errInvalidAddress,
			ufmt.Sprintf("invalid address %s to transfer protocol fee", to.String()),
		)
	}

	if amount < 0 {
		return makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("invalid amount %d to transfer protocol fee", amount),
		)
	}

	balance := common.BalanceOf(tokenPath, from)
	if balance < amount {
		return makeErrorWithDetail(
			errNotEnoughBalance,
			ufmt.Sprintf("not enough %s balance(%d) to collect(%d)", tokenPath, balance, amount),
		)
	}

	isGnoNativeCoin := tokenPath == consts.WUGNOT_PATH
	if isGnoNativeCoin {
		wugnot.Withdraw(cross, amount)

		sendCoin := std.Coin{Denom: "ugnot", Amount: amount}
		banker := std.NewBanker(std.BankerTypeRealmSend)
		banker.SendCoins(from, to, std.Coins{sendCoin})

		return nil
	}

	return common.Transfer(cross, tokenPath, to, amount)
}
