package v1

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/mock"
)

func TestInit_initStoreDataUsesFreshFeeAmountTickSpacingPerStore(cur realm, t *testing.T) {
	firstStore := mock.NewMockPoolStore()
	err := initStoreData(0, cur, firstStore)
	uassert.Nil(t, err)

	// not allowed to modify
	firstStore.SetFeeAmountTickSpacing(0, cur, map[uint32]int32{
		100:   999,
		500:   999,
		3000:  999,
		10000: 999,
	})

	secondStore := mock.NewMockPoolStore()
	err = initStoreData(0, cur, secondStore)
	uassert.Nil(t, err)

	secondStoreFeeAmountTickSpacing := secondStore.GetFeeAmountTickSpacing()
	uassert.Equal(t, secondStoreFeeAmountTickSpacing[100], int32(1))
	uassert.Equal(t, secondStoreFeeAmountTickSpacing[500], int32(10))
	uassert.Equal(t, secondStoreFeeAmountTickSpacing[3000], int32(60))
	uassert.Equal(t, secondStoreFeeAmountTickSpacing[10000], int32(200))
}
