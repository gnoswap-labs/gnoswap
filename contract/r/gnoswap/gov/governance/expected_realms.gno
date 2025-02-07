package governance

import (
	"std"

	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/community_pool"
	"gno.land/r/gnoswap/v1/pool"
	"gno.land/r/gnoswap/v1/protocol_fee"
	"gno.land/r/gnoswap/v1/router"
	"gno.land/r/gnoswap/v1/staker"
)

type EmissionI struct {
	MintAndDistributeGns func() uint64
	ChangeDistributionPct func(
		target01 int,
		pct01 uint64,
		target02 int,
		pct02 uint64,
		target03 int,
		pct03 uint64,
		target04 int,
		pct04 uint64,
	)
	GetDistributedToGovStaker func() uint64
}

var en EmissionI = EmissionI{
	MintAndDistributeGns: emission.MintAndDistributeGns,
	ChangeDistributionPct: emission.ChangeDistributionPct,
	GetDistributedToGovStaker: emission.GetDistributedToGovStaker,
}

type CommunityPoolI struct {
	TransferToken func(pkgPath string, to std.Address, amount uint64)
}

var cp CommunityPoolI = CommunityPoolI{
	TransferToken: community_pool.TransferToken,
}

type PoolI struct {
	SetFeeProtocol func(feeProtocol0 uint8, feeProtocol1 uint8)
	SetPoolCreationFee func(poolCreationFee uint64)
	SetWithdrawalFee func(withdrawalFee uint64)
}

var pl PoolI = PoolI{
	SetFeeProtocol: pool.SetFeeProtocol,
	SetPoolCreationFee: pool.SetPoolCreationFee,
	SetWithdrawalFee: pool.SetWithdrawalFee,
}

type ProtocolFeeI struct {
	SetDevOpsPct func(devOpsPct uint64)
}

var pf ProtocolFeeI = ProtocolFeeI{
	SetDevOpsPct: protocol_fee.SetDevOpsPct,
}

type RouterI struct {
	SetSwapFee func(swapFee uint64)
}

var rr RouterI = RouterI{
	SetSwapFee: router.SetSwapFee,
}

type StakerI struct {
	SetDepositGnsAmount func(depositGnsAmount uint64)
	SetPoolTier func(poolId string, poolTier uint64)
	ChangePoolTier func(poolId string, poolTier uint64)
	RemovePoolTier func(poolId string)
	SetUnStakingFee func(unstakingFee uint64)
	SetWarmUp func(percent int64, block int64)
}

var sr StakerI = StakerI{
	SetDepositGnsAmount: staker.SetDepositGnsAmount,
	SetPoolTier: staker.SetPoolTier,
	ChangePoolTier: staker.ChangePoolTier,
	RemovePoolTier: staker.RemovePoolTier,
	SetUnStakingFee: staker.SetUnStakingFee,
}