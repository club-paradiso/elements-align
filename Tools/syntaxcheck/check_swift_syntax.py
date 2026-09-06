#!/usr/bin/env python3
"""
Parse every Swift file with tree-sitter and report syntax errors.

This is NOT a substitute for `swift build`. It parses; it does not type-check,
resolve names, or verify availability. It exists because this repository was
authored in an environment with no Swift toolchain (see
Documentation/BUILD_STATUS.md), and catching unbalanced braces and malformed
declarations mechanically is strictly better than catching none of them.

Known grammar limitation: tree-sitter-swift rejects a continuation line that
begins with `*`, though Swift itself accepts it as an infix operator (it
accepts leading `+` and `-`, which are also valid prefix operators). Rather
than suppress the diagnostic, this repository writes such expressions with the
operator at the end of the line, which is unambiguous either way.

Usage: python3 check_swift_syntax.py <dir> [<dir> ...]
Exit code 1 if any file fails to parse.
"""
import sys, os

try:
    import tree_sitter_swift
    from tree_sitter import Language, Parser
except ImportError:
    sys.exit("needs: pip install tree_sitter tree_sitter_swift")

parser = Parser(Language(tree_sitter_swift.language()))

def errors(node, src, out, limit=12):
    """Collect ERROR and MISSING nodes with a line number and a source excerpt."""
    if len(out) >= limit:
        return
    if node.type == "ERROR" or node.is_missing:
        line = node.start_point[0] + 1
        excerpt = src.split(b"\n")[node.start_point[0]].decode("utf8", "replace").strip()
        out.append((line, "MISSING" if node.is_missing else "ERROR", excerpt[:110]))
        return
    if node.has_error:
        for child in node.children:
            errors(child, src, out, limit)

def main(roots):
    files = []
    for root in roots:
        for dirpath, _, names in os.walk(root):
            files.extend(os.path.join(dirpath, n) for n in sorted(names)
                         if n.endswith(".swift"))
    failed = 0
    for path in sorted(files):
        src = open(path, "rb").read()
        tree = parser.parse(src)
        if not tree.root_node.has_error:
            continue
        found = []
        errors(tree.root_node, src, found)
        failed += 1
        rel = os.path.relpath(path)
        print("FAIL %s" % rel)
        for line, kind, excerpt in found:
            print("     %s:%d  %s  %s" % (rel, line, kind, excerpt))
    print()
    print("%d Swift file(s) parsed, %d with syntax errors" % (len(files), failed))
    return 1 if failed else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] or ["."]))
