package scriptgen

import (
	"bufio"
	"errors"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strings"
)

// ProcessFile parses a gno file passed as a parameter and generates test command
// strings (gnokey maketx call ...) for each public function.
func ProcessFile(path string) ([]string, error) {
	var cmds []string

	fset := token.NewFileSet()
	f, err := parser.ParseFile(fset, path, nil, parser.ParseComments)
	if err != nil {
		return nil, fmt.Errorf("failed to parse file %s: %w", path, err)
	}

	// Read the module declaration from `gno.mod` in the file's directory
	// (or parent directory) to determine the package path
	pkgPath, err := DerivePackagePath(path)
	if err != nil {
		// use fallback if `gno.mod` file is not found
		pkgPath = FallbackDerivePackagePath(path)
	}

	// extract only exported functions from the AST
	for _, decl := range f.Decls {
		fn, ok := decl.(*ast.FuncDecl)
		if !ok {
			continue
		}
		if !fn.Name.IsExported() {
			continue
		}

		// traverse function parameters and determine default values based on their types
		args := []string{}
		if fn.Type.Params != nil {
			for _, field := range fn.Type.Params.List {
				typeStr := ExprToString(field.Type)
				// process multiple names in a single field with count handling
				count := 1
				if len(field.Names) > 0 {
					count = len(field.Names)
				}
				for i := 0; i < count; i++ {
					defaultArg := GetDefaultArg(typeStr)
					args = append(args, defaultArg)
				}
			}
		}

		// generate test command string
		cmd := fmt.Sprintf("gnokey maketx call -pkgpath %s -func %s", pkgPath, fn.Name.Name)
		for _, arg := range args {
			cmd += fmt.Sprintf(" -args %s", arg)
		}
		// add additional options if needed
		cmd += " -gas-fee 1ugnot -gas-wanted 3000000000 -broadcast -chainid=tendermint_test test1"
		cmds = append(cmds, cmd)
	}

	return cmds, nil
}

// DerivePackagePath traverses up from the file path to find gno.mod file and
// returns the package path by reading the "module gno.land/..." declaration
// from the file.
func DerivePackagePath(filePath string) (string, error) {
	dir := filepath.Dir(filePath)
	for {
		modFile := filepath.Join(dir, "gno.mod")
		if _, err := os.Stat(modFile); err == nil {
			// if `gno.mod` file exists, open it and find the module declaration
			f, err := os.Open(modFile)
			if err != nil {
				return "", fmt.Errorf("failed to open %s: %w", modFile, err)
			}
			defer f.Close()

			scanner := bufio.NewScanner(f)
			for scanner.Scan() {
				line := strings.TrimSpace(scanner.Text())
				if strings.HasPrefix(line, "module ") {
					parts := strings.Fields(line)
					if len(parts) >= 2 {
						return parts[1], nil
					}
				}
			}
			if err := scanner.Err(); err != nil {
				return "", fmt.Errorf("error reading %s: %w", modFile, err)
			}
		}
		// move to the parent directory
		parentDir := filepath.Dir(dir)
		if parentDir == dir {
			break
		}
		dir = parentDir
	}
	return "", errors.New("gno.mod file not found")
}

// FallbackDerivePackagePath derives the package path simply based on the file path
// when `gno.mod` file cannot be found.
func FallbackDerivePackagePath(filePath string) string {
	parts := strings.Split(filePath, string(os.PathSeparator))
	var pkgType string
	var pkgDirs []string
	for i, p := range parts {
		if p == "contract" && i+2 < len(parts) {
			pkgType = parts[i+1]
			pkgDirs = parts[i+2 : len(parts)-1]
			break
		}
	}
	basePath := fmt.Sprintf("gno.land/%s", pkgType)
	if len(pkgDirs) > 0 {
		basePath += "/" + strings.Join(pkgDirs, "/")
	}
	return basePath
}

// ExprToString converts an `ast.Expr` to a simple string.
func ExprToString(expr ast.Expr) string {
	switch t := expr.(type) {
	case *ast.Ident:
		return t.Name
	case *ast.SelectorExpr:
		return ExprToString(t.X) + "." + t.Sel.Name
	case *ast.StarExpr:
		return "*" + ExprToString(t.X)
	default:
		return "<unknown>"
	}
}

// GetDefaultArg returns a default argument value based on the type string.
// For `std.Address` type, it returns a dummy address string in "g1xxxxx" format.
func GetDefaultArg(typ string) string {
	switch typ {
	case "string":
		return `""`
	case "int", "int64", "uint", "uint64":
		return "0"
	case "bool":
		return "false"
	case "std.Address":
		// TODO: The `std.Address` values can use the strings
		// defined in the `contract/p/gnoswap/consts/consts.gno` file,
		// but we need to determine the rules for when and which values to use.
		return `"g1defaultaddress000000000000000000000000"`
	default:
		return `"<default>"`
	}
}
