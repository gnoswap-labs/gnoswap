package gns

import (
	gnsmath "gno.land/p/gnoswap/gnsmath"
)

// HalvingData stores emission data for each halving period.
// Contains timestamps, amounts, and rates for the 12-year emission schedule.
type HalvingData struct {
	startTimestamps []int64
	endTimestamps   []int64
	maxAmount       []int64
	leftAmount      []int64
	mintedAmount    []int64
	amountPerSecond []int64
}

// getStartTimestamp returns the inclusive start Unix timestamp for year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//
// Returns:
//   - timestamp: stored start timestamp for year, or 0 when year is invalid
func (h *HalvingData) getStartTimestamp(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}

	return h.startTimestamps[year-1]
}

// getEndTimestamp returns the inclusive end Unix timestamp for year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//
// Returns:
//   - timestamp: stored end timestamp for year, or 0 when year is invalid
func (h *HalvingData) getEndTimestamp(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}

	return h.endTimestamps[year-1]
}

// getMaxAmount returns the maximum GNS emission allocation stored for year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//
// Returns:
//   - amount: maximum GNS base units allocated to year, or 0 when year is invalid
func (h *HalvingData) getMaxAmount(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}

	return h.maxAmount[year-1]
}

// getMintedAmount returns the GNS emission amount already recorded as minted for year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//
// Returns:
//   - amount: minted GNS base units stored for year, or 0 when year is invalid
func (h *HalvingData) getMintedAmount(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}
	return h.mintedAmount[year-1]
}

// getLeftAmount returns the unminted GNS emission allocation stored for year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//
// Returns:
//   - amount: remaining GNS base units stored for year, or 0 when year is invalid
func (h *HalvingData) getLeftAmount(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}
	return h.leftAmount[year-1]
}

// getAmountPerSecond returns the GNS emission rate stored for year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//
// Returns:
//   - amountPerSecond: GNS base units emitted per second in year, or 0 when year is invalid
func (h *HalvingData) getAmountPerSecond(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}
	return h.amountPerSecond[year-1]
}

// setStartTimestamp stores the inclusive start Unix timestamp for year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//   - timestamp: Unix timestamp to store as year's start
//
// Returns:
//   - error: nil when year is valid and the timestamp is stored; non-nil when year is outside [1, 12]
func (h *HalvingData) setStartTimestamp(year int64, timestamp int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.startTimestamps[year-1] = timestamp

	return nil
}

// setEndTimestamp stores the inclusive end Unix timestamp for year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//   - timestamp: Unix timestamp to store as year's end
//
// Returns:
//   - error: nil when year is valid and the timestamp is stored; non-nil when year is outside [1, 12]
func (h *HalvingData) setEndTimestamp(year int64, timestamp int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.endTimestamps[year-1] = timestamp

	return nil
}

// setMaxAmount stores the maximum GNS allocation for year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//   - amount: maximum GNS base units to store for year
//
// Returns:
//   - error: nil when year is valid and amount is stored; non-nil when year is outside [1, 12]
func (h *HalvingData) setMaxAmount(year, amount int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.maxAmount[year-1] = amount

	return nil
}

// setMintedAmount stores the already minted GNS allocation for year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//   - amount: minted GNS base units to store for year
//
// Returns:
//   - error: nil when year is valid and amount is stored; non-nil when year is outside [1, 12]
func (h *HalvingData) setMintedAmount(year, amount int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.mintedAmount[year-1] = amount

	return nil
}

// setLeftAmount stores the remaining GNS allocation for year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//   - amount: remaining unminted GNS base units to store for year
//
// Returns:
//   - error: nil when year is valid and amount is stored; non-nil when year is outside [1, 12]
func (h *HalvingData) setLeftAmount(year, amount int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.leftAmount[year-1] = amount

	return nil
}

// addMintedAmount adds amount to the stored minted allocation for year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//   - amount: GNS base units to add to year's minted amount
//
// Returns:
//   - error: nil when year is valid and the updated amount is stored; non-nil when year is outside [1, 12]
func (h *HalvingData) addMintedAmount(year, amount int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.mintedAmount[year-1] = gnsmath.SafeAddInt64(h.mintedAmount[year-1], amount)

	return nil
}

// setAmountPerSecond stores the GNS emission rate for year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//   - amount: GNS base units emitted per second to store for year
//
// Returns:
//   - error: nil when year is valid and amount is stored; non-nil when year is outside [1, 12]
func (h *HalvingData) setAmountPerSecond(year, amount int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.amountPerSecond[year-1] = amount

	return nil
}

// Clone creates a deep copy of all halving schedule slices.
//
// Returns:
//   - halvingData: independent copy of timestamps, allocations, minted amounts, remaining amounts, and rates
func (h *HalvingData) Clone() *HalvingData {
	startTimestamps := make([]int64, len(h.startTimestamps))
	endTimestamps := make([]int64, len(h.endTimestamps))
	maxAmount := make([]int64, len(h.maxAmount))
	leftAmount := make([]int64, len(h.leftAmount))
	mintedAmount := make([]int64, len(h.mintedAmount))
	amountPerSecond := make([]int64, len(h.amountPerSecond))

	copy(startTimestamps, h.startTimestamps)
	copy(endTimestamps, h.endTimestamps)
	copy(maxAmount, h.maxAmount)
	copy(leftAmount, h.leftAmount)
	copy(mintedAmount, h.mintedAmount)
	copy(amountPerSecond, h.amountPerSecond)

	return &HalvingData{
		startTimestamps: startTimestamps,
		endTimestamps:   endTimestamps,
		maxAmount:       maxAmount,
		leftAmount:      leftAmount,
		mintedAmount:    mintedAmount,
		amountPerSecond: amountPerSecond,
	}
}

// NewHalvingData creates a 12-year HalvingData emission schedule starting at
// startTimestamp. Each year receives configured timestamps, allocation, zero
// minted amount, remaining allocation, and an integer-truncated per-second rate.
//
// Parameters:
//   - startTimestamp: Unix timestamp at which halving year 1 begins
//
// Returns:
//   - halvingData: initialized schedule with years [1, 12] and their derived values
func NewHalvingData(startTimestamp int64) *HalvingData {
	halvingData := &HalvingData{
		startTimestamps: make([]int64, HALVING_END_YEAR),
		endTimestamps:   make([]int64, HALVING_END_YEAR),
		maxAmount:       make([]int64, HALVING_END_YEAR),
		leftAmount:      make([]int64, HALVING_END_YEAR),
		mintedAmount:    make([]int64, HALVING_END_YEAR),
		amountPerSecond: make([]int64, HALVING_END_YEAR),
	}

	for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
		yearStartTimestamp := startTimestamp + (SECONDS_IN_YEAR * (year - 1))
		yearEndTimestamp := yearStartTimestamp + SECONDS_IN_YEAR - 1
		yearDistributionAmount := GetHalvingAmountsPerYear(year)
		yearAmountPerSecond := yearDistributionAmount / SECONDS_IN_YEAR

		halvingData.setStartTimestamp(year, yearStartTimestamp)
		halvingData.setEndTimestamp(year, yearEndTimestamp)
		halvingData.setMaxAmount(year, yearDistributionAmount)
		halvingData.setMintedAmount(year, 0)
		halvingData.setAmountPerSecond(year, yearAmountPerSecond)
		halvingData.setLeftAmount(year, yearDistributionAmount)
	}

	return halvingData
}
