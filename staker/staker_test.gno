package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/r/demo/users"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/consts"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestCalculateCollectReward(t *testing.T) {
    tokenId := uint64(1)
    owner := testutils.TestAddress("owner")
    poolPath := "token0:token1:3000"

    tests := []struct {
        name string
        setup func()
        want struct {
            tokenId uint64
            owner std.Address 
            poolPath string
            hasError bool
        }
    }{
        {
			name: "normal case - no reward",
            setup: func() {
                deposits.Set(tokenId, newDeposit(
                    owner,
                    1,
                    time.Now().Unix(),
                    100,
                    poolPath,
                ))
            },
            want: struct {
                tokenId uint64
                owner std.Address
                poolPath string 
                hasError bool
            }{
                tokenId: tokenId,
                owner: owner,
                poolPath: poolPath,
                hasError: false,
            },
        },
        {
			name: "external reward",
            setup: func() {
                deposits.Set(tokenId, newDeposit(
                    owner,
                    1, 
                    time.Now().Unix(),
                    100,
                    poolPath,
                ))

                ictvId := "incentive1"
                incentives.Set(ictvId, ExternalIncentive{
                    targetPoolPath: poolPath,
                    rewardToken: "rewardToken",
                })

				// TODO: update type if needed (avl.Tree ?)
                positionExternal[tokenId] = map[string]externalRewards{
					ictvId: {
						incentiveId: ictvId,
						poolPath: poolPath,
						tokenPath: "rewardToken",
					},
				}

				// TODO: update type if needed (avl.Tree ?)
                positionsExternalWarmUpAmount[tokenId] = map[string]warmUpAmount{
					ictvId: {
						full30: 30,
						give30: 15,
						full50: 50,
						give50: 25,
						full70: 70,
						give70: 35,
						full100: 100,
					},
				}
            },
            want: struct {
                tokenId uint64
                owner std.Address
                poolPath string
                hasError bool
            }{
                tokenId: tokenId,
                owner: owner,
                poolPath: poolPath,
                hasError: false,
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            tt.setup()

            deposit := deposits.MustGet(tokenId)
            result, err := calculateCollectReward(tokenId, deposit)

            if tt.want.hasError {
				uassert.Error(t, err)
            }

			uassert.NoError(t, err)
			uassert.Equal(t, result.tokenId, tt.want.tokenId)
			uassert.Equal(t, result.owner, tt.want.owner)
			uassert.Equal(t, result.poolPath, tt.want.poolPath)
        })
    }
}

func TestApplyExternalReward(t *testing.T) {
    tokenId := uint64(1)
    owner := testutils.TestAddress("owner")
    ictvId := "incentive1"
    tokenPath := barPath
    poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"

    mockToken := struct {
        GRC20Interface
    }{
        GRC20Interface: BarToken{},
    }

    tests := []struct {
        name string
        setup func()
        reward externalRewardInfo
        want struct {
            toUser uint64
            remaining uint64
            tokenAmountX96 *u256.Uint
            tokenAmountFull uint64
            tokenAmountToGive uint64
        }
    }{
        {
            name: "no incentive",
            setup: func() {
                incentives = newIncentives()
            },
            reward: externalRewardInfo{
                ictvId: "non_existing_incentive",
                tokenPath: tokenPath,
                fullAmount: 100,
                toGive: 60,
            },
            want: struct {
                toUser uint64
                remaining uint64
                tokenAmountX96 *u256.Uint
                tokenAmountFull uint64
                tokenAmountToGive uint64
            }{
                toUser: 0,
                remaining: 0,
                tokenAmountX96: nil,
                tokenAmountFull: 0,
                tokenAmountToGive: 0,
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            std.TestSetOrigCaller(users.Resolve(admin))
            tt.setup()

            result := applyExternalReward(tokenId, tt.reward, owner, false)
			uassert.Equal(t, result.toUser, tt.want.toUser)
			uassert.Equal(t, result.left, tt.want.remaining)

            external := positionExternal[tokenId][tt.reward.ictvId]
			uassert.Equal(t, external.tokenAmountX96.ToString(), tt.want.tokenAmountX96.ToString())
			uassert.Equal(t, external.tokenAmountFull, tt.want.tokenAmountFull)

			uassert.Equal(t, external.tokenAmountToGive, tt.want.tokenAmountToGive)

            warmUp := positionsExternalWarmUpAmount[tokenId][tt.reward.ictvId]
			uassert.Equal(t, warmUp.totalFull(), uint64(0))
			uassert.Equal(t, warmUp.totalGive(), uint64(0))
        })
    }
}

