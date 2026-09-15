// Package staker manages liquidity mining rewards for GnoSwap positions.
//
// The staker distributes GNS emissions and external incentives to liquidity
// providers based on their position size, price range, and staking duration.
// It supports both internal GNS rewards and external token incentives.
//
// Reward calculations combine elapsed-time rates with tick/range accumulation, and
// collection flows are integrated into the staking lifecycle.
package staker
