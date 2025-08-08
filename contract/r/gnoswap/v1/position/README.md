# Position

GRC721 NFT representing liquidity positions in GnoSwap.

## Features

- **Minting**: Create positions with liquidity in price ranges
- **Liquidity Management**: Increase or decrease liquidity
- **Fee Collection**: Collect trading fees
- **Repositioning**: Adjust price ranges
- **NFT Representation**: Each position is unique NFT

## Properties

- Owner address
- Price range (upper/lower ticks)
- Liquidity amount
- Accumulated fees

## Liquidity Merging

Positions with overlapping price ranges merge liquidity within same ticks for capital efficiency.