package referral

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/r/gnoswap/v1/consts"
)

var (
	validAddr1  = testutils.TestAddress("valid1")
	validAddr2  = testutils.TestAddress("valid2")
	invalidAddr = testutils.TestAddress("invalid")
)

func setupKeeper() *keeper { return NewKeeper().(*keeper) }

func mockValidCaller() func() {
	origCaller := std.GetOrigCaller()
	std.TestSetOrigCaller(consts.ROUTER_ADDR)
	return func() {
		std.TestSetOrigCaller(origCaller)
	}
}

func TestRegister(t *testing.T) {
	tests := []struct {
		name        string
		addr        std.Address
		refAddr     std.Address
		setupCaller func() func()
		wantErr     bool
		errCode     int
	}{
		{
			name:        "valid registration",
			addr:        validAddr1,
			refAddr:     validAddr2,
			setupCaller: mockValidCaller,
			wantErr:     false,
		},
		{
			name:    "unauthorized caller",
			addr:    validAddr1,
			refAddr: validAddr2,
			setupCaller: func() func() {
				origCaller := std.GetOrigCaller()
				std.TestSetOrigCaller(std.Address("unauthorized"))
				return func() {
					std.TestSetOrigCaller(origCaller)
				}
			},
			wantErr: true,
			errCode: ErrUnauthorized,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			k := setupKeeper()
			cleanup := tt.setupCaller()
			defer cleanup()

			err := k.register(tt.addr, tt.refAddr)

			if tt.wantErr {
				if err == nil {
					t.Errorf("register() error = nil, wantErr %v", tt.wantErr)
					return
				}
				referralErr, ok := err.(*ReferralError)
				if !ok {
					t.Errorf("register() error is not ReferralError type")
					return
				}
				if referralErr.Code != tt.errCode {
					t.Errorf("register() error code = %v, want %v", referralErr.Code, tt.errCode)
				}
			} else if err != nil {
				t.Errorf("register() unexpected error = %v", err)
			}
		})
	}
}

func TestUpdate(t *testing.T) {
	tests := []struct {
		name        string
		addr        std.Address
		refAddr     std.Address
		setupState  func(*keeper)
		setupCaller func() func()
		wantErr     bool
		errCode     int
	}{
		{
			name:    "valid update",
			addr:    validAddr1,
			refAddr: validAddr2,
			setupState: func(k *keeper) {
				k.store.Set(validAddr1.String(), "old_ref_addr")
			},
			setupCaller: mockValidCaller,
			wantErr:     false,
		},
		{
			name:        "update non-existent referral",
			addr:        validAddr1,
			refAddr:     validAddr2,
			setupState:  func(k *keeper) {},
			setupCaller: mockValidCaller,
			wantErr:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			k := setupKeeper()
			tt.setupState(k)
			cleanup := tt.setupCaller()
			defer cleanup()

			err := k.update(tt.addr, tt.refAddr)

			if tt.wantErr {
				if err == nil {
					t.Errorf("update() error = nil, wantErr %v", tt.wantErr)
					return
				}
				referralErr, ok := err.(*ReferralError)
				if !ok {
					t.Errorf("update() error is not ReferralError type")
					return
				}
				if referralErr.Code != tt.errCode {
					t.Errorf("update() error code = %v, want %v", referralErr.Code, tt.errCode)
				}
			} else if err != nil {
				t.Errorf("update() unexpected error = %v", err)
			}
		})
	}
}

func TestGet(t *testing.T) {
	tests := []struct {
		name       string
		addr       std.Address
		setupState func(*keeper)
		wantAddr   std.Address
		wantErr    bool
		errCode    int
	}{
		{
			name: "get existing referral",
			addr: validAddr1,
			setupState: func(k *keeper) {
				k.store.Set(validAddr1.String(), validAddr2.String())
			},
			wantAddr: validAddr2,
			wantErr:  false,
		},
		{
			name:       "get non-existent referral",
			addr:       validAddr1,
			setupState: func(k *keeper) {},
			wantAddr:   zeroAddress,
			wantErr:    true,
			errCode:    ErrNotFound,
		},
		{
			name:       "get with invalid address",
			addr:       invalidAddr,
			setupState: func(k *keeper) {},
			wantAddr:   zeroAddress,
			wantErr:    true,
			errCode:    ErrNotFound,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			k := setupKeeper()
			tt.setupState(k)

			gotAddr, err := k.get(tt.addr)

			if tt.wantErr {
				if err == nil {
					t.Errorf("get() error = nil, wantErr %v", tt.wantErr)
					return
				}
				referralErr, ok := err.(*ReferralError)
				if !ok {
					t.Errorf("get() error is not ReferralError type")
					return
				}
				if referralErr.Code != tt.errCode {
					t.Errorf("get() error code = %v, want %v", referralErr.Code, tt.errCode)
				}
			} else {
				if err != nil {
					t.Errorf("get() unexpected error")
					return
				}
				if gotAddr != tt.wantAddr {
					t.Errorf("get() gotAddr = %v, want %v", gotAddr, tt.wantAddr)
				}
			}
		})
	}
}

func TestHas(t *testing.T) {
	tests := []struct {
		name       string
		addr       std.Address
		setupState func(*keeper)
		want       bool
	}{
		{
			name: "has existing referral",
			addr: validAddr1,
			setupState: func(k *keeper) {
				k.store.Set(validAddr1.String(), validAddr2.String())
			},
			want: true,
		},
		{
			name:       "does not have referral",
			addr:       validAddr1,
			setupState: func(k *keeper) {},
			want:       false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			k := setupKeeper()
			tt.setupState(k)

			if got := k.has(tt.addr); got != tt.want {
				t.Errorf("has() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestRemove(t *testing.T) {
	tests := []struct {
		name        string
		addr        std.Address
		setupState  func(*keeper)
		setupCaller func() func()
		wantErr     bool
		errCode     int
	}{
		{
			name: "remove existing referral",
			addr: validAddr1,
			setupState: func(k *keeper) {
				k.store.Set(validAddr1.String(), validAddr2.String())
			},
			setupCaller: mockValidCaller,
			wantErr:     false,
		},
		{
			name:        "remove non-existent referral",
			addr:        validAddr1,
			setupState:  func(k *keeper) {},
			setupCaller: mockValidCaller,
			wantErr:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			k := setupKeeper()
			tt.setupState(k)
			cleanup := tt.setupCaller()
			defer cleanup()

			err := k.remove(tt.addr)

			if tt.wantErr {
				if err == nil {
					t.Errorf("remove() error = nil, wantErr %v", tt.wantErr)
					return
				}
				referralErr, ok := err.(*ReferralError)
				if !ok {
					t.Errorf("remove() error is not ReferralError type")
					return
				}
				if referralErr.Code != tt.errCode {
					t.Errorf("remove() error code = %v, want %v", referralErr.Code, tt.errCode)
				}
			} else if err != nil {
				t.Errorf("remove() unexpected error = %v", err)
			}

			// 삭제 후 has() 호출로 실제 삭제 되었는지 확인
			if k.has(tt.addr) {
				t.Errorf("remove() referral still exists after removal")
			}
		})
	}
}
