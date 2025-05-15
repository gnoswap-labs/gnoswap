package governance

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/gns"

	"gno.land/r/gnoswap/v1/access"
	cp "gno.land/r/gnoswap/v1/community_pool"
	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
	pf "gno.land/r/gnoswap/v1/protocol_fee"
	rr "gno.land/r/gnoswap/v1/router"
	sr "gno.land/r/gnoswap/v1/staker"

	"gno.land/r/gnoswap/v1/halt"

	"gno.land/p/demo/ufmt"
)

// HandlerConfig defines the configuration for each handler
type HandlerConfig struct {
	PkgPath     string
	Function    string
	ParamCount  int
	HandlerFunc func([]string) error
}

// registerHandlers registers all configured handlers at once
func registerHandlers(registry *ParameterRegistry, configs []HandlerConfig) {
	for _, config := range configs {
		func(config HandlerConfig) {
			registry.Register(config.PkgPath, config.Function, NewFunctionHandler(func(params []string) error {
				if err := hasDesiredParams(params, config.ParamCount); err != nil {
					return err
				}
				return config.HandlerFunc(params)
			}))
		}(config) // avoid closure problem
	}
}

// helper functions to return h with error
func simpleHandler(fn func([]string)) func([]string) error {
	return func(params []string) error {
		fn(params)
		return nil
	}
}

