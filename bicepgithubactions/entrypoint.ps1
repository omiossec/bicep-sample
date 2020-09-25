#$bicepFolder = Join-Path -Path $Env:INPUT_DIRECTORY  -ChildPath "bicep"
$bicepFolder = "/Users/oliviermiossec/Documents/work/dev-to-demo/bicep-sample/bicep"
$exitCodeCounter = 0 

if (test-path -Path $bicepFolder -ErrorAction SilentlyContinue) {
    $BicepFiles =  Get-ChildItem -Path $bicepFolder -Filter "*.bicep"


    foreach ($bicep in $BicepFiles) {

        Invoke-Expression "& bicep build $($bicep.FullName)"

        if ($LASTEXITCODE -ne 0) {
            write-error "File $($bicep.name) can't be compiled"
        }
        $exitCodeCounter += $LASTEXITCODE
    }


    if ($exitCodeCounter -gt 0){
        throw "Error at least one file did not compile"
        exit 1
    }

}

