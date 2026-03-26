package halt

const (
	ConfigNone      = uint64(0)
	ConfigSafeMode  = uint64(OpTypeWithdraw)
	ConfigEmergency = uint64(OpTypeAll &^ (OpTypeGovernance | OpTypeWithdraw))
	ConfigComplete  = uint64(OpTypeAll)
)
