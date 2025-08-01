package protocol_fee

import (
	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
)

// ProtocolFeeState holds all the state variables for protocol fee management
type ProtocolFeeState struct {
	// by default, devOps will get 0% of the protocol fee (which means gov/staker will get 100% of the protocol fee)
	devOpsPct uint64 // 0%

	// accumulated amount distributed to gov/staker by token path
	accuToGovStaker *avl.Tree
	accuToDevOps    *avl.Tree

	// distributedToDevOpsHistory and distributedToGovStakerHistory are used to keep track of the distribution history
	distributedToGovStakerHistory *avl.Tree
	distributedToDevOpsHistory    *avl.Tree

	tokenListWithAmount map[string]uint64 // tokenPath -> amount
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
		tokenListWithAmount:           make(map[string]uint64),
	}
}

// Global instance of the protocol fee state
var protocolFeeState = NewProtocolFeeState()

func (pfs *ProtocolFeeState) GetDevOpsPct() uint64 {
	return pfs.devOpsPct
}

func (pfs *ProtocolFeeState) GetGovStakerPct() uint64 {
	return 10000 - pfs.devOpsPct
}

func (pfs *ProtocolFeeState) GetAccuToGovStaker() *avl.Tree {
	return pfs.accuToGovStaker
}

func (pfs *ProtocolFeeState) GetAccuToDevOps() *avl.Tree {
	return pfs.accuToDevOps
}

// distributeToDevOps distributes tokens to DevOps and updates related state
// amount should be greater than 0 (already checked in DistributeProtocolFee)
func (pfs *ProtocolFeeState) distributeToDevOps(token string, amount uint64) error {
	pfs.addAccuToDevOps(token, amount)
	pfs.updateDistributedToDevOpsHistory(token, amount)
	if err := common.Transfer(cross, token, devOpsAddr, int64(amount)); err != nil {
		return ufmt.Errorf("transfer failed: token(%s), amount(%d)", token, amount)
	}

	return nil
}

// distributeToGovStaker distributes tokens to Gov/Staker and updates related state
// amount should be greater than 0 (already checked in DistributeProtocolFee)
func (pfs *ProtocolFeeState) distributeToGovStaker(token string, amount uint64) error {
	pfs.addAccuToGovStaker(token, amount)
	pfs.updateDistributedToGovStakerHistory(token, amount)
	if err := common.Transfer(cross, token, govStakerAddr, int64(amount)); err != nil {
		return ufmt.Errorf("transfer failed: token(%s), amount(%d)", token, amount)
	}

	return nil
}

// setDevOpsPct sets the devOpsPct.
func (pfs *ProtocolFeeState) setDevOpsPct(pct uint64) (uint64, error) {
	if pct > 10000 {
		return 0, makeErrorWithDetail(
			errInvalidPct,
			ufmt.Sprintf("pct(%d) should not be bigger than 10000", pct),
		)
	}

	pfs.devOpsPct = pct

	return pct, nil
}

// setGovStakerPct sets the devOpsPct.
func (pfs *ProtocolFeeState) setGovStakerPct(pct uint64) (uint64, error) {
	devOpsPct := 10000 - pct
	if _, err := pfs.setDevOpsPct(devOpsPct); err != nil {
		return 0, err
	}

	return pct, nil
}

// addAccuToGovStaker adds the amount to the accuToGovStaker by token path.
func (pfs *ProtocolFeeState) addAccuToGovStaker(tokenPath string, amount uint64) {
	before := pfs.GetAccuTransferToGovStakerByTokenPath(tokenPath)
	after := before + amount
	pfs.accuToGovStaker.Set(tokenPath, after)
}

// addAccuToDevOps adds the amount to the accuToDevOps by token path.
func (pfs *ProtocolFeeState) addAccuToDevOps(tokenPath string, amount uint64) {
	before := pfs.GetAccuTransferToDevOpsByTokenPath(tokenPath)
	after := before + amount
	pfs.accuToDevOps.Set(tokenPath, after)
}

// GetAccuTransferToGovStakerByTokenPath gets the accumulated amount to gov/staker by token path.
func (pfs *ProtocolFeeState) GetAccuTransferToGovStakerByTokenPath(tokenPath string) uint64 {
	amountI, exists := pfs.accuToGovStaker.Get(tokenPath)
	if !exists {
		return 0
	}
	return amountI.(uint64)
}

// GetAccuTransferToDevOpsByTokenPath gets the accumulated amount to devOps by token path.
func (pfs *ProtocolFeeState) GetAccuTransferToDevOpsByTokenPath(tokenPath string) uint64 {
	amountI, exists := pfs.accuToDevOps.Get(tokenPath)
	if !exists {
		return 0
	}
	return amountI.(uint64)
}

// updateDistributedToGovStakerHistory updates the distributedToGovStakerHistory.
func (pfs *ProtocolFeeState) updateDistributedToGovStakerHistory(tokenPath string, amount uint64) {
	// get the previous amount
	prevAmountI, exists := pfs.distributedToGovStakerHistory.Get(tokenPath)
	prevAmount := uint64(0)
	if exists {
		prevAmount = prevAmountI.(uint64)
	}

	// update the amount
	afterAmount := prevAmount + amount
	pfs.distributedToGovStakerHistory.Set(tokenPath, afterAmount)
}

// updateDistributedToDevOpsHistory updates the distributedToDevOpsHistory.
func (pfs *ProtocolFeeState) updateDistributedToDevOpsHistory(tokenPath string, amount uint64) {
	// get the previous amount
	prevAmountI, exists := pfs.distributedToDevOpsHistory.Get(tokenPath)
	prevAmount := uint64(0)
	if exists {
		prevAmount = prevAmountI.(uint64)
	}

	// update the amount
	afterAmount := prevAmount + amount
	pfs.distributedToDevOpsHistory.Set(tokenPath, afterAmount)
}

// clearTokenListWithAmount clears the tokenListWithAmount.
func (pfs *ProtocolFeeState) clearTokenListWithAmount() {
	pfs.tokenListWithAmount = make(map[string]uint64)
}
