package router

import "strings"

func findTwicePath(
	tokenPairs TokenPairs,
	inputTokenPath string,
	outputTokenPath string,
	swapPaths SwapPaths,
) SwapPaths {
	for _, second := range tokenPairs[inputTokenPath] {
		secondPath, secondFee := singlePoolPathWithFeeDivide(second)
		tokenPairs[inputTokenPath] = removeItemFromStringArray(tokenPairs[inputTokenPath], second)
		tokenPairs[secondPath] = removeItemFromStringArray(tokenPairs[secondPath], (inputTokenPath + ":" + secondFee))

		for _, third := range tokenPairs[secondPath] {
			thirdPath, thirdFee := singlePoolPathWithFeeDivide(third)
			tokenPairs[secondPath] = removeItemFromStringArray(tokenPairs[secondPath], third)
			tokenPairs[thirdPath] = removeItemFromStringArray(tokenPairs[thirdPath], (secondPath + ":" + thirdFee))

			if strings.HasPrefix(third, outputTokenPath) {
				// twice
				nestedPath := inputTokenPath + "," + secondFee + "," + secondPath + "," + secondFee + "," + outputTokenPath

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
		tokenPairs[secondPath] = removeItemFromStringArray(tokenPairs[secondPath], (inputTokenPath + ":" + secondFee))

		for _, third := range tokenPairs[secondPath] { // bar > bz
			thirdPath, thirdFee := singlePoolPathWithFeeDivide(third)
			tokenPairs[secondPath] = removeItemFromStringArray(tokenPairs[thirdPath], (secondPath + ":" + thirdFee))

			for _, fourth := range tokenPairs[thirdPath] {
				fourthPath, fourthFee := singlePoolPathWithFeeDivide(fourth)

				if strings.HasPrefix(fourth, outputTokenPath) {
					// three times
					nestedPath := inputTokenPath + "," + secondFee + "," + secondPath + "," + secondFee + "," + thirdPath + "," + thirdFee + "," + fourthPath
					swapPaths[len(swapPaths)] = nestedPath
				}
			}
		}
	}
	return swapPaths
}
