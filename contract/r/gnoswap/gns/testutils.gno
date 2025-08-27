package gns

import (
	"std"
	"testing"
	"time"
)

// InitGnsTest initializes GNS state for testing by resetting emission amounts and state.
func InitGnsTest(t *testing.T) {
	t.Helper()

	setLeftEmissionAmount(MAX_EMISSION_AMOUNT)
	setMintedEmissionAmount(0)
	setLastMintedTimestamp(time.Now().Unix())
	burnAmount = 0

	emissionState = NewEmissionState(std.ChainHeight(), time.Now().Unix())
}
