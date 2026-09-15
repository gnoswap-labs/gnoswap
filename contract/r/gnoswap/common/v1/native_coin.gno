package common

import (
	"chain/runtime/unsafe"
	"errors"
)

// ValidateNotHandleNativeCoin rejects calls that include native coins in the
// transaction's origin send data; it returns nil when no native coin is attached.
//
// Returns:
//   - error: non-nil when the call attempts to send native coins; nil otherwise
func (c *commonV1) ValidateNotHandleNativeCoin() error {
	if len(unsafe.OriginSend()) > 0 {
		return errors.New(errNotHandleNativeCoin)
	}

	return nil
}
