package staker

import (
	"std"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/v2/consts"
)

func rewardMathComputeExternalRewardAmount2(tokenId uint64, incentiveId string) (uint64, uint64) {
    currentHeight := std.GetHeight()
    _currentHeightU64 := uint64(currentHeight)

    // 1. 입력 검증 및 기본 데이터 얻기
    externals, exists := validateAndGetExternals(tokenId)
    if !exists {
        return 0, 0
    }

    // 2. 시작 시간과 높이 계산
    stakedStartInfo := calculateStakedStartInfo(tokenId, incentiveId, currentHeight)

    // 3. 각 단계별 임계값(threshold) 계산
    thresholds := calculateThresholds(stakedStartInfo.startHeight)

    // 4. 리워드 계산
    for _, external := range externals {
        if external.incentiveId == incentiveId {
            return calculateRewardsForExternal(
                tokenId,
                incentiveId,
                external,
                _currentHeightU64,
                stakedStartInfo,
                thresholds,
            )
        }
    }

    panic("NO INCENTIVE_ID FOUND")
}

type stakedStartInfo struct {
    startHeight int64
    duration    int64
}

type thresholds struct {
    until30  uint64
    until50  uint64
    until70  uint64
    begin100 uint64
}

func validateAndGetExternals(tokenId uint64) (map[string]externalRewards, bool) {
    externals, exist := positionExternal[tokenId]
    if !exist {
        return nil, false
    }
    return externals, true
}

func calculateStakedStartInfo(tokenId uint64, incentiveId string, currentHeight int64) stakedStartInfo {
    _max := max(incentives[incentiveId].startTimestamp, deposits[tokenId].stakeTimestamp)

    stakedOrExternalDuration := (time.Now().Unix() - _max) / consts.BLOCK_GENERATION_INTERVAL
    stakedOrExternalStartedHeight := currentHeight - stakedOrExternalDuration

    return stakedStartInfo{
        startHeight: stakedOrExternalStartedHeight,
        duration:    stakedOrExternalDuration,
    }
}

func calculateThresholds(startHeight int64) thresholds {
    baseHeight := uint64(startHeight)
    return thresholds{
        until30:  baseHeight + uint64(warmUp[50]) - 1,  // 150
        until50:  baseHeight + uint64(warmUp[70]) - 1,  // 300
        until70:  baseHeight + uint64(warmUp[100]) - 1, // 900
        begin100: baseHeight + uint64(warmUp[100]),     // 901~
    }
}

func calculateRewardsForExternal(
    tokenId uint64,
    incentiveId string,
    external externalRewards,
    currentHeight uint64,
    startInfo stakedStartInfo,
    thresholds thresholds,
) (uint64, uint64) {
    // 1. 분배할 리워드 금액 계산
    tokenAmountX96 := external.tokenAmountX96
    toDistributeX96 := new(u256.Uint).Sub(tokenAmountX96, positionLastExternal[tokenId][incentiveId])

    if tokenAmountX96.Lt(positionLastExternal[tokenId][incentiveId]) {
        panic("THIS SHOULD NOT HAPPEN_EXTERNAL #1")
    }

    // 2. 마지막 계산 높이 얻기
    lastCalculatedHeightU64 := uint64(positionsExternalLastCalculatedHeight[tokenId][incentiveId])

    // 3. 블록당 평균 리워드 계산
    avgExternalBlockAmountX96 := new(u256.Uint).Div(
        toDistributeX96,
        u256.NewUint(currentHeight-lastCalculatedHeightU64),
    )

    // 4. warm-up amount 검증
    positionExternalWarmUpAmount, exist := positionsExternalWarmUpAmount[tokenId][incentiveId]
    if !exist {
        panic("THIS SHOULD NOT HAPPEN_EXTERNAL #2")
    }

    // 5. 리워드 비율 계산 및 리워드 적립
    durationRatio := getRewardRatio(startInfo.duration)
    positionExternalWarmUpAmount = computeRewardsByRatio(
        uint64(durationRatio),
        currentHeight,
        lastCalculatedHeightU64,
        thresholds,
        avgExternalBlockAmountX96,
        positionExternalWarmUpAmount,
    )

    // 6. 총 리워드 계산
    accuFull := uint64(0)
    accuGive := uint64(0)

    accuFull += positionExternalWarmUpAmount.full30 +
        positionExternalWarmUpAmount.full50 +
        positionExternalWarmUpAmount.full70 +
        positionExternalWarmUpAmount.full100

    accuGive += positionExternalWarmUpAmount.give30 +
        positionExternalWarmUpAmount.give50 +
        positionExternalWarmUpAmount.give70 +
        positionExternalWarmUpAmount.full100

    // 7. 상태 업데이트
    positionsExternalWarmUpAmount[tokenId][incentiveId] = positionExternalWarmUpAmount

    return accuFull, accuGive
}

