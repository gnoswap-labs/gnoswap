package callback

import (
	"chain/runtime"
)

var adminAddr address = "g1admin0000000000000000000000000000000000"

type VulnerableVault struct {
	balance    int64
	adminKey   string
	lastCaller string
	lastRealm  string
}

type VulnerableCallbackType func(cur realm, amount int64) (string, string, error)

var vulnerableVault *VulnerableVault

func init() {
	vulnerableVault = &VulnerableVault{
		balance:    1000,
		adminKey:   "super_secret_key_12345",
		lastCaller: "",
		lastRealm:  "",
	}
}

func ResetVulnerableVault() {
	vulnerableVault.resetState()
}

func (v *VulnerableVault) resetState() {
	v.balance = 1000
	v.adminKey = "super_secret_key_12345"
	v.lastCaller = ""
	v.lastRealm = ""
}

func AdminResetBalance(cur realm, amount int64) (string, string, error) {
	caller := runtime.CurrentRealm().Address().String()
	pkgPath := runtime.CurrentRealm().PkgPath()

	vulnerableVault.setLastCaller(caller)
	vulnerableVault.setLastRealm(pkgPath)
	vulnerableVault.setBalance(999999)
	vulnerableVault.setAdminKey("ADMIN_RESET")

	return caller, pkgPath, nil
}

func LegitimateCallback(cur realm, amount int64) (string, string, error) {
	caller := runtime.CurrentRealm().Address().String()
	pkgPath := runtime.CurrentRealm().PkgPath()

	vulnerableVault.setLastCaller(caller)
	vulnerableVault.setLastRealm(pkgPath)

	return caller, pkgPath, nil
}

func VulnerableWithdraw(amount int64, callback VulnerableCallbackType) (string, string, error) {
	if amount > vulnerableVault.balance {
		panic("insufficient balance")
	}
	vulnerableVault.deductBalance(amount)

	return callback(cross, amount)
}

func (v *VulnerableVault) setBalance(balance int64) {
	v.balance = balance
}

func (v *VulnerableVault) deductBalance(amount int64) {
	v.balance -= amount
}

func (v *VulnerableVault) setAdminKey(key string) {
	v.adminKey = key
}

func (v *VulnerableVault) setLastCaller(caller string) {
	v.lastCaller = caller
}

func (v *VulnerableVault) setLastRealm(realm string) {
	v.lastRealm = realm
}

func GetVulnerableBalance() int64 {
	return vulnerableVault.balance
}

func GetAdminKey() string {
	return vulnerableVault.adminKey
}

func GetLastCaller() string {
	return vulnerableVault.lastCaller
}

func GetLastRealm() string {
	return vulnerableVault.lastRealm
}

func GetAdminAddr() string {
	return adminAddr.String()
}
