package router

import (
	"strconv"
	"strings"

	p "gno.land/r/pool"

	"gno.land/p/demo/ufmt"
)

func findSwapPaths(
	inputTokenPath string,
	outputTokenPath string,
) (swapPaths SwapPaths) {
	tokenPairs := TokenPairs{}
	poolList := p.GetPoolList()

	for i, poolPath := range poolList {
		token0Path, token1Path, pFee := poolPathWithFeeDivide(poolPath)

		{
			k := token0Path
			v := token1Path + ":" + strconv.Itoa(pFee)

			tokenPairs[k] = append(tokenPairs[k], v)
		}

		{
			k := token1Path
			v := token0Path + ":" + strconv.Itoa(pFee)

			tokenPairs[k] = append(tokenPairs[k], v)
		}
	}

	swapPaths = getSwapPaths(tokenPairs, inputTokenPath, outputTokenPath)
	return swapPaths
}

func getSwapPaths(
	tokenPairs TokenPairs,
	inputTokenPath string,
	outputTokenPath string,
) (swapPaths SwapPaths) {
	swapPaths = make(SwapPaths, 0)

	// check if there is path that starts with input
	require(len(tokenPairs[inputTokenPath]) != 0, ufmt.Sprintf("[ROUTER] find_path.gno__getSwapPaths() || len(tokenPairs[inputTokenPath]) == 0, inputTokenPath: %s", inputTokenPath))

	// find direct path
	for _, output := range tokenPairs[inputTokenPath] {
		if strings.HasPrefix(output, outputTokenPath) {
			outputPath, outputFee := singlePoolPathWithFeeDivide(output)
			directPath := inputTokenPath + "," + outputFee + "," + outputPath
			swapPaths = append(swapPaths, directPath)

			tokenPairs[inputTokenPath] = removeItemFromStringArray(tokenPairs[inputTokenPath], output)
		}
	}

	// find nested path
	swapPaths = findTwicePath(tokenPairs, inputTokenPath, outputTokenPath, swapPaths)
	swapPaths = findThreeTimePath(tokenPairs, inputTokenPath, outputTokenPath, swapPaths)

	return swapPaths
}

func findTwicePath(
	tokenPairs TokenPairs,
	inputTokenPath string,
	outputTokenPath string,
	swapPaths SwapPaths,
) SwapPaths {
	for _, second := range tokenPairs[inputTokenPath] {
		secondPath, secondFee := singlePoolPathWithFeeDivide(second)

		for _, third := range tokenPairs[secondPath] {
			thirdPath, thirdFee := singlePoolPathWithFeeDivide(third)

			if strings.HasPrefix(third, outputTokenPath) {
				nestedPath := inputTokenPath + "," + secondFee + "," + secondPath + "," + thirdFee + "," + outputTokenPath
				swapPaths[len(swapPaths)] = nestedPath
			}
		}
	}

	return swapPaths
}

func findThreeTimePath(
	tokenPairs TokenPairs,
	inputTokenPath string,
	outputTokenPath string,
	swapPaths SwapPaths,
) SwapPaths {
	for _, second := range tokenPairs[inputTokenPath] {
		secondPath, secondFee := singlePoolPathWithFeeDivide(second)

		for _, third := range tokenPairs[secondPath] { // bar > bz
			thirdPath, thirdFee := singlePoolPathWithFeeDivide(third)

			for _, fourth := range tokenPairs[thirdPath] {
				fourthPath, fourthFee := singlePoolPathWithFeeDivide(fourth)

				if strings.HasPrefix(fourth, outputTokenPath) {
					// three times
					nestedPath := inputTokenPath + "," + secondFee + "," + secondPath + "," + thirdFee + "," + thirdPath + "," + fourthFee + "," + fourthPath
					swapPaths[len(swapPaths)] = nestedPath
				}
			}
		}
	}
	return swapPaths
}
