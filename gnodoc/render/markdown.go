package render

import (
	"fmt"
	"sort"
	"strings"

	"gnodoc/model"
)

// MarkdownRenderer renders DocPackage to Markdown format.
type MarkdownRenderer struct {
	opts     *RenderOptions
	anchors  *AnchorRegistry
	sections []string
}

// NewMarkdownRenderer creates a new Markdown renderer with the given options.
func NewMarkdownRenderer(opts *RenderOptions) *MarkdownRenderer {
	if opts == nil {
		opts = DefaultOptions()
	}
	return &MarkdownRenderer{
		opts:    opts,
		anchors: NewAnchorRegistry(),
	}
}

// Render renders the entire package to Markdown.
func (r *MarkdownRenderer) Render(pkg *model.DocPackage) string {
	r.anchors = NewAnchorRegistry() // Reset anchors
	r.sections = nil

	// Build sections in order
	r.sections = append(r.sections, r.RenderOverview(pkg))

	if r.opts.IncludeIndex {
		if idx := r.RenderIndex(pkg); idx != "" {
			r.sections = append(r.sections, idx)
		}
	}

	if consts := r.RenderConstants(pkg); consts != "" {
		r.sections = append(r.sections, consts)
	}

	if vars := r.RenderVariables(pkg); vars != "" {
		r.sections = append(r.sections, vars)
	}

	if funcs := r.RenderFunctions(pkg); funcs != "" {
		r.sections = append(r.sections, funcs)
	}

	if types := r.RenderTypes(pkg); types != "" {
		r.sections = append(r.sections, types)
	}

	if r.opts.IncludeExamples {
		if examples := r.RenderExamples(pkg); examples != "" {
			r.sections = append(r.sections, examples)
		}
	}

	if r.opts.IncludeNotes {
		if notes := r.RenderNotes(pkg); notes != "" {
			r.sections = append(r.sections, notes)
		}
	}

	return strings.Join(r.sections, "\n\n")
}

func (r *MarkdownRenderer) anchorTag(anchor string) string {
	return fmt.Sprintf("<a id=\"%s\"></a>", anchor)
}

func (r *MarkdownRenderer) symbolAnchor(kind model.SymbolKind, name string) string {
	key := fmt.Sprintf("%s:%s", kind, name)
	return r.anchors.RegisterKey(key, ToAnchor(name))
}

func (r *MarkdownRenderer) methodAnchor(typeName, methodName string) string {
	key := fmt.Sprintf("%s:%s:%s", model.KindMethod, typeName, methodName)
	return r.anchors.RegisterKey(key, MethodAnchor(typeName, methodName))
}

func (r *MarkdownRenderer) sourceLink(pos model.SourcePos) string {
	if r.opts.SourceLinkBase == "" || !pos.IsValid() {
		return ""
	}
	return fmt.Sprintf("%s/%s#L%d", r.opts.SourceLinkBase, pos.Filename, pos.Line)
}

// RenderOverview renders the Overview section.
func (r *MarkdownRenderer) RenderOverview(pkg *model.DocPackage) string {
	var sb strings.Builder

	// Package title
	sb.WriteString(fmt.Sprintf("# %s\n\n", pkg.Name))

	// Import path
	if pkg.ImportPath != "" {
		sb.WriteString(fmt.Sprintf("`import %q`\n\n", pkg.ImportPath))
	}

	// Package documentation
	if pkg.Doc != "" {
		sb.WriteString(pkg.Doc)
		sb.WriteString("\n")
	}

	return sb.String()
}

