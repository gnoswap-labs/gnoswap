package common

import (
	"chain/runtime/unsafe"
	"errors"
)

func (m *MockGrc20regCommon) ValidateNotHandleNativeCoin() error {
	if len(unsafe.OriginSend()) > 0 {
		return errors.New("[GNOSWAP-COMMON-002] handle native coin is not allowed")
	}
	return nil
}
