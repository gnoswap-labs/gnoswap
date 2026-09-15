// Package gnft implements the position-NFT surface used by GnoSwap.
//
// It provides GRC721-compatible ownership, transfer, approval, and metadata
// operations for LP positions. Generated parameter-format URIs become SVG data
// URIs on read; custom non-empty URIs are returned unchanged. Enumeration and
// safeTransferFrom are not exposed by this package.
package gnft
