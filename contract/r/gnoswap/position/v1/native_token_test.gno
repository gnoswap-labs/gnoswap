package v1

import (
	"strconv"
	"testing"

	"gno.land/p/nt/uassert"
)

func TestIsNative(t *testing.T) {
	tests := []struct {
		name     string
		token    string
		expected bool
	}{
		{
			name:     "isNative is success by native token",
			token:    "ugnot",
			expected: true,
		},
		{
			name:     "isNative is failed by non-native token",
			token:    "usdt",
			expected: false,
		},
		{
			name:     "isNative is failed by empty token",
			token:    "",
			expected: false,
		},
		{
			name:     "isNative is failed by similar but different token",
			token:    "GNOT",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isNative(tt.token)
			uassert.Equal(t, tt.expected, result, "Unexpected result for token: "+tt.token)
		})
	}
}

func TestIsWrappedToken(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
		expected  bool
	}{
		{
			name:      "isWrappedToken is success by wrapped UGNOT",
			tokenPath: WUGNOT_PATH,
			expected:  true,
		},
		{
			name:      "isWrappedToken is failed by non-wrapped UGNOT",
			tokenPath: "gno.land/r/demo/ugnot",
			expected:  false,
		},
		{
			name:      "isWrappedToken is failed by empty tokenPath",
			tokenPath: "",
			expected:  false,
		},
		{
			name:      "isWrappedToken is failed by similar but different tokenPath",
			tokenPath: "gno.land/r/gnolands/wugnot",
			expected:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isWrappedToken(tt.tokenPath)
			if result != tt.expected {
				t.Errorf(
					"expected %s but got %s",
					strconv.FormatBool(tt.expected),
					strconv.FormatBool(result),
				)
			}
		})
	}
}

