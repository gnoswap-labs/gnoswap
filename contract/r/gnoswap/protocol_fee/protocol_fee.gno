package protocol_fee

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/halt"
)

// Global instance of the protocol fee state
var protocolFeeState = NewProtocolFeeState()

// ProtocolFeeState holds all the state variables for protocol fee management
type ProtocolFeeState struct {
	// by default, devOps will get 0% of the protocol fee (which means gov/staker will get 100% of the protocol fee)
	DevOpsPct uint64 // 0%

	// accumulated amount distributed to gov/staker by token path
	AccuToGovStaker *avl.Tree
	AccuToDevOps    *avl.Tree

	// distributedToDevOpsHistory and distributedToGovStakerHistory are used to keep track of the distribution history
	DistributedToGovStakerHistory *avl.Tree
	DistributedToDevOpsHistory    *avl.Tree

	TokenListWithAmount map[string]uint64 // tokenPath -> amount
}

// NewProtocolFeeState creates a new instance of ProtocolFeeState with initialized values
func NewProtocolFeeState() *ProtocolFeeState {
	return &ProtocolFeeState{
		DevOpsPct:                     0, // 0%
		AccuToGovStaker:               avl.NewTree(),
		AccuToDevOps:                  avl.NewTree(),
		DistributedToGovStakerHistory: avl.NewTree(),
		DistributedToDevOpsHistory:    avl.NewTree(),
		TokenListWithAmount:           make(map[string]uint64),
	}
}

// distributeTo distributes tokens to the desired address (should be registered in access contract)
// with the amount of the token
func (pfs *ProtocolFeeState) distributeTo(token string, addr std.Address, amount uint64) error {
	pfs.addAccuToDevOps(token, amount)
	pfs.updateDistributedToDevOpsHistory(token, amount)
	common.Transfer(cross, token, addr, int64(amount))
	return nil
}

// DistributeProtocolFee distributes the protocol fee to devOps and gov/staker.
// only `gov/staker` can execute this function.
// It returns list of token with amount has been sent to gov/staker.
func DistributeProtocolFee(cur realm) map[string]uint64 {
	currentLevel := halt.GetCurrentHaltLevel()
	if currentLevel != halt.LvMainnetSafeMode {
		// Check if withdrawals are specifically halted, not just if the system is halted
		if err := halt.IsHalted(halt.OpTypeWithdraw); err != nil {
			panic(err)
		}

		if halt.IsContractHalted(halt.OpTypeProtocolFee) {
			panic("protocol fee contract operations are currently disabled")
		}
	}

	assertOnlyGovStaker()
	sentToDevOpsForEvent := make([]string, 0)
	sentToGovStakerForEvent := make([]string, 0)
	toReturnDistributedToGovStaker := make(map[string]uint64)

	for token, amount := range protocolFeeState.TokenListWithAmount {
		balance := uint64(common.BalanceOf(token, protocolFeeAddr))

		// anyone can just send certain grc20 token to `protocol_fee` contract
		// therefore, we don't need any guard logic to check whether protocol_fee's xxx token balance is equal to `amount`
		// however, amount always should be less than or equal to balance
		if amount > balance {
			panic(addDetailToError(
				errInvalidAmount,
				ufmt.Sprintf("amount: %d should be less than or equal to balance: %d", amount, balance),
			))
		}

		if amount <= 0 {
			continue
		}

		// Distribute only the recorded amount, not the entire balance
		distributeAmount := amount
		if distributeAmount > balance {
			// This should not happen due to the check above, but safeguard anyway
			distributeAmount = balance
		}

		toDevOpsAmount := distributeAmount * protocolFeeState.DevOpsPct / 10000 // default 0%
		toGovStakerAmount := distributeAmount - toDevOpsAmount                  // default 100%

		if err := protocolFeeState.distributeTo(token, devOpsAddr, toDevOpsAmount); err != nil {
			panic(err)
		}
		if toDevOpsAmount > 0 {
			sentToDevOpsForEvent = append(sentToDevOpsForEvent, makeEventString(token, toDevOpsAmount))
		}

		if err := protocolFeeState.distributeTo(token, govStakerAddr, toGovStakerAmount); err != nil {
			panic(err)
		}

		if toGovStakerAmount > 0 {
			sentToGovStakerForEvent = append(sentToGovStakerForEvent, makeEventString(token, toGovStakerAmount))
			toReturnDistributedToGovStaker[token] = toGovStakerAmount
		}
	}

	protocolFeeState.clearTokenListWithAmount()

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"TransferProtocolFee",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"toDevOps", strings.Join(sentToDevOpsForEvent, ","),
		"toGovStaker", strings.Join(sentToGovStakerForEvent, ","),
	)

	return toReturnDistributedToGovStaker
}

func GetDevOpsPct() uint64 {
	return protocolFeeState.DevOpsPct
}

// SetDevOpsPctByAdmin sets the devOpsPct.
func SetDevOpsPctByAdmin(cur realm, pct uint64) {
	caller := std.PreviousRealm().Address()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	protocolFeeState.setDevOpsPct(pct)
}

