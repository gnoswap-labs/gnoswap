package access

import (
	"std"

	"gno.land/p/gnoswap/consts"
)

// initial addresses
const (
	ADMIN   std.Address = "g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d"
	DEV_OPS std.Address = "g1mjvd83nnjee3z2g7683er55me9f09688pd4mj9"

	COMMUNITY_POOL_ADDR std.Address = "g100fnnlz5eh87p5hvwt8pf279lxaelm8k8md049"
	GOV_GOVERNANCE_ADDR std.Address = "g17s8w2ve7k85fwfnrk59lmlhthkjdted8whvqxd"
	GOV_STAKER_ADDR     std.Address = "g17e3ykyqk9jmqe2y9wxe9zhep3p7cw56davjqwa"
	GOV_XGNS_ADDR       std.Address = "g1wwh55uwzlz2zzr2qcvvxf83qhcvmx2t8779l9r"

	POOL_ADDR     std.Address = "g148tjamj80yyrm309z7rk690an22thd2l3z8ank"
	POSITION_ADDR std.Address = "g1q646ctzhvn60v492x8ucvyqnrj2w30cwh6efk5"
	ROUTER_ADDR   std.Address = "g1lm2l7tf49h3mykesct7rhfml30yx8dw5xrval7"
	STAKER_ADDR   std.Address = "g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu"

	EMISSION_ADDR     std.Address = "g10xg6559w9e93zfttlhvdmaaa0er3zewcr7nh20"
	LAUNCHPAD_ADDR    std.Address = "g122mau2lp2rc0scs8d27pkkuys4w54mdy2tuer3"
	PROTOCOL_FEE_ADDR std.Address = "g1f7wpek7q67tkns27sw495u5yuu3a5wwjxw5l6l"
)

// Pre-defined role kinds (follows the each contract's name)
const (
	ROLE_ADMIN          = "admin"
	ROLE_COMMUNITY_POOL = "community_pool"
	ROLE_DEVOPS         = "devops"
	ROLE_GOVERNANCE     = "governance"
	ROLE_GOV_STAKER     = "gov_staker"
	ROLE_ROUTER         = "router"
	ROLE_POOL           = "pool"
	ROLE_POSITION       = "position"
	ROLE_STAKER         = "staker"
	ROLE_LAUNCHPAD      = "launchpad"
	ROLE_EMISSION       = "emission"
	ROLE_PROTOCOL_FEE   = "protocol_fee"
	ROLE_GOV_XGNS       = "xgns"

	PERM_ACCESS = "access" // Permission name for access control
)

// initializeDefaultRoles initializes the default roles with their corresponding addresses from consts
// dependent with the gnoswap contracts.
func initializeDefaultRoles() (*config, error) {
	cfg := newConfig()

	// Set up roles with their corresponding addresses from consts
	defaultRoles := map[string]std.Address{
		ROLE_ADMIN:          ADMIN,
		ROLE_COMMUNITY_POOL: COMMUNITY_POOL_ADDR,
		ROLE_DEVOPS:         DEV_OPS,
		ROLE_GOVERNANCE:     GOV_GOVERNANCE_ADDR,
		ROLE_GOV_STAKER:     GOV_STAKER_ADDR,
		ROLE_ROUTER:         ROUTER_ADDR,
		ROLE_POOL:           POOL_ADDR,
		ROLE_POSITION:       POSITION_ADDR,
		ROLE_STAKER:         STAKER_ADDR,
		ROLE_LAUNCHPAD:      LAUNCHPAD_ADDR,
		ROLE_EMISSION:       EMISSION_ADDR,
		ROLE_PROTOCOL_FEE:   PROTOCOL_FEE_ADDR,
		ROLE_GOV_XGNS:       GOV_XGNS_ADDR,
	}

	cfg.roles = defaultRoles
	return cfg, initialize(cfg)
}