func computeRewardsByRatio(
    durationRatio uint64,
    currentHeight uint64,
    lastCalculatedHeight uint64,
    thresholds thresholds,
    avgBlockAmountX96 *u256.Uint,
    warmUpAmount warmUpAmount,
) warmUpAmount {
    switch durationRatio {
    case 100:
        return computeRewardsFor100Ratio(
            currentHeight,
            lastCalculatedHeight,
            thresholds,
            avgBlockAmountX96,
            warmUpAmount,
        )
    case 70:
        return computeRewardsFor70Ratio(
            currentHeight,
            lastCalculatedHeight,
            thresholds,
            avgBlockAmountX96,
            warmUpAmount,
        )
    case 50:
        return computeRewardsFor50Ratio(
            currentHeight,
            lastCalculatedHeight,
            thresholds,
            avgBlockAmountX96,
            warmUpAmount,
        )
    case 30:
        return computeRewardsFor30Ratio(
            currentHeight,
            lastCalculatedHeight,
            avgBlockAmountX96,
            warmUpAmount,
        )
    default:
        return warmUpAmount
    }
}

func computeRewardsFor100Ratio(
    currentHeight uint64,
    lastCalculatedHeight uint64,
    thresholds thresholds,
    avgBlockAmountX96 *u256.Uint,
    warmUpAmount warmUpAmount,
) warmUpAmount {
    if lastCalculatedHeight > thresholds.begin100 {
        // 100% 구간만 계산
        dur100 := currentHeight - lastCalculatedHeight
        full, _ := calcAmount(avgBlockAmountX96, dur100, 100)
        warmUpAmount.full100 += full
        return warmUpAmount
    }

    if lastCalculatedHeight > thresholds.until50 {
        // 100% + 70% 구간 계산
        dur100 := currentHeight - thresholds.until70
        full, _ := calcAmount(avgBlockAmountX96, dur100, 100)
        warmUpAmount.full100 += full

        dur70 := thresholds.until70 - lastCalculatedHeight
        full, toGive := calcAmount(avgBlockAmountX96, dur70, 70)
        warmUpAmount.full70 += full
        warmUpAmount.give70 += toGive
        warmUpAmount.left70 += full - toGive

        return warmUpAmount
    }

    if lastCalculatedHeight > thresholds.until30 {
        // 100% + 70% + 50% 구간 계산
        dur100 := currentHeight - thresholds.until70
        full, _ := calcAmount(avgBlockAmountX96, dur100, 100)
        warmUpAmount.full100 += full

        dur70 := thresholds.until70 - thresholds.until50
        full, toGive := calcAmount(avgBlockAmountX96, dur70, 70)
        warmUpAmount.full70 += full
        warmUpAmount.give70 += toGive
        warmUpAmount.left70 += full - toGive

        dur50 := thresholds.until50 - lastCalculatedHeight
        full, toGive = calcAmount(avgBlockAmountX96, dur50, 50)
        warmUpAmount.full50 += full
        warmUpAmount.give50 += toGive
        warmUpAmount.left50 += full - toGive

        return warmUpAmount
    }

    // 모든 구간 계산 (100% + 70% + 50% + 30%)
    dur100 := currentHeight - thresholds.until70
    full, _ := calcAmount(avgBlockAmountX96, dur100, 100)
    warmUpAmount.full100 += full

    dur70 := thresholds.until70 - thresholds.until50
    full, toGive := calcAmount(avgBlockAmountX96, dur70, 70)
    warmUpAmount.full70 += full
    warmUpAmount.give70 += toGive
    warmUpAmount.left70 += full - toGive

    dur50 := thresholds.until50 - thresholds.until30
    full, toGive = calcAmount(avgBlockAmountX96, dur50, 50)
    warmUpAmount.full50 += full
    warmUpAmount.give50 += toGive
    warmUpAmount.left50 += full - toGive

    dur30 := thresholds.until30 - lastCalculatedHeight
    full, toGive = calcAmount(avgBlockAmountX96, dur30, 30)
    warmUpAmount.full30 += full
    warmUpAmount.give30 += toGive
    warmUpAmount.left30 += full - toGive

    return warmUpAmount
}

