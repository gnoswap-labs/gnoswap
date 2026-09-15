// Package governance implements proposal lifecycle management and voting.
// It supports text proposals, parameter changes, and community-pool spending.
// Voting uses timestamped delegation history and quorum from total xGNS supply
// (including launchpad-held xGNS); proposal timing and thresholds are configurable.
package governance
