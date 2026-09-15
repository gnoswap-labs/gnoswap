package staker

import (
	ufmt "gno.land/p/nt/ufmt/v0"

	u256 "gno.land/p/gnoswap/uint256/v1"
)

// ProtocolFeeTokenAccumulator tracks the accumulated protocol fee per stake of one token.
//
// Fees are folded in per accrual epoch, each against the total stake in force during
// that epoch. The value after folding each epoch is kept in history so that a staker's
// reward can be settled later against the accumulator as it stood at any epoch.
type ProtocolFeeTokenAccumulator struct {
	// accumulatedX128PerStake is the latest accumulated fee per stake, scaled by 2^128
	accumulatedX128PerStake *u256.Uint
	// history maps an epoch to the accumulated value after that epoch's fees were folded
	history *UintTree // epoch -> *u256.Uint
	// firstEpoch is the first epoch a fee was folded for, or -1 when none was
	firstEpoch int64
	// foldedEpoch is the last epoch whose fees are known to be fully folded, or -1
	foldedEpoch int64
	// protocolFeeAmount is the total fee amount folded in
	protocolFeeAmount int64
}

// NewProtocolFeeTokenAccumulator creates an empty accumulator with no folded
// epochs or protocol fees recorded.
//
// Returns:
//   - *ProtocolFeeTokenAccumulator: accumulator initialized with zero values and
//     empty epoch history.
func NewProtocolFeeTokenAccumulator() *ProtocolFeeTokenAccumulator {
	return &ProtocolFeeTokenAccumulator{
		accumulatedX128PerStake: u256.Zero(),
		history:                 NewUintTree(),
		firstEpoch:              -1,
		foldedEpoch:             -1,
		protocolFeeAmount:       0,
	}
}

/* Getters */

// GetAccumulatedX128PerStake returns the latest accumulated protocol fee per stake,
// scaled by 2^128.
//
// Returns:
//   - *u256.Uint: latest accumulated fee-per-stake value in Q128 fixed-point form.
func (a *ProtocolFeeTokenAccumulator) GetAccumulatedX128PerStake() *u256.Uint {
	return a.accumulatedX128PerStake
}

// GetAccumulatedX128PerStakeAt returns the accumulated value after the fees of the
// latest folded epoch at or before epoch, or zero when no fee was folded by then.
//
// Parameters:
//   - epoch: accrual epoch whose latest post-fold value is requested.
//
// Returns:
//   - *u256.Uint: accumulated fee per stake in Q128 fixed-point form, or zero
//     when no fee was folded by epoch.
func (a *ProtocolFeeTokenAccumulator) GetAccumulatedX128PerStakeAt(epoch int64) *u256.Uint {
	if epoch < 0 {
		return u256.Zero()
	}

	accumulated := u256.Zero()
	a.history.ReverseIterate(0, epoch, func(_ int64, value any) bool {
		stored, castOk := value.(*u256.Uint)
		if !castOk {
			panic(ufmt.Sprintf("failed to cast accumulated value: %T", value))
		}
		accumulated = stored
		return true
	})

	return accumulated
}

// GetFirstEpoch returns the first epoch for which a fee was folded.
//
// Returns:
//   - int64: first folded epoch, or -1 when no fee has been folded.
func (a *ProtocolFeeTokenAccumulator) GetFirstEpoch() int64 {
	return a.firstEpoch
}

// GetFoldedEpoch returns the last epoch known to be fully folded.
//
// Returns:
//   - int64: last fully folded epoch, or -1 when no epoch is fully folded.
func (a *ProtocolFeeTokenAccumulator) GetFoldedEpoch() int64 {
	return a.foldedEpoch
}

// GetProtocolFeeAmount returns the total protocol fee amount folded into the
// accumulator.
//
// Returns:
//   - int64: total fee amount folded for this token.
func (a *ProtocolFeeTokenAccumulator) GetProtocolFeeAmount() int64 {
	return a.protocolFeeAmount
}

/* Setters */

// SetAccumulatedX128PerStakeAt stores value as the accumulated amount after epoch's
// fees and makes it the latest value.
//
// Parameters:
//   - epoch: epoch whose post-fold accumulator value is being stored.
//   - value: accumulated fee-per-stake value in Q128 fixed-point form.
func (a *ProtocolFeeTokenAccumulator) SetAccumulatedX128PerStakeAt(epoch int64, value *u256.Uint) {
	stored := u256.Zero().Set(value)
	a.accumulatedX128PerStake = stored
	a.history.Set(epoch, stored)
	if a.firstEpoch < 0 || epoch < a.firstEpoch {
		a.firstEpoch = epoch
	}
}

// SetFoldedEpoch records the last epoch whose protocol fees are fully folded.
//
// Parameters:
//   - epoch: latest fully folded accrual epoch.
func (a *ProtocolFeeTokenAccumulator) SetFoldedEpoch(epoch int64) {
	a.foldedEpoch = epoch
}

// SetProtocolFeeAmount records the total protocol fee amount folded so far.
//
// Parameters:
//   - amount: total folded protocol fee amount for this token.
func (a *ProtocolFeeTokenAccumulator) SetProtocolFeeAmount(amount int64) {
	a.protocolFeeAmount = amount
}
