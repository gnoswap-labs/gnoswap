package v1

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
	"gno.land/p/onbloc/json"
	u256 "gno.land/p/gnoswap/uint256"
)

// TestFormatUint tests uint64 formatting
func TestFormatUint(t *testing.T) {
	tests := []struct {
		name     string
		input    uint64
		expected string
	}{
		{
			name:     "Format zero",
			input:    0,
			expected: "0",
		},
		{
			name:     "Format positive number",
			input:    12345,
			expected: "12345",
		},
		{
			name:     "Format large number",
			input:    18446744073709551615, // max uint64
			expected: "18446744073709551615",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := formatUint(tc.input)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

// TestFormatInt tests int64 formatting
func TestFormatInt(t *testing.T) {
	tests := []struct {
		name     string
		input    int64
		expected string
	}{
		{
			name:     "Format zero",
			input:    0,
			expected: "0",
		},
		{
			name:     "Format positive number",
			input:    12345,
			expected: "12345",
		},
		{
			name:     "Format negative number",
			input:    -12345,
			expected: "-12345",
		},
		{
			name:     "Format max int64",
			input:    9223372036854775807,
			expected: "9223372036854775807",
		},
		{
			name:     "Format min int64",
			input:    -9223372036854775808,
			expected: "-9223372036854775808",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := formatInt(tc.input)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

// TestB64Encode tests base64 encoding
func TestB64Encode(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "Encode simple string",
			input:    "hello",
			expected: "aGVsbG8=",
		},
		{
			name:     "Encode empty string",
			input:    "",
			expected: "",
		},
		{
			name:     "Encode complex string",
			input:    "Hello, World!",
			expected: "SGVsbG8sIFdvcmxkIQ==",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := b64Encode(tc.input)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

// TestUtil_marshal tests JSON marshalling
func TestUtil_marshal(t *testing.T) {
	tests := []struct {
		name     string
		setup    func() *json.Node
		expected string
	}{
		{
			name: "marshal simple object",
			setup: func() *json.Node {
				return json.Builder().
					WriteString("key1", "value1").
					WriteString("key2", "value2").
					Node()
			},
			expected: `{"key1":"value1","key2":"value2"}`,
		},
		{
			name: "marshal with numbers",
			setup: func() *json.Node {
				return json.Builder().
					WriteString("count", "123").
					WriteString("price", "456").
					Node()
			},
			expected: `{"count":"123","price":"456"}`,
		},
		{
			name: "marshal empty object",
			setup: func() *json.Node {
				return json.Builder().Node()
			},
			expected: `{}`,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			data := tc.setup()

			// when
			result := marshal(data)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

// TestUtil_getUint64FromTree tests retrieving uint64 from AVL tree
func TestUtil_getUint64FromTree(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func() (*avl.Tree, string)
		expected             uint64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name: "get existing value",
			setup: func() (*avl.Tree, string) {
				tree := avl.NewTree()
				tree.Set("key1", uint64(12345))
				return tree, "key1"
			},
			expected: 12345,
		},
		{
			name: "get non-existent value returns zero",
			setup: func() (*avl.Tree, string) {
				tree := avl.NewTree()
				return tree, "nonexistent"
			},
			expected: 0,
		},
		{
			name: "get zero value",
			setup: func() (*avl.Tree, string) {
				tree := avl.NewTree()
				tree.Set("key1", uint64(0))
				return tree, "key1"
			},
			expected: 0,
		},
		{
		    name: "panics on wrong type",
			setup: func() (*avl.Tree, string) {
			    tree := avl.NewTree()
				tree.Set("key1", int64(100)) // Wrong type (int64 instead of uint64)
				return tree, "key1"
			},
			expectedHasPanic:     true,
            expectedPanicMessage: "failed to cast value to uint64: int64",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			tree, key := tc.setup()

			// when/then
			if tc.expectedHasPanic {
                uassert.PanicsWithMessage(t, tc.expectedPanicMessage, func() {
                    getUint64FromTree(tree, key)
                })
            } else {
                result := getUint64FromTree(tree, key)
                uassert.Equal(t, result, tc.expected)
            }
		})
	}
}

// TestUtil_updateUint64InTree tests updating uint64 in AVL tree
func TestUtil_updateUint64InTree(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func() (*avl.Tree, string, uint64, bool)
		expected             uint64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name: "add to existing value",
			setup: func() (*avl.Tree, string, uint64, bool) {
				tree := avl.NewTree()
				tree.Set("key1", uint64(100))
				return tree, "key1", 50, true
			},
			expected: 150,
		},
		{
			name: "add to non-existent value",
			setup: func() (*avl.Tree, string, uint64, bool) {
				tree := avl.NewTree()
				return tree, "key1", 100, true
			},
			expected: 100,
		},
		{
			name: "subtract from existing value",
			setup: func() (*avl.Tree, string, uint64, bool) {
				tree := avl.NewTree()
				tree.Set("key1", uint64(100))
				return tree, "key1", 50, false
			},
			expected: 50,
		},
		{
			name: "subtract to zero",
			setup: func() (*avl.Tree, string, uint64, bool) {
				tree := avl.NewTree()
				tree.Set("key1", uint64(100))
				return tree, "key1", 100, false
			},
			expected: 0,
		},
		{
			name: "update with zero delta",
			setup: func() (*avl.Tree, string, uint64, bool) {
				tree := avl.NewTree()
				tree.Set("key1", uint64(100))
				return tree, "key1", 0, true
			},
			expected: 100, // Should remain unchanged
		},
		{
			name: "overflow on add",
			setup: func() (*avl.Tree, string, uint64, bool) {
				tree := avl.NewTree()
				maxUint64 := uint64(18446744073709551615)
				tree.Set("key1", maxUint64-1)
				return tree, "key1", 10, true
			},
			expected: 8, // Wrapped around: (max-1) + 10 = 8
		},
		{
		    name: "panics on insufficient balance",
			setup: func() (*avl.Tree, string, uint64, bool) {
                tree := avl.NewTree()
                tree.Set("key1", uint64(50))
                return tree, "key1", 100, false
			},
			expectedHasPanic:     true,
            expectedPanicMessage: "[GNOSWAP-GOV_STAKER-010] not enough balance || not enough balance: current(50) < requested(100)",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			tree, key, delta, add := tc.setup()

			// when/then
			if tc.expectedHasPanic {
                uassert.PanicsWithMessage(t, tc.expectedPanicMessage, func() {
                    updateUint64InTree(tree, key, delta, add)
                })
            } else {
			    result := updateUint64InTree(tree, key, delta, add)
				uassert.Equal(t, result, tc.expected)
		    }
		})
	}
}

// TestUtil_getOrCreateInnerTree tests getting or creating inner AVL tree
func TestUtil_getOrCreateInnerTree(t *testing.T) {
	tests := []struct {
		name                 string
		setup                func() (*avl.Tree, string)
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name: "create new inner tree",
			setup: func() (*avl.Tree, string) {
				tree := avl.NewTree()
				return tree, "key1"
			},
		},
		{
			name: "get existing inner tree",
			setup: func() (*avl.Tree, string) {
				tree := avl.NewTree()
				innerTree := avl.NewTree()
				innerTree.Set("innerKey", "innerValue")
				tree.Set("key1", innerTree)
				return tree, "key1"
			},
		},
		{
		    name: "panics on wrong type",
            setup: func() (*avl.Tree, string) {
                tree := avl.NewTree()
                tree.Set("key1", uint64(100)) // Wrong type (uint64 instead of *avl.Tree)
                return tree, "key1"
            },
            expectedHasPanic:     true,
            expectedPanicMessage: "failed to cast value to *avl.Tree: uint64",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			tree, key := tc.setup()

			// when/then
			if tc.expectedHasPanic {
                uassert.PanicsWithMessage(t, "failed to cast value to *avl.Tree: uint64", func() {
    				getOrCreateInnerTree(tree, "key1")
    			})
			} else {
			    innerTree := getOrCreateInnerTree(tree, key)

                if innerTree == nil {
                    t.Errorf("innerTree should not be nil")
                }

                retrieved := getOrCreateInnerTree(tree, key)
                if retrieved != innerTree {
                    t.Errorf("retrieved tree should be the same instance as innerTree")
                }
			}
		})
	}
}

// TestUtil_milliToSec tests milliseconds to seconds conversion
func TestUtil_milliToSec(t *testing.T) {
	tests := []struct {
		name     string
		input    int64
		expected int64
	}{
		{
			name:     "convert 1000ms to 1s",
			input:    1000,
			expected: 1,
		},
		{
			name:     "convert 5000ms to 5s",
			input:    5000,
			expected: 5,
		},
		{
			name:     "convert 0ms to 0s",
			input:    0,
			expected: 0,
		},
		{
			name:     "convert 999ms to 0s (truncate)",
			input:    999,
			expected: 0,
		},
		{
			name:     "convert 1500ms to 1s (truncate)",
			input:    1500,
			expected: 1,
		},
		{
			name:     "convert negative milliseconds",
			input:    -1000,
			expected: -1,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := milliToSec(tc.input)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

// TestUtil_safeConvertToInt64 tests safe conversion from uint256 to int64
func TestUtil_safeConvertToInt64(t *testing.T) {
	tests := []struct {
		name                 string
		input                *u256.Uint
		expected             int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:     "convert zero",
			input:    u256.Zero(),
			expected: 0,
		},
		{
			name:     "convert small value",
			input:    u256.NewUint(12345),
			expected: 12345,
		},
		{
			name:     "convert max int64",
			input:    u256.NewUint(9223372036854775807),
			expected: 9223372036854775807,
		},
		{
			name:     "convert boundary - int64 max minus 1",
			input:    u256.NewUint(9223372036854775806),
			expected: 9223372036854775806,
		},
		{
		    name: "panics on overflow - int64 max + 1",
			input:    u256.NewUint(9223372036854775808), // int64 max + 1
			expectedHasPanic:     true,
			expectedPanicMessage: "amount(9223372036854775808) overflows int64 range (max 9223372036854775807)",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {

		    // when/then
		    if tc.expectedHasPanic {
                uassert.PanicsWithMessage(t, tc.expectedPanicMessage, func() {
                    safeConvertToInt64(tc.input)
                })
            } else {
                result := safeConvertToInt64(tc.input)
                uassert.Equal(t, result, tc.expected)
            }
		})
	}
}
