package gns

// HalvingData stores emission data for each halving period.
// Contains timestamps, amounts, and rates for the 12-year emission schedule.
type HalvingData struct {
	startTimestamps []int64
	endTimestamps   []int64
	maxAmount       []int64
	mintedAmount    []int64
	leftAmount      []int64
	accumAmount     []int64
	amountPerSecond []int64
}

// getStartTimestamp returns the start timestamp for the specified halving year.
// Returns 0 if year is invalid.
func (h *HalvingData) getStartTimestamp(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}

	return h.startTimestamps[year-1]
}

// getEndTimestamp returns the end timestamp for the specified halving year.
// Returns 0 if year is invalid.
func (h *HalvingData) getEndTimestamp(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}

	return h.endTimestamps[year-1]
}

// getMaxAmount returns the maximum emission amount for the specified halving year.
// Returns 0 if year is invalid.
func (h *HalvingData) getMaxAmount(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}

	return h.maxAmount[year-1]
}

// getMintedAmount returns the amount already minted for the specified halving year.
func (h *HalvingData) getMintedAmount(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}
	return h.mintedAmount[year-1]
}

// getAccumAmount returns the accumulated emission amount for the specified halving year.
func (h *HalvingData) getAccumAmount(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}
	return h.accumAmount[year-1]
}

// getLeftAmount returns the remaining emission amount for the specified halving year.
func (h *HalvingData) getLeftAmount(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}
	return h.leftAmount[year-1]
}

// getAmountPerSecond returns the emission rate per second for the specified halving year.
// Returns 0 if year is invalid.
func (h *HalvingData) getAmountPerSecond(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}
	return h.amountPerSecond[year-1]
}

// setStartTimestamp sets the start timestamp for the specified halving year.
// Returns error if year is invalid.
func (h *HalvingData) setStartTimestamp(year int64, timestamp int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.startTimestamps[year-1] = timestamp

	return nil
}

// setEndTimestamp sets the end timestamp for the specified halving year.
func (h *HalvingData) setEndTimestamp(year int64, timestamp int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.endTimestamps[year-1] = timestamp

	return nil
}

// setMaxAmount sets the maximum emission amount for the specified halving year.
func (h *HalvingData) setMaxAmount(year, amount int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.maxAmount[year-1] = amount

	return nil
}

// setMintedAmount sets the minted amount for the specified halving year.
func (h *HalvingData) setMintedAmount(year, amount int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.mintedAmount[year-1] = amount

	return nil
}

// setAccumAmount sets the accumulated amount for the specified halving year.
func (h *HalvingData) setAccumAmount(year, amount int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.accumAmount[year-1] = amount

	return nil
}

// setLeftAmount sets the remaining amount for the specified halving year.
func (h *HalvingData) setLeftAmount(year, amount int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.leftAmount[year-1] = amount

	return nil
}

// addAccumAmount adds to the accumulated amount for the specified halving year.
func (h *HalvingData) addAccumAmount(year, amount int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.accumAmount[year-1] += amount

	return nil
}

// setAmountPerSecond sets the emission rate per second for the specified halving year.
// Returns error if year is invalid.
func (h *HalvingData) setAmountPerSecond(year, amount int64) error {
	err := validYear(year)
	if err != nil {
		return err
	}

	h.amountPerSecond[year-1] = amount

	return nil
}

// NewHalvingData creates a new HalvingData instance with emission schedule.
// Initializes 12 years of halving periods with timestamps, amounts, and rates based on startTimestamp.
func NewHalvingData(startTimestamp int64) *HalvingData {
	halvingData := &HalvingData{
		startTimestamps: make([]int64, HALVING_END_YEAR),
		endTimestamps:   make([]int64, HALVING_END_YEAR),
		maxAmount:       make([]int64, HALVING_END_YEAR),
		mintedAmount:    make([]int64, HALVING_END_YEAR),
		leftAmount:      make([]int64, HALVING_END_YEAR),
		accumAmount:     make([]int64, HALVING_END_YEAR),
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
		halvingData.setAccumAmount(year, 0)
		halvingData.setAmountPerSecond(year, yearAmountPerSecond)
		halvingData.setLeftAmount(year, yearDistributionAmount)
	}

	return halvingData
}
