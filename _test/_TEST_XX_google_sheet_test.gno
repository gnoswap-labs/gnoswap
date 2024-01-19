package swap_scneraio

import (
	"std"
	"testing"

	_ "gno.land/r/demo/grc20_wrapper"

	pl "gno.land/r/demo/pool"
	pos "gno.land/r/demo/position"

	"gno.land/r/demo/token01"
	"gno.land/r/demo/token02"
	"gno.land/r/demo/token03"
	"gno.land/r/demo/token04"
	"gno.land/r/demo/token05"
	"gno.land/r/demo/token06"
	"gno.land/r/demo/token07"

	"gno.land/r/demo/gns"
	"gno.land/r/demo/token01"
	"gno.land/r/demo/token02"
)

var (
	test1 = std.Address("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5")

	poolAddr     = std.DerivePkgAddr("gno.land/r/demo/pool")
	positionAddr = std.DerivePkgAddr("gno.land/r/demo/position")
	stakerAddr   = std.DerivePkgAddr("gno.land/r/demo/staker")
	routerAddr   = std.DerivePkgAddr("gno.land/r/demo/router")

	token01Path = "gno.land/r/demo/token01"
	token02Path = "gno.land/r/demo/token02"
	token03Path = "gno.land/r/demo/token03"
	token04Path = "gno.land/r/demo/token04"
	token05Path = "gno.land/r/demo/token05"
	token06Path = "gno.land/r/demo/token06"
	token07Path = "gno.land/r/demo/token07"

	max_timeout = bigint(9999999999)
)

func TestApproveAll(t *testing.T) {
	std.TestSetOrigCaller(test1)

	token01.Approve(a2u(poolAddr), 10_000_000_000_000_000)
	token02.Approve(a2u(poolAddr), 10_000_000_000_000_000)
	token03.Approve(a2u(poolAddr), 10_000_000_000_000_000)
	token04.Approve(a2u(poolAddr), 10_000_000_000_000_000)
	token05.Approve(a2u(poolAddr), 10_000_000_000_000_000)
	token06.Approve(a2u(poolAddr), 10_000_000_000_000_000)
	token07.Approve(a2u(poolAddr), 10_000_000_000_000_000)
}

func TestPoolInitByAdmin(t *testing.T) {
	std.TestSetOrigCaller(test1)

	pl.InitManual()
	std.TestSkipHeights(1)
}

