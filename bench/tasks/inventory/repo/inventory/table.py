def render(headers, rows, numeric=()):
    """Plain-text table. Columns in `numeric` (by header name) are right-aligned.

    Every CLI command that prints rows uses this, so output stays consistent:
    header line, a dashed rule, then one line per row; columns separated by two spaces.
    """
    cells = [[str(c) for c in row] for row in rows]
    widths = [len(h) for h in headers]
    for row in cells:
        for i, c in enumerate(row):
            widths[i] = max(widths[i], len(c))

    def line(values):
        out = []
        for i, v in enumerate(values):
            out.append(v.rjust(widths[i]) if headers[i] in numeric else v.ljust(widths[i]))
        return "  ".join(out).rstrip()

    lines = [line(headers), "  ".join("-" * w for w in widths)]
    lines.extend(line(r) for r in cells)
    return "\n".join(lines)
