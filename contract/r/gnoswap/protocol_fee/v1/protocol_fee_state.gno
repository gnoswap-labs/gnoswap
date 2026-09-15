package protocol_fee

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	gnsmath "gno.land/p/gnoswap/gnsmath"
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
//
// Returns:
//   - pct: Stored DevOps protocol-fee allocation percentage in basis points.
func (pfs *protocolFeeState) DevOpsPct() int64 {
	return pfs.store.GetDevOpsPct()
}

// GovStakerPct returns the percentage of protocol fees allocated to Gov/Staker.
//
// Returns:
//   - pct: Gov/Staker protocol-fee allocation percentage in basis points, computed as 10000 minus the stored DevOps percentage.
func (pfs *protocolFeeState) GovStakerPct() int64 {
	return 10000 - pfs.store.GetDevOpsPct()
}

// AccuToGovStaker returns the cumulative amount allocated to GovStaker.
// It includes allocations that may still be pending distribution; completed
// transfers are tracked separately in the distribution history.
//
// Returns:
//   - tree: BP-tree mapping token paths to cumulative amounts allocated to Gov/Staker, including allocations pending distribution.
func (pfs *protocolFeeState) AccuToGovStaker() *bptree.BPTree {
	return pfs.store.GetAccuToGovStaker()
}

// AccuToDevOps returns the cumulative amount allocated to DevOps.
// It includes allocations that may still be pending distribution; completed
// transfers are tracked separately in the distribution history.
//
// Returns:
//   - tree: BP-tree mapping token paths to cumulative amounts allocated to DevOps, including allocations pending distribution.
func (pfs *protocolFeeState) AccuToDevOps() *bptree.BPTree {
	return pfs.store.GetAccuToDevOps()
}

// ActualDistributedToGovStaker returns the cumulative amounts actually distributed to Gov/Staker.
//
// Returns:
//   - tree: BP-tree mapping token paths to cumulative amounts actually distributed to Gov/Staker.
func (pfs *protocolFeeState) ActualDistributedToGovStaker() *bptree.BPTree {
	return pfs.store.GetDistributedToGovStakerHistory()
}

// ActualDistributedToDevOps returns the cumulative amounts actually distributed to DevOps.
//
// Returns:
//   - tree: BP-tree mapping token paths to cumulative amounts actually distributed to DevOps.
func (pfs *protocolFeeState) ActualDistributedToDevOps() *bptree.BPTree {
	return pfs.store.GetDistributedToDevOpsHistory()
}

// ReservedTokens returns token paths reserved for distribution.
//
// Returns:
//   - tokenPaths: Token paths currently reserved for protocol-fee distribution.
func (pfs *protocolFeeState) ReservedTokens() []string {
	return pfs.store.GetReservedTokens()
}

// distributeToDevOps distributes tokens to DevOps and updates related state.
// Amount should be greater than 0 (already checked in DistributeProtocolFee).
//
// Parameters:
//   - _: Crossing discriminator for the state operation; pass 0.
//   - rlm: Propagated realm context used for the state update and token transfer; downstream calls validate or consume this current context.
//   - token: Token path of the protocol-fee asset to transfer to DevOps.
//   - amount: Positive token amount to distribute; callers validate it before invoking this helper.
//
// Returns:
//   - err: Nil after the distribution history is updated and the transfer is initiated; otherwise the history-update error.
func (pfs *protocolFeeState) distributeToDevOps(_ int, rlm realm, token string, amount int64) error {
	devOpsAddr := access.MustGetAddress(prabc.ROLE_DEVOPS.String())

	if err := pfs.addActualDistributedToDevOps(0, rlm, token, amount); err != nil {
		return err
	}
	common.SafeGRC20Transfer(0, rlm, token, devOpsAddr, amount)

	return nil
}

// distributeToGovStaker distributes tokens to Gov/Staker and updates related state.
// Amount should be greater than 0 (already checked in DistributeProtocolFee).
//
// Parameters:
//   - _: Crossing discriminator for the state operation; pass 0.
//   - rlm: Propagated realm context used for the state update and token transfer; downstream calls validate or consume this current context.
//   - token: Token path of the protocol-fee asset to transfer to Gov/Staker.
//   - amount: Positive token amount to distribute; callers validate it before invoking this helper.
//
// Returns:
//   - err: Nil after the distribution history is updated and the transfer is initiated; otherwise the history-update error.
func (pfs *protocolFeeState) distributeToGovStaker(_ int, rlm realm, token string, amount int64) error {
	govStakerAddr := access.MustGetAddress(prabc.ROLE_GOV_STAKER.String())

	if err := pfs.addActualDistributedToGovStaker(0, rlm, token, amount); err != nil {
		return err
	}
	common.SafeGRC20Transfer(0, rlm, token, govStakerAddr, amount)

	return nil
}

