package callback

import (
	"chain/runtime"
)

type CallbackMarker struct{}

type SecureVault struct {
	balance    int64
	adminKey   string
	lastCaller string
	lastRealm  string
}

type SecureCallbackType func(cur realm, amount int64, marker *CallbackMarker) (string, string, error)

var secureVault *SecureVault

func init() {
	secureVault = &SecureVault{
		balance:    1000,
		adminKey:   "super_secret_key_12345",
		lastCaller: "",
		lastRealm:  "",
	}
}

func ResetSecureVault() {
	secureVault.resetState()
}

func (v *SecureVault) resetState() {
	v.balance = 1000
	v.adminKey = "super_secret_key_12345"
	v.lastCaller = ""
	v.lastRealm = ""
}

func SecureAdminResetBalance(cur realm, amount int64) (string, string, error) {
	caller := runtime.CurrentRealm().Address().String()
	pkgPath := runtime.CurrentRealm().PkgPath()

	secureVault.setLastCaller(caller)
	secureVault.setLastRealm(pkgPath)
	secureVault.setBalance(999999)
	secureVault.setAdminKey("ADMIN_RESET")

	return caller, pkgPath, nil
}

func SecureLegitimateCallback(cur realm, amount int64, marker *CallbackMarker) (string, string, error) {
	caller := runtime.CurrentRealm().Address().String()
	pkgPath := runtime.CurrentRealm().PkgPath()

	if marker == nil {
		panic("invalid callback marker")
	}

	secureVault.setLastCaller(caller)
	secureVault.setLastRealm(pkgPath)

	return caller, pkgPath, nil
}

func SecureWithdraw(amount int64, callback SecureCallbackType) (string, string, error) {
	if amount > secureVault.balance {
		panic("insufficient balance")
	}
	secureVault.deductBalance(amount)

	return callback(cross, amount, &CallbackMarker{})
}

func (v *SecureVault) setBalance(balance int64) {
	v.balance = balance
}

func (v *SecureVault) deductBalance(amount int64) {
	v.balance -= amount
}

func (v *SecureVault) setAdminKey(key string) {
	v.adminKey = key
}

func (v *SecureVault) setLastCaller(caller string) {
	v.lastCaller = caller
}

func (v *SecureVault) setLastRealm(realm string) {
	v.lastRealm = realm
}

func GetSecureBalance() int64 {
	return secureVault.balance
}

func GetSecureAdminKey() string {
	return secureVault.adminKey
}

func GetSecureLastCaller() string {
	return secureVault.lastCaller
}

func GetSecureLastRealm() string {
	return secureVault.lastRealm
}
