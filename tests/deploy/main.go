package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"text/template"
)

type Package struct {
	Name    string
	Path    string
	PkgPath string
	IsRealm bool
}

const deployTemplate = `deploy-{{.Name}}:
	$(info ************ deploy {{.Name}} ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/{{.Path}} -pkgpath {{.PkgPath}} -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

`

const makefileTemplate = `# Code generated by makefile-codegen. DO NOT EDIT.
# Source: github.com/gnoswap/gnoswap/tests/deploy/main.go
# To generate this file, run:
# go run main.go > deploy.mk

include _info.mk

## INIT
.PHONY: init
init: send-ugnot-must deploy-test-tokens deploy-libraries deploy-base-tokens deploy-gnoswap-realms

.PHONY: deploy-test-tokens
deploy-test-tokens: {{.TestTokens}}

.PHONY: deploy-libraries
deploy-libraries: {{.Libraries}}

.PHONY: deploy-base-tokens
deploy-base-tokens: {{.BaseTokens}}

.PHONY: deploy-gnoswap-realms
deploy-gnoswap-realms: {{.GnoswapRealms}}

# send ugnot to necessary accounts
send-ugnot-must:
	$(info ************ send ugnot to necessary accounts ************)
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_GNOSWAP) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" test1
	@echo

{{ .DeployCommands }}
`

type MakefileData struct {
	TestTokens     string
	Libraries      string
	BaseTokens     string
	GnoswapRealms  string
	DeployCommands string
}

// isValidPackageDir checks if the directory is a valid package directory by checking for gno.mod file
func isValidPackageDir(path string) bool {
	_, err := os.Stat(filepath.Join(path, "gno.mod"))
	return err == nil
}

func findContractDir() (string, error) {
	// Start from current directory and go up until we find contract directory
	currentDir, err := os.Getwd()
	if err != nil {
		return "", fmt.Errorf("failed to get current directory: %v", err)
	}

	dir := currentDir
	for {
		// Check if contract/p/gnoswap exists in this directory
		if _, err := os.Stat(filepath.Join(dir, "contract", "p", "gnoswap")); err == nil {
			return filepath.Join(dir, "contract"), nil
		}

		// Go up one directory
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("could not find contract directory")
		}
		dir = parent
	}
}

func discoverPackages() ([]Package, error) {
	var packages []Package

	// Find contract directory
	contractDir, err := findContractDir()
	if err != nil {
		return nil, err
	}

	// Change to contract directory
	err = os.Chdir(contractDir)
	if err != nil {
		return nil, fmt.Errorf("failed to change to contract directory: %v", err)
	}

	// Discover packages in p/gnoswap
	err = filepath.Walk("p/gnoswap", func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() && filepath.Base(path) != "gnoswap" {
			if isValidPackageDir(path) {
				relPath, _ := filepath.Rel("p/gnoswap", path)
				pkgName := filepath.Base(path)
				packages = append(packages, Package{
					Name:    pkgName,
					Path:    "p/gnoswap/" + relPath,
					PkgPath: "gno.land/p/gnoswap/" + relPath,
					IsRealm: false,
				})
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	// Discover packages in r/gnoswap
	err = filepath.Walk("r/gnoswap", func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() && filepath.Base(path) != "gnoswap" {
			if isValidPackageDir(path) {
				relPath, _ := filepath.Rel("r/gnoswap", path)
				pkgName := filepath.Base(path)

				// Skip test_token directory itself
				if pkgName == "test_token" {
					return nil
				}

				packages = append(packages, Package{
					Name:    pkgName,
					Path:    "r/gnoswap/" + relPath,
					PkgPath: "gno.land/r/gnoswap/v1/" + relPath,
					IsRealm: true,
				})
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	return packages, nil
}

func main() {
	packages, err := discoverPackages()
	if err != nil {
		log.Fatal(err)
	}

	// Generate deploy commands
	tmpl := template.Must(template.New("deploy").Parse(deployTemplate))
	var deployCommands strings.Builder
	var testTokens []string
	var libraries []string
	var baseTokens []string
	var gnoswapRealms []string

	for _, pkg := range packages {
		var deployCmd strings.Builder
		err := tmpl.Execute(&deployCmd, pkg)
		if err != nil {
			log.Fatal(err)
		}
		deployCommands.WriteString(deployCmd.String())

		deployName := "deploy-" + pkg.Name

		// Categorize packages
		if strings.HasPrefix(pkg.Path, "r/gnoswap/test_token/") {
			testTokens = append(testTokens, deployName)
		} else if !pkg.IsRealm {
			libraries = append(libraries, deployName)
		} else if pkg.Name == "gns" || pkg.Name == "gnft" {
			baseTokens = append(baseTokens, deployName)
		} else if pkg.IsRealm {
			gnoswapRealms = append(gnoswapRealms, deployName)
		}
	}

	// Generate final makefile
	makefileData := MakefileData{
		TestTokens:     strings.Join(testTokens, " "),
		Libraries:      strings.Join(libraries, " "),
		BaseTokens:     strings.Join(baseTokens, " "),
		GnoswapRealms:  strings.Join(gnoswapRealms, " "),
		DeployCommands: deployCommands.String(),
	}

	makefileTmpl := template.Must(template.New("makefile").Parse(makefileTemplate))
	err = makefileTmpl.Execute(os.Stdout, makefileData)
	if err != nil {
		log.Fatal(err)
	}
}
