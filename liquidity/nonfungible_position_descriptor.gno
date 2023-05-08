package liquidity

import (
	factory "gno.land/p/demo/factory" 
)

const (
	// DAI std.Address = "0x6b175474e89094c44da98b954eedeac495271d0f"
	DAI std.Address = "gno.land/r/demo/dai"
	USDC std.Address = "gno.land/r/demo/usdc"
	USDT std.Address = "gno.land/r/demo/usdt"
	TBTC std.Address = "gno.land/r/demo/tbtc"
	WBTC std.Address = "gno.land/r/demo/wbtc"

	WET9 std.Address
	nativeCurrencyLabelBytes []byte
)


func Init(
	_WETH9 std.Address,
	_nativeCurrencyLabelBytes []byte,
) {
	WETH9 = _WETH9
	nativeCurrencyLabelBytes = _nativeCurrencyLabelBytes
}


func nativeCUrrencyLabel() string {
	string(nativeCurrencyLabelBytes[:])
}


func tokenURI(positionManager INonfungiblePositionManager, tokenId bigint) string {
	var (
		token0 std.Address
		token1	std.Address
		fee bigint
		tickLower bigint
		tickUpper bigint
	)
	(, , token0, token1, fee, tickLower, tickUpper, , , , ,) = positionManager.positions(tokenId)

	// XXX test.DerivePakcageAddress deprecated
	pool = factory.getPool(token0, token1, fee)

	var _flipRatio bool = flipRatio(token0, token1, ChainId.get())
	var quoteTokenAddress = !_flipRatio ? token1: token0;
	var baseTokenAddress = !_flipRatio ? token0: token1;
	(, tick bigint, , , , ,) = pool.slot0();

	return
		NFTDescriptor.constructTokenURI(
			NFTDescriptor.ConstructTokenURIParams({
				tokenId: tokenId,
				quoteTokenAddress: quoteTokenAddress,
				baseTokenAddress: baseTokenAddress,
				quoteTokenSymbol: quoteTokenAddress == WETH9
					? nativeCurrencyLabel()
					: SafeERC20Namer.tokenSymbol(quoteTokenAddress),
				baseTokenSYmbol: baseTokenAddress == WETH9
					? nativeCurrencyLabel()
					: SafeERC20Namer.tokenSymbol(baseTokenAddress),
				quoteTokenDecimals: IERC20Metadata(quoteTokenAddress).decimals(), // Token1.Decimals
				baseTokenDecimals: IERC20Metadata(baseTokenAddress).decimals(), // Token0.Decimals
				flipRatio: _flipRatio,
				tickLower: tickLower,
				tickUpper: tickUpper,
				tickCurrent: tick,
				tickSpacing: pool.tickSpacing(),
				fee: fee,
				poolAddress: pool
			})
		)
}


func flipRatio {
	token0 std.Address,
	token1 std.Address,
	chainId bigint,
} bool {
	return tokenRatioPriority(token0, chainId) > tokenRatioPriority(token1, chainId)
}

func tokenRatioPriority(token std.Address, bigint chainId) bigint {
	if (token == WETH9) {
		return TokenRatioSortOrder.DENOMINATOR
	}

	if (chainId == 1) {
		switch token {
		case USDC:
			return TokenRatioSortOrder.NUMERATOR_MOST;
		case USDT:
			return TokenRatioSortOrder.NUMERATOR_MORE;
		case DAI:
			return TokenRatioSortOrder.NUMERATOR;
		case TBTC:
			return TokenRatioSortOrder.NUMERATOR_MORE;
		case WBTC:
			return TokenRatioSortOrder.NUMERATOR_MOST;
		default:
			return 0
		}
	}

	return 0
}