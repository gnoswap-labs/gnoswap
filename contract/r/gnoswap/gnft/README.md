# GNFT

GRC721-compliant NFT contract for GnoSwap LP positions.

## Overview

GNFT represents each liquidity position as a unique NFT with dynamically generated SVG artwork. Each NFT features a gradient background with parameters stored efficiently to minimize gas costs.

## Core Features

### GRC721 Standard Compliance

- Full implementation of GRC721 interface
- Transfer, approval, and operator management
- Token enumeration and metadata

### Dynamic SVG Generation

- Unique gradient backgrounds for each NFT
- Parameters: x1, y1, x2, y2, color1, color2
- On-demand SVG rendering from stored parameters
- Base64-encoded data URI for direct browser display

### Gas Optimization

- Compact parameter storage (CSV string format)
- Template-based SVG generation
- Lazy rendering (generate on read, not on mint)
- Minimal storage footprint per token

### Integration

- Position contract mints NFTs for new positions
- Staker contract locks NFTs during staking
- GRC721 owner/approval checks for transfers and operator management

## Key Functions

### `Mint`

Mints new NFT for LP position.

**Parameters:**
- `cur realm`: Current realm context
- `to address`: Recipient address
- `tid grc721.TokenID`: Token ID to mint

**Returns:** `grc721.TokenID`

### `Burn`

Burns NFT when position is closed.

**Parameters:**
- `cur realm`: Current realm context
- `tid grc721.TokenID`: Token ID to burn

### `TransferFrom`

Transfers NFT ownership.

**Parameters:**
- `cur realm`: Current realm context
- `from address`: Current owner
- `to address`: New owner
- `tid grc721.TokenID`: Token ID to transfer

### `TokenURI`

Returns the token URI, rendering stored SVG parameters as a base64 image data URI.

**Parameters:**
- `tid grc721.TokenID`: Token ID

**Returns:** Token URI string, using a base64-encoded SVG data URI for generated GNFT images

### `Approve`

Approves address to manage specific token.

**Parameters:**
- `cur realm`: Current realm context
- `to address`: Address to approve
- `tid grc721.TokenID`: Token ID

### `SetApprovalForAll`

Approves operator to manage all tokens.

**Parameters:**
- `cur realm`: Current realm context
- `operator address`: Operator address
- `approved bool`: Approval status

## SVG Generation

### Parameter Format

Token URI stores compact parameters:
```
"x1,y1,x2,y2,#COLOR1,#COLOR2"
Example: "10,12,125,123,#FF5733,#33B5FF"
```

### Parameter Ranges

- x1: 7-13
- y1: 7-13
- x2: 121-126
- y2: 121-126
- colors: 6-digit hex (#RRGGBB)

### SVG Structure

```svg
<svg width="135" height="135">
  <circle cx="67.5" cy="67.5" r="67.5" fill="url(#gradient)"/>
  <!-- GnoSwap logo paths -->
  <linearGradient id="gradient" x1="X1" y1="Y1" x2="X2" y2="Y2">
    <stop stop-color="#COLOR1"/>
    <stop offset="1" stop-color="#COLOR2"/>
  </linearGradient>
</svg>
```

### Rendering Process

1. **Mint**: Generate random parameters → Store as CSV string
2. **TokenURI**: Parse CSV → Generate SVG → Encode base64 → Return data URI
3. **Display**: Browser decodes data URI → Renders SVG

## Usage

```go
// Position contract mints NFT when creating position
import "gno.land/r/gnoswap/gnft"

// Mint NFT for new position
tokenId := gnft.Mint(cross(cur), ownerAddress, positionId)

// Get token URI with SVG
imageURI, err := gnft.TokenURI(tokenId)
// Returns: "data:image/svg+xml;base64,..." for generated GNFT images

// Transfer NFT
gnft.TransferFrom(cross(cur), fromAddress, toAddress, tokenId)

// Burn NFT when closing position
gnft.Burn(cross(cur), tokenId)
```

## Security

- Position contract mints NFTs for new positions
- Transfers and approvals require the caller to be the owner or approved for the token
- Tokens held by the staker contract can only be moved by the staker
- Validated parameter ranges
- Secure random generation

## Architecture

### Dependencies

- `gno.land/p/demo/tokens/grc721`: GRC721 implementation
- `gno.land/r/gnoswap/rbac`: Access control
- `gno.land/r/gnoswap/access`: Position role mirror

### State Variables

- `nft`: GRC721 token instance
- Token URIs are stored by the GRC721 token as compact SVG parameter strings

### Access Control

- `owner.AssertOwnedByPrevious()`: Checks that the caller owns the GNFT before owner-only operations
- `checkErr()`: Panic on errors
