# modify just user 

function AddTo-Path{
param(
    [string]$Dir
)

    if( !(Test-Path $Dir) ){
        Write-warning "Supplied directory was not found!"
        return
    }

    $PATH = [Environment]::GetEnvironmentVariable("PATH", "user")

    # TODO => better expression?
    # notmatch / match uses regular expressions
    if( $PATH -notlike "*"+$Dir+"*" ){
        [Environment]::SetEnvironmentVariable("PATH", "$PATH;$Dir", "user")
    }
}

$paths = (
)

#TODO - iterate

# print out that must close your shell
