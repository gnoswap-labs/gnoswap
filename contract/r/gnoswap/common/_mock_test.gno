package common

import (
	"gno.land/p/nt/grc20/v0"
	"gno.land/r/nt/grc20reg/v0"
)

// MockCommon is a versioned mock that serves a fixed key set with a fixed balance.
type MockCommon struct {
	Version  string
	balances map[string]int64
}

func NewMockCommon(version string, keys ...string) *MockCommon {
	m := &MockCommon{Version: version, balances: make(map[string]int64)}
	for i, key := range keys {
		m.balances[key] = int64(1000 * (i + 1))
	}
	return m
}

func (m *MockCommon) IsRegistered(tokenKey string) bool {
	_, ok := m.balances[tokenKey]
	return ok
}

func (m *MockCommon) TotalSupply(tokenKey string) int64 { return m.balances[tokenKey] }
func (m *MockCommon) BalanceOf(tokenKey string, addr address) int64 {
	return m.balances[tokenKey]
}

func (m *MockCommon) Allowance(tokenKey string, owner, spender address) int64 { return 0 }
func (m *MockCommon) Transfer(_ int, rlm realm, tokenKey string, to address, amount int64) error {
	return nil
}

func (m *MockCommon) TransferFrom(_ int, rlm realm, tokenKey string, from, to address, amount int64) error {
	return nil
}

func (m *MockCommon) Approve(_ int, rlm realm, tokenKey string, spender address, amount int64) error {
	return nil
}

func makeMockInitializer(version string, keys ...string) func(_ int, rlm realm) ICommon {
	return func(_ int, rlm realm) ICommon {
		return NewMockCommon(version, keys...)
	}
}

// MockGrc20regCommon mirrors common/v1 against grc20reg so the helper tests
// exercise real GRC20 tokens without importing common/v1.
type MockGrc20regCommon struct{}

func (m *MockGrc20regCommon) IsRegistered(tokenKey string) bool {
	return grc20reg.Get(tokenKey) != nil
}

func (m *MockGrc20regCommon) TotalSupply(tokenKey string) int64 {
	return m.mustGetToken(tokenKey).TotalSupply()
}

func (m *MockGrc20regCommon) BalanceOf(tokenKey string, addr address) int64 {
	return m.mustGetToken(tokenKey).BalanceOf(addr)
}

func (m *MockGrc20regCommon) Allowance(tokenKey string, owner, spender address) int64 {
	return m.mustGetToken(tokenKey).Allowance(owner, spender)
}

func (m *MockGrc20regCommon) Transfer(_ int, rlm realm, tokenKey string, to address, amount int64) error {
	return m.mustGetToken(tokenKey).RealmTeller(0, rlm).Transfer(0, rlm, to, amount)
}

func (m *MockGrc20regCommon) TransferFrom(_ int, rlm realm, tokenKey string, from, to address, amount int64) error {
	return m.mustGetToken(tokenKey).RealmTeller(0, rlm).TransferFrom(0, rlm, from, to, amount)
}

func (m *MockGrc20regCommon) Approve(_ int, rlm realm, tokenKey string, spender address, amount int64) error {
	return m.mustGetToken(tokenKey).RealmTeller(0, rlm).Approve(0, rlm, spender, amount)
}

func (m *MockGrc20regCommon) mustGetToken(tokenKey string) *grc20.Token {
	token := grc20reg.Get(tokenKey)
	if token == nil {
		panic("unknown token(" + tokenKey + ")")
	}
	return token
}
