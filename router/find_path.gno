package router

import (
	"strconv"
	"strings"

	p "gno.land/r/demo/pool"

	"gno.land/p/demo/ufmt"
)

func findSwapPaths(
	inputTokenPath string,
	outputTokenPath string,
	maxHops int,
) string {
	tokenPairs := TokenPairs{}
	poolList := p.PoolGetPoolList()

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

	swapPaths := getSwapPaths(tokenPairs, inputTokenPath, outputTokenPath, maxHops)
	return swapPaths
}

func getSwapPaths(
	tokenPairs TokenPairs,
	inputTokenPath string,
	outputTokenPath string,
	maxHops int,
) string {
	var builder strings.Builder

	// check if there is path that starts with input
	require(len(tokenPairs[inputTokenPath]) != 0, ufmt.Sprintf("[ROUTER] find_path.gno__getSwapPaths() || len(tokenPairs[inputTokenPath]) == 0, inputTokenPath: %s", inputTokenPath))

	// find direct path
	for _, output := range tokenPairs[inputTokenPath] {
		if strings.HasPrefix(output, outputTokenPath) {
			outputPath, outputFee := singlePoolPathWithFeeDivide(output)
			appendToBuilder(&builder, inputTokenPath, ",", outputFee, ",", outputPath, "_FIN_")
			tokenPairs[inputTokenPath] = removeItemFromStringArray(tokenPairs[inputTokenPath], output)
		}
	}

	firstToken := ""
	for i := 1; i <= maxHops; i++ {
		findPath(tokenPairs, inputTokenPath, outputTokenPath, "", i, &firstToken, &builder)
	}

	return builder.String()
}

func findPath(
	tokenPairs TokenPairs,
	currentTokenPath string,
	outputTokenPath string,
	currentPath string,
	remainingHops int,
	firstToken *string,
	builder *strings.Builder,
) {
	if *firstToken == "" {
		*firstToken = currentTokenPath
	}

	if remainingHops == 0 {
		if strings.HasPrefix(currentTokenPath, outputTokenPath) {
			appendToBuilder(builder, *firstToken, ",", currentPath, "_FIN_")
		}
		return
	}

	for _, next := range tokenPairs[currentTokenPath] {
		nextPath, nextFee := singlePoolPathWithFeeDivide(next)
		newPath := currentPath
		if currentPath != "" {
			newPath += ","
		}
		newPath += nextFee + "," + nextPath
		// remove found path
		tokenPairs[currentTokenPath] = removeItemFromStringArray(tokenPairs[currentTokenPath], newPath)
		// remove opposite path
		tokenPairs[nextPath] = removeItemFromStringArray(tokenPairs[nextPath], (currentTokenPath + ":" + nextFee))

		findPath(tokenPairs, nextPath, outputTokenPath, newPath, remainingHops-1, firstToken, builder)
	}
}

// appendToBuilder appends the given elements to the strings.Builder.
// It takes a pointer to a strings.Builder and a variadic parameter of strings.
// The elements are appended to the builder in the order they are provided.
func appendToBuilder(builder *strings.Builder, elements ...string) {
	for _, element := range elements {
		builder.WriteString(element)
	}
}