func TestNewUnstakeInput(t *testing.T) {
    tests := []struct {
        name    string
        tokenId uint64
        unwrap  bool
        deposit Deposit
        want    unstakeInput
    }{
        {
            name:    "should create unstake input with false unwrap",
            tokenId: 1,
            unwrap:  false,
            deposit: Deposit{
                owner:          std.Address("test1"),
                targetPoolPath: "pool1",
            },
            want: unstakeInput{
                tokenId: 1,
                unwrap:  false,
                deposit: Deposit{
                    owner:          std.Address("test1"),
                    targetPoolPath: "pool1",
                },
            },
        },
        {
            name:    "should create unstake input with true unwrap",
            tokenId: 2,
            unwrap:  true,
            deposit: Deposit{
                owner:          std.Address("test2"),
                targetPoolPath: "pool2",
            },
            want: unstakeInput{
                tokenId: 2,
                unwrap:  true,
                deposit: Deposit{
                    owner:          std.Address("test2"),
                    targetPoolPath: "pool2",
                },
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := newUnstakeInput(tt.tokenId, tt.unwrap, tt.deposit)
			uassert.Equal(t, got.tokenId, tt.want.tokenId)
			uassert.Equal(t, got.unwrap, tt.want.unwrap)

			assertDeposit(t, got.deposit, tt.want.deposit)
        })
    }
}

func TestNewUnstakeOutput(t *testing.T) {
	test1 := testutils.TestAddress("test1")
	test2 := testutils.TestAddress("test2")
	test3 := testutils.TestAddress("test3")

    tests := []struct {
        name         string
        poolPath     string
        token0Amount string
        token1Amount string
        input        unstakeInput
        want         *unstakeOutput
    }{
        {
            name:         "should create unstake output with zero amounts",
            poolPath:     "pool1",
            token0Amount: "0",
            token1Amount: "0",
            input: unstakeInput{
                tokenId: 1,
                unwrap:  false,
                deposit: Deposit{
                    owner:          test1,
                    targetPoolPath: "pool1",
                },
            },
            want: &unstakeOutput{
                tokenId:      1,
                owner:        test1,
                poolPath:     "pool1",
                token0Amount: "0",
                token1Amount: "0",
                from:        consts.STAKER_ADDR,
                to:          test1,
            },
        },
        {
            name:         "should create unstake output with non-zero amounts",
            poolPath:     "pool2",
            token0Amount: "100",
            token1Amount: "200",
            input: unstakeInput{
                tokenId: 2,
                unwrap:  true,
                deposit: Deposit{
                    owner:          test2,
                    targetPoolPath: "pool2",
                },
            },
            want: &unstakeOutput{
                tokenId:      2,
                owner:        test2,
                poolPath:     "pool2",
                token0Amount: "100",
                token1Amount: "200",
                from:        consts.STAKER_ADDR,
                to:          test2,
            },
        },
        {
            name:         "should create unstake output with different pool path",
            poolPath:     "newPool",
            token0Amount: "150",
            token1Amount: "300",
            input: unstakeInput{
                tokenId: 3,
                unwrap:  false,
                deposit: Deposit{
                    owner:          test3,
                    targetPoolPath: "oldPool",
                },
            },
            want: &unstakeOutput{
                tokenId:      3,
                owner:        test3,
                poolPath:     "newPool",
                token0Amount: "150",
                token1Amount: "300",
                from:        consts.STAKER_ADDR,
                to:          test3,
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := newUnstakeOutput(tt.poolPath, tt.token0Amount, tt.token1Amount, tt.input)
			assertUnstakeOutput(t, got, tt.want)
        })
    }
}

