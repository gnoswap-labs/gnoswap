package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/xgns"
	"gno.land/r/gnoswap/v1/halt"
)

// CollectReward collects the rewards from the protocol fee contract based on the holdings of xGNS.
// This function allows stakers to claim both emission rewards (in GNS) and protocol fee rewards (in various tokens)
// that have accumulated based on their xGNS holdings.
//
// The collection process involves:
// 1. Checking system halt status
// 2. Claiming emission and protocol fee rewards
// 3. Transferring GNS emission rewards to the caller
// 4. Transferring protocol fee rewards in various tokens to the caller
// 5. Emitting events for each type of reward collected
//
// Parameters:
//   - cur: realm context for cross-realm calls
//
// Panics:
//   - if system is halted for withdrawals
//   - if reward claiming fails
//   - if token transfers fail
//
// Reference: https://docs.gnoswap.io/contracts/governance/staker.gno#collectreward
func CollectReward(cur realm) {
	halt.AssertIsNotHaltedGovStaker()
	halt.AssertIsNotHaltedWithdraw()

	previousRealm := std.PreviousRealm()
	caller := previousRealm.Address()	
	from := std.CurrentRealm().Address()
	currentHeight := std.ChainHeight()


	emissionReward, protocolFeeRewards, err := claimRewards(caller.String(), currentHeight)
	if err != nil {
		panic(err)
	}

	// Transfer emission rewards (GNS tokens) if any
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

	// Transfer protocol fee rewards for each token type
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
// This function is exclusively callable by the launchpad contract to collect rewards on behalf of project wallets
// that have deposited tokens through the launchpad system.
//
// The collection process involves:
// 1. Verifying caller is the launchpad contract
// 2. Checking system halt status
// 3. Validating the project wallet is registered in launchpad
// 4. Claiming emission and protocol fee rewards for the project wallet
// 5. Transferring rewards directly to the project wallet
//
// Parameters:
//   - cur: realm context for cross-realm calls
//   - to: project wallet address to collect rewards for
//
// Panics:
//   - if caller is not the launchpad contract
//   - if system is halted for withdrawals
//   - if project wallet is not registered in launchpad
//   - if reward claiming or transfers fail
//
// Reference: https://docs.gnoswap.io/contracts/governance/staker.gno#collectrewardfromlaunchpad
func CollectRewardFromLaunchPad(cur realm, to std.Address) {
	halt.AssertIsNotHaltedGovStaker()
	halt.AssertIsNotHaltedWithdraw()
	
	previousRealm := std.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsLaunchpad(caller)

	from := std.CurrentRealm().Address()
	currentHeight := std.ChainHeight()

	launchpadRewardID := makeLaunchpadRewardID(to.String())
	_, exists := getLaunchpadProjectDeposit(launchpadRewardID)
	if !exists {
		panic(makeErrorWithDetails(
			errNoDelegatedAmount,
			ufmt.Sprintf("%s is not project wallet from launchpad", to.String()),
		))
	}

	emissionReward, protocolFeeRewards, err := claimRewardsFromLaunchpad(to.String(), currentHeight)
	if err != nil {
		panic(err)
	}

	// Transfer emission rewards (GNS tokens) to project wallet if any
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

	// Transfer protocol fee rewards to project wallet for each token type
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

// SetAmountByProjectWallet sets the amount of reward for the project wallet.
// This function is exclusively callable by the launchpad contract to manage
// xGNS balances for project wallets that participate in launchpad offerings.
//
// The function handles both adding and removing stakes:
// - When adding: mints xGNS to launchpad address and starts reward accumulation
// - When removing: burns xGNS from launchpad address and stops reward accumulation
//
// Parameters:
//   - cur: realm context for cross-realm calls
//   - addr: project wallet address
//   - amount: amount of stake to add or remove
//   - add: true to add stake, false to remove stake
//
// Panics:
//   - if caller is not the launchpad contract
//   - if system is halted for withdrawals
//   - if access control operations fail
func SetAmountByProjectWallet(cur realm, addr std.Address, amount int64, add bool) {
	halt.AssertIsNotHaltedGovStaker()
	halt.AssertIsNotHaltedWithdraw()

	caller := std.PreviousRealm().Address()
	currentHeight := std.ChainHeight()

	access.AssertIsLaunchpad(caller)

	launchpadAddr, exists := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	if !exists {
		panic(ufmt.Sprintf("launchpad address not found"))
	}

	if add {
		// Add stake for the project wallet and mint xGNS to launchpad
		addStakeFromLaunchpad(addr.String(), amount, currentHeight)
		xgns.Mint(cross, launchpadAddr, amount)
	} else {
		// Remove stake for the project wallet and burn xGNS from launchpad
		removeStakeFromLaunchpad(addr.String(), amount, currentHeight)
		xgns.Burn(cross, launchpadAddr, amount)
	}
}

// claimRewards is the internal function that claims both emission and protocol fee rewards.
// This function coordinates the claiming process for both reward types.
//
// Parameters:
//   - rewardID: identifier for the reward account (typically user address)
//   - currentHeight: current block height
//
// Returns:
//   - int64: emission reward amount claimed
//   - map[string]int64: protocol fee rewards claimed by token
//   - error: nil on success, error if claiming fails
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

// claimRewardsFromLaunchpad is the internal function that claims rewards for launchpad project wallets.
// This function uses a special reward ID format for launchpad integration.
//
// Parameters:
//   - address: project wallet address
//   - currentHeight: current block height
//
// Returns:
//   - int64: emission reward amount claimed
//   - map[string]int64: protocol fee rewards claimed by token
//   - error: nil on success, error if claiming fails
func claimRewardsFromLaunchpad(address string, currentHeight int64) (int64, map[string]int64, error) {
	launchpadRewardID := makeLaunchpadRewardID(address)

	return claimRewards(launchpadRewardID, currentHeight)
}

// transferToken transfers tokens from the staker contract to a recipient address.
// This function handles both native GNOT (through wUGNOT unwrapping) and GRC20 tokens,
// with proper validation and balance checking.
//
// Parameters:
//   - tokenPath: path identifier for the token to transfer
//   - from: source address (typically the staker contract)
//   - to: destination address
//   - amount: amount of tokens to transfer
//
// Returns:
//   - error: nil on success, error if transfer fails
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
	isGnoNativeCoin := tokenPath == consts.WUGNOT_PATH
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
