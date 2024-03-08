package oneclick

import (
	"std"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"

	"gno.land/r/demo/consts"

	"gno.land/r/demo/wugnot"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/big/uint256"
)

const UGNOT_MINT_DEPOSIT_TO_WRAP = 1 // defined in gno.land/r/demo/wugnot

func OneClickMint(
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	amount0Desired string, // *u256.Uint
	amount1Desired string, // *u256.Uint
	amount0Min string, // *u256.Uint
	amount1Min string, // *u256.Uint
	deadline int64,
) (uint64, string, string, string) { // tokenId, liquidity, amount0, amount1 ( *u256.Uint x3 )
	std.AssertOriginCall() // can not call by other contract

	// one of token should be "gnot"
	token0IsNative := false
	if token0 == consts.GNOT {
		token0 = consts.WRAPPED_WUGNOT
		token0IsNative = true
	} else if token1 == consts.GNOT {
		token1 = consts.WRAPPED_WUGNOT
	} else {
		panic("one of token should be native gnot")
	}

	if token1 < token0 {
		token0, token1 = token1, token0
		amount0Desired, amount1Desired = amount1Desired, amount0Desired
		amount0Min, amount1Min = amount1Min, amount0Min
		tickLower, tickUpper = -tickUpper, -tickLower
		token0IsNative = !token0IsNative
	}

	// one of token amount can be 0 if position is out of range
	// check above condition using DryMint()
	poolPath := ufmt.Sprintf("%s:%s:%d", token0, token1, fee)
	poolCurrentTick := pl.PoolGetSlot0Tick(poolPath)

	estimatedMintAmount0Str, estimatedMintAmount1Str := pn.DryMint(
		poolCurrentTick,
		tickLower,
		tickUpper,
		amount0Desired,
		amount1Desired,
	)

	// if estmiated gnot amount is not 0, user should have been sent gnot to oneclick
	ugnotSent := uint64(0)
	if (token0IsNative && estimatedMintAmount0Str != "0") || (token0IsNative == false && estimatedMintAmount1Str != "0") {
		// SEND GNOT: oneclick -> wugnot
		oldWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigPkgAddr()))

		sent := std.GetOrigSend()
		ugnotSent = uint64(sent.AmountOf("ugnot"))

		if ugnotSent < UGNOT_MINT_DEPOSIT_TO_WRAP {
			panic(ufmt.Sprintf("Deposit below minimum: %d/%d ugnot.", ugnotSent, UGNOT_MINT_DEPOSIT_TO_WRAP))
		}

		wugnotAddr := std.DerivePkgAddr(consts.WRAPPED_WUGNOT)
		banker := std.GetBanker(std.BankerTypeRealmSend)
		banker.SendCoins(std.GetOrigPkgAddr(), wugnotAddr, std.Coins{{"ugnot", int64(ugnotSent)}})
		// SEND WUGNOT: wugnot -> oneclick
		wugnot.Deposit()

		newWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigPkgAddr()))
		if newWugnotBalance != oldWugnotBalance+ugnotSent {
			panic(ufmt.Sprintf("wugnot deposit failed(old:%d + send:%d != new:%d)", oldWugnotBalance, int64(ugnotSent), newWugnotBalance))
		}

		// SEND WUGNOT: position -> user
		wugnot.Transfer(a2u(std.GetOrigCaller()), ugnotSent)
	}

	tokenId, liquidityStr, amount0Str, amount1Str := pn.Mint(
		token0,
		token1,
		fee,
		tickLower,
		tickUpper,
		amount0Desired,
		amount1Desired,
		amount0Min,
		amount1Min,
		deadline,
	)

	spendWugnot := uint64(0)
	if token0 == consts.WRAPPED_WUGNOT {
		spendWugnot = u256.MustFromDecimal(amount0Str).Uint64()
	} else {
		spendWugnot = u256.MustFromDecimal(amount1Str).Uint64()
	}

	// REFUND LEFT WUGNOT
	leftOver := ugnotSent - spendWugnot
	if leftOver > 0 {
		// SEND WUGNOT: user -> oneclick
		wugnot.TransferFrom(a2u(std.GetOrigCaller()), a2u(std.GetOrigPkgAddr()), leftOver)

		// UNWRAP WUGNOT TO UGNOT
		wugnot.Withdraw(leftOver)

		// SEND GNOT: oneclick -> user
		banker := std.GetBanker(std.BankerTypeRealmSend)
		banker.SendCoins(std.GetOrigPkgAddr(), std.GetOrigCaller(), std.Coins{{"gnot", int64(leftOver)}})
	}

	return tokenId, liquidityStr, amount0Str, amount1Str
}
