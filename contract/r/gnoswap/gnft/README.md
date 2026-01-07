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
- Access control via RBAC system
- Halt mechanism for emergency stops

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

Returns token metadata with SVG image.

**Parameters:**
- `tid grc721.TokenID`: Token ID

**Returns:** Metadata JSON with base64-encoded SVG

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
tokenId := gnft.Mint(cur, ownerAddress, positionId)

// Get token metadata with SVG
metadata := gnft.TokenURI(tokenId)
// Returns: {"name":"Position #1","image":"data:image/svg+xml;base64,..."}

// Transfer NFT
gnft.TransferFrom(cur, fromAddress, toAddress, tokenId)

// Burn NFT when closing position
gnft.Burn(cur, tokenId)
```

## Security

- Only position contract can mint NFTs
- Transfers blocked during staking
- RBAC-based access control
- Halt mechanism for emergencies
- Validated parameter ranges
- Secure random generation

## Architecture

### Dependencies

- `gno.land/p/demo/grc/grc721`: GRC721 interface
- `gno.land/r/gnoswap/rbac`: Access control
- `gno.land/r/gnoswap/halt`: Emergency stops

### State Variables

- `nft *grc721.AdminToken`: GRC721 token instance
- `tokenURIs avl.Tree`: TokenID → parameter string mapping

### Access Control

- `owner.AssertOwnedByPrevious()`: Only position contract
- `checkErr()`: Panic on errors
- `halt.AssertIsNotHalted*()`: Check halt status
