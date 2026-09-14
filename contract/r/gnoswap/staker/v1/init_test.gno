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

	uassert.True(t, firstStore.HasAllowedToken("gno.land/r/gnoswap/custom"))
	uassert.False(t, secondStore.HasAllowedToken("gno.land/r/gnoswap/custom"))
	uassert.True(t, secondStore.HasAllowedToken(GNS_TOKEN_KEY))
	uassert.True(t, secondStore.HasAllowedToken(WUGNOT_TOKEN_KEY))
}

func TestInit_initStoreDataAllowsMissingDefaultInitialPool(cur realm, t *testing.T) {
	err := initStoreData(0, cur, &MockStakerStore{}, newMockEmissionAccessor())
	uassert.Nil(t, err)
}
