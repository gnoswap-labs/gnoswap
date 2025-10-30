package gnft

import (
	"chain/runtime"
	"strings"
	"testing"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	_ "gno.land/r/gnoswap/rbac" // initialize rbac package
)

const (
	errInvalidTokenId = "invalid token id"
)

var (
	positionPath  = "gno.land/r/gnoswap/position"
	positionRealm = testing.NewCodeRealm(positionPath)

	stakerPath  = "gno.land/r/gnoswap/staker"
	stakerRealm = testing.NewCodeRealm(stakerPath)

	addr01      = testutils.TestAddress("addr01")
	addr01Realm = testing.NewUserRealm(addr01)

	addr02      = testutils.TestAddress("addr02")
	addr02Realm = testing.NewUserRealm(addr02)
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
	tests := []struct {
		name        string
		setup       func()
		addr        address
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "balance with one NFT",
			setup: func() {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(100))
			},
			addr:     addr01,
			expected: 1,
		},
		{
			name: "balance with zero NFTs",
			setup: func() {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(100))
			},
			addr:     addr02,
			expected: 0,
		},
		{
			name: "balance with multiple NFTs",
			setup: func() {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(1))
				Mint(cross, addr01, tid(2))
				Mint(cross, addr01, tid(3))
			},
			addr:     addr01,
			expected: 3,
		},
		{
			name: "balance after transfer",
			setup: func() {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(1))
				Mint(cross, addr01, tid(2))
				// Transfer one NFT to addr02
				testing.SetRealm(addr01Realm)
				Approve(cross, stakerRealm.Address(), tid(1))
				testing.SetRealm(stakerRealm)
				TransferFrom(cross, addr01, addr02, tid(1))
			},
			addr:     addr01,
			expected: 1,
		},
		{
			name: "balance of recipient after transfer",
			setup: func() {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(1))
				Mint(cross, addr01, tid(2))
				// Transfer one NFT to addr02
				testing.SetRealm(addr01Realm)
				Approve(cross, stakerRealm.Address(), tid(1))
				testing.SetRealm(stakerRealm)
				TransferFrom(cross, addr01, addr02, tid(1))
			},
			addr:     addr02,
			expected: 1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup()
			}

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
	resetObject(t)
	testing.SetRealm(positionRealm)
	Mint(cross, addr01, tid(1))
	Mint(cross, addr02, tid(2))

	tests := []struct {
		name        string
		setup       func()
		tokenId     uint64
		shouldError bool
		errorMsg    string
		expected    address
	}{
		{
			name:        "valid token owner",
			tokenId:     1,
			shouldError: false,
			expected:    addr01,
		},
		{
			name:        "non-existent token",
			tokenId:     999,
			shouldError: true,
			errorMsg:    errInvalidTokenId,
		},
		{
			name: "burned token",
			setup: func() {
				testing.SetRealm(positionRealm)
				Burn(cross, tid(2))
			},
			tokenId:     2,
			shouldError: true,
			errorMsg:    errInvalidTokenId,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup()
			}

			ownerAddr, err := OwnerOf(tid(tt.tokenId))
			if tt.shouldError {
				uassert.Error(t, err)
				if err != nil {
					uassert.Equal(t, tt.errorMsg, err.Error())
				}
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tt.expected, ownerAddr)
			}
		})
	}
}

