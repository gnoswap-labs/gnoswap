package staker

import (
	"testing"
)

func TestGetPoolsWithTier(t *testing.T) {
	poolTiers = newPoolTiers()

	tests := []struct {
		name     string
		setup    func()
		expected []string
	}{
		{
			name: "empty pool list",
			setup: func() {
				poolTiers = newPoolTiers()
			},
			expected: []string{},
		},
		{
			name: "single pool",
			setup: func() {
				poolTiers = newPoolTiers()
				poolTiers.Set("pool1", InternalTier{tier: 1})
			},
			expected: []string{"pool1_1"},
		},
		{
			name: "multiple pools",
			setup: func() {
				poolTiers = newPoolTiers()
				poolTiers.Set("pool1", InternalTier{tier: 1})
				poolTiers.Set("pool2", InternalTier{tier: 2})
				poolTiers.Set("pool3", InternalTier{tier: 3})
			},
			expected: []string{"pool1_1", "pool2_2", "pool3_3"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.setup()
			result := GetPoolsWithTier()

			if len(result) != len(tt.expected) {
				t.Errorf("expected length %d, actual length %d", len(tt.expected), len(result))
				return
			}

			resultMap := make(map[string]bool)
			for _, r := range result {
				resultMap[r] = true
			}

			for _, expected := range tt.expected {
				if !resultMap[expected] {
					t.Errorf("expected item %s not found in result", expected)
				}
			}
		})
	}
}
