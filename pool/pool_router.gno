package pool

import (
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"
)

type POSSIBLE_PATHS map[int][]string

func FindAllPoolPath(
	inputTokenPath string,
	outputTokenPath string,
	maxDepths int,
) POSSIBLE_PATHS {

	tokenPairs := make(map[string][]string)

	for poolPath, _ := range pools {
		token0Path, token1Path, pFee := poolPathWithFeeDivide(poolPath)

		k := token0Path
		v := token1Path + ":" + strconv.Itoa(int(pFee))

		tokenPairs[k] = append(tokenPairs[k], v)
	}

	// r3v4_xx: pass max_depth
	possiblePaths := getSwapPaths(tokenPairs, inputTokenPath, outputTokenPath)

	return possiblePaths
}

func getSwapPaths(
	tokenPairs map[string][]string,
	inputTokenPath string,
	outputTokenPath string,
) POSSIBLE_PATHS {
	// r3v4_xx: handle max_depth

	possiblePaths := make(POSSIBLE_PATHS, 0)

	for firstPath, secondPaths := range tokenPairs {
		if firstPath == inputTokenPath { // find if direct path exists
			for _, secondPath := range secondPaths {
				if strings.HasPrefix(secondPath, outputTokenPath) {
					fullPath := inputTokenPath + " > " + secondPath
					possiblePaths[len(possiblePaths)] = []string{fullPath}
				}
			}
		} else { // no direct path
			for _, secondPathWithFee := range secondPaths {
				secondPath, sFee := singlePoolPathWithFeeDivide(secondPathWithFee)

				if secondPath == inputTokenPath {
					// l2 go
					for i, thirdPathWithFee := range tokenPairs[secondPath] {
						thirdPath, tFee := singlePoolPathWithFeeDivide(thirdPathWithFee)

						if strings.HasPrefix(thirdPathWithFee, outputTokenPath) {
							fullPath := inputTokenPath + " > " + firstPath + ":" + strconv.Itoa(int(sFee)) + " > " + thirdPathWithFee
							possiblePaths[len(possiblePaths)] = []string{fullPath}
						}
					}
				} else {
					// l3 go
					for i, secondPathWithFee := range tokenPairs[firstPath] {
						secondPath, sFee := singlePoolPathWithFeeDivide(secondPathWithFee)

						if strings.HasPrefix(secondPathWithFee, inputTokenPath) {
							partialPath := ""
							partialPath += inputTokenPath + " > " + firstPath + ":" + strconv.Itoa(int(sFee))
							// println("F PARTIAL:", partialPath)

							for _, thirdPathWithFee := range tokenPairs[firstPath] {
								thirdPath, tFee := singlePoolPathWithFeeDivide(thirdPathWithFee)

								if thirdPath != inputTokenPath && thirdPath != outputTokenPath {
									partialPath += " > " + thirdPathWithFee

									for i, fourthPathWithFee := range tokenPairs[thirdPath] {
										if strings.HasPrefix(fourthPathWithFee, outputTokenPath) {
											fourthPath, _ := singlePoolPathWithFeeDivide(fourthPathWithFee)

											// THIS IS FULL PATH
											partialPath += " > " + fourthPathWithFee
											possiblePaths[len(possiblePaths)] = []string{partialPath}

											firstToSecond := tokenPairs[firstPath]
											toDel := secondPath + ":" + strconv.Itoa(int(sFee))
											remove(firstToSecond, toDel)
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}

	return possiblePaths
}

func poolPathWithFeeDivide(poolPath string) (string, string, uint16) {
	poolPathSplit := strings.Split(poolPath, ":")

	if len(poolPathSplit) != 3 {
		panic(ufmt.Sprintf("[POOL] pool_router.gno__poolPathWithFeeDivide() || len(poolPathSplit) != 3, poolPath: %s", poolPath))
	}

	feeInt, err := strconv.Atoi(poolPathSplit[2])
	if err != nil {
		panic(ufmt.Sprintf("[POOL] pool_router.gno__poolPathWithFeeDivide() || cannot convert fee(%s) to uint16", poolPathSplit[2]))
	}

	return poolPathSplit[0], poolPathSplit[1], uint16(feeInt)
}

func singlePoolPathWithFeeDivide(poolPath string) (string, uint16) {
	singlePoolPathSplit := strings.Split(poolPath, ":")

	if len(singlePoolPathSplit) != 2 {
		panic(ufmt.Sprintf("[POOL] pool_router.gno__singlePoolPathWithFeeDivide || len(singlePoolPathSplit) != 2, poolPath: %s", poolPath))
	}

	feeInt, err := strconv.Atoi(singlePoolPathSplit[1])
	if err != nil {
		panic(ufmt.Sprintf("[POOL] pool_router.gno__singlePoolPathWithFeeDivide() || cannot convert fee(%s) to uint16", singlePoolPathSplit[1]))
	}

	return singlePoolPathSplit[0], uint16(feeInt)
}