func TestPoolCreatePools(t *testing.T) {
	std.TestSetOrigCaller(test1)

	// approve gns to CreatePool ( 500 gns for 1 pool)
	gns.Approve(a2u(poolAddr), 500*100)

	pl.CreatePool(token01Path, token02Path, 100, getSqrtRatioAtTick(630))
	pl.CreatePool(token01Path, token02Path, 500, getSqrtRatioAtTick(620))
	pl.CreatePool(token01Path, token02Path, 10000, getSqrtRatioAtTick(800))

	pl.CreatePool(token01Path, token03Path, 100, getSqrtRatioAtTick(8134))
	pl.CreatePool(token01Path, token03Path, 500, getSqrtRatioAtTick(8090))
	pl.CreatePool(token01Path, token03Path, 3000, getSqrtRatioAtTick(8160))

	pl.CreatePool(token01Path, token04Path, 100, getSqrtRatioAtTick(15810))
	pl.CreatePool(token01Path, token04Path, 500, getSqrtRatioAtTick(15860))
	pl.CreatePool(token01Path, token04Path, 10000, getSqrtRatioAtTick(15800))

	pl.CreatePool(token01Path, token05Path, 100, getSqrtRatioAtTick(27364))
	pl.CreatePool(token01Path, token05Path, 500, getSqrtRatioAtTick(27310))
	pl.CreatePool(token01Path, token05Path, 3000, getSqrtRatioAtTick(27300))

	pl.CreatePool(token01Path, token06Path, 100, getSqrtRatioAtTick(24362))
	pl.CreatePool(token01Path, token06Path, 500, getSqrtRatioAtTick(24360))
	pl.CreatePool(token01Path, token06Path, 10000, getSqrtRatioAtTick(24200))

	pl.CreatePool(token01Path, token07Path, 100, getSqrtRatioAtTick(16106))
	pl.CreatePool(token01Path, token07Path, 500, getSqrtRatioAtTick(16090))
	pl.CreatePool(token01Path, token07Path, 3000, getSqrtRatioAtTick(16020))

	pl.CreatePool(token02Path, token03Path, 100, getSqrtRatioAtTick(7466))
	pl.CreatePool(token02Path, token03Path, 500, getSqrtRatioAtTick(7480))
	pl.CreatePool(token02Path, token03Path, 10000, getSqrtRatioAtTick(7400))

	pl.CreatePool(token02Path, token04Path, 100, getSqrtRatioAtTick(15108))
	pl.CreatePool(token02Path, token04Path, 500, getSqrtRatioAtTick(15260))
	pl.CreatePool(token02Path, token04Path, 3000, getSqrtRatioAtTick(15240))

	pl.CreatePool(token02Path, token05Path, 100, getSqrtRatioAtTick(26746))
	pl.CreatePool(token02Path, token05Path, 500, getSqrtRatioAtTick(26400))
	pl.CreatePool(token02Path, token05Path, 10000, getSqrtRatioAtTick(26600))

	pl.CreatePool(token02Path, token06Path, 100, getSqrtRatioAtTick(23810))
	pl.CreatePool(token02Path, token06Path, 500, getSqrtRatioAtTick(23710))
	pl.CreatePool(token02Path, token06Path, 3000, getSqrtRatioAtTick(23760))

	pl.CreatePool(token02Path, token07Path, 100, getSqrtRatioAtTick(15580))
	pl.CreatePool(token02Path, token07Path, 500, getSqrtRatioAtTick(15670))
	pl.CreatePool(token02Path, token07Path, 10000, getSqrtRatioAtTick(15600))

	pl.CreatePool(token03Path, token04Path, 100, getSqrtRatioAtTick(7584))
	pl.CreatePool(token03Path, token04Path, 500, getSqrtRatioAtTick(7650))
	pl.CreatePool(token03Path, token04Path, 3000, getSqrtRatioAtTick(7740))

	pl.CreatePool(token03Path, token05Path, 100, getSqrtRatioAtTick(19310))
	pl.CreatePool(token03Path, token05Path, 500, getSqrtRatioAtTick(19400))
	pl.CreatePool(token03Path, token05Path, 10000, getSqrtRatioAtTick(19400))

	pl.CreatePool(token03Path, token06Path, 100, getSqrtRatioAtTick(16302))
	pl.CreatePool(token03Path, token06Path, 500, getSqrtRatioAtTick(16330))
	pl.CreatePool(token03Path, token06Path, 3000, getSqrtRatioAtTick(16560))

	pl.CreatePool(token03Path, token07Path, 100, getSqrtRatioAtTick(8164))
	pl.CreatePool(token03Path, token07Path, 500, getSqrtRatioAtTick(8060))
	pl.CreatePool(token03Path, token07Path, 10000, getSqrtRatioAtTick(8400))

	pl.CreatePool(token04Path, token05Path, 100, getSqrtRatioAtTick(11468))
	pl.CreatePool(token04Path, token05Path, 500, getSqrtRatioAtTick(11750))
	pl.CreatePool(token04Path, token05Path, 3000, getSqrtRatioAtTick(11700))

	pl.CreatePool(token04Path, token06Path, 100, getSqrtRatioAtTick(8508))
	pl.CreatePool(token04Path, token06Path, 500, getSqrtRatioAtTick(8990))
	pl.CreatePool(token04Path, token06Path, 10000, getSqrtRatioAtTick(9000))

	pl.CreatePool(token04Path, token07Path, 100, getSqrtRatioAtTick(258))
	pl.CreatePool(token04Path, token07Path, 500, getSqrtRatioAtTick(850))
	pl.CreatePool(token04Path, token07Path, 3000, getSqrtRatioAtTick(840))

	pl.CreatePool(token05Path, token06Path, 100, getSqrtRatioAtTick(-2692))
	pl.CreatePool(token05Path, token06Path, 500, getSqrtRatioAtTick(-2970))
	pl.CreatePool(token05Path, token06Path, 10000, getSqrtRatioAtTick(-2600))

	pl.CreatePool(token05Path, token07Path, 100, getSqrtRatioAtTick(-11292))
	pl.CreatePool(token05Path, token07Path, 500, getSqrtRatioAtTick(-10800))
	pl.CreatePool(token05Path, token07Path, 3000, getSqrtRatioAtTick(-11100))

	pl.CreatePool(token06Path, token07Path, 100, getSqrtRatioAtTick(-8000))
	pl.CreatePool(token06Path, token07Path, 500, getSqrtRatioAtTick(-8190))
	pl.CreatePool(token06Path, token07Path, 10000, getSqrtRatioAtTick(-7800))

	std.TestSkipHeights(4)
}

