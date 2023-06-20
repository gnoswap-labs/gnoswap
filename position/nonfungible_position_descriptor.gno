package position

// XXX
// import (
// 	pool "gno.land/r/pool"
// 	"std"
// )

// const (
// 	// nativeCurrencyLabelBytes []byte
// 	nativeCurrencyLabelBytes []byte = []byte("NativeCurrencyLabelBytesHere")

// 	WGNOT = std.Address("WGNOT")
// 	WATOM = std.Address("WATOM")
// 	USDC  = std.Address("USDC")
// 	WETH  = std.Address("WETH")
// 	WBTC  = std.Address("WBTC")
// )

// func nativeCurrencyLabel() string {
// 	string(nativeCurrencyLabelBytes[:])
// }

// func tokenURI(tokenId string) string {
// 	// _p := Positions(tokenId)
// 	// _token0 := _p.token0
// 	// _token1 := _p.token1
// 	// _fee := _p.fee
// 	// _tickLower := _p.tickLower
// 	// _tickUpper := _p.tickUpper
// 	_, _, token0, token1, fee, tickLower, tickUpper, _, _, _, _, _ := Positions(tokenId)

// 	// pool := PoolAddressComputeAddress(factory(), PoolKey{token0: _token0, token1: _token1, fee: _fee})

// 	_flipRatio := flipRatio(token0, token1, GetChainID())

// 	var quoteTokenAddress std.Address
// 	var baseTokenAddress std.Address
// 	if !_flipRatio {
// 		quoteTokenAddress = token1
// 		baseTokenAddress = token0
// 	} else {
// 		quoteTokenAddress = token0
// 		baseTokenAddress = token1
// 	}

// 	_tick := pool.GetPoolSlot0Tick()

// 	return ("XXX_TOKEN_URI_HERE")
// 	/*
// 		return
// 			NFTDescriptor.constructTokenURI(
// 				NFTDescriptor.ConstructTokenURIParams({
// 					tokenId: tokenId,
// 					quoteTokenAddress: quoteTokenAddress,
// 					baseTokenAddress: baseTokenAddress,
// 					quoteTokenSymbol: quoteTokenAddress == WETH9
// 						? nativeCurrencyLabel()
// 						: SafeERC20Namer.tokenSymbol(quoteTokenAddress),
// 					baseTokenSYmbol: baseTokenAddress == WETH9
// 						? nativeCurrencyLabel()
// 						: SafeERC20Namer.tokenSymbol(baseTokenAddress),
// 					quoteTokenDecimals: IERC20Metadata(quoteTokenAddress).decimals(), // Token1.Decimals
// 					baseTokenDecimals: IERC20Metadata(baseTokenAddress).decimals(), // Token0.Decimals
// 					flipRatio: _flipRatio,
// 					tickLower: tickLower,
// 					tickUpper: tickUpper,
// 					tickCurrent: tick,
// 					tickSpacing: pool.tickSpacing(),
// 					fee: fee,
// 					poolAddress: pool
// 				})
// 			)
// 	*/
// }

// func flipRatio(
// 	token0 std.Address,
// 	token1 std.Address,
// 	chainId string,
// ) bool {
// 	return tokenRatioPriority(token0, chainId) > tokenRatioPriority(token1, chainId)
// }

// func tokenRatioPriority(token std.Address, chainId string) bigint {
// 	if token == WGNOT {
// 		return DENOMINATOR
// 	}

// 	if chainId == "test3" { // current gno latest chainid
// 		// XXX which token will be in gno?
// 		switch token {
// 		case WGNOT:
// 			return NUMERATOR_MOST
// 		case WATOM:
// 			return NUMERATOR_MORE
// 		case USDC:
// 			return NUMERATOR
// 		case WETH:
// 			return NUMERATOR_MORE
// 		case WBTC:
// 			return NUMERATOR_MOST
// 		default:
// 			return 0
// 		}
// 	}

// 	return 0
// }
