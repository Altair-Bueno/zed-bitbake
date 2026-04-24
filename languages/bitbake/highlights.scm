; Adapted from https://github.com/tree-sitter-grammars/tree-sitter-bitbake (MIT)
; Copyright (c) 2023 Amaan Qureshi <amaanq12@gmail.com>

; Includes

[
  "inherit"
  "include"
  "require"
  "export"
  "import"
] @keyword

; Keywords

[
  "unset"
  "EXPORT_FUNCTIONS"
  "python"
  "assert"
  "exec"
  "global"
  "nonlocal"
  "pass"
  "print"
  "with"
  "as"
] @keyword

["async" "await"] @keyword

["return" "yield"] @keyword
(yield "from" @keyword)

(future_import_statement "from" @keyword "__future__" @constant)
(import_from_statement "from" @keyword)
"import" @keyword

(aliased_import "as" @keyword)

["if" "elif" "else"] @keyword
["for" "while" "break" "continue"] @keyword

[
  "try"
  "except"
  "except*"
  "raise"
  "finally"
] @keyword

(raise_statement "from" @keyword)
(try_statement (else_clause "else" @keyword))

[
  "addtask"
  "deltask"
  "addhandler"
  "def"
  "lambda"
] @keyword

["before" "after"] @keyword
["append" "prepend" "remove"] @type

; Variables

[
  (identifier)
  (python_identifier)
] @variable

[
  "noexec"
  "INHERIT"
  "OVERRIDES"
  "$BB_ENV_PASSTHROUGH"
  "$BB_ENV_PASSTHROUGH_ADDITIONS"
] @variable.special

; Identifier naming conventions

