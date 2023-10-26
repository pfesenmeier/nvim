# modify just user 

# https://stackoverflow.com/a/29109007
function AddTo-Path{
param(
    [string]$Dir
)

    if( !(Test-Path $Dir) ){
        Write-warning "$Dir not found."
        return
    }

    $PATH = [Environment]::GetEnvironmentVariable("PATH", "user")

    # notmatch => regex
    # notlike => glob
    if( $PATH -notlike "*"+$Dir+"*" ){
        "Adding $Dir."
        [Environment]::SetEnvironmentVariable("PATH", "$PATH;$Dir", "user")
    }
}

