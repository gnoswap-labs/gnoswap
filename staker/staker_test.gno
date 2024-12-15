package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/avl"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
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
                if err == nil {
                    t.Error("expected error but not occurred")
                }
                return
            }

			uassert.NoError(t, err)
			uassert.Equal(t, result.tokenId, tt.want.tokenId)
			uassert.Equal(t, result.owner, tt.want.owner)
			uassert.Equal(t, result.poolPath, tt.want.poolPath)
        })
    }
}
