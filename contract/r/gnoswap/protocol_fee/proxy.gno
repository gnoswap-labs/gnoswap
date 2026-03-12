package protocol_fee

// DistributeProtocolFee distributes accumulated protocol fees to DevOps and GovStaker.
//
// Returns:
//   - map[string]int64: amounts distributed per token
func DistributeProtocolFee(cur realm) map[string]int64 {
	distributed := getImplementation().DistributeProtocolFee()
	result := make(map[string]int64, len(distributed))
	for tokenPath, amount := range distributed {
		result[tokenPath] = amount
	}
	return result
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
func GetDevOpsPct() int64 {
	return getImplementation().GetDevOpsPct()
}

// GetGovStakerPct returns the GovStaker fee percentage.
func GetGovStakerPct() int64 {
	return getImplementation().GetGovStakerPct()
}

// GetTokenListWithAmount returns the list of tokens with their amounts.
func GetTokenListWithAmount() map[string]int64 {
	tokenListWithAmount := getImplementation().GetTokenListWithAmount()
	result := make(map[string]int64, len(tokenListWithAmount))
	for tokenPath, amount := range tokenListWithAmount {
		result[tokenPath] = amount
	}
	return result
}

// GetTokenList returns the list of token paths without amounts.
func GetTokenList() []string {
	tokenList := getImplementation().GetTokenList()
	result := make([]string, len(tokenList))
	copy(result, tokenList)
	return result
}

// GetAmountOfToken returns the amount of a specific token.
func GetAmountOfToken(tokenPath string) int64 {
	return getImplementation().GetAmountOfToken(tokenPath)
}

// GetAccuTransfersToGovStaker returns accumulated transfers to GovStaker.
func GetAccuTransfersToGovStaker() map[string]int64 {
	accuTransfers := getImplementation().GetAccuTransfersToGovStaker()
	result := make(map[string]int64, len(accuTransfers))
	for tokenPath, amount := range accuTransfers {
		result[tokenPath] = amount
	}
	return result
}

// GetAccuTransfersToDevOps returns accumulated transfers to DevOps.
func GetAccuTransfersToDevOps() map[string]int64 {
	accuTransfers := getImplementation().GetAccuTransfersToDevOps()
	result := make(map[string]int64, len(accuTransfers))
	for tokenPath, amount := range accuTransfers {
		result[tokenPath] = amount
	}
	return result
}

// GetAccuTransferToGovStakerByTokenPath returns accumulated GovStaker transfer for a token.
func GetAccuTransferToGovStakerByTokenPath(tokenPath string) int64 {
	return getImplementation().GetAccuTransferToGovStakerByTokenPath(tokenPath)
}

// GetAccuTransferToDevOpsByTokenPath returns accumulated DevOps transfer for a token.
func GetAccuTransferToDevOpsByTokenPath(tokenPath string) int64 {
	return getImplementation().GetAccuTransferToDevOpsByTokenPath(tokenPath)
}
