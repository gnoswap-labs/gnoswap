// Package staker manages liquidity mining rewards for GnoSwap positions.
//
// The staker distributes GNS emissions and external incentives to liquidity
// providers based on their position size, price range, and staking duration.
// It supports both internal GNS rewards and external token incentives.
//
// Rewards are calculated per-tick and accumulate over time, with automatic
// compounding and fee collection integration.
package staker
