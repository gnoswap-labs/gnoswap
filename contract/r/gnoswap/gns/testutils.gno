package gns

import (
	"std"
	"testing"
	"time"
)

func InitGnsTest(t *testing.T) {
	t.Helper()

	setLeftEmissionAmount(MAX_EMISSION_AMOUNT)
	setMintedEmissionAmount(0)
	setLastMintedTimestamp(time.Now().Unix())
	burnAmount = 0

	emissionState = NewEmissionState(std.ChainHeight(), time.Now().Unix())
}
