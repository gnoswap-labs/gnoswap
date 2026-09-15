// Package xgns implements the GRC20-compliant xGNS token that represents
// GNS held by gov/staker delegations and launchpad deposits. It manages balances,
// total supply, and the gov/staker-authorized mint and burn operations used by
// both accounting paths.
//
// xGNS does not maintain a separate voting-power ledger. Governance and
// gov/staker read xGNS balances and supply, then apply delegation history and
// proposal rules outside this package.
package xgns
