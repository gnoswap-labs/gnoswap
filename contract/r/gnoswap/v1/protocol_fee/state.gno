package protocol_fee

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/v1/common"
)

// ProtocolFeeState holds all the state variables for protocol fee management
type ProtocolFeeState struct {
	// By default, devOps will get 0% of the protocol fee (which means gov/staker will get 100% of the protocol fee)
	// This percentage can be modified through governance.
	devOpsPct int64 // 0%

	// accumulated amount distributed to gov/staker by token path
	accuToGovStaker *avl.Tree
	accuToDevOps    *avl.Tree

	// distributedToDevOpsHistory and distributedToGovStakerHistory are used to keep track of the distribution history
	distributedToGovStakerHistory *avl.Tree
	distributedToDevOpsHistory    *avl.Tree

	tokenListWithAmount map[string]int64 // tokenPath -> amount
}

// distributedToGovStakerHistory returns the history of distributed to gov/staker.
func distributedToGovStakerHistory() *avl.Tree {
	return protocolFeeState.distributedToGovStakerHistory
}

// distributedToDevOpsHistory returns the history of distributed to devOps.
func distributedToDevOpsHistory() *avl.Tree {
	return protocolFeeState.distributedToDevOpsHistory
}

// NewProtocolFeeState creates a new instance of ProtocolFeeState with initialized values
func NewProtocolFeeState() *ProtocolFeeState {
	return &ProtocolFeeState{
		devOpsPct:                     0, // 0%
		accuToGovStaker:               avl.NewTree(),
		accuToDevOps:                  avl.NewTree(),
		distributedToGovStakerHistory: avl.NewTree(),
		distributedToDevOpsHistory:    avl.NewTree(),
		tokenListWithAmount:           make(map[string]int64),
	}
}

// Global instance of the protocol fee state
var protocolFeeState = NewProtocolFeeState()

// DevOpsPct returns the percentage of protocol fees allocated to DevOps.
func (pfs *ProtocolFeeState) DevOpsPct() int64 { return pfs.devOpsPct }

// GovStakerPct returns the percentage of protocol fees allocated to Gov/Staker.
func (pfs *ProtocolFeeState) GovStakerPct() int64 { return 10000 - pfs.devOpsPct }

// AccuToGovStaker returns the accumulated amounts distributed to Gov/Staker.
func (pfs *ProtocolFeeState) AccuToGovStaker() *avl.Tree { return pfs.accuToGovStaker }

// AccuToDevOps returns the accumulated amounts distributed to DevOps.
func (pfs *ProtocolFeeState) AccuToDevOps() *avl.Tree { return pfs.accuToDevOps }

// distributeToDevOps distributes tokens to DevOps and updates related state.
// Amount should be greater than 0 (already checked in DistributeProtocolFee).
func (pfs *ProtocolFeeState) distributeToDevOps(token string, amount int64) error {
	pfs.addAccuToDevOps(token, amount)
	pfs.updateDistributedToDevOpsHistory(token, amount)
	if err := common.Transfer(cross, token, devOpsAddr, amount); err != nil {
		return ufmt.Errorf("transfer failed: token(%s), amount(%d)", token, amount)
	}
	return nil
}

// distributeToGovStaker distributes tokens to Gov/Staker and updates related state.
// Amount should be greater than 0 (already checked in DistributeProtocolFee).
func (pfs *ProtocolFeeState) distributeToGovStaker(token string, amount int64) error {
	pfs.addAccuToGovStaker(token, amount)
	pfs.updateDistributedToGovStakerHistory(token, amount)
	if err := common.Transfer(cross, token, govStakerAddr, amount); err != nil {
		return ufmt.Errorf("transfer failed: token(%s), amount(%d)", token, amount)
	}
	return nil
}

// setDevOpsPct sets the devOpsPct.
func (pfs *ProtocolFeeState) setDevOpsPct(pct int64) (int64, error) {
	if pct < 0 {
		return 0, makeErrorWithDetail(
			errInvalidPct,
			ufmt.Sprintf("pct(%d) should not be negative", pct),
		)
	}
	if pct > 10000 {
		return 0, makeErrorWithDetail(
			errInvalidPct,
			ufmt.Sprintf("pct(%d) should not be bigger than 10000", pct),
		)
	}

	pfs.devOpsPct = pct

	return pct, nil
}

