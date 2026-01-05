// Package gnft implements GRC721-compliant NFTs for GnoSwap LP positions.
//
// Each LP position in GnoSwap is represented as a unique NFT with dynamically
// generated SVG artwork. The contract manages ownership, transfers, and visual
// representation of positions while minimizing storage costs.
//
// Key features:
// - GRC721 standard compliance for interoperability
// - Unique SVG generation with gradient backgrounds
// - Gas-optimized parameter storage (string format)
// - Integration with position and staker contracts
// - Halt mechanism for emergency stops
package gnft
