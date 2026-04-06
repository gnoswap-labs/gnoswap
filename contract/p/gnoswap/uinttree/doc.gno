// Package uinttree provides a shared uint64-keyed AVL wrapper for GnoSwap realms.
//
// Keys are encoded as zero-padded decimal strings so natural AVL ordering matches
// uint64 ordering, which makes the package suitable for timestamp-indexed history.
package uinttree
