package gnft

import (
	"std"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	_ "gno.land/r/gnoswap/v1/rbac" // initialize rbac package
)

const (
	errInvalidTokenId = "invalid token id"
)

var (
	positionPath  = "gno.land/r/gnoswap/v1/position"
	positionRealm = std.NewCodeRealm(positionPath)

	addr01      = testutils.TestAddress("addr01")
	addr01Realm = std.NewUserRealm(addr01)

	addr02      = testutils.TestAddress("addr02")
	addr02Realm = std.NewUserRealm(addr02)
)

func TestMetadata(t *testing.T) {
	tests := []struct {
		name     string
		fn       func() string
		expected string
	}{
		{"Name()", Name, "GNOSWAP NFT"},
		{"Symbol()", Symbol, "GNFT"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.Equal(t, tt.expected, tt.fn())
		})
	}
}

func TestBalanceOf(t *testing.T) {
	resetObject(t)
	testing.SetRealm(positionRealm)
	Mint(cross, addr01, tid(100))

	tests := []struct {
		name     string
		addr     std.Address
		expected int64
	}{
		{"BalanceOf(addr01)", addr01, 1},
		{"BalanceOf(addr02)", addr02, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			balance, _ := BalanceOf(tt.addr)
			uassert.Equal(t, tt.expected, balance)
		})
	}
}

func TestTotalSupply(t *testing.T) {
	resetObject(t)
	tests := []struct {
		name     string
		setup    func(cur realm)
		expected int64
	}{
		{
			name:     "initial total supply",
			expected: 0,
		},
		{
			name: "total supply after minting",
			setup: func(cur realm) {
				testing.SetRealm(positionRealm)
				Mint(cur, addr01, tid(1))
				Mint(cur, addr01, tid(2))
			},
			expected: 2,
		},
		{
			name: "total supply after burning",
			setup: func(cur realm) {
				testing.SetRealm(positionRealm)
				Burn(cur, tid(2))
			},
			expected: 1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				testing.SetRealm(positionRealm)
				tt.setup(cross)
			}
			uassert.Equal(t, tt.expected, TotalSupply())
		})
	}
}

func TestOwnerOf(t *testing.T) {
	tests := []struct {
		name        string
		tokenId     uint64
		shouldPanic bool
		panicMsg    string
		expected    std.Address
	}{
		// {"OwnerOf(1)", 1, false, "", addr01},
		{"OwnerOf(500)", 500, false, errInvalidTokenId, addr01},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					OwnerOf(tid(tt.tokenId))
				})
			} else {
				ownerAddr, err := OwnerOf(tid(tt.tokenId))
				if err != nil {
					uassert.Equal(t, tt.panicMsg, err.Error())
				} else {
					uassert.Equal(t, tt.expected, ownerAddr)
				}
			}
		})
	}
}

func TestIsApprovedForAll(t *testing.T) {
	tests := []struct {
		name             string
		isApprovedForAll bool
		expected         bool
	}{
		{
			name:             "IsApprovedForAll(addr01, addr02)",
			isApprovedForAll: false,
			expected:         false,
		},
		{
			name:             "IsApprovedForAll(addr01, addr02) after setting approval",
			isApprovedForAll: true,
			expected:         true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(addr01Realm)
			if tt.isApprovedForAll {
				SetApprovalForAll(cross, addr02, tt.isApprovedForAll)
			}
			uassert.Equal(t, tt.expected, IsApprovedForAll(addr01, addr02))
		})
	}
}

func TestGetApproved(t *testing.T) {
	resetObject(t)
	testing.SetRealm(positionRealm)
	Mint(cross, addr01, tid(1))

	tests := []struct {
		name         string
		setup        func(cur realm)
		tokenId      uint64
		expectedAddr std.Address
		shouldError  bool
		errorMsg     string
	}{
		{
			name:        "GetApproved for token without approval",
			tokenId:     1,
			shouldError: true,
			errorMsg:    "token id not approved for anyone",
		},
		{
			name: "GetApproved for token with approval",
			setup: func(cur realm) {
				testing.SetRealm(addr01Realm)
				Approve(cross, addr02, tid(1))
			},
			tokenId:      1,
			expectedAddr: addr02,
		},
		{
			name:        "GetApproved for non-existent token",
			tokenId:     999,
			shouldError: true,
			errorMsg:    "token id not approved for anyone",
		},
		{
			name: "GetApproved for token with different approval",
			setup: func(cur realm) {
				testing.SetRealm(addr01Realm)
				Approve(cross, addr02, tid(1))
				Approve(cross, testutils.TestAddress("addr03"), tid(1)) // change approval
			},
			tokenId:      1,
			expectedAddr: testutils.TestAddress("addr03"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup(cross)
			}

			addr, err := GetApproved(tid(tt.tokenId))

			if tt.shouldError {
				if err == nil {
					t.Errorf("Expected error but got none")
				} else if err.Error() != tt.errorMsg {
					t.Errorf("Expected error message '%s', got '%s'", tt.errorMsg, err.Error())
				}
			} else {
				if err != nil {
					t.Errorf("Unexpected error: %v", err)
				}
				uassert.Equal(t, tt.expectedAddr, addr)
			}
		})
	}
}