// setDevOpsPct sets the devOpsPct.
//
// Parameters:
//   - _: Crossing discriminator for the state operation; pass 0.
//   - rlm: Propagated realm context used for the store write; it must be current when the store persists the percentage.
//   - pct: DevOps protocol-fee allocation percentage in basis points, valid from 0 through 10000 inclusive.
//
// Returns:
//   - pct: The accepted DevOps percentage on success, or zero when validation or persistence fails.
//   - err: Nil when pct is persisted; otherwise an invalid-percentage or store error.
func (pfs *protocolFeeState) setDevOpsPct(_ int, rlm realm, pct int64) (int64, error) {
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

	if err := pfs.store.SetDevOpsPct(0, rlm, pct); err != nil {
		return 0, err
	}

	return pct, nil
}

// setGovStakerPct sets the govStakerPct by calculating devOpsPct.
//
// Parameters:
//   - _: Crossing discriminator for the state operation; pass 0.
//   - rlm: Propagated realm context used to persist the derived DevOps percentage; it must be current for the store write.
//   - pct: Gov/Staker protocol-fee allocation percentage in basis points, valid from 0 through 10000 inclusive.
//
// Returns:
//   - pct: The requested Gov/Staker percentage on success, or zero when validation or persistence fails.
//   - err: Nil when the complementary DevOps percentage is persisted; otherwise an invalid-percentage or store error.
func (pfs *protocolFeeState) setGovStakerPct(_ int, rlm realm, pct int64) (int64, error) {
	if pct < 0 {
		return 0, makeErrorWithDetail(
			errInvalidPct,
			ufmt.Sprintf("pct(%d) should not be negative", pct),
		)
	}

	devOpsPct := 10000 - pct

	if _, err := pfs.setDevOpsPct(0, rlm, devOpsPct); err != nil {
		return 0, err
	}

	return pct, nil
}

// addAccuToGovStaker adds the amount to the accuToGovStaker by token path.
//
// Parameters:
//   - _: Crossing discriminator for the state operation; pass 0.
//   - rlm: Propagated realm context for the store write; it must be current when the cumulative allocation is persisted.
//   - tokenPath: Token path whose Gov/Staker allocation accumulator is updated.
//   - amount: Signed allocation delta added to the existing value; SafeAddInt64 guards the addition against overflow.
//
// Returns:
//   - err: Nil when the updated accumulator is persisted; otherwise the store error.
func (pfs *protocolFeeState) addAccuToGovStaker(_ int, rlm realm, tokenPath string, amount int64) error {
	before := pfs.GetAccuTransferToGovStakerByTokenPath(tokenPath)

	// Check for overflow
	after := gnsmath.SafeAddInt64(before, amount)
	if err := pfs.store.SetAccuToGovStakerItem(0, rlm, tokenPath, after); err != nil {
		return err
	}
	return nil
}

// addAccuToDevOps adds the amount to the accuToDevOps by token path.
//
// Parameters:
//   - _: Crossing discriminator for the state operation; pass 0.
//   - rlm: Propagated realm context for the store write; it must be current when the cumulative allocation is persisted.
//   - tokenPath: Token path whose DevOps allocation accumulator is updated.
//   - amount: Signed allocation delta added to the existing value; SafeAddInt64 guards the addition against overflow.
//
// Returns:
//   - err: Nil when the updated accumulator is persisted; otherwise the store error.
func (pfs *protocolFeeState) addAccuToDevOps(_ int, rlm realm, tokenPath string, amount int64) error {
	before := pfs.GetAccuTransferToDevOpsByTokenPath(tokenPath)

	// Check for overflow
	after := gnsmath.SafeAddInt64(before, amount)
	if err := pfs.store.SetAccuToDevOpsItem(0, rlm, tokenPath, after); err != nil {
		return err
	}
	return nil
}

// addActualDistributedToGovStaker adds the amount to the actual distributed amount to gov/staker by token path.
//
// Parameters:
//   - _: Crossing discriminator for the state operation; pass 0.
//   - rlm: Propagated realm context for the store write; it must be current when the distribution history is persisted.
//   - tokenPath: Token path whose cumulative Gov/Staker distribution history is updated.
//   - amount: Signed distribution delta added to the existing history; SafeAddInt64 guards the addition against overflow.
//
// Returns:
//   - err: Nil when the updated distribution history is persisted; otherwise the store error.
func (pfs *protocolFeeState) addActualDistributedToGovStaker(_ int, rlm realm, tokenPath string, amount int64) error {
	before := pfs.GetActualDistributedToGovStakerByTokenPath(tokenPath)
	after := gnsmath.SafeAddInt64(before, amount)
	if err := pfs.store.SetDistributedToGovStakerHistoryItem(0, rlm, tokenPath, after); err != nil {
		return err
	}
	return nil
}

