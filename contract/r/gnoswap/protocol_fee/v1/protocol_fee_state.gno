package v1

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/protocol_fee"
)

// protocolFeeState holds all the state variables for protocol fee management
type protocolFeeState struct {
	store protocol_fee.IProtocolFeeStore
}

// DevOpsPct returns the percentage of protocol fees allocated to DevOps.
func (pfs *protocolFeeState) DevOpsPct() int64 {
	return pfs.store.GetDevOpsPct()
}

// GovStakerPct returns the percentage of protocol fees allocated to Gov/Staker.
func (pfs *protocolFeeState) GovStakerPct() int64 {
	return 10000 - pfs.store.GetDevOpsPct()
}

// AccuToGovStaker returns the accumulated amounts distributed to Gov/Staker.
func (pfs *protocolFeeState) AccuToGovStaker() *avl.Tree {
	return pfs.store.GetAccuToGovStaker()
}

// AccuToDevOps returns the accumulated amounts distributed to DevOps.
func (pfs *protocolFeeState) AccuToDevOps() *avl.Tree {
	return pfs.store.GetAccuToDevOps()
}

func (pfs *protocolFeeState) TokenListWithAmounts() map[string]int64 {
	return pfs.store.GetTokenListWithAmounts()
}

func (pfs *protocolFeeState) TokenAmountOfTokenPath(tokenPath string) int64 {
	amount, exists := pfs.store.GetTokenListWithAmountItem(tokenPath)
	if !exists {
		return 0
	}

	return amount
}

// distributeToDevOps distributes tokens to DevOps and updates related state.
// Amount should be greater than 0 (already checked in DistributeProtocolFee).
func (pfs *protocolFeeState) distributeToDevOps(token string, amount int64) error {
	if err := pfs.addAccuToDevOps(token, amount); err != nil {
		return err
	}

	if err := pfs.updateDistributedToDevOpsHistory(token, amount); err != nil {
		return err
	}

	common.SafeGRC20Transfer(cross, token, devOpsAddr, amount)

	return nil
}

// distributeToGovStaker distributes tokens to Gov/Staker and updates related state.
// Amount should be greater than 0 (already checked in DistributeProtocolFee).
func (pfs *protocolFeeState) distributeToGovStaker(token string, amount int64) error {
	if err := pfs.addAccuToGovStaker(token, amount); err != nil {
		return err
	}

	if err := pfs.updateDistributedToGovStakerHistory(token, amount); err != nil {
		return err
	}

	common.SafeGRC20Transfer(cross, token, govStakerAddr, amount)

	return nil
}

// setDevOpsPct sets the devOpsPct.
func (pfs *protocolFeeState) setDevOpsPct(pct int64) (int64, error) {
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

	if err := pfs.store.SetDevOpsPct(pct); err != nil {
		return 0, err
	}

	return pct, nil
}

// setGovStakerPct sets the govStakerPct by calculating devOpsPct.
func (pfs *protocolFeeState) setGovStakerPct(pct int64) (int64, error) {
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
func (pfs *protocolFeeState) addAccuToGovStaker(tokenPath string, amount int64) error {
	before := pfs.GetAccuTransferToGovStakerByTokenPath(tokenPath)

	// Check for overflow
	after := safeAddInt64(before, amount)
	if err := pfs.store.SetAccuToGovStakerItem(tokenPath, after); err != nil {
		return err
	}
	return nil
}

// addAccuToDevOps adds the amount to the accuToDevOps by token path.
func (pfs *protocolFeeState) addAccuToDevOps(tokenPath string, amount int64) error {
	before := pfs.GetAccuTransferToDevOpsByTokenPath(tokenPath)

	// Check for overflow
	after := safeAddInt64(before, amount)
	if err := pfs.store.SetAccuToDevOpsItem(tokenPath, after); err != nil {
		return err
	}
	return nil
}

// GetAccuTransferToGovStakerByTokenPath gets the accumulated amount to gov/staker by token path.
func (pfs *protocolFeeState) GetAccuTransferToGovStakerByTokenPath(tokenPath string) int64 {
	return retrieveAmount(pfs.store.GetAccuToGovStaker(), tokenPath)
}

// GetAccuTransferToDevOpsByTokenPath gets the accumulated amount to devOps by token path.
func (pfs *protocolFeeState) GetAccuTransferToDevOpsByTokenPath(tokenPath string) int64 {
	return retrieveAmount(pfs.store.GetAccuToDevOps(), tokenPath)
}

// GetDistributedToGovStakerHistoryByTokenPath gets the history of distributed amounts to Gov/Staker by token path.
func (pfs *protocolFeeState) GetDistributedToGovStakerHistoryByTokenPath(tokenPath string) int64 {
	return retrieveAmount(pfs.store.GetDistributedToGovStakerHistory(), tokenPath)
}

// GetDistributedToDevOpsHistoryByTokenPath gets the history of distributed amounts to DevOps by token path.
func (pfs *protocolFeeState) GetDistributedToDevOpsHistoryByTokenPath(tokenPath string) int64 {
	return retrieveAmount(pfs.store.GetDistributedToDevOpsHistory(), tokenPath)
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
func (pfs *protocolFeeState) updateDistributedToGovStakerHistory(tokenPath string, amount int64) error {
	prevAmount := retrievePrevAmount(pfs.store.GetDistributedToGovStakerHistory(), tokenPath)
	afterAmount := safeAddInt64(prevAmount, amount)

	if err := pfs.store.SetDistributedToGovStakerHistoryItem(tokenPath, afterAmount); err != nil {
		return err
	}
	return nil
}

// updateDistributedToDevOpsHistory updates the distributedToDevOpsHistory.
func (pfs *protocolFeeState) updateDistributedToDevOpsHistory(tokenPath string, amount int64) error {
	prevAmount := retrievePrevAmount(pfs.store.GetDistributedToDevOpsHistory(), tokenPath)
	afterAmount := safeAddInt64(prevAmount, amount)

	if err := pfs.store.SetDistributedToDevOpsHistoryItem(tokenPath, afterAmount); err != nil {
		return err
	}
	return nil
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
func (pfs *protocolFeeState) clearTokenListWithAmount() error {
	if err := pfs.store.SetTokenListWithAmounts(make(map[string]int64)); err != nil {
		return err
	}
	return nil
}

// NewProtocolFeeState creates a new instance of protocolFeeState with initialized values
func NewProtocolFeeStateBy(protocolFeeStore protocol_fee.IProtocolFeeStore) *protocolFeeState {
	return &protocolFeeState{
		store: protocolFeeStore,
	}
}