func TestSetApprovalForAll(t *testing.T) {
	tests := []struct {
		name        string
		setup       func()
		callerRealm runtime.Realm
		operator    address
		approved    bool
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "approve operator for all tokens",
			setup: func() {
				resetObject(t)
			},
			callerRealm: addr01Realm,
			operator:    addr02,
			approved:    true,
			shouldPanic: false,
		},
		{
			name: "revoke operator approval for all tokens",
			setup: func() {
				resetObject(t)
				testing.SetRealm(addr01Realm)
				SetApprovalForAll(cross, addr02, true)
			},
			callerRealm: addr01Realm,
			operator:    addr02,
			approved:    false,
			shouldPanic: false,
		},
		{
			name: "approve invalid operator address",
			setup: func() {
				resetObject(t)
			},
			callerRealm: addr01Realm,
			operator:    address(""),
			approved:    true,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-GNFT-004] invalid addresss",
		},
		{
			name: "approve self as operator",
			setup: func() {
				resetObject(t)
			},
			callerRealm: addr01Realm,
			operator:    addr01,
			approved:    true,
			shouldPanic: true,
			panicMsg:    "approval to current owner",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup()
			}

			testing.SetRealm(tt.callerRealm)

			if tt.shouldPanic {
				uassert.AbortsContains(t, tt.panicMsg, func() {
					SetApprovalForAll(cross, tt.operator, tt.approved)
				})
			} else {
				err := SetApprovalForAll(cross, tt.operator, tt.approved)
				uassert.NoError(t, err)

				// Verify approval status
				result := IsApprovedForAll(tt.callerRealm.Address(), tt.operator)
				uassert.Equal(t, tt.approved, result)
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

func TestSetTokenURI(t *testing.T) {
	tests := []struct {
		name             string
		callerRealm      runtime.Realm
		tokenId          uint64
		expectedHasAbort bool
		expectedErrMsg   string
	}{
		{
			name:             "set token uri expected error",
			callerRealm:      addr01Realm,
			tokenId:          1,
			expectedHasAbort: true,
			expectedErrMsg:   "[GNOSWAP-GNFT-002] cannot set URI || token id (1) has already set URI",
		},
		{
			name:             "set token uri is failed by not owner",
			callerRealm:      addr02Realm,
			tokenId:          1,
			expectedHasAbort: true,
			expectedErrMsg:   "[GNOSWAP-GNFT-002] cannot set URI || token id (1) has already set URI",
		},
		{
			name:             "set token uri is failed by empty token uri",
			callerRealm:      addr01Realm,
			tokenId:          1,
			expectedHasAbort: true,
			expectedErrMsg:   "[GNOSWAP-GNFT-002] cannot set URI || token id (1) has already set URI",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetObject(t)

			// token id 1 is pre-minted
			testing.SetRealm(positionRealm)
			Mint(cross, addr01, tid(1))

			testing.SetRealm(tt.callerRealm)
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedErrMsg, func() {
					SetTokenURI(cross, tid(tt.tokenId), "not change")
				})
			} else {
				SetTokenURI(cross, tid(tt.tokenId), "not change")
			}
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
		expectedAddr address
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
		callerRealm       runtime.Realm
		fromAddr          address
		toAddr            address
		tokenIdToTransfer uint64
		shouldPanic       bool
		panicMsg          string
		expected          address
	}{
		{
			name:              "transfer non-existent token id",
			callerRealm:       stakerRealm,
			fromAddr:          addr01,
			toAddr:            addr02,
			tokenIdToTransfer: 99,
			shouldPanic:       true,
			panicMsg:          "invalid token id",
		},
		{
			name:              "transfer token owned by other user without approval",
			callerRealm:       stakerRealm,
			fromAddr:          addr01,
			toAddr:            addr02,
			tokenIdToTransfer: 1,
			shouldPanic:       true,
			panicMsg:          "caller is not token owner or approved || caller g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3 is not owner g1v9jxgu3sx9047h6lta047h6lta047h6l0js7st or approved for token 1",
		},
		{
			name: "transfer token owned by other user with approval",
			setup: func(cur realm) {
				testing.SetRealm(addr01Realm)
				Approve(cross, stakerRealm.Address(), tid(1))
			},
			callerRealm:       stakerRealm,
			fromAddr:          addr01,
			toAddr:            addr02,
			tokenIdToTransfer: 1,
		},
		{
			name: "transfer token owned by caller",
			setup: func(cur realm) {
				testing.SetRealm(addr02Realm)
				Approve(cross, stakerRealm.Address(), tid(1))
			},
			callerRealm:       stakerRealm,
			fromAddr:          addr02,
			toAddr:            addr01,
			tokenIdToTransfer: 1,
		},
		{
			name:              "transfer from is invalid address",
			callerRealm:       stakerRealm,
			fromAddr:          address(""),
			toAddr:            addr02,
			tokenIdToTransfer: 1,
			shouldPanic:       true,
			panicMsg:          "[GNOSWAP-GNFT-004] invalid addresss || from address ()",
		},
		{
			name:              "transfer to is invalid address",
			callerRealm:       stakerRealm,
			fromAddr:          addr01,
			toAddr:            address("this_is_invalid_address"),
			tokenIdToTransfer: 1,
			shouldPanic:       true,
			panicMsg:          "[GNOSWAP-GNFT-004] invalid addresss || to address (this_is_invalid_address)",
		},
		{
			name:              "not-staker contract transfer",
			callerRealm:       addr01Realm,
			fromAddr:          addr01,
			toAddr:            addr02,
			tokenIdToTransfer: 1,
			shouldPanic:       true,
			panicMsg:          "unauthorized: caller g1v9jxgu3sx9047h6lta047h6lta047h6l0js7st is not staker",
		},
		{
			name: "transfer to self",
			setup: func(cur realm) {
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(100))
				testing.SetRealm(addr01Realm)
				Approve(cross, stakerRealm.Address(), tid(100))
			},
			callerRealm:       stakerRealm,
			fromAddr:          addr01,
			toAddr:            addr01,
			tokenIdToTransfer: 100,
			shouldPanic:       true,
			panicMsg:          "cannot send transfer to self",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup(cross)
			}

			testing.SetRealm(tt.callerRealm)
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
	tests := []struct {
		name            string
		callerRealm     runtime.Realm
		tokenIdToMint   uint64
		addressToMint   address
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
		{
			name:          "mint failed by existing token id",
			callerRealm:   positionRealm,
			tokenIdToMint: 0,
			addressToMint: addr01,
			shouldPanic:   true,
			panicMsg:      "token id already exists",
		},
		{
			name:          "mint failed by unauthorized caller",
			callerRealm:   addr01Realm,
			tokenIdToMint: 10,
			addressToMint: addr01,
			shouldPanic:   true,
			panicMsg:      "ownable: caller is not owner",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetObject(t)

			// token id 0 is pre-minted
			testing.SetRealm(positionRealm)
			Mint(cross, testutils.TestAddress("human"), tid(0))

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					testing.SetRealm(tt.callerRealm)
					Mint(cross, tt.addressToMint, tid(tt.tokenIdToMint))
				})

				balance, _ := BalanceOf(tt.addressToMint)
				uassert.Equal(t, int64(0), balance)
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
		setup           func()
		callerRealm     runtime.Realm
		tokenIdToBurn   uint64
		expectedBalance int64
		shouldPanic     bool
		panicMsg        string
	}{
		{
			name:            "burn success",
			tokenIdToBurn:   1,
			shouldPanic:     false,
			expectedBalance: 0,
		},
		{
			name:            "burn without permission",
			callerRealm:     testing.NewUserRealm(addr01),
			tokenIdToBurn:   1,
			expectedBalance: 1,
			shouldPanic:     true,
			panicMsg:        "ownable: caller is not owner",
		},
		{
			name:            "burn non-existent token id",
			callerRealm:     positionRealm,
			tokenIdToBurn:   99,
			expectedBalance: 1,
			shouldPanic:     true,
			panicMsg:        errInvalidTokenId,
		},
		{
			name: "burn already burned token",
			setup: func() {
				testing.SetRealm(positionRealm)
				Burn(cross, tid(1))
			},
			callerRealm:     positionRealm,
			tokenIdToBurn:   1,
			expectedBalance: 0,
			shouldPanic:     true,
			panicMsg:        errInvalidTokenId,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetObject(t)

			// token id 1 is pre-minted
			testing.SetRealm(positionRealm)
			Mint(cross, testutils.TestAddress("human"), tid(1))

			if tt.setup != nil {
				tt.setup()
			}

			testing.SetRealm(tt.callerRealm)

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					Burn(cross, tid(tt.tokenIdToBurn))
				})
			} else {
				Burn(cross, tid(tt.tokenIdToBurn))
			}

			balance, _ := BalanceOf(testutils.TestAddress("human"))
			uassert.Equal(t, tt.expectedBalance, balance)
		})
	}
}

