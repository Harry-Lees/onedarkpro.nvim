; extends
(list_splat_pattern ("*" @odp.operator.splat))
(dictionary_splat_pattern ("**" @odp.operator.splat))

(import_from_statement) "from" @odp.import_from

((function_definition name: (identifier) @odp.base_constructor)
(#any-of? @odp.base_constructor "__new__" "__init__"))

((identifier) @odp.keyword (#vim-match? @odp.keyword "^(kwargs|self)$"))
(class_definition "class" @odp.keyword.class)

"{" @odp.punctuation.brace
"}" @odp.punctuation.brace