// addActualDistributedToDevOps adds the amount to the actual distributed amount to devOps by token path.
//
// Parameters:
//   - _: Crossing discriminator for the state operation; pass 0.
//   - rlm: Propagated realm context for the store write; it must be current when the distribution history is persisted.
//   - tokenPath: Token path whose cumulative DevOps distribution history is updated.
//   - amount: Signed distribution delta added to the existing history; SafeAddInt64 guards the addition against overflow.
//
// Returns:
//   - err: Nil when the updated distribution history is persisted; otherwise the store error.
func (pfs *protocolFeeState) addActualDistributedToDevOps(_ int, rlm realm, tokenPath string, amount int64) error {
	before := pfs.GetActualDistributedToDevOpsByTokenPath(tokenPath)
	after := gnsmath.SafeAddInt64(before, amount)
	if err := pfs.store.SetDistributedToDevOpsHistoryItem(0, rlm, tokenPath, after); err != nil {
		return err
	}
	return nil
}

// GetAccuTransferToGovStakerByTokenPath gets the accumulated amount to gov/staker by token path.
//
// Parameters:
//   - tokenPath: Token path whose cumulative Gov/Staker allocation should be read.
//
// Returns:
//   - amount: Cumulative Gov/Staker allocation for tokenPath, or zero when no entry is recorded.
func (pfs *protocolFeeState) GetAccuTransferToGovStakerByTokenPath(tokenPath string) int64 {
	return retrieveAmount(pfs.store.GetAccuToGovStaker(), tokenPath)
}

// GetAccuTransferToDevOpsByTokenPath gets the accumulated amount to devOps by token path.
//
// Parameters:
//   - tokenPath: Token path whose cumulative DevOps allocation should be read.
//
// Returns:
//   - amount: Cumulative DevOps allocation for tokenPath, or zero when no entry is recorded.
func (pfs *protocolFeeState) GetAccuTransferToDevOpsByTokenPath(tokenPath string) int64 {
	return retrieveAmount(pfs.store.GetAccuToDevOps(), tokenPath)
}

// GetActualDistributedToGovStakerByTokenPath gets the actual distributed amount to gov/staker by token path.
//
// Parameters:
//   - tokenPath: Token path whose cumulative actual Gov/Staker distribution should be read.
//
// Returns:
//   - amount: Cumulative amount actually distributed to Gov/Staker for tokenPath, or zero when no history is recorded.
func (pfs *protocolFeeState) GetActualDistributedToGovStakerByTokenPath(tokenPath string) int64 {
	return retrieveAmount(pfs.store.GetDistributedToGovStakerHistory(), tokenPath)
}

// GetActualDistributedToDevOpsByTokenPath gets the actual distributed amount to devOps by token path.
//
// Parameters:
//   - tokenPath: Token path whose cumulative actual DevOps distribution should be read.
//
// Returns:
//   - amount: Cumulative amount actually distributed to DevOps for tokenPath, or zero when no history is recorded.
func (pfs *protocolFeeState) GetActualDistributedToDevOpsByTokenPath(tokenPath string) int64 {
	return retrieveAmount(pfs.store.GetDistributedToDevOpsHistory(), tokenPath)
}

// removeReservedToken removes one distributed token from the reserved token index.
//
// Parameters:
//   - _: Crossing discriminator for the state operation; pass 0.
//   - rlm: Propagated realm context forwarded to the reserved-token store; it must be current for the removal.
//   - tokenPath: Token path to remove from the reserved-token index.
//
// Returns:
//   - err: Nil when tokenPath is absent or removed; otherwise the store error.
func (pfs *protocolFeeState) removeReservedToken(_ int, rlm realm, tokenPath string) error {
	return pfs.store.RemoveReservedToken(0, rlm, tokenPath)
}

// NewProtocolFeeState creates a new instance of protocolFeeState with initialized values
//
// Parameters:
//   - protocolFeeStore: Store implementation backing the new protocol-fee state view.
//
// Returns:
//   - state: New protocolFeeState wrapper backed by protocolFeeStore.
func NewProtocolFeeStateBy(protocolFeeStore protocol_fee.IProtocolFeeStore) *protocolFeeState {
	return &protocolFeeState{
		store: protocolFeeStore,
	}
}

func retrieveAmount(tree *bptree.BPTree, key string) int64 {
	amountI := tree.Get(key)
	if amountI == nil {
		return 0
	}
	res, ok := amountI.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast amount to int64: %T", amountI))
	}
	return res
}
