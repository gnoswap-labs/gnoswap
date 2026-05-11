package v1

import (
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/mock"
)

func TestAssertIsNotExpired(t *testing.T) {
	tests := []struct {
		name                 string
		deadline             int64
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:        "Valid deadline is future time",
			deadline:    time.Now().Unix() + 3600, // 1 hour from now
			shouldPanic: false,
		},
		{
			name:        "Valid deadline is far future",
			deadline:    time.Now().Unix() + 86400*365, // 1 year from now
			shouldPanic: false,
		},
		{
			name:        "Valid deadline is current time (not expired)",
			deadline:    time.Now().Unix(),
			shouldPanic: false,
		},
		{
			name:        "Valid deadline is max int64 deadline",
			deadline:    9223372036854775807,
			shouldPanic: false,
		},
		{
			name:                 "Expired deadline is past time",
			deadline:             time.Now().Unix() - 1,
			expectedPanicMessage: ufmt.Sprintf("[GNOSWAP-POSITION-006] transaction expired || transaction too old, now(%d) > deadline(%d)", time.Now().Unix(), time.Now().Unix()-1),
			shouldPanic:          true,
		},
		{
			name:                 "Expired deadline is far past",
			deadline:             time.Now().Unix() - 86400,
			expectedPanicMessage: ufmt.Sprintf("[GNOSWAP-POSITION-006] transaction expired || transaction too old, now(%d) > deadline(%d)", time.Now().Unix(), time.Now().Unix()-86400),
			shouldPanic:          true,
		},
		{
			name:                 "Expired deadline is zero deadline",
			deadline:             0,
			expectedPanicMessage: ufmt.Sprintf("[GNOSWAP-POSITION-006] transaction expired || transaction too old, now(%d) > deadline(%d)", time.Now().Unix(), 0),
			shouldPanic:          true,
		},
		{
			name:                 "Expired deadline is negative deadline",
			deadline:             -1,
			expectedPanicMessage: ufmt.Sprintf("[GNOSWAP-POSITION-006] transaction expired || transaction too old, now(%d) > deadline(%d)", time.Now().Unix(), -1),
			shouldPanic:          true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertIsNotExpired(tt.deadline)
				})
			} else {
				assertIsNotExpired(tt.deadline)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestAssertValidLiquidityAmount(t *testing.T) {
	tests := []struct {
		name                 string
		liquidity            string
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:        "Valid liquidity is positive number",
			liquidity:   "1000000",
			shouldPanic: false,
		},
		{
			name:        "Valid liquidity is large number",
			liquidity:   "999999999999999999999999999999999",
			shouldPanic: false,
		},
		{
			name:        "Valid liquidity is minimum valid (1)",
			liquidity:   "1",
			shouldPanic: false,
		},
		{
			name:                 "Invalid liquidity is zero",
			liquidity:            "0",
			expectedPanicMessage: "[GNOSWAP-POSITION-009] zero liquidity || liquidity amount must be greater than 0, got 0",
			shouldPanic:          true,
		},
		{
			name:                 "Invalid liquidity is negative (will panic in u256)",
			liquidity:            "-1",
			expectedPanicMessage: "strconv.ParseUint: parsing \"-1\": invalid syntax",
			shouldPanic:          true,
		},
		{
			name:                 "Invalid liquidity is non-numeric",
			liquidity:            "abc",
			expectedPanicMessage: "strconv.ParseUint: parsing \"abc\": invalid syntax",
			shouldPanic:          true,
		},
		{
			name:                 "Invalid liquidity is empty string",
			liquidity:            "",
			expectedPanicMessage: "EOF",
			shouldPanic:          true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertValidLiquidityAmount(tt.liquidity)
				})
			} else {
				assertValidLiquidityAmount(tt.liquidity)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestAssertExistsPosition(t *testing.T) {
	tests := []struct {
		name                 string
		positionId           uint64
		setupPosition        bool
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:          "Position exists",
			positionId:    1,
			setupPosition: true,
			shouldPanic:   false,
		},
		{
			name:                 "Position does not exist",
			positionId:           999,
			setupPosition:        false,
			expectedPanicMessage: "[GNOSWAP-POSITION-012] position does not exist || position with position ID(999) doesn't exist",
			shouldPanic:          true,
		},
		{
			name:                 "Position ID is 0",
			positionId:           0,
			setupPosition:        false,
			expectedPanicMessage: "[GNOSWAP-POSITION-012] position does not exist || position with position ID(0) doesn't exist",
			shouldPanic:          true,
		},
		{
			name:                 "Large position ID doesn't exist",
			positionId:           18446744073709551615,
			setupPosition:        false,
			expectedPanicMessage: "[GNOSWAP-POSITION-012] position does not exist || position with position ID(18446744073709551615) doesn't exist",
			shouldPanic:          true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.setupPosition {
				position := newDummyPosition(tt.positionId)
				mockInstance.mustUpdatePosition(tt.positionId, position)
				mockInstance.incrementNextId()

				mockInstance.nftAccessor.Mint(adminAddr, positionIdFrom(tt.positionId))
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertExistsPosition(mockInstance, tt.positionId)
				})
			} else {
				assertExistsPosition(mockInstance, tt.positionId)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestAssertIsOwnerForToken(t *testing.T) {
	tests := []struct {
		name                 string
		positionId           uint64
		caller               address
		setupPosition        bool
		setupOwner           address
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:          "Valid owner",
			positionId:    1,
			caller:        adminAddr,
			setupPosition: true,
			setupOwner:    adminAddr,
			shouldPanic:   false,
		},
		{
			name:                 "Not the owner",
			positionId:           1,
			caller:               alice,
			setupPosition:        true,
			setupOwner:           adminAddr,
			expectedPanicMessage: "[GNOSWAP-POSITION-001] caller has no permission || caller(g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh) is not owner of positionId(1)",
			shouldPanic:          true,
		},
		{
			name:                 "Position does not exist",
			positionId:           999,
			caller:               adminAddr,
			setupPosition:        false,
			expectedPanicMessage: "[GNOSWAP-POSITION-012] position does not exist || position with position ID(999) doesn't exist",
			shouldPanic:          true,
		},
		{
			name:                 "Empty address as caller",
			positionId:           1,
			caller:               "",
			setupPosition:        true,
			setupOwner:           adminAddr,
			expectedPanicMessage: "[GNOSWAP-POSITION-001] caller has no permission || caller() is not owner of positionId(1)",
			shouldPanic:          true,
		},
		{
			name:          "Owner is bob",
			positionId:    2,
			caller:        bob,
			setupPosition: true,
			setupOwner:    bob,
			shouldPanic:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.setupPosition {
				testing.SetRealm(posRealm)
				mockInstance.nftAccessor.Mint(tt.setupOwner, positionIdFrom(tt.positionId))
				position := newDummyPosition(tt.positionId)
				mockInstance.mustUpdatePosition(tt.positionId, position)
				mockInstance.incrementNextId()
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertIsOwnerForToken(mockInstance, tt.positionId, tt.caller)
				})
			} else {
				assertIsOwnerForToken(mockInstance, tt.positionId, tt.caller)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestAssertIsOwnerOrOperatorForToken(t *testing.T) {
	tests := []struct {
		name                 string
		positionId           uint64
		isStaked             bool
		caller               address
		setupPosition        bool
		setupOwner           address
		setupOperator        address
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:          "Caller is owner",
			positionId:    1,
			isStaked:      false,
			caller:        adminAddr,
			setupPosition: true,
			setupOwner:    adminAddr,
			shouldPanic:   false,
		},
		{
			name:          "Caller is operator",
			positionId:    1,
			isStaked:      true,
			caller:        alice,
			setupPosition: true,
			setupOwner:    adminAddr,
			setupOperator: alice,
			shouldPanic:   false,
		},
		{
			name:                 "Caller is neither owner nor operator",
			positionId:           1,
			isStaked:             false,
			caller:               bob,
			setupPosition:        true,
			setupOwner:           adminAddr,
			setupOperator:        alice,
			expectedPanicMessage: "[GNOSWAP-POSITION-001] caller has no permission || caller(g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu) is not owner or approved operator of positionId(1)",
			shouldPanic:          true,
		},
		{
			name:                 "Position does not exist",
			positionId:           999,
			isStaked:             false,
			caller:               adminAddr,
			setupPosition:        false,
			expectedPanicMessage: "[GNOSWAP-POSITION-012] position does not exist || position with position ID(999) doesn't exist",
			shouldPanic:          true,
		},
		{
			name:          "Owner and operator are the same",
			positionId:    2,
			isStaked:      false,
			caller:        alice,
			setupPosition: true,
			setupOwner:    alice,
			setupOperator: alice,
			shouldPanic:   false,
		},
		{
			name:                 "Empty address as caller",
			positionId:           1,
			isStaked:             false,
			caller:               "",
			setupPosition:        true,
			setupOwner:           adminAddr,
			setupOperator:        alice,
			expectedPanicMessage: "[GNOSWAP-POSITION-001] caller has no permission || caller() is not owner or approved operator of positionId(1)",
			shouldPanic:          true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.setupPosition {
				testing.SetRealm(posRealm)
				mockInstance.nftAccessor.Mint(tt.setupOwner, positionIdFrom(tt.positionId))

				position := newDummyPosition(tt.positionId)
				if tt.setupOperator != "" {
					if tt.isStaked {
						stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())
						nftAccessor := mockInstance.nftAccessor.(*mock.MockNFTAccessor)
						nftAccessor.SetOwner(positionIdFrom(tt.positionId), stakerAddr)
					}

					position.SetOperator(tt.setupOperator)
				}
				mockInstance.mustUpdatePosition(tt.positionId, position)
				mockInstance.incrementNextId()
			}

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertIsOwnerOrOperatorForToken(mockInstance, tt.positionId, tt.caller)
				})
			} else {
				assertIsOwnerOrOperatorForToken(mockInstance, tt.positionId, tt.caller)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestAssertEqualsAddress(t *testing.T) {
	tests := []struct {
		name                 string
		prevAddr             address
		otherAddr            address
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:        "Valid equal addresses",
			prevAddr:    adminAddr,
			otherAddr:   adminAddr,
			shouldPanic: false,
		},
		{
			name:        "Valid equal addresses - alice",
			prevAddr:    alice,
			otherAddr:   alice,
			shouldPanic: false,
		},
		{
			name:                 "Different addresses",
			prevAddr:             adminAddr,
			otherAddr:            alice,
			expectedPanicMessage: "[GNOSWAP-POSITION-011] invalid address || (g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5, g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh)",
			shouldPanic:          true,
		},
		{
			name:                 "First address is invalid (empty)",
			prevAddr:             "",
			otherAddr:            alice,
			expectedPanicMessage: "invalid address: ",
			shouldPanic:          true,
		},
		{
			name:                 "Second address is invalid (empty)",
			prevAddr:             alice,
			otherAddr:            "",
			expectedPanicMessage: "invalid address: ",
			shouldPanic:          true,
		},
		{
			name:                 "Both addresses are invalid (empty)",
			prevAddr:             "",
			otherAddr:            "",
			expectedPanicMessage: "invalid address: ",
			shouldPanic:          true,
		},
		{
			name:                 "Different valid addresses",
			prevAddr:             bob,
			otherAddr:            "g1charlie",
			expectedPanicMessage: "invalid address: g1charlie",
			shouldPanic:          true,
		},
		{
			name:                 "Same address with different case (should be equal)",
			prevAddr:             "g1alice",
			otherAddr:            "g1alice",
			expectedPanicMessage: "invalid address: g1alice",
			shouldPanic:          true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertEqualsAddress(tt.prevAddr, tt.otherAddr)
				})
			} else {
				assertEqualsAddress(tt.prevAddr, tt.otherAddr)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestAssertValidOperatorAddress(t *testing.T) {
	tests := []struct {
		name                 string
		operator             address
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:        "Valid operator address",
			operator:    alice,
			shouldPanic: false,
		},
		{
			name:        "Valid operator address - admin",
			operator:    adminAddr,
			shouldPanic: false,
		},
		{
			name:        "Empty address - operator removal",
			operator:    address(""),
			shouldPanic: false,
		},
		{
			name:                 "Invalid operator address",
			operator:             address("invalid_address"),
			expectedPanicMessage: "[GNOSWAP-POSITION-011] invalid address || operator(invalid_address)",
			shouldPanic:          true,
		},
		{
			name:                 "Invalid operator address - short",
			operator:             address("g1"),
			expectedPanicMessage: "[GNOSWAP-POSITION-011] invalid address || operator(g1)",
			shouldPanic:          true,
		},
		{
			name:                 "Invalid operator address - malformed",
			operator:             address("not_a_valid_gnosis_address"),
			expectedPanicMessage: "[GNOSWAP-POSITION-011] invalid address || operator(not_a_valid_gnosis_address)",
			shouldPanic:          true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertValidOperatorAddress(tt.operator)
				})
			} else {
				// Should not panic for valid operators
				assertValidOperatorAddress(tt.operator)
			}
		})
	}
}

// TestAssertIsNotMintToStaker covers the guard that prevents users from
// minting a position NFT directly to the staker contract.
func TestAssertIsNotMintToStaker(t *testing.T) {
	tests := []struct {
		name                 string
		mintTo               address
		expectedPanicMessage string
		shouldPanic          bool
	}{
		{
			name:        "regular user address is allowed",
			mintTo:      alice,
			shouldPanic: false,
		},
		{
			name:        "another user address is allowed",
			mintTo:      bob,
			shouldPanic: false,
		},
		{
			name:        "admin address is allowed",
			mintTo:      adminAddr,
			shouldPanic: false,
		},
		{
			// Empty address passes this guard; address validity is the
			// concern of access.AssertIsValidAddress earlier in Mint.
			name:        "empty address is allowed by this guard",
			mintTo:      address(""),
			shouldPanic: false,
		},
		{
			// Core policy: cannot mint directly to the staker contract.
			name:                 "staker address is rejected",
			mintTo:               stakerAddr,
			expectedPanicMessage: "[GNOSWAP-POSITION-015] cannot mint to staker",
			shouldPanic:          true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertIsNotMintToStaker(tt.mintTo)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsNotMintToStaker(tt.mintTo)
				})
			}
		})
	}
}
