# GNS Token

The `GNS` token serves as the governance and gnoswap's utility token. The emission system is designed to distribute token gradually over time, with a decreasing inflation rate.

## Token Implementation

- Follows `grc20` token specs
- Symbol: `GNS`
- Decimals: 6

## Emission Mechanism

- Block-based token emission with predefined schedule
- Token emission follows a halving model over a 12 years
- Each halving period adjusts the amounts of tokens minted per block

## Halving Schedule

- 12 years emission period devided into halving periods

| Years | Description |
| --- | --- |
| 1-2 | Full emission rate |
| 3-4 | 50% of initial emission rate |
| 5-6 | 25% of initial emission rate |
| 7-8 | 12.5% of initial emission rate |
| 9-12 | 6.25% of initial emission rate |
