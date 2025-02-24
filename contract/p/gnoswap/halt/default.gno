package halt

var (
	defaultOperations = []struct {
		opType OpType
		name   string
		desc   string
	}{
		{OpTypeSwap, rawSwap, "Token swap operation"},
		{OpTypeLiquidity, rawLiquidity, "Liquidity provision operations"},
		{OpTypeWithdraw, rawWithdraw, "Withdrawal operations"},
	}

	defaultLevels = []struct {
		id      LevelID
		name    string
		desc    string
		allowed map[OpType]bool
	}{
		{
			LvNoHalt,
			rawNoHalt,
			"Normal operation",
			// enabling all operations
			map[OpType]bool{
				OpTypePool: true,
				OpTypePosition: true,
				OpTypeProtocolFee: true,
				OpTypeRouter: true,
				OpTypeStaker: true,
				OpTypeLaunchpad: true,
				OpTypeGovernance: true,

				OpTypeWithdraw: true,
				OpTypeDeposit: true,
				OpTypeSwap: true,
				OpTypeLiquidity: true,
			},
		},
		{
			LvSwapHalt,
			rawSwapHalt,
			"Swaps disabled",
			// only disable the swap, rest => enable
			map[OpType]bool{
				OpTypePool: true,
				OpTypePosition: true,
				OpTypeProtocolFee: true,
				OpTypeRouter: true,
				OpTypeStaker: true,
				OpTypeLaunchpad: true,
				OpTypeGovernance: true,

				OpTypeWithdraw: true,
				OpTypeDeposit: true,
				OpTypeSwap: false,
				OpTypeLiquidity: true,
			},
		},
		{
			LvEmergencyHalt,
			rawEmergencyHalt,
			"Only withdrawals allowed",
			map[OpType]bool{
				OpTypeGovernance: true,
				OpTypeWithdraw: true,
			},
		},
		{
			LvCompleteHalt,
			rawCompleteHalt,
			"All operations disabled",
			map[OpType]bool{
				OpTypeWithdraw:   true,
			},
		},
	}
)
