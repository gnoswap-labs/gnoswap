package v1

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestInit_initStoreDataUsesFreshAllowedTokensPerStore(t *testing.T) {
	firstStore := &MockStakerStore{}
	err := initStoreData(firstStore, newMockEmissionAccessor())
	uassert.Nil(t, err)

	firstStoreAllowedTokens := firstStore.GetAllowedTokens()
	firstStoreAllowedTokens[0] = "gno.land/r/gnoswap/custom"

	secondStore := &MockStakerStore{}
	err = initStoreData(secondStore, newMockEmissionAccessor())
	uassert.Nil(t, err)

	secondStoreAllowedTokens := secondStore.GetAllowedTokens()
	uassert.Equal(t, len(secondStoreAllowedTokens), 2)
	uassert.Equal(t, secondStoreAllowedTokens[0], GNS_PATH)
	uassert.Equal(t, secondStoreAllowedTokens[1], WUGNOT_PATH)
}
