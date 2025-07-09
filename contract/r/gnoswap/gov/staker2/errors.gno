package staker2

import "errors"

var (
	// Delegation errors
	ErrInsufficientAmount      = errors.New("insufficient delegation amount")
	ErrInsufficientIncrement   = errors.New("delegation increment too small")
	ErrInsufficientDelegation  = errors.New("delegation amount below minimum per address")
	ErrTooManyDelegations      = errors.New("maximum delegations per user exceeded")
	ErrNoDelegation            = errors.New("no delegation found")
	ErrInvalidAddress          = errors.New("invalid address")
	ErrSelfDelegation          = errors.New("cannot delegate to self")
	
	// Staking errors
	ErrNoStake                 = errors.New("no stake found")
	ErrInsufficientBalance     = errors.New("insufficient balance")
	
	// Epoch errors
	ErrEpochNotFinalized       = errors.New("epoch not finalized")
	ErrInvalidEpoch            = errors.New("invalid epoch")
	
	// Lock errors
	ErrStillLocked             = errors.New("tokens still locked")
	ErrNoLockedTokens          = errors.New("no locked tokens found")
	
	// Reward errors
	ErrNoRewards               = errors.New("no rewards to claim")
)