jj config set --user ui.editor "nvim"
jj config set --user user.name "Paul Fesenmeier"
jj config set --user user.email "pfesenmeier@gmail.com"
jj config set --user ui.diff-editor :builtin
jj config set --user ui.diff-formatter '["difft", "--color=always", "$left", "$right"]'
jj config set --user ui.default-command log