// setGovStakerPct sets the govStakerPct by calculating devOpsPct.
func (pfs *ProtocolFeeState) setGovStakerPct(pct int64) (int64, error) {
	if pct < 0 {
		return 0, makeErrorWithDetail(
			errInvalidPct,
			ufmt.Sprintf("pct(%d) should not be negative", pct),
		)
	}
	devOpsPct := 10000 - pct
	if _, err := pfs.setDevOpsPct(devOpsPct); err != nil {
		return 0, err
	}

	return pct, nil
}

// addAccuToGovStaker adds the amount to the accuToGovStaker by token path.
func (pfs *ProtocolFeeState) addAccuToGovStaker(tokenPath string, amount int64) {
	before := pfs.GetAccuTransferToGovStakerByTokenPath(tokenPath)

	// Check for overflow
	if amount > 0 && before > 0 && before > (9223372036854775807-amount) {
		panic(makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("overflow detected: before(%d) + amount(%d) would exceed int64 max", before, amount),
		))
	}

	after := before + amount
	pfs.accuToGovStaker.Set(tokenPath, after)
}

// addAccuToDevOps adds the amount to the accuToDevOps by token path.
func (pfs *ProtocolFeeState) addAccuToDevOps(tokenPath string, amount int64) {
	before := pfs.GetAccuTransferToDevOpsByTokenPath(tokenPath)

	// Check for overflow
	if amount > 0 && before > 0 && before > (9223372036854775807-amount) {
		panic(makeErrorWithDetail(
			errInvalidAmount,
			ufmt.Sprintf("overflow detected: before(%d) + amount(%d) would exceed int64 max", before, amount),
		))
	}

	after := before + amount
	pfs.accuToDevOps.Set(tokenPath, after)
}

// GetAccuTransferToGovStakerByTokenPath gets the accumulated amount to gov/staker by token path.
func (pfs *ProtocolFeeState) GetAccuTransferToGovStakerByTokenPath(tokenPath string) int64 {
	return retrieveAmount(pfs.accuToGovStaker, tokenPath)
}

// GetAccuTransferToDevOpsByTokenPath gets the accumulated amount to devOps by token path.
func (pfs *ProtocolFeeState) GetAccuTransferToDevOpsByTokenPath(tokenPath string) int64 {
	return retrieveAmount(pfs.accuToDevOps, tokenPath)
}

func retrieveAmount(tree *avl.Tree, key string) int64 {
	amountI, exists := tree.Get(key)
	if !exists {
		return 0
	}
	res, ok := amountI.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast amount to int64: %T", amountI))
	}
	return res
}

// updateDistributedToGovStakerHistory updates the distributedToGovStakerHistory.
func (pfs *ProtocolFeeState) updateDistributedToGovStakerHistory(tokenPath string, amount int64) {
	prevAmount := retrievePrevAmount(pfs.distributedToGovStakerHistory, tokenPath)
	afterAmount := prevAmount + amount

	pfs.distributedToGovStakerHistory.Set(tokenPath, afterAmount)
}

// updateDistributedToDevOpsHistory updates the distributedToDevOpsHistory.
func (pfs *ProtocolFeeState) updateDistributedToDevOpsHistory(tokenPath string, amount int64) {
	prevAmount := retrievePrevAmount(pfs.distributedToDevOpsHistory, tokenPath)
	afterAmount := prevAmount + amount

	pfs.distributedToDevOpsHistory.Set(tokenPath, afterAmount)
}

func retrievePrevAmount(tree *avl.Tree, key string) (amount int64) {
	if prevAmountI, exists := tree.Get(key); !exists {
		return 0
	} else {
		v, ok := prevAmountI.(int64)
		if !ok {
			panic(ufmt.Sprintf("failed to cast prevAmount to int64: %T", prevAmountI))
		}
		amount = v
	}
	return
}

// clearTokenListWithAmount clears the tokenListWithAmount.
func (pfs *ProtocolFeeState) clearTokenListWithAmount() {
	pfs.tokenListWithAmount = make(map[string]int64)
}
