param (
    # Database info parameters    
    [string]$connectionString,
    [string]$databaseName,
    [string]$testOrClassName = "",

    # Test Result parameters
    [string]$testResultsFileName,

    # Code Coverage parameters
    [string]$openCoverSourceFolder,
    [string]$openCoverXmlFile,
    [string]$coberturaFileName,
    [string]$htmlReportsOutput,
    [string]$queryTimeout
)

$sqlCoverPath = "$PSScriptRoot\dependencies\sqlcover\SQLCover.dll"
Add-Type -Path $sqlCoverPath
Write-Output "Successfully added SQLCover dependency from $sqlCoverPath"

# $connectionString = "Server=tcp:$server,1433;Initial Catalog=$database;Persist Security Info=False;User ID=$username;Password=$password;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;"
Write-Output "Running the tSQLt tests and getting Code Coverage..."

$connectionStringBuilder = New-Object System.Data.Common.DbConnectionStringBuilder
$connectionStringBuilder.set_ConnectionString($connectionString)
Write-Output "Database set to $databaseName"

$coverage = new-object SQLCover.CodeCoverage($connectionString, $databaseName, $null, $true, $false, [SQLCover.Trace.TraceControllerType]::Azure)

$startResult = $coverage.Start()

if(!$startResult){
    Write-Error "Error while starting the Unit Test with Code Coverage session."
    Exit -1
}

. .\Invoke-tSQLtTests.ps1 -connectionString $connectionString `
    -testResultsFileName $testResultsFileName `
    -queryTimeout $queryTimeout `
    -testOrClassName $testOrClassName

$coverageResults = $coverage.Stop()

New-Item -Type Directory -Force -Path $openCoverSourceFolder | out-Null
Write-Output "Successfully created $openCoverSourceFolder"

$coverageResults.OpenCoverXml() | Out-File -force $openCoverXmlFile
Write-Output "Successfully generated OpenCover XML report at $openCoverXmlFile."

$coverageResults.SaveSourceFiles($openCoverSourceFolder)
Write-Output "Successfully saved source code to $openCoverSourceFolder"

Write-Output "Converting OpenCover to Cobertura results..."
$coberturaConverterToolPath = Join-Path -Path $PSScriptRoot -ChildPath "dependencies\opencovertocoberturaconverter\OpenCoverToCoberturaConverter.exe"
$argsList = "-input:$openCoverXmlFile -output:$coberturaFileName -sources:$openCoverSourceFolder -includeGettersSetters:true"

Start-Process -FilePath $coberturaConverterToolPath -ArgumentList $argsList -NoNewWindow -Wait
Write-Output "Finished converting OpenCover to Cobertura. File available at $coberturaFileName"

Write-Output "Generating Azure Pipelines report from Cobertura results..."
$reportGeneratorToolPath = Join-Path -Path $PSScriptRoot -ChildPath "dependencies\reportgenerator\ReportGenerator.exe"
$argsList = "-reports:$coberturaFileName -targetDir:$htmlReportsOutput -reporttype:HtmlInline_AzurePipelines -sourcedirs:$openCoverSourceFolder -assemblyfilters:+* -classfilters:+* -filefilters:+* -verbosity:Verbose"

Start-Process -FilePath $reportGeneratorToolPath -ArgumentList $argsList -NoNewWindow -Wait
Write-Output "Finished generating Azure Pipelines report at $htmlReportsOutput"