// SetDevOpsPct sets the devOpsPct.
// Only governance contract can execute this function via proposal
func SetDevOpsPct(cur realm, pct uint64) {
	caller := std.PreviousRealm().Address()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
	}

	protocolFeeState.setDevOpsPct(pct)
}

// setDevOpsPct sets the devOpsPct.
func (pfs *ProtocolFeeState) setDevOpsPct(pct uint64) {
	if pct > 10000 {
		panic(addDetailToError(
			errInvalidPct,
			ufmt.Sprintf("pct(%d) should not be bigger than 10000", pct),
		))
	}

	prevDevOpsPct := pfs.DevOpsPct
	pfs.DevOpsPct = pct

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"SetDevOpsPct",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"newPct", strconv.FormatUint(pct, 10),
		"prevPct", strconv.FormatUint(prevDevOpsPct, 10),
	)
}

// AddToProtocolFee adds the amount to the tokenListWithAmount
// Only `pool + router + staker` can execute this function.
func AddToProtocolFee(cur realm, tokenPath string, amount uint64) {
	assertOnlyPoolRouterStaker()
	protocolFeeState.TokenListWithAmount[tokenPath] += amount
}

// ClearTokenListWithAmount clears the tokenListWithAmount.
// only `gov/staker` can execute this function.
func ClearTokenListWithAmount(cur realm) {
	assertOnlyGovStaker()
	protocolFeeState.clearTokenListWithAmount()
}

// ClearAccuTransferToGovStaker clears the accuToGovStaker.
// Only gov/staker can execute this function.
// protocol_fee just sends the accumulated amount to gov/staker
// which means gov/staker doesn't known how much protocol_fee has been distributed from last time
// Therefore, gov/staker calls GetAccuTransferToGovStaker to get the accumulated amount and clear it
func ClearAccuTransferToGovStaker(cur realm) {
	assertOnlyNotHalted()
	caller := std.PreviousRealm().Address()
	if err := common.GovStakerOnly(caller); err != nil {
		panic(err)
	}

	protocolFeeState.AccuToGovStaker = avl.NewTree()
}

// addAccuToGovStaker adds the amount to the accuToGovStaker by token path.
func (pfs *ProtocolFeeState) addAccuToGovStaker(tokenPath string, amount uint64) {
	before := pfs.GetAccuTransferToGovStakerByTokenPath(tokenPath)
	after := before + amount
	pfs.AccuToGovStaker.Set(tokenPath, after)
}

// addAccuToDevOps adds the amount to the accuToDevOps by token path.
func (pfs *ProtocolFeeState) addAccuToDevOps(tokenPath string, amount uint64) {
	before := pfs.GetAccuTransferToDevOpsByTokenPath(tokenPath)
	after := before + amount
	pfs.AccuToDevOps.Set(tokenPath, after)
}

// GetAccuTransferToGovStakerByTokenPath gets the accumulated amount to gov/staker by token path.
func (pfs *ProtocolFeeState) GetAccuTransferToGovStakerByTokenPath(tokenPath string) uint64 {
	amountI, exists := pfs.AccuToGovStaker.Get(tokenPath)
	if !exists {
		return 0
	}
	return amountI.(uint64)
}

// GetAccuTransferToDevOpsByTokenPath gets the accumulated amount to devOps by token path.
func (pfs *ProtocolFeeState) GetAccuTransferToDevOpsByTokenPath(tokenPath string) uint64 {
	amountI, exists := pfs.AccuToDevOps.Get(tokenPath)
	if !exists {
		return 0
	}
	return amountI.(uint64)
}

// updateDistributedToGovStakerHistory updates the distributedToGovStakerHistory.
func (pfs *ProtocolFeeState) updateDistributedToGovStakerHistory(tokenPath string, amount uint64) {
	// get the previous amount
	prevAmountI, exists := pfs.DistributedToGovStakerHistory.Get(tokenPath)
	prevAmount := uint64(0)
	if exists {
		prevAmount = prevAmountI.(uint64)
	}

	// update the amount
	afterAmount := prevAmount + amount
	pfs.DistributedToGovStakerHistory.Set(tokenPath, afterAmount)
}

// updateDistributedToDevOpsHistory updates the distributedToDevOpsHistory.
func (pfs *ProtocolFeeState) updateDistributedToDevOpsHistory(tokenPath string, amount uint64) {
	// get the previous amount
	prevAmountI, exists := pfs.DistributedToDevOpsHistory.Get(tokenPath)
	prevAmount := uint64(0)
	if exists {
		prevAmount = prevAmountI.(uint64)
	}

	// update the amount
	afterAmount := prevAmount + amount
	pfs.DistributedToDevOpsHistory.Set(tokenPath, afterAmount)
}

// clearTokenListWithAmount clears the tokenListWithAmount.
func (pfs *ProtocolFeeState) clearTokenListWithAmount() {
	pfs.TokenListWithAmount = make(map[string]uint64)
}

func makeEventString(tokenPath string, amount uint64) string {
	return ufmt.Sprintf("%s*FEE*%d", tokenPath, amount)
}
