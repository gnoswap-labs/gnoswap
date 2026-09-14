package common

import (
	"chain/runtime/unsafe"
	"errors"
)

func (c *commonV1) ValidateNotHandleNativeCoin() error {
	if len(unsafe.OriginSend()) > 0 {
		return errors.New(errNotHandleNativeCoin)
	}

	return nil
}
