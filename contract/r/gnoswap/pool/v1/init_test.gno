package v1

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/mock"
)

func TestInit_initStoreDataUsesFreshFeeAmountTickSpacingPerStore(t *testing.T) {
	firstStore := mock.NewMockPoolStore()
	err := initStoreData(firstStore)
	uassert.Nil(t, err)

	firstStore.GetFeeAmountTickSpacing()[100] = 999

	secondStore := mock.NewMockPoolStore()
	err = initStoreData(secondStore)
	uassert.Nil(t, err)

	secondStoreFeeAmountTickSpacing := secondStore.GetFeeAmountTickSpacing()
	uassert.Equal(t, secondStoreFeeAmountTickSpacing[100], int32(1))
	uassert.Equal(t, secondStoreFeeAmountTickSpacing[500], int32(10))
	uassert.Equal(t, secondStoreFeeAmountTickSpacing[3000], int32(60))
	uassert.Equal(t, secondStoreFeeAmountTickSpacing[10000], int32(200))
}