func createParameterHandlers() *ParameterRegistry {
	registry := NewParameterRegistry()

	// define all handler configurations in one array
	handlers := []HandlerConfig{
		// Common
		{
			PkgPath:    consts.COMMON_PATH,
			Function:   "SetHalt",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				halt.SetHalt(parseBool(params[0])) // halt
			}),
		},

		// Community pool
		{
			PkgPath:    consts.COMMUNITY_POOL_PATH,
			Function:   "TransferToken",
			ParamCount: 3,
			HandlerFunc: simpleHandler(func(params []string) {
				cp.TransferToken(
					params[0],              // pkgPath
					std.Address(params[1]), // to
					parseUint64(params[2]), // amount
				)
			}),
		},

		// Emission
		{
			PkgPath:    consts.EMISSION_PATH,
			Function:   "ChangeDistributionPct",
			ParamCount: 8,
			HandlerFunc: simpleHandler(func(params []string) {
				en.ChangeDistributionPct(
					parseInt(params[0]),    // target01
					parseUint64(params[1]), // pct01
					parseInt(params[2]),    // target02
					parseUint64(params[3]), // pct02
					parseInt(params[4]),    // target03
					parseUint64(params[5]), // pct03
					parseInt(params[6]),    // target04
					parseUint64(params[7]), // pct04
				)
			}),
		},

		// GNS Path
		{
			PkgPath:    consts.GNS_PATH,
			Function:   "SetAvgBlockTimeInMs",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				blockTime, err := strconv.ParseInt(params[0], 10, 64)
				if err != nil {
					panic(err)
				}
				gns.SetAvgBlockTimeInMs(blockTime)
			}),
		},

		// Governance Path
		{
			PkgPath:    consts.GOV_GOVERNANCE_PATH,
			Function:   "Reconfigure",
			ParamCount: 7,
			HandlerFunc: simpleHandler(func(params []string) {
				reconfigure(
					parseUint64(params[0]), // votingStartDelay
					parseUint64(params[1]), // votingPeriod
					parseUint64(params[2]), // votingWeightSmoothingDuration
					parseUint64(params[3]), // quorum
					parseUint64(params[4]), // proposalCreationhold
					parseUint64(params[5]), // executionDelay
					parseUint64(params[6]), // executionWindow
				)
			}),
		},

		// Pool Path
		{
			PkgPath:    consts.POOL_PATH,
			Function:   "SetFeeProtocol",
			ParamCount: 2,
			HandlerFunc: simpleHandler(func(params []string) {
				feeProtocol0 := parseUint64(params[0])
				feeProtocol1 := parseUint64(params[1])
				if feeProtocol0 > 255 {
					panic(ufmt.Sprintf("feeProtocol0 out of range: %d", feeProtocol0))
				}
				if feeProtocol1 > 255 {
					panic(ufmt.Sprintf("feeProtocol1 out of range: %d", feeProtocol1))
				}
				pl.SetFeeProtocol(
					uint8(feeProtocol0), // feeProtocol0
					uint8(feeProtocol1), // feeProtocol1
				)
			}),
		},
		{
			PkgPath:    consts.POOL_PATH,
			Function:   "SetPoolCreationFee",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				pl.SetPoolCreationFee(parseUint64(params[0])) // fee
			}),
		},
		{
			PkgPath:    consts.POOL_PATH,
			Function:   "SetWithdrawalFee",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				pl.SetWithdrawalFee(parseUint64(params[0])) // fee
			}),
		},

		// Protocol fee
		{
			PkgPath:    consts.PROTOCOL_FEE_PATH,
			Function:   "SetDevOpsPct",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				pf.SetDevOpsPct(parseUint64(params[0])) // pct
			}),
		},

		// Router
		{
			PkgPath:    consts.ROUTER_PATH,
			Function:   "SetSwapFee",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				rr.SetSwapFee(parseUint64(params[0])) // fee
			}),
		},

		// Staker
		{
			PkgPath:    consts.STAKER_PATH,
			Function:   "SetDepositGnsAmount",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				sr.SetDepositGnsAmount(parseUint64(params[0])) // amount
			}),
		},
		{
			PkgPath:    consts.STAKER_PATH,
			Function:   "SetPoolTier",
			ParamCount: 2,
			HandlerFunc: simpleHandler(func(params []string) {
				sr.SetPoolTier(
					params[0],              // pool
					parseUint64(params[1]), // tier
				)
			}),
		},
		{
			PkgPath:    consts.STAKER_PATH,
			Function:   "ChangePoolTier",
			ParamCount: 2,
			HandlerFunc: simpleHandler(func(params []string) {
				sr.ChangePoolTier(
					params[0],              // pool
					parseUint64(params[1]), // tier
				)
			}),
		},
		{
			PkgPath:    consts.STAKER_PATH,
			Function:   "RemovePoolTier",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				sr.RemovePoolTier(params[0]) // pool
			}),
		},
		{
			PkgPath:    consts.STAKER_PATH,
			Function:   "SetUnStakingFee",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				sr.SetUnStakingFee(parseUint64(params[0]))
			}),
		},
		{
			PkgPath:    consts.STAKER_PATH,
			Function:   "SetWarmUp",
			ParamCount: 2,
			HandlerFunc: simpleHandler(func(params []string) {
				percent, err := strconv.ParseInt(params[0], 10, 64)
				if err != nil {
					panic(err)
				}
				block, err := strconv.ParseInt(params[1], 10, 64)
				if err != nil {
					panic(err)
				}
				sr.SetWarmUp(percent, block)
			}),
		},

		// Access
		{
			PkgPath:    consts.ACCESS_PATH,
			Function:   "CreateRole",
			ParamCount: 2,
			HandlerFunc: simpleHandler(func(params []string) {
				addr := std.Address(params[1])
				if !addr.IsValid() {
					panic(ufmt.Sprintf("invalid address: %s", params[1]))
				}

				roleName := params[0]
				access.CreateRole(roleName, addr)
			}),
		},
		{
			PkgPath:    consts.ACCESS_PATH,
			Function:   "SetRole",
			ParamCount: 2,
			HandlerFunc: simpleHandler(func(params []string) {
				addr := std.Address(params[1])
				if !addr.IsValid() {
					panic(ufmt.Sprintf("invalid address: %s", params[1]))
				}

				roleName := params[0]
				access.SetRole(roleName, addr)
			}),
		},
		{
			PkgPath:    consts.ACCESS_PATH,
			Function:   "UpdateRoleAddress",
			ParamCount: 2,
			HandlerFunc: simpleHandler(func(params []string) {
				addr := std.Address(params[1])
				if !addr.IsValid() {
					panic(ufmt.Sprintf("invalid address: %s", params[1]))
				}

				roleName := params[0]
				access.UpdateRoleAddress(roleName, addr)
			}),
		},

		// halt
		{
			PkgPath:    consts.HALT_PATH,
			Function:   "SetHalt",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				halt.SetHalt(parseBool(params[0])) // true = halt, false = no halt
			}),
		},
		{
			PkgPath:    consts.HALT_PATH,
			Function:   "SetHaltWithLevel",
			ParamCount: 2,
			HandlerFunc: func(params []string) error {
				haltStatus := parseBool(params[0])
				levels := make([]halt.LevelID, 0)
				for _, level := range strings.Split(params[1], ",") {
					levelID, err := halt.LevelIDFromString(level)
					if err != nil {
						return err
					}
					levels = append(levels, levelID)
				}
				return halt.SetHalt(haltStatus, levels...)
			},
		},
		{
			PkgPath:    consts.HALT_PATH,
			Function:   "SetHaltLevel",
			ParamCount: 1,
			HandlerFunc: func(params []string) error {
				haltLevel, err := halt.LevelIDFromString(params[0])
				if err != nil {
					return err
				}
				return halt.SetHaltLevel(haltLevel)
			},
		},
		{
			PkgPath:    consts.HALT_PATH,
			Function:   "SetOperationStatus",
			ParamCount: 2,
			HandlerFunc: func(params []string) error {
				opType := halt.OpType(params[0])
				allowed := parseBool(params[1])
				return halt.SetOperationStatus(opType, allowed)
			},
		},
		{
			PkgPath:    consts.HALT_PATH,
			Function:   "EnableWithdrawals",
			ParamCount: 0,
			HandlerFunc: func(params []string) error {
				return halt.EnableWithdrawalsForTestnet()
			},
		},
		{
			PkgPath:    consts.HALT_PATH,
			Function:   "EnableContractOperations",
			ParamCount: 1,
			HandlerFunc: func(params []string) error {
				contract := halt.OpType(params[0])
				return halt.EnableContractOperations(contract)
			},
		},
		{
			PkgPath:    consts.HALT_PATH,
			Function:   "DisableContractOperations",
			ParamCount: 1,
			HandlerFunc: func(params []string) error {
				contract := halt.OpType(params[0])
				return halt.DisableContractOperations(contract)
			},
		},
	}

	// apply all handlers at once
	registerHandlers(registry, handlers)

	return registry
}
