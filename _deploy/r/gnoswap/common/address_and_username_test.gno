package common

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	pusers "gno.land/p/demo/users"
)

func TestAddrToUser(t *testing.T) {
	tests := []struct {
		name        string
		addr        std.Address
		want        pusers.AddressOrName
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "valid address",
			addr: std.Address("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"),
			want: pusers.AddressOrName("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"),
		},
		{
			name:        "empty address",
			addr:        std.Address(""),
			shouldPanic: true,
			panicMsg:    `[GNOSWAP-COMMON-005] invalid address || `,
		},
		{
			name:        "invalid address",
			addr:        std.Address("invalid"),
			shouldPanic: true,
			panicMsg:    `[GNOSWAP-COMMON-005] invalid address || invalid`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					AddrToUser(tt.addr)
				})
			} else {
				got := AddrToUser(tt.addr)
				if got != tt.want {
					t.Errorf("AddrToUser() = %v, want %v", got, tt.want)
				}
			}
		})
	}
}

func TestUserToAddr(t *testing.T) {
	tests := []struct {
		name string
		user pusers.AddressOrName
		want std.Address
	}{
		{
			name: "address string with user type",
			user: pusers.AddressOrName("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"),
			want: std.Address("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := UserToAddr(tt.user)
			if got != tt.want {
				t.Errorf("UserToAddr() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestAssertValidAddr(t *testing.T) {
	tests := []struct {
		name        string
		addr        std.Address
		shouldPanic bool
		panicMsg    string
	}{
		{
			name: "valid address",
			addr: std.Address("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"),
		},
		{
			name:        "empty address",
			addr:        std.Address(""),
			shouldPanic: true,
			panicMsg:    `[GNOSWAP-COMMON-005] invalid address || `,
		},
		{
			name:        "invalid address",
			addr:        std.Address("invalid"),
			shouldPanic: true,
			panicMsg:    `[GNOSWAP-COMMON-005] invalid address || invalid`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					assertValidAddr(tt.addr)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertValidAddr(tt.addr)
				})
			}
		})
	}
}
