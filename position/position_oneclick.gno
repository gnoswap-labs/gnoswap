package position

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/wugnot"

	"gno.land/r/demo/consts"

	pl "gno.land/r/demo/pool"

	u256 "gno.land/p/big/uint256"
)

const UGNOT_MINT_DEPOSIT_TO_WRAP = 1 // defined in gno.land/r/demo/wugnot

func OneClickMint(
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	_amount0Desired string, // *u256.Uint
	_amount1Desired string, // *u256.Uint
	_amount0Min string, // *u256.Uint
	_amount1Min string, // *u256.Uint
	deadline int64,
) (uint64, string, string, string) { // tokenId, liquidity, amount0, amount1 ( *u256.Uint x3)
	std.AssertOriginCall() // can not call by other contract

	// one of token should be "gnot"
	token0IsNative := true
	if token0 == consts.GNOT {
		token0 = consts.WRAPPED_WUGNOT
	} else if token1 == consts.GNOT {
		token1 = consts.WRAPPED_WUGNOT
		token0IsNative = false
	} else {
		panic("one of token should be native gnot")
	}

	if token1 < token0 {
		token0, token1 = token1, token0
		_amount0Desired, _amount1Desired = _amount1Desired, _amount0Desired
		_amount0Min, _amount1Min = _amount1Min, _amount0Min
		tickLower, tickUpper = -tickUpper, -tickLower
		token0IsNative = !token0IsNative
	}

	amount0Desired := u256.MustFromDecimal(_amount0Desired)
	amount1Desired := u256.MustFromDecimal(_amount1Desired)
	amount0Min := u256.MustFromDecimal(_amount0Min)
	amount1Min := u256.MustFromDecimal(_amount1Min)

	// one of token amount can be 0 if position is out of range
	// check above condition using DryMint()
	poolPath := ufmt.Sprintf("%s:%s:%d", token0, token1, fee)
	poolCurrentTick := pl.PoolGetSlot0Tick(poolPath)

	estimatedMintAmount0Str, estimatedMintAmount1Str := DryMint(
		poolCurrentTick,
		tickLower,
		tickUpper,
		_amount0Desired,
		_amount1Desired,
	)

	// if estmiated gnot amount is not 0, user should have been sent gnot to position
	ugnotSent := uint64(0)
	if (token0IsNative && estimatedMintAmount0Str != "0") || (token0IsNative == false && estimatedMintAmount1Str != "0") {
		// GNOT: position -> wugnot
		oldWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigPkgAddr()))

		sent := std.GetOrigSend()
		ugnotSent = uint64(sent.AmountOf("ugnot"))

		if ugnotSent < UGNOT_MINT_DEPOSIT_TO_WRAP {
			panic(ufmt.Sprintf("Deposit below minimum: %d/%d ugnot.", ugnotSent, UGNOT_MINT_DEPOSIT_TO_WRAP))
		}

		wugnotAddr := std.DerivePkgAddr(consts.WRAPPED_WUGNOT)
		banker := std.GetBanker(std.BankerTypeRealmSend)
		banker.SendCoins(std.GetOrigPkgAddr(), wugnotAddr, std.Coins{{"ugnot", int64(ugnotSent)}})
		wugnot.Deposit() // WUGNOT: wugnot -> position

		newWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigPkgAddr()))
		if newWugnotBalance != oldWugnotBalance+ugnotSent {
			panic(ufmt.Sprintf("wugnot deposit failed(old:%d + send:%d != new:%d)", oldWugnotBalance, int64(ugnotSent), newWugnotBalance))
		}

		// WUGNOT: position -> user
		wugnot.Transfer(a2u(std.GetOrigCaller()), ugnotSent)
	}

	mintParams := MintParams{
		token0:         token0,
		token1:         token1,
		fee:            fee,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		amount0Desired: amount0Desired,
		amount1Desired: amount1Desired,
		amount0Min:     amount0Min,
		amount1Min:     amount1Min,
		deadline:       deadline,
	}

	tokenId, liquidity, amount0, amount1 := mint(mintParams)

	// check actual minted token amount, and return left wugnot to user in NATIVE GNOT COIN
	spendWugnot := uint64(0)
	if token0 == consts.WRAPPED_WUGNOT {
		spendWugnot = amount0.Uint64()
	} else {
		spendWugnot = amount1.Uint64()
	}

	// get left wugnot from user
	leftOver := ugnotSent - spendWugnot
	wugnot.TransferFrom(a2u(std.GetOrigCaller()), a2u(std.GetOrigPkgAddr()), leftOver)

	return tokenId, liquidity.ToString(), amount0.ToString(), amount1.ToString()
}
