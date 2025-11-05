package v1

import (
	"testing"

	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/governance"
)

// TestInit_formatConfigKey tests the private formatConfigKey function
func TestInit_formatConfigKey(t *testing.T) {
	tests := []struct {
		name     string
		version  int64
		expected string
	}{
		{
			name:     "format positive version",
			version:  1,
			expected: "1",
		},
		{
			name:     "format zero version",
			version:  0,
			expected: "0",
		},
		{
			name:     "format large version",
			version:  9223372036854775807, // max int64
			expected: "9223372036854775807",
		},
		{
			name:     "format negative version",
			version:  -1,
			expected: "-1",
		},
		{
			name:     "format version 100",
			version:  100,
			expected: "100",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// when
			result := formatConfigKey(tt.version)

			// then
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// TestInit_initStoreData tests the private initStoreData function
func TestInit_initStoreData(t *testing.T) {
	tests := []struct {
		name              string
		setupStore        func() governance.IGovernanceStore
		expectedError     bool
		verifyStore       func(*testing.T, governance.IGovernanceStore)
	}{
		{
			name: "success - initialize empty store",
			setupStore: func() governance.IGovernanceStore {
				// Create completely empty store (not initialized)
				return &mockGovernanceStore{}
			},
			expectedError: false,
			verifyStore: func(t *testing.T, store governance.IGovernanceStore) {
				// Verify config counter exists
				uassert.True(t, store.HasConfigCounterStoreKey())
				counter := store.GetConfigCounter()
				uassert.NotNil(t, counter)

				// Verify proposal counter exists
				uassert.True(t, store.HasProposalCounterStoreKey())
				proposalCounter := store.GetProposalCounter()
				uassert.NotNil(t, proposalCounter)

				// Verify configs tree exists
				uassert.True(t, store.HasConfigsStoreKey())

				// Verify default config is set at version 1
				// initStoreData calls Next() which increments from 0 to 1
				_, exists := store.GetConfig(1)
				uassert.True(t, exists)

				// Verify proposals tree exists
				uassert.True(t, store.HasProposalsStoreKey())

				// Verify proposal user voting infos tree exists
				uassert.True(t, store.HasProposalUserVotingInfosStoreKey())
				votingInfosTree := store.GetProposalUserVotingInfos()
				uassert.NotNil(t, votingInfosTree)

				// Verify user proposals tree exists
				uassert.True(t, store.HasUserProposalsStoreKey())
			},
		},
		{
			name: "success - idempotent initialization (already initialized)",
			setupStore: func() governance.IGovernanceStore {
				store := createMockGovernanceStore()
				// Pre-initialize store
				err := initStoreData(store)
				if err != nil {
					panic(err)
				}
				return store
			},
			expectedError: false,
			verifyStore: func(t *testing.T, store governance.IGovernanceStore) {
				// Should still have all data
				uassert.True(t, store.HasConfigCounterStoreKey())
				uassert.True(t, store.HasProposalCounterStoreKey())
				uassert.True(t, store.HasConfigsStoreKey())
				uassert.True(t, store.HasProposalsStoreKey())
				uassert.True(t, store.HasProposalUserVotingInfosStoreKey())
				uassert.True(t, store.HasUserProposalsStoreKey())
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			store := tt.setupStore()

			// when
			err := initStoreData(store)

			// then
			if tt.expectedError {
				uassert.NotNil(t, err)
			} else {
				uassert.Nil(t, err)
				if tt.verifyStore != nil {
					tt.verifyStore(t, store)
				}
			}
		})
	}
}
