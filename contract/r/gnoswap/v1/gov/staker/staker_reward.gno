package staker

import (
	"std"
	"time"

	"gno.land/p/nt/ufmt"
	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/gov/xgns"
)

const WUGNOT_PATH string = "gno.land/r/gnoland/wugnot"

// CollectReward collects accumulated rewards based on xGNS holdings.
//
// Claims all pending rewards from governance staking.
// Distributes protocol fees and emission rewards proportionally.
// Multi-token rewards system based on xGNS share.
//
// Reward Types:
//  1. Emission rewards: GNS from protocol emission
//  2. Protocol fees: Various tokens from swap/pool fees
//  3. Withdrawal fees: 1% of liquidity provider rewards
//  4. Pool creation fees: 100 GNS per pool
//
// Distribution Formula:
//
//	userReward = (userXGNS / totalXGNS) * accumulatedRewards
//
// Process:
//  1. Calculates share based on xGNS balance
//  2. Claims GNS emission rewards
//  3. Claims protocol fee rewards (all tokens)
//  4. Transfers all rewards to caller
//  5. Resets user's reward tracking
//
// No parameters required - automatically determines caller's rewards.
// Transfers rewards directly to caller.
func CollectReward(cur realm) {
	halt.AssertIsNotHaltedGovStaker()
	halt.AssertIsNotHaltedWithdraw()

	caller := std.PreviousRealm().Address()
	from := std.CurrentRealm().Address()
	currentTimestamp := time.Now().Unix()

	emissionReward, protocolFeeRewards, err := claimRewards(caller.String(), currentTimestamp)
	if err != nil {
		panic(err)
	}

	// Transfer emission rewards (GNS tokens) if any
	if emissionReward > 0 {
		gns.Transfer(cross, caller, emissionReward)

		previousRealm := std.PreviousRealm()
		std.Emit(
			"CollectEmissionReward",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"from", from.String(),
			"to", caller.String(),
			"emissionRewardAmount", formatInt(emissionReward),
		)
	}

	// Transfer protocol fee rewards for each token type
	for tokenPath, amount := range protocolFeeRewards {
		if amount > 0 {
			err := transferToken(tokenPath, from, caller, amount)
			if err != nil {
				panic(err)
			}

			previousRealm := std.PreviousRealm()
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

// CollectRewardFromLaunchPad collects rewards for launchpad project wallets.
//
// Parameters:
//   - to: recipient address for rewards
//
// Only callable by launchpad contract.
func CollectRewardFromLaunchPad(cur realm, to std.Address) {
	halt.AssertIsNotHaltedGovStaker()
	halt.AssertIsNotHaltedWithdraw()

	caller := std.PreviousRealm().Address()
	access.AssertIsLaunchpad(caller)

	from := std.CurrentRealm().Address()
	currentTimestamp := time.Now().Unix()

	launchpadRewardID := makeLaunchpadRewardID(to.String())
	_, exists := getLaunchpadProjectDeposit(launchpadRewardID)
	if !exists {
		panic(makeErrorWithDetails(
			errNoDelegatedAmount,
			ufmt.Sprintf("%s is not project wallet from launchpad", to.String()),
		))
	}

	emissionReward, protocolFeeRewards, err := claimRewardsFromLaunchpad(to.String(), currentTimestamp)
	if err != nil {
		panic(err)
	}

	// Transfer emission rewards (GNS tokens) to project wallet if any
	if emissionReward > 0 {
		gns.Transfer(cross, to, emissionReward)

		previousRealm := std.PreviousRealm()
		std.Emit(
			"CollectEmissionFromLaunchPad",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"from", from.String(),
			"to", to.String(),
			"emissionRewardAmount", formatInt(emissionReward),
		)
	}

	// Transfer protocol fee rewards to project wallet for each token type
	for tokenPath, amount := range protocolFeeRewards {
		if amount > 0 {
			err := transferToken(tokenPath, from, to, amount)
			if err != nil {
				panic(err)
			}

			previousRealm := std.PreviousRealm()
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

// SetAmountByProjectWallet sets the amount of reward for the project wallet.
// This function is exclusively callable by the launchpad contract to manage
// xGNS balances for project wallets that participate in launchpad offerings.
//
// The function handles both adding and removing stakes:
// - When adding: mints xGNS to launchpad address and starts reward accumulation
// - When removing: burns xGNS from launchpad address and stops reward accumulation
// Adjusts stake amount for project wallet address.
// Panics:
//   - if caller is not the launchpad contract
//   - if system is halted for withdrawals
//   - if access control operations fail
func SetAmountByProjectWallet(cur realm, addr std.Address, amount int64, add bool) {
	halt.AssertIsNotHaltedGovStaker()
	halt.AssertIsNotHaltedWithdraw()

	caller := std.PreviousRealm().Address()
	currentTimestamp := time.Now().Unix()

	access.AssertIsLaunchpad(caller)

	launchpadAddr, exists := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	if !exists {
		panic(ufmt.Sprintf("launchpad address not found"))
	}

	if add {
		// Add stake for the project wallet and mint xGNS to launchpad
		err := addStakeFromLaunchpad(addr.String(), amount, currentTimestamp)
		if err != nil {
			panic(err)
		}

		xgns.Mint(cross, launchpadAddr, amount)
	} else {
		// Remove stake for the project wallet and burn xGNS from launchpad
		err := removeStakeFromLaunchpad(addr.String(), amount, currentTimestamp)
		if err != nil {
			panic(err)
		}

		xgns.Burn(cross, launchpadAddr, amount)
	}
}

// claimRewards claims both emission and protocol fee rewards.
// Coordinates claiming process for both reward types.
func claimRewards(rewardID string, currentTimestamp int64) (int64, map[string]int64, error) {
	emissionReward, err := claimRewardsEmissionReward(rewardID, currentTimestamp)
	if err != nil {
		return 0, nil, err
	}

	protocolFeeRewards, err := claimRewardsProtocolFeeReward(rewardID, currentTimestamp)
	if err != nil {
		return 0, nil, err
	}

	return emissionReward, protocolFeeRewards, nil
}

// claimRewardsFromLaunchpad claims rewards for launchpad project wallets.
// Uses special reward ID format for launchpad integration.
func claimRewardsFromLaunchpad(address string, currentTimestamp int64) (int64, map[string]int64, error) {
	launchpadRewardID := makeLaunchpadRewardID(address)

	return claimRewards(launchpadRewardID, currentTimestamp)
}

// transferToken transfers tokens from the staker contract to a recipient address.
// transferToken handles token transfers for reward distribution.
// Supports both native GNOT (through wUGNOT unwrapping) and GRC20 tokens.
func transferToken(
	tokenPath string,
	from, to std.Address,
	amount int64,
) error {
	common.MustRegistered(tokenPath)

	// Validate recipient address
	if !to.IsValid() {
		return makeErrorWithDetails(
			errInvalidAddress,
			ufmt.Sprintf("invalid address %s to transfer protocol fee", to.String()),
		)
	}

	// Validate transfer amount
	if amount < 0 {
		return makeErrorWithDetails(
			errInvalidAmount,
			ufmt.Sprintf("invalid amount %d to transfer protocol fee", amount),
		)
	}

	// Check sufficient balance
	balance := common.BalanceOf(tokenPath, from)
	if balance < amount {
		return makeErrorWithDetails(
			errNotEnoughBalance,
			ufmt.Sprintf("not enough %s balance(%d) to collect(%d)", tokenPath, balance, amount),
		)
	}

	// Handle native GNOT transfer through wUGNOT unwrapping
	isGnoNativeCoin := tokenPath == WUGNOT_PATH
	if isGnoNativeCoin {
		wugnot.Withdraw(cross, amount)

		sendCoin := std.Coin{Denom: "ugnot", Amount: amount}
		banker := std.NewBanker(std.BankerTypeRealmSend)
		banker.SendCoins(from, to, std.Coins{sendCoin})

		return nil
	}

	// Handle GRC20 token transfer
	return common.Transfer(cross, tokenPath, to, amount)
}
