package position

func PositionGetPosition(tokenId string) Position {
	// return positions[tokenId].(Position)
	_position, ok := positions.Get(tokenId)
	var position Position
	if ok {
		position = _position.(Position)
	} else {
		position = Position{}
	}

	return position
}

func PositionGetPositionTickLower(tokenId string) bigint {
	// return positions[tokenId].tickLower
	_position, ok := positions.Get(tokenId)
	var position Position
	if ok {
		position = _position.(Position)
	} else {
		position = Position{}
	}

	return position.tickLower
}

func PositionGetPositionTickUpper(tokenId string) bigint {
	// return positions[tokenId].tickUpper
	_position, ok := positions.Get(tokenId)
	var position Position
	if ok {
		position = _position.(Position)
	} else {
		position = Position{}
	}

	return position.tickUpper
}

func PositionGetPositionTickLiquidity(tokenId string) bigint {
	// return positions[tokenId].liquidity
	_position, ok := positions.Get(tokenId)
	var position Position
	if ok {
		position = _position.(Position)
	} else {
		position = Position{}
	}

	return position.liquidity
}
