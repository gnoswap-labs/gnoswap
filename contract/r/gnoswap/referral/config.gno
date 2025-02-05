package referral

type Config struct {
	enabled  bool
	referral *Referral
}

// NewConfig creates a new referral config instance.
func NewConfig() *Config {
	return &Config{
		enabled:  false,
		referral: nil,
	}
}

func (c *Config) IsEnabled() bool     { return c.enabled }
func (c *Config) Referral() *Referral { return c.referral }

// Enable enables the referral system.
func (c *Config) Enable() {
	c.enabled = true
	c.referral = NewReferral()
}

// Disable disables the referral system.
func (c *Config) Disable() {
	c.enabled = false
	c.referral = nil
}
