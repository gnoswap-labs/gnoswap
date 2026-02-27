package main

import (
	"os"

	"gnodoc/cmd"
)

func main() {
	runner := cmd.NewRunner(os.Stdout, os.Stderr)
	code := runner.Run(os.Args[1:])
	os.Exit(int(code))
}