func Test_applyUnstake(t *testing.T) {
	var notExistTokenId uint64 = 999

    tests := []struct {
        name  string
        setup func() (*RewardManager, unstakeInput)
        verify func(*RewardManager) bool
    }{
        {
            name: "Normal unstaking test",
            setup: func() (*RewardManager, unstakeInput) {
                rm := NewRewardManager()
                internalReward := NewInternalEmissionReward()
                recipientsMap := NewRewardRecipientMap()
                poolLiquidity := NewPoolLiquidity()

                inRangeLiquidity := NewInRangeLiquidity()
                inRangeLiquidity.SetLiquidity(u256.NewUint(1000))
                inRangeLiquidity.SetLiquidityRatio(u256.NewUint(100))
                inRangeLiquidity.SetStakedHeight(100)
                
                poolLiquidity.AddInRangePosition(1, inRangeLiquidity)
                recipientsMap.SetPoolLiquidity("test/pool", poolLiquidity)
                internalReward.SetRewardRecipientsMap(recipientsMap)
                rm.SetInternalEmissionReward(internalReward)

                input := unstakeInput{
                    tokenId: 1,
                    deposit: Deposit{
                        targetPoolPath: "test/pool",
                        stakeHeight:   100,
                    },
                }

                return rm, input
            },
            verify: func(rm *RewardManager) bool {
                internalReward := rm.GetInternalEmissionReward()
                if internalReward == nil {
                    return false
                }

                recipientsMap := internalReward.GetRewardRecipientsMap()
                if recipientsMap == nil {
                    return false
                }

                poolLiquidity := recipientsMap.GetPoolLiquidity("test/pool")
                if poolLiquidity == nil {
                    return false
                }

                position := poolLiquidity.GetInRangeLiquidity(1)
                if position == nil {
                    return false
                }

                if !position.GetLiquidity().IsZero() {
                    return false
                }
                if !position.GetLiquidityRatio().IsZero() {
                    return false
                }
                if position.GetStakedHeight() != 0 {
                    return false
                }

                return true
            },
        },
        {
            name: "Non-existent pool unstaking test",
            setup: func() (*RewardManager, unstakeInput) {
                rm := NewRewardManager()
                input := unstakeInput{
                    tokenId: 1,
                    deposit: Deposit{
                        targetPoolPath: "non/existent/pool",
                        stakeHeight:   100,
                    },
                }
                return rm, input
            },
            verify: func(rm *RewardManager) bool {
                return rm.GetInternalEmissionReward() != nil
            },
        },
        {
			name: "Non-existent token ID unstaking test",
            setup: func() (*RewardManager, unstakeInput) {
                rm := NewRewardManager()
                internalReward := NewInternalEmissionReward()
                recipientsMap := NewRewardRecipientMap()
                poolLiquidity := NewPoolLiquidity()
                recipientsMap.SetPoolLiquidity("test/pool", poolLiquidity)
                internalReward.SetRewardRecipientsMap(recipientsMap)
                rm.SetInternalEmissionReward(internalReward)

                input := unstakeInput{
                    tokenId: notExistTokenId,
                    deposit: Deposit{
                        targetPoolPath: "test/pool",
                        stakeHeight:   100,
                    },
                }
                return rm, input
            },
            verify: func(rm *RewardManager) bool {
                return rm.GetInternalEmissionReward() != nil
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            rm, input := tt.setup()

            resultRM := applyUnstake(rm, input)
            
            if !tt.verify(resultRM) {
                t.Errorf("%s: verification failed", tt.name)
            }
        })
    }
}