func TestTokenURI(t *testing.T) {
	resetObject(t)
	testing.SetRealm(positionRealm)
	Mint(cross, addr01, tid(1))

	tests := []struct {
		name        string
		tokenId     uint64
		shouldError bool
		errorMsg    string
	}{
		{
			name:        "valid token URI",
			tokenId:     1,
			shouldError: false,
		},
		{
			name:        "non-existent token",
			tokenId:     999,
			shouldError: true,
			errorMsg:    errInvalidTokenId,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uri, err := TokenURI(tid(tt.tokenId))

			if tt.shouldError {
				uassert.Error(t, err)
				if err != nil {
					uassert.Equal(t, tt.errorMsg, err.Error())
				}
			} else {
				uassert.NoError(t, err)
				uassert.NotEmpty(t, uri)
				uassert.True(t, strings.HasPrefix(uri, "data:image/svg+xml;base64,"))
			}
		})
	}
}

func TestMustOwnerOf(t *testing.T) {
	resetObject(t)
	testing.SetRealm(positionRealm)
	Mint(cross, addr01, tid(1))

	tests := []struct {
		name        string
		tokenId     uint64
		shouldPanic bool
		panicMsg    string
		expected    address
	}{
		{
			name:        "valid token",
			tokenId:     1,
			shouldPanic: false,
			expected:    addr01,
		},
		{
			name:        "non-existent token",
			tokenId:     999,
			shouldPanic: true,
			panicMsg:    errInvalidTokenId,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					MustOwnerOf(tid(tt.tokenId))
				})
			} else {
				owner := MustOwnerOf(tid(tt.tokenId))
				uassert.Equal(t, tt.expected, owner)
			}
		})
	}
}

