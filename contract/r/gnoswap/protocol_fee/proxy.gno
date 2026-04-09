package protocol_fee

// DistributeProtocolFee distributes accumulated protocol fees to DevOps and GovStaker.
//
// Parameters:
//   - cur: current realm context
func DistributeProtocolFee(cur realm) {
	getImplementation().DistributeProtocolFee()
}

// SetDevOpsPct sets the percentage of protocol fees allocated to DevOps.
//
// Parameters:
//   - pct: percentage (0-100)
func SetDevOpsPct(cur realm, pct int64) {
	getImplementation().SetDevOpsPct(pct)
}

// SetGovStakerPct sets the percentage of protocol fees allocated to GovStaker.
//
// Parameters:
//   - pct: percentage (0-100)
func SetGovStakerPct(cur realm, pct int64) {
	getImplementation().SetGovStakerPct(pct)
}

// AddToProtocolFee adds tokens to the protocol fee pool.
//
// Parameters:
//   - tokenPath: path of the token
//   - amount: amount to add
func AddToProtocolFee(cur realm, tokenPath string, amount int64) error {
	return getImplementation().AddToProtocolFee(tokenPath, amount)
}

// GetDevOpsPct returns the DevOps fee percentage.
//
// Returns:
//   - pct: DevOps fee percentage (0-100)
func GetDevOpsPct() int64 {
	return getImplementation().GetDevOpsPct()
}

// GetGovStakerPct returns the GovStaker fee percentage.
//
// Returns:
//   - pct: GovStaker fee percentage (0-100)
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
func GetActualDistributedToGovStaker() map[string]int64 {
	return cloneStringInt64Map(getImplementation().GetActualDistributedToGovStaker())
}

// GetActualDistributedToDevOps returns actual transfers completed to DevOps.
func GetActualDistributedToDevOps() map[string]int64 {
	return cloneStringInt64Map(getImplementation().GetActualDistributedToDevOps())
}

// GetActualDistributedToGovStakerByTokenPath returns actual GovStaker transfer for a token.
func GetActualDistributedToGovStakerByTokenPath(tokenPath string) int64 {
	return getImplementation().GetActualDistributedToGovStakerByTokenPath(tokenPath)
}

// GetActualDistributedToDevOpsByTokenPath returns actual DevOps transfer for a token.
func GetActualDistributedToDevOpsByTokenPath(tokenPath string) int64 {
	return getImplementation().GetActualDistributedToDevOpsByTokenPath(tokenPath)
}
