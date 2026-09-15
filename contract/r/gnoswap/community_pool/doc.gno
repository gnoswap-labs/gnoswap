// Package community_pool manages the GnoSwap community treasury.
//
// This contract holds registered protocol-owned assets. The emission system
// routes its configured community-pool share here, and external governance may
// use proposal execution to authorize a spend. Proposal and voting state are
// outside this package: TransferToken is a direct admin-or-governance entry
// point subject to the withdrawal halt and token-transfer validation.
package community_pool
