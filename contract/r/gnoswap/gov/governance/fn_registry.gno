package governance

import (
	"std"
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
				cross(halt.SetHalt)(parseBool(params[0])) // halt
			}),
		},

		// Community pool
		{
			PkgPath:    consts.COMMUNITY_POOL_PATH,
			Function:   "TransferToken",
			ParamCount: 3,
			HandlerFunc: simpleHandler(func(params []string) {
				cross(cp.TransferToken)(
					params[0],              // pkgPath
					std.Address(params[1]), // to
					parseNumber(params[2], kindInt64).(int64), // amount
				)
			}),
		},

		// Emission
		{
			PkgPath:    consts.EMISSION_PATH,
			Function:   "ChangeDistributionPct",
			ParamCount: 8,
			HandlerFunc: simpleHandler(func(params []string) {
				target01 := parseNumber(params[0], kindInt).(int)    // target01
				pct01 := parseNumber(params[1], kindInt64).(int64) // pct01
				target02 := parseNumber(params[2], kindInt).(int)    // target02
				pct02 := parseNumber(params[3], kindInt64).(int64) // pct02
				target03 := parseNumber(params[4], kindInt).(int)    // target03
				pct03 := parseNumber(params[5], kindInt64).(int64) // pct03
				target04 := parseNumber(params[6], kindInt).(int)    // target04
				pct04 := parseNumber(params[7], kindInt64).(int64) // pct04
				cross(en.ChangeDistributionPct)(
					target01,    // target01
					pct01,        // pct01
					target02,    // target02
					pct02,        // pct02
					target03,    // target03
					pct03,        // pct03
					target04,    // target04
					pct04,        // pct04
				)
			}),
		},

		// GNS Path
		{
			PkgPath:    consts.GNS_PATH,
			Function:   "SetAvgBlockTimeInMs",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				blockTime := parseNumber(params[0], kindInt64).(int64)
				cross(gns.SetAvgBlockTimeInMs)(blockTime)
			}),
		},

		// Governance Path
		{
			PkgPath:    consts.GOV_GOVERNANCE_PATH,
			Function:   "Reconfigure",
			ParamCount: 7,
			HandlerFunc: simpleHandler(func(params []string) {
				votingStartDelay := parseNumber(params[0], kindUint64).(uint64) // votingStartDelay
				votingPeriod := parseNumber(params[1], kindUint64).(uint64)     // votingPeriod
				votingWeightSmoothingDuration := parseNumber(params[2], kindUint64).(uint64) // votingWeightSmoothingDuration
				quorum := parseNumber(params[3], kindUint64).(uint64)           // quorum
				proposalCreationhold := parseNumber(params[4], kindUint64).(uint64) // proposalCreationhold
				executionDelay := parseNumber(params[5], kindUint64).(uint64)   // executionDelay
				executionWindow := parseNumber(params[6], kindUint64).(uint64)  // executionWindow
				reconfigure(
					votingStartDelay, // votingStartDelay
					votingPeriod,     // votingPeriod
					votingWeightSmoothingDuration, // votingWeightSmoothingDuration
					quorum,           // quorum
					proposalCreationhold, // proposalCreationhold
					executionDelay,   // executionDelay
					executionWindow,  // executionWindow
				)
			}),
		},

		// Pool Path
		{
			PkgPath:    consts.POOL_PATH,
			Function:   "SetFeeProtocol",
			ParamCount: 2,
			HandlerFunc: simpleHandler(func(params []string) {
				feeProtocol0 := parseNumber(params[0], kindUint64).(uint64)
				feeProtocol1 := parseNumber(params[1], kindUint64).(uint64)
				if feeProtocol0 > 255 {
					panic(ufmt.Sprintf("feeProtocol0 out of range: %d", feeProtocol0))
				}
				if feeProtocol1 > 255 {
					panic(ufmt.Sprintf("feeProtocol1 out of range: %d", feeProtocol1))
				}
				cross(pl.SetFeeProtocol)(
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
				cross(pl.SetPoolCreationFee)(parseNumber(params[0], kindInt64).(int64)) // fee
			}),
		},
		{
			PkgPath:    consts.POOL_PATH,
			Function:   "SetWithdrawalFee",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				cross(pl.SetWithdrawalFee)(parseNumber(params[0], kindUint64).(uint64)) // fee
			}),
		},

		// Protocol fee
		{
			PkgPath:    consts.PROTOCOL_FEE_PATH,
			Function:   "SetDevOpsPct",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				cross(pf.SetDevOpsPct)(parseNumber(params[0], kindUint64).(uint64)) // pct
			}),
		},

		// Router
		{
			PkgPath:    consts.ROUTER_PATH,
			Function:   "SetSwapFee",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				cross(rr.SetSwapFee)(parseNumber(params[0], kindUint64).(uint64)) // fee
			}),
		},

		// Staker
		{
			PkgPath:    consts.STAKER_PATH,
			Function:   "SetDepositGnsAmount",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				cross(sr.SetDepositGnsAmount)(parseNumber(params[0], kindInt64).(int64)) // amount
			}),
		},
		{
			PkgPath:    consts.STAKER_PATH,
			Function:   "SetPoolTier",
			ParamCount: 2,
			HandlerFunc: simpleHandler(func(params []string) {
				cross(sr.SetPoolTier)(
					params[0],              // pool
					parseNumber(params[1], kindUint64).(uint64), // tier
				)
			}),
		},
		{
			PkgPath:    consts.STAKER_PATH,
			Function:   "ChangePoolTier",
			ParamCount: 2,
			HandlerFunc: simpleHandler(func(params []string) {
				cross(sr.ChangePoolTier)(
					params[0],              // pool
					parseNumber(params[1], kindUint64).(uint64), // tier
				)
			}),
		},
		{
			PkgPath:    consts.STAKER_PATH,
			Function:   "RemovePoolTier",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				cross(sr.RemovePoolTier)(params[0]) // pool
			}),
		},
		{
			PkgPath:    consts.STAKER_PATH,
			Function:   "SetUnStakingFee",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				cross(sr.SetUnStakingFee)(parseNumber(params[0], kindUint64).(uint64))
			}),
		},
		{
			PkgPath:    consts.STAKER_PATH,
			Function:   "SetWarmUp",
			ParamCount: 2,
			HandlerFunc: simpleHandler(func(params []string) {
				percent := parseNumber(params[0], kindInt64).(int64)
				block := parseNumber(params[1], kindInt64).(int64)
				cross(sr.SetWarmUp)(percent, block)
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
				cross(access.CreateRole)(roleName, addr)
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
				cross(access.SetRole)(roleName, addr)
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
				cross(access.UpdateRoleAddress)(roleName, addr)
			}),
		},

		// halt
		{
			PkgPath:    consts.HALT_PATH,
			Function:   "SetHalt",
			ParamCount: 1,
			HandlerFunc: simpleHandler(func(params []string) {
				cross(halt.SetHalt)(parseBool(params[0])) // true = halt, false = no halt
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
				return cross(halt.SetHalt)(haltStatus, levels...)
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
				return cross(halt.SetHaltLevel)(haltLevel)
			},
		},
		{
			PkgPath:    consts.HALT_PATH,
			Function:   "SetOperationStatus",
			ParamCount: 2,
			HandlerFunc: func(params []string) error {
				opType := halt.OpType(params[0])
				allowed := parseBool(params[1])
				return cross(halt.SetOperationStatus)(opType, allowed)
			},
		},
		{
			PkgPath:    consts.HALT_PATH,
			Function:   "EnableWithdrawals",
			ParamCount: 0,
			HandlerFunc: func(params []string) error {
				return cross(halt.EnableWithdrawalsForTestnet)()
			},
		},
		{
			PkgPath:    consts.HALT_PATH,
			Function:   "EnableContractOperations",
			ParamCount: 1,
			HandlerFunc: func(params []string) error {
				contract := halt.OpType(params[0])
				return cross(halt.EnableContractOperations)(contract)
			},
		},
		{
			PkgPath:    consts.HALT_PATH,
			Function:   "DisableContractOperations",
			ParamCount: 1,
			HandlerFunc: func(params []string) error {
				contract := halt.OpType(params[0])
				return cross(halt.DisableContractOperations)(contract)
			},
		},
	}

	// apply all handlers at once
	registerHandlers(registry, handlers)

	return registry
}