func TestPositions(t *testing.T) {
	std.TestSetOrigCaller(test1)

	mintParams := []MintParmas{
		{token01Path, token02Path, 100, -1054, 952, 400000, 400000},
		{token01Path, token02Path, 100, -2168, 50, 400000, 400000},

		{token01Path, token02Path, 500, -6440, 7420, 1070000, 1070000},
		{token01Path, token02Path, 500, 440, 2270, 1850000, 1850000},

		{token01Path, token02Path, 10000, 400, 17000, 10230000, 10230000},
		{token01Path, token02Path, 10000, -15200, 1400, 15040000, 15040000},

		{token01Path, token03Path, 100, 6804, 8810, 616700, 616700},
		{token01Path, token03Path, 100, 5688, 7906, 17000000, 17000000},

		{token01Path, token03Path, 500, 1410, 15280, 2200000, 2200000},
		{token01Path, token03Path, 500, 8290, 10130, 2000000, 2000000},

		{token01Path, token03Path, 3000, 8280, 24900, 1050000, 1050000},
		{token01Path, token03Path, 3000, -7260, 9300, 14070000, 14070000},

		{token01Path, token04Path, 100, 14324, 16330, 1460000, 1460000},
		{token01Path, token04Path, 100, 13208, 15426, 51250000, 51250000},

		{token01Path, token04Path, 500, 8930, 22800, 4878000, 4878000},
		{token01Path, token04Path, 500, 15810, 17650, 1000000, 1000000},

		{token01Path, token04Path, 10000, 15800, 32400, 1060000, 1060000},
		{token01Path, token04Path, 10000, 200, 16800, 34150000, 34150000},

		{token01Path, token05Path, 100, 25698, 27704, 5140000, 5140000},
		{token01Path, token05Path, 100, 24582, 26802, 15810000, 15810000},

		{token01Path, token05Path, 500, 20310, 34170, 7710000, 7710000},
		{token01Path, token05Path, 500, 27190, 29020, 2680000, 2680000},

		{token01Path, token05Path, 3000, 27180, 43800, 1040000, 1040000},
		{token01Path, token05Path, 3000, 11580, 28200, 35940000, 35940000},

		{token01Path, token06Path, 100, 22718, 24726, 3760000, 3760000},
		{token01Path, token06Path, 100, 21604, 23822, 400000, 400000},

		{token01Path, token06Path, 500, 17330, 31190, 11510000, 11510000},
		{token01Path, token06Path, 500, 24210, 26040, 2020000, 2020000},

		{token01Path, token06Path, 10000, 24200, 40800, 1050000, 1050000},
		{token01Path, token06Path, 10000, 8600, 25200, 31850000, 31850000},

		{token01Path, token07Path, 100, 14432, 16438, 1670000, 1670000},
		{token01Path, token07Path, 100, 13316, 15534, 400, 400},

		{token01Path, token07Path, 500, 9040, 22900, 5040000, 5040000},
		{token01Path, token07Path, 500, 15920, 17750, 1860000, 1860000},

		{token01Path, token07Path, 3000, 15900, 32520, 1040000, 1040000},
		{token01Path, token07Path, 3000, 360, 16920, 29040000, 29040000},

		{token02Path, token03Path, 100, 5878, 7884, 676180, 676180},
		{token02Path, token03Path, 100, 4762, 6982, 400000, 400000},

		{token02Path, token03Path, 500, 490, 14350, 2120000, 2120000},
		{token02Path, token03Path, 500, 7370, 9200, 1930000, 1930000},

		{token02Path, token03Path, 10000, 7400, 24000, 1030000, 1030000},
		{token02Path, token03Path, 10000, -8200, 8400, 9820000, 9820000},

		{token02Path, token04Path, 100, 13736, 15742, 1270000, 1270000},
		{token02Path, token04Path, 100, 12620, 14838, 400000, 400000},

		{token02Path, token04Path, 500, 8340, 22210, 4958510, 4958510},
		{token02Path, token04Path, 500, 15230, 17060, 2020000, 2020000},

		{token02Path, token04Path, 3000, 15240, 31860, 1040000, 1040000},
		{token02Path, token04Path, 3000, -360, 16200, 26810000, 26810000},

		{token02Path, token05Path, 100, 25310, 27316, 4240000, 4240000},
		{token02Path, token05Path, 100, 24194, 26414, 400000, 400000},

		{token02Path, token05Path, 500, 19920, 33780, 13540000, 13540000},
		{token02Path, token05Path, 500, 26800, 28630, 2060000, 2060000},

		{token02Path, token05Path, 10000, 26800, 43400, 1060000, 1060000},
		{token02Path, token05Path, 10000, 11200, 27800, 4030000, 4030000},

		{token02Path, token06Path, 100, 22130, 24138, 3630000, 3630000},
		{token02Path, token06Path, 100, 21016, 23234, 400000, 400000},

		{token02Path, token06Path, 500, 16740, 30600, 10730000, 10730000},
		{token02Path, token06Path, 500, 23620, 25450, 1950000, 1950000},

		{token02Path, token06Path, 3000, 23640, 40260, 1030000, 1030000},
		{token02Path, token06Path, 3000, 8040, 24600, 62930000, 62930000},

		{token02Path, token07Path, 100, 13944, 15950, 1560000, 1560000},
		{token02Path, token07Path, 100, 12828, 15046, 400000, 400000},

		{token02Path, token07Path, 500, 8550, 22420, 4850000, 4850000},
		{token02Path, token07Path, 500, 15430, 17270, 1770000, 1770000},

		{token02Path, token07Path, 10000, 15400, 32000, 1030000, 1030000},
		{token02Path, token07Path, 10000, -200, 16400, 33720000, 33720000},

		{token03Path, token04Path, 100, 5878, 7884, 727600, 727600},
		{token03Path, token04Path, 100, 4762, 6982, 40000, 400000},

		{token03Path, token04Path, 500, 490, 14350, 2180000, 2180000},
		{token03Path, token04Path, 500, 7370, 9200, 1730000, 173000},

		{token03Path, token04Path, 3000, 7380, 24000, 1010000, 1010000},
		{token03Path, token04Path, 3000, -8220, 8400, 45100000, 45100000},

		{token03Path, token05Path, 100, 11790, 19796, 2120000, 2120000},
		{token03Path, token05Path, 100, 16674, 18894, 400000, 400000},

		{token03Path, token05Path, 500, 12400, 26260, 700000, 700000},
		{token03Path, token05Path, 500, 19280, 21110, 1910000, 1910000},

		{token03Path, token05Path, 10000, 19200, 35800, 1030000, 1030000},
		{token03Path, token05Path, 10000, 3800, 202000, 49070000, 49070000},

		{token03Path, token06Path, 100, 14812, 16818, 1540000, 1540000},
		{token03Path, token06Path, 100, 13696, 15914, 400000, 400000},

		{token03Path, token06Path, 500, 9420, 23280, 5110000, 5110000},
		{token03Path, token06Path, 500, 16300, 18130, 2030000, 2030000},

		{token03Path, token06Path, 3000, 16320, 32940, 1020000, 1020000},
		{token03Path, token06Path, 3000, 720, 17280, 3048000, 3048000},

		{token03Path, token07Path, 100, 6524, 8530, 744280, 744280},
		{token03Path, token07Path, 100, 5408, 7628, 400000, 400000},

		{token03Path, token07Path, 500, 1130, 15000, 2240000, 2240000},
		{token03Path, token07Path, 500, 8010, 9850, 2010000, 2010000},

		{token03Path, token07Path, 10000, 8000, 24600, 1020000, 1020000},
		{token03Path, token07Path, 10000, -7600, 9000, 16350000, 16350000},

		{token04Path, token05Path, 100, 9932, 11940, 975000, 975000},
		{token04Path, token05Path, 100, 8816, 11036, 400000, 400000},

		{token04Path, token05Path, 500, 4540, 18410, 3300000, 3300000},
		{token04Path, token05Path, 500, 11420, 13260, 1680000, 1680000},

		{token04Path, token05Path, 3000, 11400, 28020, 1020000, 1020000},
		{token04Path, token05Path, 3000, -4140, 12420, 18870000, 18870000},

		{token04Path, token06Path, 100, 7292, 9298, 589000, 589000},
		{token04Path, token06Path, 100, 6176, 8394, 400000, 400000},

		{token04Path, token06Path, 500, 1900, 15760, 2480000, 2480000},
		{token04Path, token06Path, 500, 8780, 10610, 1820000, 1820000},

		{token04Path, token06Path, 10000, 8800, 25400, 10150000, 10150000},
		{token04Path, token06Path, 10000, -6800, 9800, 57560000, 57560000},

		{token04Path, token07Path, 100, -796, 1210, 226400, 226400},
		{token04Path, token07Path, 100, -1910, 308, 14010000, 14010000},

		{token04Path, token07Path, 500, -6190, 7680, 1100000, 1100000},
		{token04Path, token07Path, 500, 700, 2530, 9410000, 9410000},

		{token04Path, token07Path, 3000, 720, 17280, 6190000, 6190000},
		{token04Path, token07Path, 3000, -14880, 1680, 38170000, 38170000},

		{token05Path, token06Path, 100, -4620, -2614, 289000, 289000},
		{token05Path, token06Path, 100, -5736, -3516, 400000, 400000},

		{token05Path, token06Path, 500, -10010, 3850, 981540, 981540},
		{token05Path, token06Path, 500, -3130, -1300, 9370000, 9370000},

		{token05Path, token06Path, 10000, -3200, 13400, 10000000, 10000000},
		{token05Path, token06Path, 10000, -18800, -2200, 43235000, 43235000},

		{token05Path, token07Path, 100, -12370, -10362, 195000, 195000},
		{token05Path, token07Path, 100, -13486, -11266, 394000, 394000},

		{token05Path, token07Path, 500, -17760, -3900, 994700, 994700},
		{token05Path, token07Path, 500, -10880, -9050, 19640000, 19640000},

		{token05Path, token07Path, 3000, -10860, 5760, 10440000, 10440000},
		{token05Path, token07Path, 3000, -26460, -9900, 4170000, 4170000},

		{token06Path, token07Path, 100, -9728, -7722, 154000, 154000},
		{token06Path, token07Path, 100, -10844, -8626, 400000, 400000},

		{token06Path, token07Path, 500, -15120, -1260, 1000000, 1000000},
		{token06Path, token07Path, 500, -8240, -6410, 10000000, 10000000},

		{token06Path, token07Path, 10000, -8200, 8400, 10000000, 10000000},
		{token06Path, token07Path, 10000, -23800, -7200, 8556000, 8556000},
	}

	for _, params := range mintParams {
		tokenId, liquidity, amount0, amount1 := pos.Mint(params.token0Path, params.token1Path, params.fee, params.tickLower, params.tickUpper, params.amount0Desired, params.amount1Desired, 0, 0, max_timeout)
		println("tokenId:", tokenId, "amount0:", amount0, "amount1:", amount1)
		// println("tokenId:", tokenId, "liquidity:", liquidity, "amount0:", amount0, "amount1:", amount1)
	}

}

type MintParmas struct {
	token0Path     string
	token1Path     string
	fee            uint16
	tickLower      int32
	tickUpper      int32
	amount0Desired bigint
	amount1Desired bigint
}