((python_identifier) @type
 (#match? @type "^[A-Z].*[a-z]"))

([(identifier) (python_identifier)] @constant
 (#match? @constant "^[A-Z][A-Z_0-9]*$"))

((python_identifier) @constant
 (#match? @constant "^__[a-zA-Z0-9_]*__$"))

((python_identifier) @constant
 (#any-of? @constant
   "NotImplemented" "Ellipsis" "quit" "exit"
   "copyright" "credits" "license"))

((assignment
  left: (python_identifier) @type
  (type (python_identifier) @_annotation))
 (#eq? @_annotation "TypeAlias"))

((assignment
  left: (python_identifier) @type
  right: (call
    function: (python_identifier) @_func))
 (#any-of? @_func "TypeVar" "NewType"))

; Properties / fields

(flag) @property

((attribute
    attribute: (python_identifier) @property)
 (#match? @property "^[a-z_].*$"))

; Functions

(call function: (python_identifier) @function)

(call function: (attribute attribute: (python_identifier) @function))

((call function: (python_identifier) @constructor)
 (#match? @constructor "^[A-Z]"))

((call function: (attribute attribute: (python_identifier) @constructor))
 (#match? @constructor "^[A-Z]"))

((call function: (python_identifier) @function)
 (#any-of? @function
   "abs" "all" "any" "ascii" "bin" "bool" "breakpoint" "bytearray" "bytes"
   "callable" "chr" "classmethod" "compile" "complex" "delattr" "dict" "dir"
   "divmod" "enumerate" "eval" "exec" "filter" "float" "format" "frozenset"
   "getattr" "globals" "hasattr" "hash" "help" "hex" "id" "input" "int"
   "isinstance" "issubclass" "iter" "len" "list" "locals" "map" "max"
   "memoryview" "min" "next" "object" "oct" "open" "ord" "pow" "print"
   "property" "range" "repr" "reversed" "round" "set" "setattr" "slice"
   "sorted" "staticmethod" "str" "sum" "super" "tuple" "type" "vars" "zip"
   "__import__"))

(python_function_definition name: (python_identifier) @function)

(type (python_identifier) @type)
(type (subscript (python_identifier) @type))

((call
  function: (python_identifier) @_isinstance
  arguments: (argument_list (_) (python_identifier) @type))
 (#eq? @_isinstance "isinstance"))

(anonymous_python_function (identifier) @function)
(function_definition (identifier) @function)
(addtask_statement (identifier) @function)
(deltask_statement (identifier) @function)
(export_functions_statement (identifier) @function)
(addhandler_statement (identifier) @function)

(python_function_definition
  body: (block . (expression_statement (python_string) @string)))

; Namespace / inherit paths

(inherit_path) @type

; Parameters

(parameters (python_identifier) @variable.parameter)
(lambda_parameters (python_identifier) @variable.parameter)
(lambda_parameters (tuple_pattern (python_identifier) @variable.parameter))
(keyword_argument name: (python_identifier) @variable.parameter)
(default_parameter name: (python_identifier) @variable.parameter)
(typed_parameter (python_identifier) @variable.parameter)
(typed_default_parameter (python_identifier) @variable.parameter)
(parameters (list_splat_pattern (python_identifier) @variable.parameter))
(parameters (dictionary_splat_pattern (python_identifier) @variable.parameter))

; Literals

(none) @constant
[(true) (false)] @boolean

((python_identifier) @variable.special (#eq? @variable.special "self"))
((python_identifier) @variable.special (#eq? @variable.special "cls"))

(integer) @number
(float) @number

; Operators

[
  "?=" "??=" ":=" "=+" ".=" "=." "-" "-=" "!="
  "*" "**" "**=" "*=" "/" "//" "//=" "/="
  "&" "&=" "%" "%=" "^" "^=" "+" "+="
  "<" "<<" "<<=" "<=" "<>" "=" "==" ">" ">=" ">>" ">>="
  "@" "@=" "|" "|=" "~" "->"
] @operator

["and" "in" "is" "not" "or" "is not" "not in" "del"] @keyword

; String literals

[
  (string)
  (python_string)
  "\""
] @string

(include_path) @string.special

[
  (escape_sequence)
  (escape_interpolation)
] @string.escape

; Punctuation

["(" ")" "{" "}" "[" "]"] @punctuation.bracket

[":" "->" ";" "." "," (ellipsis)] @punctuation.delimiter

(variable_expansion ["${" "}"] @punctuation.special)
(inline_python ["${@" "}"] @punctuation.special)
(interpolation "{" @punctuation.special "}" @punctuation.special)

(type_conversion) @function

; Built-in types

([(identifier) (python_identifier)] @type.builtin
 (#any-of? @type.builtin
   "BaseException" "Exception" "ArithmeticError" "BufferError" "LookupError"
   "AssertionError" "AttributeError" "EOFError" "FloatingPointError"
   "GeneratorExit" "ImportError" "ModuleNotFoundError" "IndexError" "KeyError"
   "KeyboardInterrupt" "MemoryError" "NameError" "NotImplementedError" "OSError"
   "OverflowError" "RecursionError" "ReferenceError" "RuntimeError"
   "StopIteration" "StopAsyncIteration" "SyntaxError" "IndentationError"
   "TabError" "SystemError" "SystemExit" "TypeError" "UnboundLocalError"
   "UnicodeError" "UnicodeEncodeError" "UnicodeDecodeError"
   "UnicodeTranslateError" "ValueError" "ZeroDivisionError" "EnvironmentError"
   "IOError" "WindowsError" "BlockingIOError" "ChildProcessError"
   "ConnectionError" "BrokenPipeError" "ConnectionAbortedError"
   "ConnectionRefusedError" "ConnectionResetError" "FileExistsError"
   "FileNotFoundError" "InterruptedError" "IsADirectoryError"
   "NotADirectoryError" "PermissionError" "ProcessLookupError" "TimeoutError"
   "Warning" "UserWarning" "DeprecationWarning" "PendingDeprecationWarning"
   "SyntaxWarning" "RuntimeWarning" "FutureWarning" "ImportWarning"
   "UnicodeWarning" "BytesWarning" "ResourceWarning"
   "bool" "int" "float" "complex" "list" "tuple" "range" "str"
   "bytes" "bytearray" "memoryview" "set" "frozenset" "dict" "type" "object"))

(comment) @comment

(ERROR) @error