// RenderIndex renders the Index section with anchor links.
func (r *MarkdownRenderer) RenderIndex(pkg *model.DocPackage) string {
	var items []string

	// Collect constants
	for _, group := range pkg.Consts {
		for _, spec := range group.Specs {
			if r.opts.ShouldRender(spec.Exported) {
				anchor := r.symbolAnchor(spec.Kind, spec.Name)
				items = append(items, fmt.Sprintf("- [%s](#%s)", spec.Name, anchor))
			}
		}
	}

	// Collect variables
	for _, group := range pkg.Vars {
		for _, spec := range group.Specs {
			if r.opts.ShouldRender(spec.Exported) {
				anchor := r.symbolAnchor(spec.Kind, spec.Name)
				items = append(items, fmt.Sprintf("- [%s](#%s)", spec.Name, anchor))
			}
		}
	}

	// Collect functions
	for _, fn := range pkg.Funcs {
		if r.opts.ShouldRender(fn.Exported) {
			anchor := r.symbolAnchor(fn.Kind, fn.Name)
			items = append(items, fmt.Sprintf("- [%s](#%s)", fn.Name, anchor))
		}
	}

	// Collect types
	for _, typ := range pkg.Types {
		if r.opts.ShouldRender(typ.Exported) {
			anchor := r.symbolAnchor(typ.Kind, typ.Name)
			items = append(items, fmt.Sprintf("- [%s](#%s)", typ.Name, anchor))
		}
	}

	if len(items) == 0 {
		return ""
	}

	var sb strings.Builder
	sb.WriteString("## Index\n\n")
	sb.WriteString(strings.Join(items, "\n"))
	sb.WriteString("\n")

	return sb.String()
}

// RenderConstants renders the Constants section.
func (r *MarkdownRenderer) RenderConstants(pkg *model.DocPackage) string {
	var parts []string

	for _, group := range pkg.Consts {
		hasExported := false
		for _, spec := range group.Specs {
			if r.opts.ShouldRender(spec.Exported) {
				hasExported = true
				break
			}
		}
		if !hasExported {
			continue
		}

		var groupParts []string

		// Group documentation
		if group.Doc != "" {
			groupParts = append(groupParts, group.Doc)
		}

		// Anchors for constants
		var anchors []string
		for _, spec := range group.Specs {
			if r.opts.ShouldRender(spec.Exported) {
				anchor := r.symbolAnchor(spec.Kind, spec.Name)
				anchors = append(anchors, r.anchorTag(anchor))
			}
		}
		if len(anchors) > 0 {
			groupParts = append(groupParts, strings.Join(anchors, "\n"))
		}

		// Constants
		groupParts = append(groupParts, "```go")
		groupParts = append(groupParts, "const (")
		for _, spec := range group.Specs {
			if !r.opts.ShouldRender(spec.Exported) {
				continue
			}
			if spec.Value != "" {
				groupParts = append(groupParts, fmt.Sprintf("\t%s = %s", spec.Name, spec.Value))
			} else {
				groupParts = append(groupParts, fmt.Sprintf("\t%s %s", spec.Name, spec.Type))
			}
		}
		groupParts = append(groupParts, ")")
		groupParts = append(groupParts, "```")

		// Source links
		if r.opts.SourceLinkBase != "" {
			var links []string
			for _, spec := range group.Specs {
				if !r.opts.ShouldRender(spec.Exported) {
					continue
				}
				if link := r.sourceLink(spec.Pos); link != "" {
					links = append(links, fmt.Sprintf("- %s: [source](%s)", spec.Name, link))
				}
			}
			if len(links) > 0 {
				groupParts = append(groupParts, strings.Join(links, "\n"))
			}
		}

		parts = append(parts, strings.Join(groupParts, "\n"))
	}

	if len(parts) == 0 {
		return ""
	}

	var sb strings.Builder
	sb.WriteString("## Constants\n\n")
	sb.WriteString(strings.Join(parts, "\n\n"))
	sb.WriteString("\n")

	return sb.String()
}