func TestCalculateSingleExternalReward(t *testing.T) {
    tokenId := uint64(1)
    tokenPath := "gno.land/r/demo/token"
    poolPath := "gno.land/r/demo/token:gno.land/r/demo/token2:3000"

    tests := []struct {
        name string
        setup func()
        ictvId string
        want struct {
            result *externalRewardResult
            err error
        }
    }{
        {
            name: "success - with rewards to give",
            setup: func() {
                setIncentive(t, "incentive1", poolPath, tokenPath)

                if positionsExternalWarmUpAmount[tokenId] == nil {
                    positionsExternalWarmUpAmount[tokenId] = make(map[string]warmUpAmount)
                }
                
                positionsExternalWarmUpAmount[tokenId]["incentive1"] = warmUpAmount{
                    full30: 30,
                    give30: 15,
                    full50: 50,
                    give50: 25,
                    full70: 70,
                    give70: 35,
                    full100: 100,
                }
            },
            ictvId: "incentive1",
            want: struct {
                result *externalRewardResult
                err error
            }{
                result: &externalRewardResult{
                    ictvId: "incentive1",
                    tokenPath: tokenPath,
                    poolPath: poolPath,
                    fullAmount: 250, // 30 + 50 + 70 + 100
                    toGive: 175,     // 15 + 25 + 35 + 100
                },
                err: nil,
            },
        },
        {
            name: "success - with zero rewards to give",
            setup: func() {
                setIncentive(t, "incentive2", poolPath, tokenPath)

                if positionsExternalWarmUpAmount[tokenId] == nil {
                    positionsExternalWarmUpAmount[tokenId] = make(map[string]warmUpAmount)
                }
                
                positionsExternalWarmUpAmount[tokenId]["incentive2"] = warmUpAmount{} // all zeros
            },
            ictvId: "incentive2",
            want: struct {
                result *externalRewardResult
                err error
            }{
                result: nil,
                err: nil,
            },
        },
        {
            name: "failure - incentive not found",
            setup: func() {
                incentives = newIncentives() // clear incentives
            },
            ictvId: "non_existing_incentive",
            want: struct {
                result *externalRewardResult
                err error
            }{
                result: nil,
                err: errIncentiveNotFound,
            },
        },
        {
            name: "failure - warm up amount not found",
            setup: func() {
                setIncentive(t, "incentive3", poolPath, tokenPath)

                positionsExternalWarmUpAmount[tokenId] = make(map[string]warmUpAmount) // empty map
            },
            ictvId: "incentive3",
            want: struct {
                result *externalRewardResult
                err error
            }{
                result: nil,
                err: errWarmUpAmountNotFound,
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            incentives = newIncentives()
            positionsExternalWarmUpAmount = make(map[uint64]map[string]warmUpAmount)

            tt.setup()

            got, err := calculateSingleExternalReward(tokenId, tokenPath, tt.ictvId)

            if tt.want.err != nil {
				uassert.Error(t, err)
				uassert.ErrorContains(t, err, tt.want.err.Error())
                return
            }

            if tt.want.result == nil {
                if got != nil {
                    t.Errorf("expected nil result, got %+v", got)
                }
                return
            }

            if got == nil {
                t.Fatal("expected non-nil result, got nil")
            }

            uassert.Equal(t, got.ictvId, tt.want.result.ictvId)
            uassert.Equal(t, got.tokenPath, tt.want.result.tokenPath) 
            uassert.Equal(t, got.poolPath, tt.want.result.poolPath)
            uassert.Equal(t, got.fullAmount, tt.want.result.fullAmount)
            uassert.Equal(t, got.toGive, tt.want.result.toGive)
        })
    }
}

