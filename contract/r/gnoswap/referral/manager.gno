package referral

import "std"

const (
	referralRegistered     = "ReferralRegistered"
	referralRegisterFailed = "ReferralRegisterFailed"
)

// Manager handles referral registration with configuration
type Manager struct {
	config *Config
}

// NewManager creates a new referral manager instance
func NewManager() *Manager {
	return &Manager{
		config: NewConfig(),
	}
}

func (m *Manager) Enable() {
	m.config.Enable()
}

func (m *Manager) Disable() {
	m.config.Disable()
}

// TryRegisterReferral attempts to register a referral relationship if conditions are met.
// This is a no-op if:
//   - Referral system is disabled
//   - Referrer address is empty
//   - User already has a referrer
func (m *Manager) TryRegisterReferral(user, referral std.Address) {
	// skip if referral is disabled or referrer address is empty
	if !m.config.IsEnabled() || referral.String() == "" {
		return
	}

	ref := m.config.Referral()
	if ref.Has(user) {
		return
	}

	emitParams := []string{
		"user", user.String(),
		"referral", referral.String(),
	}

	err := ref.Register(user, referral)
	if err != nil {
		std.Emit(referralRegisterFailed, emitParams...)
		return
	}

	std.Emit(referralRegistered, emitParams...)
}

func (m *Manager) IsEnabled() bool {
	return m.config.IsEnabled()
}
