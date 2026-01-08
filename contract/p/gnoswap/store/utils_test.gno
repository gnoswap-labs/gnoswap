package store

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

func TestcastToInt64(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "Success",
			verifyFn: func(t *testing.T) {
				var value any = int64(123)
				result, err := castToInt64(value)
				uassert.NoError(t, err)
				uassert.Equal(t, int64(123), result)
			},
		},
		{
			name: "Failure_Uint64",
			verifyFn: func(t *testing.T) {
				var value any = uint64(123)
				_, err := castToInt64(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "uint64")
			},
		},
		{
			name: "Failure_String",
			verifyFn: func(t *testing.T) {
				var value any = "123"
				_, err := castToInt64(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "string")
			},
		},
		{
			name: "Failure_Nil",
			verifyFn: func(t *testing.T) {
				var value any = nil
				_, err := castToInt64(value)
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

func TestcastToUint64(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "Success",
			verifyFn: func(t *testing.T) {
				var value any = uint64(456)
				result, err := castToUint64(value)
				uassert.NoError(t, err)
				uassert.Equal(t, uint64(456), result)
			},
		},
		{
			name: "Failure_Int64",
			verifyFn: func(t *testing.T) {
				var value any = int64(456)
				_, err := castToUint64(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "int64")
			},
		},
		{
			name: "Failure_String",
			verifyFn: func(t *testing.T) {
				var value any = "456"
				_, err := castToUint64(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "string")
			},
		},
		{
			name: "Failure_Nil",
			verifyFn: func(t *testing.T) {
				var value any = nil
				_, err := castToUint64(value)
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

func TestcastToBool(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "Success_True",
			verifyFn: func(t *testing.T) {
				var value any = true
				result, err := castToBool(value)
				uassert.NoError(t, err)
				uassert.True(t, result, "result should be true")
			},
		},
		{
			name: "Success_False",
			verifyFn: func(t *testing.T) {
				var value any = false
				result, err := castToBool(value)
				uassert.NoError(t, err)
				uassert.False(t, result, "result should be false")
			},
		},
		{
			name: "Failure_Int",
			verifyFn: func(t *testing.T) {
				var value any = 1
				_, err := castToBool(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "int")
			},
		},
		{
			name: "Failure_String",
			verifyFn: func(t *testing.T) {
				var value any = "true"
				_, err := castToBool(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "string")
			},
		},
		{
			name: "Failure_Nil",
			verifyFn: func(t *testing.T) {
				var value any = nil
				_, err := castToBool(value)
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

func TestcastToString(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "Success",
			verifyFn: func(t *testing.T) {
				var value any = "test string"
				result, err := castToString(value)
				uassert.NoError(t, err)
				uassert.Equal(t, "test string", result)
			},
		},
		{
			name: "Success_EmptyString",
			verifyFn: func(t *testing.T) {
				var value any = ""
				result, err := castToString(value)
				uassert.NoError(t, err)
				uassert.Equal(t, "", result)
			},
		},
		{
			name: "Failure_Int",
			verifyFn: func(t *testing.T) {
				var value any = 123
				_, err := castToString(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "int")
			},
		},
		{
			name: "Failure_Nil",
			verifyFn: func(t *testing.T) {
				var value any = nil
				_, err := castToString(value)
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

func TestcastToAddress(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "Success",
			verifyFn: func(t *testing.T) {
				addr := testutils.TestAddress("test")
				var value any = addr
				result, err := castToAddress(value)
				uassert.NoError(t, err)
				uassert.Equal(t, addr, result)
			},
		},
		{
			name: "Failure_String",
			verifyFn: func(t *testing.T) {
				var value any = "g1test"
				_, err := castToAddress(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "string")
			},
		},
		{
			name: "Failure_Nil",
			verifyFn: func(t *testing.T) {
				var value any = nil
				_, err := castToAddress(value)
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

func TestcastToTree(t *testing.T) {
	testCases := []struct {
		name     string
		verifyFn func(*testing.T)
	}{
		{
			name: "Success",
			verifyFn: func(t *testing.T) {
				tree := avl.NewTree()
				var value any = tree
				result, err := castToTree(value)
				uassert.NoError(t, err)
				uassert.NotEqual(t, nil, result)
			},
		},
		{
			name: "Failure_String",
			verifyFn: func(t *testing.T) {
				var value any = "not a tree"
				_, err := castToTree(value)
				uassert.ErrorContains(t, err, "failed to cast")
				uassert.ErrorContains(t, err, "string")
			},
		},
		{
			name: "Failure_Map",
			verifyFn: func(t *testing.T) {
				var value any = make(map[string]string)
				_, err := castToTree(value)
				uassert.ErrorContains(t, err, "failed to cast")
			},
		},
		{
			name: "Failure_Nil",
			verifyFn: func(t *testing.T) {
				var value any = nil
				_, err := castToTree(value)
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
