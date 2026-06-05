package staker

import "errors"

// ErrSpoofedRealm is returned by store Set* methods when the supplied realm
// token does not match the current crossing frame (rlm.IsCurrent() is false),
// rejecting spoofed or stale realm tokens before any write is performed.
var ErrSpoofedRealm = errors.New("rlm does not match the current crossing frame")
