package parser

import (
	"bufio"
	"bytes"
	"fmt"
	"go/ast"
	"go/doc"
	"go/parser"
	"go/printer"
	"go/token"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"unicode"

	"gnodoc/model"
)

// Parser parses Go/Gno source files and converts them to DocPackage.
type Parser struct {
	opts           *Options
	fset           *token.FileSet
	hadParseErrors bool
	moduleRoot     string
	modulePath     string
}

// New creates a new parser with the given options.
func New(opts *Options) *Parser {
	if opts == nil {
		opts = DefaultOptions()
	}
	moduleRoot := ""
	if opts.ModuleRoot != "" {
		moduleRoot = filepath.Clean(opts.ModuleRoot)
	}
	return &Parser{
		opts:           opts,
		fset:           token.NewFileSet(),
		hadParseErrors: false,
		moduleRoot:     moduleRoot,
		modulePath:     "",
	}
}

// HadParseErrors returns true if some files failed to parse
// when IgnoreParseErrors was enabled.
func (p *Parser) HadParseErrors() bool {
	return p.hadParseErrors
}

// ParsePackage parses all Go/Gno files in the given path.
// The path can be a directory path or an import path (e.g., "fmt").
func (p *Parser) ParsePackage(path string) (*model.DocPackage, error) {
	// First, try to resolve as a directory path
	dir := path
	if p.opts.ModuleRoot != "" && !filepath.IsAbs(path) {
		candidate := filepath.Join(p.opts.ModuleRoot, path)
		if info, err := os.Stat(candidate); err == nil && info.IsDir() {
			dir = candidate
		}
	}

	info, err := os.Stat(dir)
	if err != nil || !info.IsDir() {
		// Try to resolve as an import path
		resolved, resolveErr := p.resolveImportPath(path)
		if resolveErr != nil {
			// Return the original error if it was a valid path attempt
			if err != nil {
				return nil, fmt.Errorf("cannot access directory: %w", err)
			}
			return nil, fmt.Errorf("not a directory: %s", path)
		}
		dir = resolved
	}

	if p.opts.ModuleRoot != "" {
		p.moduleRoot = filepath.Clean(p.opts.ModuleRoot)
	} else if root, ok := findModuleRoot(dir); ok {
		p.moduleRoot = root
	} else {
		p.moduleRoot = dir
	}
	p.modulePath = readGnoModModule(p.moduleRoot)

	// Collect files
	files, err := p.collectFiles(dir)
	if err != nil {
		return nil, err
	}

	if len(files) == 0 {
		return nil, fmt.Errorf("no Go/Gno files found in %s", dir)
	}

	// Parse files
	pkgs, err := p.parseFiles(dir, files)
	if err != nil {
		return nil, err
	}

	if len(pkgs) == 0 {
		return nil, fmt.Errorf("no packages found in %s", dir)
	}

	// Get the main package (not test package)
	var mainPkg *ast.Package
	for name, pkg := range pkgs {
		if !strings.HasSuffix(name, "_test") {
			mainPkg = pkg
			break
		}
	}
	if mainPkg == nil {
		// If only test packages, use first one
		for _, pkg := range pkgs {
			mainPkg = pkg
			break
		}
	}

	// Convert to go/doc.Package
	mode := doc.AllDecls
	if p.opts.ExportedOnly {
		mode = 0
	}
	docPkg := doc.New(mainPkg, dir, mode)

	// Convert to model.DocPackage
	var examples []*doc.Example
	if p.opts.IncludeTests {
		examples = p.collectExamplesFromFiles(dir, files)
	}
	return p.convertPackage(docPkg, dir, files, examples, p.moduleRoot, p.modulePath), nil
}

// collectFiles returns all Go/Gno files in the directory.
func (p *Parser) collectFiles(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("cannot read directory: %w", err)
	}

	var files []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		name := entry.Name()

		// Check extension
		if !strings.HasSuffix(name, ".go") && !strings.HasSuffix(name, ".gno") {
			continue
		}

		// Skip test files if not included
		if !p.opts.IncludeTests && isTestFile(name) {
			continue
		}

		// Check exclude patterns
		if p.isExcluded(name) {
			continue
		}

		files = append(files, name)
	}

	return files, nil
}