func TestSafeTransferFrom(t *testing.T) {
	resetObject(t)
	testing.SetRealm(positionRealm)
	Mint(cross, addr01, tid(1))

	tests := []struct {
		name        string
		setup       func(cur realm)
		callerRealm runtime.Realm
		from        address
		to          address
		tokenId     uint64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "owner transfers own token",
			setup: func(cur realm) {
				testing.SetRealm(addr01Realm)
				Approve(cross, stakerRealm.Address(), tid(1))
			},
			callerRealm: stakerRealm,
			from:        addr01,
			to:          addr02,
			tokenId:     1,
			shouldPanic: false,
		},
		{
			name: "non-owner transfers without approval",
			setup: func(cur realm) {
				testing.SetRealm(addr02Realm)
				Approve(cross, stakerRealm.Address(), tid(1))
			},
			callerRealm: stakerRealm,
			from:        addr01,
			to:          addr02,
			tokenId:     1,
			shouldPanic: true,
			panicMsg:    "transfer from incorrect owner || from g1v9jxgu3sx9047h6lta047h6lta047h6l0js7st is not the owner g1v9jxgu3sxf047h6lta047h6lta047h6l8tv5at of token 1",
		},
		{
			name:        "transfer non-existent token",
			callerRealm: stakerRealm,
			from:        addr01,
			to:          addr02,
			tokenId:     999,
			shouldPanic: true,
			panicMsg:    "invalid token id",
		},
		{
			name:        "transfer to zero address",
			callerRealm: stakerRealm,
			from:        addr01,
			to:          address(""),
			tokenId:     1,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-GNFT-004] invalid addresss || to address ()",
		},
		{
			name:        "not-staker contract transfer",
			callerRealm: addr01Realm,
			from:        addr01,
			to:          addr02,
			tokenId:     1,
			shouldPanic: true,
			panicMsg:    "unauthorized: caller g1v9jxgu3sx9047h6lta047h6lta047h6l0js7st is not staker",
		},
		{
			name: "safe transfer to self",
			setup: func(cur realm) {
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(100))
				testing.SetRealm(addr01Realm)
				Approve(cross, stakerRealm.Address(), tid(100))
			},
			callerRealm: stakerRealm,
			from:        addr01,
			to:          addr01,
			tokenId:     100,
			shouldPanic: true,
			panicMsg:    "cannot send transfer to self",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup(cross)
			}

			testing.SetRealm(tt.callerRealm)

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					SafeTransferFrom(cross, tt.from, tt.to, tid(tt.tokenId))
				})
			} else {
				err := SafeTransferFrom(cross, tt.from, tt.to, tid(tt.tokenId))
				uassert.NoError(t, err)

				// Verify ownership transferred
				newOwner, _ := OwnerOf(tid(tt.tokenId))
				uassert.Equal(t, tt.to, newOwner)
			}
		})
	}
}

func TestExists(t *testing.T) {
	resetObject(t)
	testing.SetRealm(positionRealm)
	Mint(cross, addr01, tid(1))
	Mint(cross, addr01, tid(2))
	Burn(cross, tid(2))

	tests := []struct {
		name     string
		tokenId  uint64
		expected bool
	}{
		{
			name:     "existing token",
			tokenId:  1,
			expected: true,
		},
		{
			name:     "burned token",
			tokenId:  2,
			expected: false,
		},
		{
			name:     "never minted token",
			tokenId:  999,
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			exists := Exists(tid(tt.tokenId))
			uassert.Equal(t, tt.expected, exists)
		})
	}
}

