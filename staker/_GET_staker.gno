package staker

func IsStaked(tokenId uint64) bool {
	_, exist := deposits[tokenId]
	return exist
}
