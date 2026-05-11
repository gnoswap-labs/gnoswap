package v1

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
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
func (pfs *protocolFeeState) AccuToGovStaker() *bptree.BPTree {
	return pfs.store.GetAccuToGovStaker()
}

// AccuToDevOps returns the accumulated amounts distributed to DevOps.
func (pfs *protocolFeeState) AccuToDevOps() *bptree.BPTree {
	return pfs.store.GetAccuToDevOps()
}

// ActualDistributedToGovStaker returns the cumulative amounts actually distributed to Gov/Staker.
func (pfs *protocolFeeState) ActualDistributedToGovStaker() *bptree.BPTree {
	return pfs.store.GetDistributedToGovStakerHistory()
}

// ActualDistributedToDevOps returns the cumulative amounts actually distributed to DevOps.
func (pfs *protocolFeeState) ActualDistributedToDevOps() *bptree.BPTree {
	return pfs.store.GetDistributedToDevOpsHistory()
}

// ReservedTokens returns token paths reserved for distribution.
func (pfs *protocolFeeState) ReservedTokens() []string {
	return pfs.store.GetReservedTokens()
}

// distributeToDevOps distributes tokens to DevOps and updates related state.
// Amount should be greater than 0 (already checked in DistributeProtocolFee).
func (pfs *protocolFeeState) distributeToDevOps(token string, amount int64) error {
	devOpsAddr := access.MustGetAddress(prabc.ROLE_DEVOPS.String())

	if err := pfs.addActualDistributedToDevOps(token, amount); err != nil {
		return err
	}
	common.SafeGRC20Transfer(cross, token, devOpsAddr, amount)

	return nil
}

// distributeToGovStaker distributes tokens to Gov/Staker and updates related state.
// Amount should be greater than 0 (already checked in DistributeProtocolFee).
func (pfs *protocolFeeState) distributeToGovStaker(token string, amount int64) error {
	govStakerAddr := access.MustGetAddress(prabc.ROLE_GOV_STAKER.String())

	if err := pfs.addActualDistributedToGovStaker(token, amount); err != nil {
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

// addActualDistributedToGovStaker adds the amount to the actual distributed amount to gov/staker by token path.
func (pfs *protocolFeeState) addActualDistributedToGovStaker(tokenPath string, amount int64) error {
	before := pfs.GetActualDistributedToGovStakerByTokenPath(tokenPath)
	after := safeAddInt64(before, amount)
	if err := pfs.store.SetDistributedToGovStakerHistoryItem(tokenPath, after); err != nil {
		return err
	}
	return nil
}

// addActualDistributedToDevOps adds the amount to the actual distributed amount to devOps by token path.
func (pfs *protocolFeeState) addActualDistributedToDevOps(tokenPath string, amount int64) error {
	before := pfs.GetActualDistributedToDevOpsByTokenPath(tokenPath)
	after := safeAddInt64(before, amount)
	if err := pfs.store.SetDistributedToDevOpsHistoryItem(tokenPath, after); err != nil {
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

// GetActualDistributedToGovStakerByTokenPath gets the actual distributed amount to gov/staker by token path.
func (pfs *protocolFeeState) GetActualDistributedToGovStakerByTokenPath(tokenPath string) int64 {
	return retrieveAmount(pfs.store.GetDistributedToGovStakerHistory(), tokenPath)
}

// GetActualDistributedToDevOpsByTokenPath gets the actual distributed amount to devOps by token path.
func (pfs *protocolFeeState) GetActualDistributedToDevOpsByTokenPath(tokenPath string) int64 {
	return retrieveAmount(pfs.store.GetDistributedToDevOpsHistory(), tokenPath)
}

// clearReservedTokens clears the reserved token index after distribution.
func (pfs *protocolFeeState) clearReservedTokens() error {
	if err := pfs.store.SetReservedTokens([]string{}); err != nil {
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

func retrieveAmount(tree *bptree.BPTree, key string) int64 {
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