// RenderVariables renders the Variables section.
func (r *MarkdownRenderer) RenderVariables(pkg *model.DocPackage) string {
	var parts []string

	for _, group := range pkg.Vars {
		hasExported := false
		for _, spec := range group.Specs {
			if r.opts.ShouldRender(spec.Exported) {
				hasExported = true
				break
			}
		}
		if !hasExported {
			continue
		}

		var groupParts []string

		// Group documentation
		if group.Doc != "" {
			groupParts = append(groupParts, group.Doc)
		}

		// Anchors for variables
		var anchors []string
		for _, spec := range group.Specs {
			if r.opts.ShouldRender(spec.Exported) {
				anchor := r.symbolAnchor(spec.Kind, spec.Name)
				anchors = append(anchors, r.anchorTag(anchor))
			}
		}
		if len(anchors) > 0 {
			groupParts = append(groupParts, strings.Join(anchors, "\n"))
		}

		// Variables
		groupParts = append(groupParts, "```go")
		groupParts = append(groupParts, "var (")
		for _, spec := range group.Specs {
			if !r.opts.ShouldRender(spec.Exported) {
				continue
			}
			groupParts = append(groupParts, fmt.Sprintf("\t%s %s", spec.Name, spec.Type))
		}
		groupParts = append(groupParts, ")")
		groupParts = append(groupParts, "```")

		// Source links
		if r.opts.SourceLinkBase != "" {
			var links []string
			for _, spec := range group.Specs {
				if !r.opts.ShouldRender(spec.Exported) {
					continue
				}
				if link := r.sourceLink(spec.Pos); link != "" {
					links = append(links, fmt.Sprintf("- %s: [source](%s)", spec.Name, link))
				}
			}
			if len(links) > 0 {
				groupParts = append(groupParts, strings.Join(links, "\n"))
			}
		}

		parts = append(parts, strings.Join(groupParts, "\n"))
	}

	if len(parts) == 0 {
		return ""
	}

	var sb strings.Builder
	sb.WriteString("## Variables\n\n")
	sb.WriteString(strings.Join(parts, "\n\n"))
	sb.WriteString("\n")

	return sb.String()
}

// RenderFunctions renders the Functions section.
func (r *MarkdownRenderer) RenderFunctions(pkg *model.DocPackage) string {
	var parts []string

	for _, fn := range pkg.Funcs {
		if !r.opts.ShouldRender(fn.Exported) {
			continue
		}

		var fnParts []string

		anchor := r.symbolAnchor(fn.Kind, fn.Name)
		fnParts = append(fnParts, r.anchorTag(anchor))

		// Function name as subheader
		fnParts = append(fnParts, fmt.Sprintf("### %s", fn.Name))

		// Signature
		fnParts = append(fnParts, "```go")
		fnParts = append(fnParts, fn.FullSignature())
		fnParts = append(fnParts, "```")

		// Documentation
		if fn.Doc != "" {
			fnParts = append(fnParts, fn.Doc)
		}

		if returns := r.renderReturns(fn); returns != "" {
			fnParts = append(fnParts, returns)
		}

		// Source link
		if link := r.sourceLink(fn.Pos); link != "" {
			fnParts = append(fnParts, fmt.Sprintf("[source](%s)", link))
		}

		parts = append(parts, strings.Join(fnParts, "\n\n"))
	}

	if len(parts) == 0 {
		return ""
	}

	var sb strings.Builder
	sb.WriteString("## Functions\n\n")
	sb.WriteString(strings.Join(parts, "\n\n---\n\n"))
	sb.WriteString("\n")

	return sb.String()
}