func computeRewardsFor70Ratio(
    currentHeight uint64,
    lastCalculatedHeight uint64,
    thresholds thresholds,
    avgBlockAmountX96 *u256.Uint,
    warmUpAmount warmUpAmount,
) warmUpAmount {
    if lastCalculatedHeight > thresholds.until50 {
        // 70% 구간만 계산
        dur70 := currentHeight - lastCalculatedHeight
        full, toGive := calcAmount(avgBlockAmountX96, dur70, 70)
        warmUpAmount.full70 += full
        warmUpAmount.give70 += toGive
        warmUpAmount.left70 += full - toGive
        return warmUpAmount
    }

    if lastCalculatedHeight > thresholds.until30 {
        // 70% + 50% 구간 계산
        dur70 := currentHeight - thresholds.until50
        full, toGive := calcAmount(avgBlockAmountX96, dur70, 70)
        warmUpAmount.full70 += full
        warmUpAmount.give70 += toGive
        warmUpAmount.left70 += full - toGive

        dur50 := thresholds.until50 - lastCalculatedHeight
        full, toGive = calcAmount(avgBlockAmountX96, dur50, 50)
        warmUpAmount.full50 += full
        warmUpAmount.give50 += toGive
        warmUpAmount.left50 += full - toGive
        return warmUpAmount
    }

    // 모든 구간 계산 (70% + 50% + 30%)
    dur70 := currentHeight - thresholds.until50
    full, toGive := calcAmount(avgBlockAmountX96, dur70, 70)
    warmUpAmount.full70 += full
    warmUpAmount.give70 += toGive
    warmUpAmount.left70 += full - toGive

    dur50 := thresholds.until50 - thresholds.until30
    full, toGive = calcAmount(avgBlockAmountX96, dur50, 50)
    warmUpAmount.full50 += full
    warmUpAmount.give50 += toGive
    warmUpAmount.left50 += full - toGive

    dur30 := thresholds.until30 - lastCalculatedHeight
    full, toGive = calcAmount(avgBlockAmountX96, dur30, 30)
    warmUpAmount.full30 += full
    warmUpAmount.give30 += toGive
    warmUpAmount.left30 += full - toGive

    return warmUpAmount
}

func computeRewardsFor50Ratio(
    currentHeight uint64,
    lastCalculatedHeight uint64,
    thresholds thresholds,
    avgBlockAmountX96 *u256.Uint,
    warmUpAmount warmUpAmount,
) warmUpAmount {
    if lastCalculatedHeight > thresholds.until30 {
        // 50% 구간만 계산
        dur50 := thresholds.until50 - thresholds.until30
        full, toGive := calcAmount(avgBlockAmountX96, dur50, 50)
        warmUpAmount.full50 += full
        warmUpAmount.give50 += toGive
        warmUpAmount.left50 += full - toGive
        return warmUpAmount
    }

    // 50% + 30% 구간 계산
    dur50 := currentHeight - thresholds.until30
    full, toGive := calcAmount(avgBlockAmountX96, dur50, 50)
    warmUpAmount.full50 += full
    warmUpAmount.give50 += toGive
    warmUpAmount.left50 += full - toGive

    dur30 := thresholds.until30 - lastCalculatedHeight
    full, toGive = calcAmount(avgBlockAmountX96, dur30, 30)
    warmUpAmount.full30 += full
    warmUpAmount.give30 += toGive
    warmUpAmount.left30 += full - toGive

    return warmUpAmount
}

func computeRewardsFor30Ratio(
    currentHeight uint64,
    lastCalculatedHeight uint64,
    avgBlockAmountX96 *u256.Uint,
    warmUpAmount warmUpAmount,
) warmUpAmount {
    dur30 := currentHeight - lastCalculatedHeight
    full, toGive := calcAmount(avgBlockAmountX96, dur30, 30)
    warmUpAmount.full30 += full
    warmUpAmount.give30 += toGive
    warmUpAmount.left30 += full - toGive

    return warmUpAmount
}

func computeRewardsFor50RatioUnit(
    currentHeight uint64,
    lastCalculatedHeight uint64,
    avgBlockAmountX96 *u256.Uint,
    warmUpAmount warmUpAmount,
) warmUpAmount {
    dur50 := currentHeight - lastCalculatedHeight
    full, toGive := calcAmount(avgBlockAmountX96, dur50, 50)
    warmUpAmount.full50 += full
    warmUpAmount.give50 += toGive
    warmUpAmount.left50 += full - toGive

    return warmUpAmount
}

func (w *warmUpAmount) computeRewardsFor50RatioUnit(
    currentHeight uint64,
    lastCalculatedHeight uint64,
    avgBlockAmountX96 *u256.Uint,
) *warmUpAmount {
    dur50 := currentHeight - lastCalculatedHeight
    full, toGive := calcAmount(avgBlockAmountX96, dur50, 50)
    w.full50 += full
    w.give50 += toGive
    w.left50 += full - toGive
    return w
}

func (w *warmUpAmount) computeRewardsFor70RatioUnit(
    currentHeight uint64,
    lastCalculatedHeight uint64,
    avgBlockAmountX96 *u256.Uint,
) *warmUpAmount {
    dur70 := currentHeight - lastCalculatedHeight
    full, toGive := calcAmount(avgBlockAmountX96, dur70, 70)
    w.full70 += full
    w.give70 += toGive
    w.left70 += full - toGive
    return w
}
