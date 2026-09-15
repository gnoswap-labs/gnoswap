// Package xgns implements the GRC20-compliant xGNS token that represents
// staked GNS. It manages balances, total supply, and the gov/staker-authorized
// mint and burn operations used by delegation and launchpad accounting.
//
// xGNS does not maintain a separate voting-power ledger. Governance and
// gov/staker read xGNS balances and supply, then apply delegation history and
// proposal rules outside this package.
package xgns