// RenderTypes renders the Types section.
func (r *MarkdownRenderer) RenderTypes(pkg *model.DocPackage) string {
	var parts []string

	for _, typ := range pkg.Types {
		if !r.opts.ShouldRender(typ.Exported) {
			continue
		}

		var typParts []string

		anchor := r.symbolAnchor(typ.Kind, typ.Name)
		typParts = append(typParts, r.anchorTag(anchor))

		// Type name as subheader
		typParts = append(typParts, fmt.Sprintf("### %s", typ.Name))

		// Type signature
		typParts = append(typParts, "```go")
		if typ.Signature != "" {
			typParts = append(typParts, typ.Signature)
		} else {
			typParts = append(typParts, fmt.Sprintf("type %s %s", typ.Name, typ.TypeKind))
		}
		typParts = append(typParts, "```")

		// Documentation
		if typ.Doc != "" {
			typParts = append(typParts, typ.Doc)
		}

		// Source link
		if link := r.sourceLink(typ.Pos); link != "" {
			typParts = append(typParts, fmt.Sprintf("[source](%s)", link))
		}

		// Fields (for struct types)
		if typ.IsStruct() && len(typ.Fields) > 0 {
			var fieldLines []string
			fieldLines = append(fieldLines, "#### Fields")
			fieldLines = append(fieldLines, "")
			for _, f := range typ.Fields {
				if r.opts.ShouldRender(f.Exported) {
					line := fmt.Sprintf("- `%s %s`", f.Name, f.Type)
					if link := r.sourceLink(f.Pos); link != "" {
						line = fmt.Sprintf("%s ([source](%s))", line, link)
					}
					fieldLines = append(fieldLines, line)
				}
			}
			if len(fieldLines) > 2 {
				typParts = append(typParts, strings.Join(fieldLines, "\n"))
			}
		}

		// Methods
		if len(typ.Methods) > 0 {
			var methodLines []string
			methodLines = append(methodLines, "#### Methods")
			methodLines = append(methodLines, "")
			for _, m := range typ.Methods {
				if r.opts.ShouldRender(m.Exported) {
					methodAnchor := r.methodAnchor(typ.Name, m.Name)
					methodLines = append(methodLines, r.anchorTag(methodAnchor))
					methodLines = append(methodLines, fmt.Sprintf("##### %s", m.Name))
					methodLines = append(methodLines, "")
					methodLines = append(methodLines, "```go")
					methodLines = append(methodLines, m.FullSignature())
					methodLines = append(methodLines, "```")
					if m.Doc != "" {
						methodLines = append(methodLines, "")
						methodLines = append(methodLines, m.Doc)
					}
					if returns := r.renderReturns(m); returns != "" {
						methodLines = append(methodLines, "")
						methodLines = append(methodLines, returns)
					}
					if link := r.sourceLink(m.Pos); link != "" {
						methodLines = append(methodLines, "")
						methodLines = append(methodLines, fmt.Sprintf("[source](%s)", link))
					}
					methodLines = append(methodLines, "")
				}
			}
			if len(methodLines) > 2 {
				typParts = append(typParts, strings.Join(methodLines, "\n"))
			}
		}

		// Constructors
		if len(typ.Constructors) > 0 {
			var ctorLines []string
			ctorLines = append(ctorLines, "#### Constructors")
			ctorLines = append(ctorLines, "")
			for _, c := range typ.Constructors {
				if r.opts.ShouldRender(c.Exported) {
					line := fmt.Sprintf("- `%s`", c.FullSignature())
					if link := r.sourceLink(c.Pos); link != "" {
						line = fmt.Sprintf("%s ([source](%s))", line, link)
					}
					ctorLines = append(ctorLines, line)
				}
			}
			if len(ctorLines) > 2 {
				typParts = append(typParts, strings.Join(ctorLines, "\n"))
			}
		}

		parts = append(parts, strings.Join(typParts, "\n\n"))
	}

	if len(parts) == 0 {
		return ""
	}

	var sb strings.Builder
	sb.WriteString("## Types\n\n")
	sb.WriteString(strings.Join(parts, "\n\n---\n\n"))
	sb.WriteString("\n")

	return sb.String()
}