// isExcluded checks if a filename matches any exclude pattern.
func (p *Parser) isExcluded(name string) bool {
	for _, pattern := range p.opts.Exclude {
		if matched, _ := filepath.Match(pattern, name); matched {
			return true
		}
	}
	return false
}

// resolveImportPath resolves a Go import path to a directory path.
func (p *Parser) resolveImportPath(importPath string) (string, error) {
	// Use go list to resolve the import path
	cmd := exec.Command("go", "list", "-f", "{{.Dir}}", importPath)
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("cannot resolve import path %q: %w", importPath, err)
	}

	dir := strings.TrimSpace(string(output))
	if dir == "" {
		return "", fmt.Errorf("cannot resolve import path %q: empty result", importPath)
	}

	return dir, nil
}

// findModuleRoot walks up from startDir to find gnomod.toml.
// Returns the directory containing gnomod.toml if found.
func findModuleRoot(startDir string) (string, bool) {
	dir := filepath.Clean(startDir)
	for {
		gnomodPath := filepath.Join(dir, "gnomod.toml")
		if info, err := os.Stat(gnomodPath); err == nil && !info.IsDir() {
			return dir, true
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return "", false
}

func readGnoModModule(moduleRoot string) string {
	if moduleRoot == "" {
		return ""
	}
	path := filepath.Join(moduleRoot, "gnomod.toml")
	file, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if !strings.HasPrefix(line, "module") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		if key != "module" {
			continue
		}
		value := strings.TrimSpace(parts[1])
		value = strings.Trim(value, "\"")
		value = strings.Trim(value, "'")
		return value
	}
	return ""
}

// parseFiles parses the given files using go/parser.
func (p *Parser) parseFiles(dir string, files []string) (map[string]*ast.Package, error) {
	for _, name := range files {
		if strings.HasSuffix(name, ".gno") {
			return p.parseFilesIndividually(dir, files)
		}
	}

	filter := func(fi os.FileInfo) bool {
		for _, f := range files {
			if fi.Name() == f {
				return true
			}
		}
		return false
	}

	pkgs, err := parser.ParseDir(p.fset, dir, filter, parser.ParseComments)
	if err != nil {
		if p.opts.IgnoreParseErrors {
			// Try to parse files individually
			return p.parseFilesIndividually(dir, files)
		}
		return nil, fmt.Errorf("parse error: %w", err)
	}

	return pkgs, nil
}

// parseFilesIndividually parses files one by one, skipping failures.
func (p *Parser) parseFilesIndividually(dir string, files []string) (map[string]*ast.Package, error) {
	pkgs := make(map[string]*ast.Package)

	for _, filename := range files {
		path := filepath.Join(dir, filename)
		f, err := parser.ParseFile(p.fset, path, nil, parser.ParseComments)
		if err != nil {
			// Mark that we had parse errors, then skip the failed file
			p.hadParseErrors = true
			continue
		}

		pkgName := f.Name.Name
		if pkgs[pkgName] == nil {
			pkgs[pkgName] = &ast.Package{
				Name:  pkgName,
				Files: make(map[string]*ast.File),
			}
		}
		pkgs[pkgName].Files[path] = f
	}

	return pkgs, nil
}

// convertPackage converts go/doc.Package to model.DocPackage.
func (p *Parser) convertPackage(docPkg *doc.Package, dir string, files []string, examples []*doc.Example, moduleRoot, modulePath string) *model.DocPackage {
	pkg := &model.DocPackage{
		Name:       docPkg.Name,
		ImportPath: docPkg.ImportPath,
	}
	if modulePath != "" && moduleRoot != "" {
		if rel, err := filepath.Rel(moduleRoot, dir); err == nil {
			rel = filepath.ToSlash(rel)
			if rel == "." {
				pkg.ImportPath = modulePath
			} else {
				pkg.ImportPath = modulePath + "/" + rel
			}
			pkg.ModulePath = modulePath
		}
	}

	// Extract summary (first sentence)
	pkg.Doc, pkg.Deprecated = extractDeprecated(docPkg.Doc, model.SourcePos{})
	if pkg.Doc != "" {
		pkg.Summary = extractSummary(pkg.Doc)
	}

	// Convert files
	for _, f := range files {
		pkg.Files = append(pkg.Files, model.SourceFile{
			Name: f,
			Path: filepath.Join(dir, f),
		})
	}

	// Convert constants
	for _, c := range docPkg.Consts {
		group := p.convertValueGroup(c, model.KindConst)
		pkg.Consts = append(pkg.Consts, group)
		pkg.Deprecated = append(pkg.Deprecated, group.Deprecated...)
	}

	// Convert variables
	for _, v := range docPkg.Vars {
		group := p.convertValueGroup(v, model.KindVar)
		pkg.Vars = append(pkg.Vars, group)
		pkg.Deprecated = append(pkg.Deprecated, group.Deprecated...)
	}

	// Convert functions
	for _, f := range docPkg.Funcs {
		fn := p.convertFunc(f)
		pkg.Funcs = append(pkg.Funcs, fn)
		pkg.Deprecated = append(pkg.Deprecated, fn.Deprecated...)
	}

	// Convert types
	for _, t := range docPkg.Types {
		typ := p.convertType(t)
		pkg.Types = append(pkg.Types, typ)
		pkg.Deprecated = append(pkg.Deprecated, typ.Deprecated...)
		for _, field := range typ.Fields {
			pkg.Deprecated = append(pkg.Deprecated, field.Deprecated...)
		}
		for _, method := range typ.Methods {
			pkg.Deprecated = append(pkg.Deprecated, method.Deprecated...)
		}
		for _, ctor := range typ.Constructors {
			pkg.Deprecated = append(pkg.Deprecated, ctor.Deprecated...)
		}
	}

	// Convert examples
	if len(examples) == 0 {
		examples = docPkg.Examples
	}
	for _, ex := range examples {
		pkg.Examples = append(pkg.Examples, p.convertExample(ex))
	}

	// Convert notes
	for kind, notes := range docPkg.Notes {
		for _, note := range notes {
			pkg.Notes = append(pkg.Notes, model.DocNote{
				Kind: kind,
				Body: note.Body,
				Pos:  p.convertPos(note.Pos),
			})
		}
	}

	// Build index
	pkg.BuildIndex()

	return pkg
}

// convertValueGroup converts a go/doc.Value to model.DocValueGroup.
func (p *Parser) convertValueGroup(v *doc.Value, kind model.SymbolKind) model.DocValueGroup {
	groupPos := model.SourcePos{}
	if v.Decl != nil {
		groupPos = p.convertPos(v.Decl.Pos())
	}
	groupDoc, groupDeprecated := extractDeprecated(v.Doc, groupPos)
	group := model.DocValueGroup{
		DocNode: model.DocNode{
			Kind:       kind,
			Doc:        groupDoc,
			Deprecated: groupDeprecated,
		},
	}

	// Build a map of name to AST info for extracting type/value/pos
	type valueInfo struct {
		typ  string
		val  string
		pos  token.Pos
		doc  string
		deps []model.DocDeprecated
	}
	nameToInfo := make(map[string]valueInfo)
	if v.Decl != nil {
		for _, s := range v.Decl.Specs {
			if vs, ok := s.(*ast.ValueSpec); ok {
				typ := ""
				if vs.Type != nil {
					typ = p.typeString(vs.Type)
				}
				docText := ""
				if vs.Doc != nil {
					docText = vs.Doc.Text()
				} else if vs.Comment != nil {
					docText = vs.Comment.Text()
				}
				docPos := model.SourcePos{}
				if len(vs.Names) > 0 {
					docPos = p.convertPos(vs.Names[0].Pos())
				} else {
					docPos = p.convertPos(vs.Pos())
				}
				docText, deps := extractDeprecated(docText, docPos)

				for i, name := range vs.Names {
					info := valueInfo{typ: typ, pos: name.Pos(), doc: docText, deps: deps}
					if len(vs.Values) == 1 {
						info.val = p.exprString(vs.Values[0])
					} else if i < len(vs.Values) {
						info.val = p.exprString(vs.Values[i])
					}
					nameToInfo[name.Name] = info
				}
			}
		}
	}

	for _, name := range v.Names {
		spec := model.DocValueSpec{
			DocNode: model.DocNode{
				Name:     name,
				Kind:     kind,
				Exported: isExported(name),
			},
		}

		// Extract type, value, and position from AST
		if info, ok := nameToInfo[name]; ok {
			spec.Pos = p.convertPos(info.pos)
			spec.Type = info.typ
			spec.Value = info.val
			spec.Doc = info.doc
			spec.Deprecated = info.deps
		}

		if spec.Doc == "" && len(v.Names) == 1 {
			spec.Doc = group.Doc
			if len(spec.Deprecated) == 0 {
				spec.Deprecated = group.Deprecated
			}
		}

		group.Specs = append(group.Specs, spec)
	}

	return group
}

// convertFunc converts a go/doc.Func to model.DocFunc.
func (p *Parser) convertFunc(f *doc.Func) model.DocFunc {
	pos := model.SourcePos{}
	if f.Decl != nil {
		pos = p.convertPos(f.Decl.Pos())
	}
	docText, deprecated := extractDeprecated(f.Doc, pos)
	fn := model.DocFunc{
		DocNode: model.DocNode{
			Name:     f.Name,
			Kind:     model.KindFunc,
			Doc:      docText,
			Summary:  extractSummary(docText),
			Exported: isExported(f.Name),
			Pos:      pos,
			Deprecated: deprecated,
		},
	}

	// Extract position
	if f.Decl != nil {
		fn.Pos = pos

		// Extract params and results from declaration
		if f.Decl.Type != nil {
			fn.Params = p.convertFieldList(f.Decl.Type.Params)
			fn.Results = p.convertFieldList(f.Decl.Type.Results)
		}

		// Extract receiver
		if f.Decl.Recv != nil && len(f.Decl.Recv.List) > 0 {
			recv := f.Decl.Recv.List[0]
			fn.Receiver = &model.DocReceiver{
				Type: p.typeString(recv.Type),
			}
			if len(recv.Names) > 0 {
				fn.Receiver.Name = recv.Names[0].Name
			}
			fn.Kind = model.KindMethod
		}
	}

	return fn
}

// convertType converts a go/doc.Type to model.DocType.
func (p *Parser) convertType(t *doc.Type) model.DocType {
	pos := model.SourcePos{}
	if t.Decl != nil {
		pos = p.convertPos(t.Decl.Pos())
	}
	docText, deprecated := extractDeprecated(t.Doc, pos)
	typ := model.DocType{
		DocNode: model.DocNode{
			Name:     t.Name,
			Kind:     model.KindType,
			Doc:      docText,
			Summary:  extractSummary(docText),
			Exported: isExported(t.Name),
			Pos:      pos,
			Deprecated: deprecated,
		},
	}

	// Determine type kind and extract fields
	if t.Decl != nil {
		typ.Pos = pos

		for _, spec := range t.Decl.Specs {
			if ts, ok := spec.(*ast.TypeSpec); ok {
				switch underlying := ts.Type.(type) {
				case *ast.StructType:
					typ.TypeKind = model.TypeKindStruct
					typ.Signature = fmt.Sprintf("type %s struct", t.Name)
					if underlying.Fields != nil {
						for _, field := range underlying.Fields.List {
							typ.Fields = append(typ.Fields, p.convertField(field))
						}
					}
				case *ast.InterfaceType:
					typ.TypeKind = model.TypeKindInterface
					typ.Signature = fmt.Sprintf("type %s interface", t.Name)
				default:
					typ.TypeKind = model.TypeKindAlias
					typ.Signature = fmt.Sprintf("type %s %s", t.Name, p.typeString(underlying))
				}
			}
		}
	}

	// Convert methods
	for _, m := range t.Methods {
		method := p.convertFunc(m)
		method.Kind = model.KindMethod
		if method.Receiver == nil {
			method.Receiver = &model.DocReceiver{Type: t.Name}
		}
		typ.Methods = append(typ.Methods, method)
	}

	// Convert constructors (functions that return this type)
	for _, f := range t.Funcs {
		ctor := p.convertFunc(f)
		typ.Constructors = append(typ.Constructors, ctor)
	}

	return typ
}

// convertField converts an ast.Field to model.DocField.
func (p *Parser) convertField(field *ast.Field) model.DocField {
	f := model.DocField{
		DocNode: model.DocNode{
			Kind: model.KindField,
		},
		Type: p.typeString(field.Type),
	}

	// Field name (may be anonymous)
	if len(field.Names) > 0 {
		f.Name = field.Names[0].Name
		f.Exported = isExported(f.Name)
		f.Pos = p.convertPos(field.Names[0].Pos())
	} else {
		// Anonymous field - use type name
		f.Name = f.Type
		f.Exported = isExported(f.Name)
	}

	// Field tag
	if field.Tag != nil {
		f.Tag = field.Tag.Value
		// Remove quotes
		if len(f.Tag) >= 2 {
			f.Tag = f.Tag[1 : len(f.Tag)-1]
		}
	}

	// Field doc
	if field.Doc != nil {
		f.Doc, f.Deprecated = extractDeprecated(field.Doc.Text(), f.Pos)
	} else if field.Comment != nil {
		f.Doc, f.Deprecated = extractDeprecated(field.Comment.Text(), f.Pos)
	}

	return f
}

// convertFieldList converts an ast.FieldList to []model.DocParam.
func (p *Parser) convertFieldList(fl *ast.FieldList) []model.DocParam {
	if fl == nil {
		return nil
	}

	var params []model.DocParam
	for _, field := range fl.List {
		typStr := p.typeString(field.Type)
		if len(field.Names) == 0 {
			// Unnamed parameter
			params = append(params, model.DocParam{Type: typStr})
		} else {
			for _, name := range field.Names {
				params = append(params, model.DocParam{
					Name: name.Name,
					Type: typStr,
				})
			}
		}
	}

	return params
}

// convertPos converts a token.Pos to model.SourcePos.
func (p *Parser) convertPos(pos token.Pos) model.SourcePos {
	if !pos.IsValid() {
		return model.SourcePos{}
	}
	position := p.fset.Position(pos)
	filename := position.Filename
	if p.moduleRoot != "" {
		if rel, err := filepath.Rel(p.moduleRoot, filename); err == nil && !strings.HasPrefix(rel, "..") {
			filename = rel
		} else {
			filename = filepath.Base(filename)
		}
	} else {
		filename = filepath.Base(filename)
	}
	return model.SourcePos{
		Filename: filepath.ToSlash(filename),
		Line:     position.Line,
		Column:   position.Column,
	}
}

// typeString returns the string representation of an ast type.
func (p *Parser) typeString(expr ast.Expr) string {
	if expr == nil {
		return ""
	}

	switch t := expr.(type) {
	case *ast.Ident:
		return t.Name
	case *ast.SelectorExpr:
		return p.typeString(t.X) + "." + t.Sel.Name
	case *ast.StarExpr:
		return "*" + p.typeString(t.X)
	case *ast.ArrayType:
		if t.Len == nil {
			return "[]" + p.typeString(t.Elt)
		}
		return "[...]" + p.typeString(t.Elt)
	case *ast.MapType:
		return "map[" + p.typeString(t.Key) + "]" + p.typeString(t.Value)
	case *ast.ChanType:
		return "chan " + p.typeString(t.Value)
	case *ast.FuncType:
		return "func(...)"
	case *ast.InterfaceType:
		return "interface{}"
	case *ast.StructType:
		return "struct{}"
	case *ast.Ellipsis:
		return "..." + p.typeString(t.Elt)
	default:
		return "?"
	}
}

// exprString returns the string representation of an expression value.
func (p *Parser) exprString(expr ast.Expr) string {
	if expr == nil {
		return ""
	}

	switch e := expr.(type) {
	case *ast.BasicLit:
		return e.Value
	case *ast.Ident:
		return e.Name
	case *ast.SelectorExpr:
		return p.exprString(e.X) + "." + e.Sel.Name
	case *ast.UnaryExpr:
		return e.Op.String() + p.exprString(e.X)
	case *ast.BinaryExpr:
		return p.exprString(e.X) + " " + e.Op.String() + " " + p.exprString(e.Y)
	case *ast.ParenExpr:
		return "(" + p.exprString(e.X) + ")"
	case *ast.CallExpr:
		return p.exprString(e.Fun) + "(...)"
	case *ast.CompositeLit:
		if e.Type != nil {
			return p.typeString(e.Type) + "{...}"
		}
		return "{...}"
	default:
		return "..."
	}
}

// collectExamplesFromFiles extracts examples from test files listed for the package.
func (p *Parser) collectExamplesFromFiles(dir string, files []string) []*doc.Example {
	var testFiles []*ast.File
	for _, name := range files {
		if !strings.HasSuffix(name, "_test.go") {
			continue
		}
		path := filepath.Join(dir, name)
		file, err := parser.ParseFile(p.fset, path, nil, parser.ParseComments)
		if err != nil {
			continue
		}
		testFiles = append(testFiles, file)
	}

	if len(testFiles) == 0 {
		return nil
	}
	return doc.Examples(testFiles...)
}

// convertExample converts a go/doc.Example to model.DocExample.
func (p *Parser) convertExample(ex *doc.Example) model.DocExample {
	code := ""
	if ex.Code != nil {
		var buf bytes.Buffer
		_ = printer.Fprint(&buf, p.fset, ex.Code)
		code = normalizeExampleCode(buf.String())
	}

	pos := model.SourcePos{}
	if ex.Code != nil {
		pos = p.convertPos(ex.Code.Pos())
	}

	return model.DocExample{
		Name:   ex.Name,
		Doc:    ex.Doc,
		Code:   code,
		Output: strings.TrimRight(ex.Output, "\n"),
		Pos:    pos,
	}
}

// Helper functions

func isTestFile(name string) bool {
	return strings.HasSuffix(name, "_test.go") || strings.HasSuffix(name, "_test.gno")
}

func isExported(name string) bool {
	if name == "" {
		return false
	}
	r := []rune(name)[0]
	return unicode.IsUpper(r)
}

func extractSummary(doc string) string {
	if doc == "" {
		return ""
	}

	// Find first sentence (ends with period followed by space or newline)
	for i, r := range doc {
		if r == '.' {
			// Check if next char is space, newline, or end of string
			if i+1 >= len(doc) {
				return doc[:i+1]
			}
			next := doc[i+1]
			if next == ' ' || next == '\n' || next == '\t' {
				return doc[:i+1]
			}
		}
	}

	// No period found, return first line
	if idx := strings.Index(doc, "\n"); idx != -1 {
		return doc[:idx]
	}

	return doc
}

func normalizeExampleCode(code string) string {
	if strings.TrimSpace(code) == "" {
		return ""
	}

	lines := strings.Split(code, "\n")
	start := 0
	for start < len(lines) && strings.TrimSpace(lines[start]) == "" {
		start++
	}
	end := len(lines) - 1
	for end >= start && strings.TrimSpace(lines[end]) == "" {
		end--
	}
	lines = lines[start : end+1]

	minIndent := -1
	for _, line := range lines {
		if strings.TrimSpace(line) == "" {
			continue
		}
		count := 0
		for _, r := range line {
			if r == ' ' || r == '\t' {
				count++
			} else {
				break
			}
		}
		if minIndent == -1 || count < minIndent {
			minIndent = count
		}
	}

	if minIndent > 0 {
		for i, line := range lines {
			if strings.TrimSpace(line) == "" {
				continue
			}
			removed := 0
			index := 0
			for index < len(line) && removed < minIndent {
				if line[index] == ' ' || line[index] == '\t' {
					removed++
					index++
					continue
				}
				break
			}
			lines[i] = line[index:]
		}
	}

	return strings.Join(lines, "\n")
}

func extractDeprecated(doc string, pos model.SourcePos) (string, []model.DocDeprecated) {
	if strings.TrimSpace(doc) == "" {
		return doc, nil
	}

	lines := strings.Split(doc, "\n")
	var kept []string
	var deprecated []model.DocDeprecated

	for i := 0; i < len(lines); {
		line := lines[i]
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "Deprecated:") {
			body := strings.TrimSpace(strings.TrimPrefix(trimmed, "Deprecated:"))
			j := i + 1
			for j < len(lines) {
				next := strings.TrimSpace(lines[j])
				if next == "" {
					break
				}
				if body != "" {
					body += " "
				}
				body += next
				j++
			}
			deprecated = append(deprecated, model.DocDeprecated{Body: body, Pos: pos})
			i = j
			continue
		}
		kept = append(kept, line)
		i++
	}

	clean := strings.TrimRight(strings.Join(kept, "\n"), "\n")
	return clean, deprecated
}