func TestCalculateExternalRewards(t *testing.T) {
    tokenId := uint64(1)
    poolPath := "gno.land/r/demo/token:gno.land/r/demo/token2:3000"
    
    tests := []struct {
        name string
        setup func()
        want struct {
            rewardsCount int
            err error
        }
    }{
        {
            name: "success - multiple rewards",
            setup: func() {
                setIncentive(t, "incentive1", poolPath, "token1")
                setIncentive(t, "incentive2", poolPath, "token2")

                // Set up positions
                positionExternal[tokenId] = map[string]externalRewards{
                    "incentive1": {
                        tokenPath: "token1",
                        incentiveId: "incentive1",
                    },
                    "incentive2": {
                        tokenPath: "token2",
                        incentiveId: "incentive2",
                    },
                }

                // Set up warm up amounts
                if positionsExternalWarmUpAmount[tokenId] == nil {
                    positionsExternalWarmUpAmount[tokenId] = make(map[string]warmUpAmount)
                }

                positionsExternalWarmUpAmount[tokenId]["incentive1"] = warmUpAmount{
                    full30: 30,
                    give30: 15,
                }
                positionsExternalWarmUpAmount[tokenId]["incentive2"] = warmUpAmount{
                    full50: 50,
                    give50: 25,
                }
            },
            want: struct {
                rewardsCount int
                err error
            }{
                rewardsCount: 2,
                err: nil,
            },
        },
        {
            name: "success - no positions exist",
            setup: func() {
                positionExternal = make(map[uint64]map[string]externalRewards)
            },
            want: struct {
                rewardsCount int
                err error
            }{
                rewardsCount: 0,
                err: nil,
            },
        },
        {
            name: "success - positions exist but no rewards to give",
            setup: func() {
                setIncentive(t, "incentive1", poolPath, "token1")

                positionExternal[tokenId] = map[string]externalRewards{
                    "incentive1": {
                        tokenPath: "token1",
                        incentiveId: "incentive1",
                    },
                }

                // Set up zero warm up amounts
                if positionsExternalWarmUpAmount[tokenId] == nil {
                    positionsExternalWarmUpAmount[tokenId] = make(map[string]warmUpAmount)
                }
                positionsExternalWarmUpAmount[tokenId]["incentive1"] = warmUpAmount{} // all zeros
            },
            want: struct {
                rewardsCount int
                err error
            }{
                rewardsCount: 0,
                err: nil,
            },
        },
        {
            name: "failure - incentive not found",
            setup: func() {
                // Set up positions with non-existing incentive
                positionExternal[tokenId] = map[string]externalRewards{
                    "non_existing": {
                        tokenPath: "token1",
                        incentiveId: "non_existing",
                    },
                }

                if positionsExternalWarmUpAmount[tokenId] == nil {
                    positionsExternalWarmUpAmount[tokenId] = make(map[string]warmUpAmount)
                }
                positionsExternalWarmUpAmount[tokenId]["non_existing"] = warmUpAmount{
                    full30: 30,
                    give30: 15,
                }
            },
            want: struct {
                rewardsCount int
                err error
            }{
                rewardsCount: 0,
                err: errIncentiveNotFound,
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            incentives = newIncentives()
            positionExternal = make(map[uint64]map[string]externalRewards)
            positionsExternalWarmUpAmount = make(map[uint64]map[string]warmUpAmount)

            tt.setup()

            result := newCollectResult(tokenId, std.Address("owner"), poolPath)

            err := calculateExternalRewards(tokenId, result)
            if tt.want.err != nil {
				uassert.Error(t, err)
				uassert.ErrorContains(t, err, tt.want.err.Error())
                return
            }

            if err != nil {
                t.Errorf("unexpected error: %v", err)
                return
            }

            // Count rewards in the tree
            rewardsCount := 0
            result.externalRewards.Iterate("", "", func(ictvId string, value interface{}) bool {
                rewardsCount++
                return false
            })

            uassert.Equal(t, rewardsCount, tt.want.rewardsCount)
        })
    }
}

func setIncentive(t *testing.T, ictvId, poolPath, rewardToken string) {
	t.Helper()
	incentives.Set(ictvId, ExternalIncentive{
		targetPoolPath: poolPath,
		rewardToken: rewardToken,
	})
}

func assertDeposit(t *testing.T, got, want Deposit) {
	t.Helper()
	uassert.Equal(t, got.owner, want.owner)
	uassert.Equal(t, got.targetPoolPath, want.targetPoolPath)
	uassert.Equal(t, got.numberOfStakes, want.numberOfStakes)
	uassert.Equal(t, got.stakeTimestamp, want.stakeTimestamp)
	uassert.Equal(t, got.stakeHeight, want.stakeHeight)
}

func assertUnstakeOutput(t *testing.T, got, want *unstakeOutput) {
	t.Helper()
	uassert.Equal(t, got.tokenId, want.tokenId)
	uassert.Equal(t, got.owner, want.owner)
	uassert.Equal(t, got.poolPath, want.poolPath)
	uassert.Equal(t, got.token0Amount, want.token0Amount)
	uassert.Equal(t, got.token1Amount, want.token1Amount)
	uassert.Equal(t, got.from, want.from)
	uassert.Equal(t, got.to, want.to)
}
