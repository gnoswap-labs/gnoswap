package protocol_fee

// DistributeProtocolFee distributes accumulated protocol fees to DevOps and
// GovStaker, subject to the implementation's caller authorization and halt checks.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
func DistributeProtocolFee(cur realm) {
	getImplementation().DistributeProtocolFee(0, cur)
}

// DistributeProtocolFeeByTokenPath distributes accumulated protocol fees reserved
// for one token path; an unreserved path has nothing to distribute.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - tokenPath: token contract path whose reserved fee balance should be distributed
func DistributeProtocolFeeByTokenPath(cur realm, tokenPath string) {
	getImplementation().DistributeProtocolFeeByTokenPath(0, cur, tokenPath)
}

// SetDevOpsPct sets the share of protocol fees allocated to DevOps.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - pct: DevOps allocation in basis-point units, from 0 through 10000 inclusive (10000 = 100%)
func SetDevOpsPct(cur realm, pct int64) {
	getImplementation().SetDevOpsPct(0, cur, pct)
}

// SetGovStakerPct sets the share of protocol fees allocated to GovStaker.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - pct: GovStaker allocation in basis-point units, from 0 through 10000 inclusive (10000 = 100%)
func SetGovStakerPct(cur realm, pct int64) {
	getImplementation().SetGovStakerPct(0, cur, pct)
}

// AddToProtocolFee pulls an approved fee amount from an authorized protocol caller
// into protocol-fee accounting. Authorized callers are pool, position, router,
// and staker realms; direct transfers to this address do not register a fee.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - tokenPath: token contract path whose fee is being collected
//   - amount: non-negative fee amount in the token's base units; zero performs no transfer
//
// Returns:
//   - err: nil on success; errSpoofedRealm for a spoofed-realm call; errProtocolFeeHalted when protocol-fee collection is halted
func AddToProtocolFee(cur realm, tokenPath string, amount int64) error {
	return getImplementation().AddToProtocolFee(0, cur, tokenPath, amount)
}

// AdvanceAccrualEpoch closes the current accrual epoch and returns the new one. Fees
// arriving from now on are bucketed under the returned epoch. Only gov/staker may call
// it, on every stake change.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//
// Returns:
//   - epoch: newly active non-negative accrual epoch used for subsequently collected GovStaker fees
func AdvanceAccrualEpoch(cur realm) int64 {
	return getImplementation().AdvanceAccrualEpoch(0, cur)
}

// ConsumeAccrualBuckets returns and clears up to limit of the oldest pending buckets
// of tokenPath as parallel epoch and amount slices. A limit of zero or less consumes
// every pending bucket. Only gov/staker may call it.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this realm.
//   - tokenPath: token contract path whose pending GovStaker accrual buckets are consumed
//   - limit: maximum number of oldest buckets to consume; zero or negative consumes all pending buckets
//
// Returns:
//   - epochs: consumed accrual epoch numbers in ascending epoch order
//   - amounts: GovStaker fee amounts corresponding positionally to epochs, in token base units
func ConsumeAccrualBuckets(cur realm, tokenPath string, limit int) ([]int64, []int64) {
	return getImplementation().ConsumeAccrualBuckets(0, cur, tokenPath, limit)
}

// GetDevOpsPct returns the DevOps fee allocation in basis-point units.
//
// Returns:
//   - pct: configured DevOps allocation from 0 through 10000 (10000 = 100%)
func GetDevOpsPct() int64 {
	return getImplementation().GetDevOpsPct()
}

// GetGovStakerPct returns the GovStaker fee allocation in basis-point units.
//
// Returns:
//   - pct: configured GovStaker allocation from 0 through 10000 (10000 = 100%)
func GetGovStakerPct() int64 {
	return getImplementation().GetGovStakerPct()
}

// GetAccrualEpoch returns the accrual epoch fees are currently bucketed under.
//
// Returns:
//   - epoch: current non-negative accrual epoch assigned to newly collected GovStaker fees
func GetAccrualEpoch() int64 {
	return getImplementation().GetAccrualEpoch()
}

