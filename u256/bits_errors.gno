// Copyright 2019 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !compiler_bootstrap

package u256

import (
	"errors"
)

//go:linkname overflowError runtime.overflowError
var overflowError error = errors.New("u256: integer overflow")

//go:linkname divideError runtime.divideError
var divideError error = errors.New("u256: integer divide by zero")