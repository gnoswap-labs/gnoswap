package store

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

func TestCastToInt64(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "Success",
			verifyFn: func(t *testing.T) {
				var value any = int64(123)
				result, err := CastToInt64(value)
				uassert.NoError(t, err)
				uassert.Equal(t, int64(123), result)
			},
		},
		{
			name: "Failure_Uint64",
			verifyFn: func(t *testing.T) {
				var value any = uint64(123)
				_, err := CastToInt64(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "uint64")
			},
		},
		{
			name: "Failure_String",
			verifyFn: func(t *testing.T) {
				var value any = "123"
				_, err := CastToInt64(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "string")
			},
		},
		{
			name: "Failure_Nil",
			verifyFn: func(t *testing.T) {
				var value any = nil
				_, err := CastToInt64(value)
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.verifyFn(t)
		})
	}
}

func TestCastToUint64(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "Success",
			verifyFn: func(t *testing.T) {
				var value any = uint64(456)
				result, err := CastToUint64(value)
				uassert.NoError(t, err)
				uassert.Equal(t, uint64(456), result)
			},
		},
		{
			name: "Failure_Int64",
			verifyFn: func(t *testing.T) {
				var value any = int64(456)
				_, err := CastToUint64(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "int64")
			},
		},
		{
			name: "Failure_String",
			verifyFn: func(t *testing.T) {
				var value any = "456"
				_, err := CastToUint64(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "string")
			},
		},
		{
			name: "Failure_Nil",
			verifyFn: func(t *testing.T) {
				var value any = nil
				_, err := CastToUint64(value)
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.verifyFn(t)
		})
	}
}

func TestCastToBool(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "Success_True",
			verifyFn: func(t *testing.T) {
				var value any = true
				result, err := CastToBool(value)
				uassert.NoError(t, err)
				uassert.True(t, result, "result should be true")
			},
		},
		{
			name: "Success_False",
			verifyFn: func(t *testing.T) {
				var value any = false
				result, err := CastToBool(value)
				uassert.NoError(t, err)
				uassert.False(t, result, "result should be false")
			},
		},
		{
			name: "Failure_Int",
			verifyFn: func(t *testing.T) {
				var value any = 1
				_, err := CastToBool(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "int")
			},
		},
		{
			name: "Failure_String",
			verifyFn: func(t *testing.T) {
				var value any = "true"
				_, err := CastToBool(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "string")
			},
		},
		{
			name: "Failure_Nil",
			verifyFn: func(t *testing.T) {
				var value any = nil
				_, err := CastToBool(value)
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.verifyFn(t)
		})
	}
}

func TestCastToString(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "Success",
			verifyFn: func(t *testing.T) {
				var value any = "test string"
				result, err := CastToString(value)
				uassert.NoError(t, err)
				uassert.Equal(t, "test string", result)
			},
		},
		{
			name: "Success_EmptyString",
			verifyFn: func(t *testing.T) {
				var value any = ""
				result, err := CastToString(value)
				uassert.NoError(t, err)
				uassert.Equal(t, "", result)
			},
		},
		{
			name: "Failure_Int",
			verifyFn: func(t *testing.T) {
				var value any = 123
				_, err := CastToString(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "int")
			},
		},
		{
			name: "Failure_Nil",
			verifyFn: func(t *testing.T) {
				var value any = nil
				_, err := CastToString(value)
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.verifyFn(t)
		})
	}
}

func TestCastToAddress(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "Success",
			verifyFn: func(t *testing.T) {
				addr := testutils.TestAddress("test")
				var value any = addr
				result, err := CastToAddress(value)
				uassert.NoError(t, err)
				uassert.Equal(t, addr, result)
			},
		},
		{
			name: "Failure_String",
			verifyFn: func(t *testing.T) {
				var value any = "g1test"
				_, err := CastToAddress(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "string")
			},
		},
		{
			name: "Failure_Nil",
			verifyFn: func(t *testing.T) {
				var value any = nil
				_, err := CastToAddress(value)
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.verifyFn(t)
		})
	}
}

func TestCastToTree(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "Success",
			verifyFn: func(t *testing.T) {
				tree := avl.NewTree()
				var value any = tree
				result, err := CastToTree(value)
				uassert.NoError(t, err)
				uassert.NotEqual(t, nil, result)
			},
		},
		{
			name: "Failure_String",
			verifyFn: func(t *testing.T) {
				var value any = "not a tree"
				_, err := CastToTree(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "string")
			},
		},
		{
			name: "Failure_Map",
			verifyFn: func(t *testing.T) {
				var value any = make(map[string]string)
				_, err := CastToTree(value)
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
		{
			name: "Failure_Nil",
			verifyFn: func(t *testing.T) {
				var value any = nil
				_, err := CastToTree(value)
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tc.verifyFn(t)
		})
	}
}