// GetAccrualPendingTokens returns the token paths that still own pending accrual buckets.
//
// Returns:
//   - tokenPaths: token contract paths with at least one pending GovStaker accrual bucket
func GetAccrualPendingTokens() []string {
	return cloneStringSlice(getImplementation().GetAccrualPendingTokens())
}

// GetAccrualBuckets returns up to limit of the oldest pending buckets of tokenPath
// without clearing them. A limit of zero or less returns every pending bucket.
//
// Parameters:
//   - tokenPath: token contract path whose pending GovStaker accrual buckets are queried
//   - limit: maximum number of oldest buckets to return; zero or negative returns all pending buckets
//
// Returns:
//   - epochs: selected accrual epoch numbers in ascending epoch order
//   - amounts: GovStaker fee amounts corresponding positionally to epochs, in token base units
func GetAccrualBuckets(tokenPath string, limit int) ([]int64, []int64) {
	epochs, amounts := getImplementation().GetAccrualBuckets(tokenPath, limit)
	return cloneInt64Slice(epochs), cloneInt64Slice(amounts)
}

// GetReservedTokens returns token paths reserved for distribution.
//
// Returns:
//   - tokenPaths: token paths reserved for distribution
func GetReservedTokens() []string {
	return cloneStringSlice(getImplementation().GetReservedTokens())
}

// GetAccuTransfersToGovStaker returns accumulated transfers to GovStaker.
//
// Returns:
//   - transfers: map of token paths to accumulated amounts
func GetAccuTransfersToGovStaker() map[string]int64 {
	return cloneStringInt64Map(getImplementation().GetAccuTransfersToGovStaker())
}

// GetAccuTransfersToDevOps returns accumulated transfers to DevOps.
//
// Returns:
//   - transfers: map of token paths to accumulated amounts
func GetAccuTransfersToDevOps() map[string]int64 {
	return cloneStringInt64Map(getImplementation().GetAccuTransfersToDevOps())
}

// GetAccuTransferToGovStakerByTokenPath returns accumulated GovStaker transfer for a token.
//
// Parameters:
//   - tokenPath: path of the token
//
// Returns:
//   - amount: accumulated transfer amount
func GetAccuTransferToGovStakerByTokenPath(tokenPath string) int64 {
	return getImplementation().GetAccuTransferToGovStakerByTokenPath(tokenPath)
}

// GetAccuTransferToDevOpsByTokenPath returns accumulated DevOps transfer for a token.
//
// Parameters:
//   - tokenPath: path of the token
//
// Returns:
//   - amount: accumulated transfer amount
func GetAccuTransferToDevOpsByTokenPath(tokenPath string) int64 {
	return getImplementation().GetAccuTransferToDevOpsByTokenPath(tokenPath)
}

// GetActualDistributedToGovStaker returns actual transfers completed to GovStaker.
//
// Returns:
//   - transfers: map of token paths to actual distributed amounts
func GetActualDistributedToGovStaker() map[string]int64 {
	return cloneStringInt64Map(getImplementation().GetActualDistributedToGovStaker())
}

// GetActualDistributedToDevOps returns actual transfers completed to DevOps.
//
// Returns:
//   - transfers: map of token paths to actual distributed amounts
func GetActualDistributedToDevOps() map[string]int64 {
	return cloneStringInt64Map(getImplementation().GetActualDistributedToDevOps())
}

// GetActualDistributedToGovStakerByTokenPath returns actual GovStaker transfer for a token.
//
// Parameters:
//   - tokenPath: path of the token
//
// Returns:
//   - amount: actual distributed amount for the token
func GetActualDistributedToGovStakerByTokenPath(tokenPath string) int64 {
	return getImplementation().GetActualDistributedToGovStakerByTokenPath(tokenPath)
}

// GetActualDistributedToDevOpsByTokenPath returns actual DevOps transfer for a token.
//
// Parameters:
//   - tokenPath: path of the token
//
// Returns:
//   - amount: actual distributed amount for the token
func GetActualDistributedToDevOpsByTokenPath(tokenPath string) int64 {
	return getImplementation().GetActualDistributedToDevOpsByTokenPath(tokenPath)
}
