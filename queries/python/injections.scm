; Копия nvim-treesitter queries/python/injections.scm без квантификатора [ ... ]+
; в concatenated_string: на nvim 0.13-dev он разбирал 1109-строчный .py за ~3 с
; (остальные шаблоны ~10 мс) и вешал открытие файла и preview в пикерах.
; Обновил nvim-treesitter — сверь с ~/.local/share/nvim/site/queries/python/injections.scm.

(call
  function: (attribute
    object: (identifier) @_re)
  arguments: (argument_list
    (string
      (string_content) @injection.content))
  (#eq? @_re "re")
  (#set! injection.language "regex"))

(call
  function: (attribute
    object: (identifier) @_re)
  arguments: (argument_list
    (concatenated_string
      (string
        (string_content) @injection.content)))
  (#eq? @_re "re")
  (#set! injection.language "regex"))

((binary_operator
  left: (string
    (string_content) @injection.content)
  operator: "%")
  (#set! injection.language "printf"))

((comment) @injection.content
  (#set! injection.language "comment"))
