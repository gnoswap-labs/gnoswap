// Package v1 manages GNS delegation and xGNS accounting.
// It maintains timestamped delegation history, distributes GNS emission and
// protocol-fee rewards, and enforces a configurable undelegation lockup
// (7 days by default; xGNS is burned when undelegated GNS is collected).
package staker
