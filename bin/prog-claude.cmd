@rem windows can't run the shebang in prog-claude, so hand it to nvim directly
@nvim -l "%~dp0prog-claude" %*
