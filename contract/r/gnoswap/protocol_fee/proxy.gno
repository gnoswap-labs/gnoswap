package protocol_fee

// DistributeProtocolFee distributes accumulated protocol fees to DevOps and GovStaker.
//
// Parameters:
//   - cur: Pass `cross` as argument.
func DistributeProtocolFee(cur realm) {
	getImplementation().DistributeProtocolFee(0, cur)
}

// DistributeProtocolFeeByTokenPath distributes accumulated protocol fees for a single token path.
func DistributeProtocolFeeByTokenPath(cur realm, tokenPath string) {
	getImplementation().DistributeProtocolFeeByTokenPath(0, cur, tokenPath)
}

// SetDevOpsPct sets the percentage of protocol fees allocated to DevOps.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - pct: percentage in basis points (0-10000)
func SetDevOpsPct(cur realm, pct int64) {
	getImplementation().SetDevOpsPct(0, cur, pct)
}

// SetGovStakerPct sets the percentage of protocol fees allocated to GovStaker.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - pct: percentage in basis points (0-10000)
func SetGovStakerPct(cur realm, pct int64) {
	getImplementation().SetGovStakerPct(0, cur, pct)
}

// AddToProtocolFee adds tokens to the protocol fee pool.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - tokenPath: path of the token
//   - amount: amount to add
//
// Returns:
//   - err: nil on success; errProtocolFeeHalted when protocol-fee collection is halted
func AddToProtocolFee(cur realm, tokenPath string, amount int64) error {
	return getImplementation().AddToProtocolFee(0, cur, tokenPath, amount)
}

// GetDevOpsPct returns the DevOps fee percentage.
//
// Returns:
//   - pct: DevOps fee percentage in basis points (0-10000)
func GetDevOpsPct() int64 {
	return getImplementation().GetDevOpsPct()
}

// GetGovStakerPct returns the GovStaker fee percentage.
//
// Returns:
//   - pct: GovStaker fee percentage in basis points (0-10000)
func GetGovStakerPct() int64 {
	return getImplementation().GetGovStakerPct()
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
