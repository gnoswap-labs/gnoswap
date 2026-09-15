# GNFT

GRC721-compatible NFT contract for GnoSwap LP positions.

## Overview

GNFT represents each liquidity position as a unique NFT. It exposes ownership,
transfer, approval, and metadata operations while generating compact SVG artwork
for tokens whose URI is stored in GNFT's parameter format.

GNFT implements the position-NFT surface used by GnoSwap; it does not expose
every optional GRC721 extension. In particular, this package has no token
enumeration API and does not expose `safeTransferFrom`.

## Core Features

### Ownership and approvals

- Transfer, single-token approval, and operator approval
- Owner, balance, existence, and approval queries
- Staked tokens are locked to the staker contract
- Other transfers use the GRC721 owner and approval checks

### Dynamic SVG generation

- Generated tokens store compact gradient parameters
- Parameters are rendered to SVG and returned as a base64-encoded data URI
- Rendering occurs on `TokenURI` reads rather than storing the full SVG
- A custom non-empty URI set with `SetTokenURI` is returned unchanged when it is not in GNFT parameter format

### Storage

- Compact parameter storage reduces per-token metadata size
- Template-based SVG generation avoids storing repeated markup

## Key Functions

### `Mint`

Mints a new NFT for an LP position. Only the position role may call it.

**Parameters:**
- `cur realm`: Current realm context
- `to address`: Recipient address
- `tid grc721.TokenID`: Token ID to mint

**Returns:** `grc721.TokenID`

### `Burn`

Burns an NFT when its position is closed. Only the position role may call it.

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

For a token held by the staker contract, only the staker can move it. For other
tokens, the owner, token approval, or operator approval must authorize the
transfer.

### `TokenURI`

Returns metadata for a token. When the stored URI parses as GNFT image
parameters (`x1,y1,x2,y2,color1,color2`), GNFT renders those parameters as an
SVG and returns a base64-encoded data URI. A custom non-empty URI that is not in
that parameter format is returned unchanged.

**Parameters:**
- `tid grc721.TokenID`: Token ID

**Returns:** Token URI string and an error when the token or metadata is missing

### `SetTokenURI`

Sets a non-empty token URI. Only the position role may call it.

**Parameters:**
- `cur realm`: Current realm context
- `tid grc721.TokenID`: Token ID
- `tURI string`: Non-empty metadata URI

### `Approve`

Approves an address to manage a specific token.

**Parameters:**
- `cur realm`: Current realm context
- `approved address`: Address to approve
- `tid grc721.TokenID`: Token ID

### `SetApprovalForAll`

Approves or revokes an operator for all tokens owned by the caller.

**Parameters:**
- `cur realm`: Current realm context
- `operator address`: Operator address
- `approved bool`: Approval status

### Queries

- `Name() string`: Collection name
- `Symbol() string`: Collection symbol
- `TotalSupply() int64`: Number of minted NFTs
- `BalanceOf(owner address) (int64, error)`: Number of NFTs owned
- `OwnerOf(tid grc721.TokenID) (address, error)`: Current owner
- `MustOwnerOf(tid grc721.TokenID) address`: Owner or panic on error
- `Exists(tid grc721.TokenID) bool`: Whether a token exists
- `GetApproved(tid grc721.TokenID) (address, error)`: Token approval
- `IsApprovedForAll(owner, operator address) bool`: Operator approval

## SVG Generation

### Parameter Format

Generated token URIs store compact parameters:

```
"x1,y1,x2,y2,#COLOR1,#COLOR2"
Example: "10,12,125,123,#FF5733,#33B5FF"
```

### Parameter Ranges

- `x1`: 7-13
- `y1`: 7-13
- `x2`: 121-126
- `y2`: 121-126
- colors: 6-digit hex (`#RRGGBB`)

### Rendering Process

1. **Mint**: Generate pseudo-random parameters and store them as a CSV string
2. **TokenURI**: Parse the CSV, generate SVG, encode it as base64, and return a data URI
3. **Display**: The browser decodes the data URI and renders the SVG

The parameters use time-seeded `math/rand`; this is pseudo-random artwork
generation, not a security or cryptographic randomness source.

## Usage

These helpers illustrate calls from an integrating realm. `mintExample` and
`burnExample` require that realm to hold the position role; `transferExample`
requires the caller to satisfy the ownership/approval rules described above.

```go
import (
    grc721 "gno.land/p/nt/grc721/v0"
    "gno.land/r/gnoswap/gnft"
)

func mintExample(cur realm, owner address, tokenID grc721.TokenID) grc721.TokenID {
    return gnft.Mint(cross(cur), owner, tokenID)
}

func metadataExample(tokenID grc721.TokenID) (string, error) {
    return gnft.TokenURI(tokenID)
}

func transferExample(cur realm, from, to address, tokenID grc721.TokenID) error {
    return gnft.TransferFrom(cross(cur), from, to, tokenID)
}

func burnExample(cur realm, tokenID grc721.TokenID) {
    gnft.Burn(cross(cur), tokenID)
}
```

## Security and Access Control

- `Mint`, `SetTokenURI`, and `Burn` require the position role
- Staker-held tokens can only be moved by the staker contract
- Other transfers are checked by the owner/approval rules in the GRC721 ledger
- Token URI parameters are validated before generated artwork is rendered
- Generated artwork uses pseudo-random, time-seeded parameters and must not be
  treated as a source of secure randomness

## Architecture

### Dependencies

- `gno.land/p/nt/grc721/v0`: GRC721 token and ledger implementation
- `gno.land/p/nt/grc721/metadata/v0`: Metadata storage
- `gno.land/r/gnoswap/access`: Position-role authorization

### State Variables

- `token`: GRC721 token metadata and supply state
- `ledger`: Ownership, transfer, and approval ledger
- `meta`: Token URI metadata
- `metaLedger`: Metadata update ledger

Generated image tokens store compact parameters in metadata; the full SVG data
URI is generated when `TokenURI` is called.
