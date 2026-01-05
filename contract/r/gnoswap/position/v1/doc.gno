// package v1 manages liquidity positions as NFTs in GnoSwap pools.
//
// Each position is represented as a non-transferable GRC721 NFT with concentrated
// liquidity within a specific tick range. The package handles position lifecycle
// including minting, liquidity adjustments, fee collection, and repositioning.
//
// Key features:
// - NFT-based position management with tick-based price ranges
// - Add/remove liquidity (IncreaseLiquidity, DecreaseLiquidity)
// - Fee collection with 1% protocol fee
// - Reposition to new price ranges without creating new NFTs
// - Native token (GNOT) wrapping/unwrapping support
package v1