func TestRender(t *testing.T) {
	tests := []struct {
		name     string
		path     string
		expected string
	}{
		{
			name:     "empty path",
			path:     "",
			expected: nft.RenderHome(),
		},
		{
			name:     "invalid path",
			path:     "invalid",
			expected: "404\n",
		},
		{
			name:     "another invalid path",
			path:     "/token/1",
			expected: "404\n",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := Render(tt.path)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestApprove(t *testing.T) {
	resetObject(t)
	testing.SetRealm(positionRealm)
	Mint(cross, addr01, tid(1))

	tests := []struct {
		name        string
		setup       func()
		callerRealm runtime.Realm
		approved    address
		tokenId     uint64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "owner approves address",
			callerRealm: addr01Realm,
			approved:    addr02,
			tokenId:     1,
			shouldPanic: false,
		},
		{
			name:        "non-owner tries to approve",
			callerRealm: addr02Realm,
			approved:    testutils.TestAddress("addr03"),
			tokenId:     1,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-GNFT-006] caller is not token owner or approved || caller g1v9jxgu3sxf047h6lta047h6lta047h6l8tv5at cannot approve for token 1 owned by g1v9jxgu3sx9047h6lta047h6lta047h6l0js7st",
		},
		{
			name:        "approve for non-existent token",
			callerRealm: addr01Realm,
			approved:    addr02,
			tokenId:     999,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-GNFT-007] token does not exist || token 999",
		},
		{
			name:        "approve self",
			callerRealm: addr01Realm,
			approved:    addr01,
			tokenId:     1,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-GNFT-008] cannot transfer to self || cannot approve to current owner g1v9jxgu3sx9047h6lta047h6lta047h6l0js7st for token 1",
		},
		{
			name:        "approve invalid address",
			callerRealm: addr01Realm,
			approved:    address(""),
			tokenId:     1,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-GNFT-004] invalid addresss || address ()",
		},
		{
			name: "re-approve same address (idempotency)",
			setup: func() {
				testing.SetRealm(addr01Realm)
				Approve(cross, addr02, tid(1))
			},
			callerRealm: addr01Realm,
			approved:    addr02,
			tokenId:     1,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup()
			}

			testing.SetRealm(tt.callerRealm)

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					Approve(cross, tt.approved, tid(tt.tokenId))
				})
			} else {
				err := Approve(cross, tt.approved, tid(tt.tokenId))
				uassert.NoError(t, err)

				// Verify approval
				approved, _ := GetApproved(tid(tt.tokenId))
				uassert.Equal(t, tt.approved, approved)
			}
		})
	}
}

