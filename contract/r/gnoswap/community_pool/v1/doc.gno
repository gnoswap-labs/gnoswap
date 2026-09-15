// Package community_pool manages the GnoSwap community treasury.
//
// This contract holds registered protocol-owned assets. The emission system
// routes its configured community-pool share here, and external governance may
// use proposal execution to authorize a spend. Proposal and voting state are
// outside this package: TransferToken is a direct admin-or-governance entry
// point subject to the withdrawal halt and token-transfer validation.
//
// Governance is the recommended normal route. While governance is not yet
// mature, admin access is retained for emergency-only use as an operational
// policy. The contract does not verify an emergency or require proposal
// approval for admin calls, and admin access does not expire automatically.
package community_pool
