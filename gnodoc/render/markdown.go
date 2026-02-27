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
		fnParts = append(fnParts, fmt.Sprintf("## %s", fn.Name))

		// Signature
		fnParts = append(fnParts, "```go")
		fnParts = append(fnParts, formatSignatureMultiline(fn))
		fnParts = append(fnParts, "```")

		// Documentation
		docText, paramItems, returnItems := splitDocSections(fn.Doc)
		if docText != "" {
			fnParts = append(fnParts, docText)
		}
		if params := r.renderParamTable(fn.Params, paramItems); params != "" {
			fnParts = append(fnParts, params)
		}
		if returns := r.renderReturnTable(fn, returnItems); returns != "" {
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

	return strings.Join(parts, "\n\n---\n\n") + "\n"
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
					methodLines = append(methodLines, formatSignatureMultiline(m))
					methodLines = append(methodLines, "```")
					docText, paramItems, returnItems := splitDocSections(m.Doc)
					if docText != "" {
						methodLines = append(methodLines, "")
						methodLines = append(methodLines, docText)
					}
					if params := r.renderParamTable(m.Params, paramItems); params != "" {
						methodLines = append(methodLines, "")
						methodLines = append(methodLines, params)
					}
					if returns := r.renderReturnTable(m, returnItems); returns != "" {
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

type docItem struct {
	Key  string
	Desc string
	Used bool
}

func splitDocSections(doc string) (string, []docItem, []docItem) {
	if doc == "" {
		return "", nil, nil
	}

	lines := strings.Split(doc, "\n")
	var cleaned []string
	var paramItems []docItem
	var returnItems []docItem

	for i := 0; i < len(lines); i++ {
		trimmed := strings.TrimSpace(lines[i])
		switch trimmed {
		case "Parameters:":
			items, next := parseDocList(lines, i+1)
			paramItems = append(paramItems, items...)
			i = next - 1
			continue
		case "Returns:":
			items, next := parseDocList(lines, i+1)
			returnItems = append(returnItems, items...)
			i = next - 1
			continue
		}
		cleaned = append(cleaned, lines[i])
	}

	cleaned = trimEmptyLines(cleaned)
	return strings.Join(cleaned, "\n"), paramItems, returnItems
}

func parseDocList(lines []string, start int) ([]docItem, int) {
	var items []docItem
	i := start
	for i < len(lines) {
		trimmed := strings.TrimLeft(lines[i], " \t")
		if !strings.HasPrefix(trimmed, "- ") {
			break
		}
		item := strings.TrimSpace(strings.TrimPrefix(trimmed, "- "))
		key, desc := splitKeyDesc(item)
		items = append(items, docItem{Key: key, Desc: desc})
		i++
	}
	return items, i
}

func splitKeyDesc(item string) (string, string) {
	if idx := strings.Index(item, ":"); idx != -1 {
		key := strings.TrimSpace(item[:idx])
		desc := strings.TrimSpace(item[idx+1:])
		return key, desc
	}
	return strings.TrimSpace(item), ""
}

func trimEmptyLines(lines []string) []string {
	for len(lines) > 0 && strings.TrimSpace(lines[0]) == "" {
		lines = lines[1:]
	}
	for len(lines) > 0 && strings.TrimSpace(lines[len(lines)-1]) == "" {
		lines = lines[:len(lines)-1]
	}
	return lines
}

func escapeTableCell(value string) string {
	value = strings.ReplaceAll(value, "|", "\\|")
	value = strings.ReplaceAll(value, "\n", " ")
	return strings.TrimSpace(value)
}

func (r *MarkdownRenderer) renderParamTable(params []model.DocParam, items []docItem) string {
	if len(params) == 0 && len(items) == 0 {
		return ""
	}

	descByName := make(map[string]string, len(items))
	for _, item := range items {
		if item.Key == "" {
			continue
		}
		descByName[item.Key] = item.Desc
	}

	var lines []string
	lines = append(lines, "#### Parameters")
	lines = append(lines, "")
	lines = append(lines, "| Name | Type | Description |")
	lines = append(lines, "| --- | --- | --- |")

	if len(params) == 0 {
		for _, item := range items {
			name := ""
			if item.Key != "" {
				name = "`" + escapeTableCell(item.Key) + "`"
			}
			lines = append(lines, fmt.Sprintf("| %s | %s | %s |",
				name,
				"",
				escapeTableCell(item.Desc),
			))
		}
		return strings.Join(lines, "\n")
	}

	for _, param := range params {
		desc := ""
		if param.Name != "" {
			desc = descByName[param.Name]
		}
		name := ""
		if param.Name != "" {
			name = "`" + escapeTableCell(param.Name) + "`"
		}
		lines = append(lines, fmt.Sprintf("| %s | %s | %s |",
			name,
			escapeTableCell(param.Type),
			escapeTableCell(desc),
		))
	}

	return strings.Join(lines, "\n")
}

func (r *MarkdownRenderer) renderReturnTable(fn model.DocFunc, items []docItem) string {
	if len(fn.Results) == 0 && len(items) == 0 {
		return ""
	}

	var lines []string
	lines = append(lines, "#### Return Values")
	lines = append(lines, "")
	lines = append(lines, "| Name | Type | Description |")
	lines = append(lines, "| --- | --- | --- |")

	if len(fn.Results) == 0 {
		for _, item := range items {
			name := ""
			if item.Key != "" {
				name = "`" + escapeTableCell(item.Key) + "`"
			}
			lines = append(lines, fmt.Sprintf("| %s | %s | %s |",
				name,
				"",
				escapeTableCell(item.Desc),
			))
		}
		return strings.Join(lines, "\n")
	}

	descItems := make([]docItem, len(items))
	copy(descItems, items)

	for _, result := range fn.Results {
		item := matchDocItem(descItems, result.Name, result.Type)
		name := result.Name
		if name == "" && item.Key != "" {
			name = item.Key
		}
		nameCell := ""
		if name != "" {
			nameCell = "`" + escapeTableCell(name) + "`"
		}
		lines = append(lines, fmt.Sprintf("| %s | %s | %s |",
			nameCell,
			escapeTableCell(result.Type),
			escapeTableCell(item.Desc),
		))
	}

	return strings.Join(lines, "\n")
}

func matchDocItem(items []docItem, name, typ string) docItem {
	if name != "" {
		for i := range items {
			if items[i].Used {
				continue
			}
			if items[i].Key == name {
				items[i].Used = true
				return items[i]
			}
		}
	}
	if typ != "" {
		for i := range items {
			if items[i].Used {
				continue
			}
			if items[i].Key == typ {
				items[i].Used = true
				return items[i]
			}
		}
	}
	for i := range items {
		if items[i].Used {
			continue
		}
		items[i].Used = true
		return items[i]
	}
	return docItem{}
}

func formatSignatureMultiline(fn model.DocFunc) string {
	var sb strings.Builder
	sb.WriteString("func ")
	if fn.Receiver != nil {
		sb.WriteString(fn.Receiver.String())
		sb.WriteString(" ")
	}
	sb.WriteString(fn.Name)
	sb.WriteString("(")
	if len(fn.Params) == 0 {
		sb.WriteString(")")
	} else {
		sb.WriteString("\n")
		for i, param := range fn.Params {
			sb.WriteString("\t")
			sb.WriteString(param.String())
			if i < len(fn.Params)-1 {
				sb.WriteString(",")
			}
			sb.WriteString("\n")
		}
		sb.WriteString(")")
	}

	if len(fn.Results) == 0 {
		return sb.String()
	}

	sb.WriteString(" ")
	if len(fn.Results) == 1 && fn.Results[0].Name == "" {
		sb.WriteString(fn.Results[0].Type)
		return sb.String()
	}

	sb.WriteString("(")
	for i, result := range fn.Results {
		if i > 0 {
			sb.WriteString(", ")
		}
		sb.WriteString(result.String())
	}
	sb.WriteString(")")
	return sb.String()
}
