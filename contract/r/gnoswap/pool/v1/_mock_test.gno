package v1

import (
	"gno.land/r/gnoswap/mock"
)

func newMockPosition() *poolV1 {
	return &poolV1{store: mock.NewMockPoolStore()}
}