func TestHaltedOperations(t *testing.T) {
	tests := []struct {
		name        string
		operation   string
		setup       func()
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:      "Mint when halted",
			operation: "Mint",
			setup: func() {
				resetObject(t)
				setHalted(true)
			},
			shouldPanic: true,
			panicMsg:    "halted: position",
		},
		{
			name:      "Burn when halted",
			operation: "Burn",
			setup: func() {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(1))
				setHalted(true)
			},
			shouldPanic: true,
			panicMsg:    "halted: position",
		},
		{
			name:      "SafeTransferFrom when halted",
			operation: "SafeTransferFrom",
			setup: func() {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(1))
				testing.SetRealm(addr01Realm)
				Approve(cross, stakerRealm.Address(), tid(1))
				setHalted(true)
			},
			shouldPanic: true,
			panicMsg:    "halted: position",
		},
		{
			name:      "TransferFrom when halted",
			operation: "TransferFrom",
			setup: func() {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(1))
				testing.SetRealm(addr01Realm)
				Approve(cross, stakerRealm.Address(), tid(1))
				setHalted(true)
			},
			shouldPanic: true,
			panicMsg:    "halted: position",
		},
		{
			name:      "Approve when halted",
			operation: "Approve",
			setup: func() {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(1))
				setHalted(true)
			},
			shouldPanic: true,
			panicMsg:    "halted: position",
		},
		{
			name:      "SetApprovalForAll when halted",
			operation: "SetApprovalForAll",
			setup: func() {
				resetObject(t)
				setHalted(true)
			},
			shouldPanic: true,
			panicMsg:    "halted: position",
		},
		{
			name:      "SetTokenURI when halted",
			operation: "SetTokenURI",
			setup: func() {
				resetObject(t)
				testing.SetRealm(positionRealm)
				Mint(cross, addr01, tid(1))
				setHalted(true)
			},
			shouldPanic: true,
			panicMsg:    "halted: position",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				tt.setup()
			}

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, tt.panicMsg, func() {
					switch tt.operation {
					case "Mint":
						testing.SetRealm(positionRealm)
						Mint(cross, addr01, tid(1))
					case "Burn":
						testing.SetRealm(positionRealm)
						Burn(cross, tid(1))
					case "SafeTransferFrom":
						testing.SetRealm(stakerRealm)
						SafeTransferFrom(cross, addr01, addr02, tid(1))
					case "TransferFrom":
						testing.SetRealm(stakerRealm)
						TransferFrom(cross, addr01, addr02, tid(1))
					case "Approve":
						testing.SetRealm(addr01Realm)
						Approve(cross, addr02, tid(1))
					case "SetApprovalForAll":
						testing.SetRealm(addr01Realm)
						SetApprovalForAll(cross, addr02, true)
					case "SetTokenURI":
						testing.SetRealm(positionRealm)
						SetTokenURI(cross, tid(1), "test-uri")
					}
				})
			}

			// Cleanup: unhalt for next test
			setHalted(false)
		})
	}
}

func Test_setTokenURI(t *testing.T) {
	tests := []struct {
		name          string
		setup         func()
		ownerAddr     address
		tokenId       uint64
		tokenURI      string
		expectedError bool
		errorContains string
	}{
		{
			name: "successfully sets URI for token owned by caller",
			setup: func() {
				// Mint token to position owner
				ownerAddr := owner.Owner()
				nft.Mint(ownerAddr, tid(100))
			},
			ownerAddr:     owner.Owner(),
			tokenId:       100,
			tokenURI:      "custom-uri",
			expectedError: false,
		},
		{
			name: "fails for non-existent token",
			setup: func() {
				// No token minted
			},
			ownerAddr:     owner.Owner(),
			tokenId:       999,
			tokenURI:      "custom-uri",
			expectedError: true,
			errorContains: "invalid token id",
		},
		{
			name: "overwrites URI when already set (private function allows this)",
			setup: func() {
				// Mint and set URI
				ownerAddr := owner.Owner()
				nft.Mint(ownerAddr, tid(200))
				// Set URI first time using nested realms
				testing.SetRealm(testing.NewUserRealm(ownerAddr))
				func() {
					testing.SetRealm(testing.NewCodeRealm("gno.land/r/test"))
					setTokenURI(tid(200), grc721.TokenURI("first-uri"))
				}()
			},
			ownerAddr:     owner.Owner(),
			tokenId:       200,
			tokenURI:      "second-uri",
			expectedError: false, // private setTokenURI allows overwriting
		},
		{
			name: "fails when caller is not token owner",
			setup: func() {
				// Mint token to addr01
				nft.Mint(addr01, tid(300))
			},
			ownerAddr:     addr02, // Different owner trying to set URI
			tokenId:       300,
			tokenURI:      "unauthorized-uri",
			expectedError: true,
			errorContains: "caller is not token owner",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resetObject(t)

			if tc.setup != nil {
				tc.setup()
			}

			// when
			var err error
			testing.SetRealm(testing.NewUserRealm(tc.ownerAddr))
			func() {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/test"))
				err = setTokenURI(tid(tc.tokenId), grc721.TokenURI(tc.tokenURI))
			}()

			// then
			if tc.expectedError {
				uassert.Error(t, err)
				if tc.errorContains != "" && err != nil {
					uassert.True(t, strings.Contains(err.Error(), tc.errorContains))
				}
			} else {
				uassert.NoError(t, err)

				// Verify URI was set correctly
				uri, err := TokenURI(tid(tc.tokenId))
				uassert.NoError(t, err)
				uassert.Equal(t, tc.tokenURI, uri)
			}
		})
	}
}

func resetObject(t *testing.T) {
	t.Helper()

	nft = grc721.NewBasicNFT("GNOSWAP NFT", "GNFT")
}
