// package v1 manages liquidity positions as NFTs in GnoSwap pools.
//
// Each position is represented as a GRC721 NFT with concentrated liquidity
// within a specific tick range. Unstaked NFTs follow GRC721 owner/approval/
// operator transfer rules; staked NFTs are locked to staker-mediated transfers.
// The package handles minting, liquidity adjustments, fee collection, and
// repositioning.
package position
