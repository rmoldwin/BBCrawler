"""Execute the approved dbo.Clean2 replacement program locally, without SQL Server.

The bundled SQL is the single rule source. Only its straight-line string
expressions are supported; unsupported syntax fails rather than guessing.
"""
from __future__ import annotations

from functools import lru_cache
from pathlib import Path
import re

__all__ = ["clean2"]

_CHAR_REPLACEMENTS = {
    **{chr(n): "" for n in (8203, 8204, 8205, 8288, 65279, 173, 8206, 8207,
                           8234, 8235, 8236, 8237, 8238, 8294, 8295, 8296, 8297)},
    **{chr(n): " " for n in (9, 10, 13, 160, 8194, 8195, 8196, 8197, 8198,
                            8199, 8200, 8201, 8202, 8239, 8287, 12288)},
    **{chr(n): "-" for n in (8208, 8209, 8210, 8211, 8212, 8213, 65112, 65123, 65293)},
    "\u00df": "\u03b2", "\u00e6": "ae", "\u00c6": "Ae",
    "\u0153": "oe", "\u0152": "Oe",
}
_TOKEN = re.compile(r"N'(?:''|[^'])*'|--[^\n]*|@\w+|[A-Za-z_]\w*|\d+|[()+,;=-]")
_FUNCTIONS = {"REPLACE", "NCHAR", "LEFT", "CHARINDEX", "LTRIM", "RTRIM"}


def _truncate_nvarchar4000(value: str) -> str:
    encoded = value.encode("utf-16-le", errors="surrogatepass")[:8000]
    return encoded.decode("utf-16-le", errors="surrogatepass")


class _Expression:
    def __init__(self, tokens: list[str], position: int):
        self.tokens = tokens
        self.position = position

    def take(self, expected: str | None = None) -> str:
        token = self.tokens[self.position]
        if expected is not None and token != expected:
            raise ValueError(f"Unsupported Clean2 SQL: expected {expected}, found {token}")
        self.position += 1
        return token

    def parse(self) -> tuple:
        node = self.atom()
        while self.tokens[self.position] in ("+", "-", "COLLATE"):
            op = self.take()
            if op == "COLLATE":
                if self.take() != "Latin1_General_100_BIN2":
                    raise ValueError("Clean2 must use exact BIN2 string comparisons")
            else:
                node = (op, node, self.atom())
        return node

    def atom(self) -> tuple:
        token = self.take()
        if token.startswith("N'"):
            return ("literal", token[2:-1].replace("''", "'"))
        if token.isdecimal():
            return ("literal", int(token))
        if token == "@s":
            return ("variable",)
        if token == "(":
            node = self.parse()
            self.take(")")
            return node
        if token not in _FUNCTIONS:
            raise ValueError(f"Unsupported Clean2 expression: {token}")
        self.take("(")
        args = [self.parse()]
        while self.tokens[self.position] == ",":
            self.take(",")
            args.append(self.parse())
        self.take(")")
        return (token, *args)


def _compile() -> tuple[tuple, ...]:
    text = Path(__file__).with_name("00_dbo_Clean2.sql").read_text(encoding="utf-8")
    tokens = [token for token in _TOKEN.findall(text) if not token.startswith("--")]
    if any(token in {"IF", "WHILE", "CASE", "EXEC", "SELECT"} for token in tokens):
        raise ValueError("Clean2 must remain a straight-line string replacement program")
    if not any(tokens[i:i + 3] == ["RETURN", "@s", ";"] for i in range(len(tokens) - 2)):
        raise ValueError("Clean2 must return its final string variable")
    program = []
    position = 0
    while position < len(tokens) - 2:
        if tokens[position:position + 3] == ["SET", "@s", "="]:
            parser = _Expression(tokens, position + 3)
            program.append(parser.parse())
            parser.take(";")
            position = parser.position
        else:
            position += 1
    if not program:
        raise ValueError("Bundled Clean2 replacement program is missing")
    return tuple(program)


def _evaluate(node: tuple, value: str):
    op = node[0]
    if op == "literal":
        return node[1]
    if op == "variable":
        return value
    args = [_evaluate(arg, value) for arg in node[1:]]
    if op == "+":
        return args[0] + args[1]
    if op == "-":
        return args[0] - args[1]
    if op == "REPLACE":
        return args[0].replace(args[1], args[2]) if args[1] else args[0]
    if op == "NCHAR":
        return chr(args[0])
    if op == "LEFT":
        return args[0][:args[1]]
    if op == "CHARINDEX":
        return args[1].find(args[0]) + 1
    if op == "LTRIM":
        return args[0].lstrip(args[1] if len(args) > 1 else " ")
    if op == "RTRIM":
        return args[0].rstrip(args[1] if len(args) > 1 else " ")
    raise ValueError(f"Unsupported Clean2 operation: {op}")


_PROGRAM = _compile()


@lru_cache(maxsize=32768)
def clean2(value: str | None) -> str | None:
    """Preserve NULL/case and match the bundled SQL's 4000-unit contract."""
    if value is None:
        return None
    value = _truncate_nvarchar4000(value)
    for instruction in _PROGRAM:
        value = _truncate_nvarchar4000(_evaluate(instruction, value))
    return value