// RenderExamples renders the Examples section.
func (r *MarkdownRenderer) RenderExamples(pkg *model.DocPackage) string {
	if len(pkg.Examples) == 0 {
		return ""
	}

	var parts []string

	for _, ex := range pkg.Examples {
		var exParts []string

		// Example name
		name := ex.Name
		if suffix := ex.Suffix(); suffix != "" {
			name = suffix
		}
		exParts = append(exParts, fmt.Sprintf("### %s", name))

		// Documentation
		if ex.Doc != "" {
			exParts = append(exParts, ex.Doc)
		}

		// Code
		exParts = append(exParts, "```go")
		exParts = append(exParts, ex.Code)
		exParts = append(exParts, "```")

		// Output
		if ex.HasOutput() {
			exParts = append(exParts, "**Output:**")
			exParts = append(exParts, "```")
			exParts = append(exParts, ex.Output)
			exParts = append(exParts, "```")
		}

		parts = append(parts, strings.Join(exParts, "\n\n"))
	}

	var sb strings.Builder
	sb.WriteString("## Examples\n\n")
	sb.WriteString(strings.Join(parts, "\n\n---\n\n"))
	sb.WriteString("\n")

	return sb.String()
}

// RenderNotes renders the Notes/Deprecated section.
func (r *MarkdownRenderer) RenderNotes(pkg *model.DocPackage) string {
	if len(pkg.Notes) == 0 && len(pkg.Deprecated) == 0 {
		return ""
	}

	var parts []string

	// Deprecated
	if len(pkg.Deprecated) > 0 {
		var depParts []string
		depParts = append(depParts, "### Deprecated")
		for _, dep := range pkg.Deprecated {
			depParts = append(depParts, fmt.Sprintf("> **Deprecated:** %s", dep.Body))
		}
		parts = append(parts, strings.Join(depParts, "\n\n"))
	}

	// Group notes by kind
	notesByKind := make(map[string][]model.DocNote)
	for _, note := range pkg.Notes {
		notesByKind[note.Kind] = append(notesByKind[note.Kind], note)
	}

	// Render each kind
	var kinds []string
	for kind := range notesByKind {
		kinds = append(kinds, kind)
	}
	sort.Strings(kinds)
	for _, kind := range kinds {
		notes := notesByKind[kind]
		var noteParts []string
		noteParts = append(noteParts, fmt.Sprintf("### %s", kind))
		for _, note := range notes {
			noteParts = append(noteParts, fmt.Sprintf("> **%s:** %s", kind, note.Body))
		}
		parts = append(parts, strings.Join(noteParts, "\n\n"))
	}

	var sb strings.Builder
	sb.WriteString("## Notes\n\n")
	sb.WriteString(strings.Join(parts, "\n\n"))
	sb.WriteString("\n")

	return sb.String()
}

func (r *MarkdownRenderer) renderReturns(fn model.DocFunc) string {
	if len(fn.ReturnNames) == 0 && len(fn.ReturnExprs) == 0 && !fn.HasNakedReturn {
		return ""
	}

	var lines []string
	lines = append(lines, "#### Returns")
	lines = append(lines, "")

	if len(fn.ReturnNames) > 0 {
		lines = append(lines, fmt.Sprintf("- named: %s", strings.Join(fn.ReturnNames, ", ")))
	}
	if fn.HasNakedReturn {
		lines = append(lines, "- return: (named returns)")
	}
	seen := make(map[string]struct{})
	var ordered []string
	hasNil := false
	for _, ret := range fn.ReturnExprs {
		ret = strings.TrimSpace(ret)
		if ret == "" {
			continue
		}
		if ret == "nil" {
			hasNil = true
			continue
		}
		if _, ok := seen[ret]; ok {
			continue
		}
		seen[ret] = struct{}{}
		ordered = append(ordered, ret)
	}
	if hasNil {
		ordered = append(ordered, "nil")
	}
	for _, ret := range ordered {
		lines = append(lines, fmt.Sprintf("- return: %s", ret))
	}

	return strings.Join(lines, "\n")
}
