package staker

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestInit_initStoreDataUsesFreshAllowedTokensPerStore(cur realm, t *testing.T) {
	firstStore := &MockStakerStore{}
	err := initStoreData(0, cur, firstStore, newMockEmissionAccessor())
	uassert.Nil(t, err)

	firstStore.SetAllowedTokens(0, cur, []string{})
	firstStore.AddAllowedToken(0, cur, "gno.land/r/gnoswap/custom")

	secondStore := &MockStakerStore{}
	err = initStoreData(0, cur, secondStore, newMockEmissionAccessor())
	uassert.Nil(t, err)

	secondStoreAllowedTokens := secondStore.GetAllowedTokens()
	uassert.Equal(t, len(secondStoreAllowedTokens), 2)
	uassert.Equal(t, secondStoreAllowedTokens[0], GNS_TOKEN_KEY)
	uassert.Equal(t, secondStoreAllowedTokens[1], WUGNOT_TOKEN_KEY)
}

func TestInit_initStoreDataAllowsMissingDefaultInitialPool(cur realm, t *testing.T) {
	err := initStoreData(0, cur, &MockStakerStore{}, newMockEmissionAccessor())
	uassert.Nil(t, err)
}
