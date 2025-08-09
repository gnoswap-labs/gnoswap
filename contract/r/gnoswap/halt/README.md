# Halt

Emergency pause mechanism for protocol safety.

## Features

- Selective halting of protocol functions
- Admin/governance control
- Safety mode for beta mainnet

## Beta Mainnet

Protocol starts in `MainnetSafeMode` with withdrawals disabled. Governance enables withdrawals after network stability is confirmed.

See [halt package](../../../p/gnoswap/halt) for implementation details.

## Notes

### Configurable Parameters
The following parameters can be modified:
- **Halt Level**: System-wide halt status (Unhalt, MainnetSafeMode, PartialHalt, CompleteHalt)
- **Operation Status**: Individual operation controls (Swap, Stake, Unstake, Withdraw, etc.)
