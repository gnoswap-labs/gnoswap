package bridge

import (
	"testing"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/r/gnoswap/v1/access"
)

func TestVariousFunctionCallbacks(t *testing.T) {
	callbackTree = avl.NewTree()

	tests := []struct {
		name     string
		key      string
		callback any
		args     []any
		want     any
		wantErr  bool
	}{
		{
			name: "Simple addition function",
			key:  "test/add",
			callback: func(a, b int) int {
				return a + b
			},
			args: []any{5, 3},
			want: 8,
		},
		{
			name: "String concatenation",
			key:  "test/concat",
			callback: func(a, b string) string {
				return a + b
			},
			args: []any{"Hello, ", "World"},
			want: "Hello, World",
		},
		{
			name: "No arguments function",
			key:  "test/constant",
			callback: func() int {
				return 42
			},
			args: []any{},
			want: 42,
		},
		{
			name: "Multiple return values",
			key:  "test/divide",
			callback: func(a, b int) (int, bool) {
				if b == 0 {
					return 0, false
				}
				return a / b, true
			},
			args: []any{10, 2},
			want: [2]any{5, true},
		},
		{
			name: "Function with slice argument",
			key:  "test/sum",
			callback: func(numbers []int) int {
				sum := 0
				for _, n := range numbers {
					sum += n
				}
				return sum
			},
			args: []any{[]int{1, 2, 3, 4, 5}},
			want: 15,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			RegisterCallback(tt.key, tt.callback)

			cb, exists := GetCallback(tt.key)
			uassert.True(t, exists)

			switch fn := cb.(type) {
			case func(int, int) int:
				if len(tt.args) == 2 {
					result := fn(tt.args[0].(int), tt.args[1].(int))
					uassert.Equal(t, result, tt.want)
				}
			case func(string, string) string:
				if len(tt.args) == 2 {
					result := fn(tt.args[0].(string), tt.args[1].(string))
					uassert.Equal(t, result, tt.want)
				}
			case func() int:
				result := fn()
				uassert.Equal(t, result, tt.want)
			case func(int, int) (int, bool):
				if len(tt.args) == 2 {
					quotient, ok := fn(tt.args[0].(int), tt.args[1].(int))
					expected := tt.want.([2]any)
					if quotient != expected[0].(int) || ok != expected[1].(bool) {
						t.Errorf("got (%v, %v), want (%v, %v)",
							quotient, ok, expected[0], expected[1])
					}
				}
			case func([]int) int:
				if len(tt.args) == 1 {
					result := fn(tt.args[0].([]int))
					uassert.Equal(t, result, tt.want)
				}
			default:
				t.Errorf("Unexpected function type for %s", tt.name)
			}
		})
	}
}

func TestDuplicateCallback(t *testing.T) {
	callbackTree = avl.NewTree()

	key := "test/duplicate"
	RegisterCallback(key, func() {})

	defer func() {
		if r := recover(); r == nil {
			t.Error("Expected panic on duplicate registration")
		}
	}()

	RegisterCallback(key, func() {})
}

func TestNonExistentCallback(t *testing.T) {
	callbackTree = avl.NewTree()

	_, exists := GetCallback("non/existent/key")
	uassert.False(t, exists)
}

func TestCallbackRegistration2(t *testing.T) {
	callbackTree = avl.NewTree()
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)

	err := RegisterCallback2(adminAddr, "test", "add", func(a, b int) int {
		return a + b
	})
	uassert.NoError(t, err)

	cb, exists := GetCallback2("test", "add")
	uassert.True(t, exists)

	addFn, ok := cb.(func(int, int) int)
	uassert.True(t, ok)
	result := addFn(5, 3)
	uassert.Equal(t, result, 8)
}

func TestCallbackUpdate(t *testing.T) {
	callbackTree = avl.NewTree()

	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)

	err := RegisterCallback2(adminAddr, "test", "multiply", func(a, b int) int {
		return a * b
	})
	uassert.NoError(t, err)

	cb, exists := GetCallback2("test", "multiply")
	uassert.True(t, exists)

	multiplyFn, ok := cb.(func(int, int) int)
	uassert.True(t, ok)
	result := multiplyFn(3, 4)
	uassert.Equal(t, result, 12) // 3 * 4 = 12

	// update callback
	err = UpdateCallback(adminAddr, "test", "multiply", func(a, b int) int {
		return a * b * 2
	})
	uassert.NoError(t, err)

	// get callback and check the result
	cb, exists = GetCallback2("test", "multiply")
	uassert.True(t, exists)

	multiplyFn, ok = cb.(func(int, int) int)
	uassert.True(t, ok)
	result = multiplyFn(3, 4)
	uassert.Equal(t, result, 24) // 3 * 4 * 2 = 24
}

