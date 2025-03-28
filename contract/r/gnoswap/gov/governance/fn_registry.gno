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

	phalt "gno.land/p/gnoswap/halt"
	"gno.land/r/gnoswap/v1/halt"
)

func createParameterHandlers() *ParameterRegistry {
	registry := NewParameterRegistry()

	// region: Common path
	registry.Register(consts.COMMON_PATH, "SetHalt", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		halt.SetHalt(parseBool(params[0])) // halt
		return nil
	})

	// region: Community pool
	registry.Register(consts.COMMUNITY_POOL_PATH, "TransferToken", func(params []string) error {
		if err := hasDesiredParams(params, 3); err != nil {
			return err
		}
		cp.TransferToken(
			params[0],              // pkgPath
			std.Address(params[1]), // to
			parseUint64(params[2]), // amount
		)
		return nil
	})

	// region: Emission
	registry.Register(consts.EMISSION_PATH, "ChangeDistributionPct", func(params []string) error {
		if err := hasDesiredParams(params, 8); err != nil {
			return err
		}
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
		return nil
	})

	// region: GNS Path
	registry.Register(consts.GNS_PATH, "SetAvgBlockTimeInMs", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		gns.SetAvgBlockTimeInMs(int64(parseInt(params[0]))) // ms
		return nil
	})

	// region: Governance Path
	registry.Register(consts.GOV_GOVERNANCE_PATH, "Reconfigure", func(params []string) error {
		if err := hasDesiredParams(params, 7); err != nil {
			return err
		}
		reconfigure(
			parseUint64(params[0]), // votingStartDelay
			parseUint64(params[1]), // votingPeriod
			parseUint64(params[2]), // votingWeightSmoothingDuration
			parseUint64(params[3]), // quorum
			parseUint64(params[4]), // proposalCreationhold
			parseUint64(params[5]), // executionDelay
			parseUint64(params[6]), // executionWindow
		)
		return nil
	})

	// region: Pool Path
	registry.Register(consts.POOL_PATH, "SetFeeProtocol", func(params []string) error {
		if err := hasDesiredParams(params, 2); err != nil {
			return err
		}
		pl.SetFeeProtocol(
			uint8(parseUint64(params[0])), // feeProtocol0
			uint8(parseUint64(params[1])), // feeProtocol1
		)
		return nil
	})

	registry.Register(consts.POOL_PATH, "SetPoolCreationFee", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		pl.SetPoolCreationFee(parseUint64(params[0])) // fee
		return nil
	})

	registry.Register(consts.POOL_PATH, "SetWithdrawalFee", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		pl.SetWithdrawalFee(parseUint64(params[0])) // fee
		return nil
	})

	// region: Protocol fee
	registry.Register(consts.PROTOCOL_FEE_PATH, "SetDevOpsPct", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		pf.SetDevOpsPct(parseUint64(params[0])) // pct
		return nil
	})

	// region: Router
	registry.Register(consts.ROUTER_PATH, "SetSwapFee", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		rr.SetSwapFee(parseUint64(params[0])) // fee
		return nil
	})

	// region: Staker
	registry.Register(consts.STAKER_PATH, "SetDepositGnsAmount", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		sr.SetDepositGnsAmount(parseUint64(params[0])) // amount
		return nil
	})

	registry.Register(consts.STAKER_PATH, "SetPoolTier", func(params []string) error {
		if err := hasDesiredParams(params, 2); err != nil {
			return err
		}
		sr.SetPoolTier(
			params[0],              // pool
			parseUint64(params[1]), // tier
		)
		return nil
	})

	registry.Register(consts.STAKER_PATH, "ChangePoolTier", func(params []string) error {
		if err := hasDesiredParams(params, 2); err != nil {
			return err
		}
		sr.ChangePoolTier(
			params[0],              // pool
			parseUint64(params[1]), // tier
		)
		return nil
	})

	registry.Register(consts.STAKER_PATH, "RemovePoolTier", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		sr.RemovePoolTier(params[0]) // pool
		return nil
	})

	registry.Register(consts.STAKER_PATH, "SetUnStakingFee", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		sr.SetUnStakingFee(parseUint64(params[0]))
		return nil
	})

	registry.Register(consts.STAKER_PATH, "SetWarmUp", func(params []string) error {
		if err := hasDesiredParams(params, 2); err != nil {
			return err
		}
		sr.SetWarmUp(
			int64(parseInt(params[0])), // percent
			int64(parseInt(params[1])), // block
		)
		return nil
	})

	// region: Access
	registry.Register(consts.ACCESS_PATH, "CreateRole", func(params []string) error {
		if err := hasDesiredParams(params, 2); err != nil {
			return err
		}
		access.CreateRole(
			params[0],              // roleName
			std.Address(params[1]), // address
		)
		return nil
	})

	registry.Register(consts.ACCESS_PATH, "SetRole", func(params []string) error {
		if err := hasDesiredParams(params, 2); err != nil {
			return err
		}
		return access.SetRole(
			params[0],              // roleName
			std.Address(params[1]), // address
		)
	})

	registry.Register(consts.ACCESS_PATH, "UpdateRoleAddress", func(params []string) error {
		if err := hasDesiredParams(params, 2); err != nil {
			return err
		}
		return access.UpdateRoleAddress(
			params[0],              // roleName
			std.Address(params[1]), // newAddress
		)
	})

	// region: halt
	registry.Register(consts.HALT_PATH, "SetHalt", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		halt.SetHalt(parseBool(params[0])) // true = halt, false = unhalt
		return nil
	})

	registry.Register(consts.HALT_PATH, "SetHaltWithLevel", func(params []string) error {
		if err := hasDesiredParams(params, 2); err != nil {
			return err
		}
		haltStatus := parseBool(params[0])
		levels := make([]phalt.LevelID, 0)
		for _, level := range strings.Split(params[1], ",") {
			levelID, err := phalt.LevelIDFromString(level)
			if err != nil {
				return err
			}
			levels = append(levels, levelID)
		}

		return halt.SetHalt(haltStatus, levels...)
	})

	registry.Register(consts.HALT_PATH, "SetHaltLevel", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		haltLevel, err := phalt.LevelIDFromString(params[0])
		if err != nil {
			return err
		}
		return halt.SetHaltLevel(haltLevel)
	})

	registry.Register(consts.HALT_PATH, "SetOperationStatus", func(params []string) error {
		if err := hasDesiredParams(params, 2); err != nil {
			return err
		}

		opType := phalt.OpType(params[0])
		allowed := parseBool(params[1])

		return halt.SetOperationStatus(opType, allowed)
	})

	registry.Register(consts.HALT_PATH, "EnableWithdrawals", func(params []string) error {
		if err := hasDesiredParams(params, 0); err != nil {
			return err
		}

		return halt.EnableWithdrawalsForTestnet()
	})

	registry.Register(consts.HALT_PATH, "EnableContractOperations", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}

		contract := phalt.OpType(params[0])

		return halt.EnableContractOperations(contract)
	})

	registry.Register(consts.HALT_PATH, "DisableContractOperations", func(params []string) error {
		if err := hasDesiredParams(params, 1); err != nil {
			return err
		}
		contract := phalt.OpType(params[0])
		return halt.DisableContractOperations(contract)
	})

	return registry
}
