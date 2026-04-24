; Adapted from https://github.com/tree-sitter-grammars/tree-sitter-bitbake (MIT)
; Copyright (c) 2023 Amaan Qureshi <amaanq12@gmail.com>

; Inject regex language into re.* string arguments
(call
  function: (attribute object: (python_identifier) @_re)
  arguments: (argument_list
    (python_string (string_content) @injection.content) @_string)
  (#eq? @_re "re")
  (#match? @_string "^r.*")
  (#set! injection.language "regex"))

; Inject bash into shell task bodies
((shell_content) @injection.content
  (#set! injection.language "bash"))