func TestCallbackRegistrationErrors(t *testing.T) {
	callbackTree = avl.NewTree()
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	userAddr := testutils.TestAddress("user")

	// duplicate registration test
	err := RegisterCallback2(adminAddr, "test", "duplicate", func() {})
	uassert.NoError(t, err)

	err = RegisterCallback2(adminAddr, "test", "duplicate", func() {})
	uassert.Error(t, err)

	// unauthorized user registration test
	err = RegisterCallback2(userAddr, "test", "unauthorized", func() {})
	uassert.Error(t, err)
}

func TestCallbackUpdateErrors(t *testing.T) {
	callbackTree = avl.NewTree()
	adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)
	userAddr := testutils.TestAddress("user2")

	err := UpdateCallback(adminAddr, "test", "nonexistent", func() {})
	uassert.Error(t, err)

	err = RegisterCallback2(adminAddr, "test", "update", func() {})
	uassert.NoError(t, err)

	err = UpdateCallback(userAddr, "test", "update", func() {})
	uassert.Error(t, err)
}

func TestUpgradablePattern(t *testing.T) {
	t.Run("version Management", func(t *testing.T) {
		callbackTree = avl.NewTree()
		adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)

		// v1
		err := RegisterCallback2(adminAddr, "emission", "MintAndDistributeGns", func() uint64 {
			return 100
		})
		uassert.NoError(t, err)

		// v2
		err = UpdateCallback(adminAddr, "emission", "MintAndDistributeGns", func() uint64 {
			return 200
		})
		uassert.NoError(t, err)

		// check version
		cb, exists := GetCallback2("emission", "MintAndDistributeGns")
		uassert.True(t, exists)
		fn, ok := cb.(func() uint64)
		uassert.True(t, ok)
		result := fn()
		uassert.Equal(t, result, uint64(200))
	})

	t.Run("Multiple Contract Callbacks", func(t *testing.T) {
		callbackTree = avl.NewTree()
		adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)

		// Emission contract callback
		err := RegisterCallback2(adminAddr, "emission", "MintAndDistributeGns", func() uint64 {
			return 100
		})
		uassert.NoError(t, err)

		// Position contract callback
		err = RegisterCallback2(adminAddr, "position", "GetPosition", func(id uint64) string {
			return "position"
		})
		uassert.NoError(t, err)

		// check each callback is independent
		cb1, exists := GetCallback2("emission", "MintAndDistributeGns")
		uassert.True(t, exists)
		cb2, exists := GetCallback2("position", "GetPosition")
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
		adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)

		// v1
		originalCallback := func() uint64 {
			return 100
		}
		err := RegisterCallback2(adminAddr, "emission", "MintAndDistributeGns", originalCallback)
		uassert.NoError(t, err)

		// buggy version
		err = UpdateCallback(adminAddr, "emission", "MintAndDistributeGns", func() uint64 {
			panic("buggy version")
		})
		uassert.NoError(t, err)

		// rollback
		err = UpdateCallback(adminAddr, "emission", "MintAndDistributeGns", originalCallback)
		uassert.NoError(t, err)

		// check rollback
		cb, exists := GetCallback2("emission", "MintAndDistributeGns")
		uassert.True(t, exists)
		fn, ok := cb.(func() uint64)
		uassert.True(t, ok)
		result := fn()
		uassert.Equal(t, result, uint64(100))
	})

	t.Run("Namespace Collision", func(t *testing.T) {
		callbackTree = avl.NewTree()
		adminAddr, _ := access.GetAddress(access.ROLE_ADMIN)

		// same namespace, different function
		err := RegisterCallback2(adminAddr, "emission", "func1", func() int { return 1 })
		uassert.NoError(t, err)
		err = RegisterCallback2(adminAddr, "emission", "func2", func() int { return 2 })
		uassert.NoError(t, err)

		// check each function is independent
		cb1, exists := GetCallback2("emission", "func1")
		uassert.True(t, exists)
		cb2, exists := GetCallback2("emission", "func2")
		uassert.True(t, exists)

		fn1, ok := cb1.(func() int)
		uassert.True(t, ok)
		fn2, ok := cb2.(func() int)
		uassert.True(t, ok)

		uassert.Equal(t, fn1(), 1)
		uassert.Equal(t, fn2(), 2)
	})
}
