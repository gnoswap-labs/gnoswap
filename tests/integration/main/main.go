package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/gnoswap-labs/gnoswap/tests/integration/testscriptgen/scriptgen"
)

func main() {
	// gno file directory
	rootDir := "./contract"

	// traverse all directories and process .gno files
	err := filepath.Walk(rootDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		// skip directories
		if info.IsDir() {
			return nil
		}
		if filepath.Ext(path) == ".gno" {
			cmds, err := scriptgen.ProcessFile(path)
			if err != nil {
				log.Printf("Error processing %s: %v", path, err)
				return nil
			}
			for _, cmd := range cmds {
				fmt.Println(cmd)
			}
		}
		return nil
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error walking directory: %v\n", err)
		os.Exit(1)
	}
}
