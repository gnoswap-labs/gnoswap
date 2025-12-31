package gnft

import (
	"testing"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/uassert"
)

func TestAssert_assertIsValidTokenURI(t *testing.T) {
	resetObject(t)
	testing.SetRealm(positionRealm)

	ownerAddress := owner.Owner()

	// Mint a token without URI (using nft.Mint directly)
	tokenID1 := tid(1)
	checkErr(nft.Mint(ownerAddress, tokenID1))

	// Mint a token and set URI
	tokenID2 := tid(2)
	checkErr(nft.Mint(ownerAddress, tokenID2))
	SetTokenURI(cross, tokenID2, "ipfs://example")

	tests := []struct {
		name        string
		tid         grc721.TokenID
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "Token without URI should not panic",
			tid:         tokenID1,
			shouldPanic: false,
		},
		{
			name:        "Token with URI already set should panic",
			tid:         tokenID2,
			shouldPanic: true,
			expectedMsg: "[GNOSWAP-GNFT-001] cannot set URI || token id (2) has already set URI",
		},
		{
			name:        "Non-existent token should not panic (empty URI)",
			tid:         tid(999),
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					assertIsValidTokenURI(tt.tid)
				})
			} else {
				assertIsValidTokenURI(tt.tid)
			}
		})
	}
}

func TestAssert_assertIsValidAddress(t *testing.T) {
	tests := []struct {
		name        string
		addr        address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "Valid address should not panic",
			addr:        addr01,
			shouldPanic: false,
		},
		{
			name:        "Another valid address should not panic",
			addr:        addr02,
			shouldPanic: false,
		},
		{
			name:        "Empty address should panic",
			addr:        address(""),
			shouldPanic: true,
			expectedMsg: "[GNOSWAP-GNFT-002] invalid address || address ()",
		},
		{
			name:        "Invalid address format should panic",
			addr:        address("invalid"),
			shouldPanic: true,
			expectedMsg: "[GNOSWAP-GNFT-002] invalid address || address (invalid)",
		},
		{
			name:        "Malformed address should panic",
			addr:        address("g1"),
			shouldPanic: true,
			expectedMsg: "[GNOSWAP-GNFT-002] invalid address || address (g1)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					assertIsValidAddress(tt.addr)
				})
			} else {
				assertIsValidAddress(tt.addr)
			}
		})
	}
}

func TestAssert_assertFromIsValidAddress(t *testing.T) {
	tests := []struct {
		name        string
		from        address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "Valid from address should not panic",
			from:        addr01,
			shouldPanic: false,
		},
		{
			name:        "Another valid from address should not panic",
			from:        addr02,
			shouldPanic: false,
		},
		{
			name:        "Empty from address should panic",
			from:        address(""),
			shouldPanic: true,
			expectedMsg: "[GNOSWAP-GNFT-002] invalid address || from address ()",
		},
		{
			name:        "Invalid from address format should panic",
			from:        address("invalid_from"),
			shouldPanic: true,
			expectedMsg: "[GNOSWAP-GNFT-002] invalid address || from address (invalid_from)",
		},
		{
			name:        "Malformed from address should panic",
			from:        address("g1xyz"),
			shouldPanic: true,
			expectedMsg: "[GNOSWAP-GNFT-002] invalid address || from address (g1xyz)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					assertFromIsValidAddress(tt.from)
				})
			} else {
				assertFromIsValidAddress(tt.from)
			}
		})
	}
}

func TestAssert_assertToIsValidAddress(t *testing.T) {
	tests := []struct {
		name        string
		to          address
		shouldPanic bool
		expectedMsg string
	}{
		{
			name:        "Valid to address should not panic",
			to:          addr01,
			shouldPanic: false,
		},
		{
			name:        "Another valid to address should not panic",
			to:          addr02,
			shouldPanic: false,
		},
		{
			name:        "Empty to address should panic",
			to:          address(""),
			shouldPanic: true,
			expectedMsg: "[GNOSWAP-GNFT-002] invalid address || to address ()",
		},
		{
			name:        "Invalid to address format should panic",
			to:          address("invalid_to"),
			shouldPanic: true,
			expectedMsg: "[GNOSWAP-GNFT-002] invalid address || to address (invalid_to)",
		},
		{
			name:        "Malformed to address should panic",
			to:          address("g1abc"),
			shouldPanic: true,
			expectedMsg: "[GNOSWAP-GNFT-002] invalid address || to address (g1abc)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					assertToIsValidAddress(tt.to)
				})
			} else {
				assertToIsValidAddress(tt.to)
			}
		})
	}
}
