package v2

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// 2 ** 128
var q128 = u256.MustFromDecimal("340282366920938463463374607431768211456")

// Previously, we used a different zero address ("g1000000..."),
// but we changed the value because using the address
// below appears to have become the de facto standard practice.
var zeroAddress address = address("")

type MintParams struct {
	token0         string     // token0 path for a specific pool
	token1         string     // token1 path for a specific pool
	fee            uint32     // fee for a specific pool
	tickLower      int32      // lower end of the tick range for the position
	tickUpper      int32      // upper end of the tick range for the position
	amount0Desired *u256.Uint // desired amount of token0 to be minted
	amount1Desired *u256.Uint // desired amount of token1 to be minted
	amount0Min     *u256.Uint // minimum amount of token0 to be minted
	amount1Min     *u256.Uint // minimum amount of token1 to be minted
	deadline       int64      // time by which the transaction must be included to effect the change
	mintTo         address    // address to mint lpToken
	caller         address    // address to call the function
}

// newMintParams creates `MintParams` from processed input data.
func newMintParams(input ProcessedMintInput, mintInput MintInput) MintParams {
	return MintParams{
		token0:         input.tokenPair.token0,
		token1:         input.tokenPair.token1,
		fee:            mintInput.fee,
		tickLower:      input.tickLower,
		tickUpper:      input.tickUpper,
		amount0Desired: input.amount0Desired,
		amount1Desired: input.amount1Desired,
		amount0Min:     input.amount0Min,
		amount1Min:     input.amount1Min,
		deadline:       mintInput.deadline,
		mintTo:         mintInput.mintTo,
		caller:         mintInput.caller,
	}
}

type IncreaseLiquidityParams struct {
	positionId     uint64     // positionId of the position to increase liquidity
	amount0Desired *u256.Uint // desired amount of token0 to be minted
	amount1Desired *u256.Uint // desired amount of token1 to be minted
	amount0Min     *u256.Uint // minimum amount of token0 to be minted
	amount1Min     *u256.Uint // minimum amount of token1 to be minted
	deadline       int64      // time by which the transaction must be included to effect the change
	caller         address    // address to call the function
}

type DecreaseLiquidityParams struct {
	positionId   uint64     // positionId of the position to decrease liquidity
	liquidity    string     // amount of liquidity to decrease
	amount0Min   *u256.Uint // minimum amount of token0 to be minted
	amount1Min   *u256.Uint // minimum amount of token1 to be minted
	deadline     int64      // time by which the transaction must be included to effect the change
	unwrapResult bool       // whether to unwrap the token if it's wrapped native token
	caller       address    // address to call the function
}

type MintInput struct {
	token0         string
	token1         string
	fee            uint32
	tickLower      int32
	tickUpper      int32
	amount0Desired string
	amount1Desired string
	amount0Min     string
	amount1Min     string
	deadline       int64
	mintTo         address
	caller         address
}

type TokenPair struct {
	token0         string
	token1         string
	token0IsNative bool
	token1IsNative bool
	wrappedAmount  int64
}

type ProcessedMintInput struct {
	tokenPair      TokenPair
	amount0Desired *u256.Uint
	amount1Desired *u256.Uint
	amount0Min     *u256.Uint
	amount1Min     *u256.Uint
	tickLower      int32
	tickUpper      int32
	poolPath       string
}

// FeeGrowthInside represents fee growth inside ticks
type FeeGrowthInside struct {
	feeGrowthInside0LastX128 *u256.Uint
	feeGrowthInside1LastX128 *u256.Uint
}