func TestTransferFrom(t *testing.T) {
	resetObject(t)
	testing.SetRealm(positionRealm)
	Mint(cross, addr01, tid(1))

	tests := []struct {
		name              string
		setup             func(cur realm)
		callerRealm       std.Realm
		fromAddr          std.Address
		toAddr            std.Address
		tokenIdToTransfer uint64
		shouldPanic       bool
		panicMsg          string
		expected          std.Address
	}{
		{
			name:              "transfer non-existent token id",
			callerRealm:       std.NewUserRealm(addr01),
			fromAddr:          addr01,
			toAddr:            addr02,
			tokenIdToTransfer: 99,
			shouldPanic:       true,
			panicMsg:          "caller is not token owner or approved",
		},
		{
			name:              "transfer token owned by other user without approval",
			callerRealm:       std.NewUserRealm(addr02),
			fromAddr:          addr01,
			toAddr:            addr02,
			tokenIdToTransfer: 1,
			shouldPanic:       true,
			panicMsg:          "caller is not token owner or approved",
		},
		{
			name: "transfer token owned by other user with approval",
			setup: func(cur realm) {
				testing.SetRealm(addr01Realm)
				Approve(cross, addr02, tid(1))
			},
			callerRealm:       std.NewUserRealm(addr02),
			fromAddr:          addr01,
			toAddr:            addr02,
			tokenIdToTransfer: 1,
		},
		{
			name:              "transfer token owned by caller",
			callerRealm:       std.NewUserRealm(addr02),
			fromAddr:          addr02,
			toAddr:            addr01,
			tokenIdToTransfer: 1,
		},
		{
			name:              "transfer from is invalid address",
			callerRealm:       std.NewUserRealm(addr01),
			fromAddr:          std.Address(""),
			toAddr:            addr02,
			tokenIdToTransfer: 1,
			shouldPanic:       true,
			panicMsg:          "caller is not token owner or approved",
		},
		{
			name:              "transfer to is invalid address",
			callerRealm:       std.NewUserRealm(addr01),
			fromAddr:          addr01,
			toAddr:            std.Address("this_is_invalid_address"),
			tokenIdToTransfer: 1,
			shouldPanic:       true,
			panicMsg:          "caller is not token owner or approved",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup(cross)
			}

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					TransferFrom(cross, tt.fromAddr, tt.toAddr, tid(tt.tokenIdToTransfer))
				})
			} else {
				testing.SetRealm(tt.callerRealm)
				TransferFrom(cross, tt.fromAddr, tt.toAddr, tid(tt.tokenIdToTransfer))
			}
		})
	}
}

func TestMint(t *testing.T) {
	resetObject(t)

	tests := []struct {
		name            string
		callerRealm     std.Realm
		tokenIdToMint   uint64
		addressToMint   std.Address
		shouldPanic     bool
		panicMsg        string
		expected        string
		verifyTokenList func()
	}{
		{
			name:          "mint first nft to addr01",
			callerRealm:   positionRealm,
			tokenIdToMint: 1,
			addressToMint: addr01,
			expected:      "1",
			verifyTokenList: func() {
				balance, _ := BalanceOf(addr01)
				uassert.Equal(t, int64(1), balance)
			},
		},
		{
			name:          "mint second nft to addr02",
			callerRealm:   positionRealm,
			tokenIdToMint: 2,
			addressToMint: addr02,
			expected:      "2",
			verifyTokenList: func() {
				balance, _ := BalanceOf(addr02)
				uassert.Equal(t, int64(1), balance)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					Mint(cross, tt.addressToMint, tid(tt.tokenIdToMint))
				})
			} else {
				testing.SetRealm(tt.callerRealm)
				mintedTokenId := Mint(cross, tt.addressToMint, tid(tt.tokenIdToMint))
				uassert.Equal(t, tt.expected, string(mintedTokenId))
				tt.verifyTokenList()
			}
		})
	}
}

func TestBurn(t *testing.T) {
	tests := []struct {
		name            string
		callerRealm     std.Realm
		tokenIdToBurn   uint64
		shouldPanic     bool
		panicMsg        string
		verifyTokenList func()
	}{
		{
			name:          "burn without permission",
			tokenIdToBurn: 1,
			shouldPanic:   true,
			panicMsg:      "ownable: caller is not owner",
		},
		{
			name:          "burn non-existent token id",
			callerRealm:   positionRealm,
			tokenIdToBurn: 99,
			shouldPanic:   true,
			panicMsg:      errInvalidTokenId,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(tt.callerRealm)

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					Burn(cross, tid(tt.tokenIdToBurn))
				})
			} else {
				uassert.NotAborts(t, func() {
					Burn(cross, tid(tt.tokenIdToBurn))
				})
				tt.verifyTokenList()
			}
		})
	}
}

func resetObject(t *testing.T) {
	t.Helper()

	nft = grc721.NewBasicNFT("GNOSWAP NFT", "GNFT")
}
