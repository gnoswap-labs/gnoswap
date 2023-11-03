package router

import (
	"strconv"
	"strings"

	p "gno.land/r/pool"
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
	if len(tokenPairs[inputTokenPath]) == 0 {
		panic("find_path.gno__NO POOL")
	}

	// find direct path
	for _, output := range tokenPairs[inputTokenPath] {
		if strings.HasPrefix(output, outputTokenPath) {
			outputPath, outputFee := singlePoolPathWithFeeDivide(output)
			directPath := inputTokenPath + "," + outputFee + "," + outputPath
			swapPaths[len(swapPaths)] = directPath

			tokenPairs[inputTokenPath] = removeItemFromStringArray(tokenPairs[inputTokenPath], output)
		}
	}

	// find nested path
	// r3v4_xx: handle more than three time swap ??
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
		// tokenPairs[inputTokenPath] = removeItemFromStringArray(tokenPairs[inputTokenPath], second)
		// tokenPairs[secondPath] = removeItemFromStringArray(tokenPairs[secondPath], (inputTokenPath + ":" + secondFee))

		for _, third := range tokenPairs[secondPath] {
			thirdPath, thirdFee := singlePoolPathWithFeeDivide(third)
			// tokenPairs[secondPath] = removeItemFromStringArray(tokenPairs[secondPath], third)
			// tokenPairs[thirdPath] = removeItemFromStringArray(tokenPairs[thirdPath], (secondPath + ":" + thirdFee))

			if strings.HasPrefix(third, outputTokenPath) {
				// twice
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
		// tokenPairs[secondPath] = removeItemFromStringArray(tokenPairs[secondPath], (inputTokenPath + ":" + secondFee))

		for _, third := range tokenPairs[secondPath] { // bar > bz
			thirdPath, thirdFee := singlePoolPathWithFeeDivide(third)
			// tokenPairs[secondPath] = removeItemFromStringArray(tokenPairs[thirdPath], (secondPath + ":" + thirdFee))

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
