@rem windows can't run the shebang in huey, so hand it to nvim directly
@nvim -l "%~dp0huey" %*
