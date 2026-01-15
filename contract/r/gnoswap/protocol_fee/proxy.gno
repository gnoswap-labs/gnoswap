package protocol_fee

// DistributeProtocolFee distributes accumulated protocol fees to DevOps and GovStaker.
//
// Returns:
//   - amountsByToken: amounts distributed per token
func DistributeProtocolFee(cur realm) map[string]int64 {
	return getImplementation().DistributeProtocolFee()
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
func AddToProtocolFee(cur realm, tokenPath string, amount int64) {
	getImplementation().AddToProtocolFee(tokenPath, amount)
}

// ClearTokenListWithAmount clears the token list with amounts.
func ClearTokenListWithAmount(cur realm) {
	getImplementation().ClearTokenListWithAmount()
}

// ClearAccuTransferToGovStaker clears accumulated transfers to GovStaker.
func ClearAccuTransferToGovStaker(cur realm) {
	getImplementation().ClearAccuTransferToGovStaker()
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

// GetTokenListWithAmount returns the list of tokens with their amounts.
//
// Returns:
//   - tokenAmounts: map of token paths to their amounts
func GetTokenListWithAmount() map[string]int64 {
	return getImplementation().GetTokenListWithAmount()
}

// GetTokenList returns the list of token paths without amounts.
//
// Returns:
//   - tokenPaths: slice of token paths
func GetTokenList() []string {
	return getImplementation().GetTokenList()
}

// GetAmountOfToken returns the amount of a specific token.
//
// Parameters:
//   - tokenPath: path of the token
//
// Returns:
//   - amount: token amount in the protocol fee pool
func GetAmountOfToken(tokenPath string) int64 {
	return getImplementation().GetAmountOfToken(tokenPath)
}

// GetAccuTransfersToGovStaker returns accumulated transfers to GovStaker.
//
// Returns:
//   - transfers: map of token paths to accumulated amounts
func GetAccuTransfersToGovStaker() map[string]int64 {
	return getImplementation().GetAccuTransfersToGovStaker()
}

// GetAccuTransfersToDevOps returns accumulated transfers to DevOps.
//
// Returns:
//   - transfers: map of token paths to accumulated amounts
func GetAccuTransfersToDevOps() map[string]int64 {
	return getImplementation().GetAccuTransfersToDevOps()
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

// GetHistoryOfDistributedToGovStakerByTokenPath returns historical GovStaker distributions for a token.
//
// Parameters:
//   - tokenPath: path of the token
//
// Returns:
//   - amount: total distributed amount
func GetHistoryOfDistributedToGovStakerByTokenPath(tokenPath string) int64 {
	return getImplementation().GetHistoryOfDistributedToGovStakerByTokenPath(tokenPath)
}

// GetHistoryOfDistributedToDevOpsByTokenPath returns historical DevOps distributions for a token.
//
// Parameters:
//   - tokenPath: path of the token
//
// Returns:
//   - amount: total distributed amount
func GetHistoryOfDistributedToDevOpsByTokenPath(tokenPath string) int64 {
	return getImplementation().GetHistoryOfDistributedToDevOpsByTokenPath(tokenPath)
}
