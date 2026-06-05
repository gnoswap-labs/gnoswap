package position

import "errors"

var ErrSpoofedRealm = errors.New("rlm does not match the current crossing frame")
