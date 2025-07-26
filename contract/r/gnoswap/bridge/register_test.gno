package bridge

import (
	"testing"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	_ "gno.land/r/gnoswap/v1/rbac" // initialize rbac package
)

func TestCallbackRegistration(t *testing.T) {
	callbackTree = avl.NewTree()
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	testing.SetOriginCaller(adminAddr)

	RegisterCallback(cross, "test", "add", func(a, b int) int {
		return a + b
	})

	cb, exists := LookupCallback("test", "add")
	uassert.True(t, exists)

	addFn, ok := cb.(func(int, int) int)
	uassert.True(t, ok)
	result := addFn(5, 3)
	uassert.Equal(t, result, 8)
}

func TestCallbackUpdate(t *testing.T) {
	callbackTree = avl.NewTree()
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	testing.SetOriginCaller(adminAddr)

	RegisterCallback(cross, "test", "multiply", func(a, b int) int {
		return a * b
	})

	cb, exists := LookupCallback("test", "multiply")
	uassert.True(t, exists)

	multiplyFn, ok := cb.(func(int, int) int)
	uassert.True(t, ok)
	result := multiplyFn(3, 4)
	uassert.Equal(t, result, 12) // 3 * 4 = 12

	// update callback
	UpdateCallback(cross, "test", "multiply", func(a, b int) int {
		return a * b * 2
	})

	// get callback and check the result
	cb, exists = LookupCallback("test", "multiply")
	uassert.True(t, exists)

	multiplyFn, ok = cb.(func(int, int) int)
	uassert.True(t, ok)
	result = multiplyFn(3, 4)
	uassert.Equal(t, result, 24) // 3 * 4 * 2 = 24
}

func TestCallbackRegistrationErrors(t *testing.T) {
	callbackTree = avl.NewTree()
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	testing.SetOriginCaller(adminAddr)

	// duplicate registration test
	RegisterCallback(cross, "test", "duplicate", func() {})

	uassert.AbortsWithMessage(t, "callback already registered for key: test/duplicate", func() {
		RegisterCallback(cross, "test", "duplicate", func() {})
	})

	// unauthorized user registration
	userAddr := testutils.TestAddress("user")
	testing.SetOriginCaller(userAddr)

	uassert.AbortsWithMessage(t, "unauthorized: caller g1w4ek2ujlta047h6lta047h6lta047h6lkvk347 is not admin or governance", func() {
		RegisterCallback(cross, "test", "unauthorized", func() {})
	})
}

func TestCallbackUpdateErrors(t *testing.T) {
	callbackTree = avl.NewTree()
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	testing.SetOriginCaller(adminAddr)

	uassert.AbortsWithMessage(t, "callback not found for key: test/nonexistent", func() {
		UpdateCallback(cross, "test", "nonexistent", func() {})
	})

	RegisterCallback(cross, "test", "update", func() {})

	userAddr := testutils.TestAddress("user")
	testing.SetOriginCaller(userAddr)
	uassert.AbortsWithMessage(t, "unauthorized: caller g1w4ek2ujlta047h6lta047h6lta047h6lkvk347 is not admin or governance", func() {
		UpdateCallback(cross, "test", "update", func() {})
	})
}

func TestUpgradablePattern(t *testing.T) {
	t.Run("version Management", func(t *testing.T) {
		callbackTree = avl.NewTree()
		adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
		testing.SetOriginCaller(adminAddr)

		// v1
		RegisterCallback(cross, "emission", "MintAndDistributeGns", func() uint64 {
			return 100
		})

		// v2
		UpdateCallback(cross, "emission", "MintAndDistributeGns", func() uint64 {
			return 200
		})

		// check version
		cb, exists := LookupCallback("emission", "MintAndDistributeGns")
		uassert.True(t, exists)
		fn, ok := cb.(func() uint64)
		uassert.True(t, ok)
		result := fn()
		uassert.Equal(t, result, uint64(200))
	})

	t.Run("Multiple Contract Callbacks", func(t *testing.T) {
		callbackTree = avl.NewTree()
		adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
		testing.SetOriginCaller(adminAddr)

		// Emission contract callback
			RegisterCallback(cross, "emission", "MintAndDistributeGns", func() uint64 {
				return 100
			})

		// Position contract callback
			RegisterCallback(cross, "position", "GetPosition", func(id uint64) string {
				return "position"
			})

		// check each callback is independent
		cb1, exists := LookupCallback("emission", "MintAndDistributeGns")
		uassert.True(t, exists)
		cb2, exists := LookupCallback("position", "GetPosition")
		uassert.True(t, exists)

		fn1, ok := cb1.(func() uint64)
		uassert.True(t, ok)
		fn2, ok := cb2.(func(uint64) string)
		uassert.True(t, ok)

		uassert.Equal(t, fn1(), uint64(100))
		uassert.Equal(t, fn2(1), "position")
	})

	t.Run("Rollback Scenario", func(t *testing.T) {
		callbackTree = avl.NewTree()
		adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
		testing.SetOriginCaller(adminAddr)

		// v1
		originalCallback := func() uint64 {
			return 100
		}
		
		RegisterCallback(cross, "emission", "MintAndDistributeGns", originalCallback)

		// buggy version
		UpdateCallback(cross, "emission", "MintAndDistributeGns", func() uint64 {
			panic("buggy version")
		})

		// rollback
		UpdateCallback(cross, "emission", "MintAndDistributeGns", originalCallback)

		// check rollback
		cb, exists := LookupCallback("emission", "MintAndDistributeGns")
		uassert.True(t, exists)
		fn, ok := cb.(func() uint64)
		uassert.True(t, ok)
		result := fn()
		uassert.Equal(t, result, uint64(100))
	})

	t.Run("Namespace Collision", func(t *testing.T) {
		callbackTree = avl.NewTree()
		adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
		testing.SetOriginCaller(adminAddr)

		// same namespace, different function
		RegisterCallback(cross, "emission", "func1", func() int { return 1 })
		RegisterCallback(cross, "emission", "func2", func() int { return 2 })

		// check each function is independent
		cb1, exists := LookupCallback("emission", "func1")
		uassert.True(t, exists)
		cb2, exists := LookupCallback("emission", "func2")
		uassert.True(t, exists)

		fn1, ok := cb1.(func() int)
		uassert.True(t, ok)
		fn2, ok := cb2.(func() int)
		uassert.True(t, ok)

		uassert.Equal(t, fn1(), 1)
		uassert.Equal(t, fn2(), 2)
	})
}
