[//]: # (need to add repository contents to the readme)

# AnalysisServices-Functionality-Demo  

A fully functional demo of capabilities of SQL Server Analysis Services, including multidimensional, tabular, CPM / writeback, and various MDX / DAX examples.

## Prerequisites
SQL Server (preferably 2014 or greater as this is the context in which the repository was created) must be installed and the user must have create database permissions / credentials.  Additionally, depending on the impersonation of the connection between SSAS and SQL Server, be able to add logins and user, and grant / revoke security privileges. 

Additionally, if you want to run the below Powershell scripts, the default security level may not allow their execution. In order to bypass this and allow 'local' executions, run the below:

```powershell
set-executionpolicy remotesigned
```

## Installation

The following Powershell script will build the database from the `bacpac` files in this repository.  Below are the only variables that [probably] should be altered:
- `$databases`: the `bacpac` file names and, in turn, the database names,
- `$instance`: the name of the SQL Server instance to deploy to, and
- `$dir`: the location of the forked repository.

If you do not want to run the below script, you can use the SSMS IDE, under the context `Databases\Import Data-tier Application`, and following the wizard - note that you will need to manually configure the security if this method is used.

```powershell
# alter the three variables below as necessary
$databases = @('demo_planning','demo_financial')
$instance = "localhost"
$dir = '...\GitHub\Analysis-Services-Demo\'

# do not alter these variables
$bacpac = "$dir\data\"
$loginSecurity = "$dir\security\login.sql"
$userSecurity = "$dir\security\user.sql"
$cnn = "Data Source=$instance;Initial Catalog=$master;Integrated Security=True;Connection Timeout=0;"

# location / version dependent, make sure to check this
Add-Type -path "C:\Program Files (x86)\Microsoft SQL Server\120\DAC\bin\Microsoft.SqlServer.Dac.dll" 

# create the demo login
Invoke-SqlCmd -InputFile $loginSecurity -ServerInstance $instance -Database "master" -Verbose

# build the databases
foreach ($database in $databases) {
    Write-Output "Building $database database..."
    
    $load = [Microsoft.SqlServer.Dac.BacPackage]::Load("$bacpac$database.bacpac")
    $import = New-Object Microsoft.SqlServer.Dac.DacServices $cnn
    $import.ImportBacpac($load, $database)
    $load.Dispose()

    Invoke-SqlCmd -InputFile $userSecurity -ServerInstance $instance -Database $database -Verbose

}
```

Once you have taken a look at the created databases, the following Powershell script will deploy the analytical layer to the SSAS instance. The following variables should be altered:
- `$instance`: the SSAS instance that the projects will be deployed to,
- `$folder`:  the file location of the solution (`.sln`) files (location of the forked repository)
- `$devenv`: the location of `devenv.exe`, this might vary.

```powershell
# alter the three variables below as necessary
$instance = "localhost"
$folder = "...\GitHub\Analysis-Services-Demo\ssas\"
$devenv = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\devenv.exe"

# some constants and an assembly load
$generate = "Microsoft.AnalysisServices.Deployment.exe"
$solution = "SSAS Demo.sln"
$solutionfile = "$folder$solution"
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices.AdomdClient") # risk of deprecation
$databases = @("Planning Demo", "Financial Demo")

# for each database
foreach ($database in $databases) {
    Write-Host "Processing $database..."

    # build the solution
    $project = "$database\$database.dwproj"

    # wipe the bin directory and [re]build the project
    Remove-Item "$folder$database\bin\*"
    & $devenv $solutionfile /build Development /project $project /projectconfig Development

    # before you move forward, make sure the build files are there
    while (-not(Test-Path "$folder\$database\bin\$database.asdatabase")) {
        Start-Sleep -s 2
    }

    # build the xmla required by ssas
    $output = "$folder\$database\bin\$database.xmla"
    & $generate "$folder\$database\bin\$database.asdatabase" /s:"$output.log" /o:$output

    # update the connection string to include the password
    $xml = [xml](Get-Content $output)
    $xml.Data.Course.Subject
    $node = $xml.Batch.Alter.ObjectDefinition.Database.DataSources.DataSource
    $cnns = $node.ConnectionString
    $cnns = $cnns -split ";"
    $cnns = $cnns -like "Initial Catalog*"
    $cnns = $cnns -split "="
    $catalog = $cnns[1]
    $node.ConnectionString = "Provider=SQLNCLI11.1;Data Source=$instance;Persist Security Info=True;User ID=demo_reader;Initial Catalog=$catalog;Password=demo_reader"
    $xml.Save($output)

    # 
    $cnn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection “Data Source=$instance”
    $cnn.Open()
    $xmla = Get-Content $output
    $cmd = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdCommand $xmla, $cnn
    $cmd.ExecuteNonQuery()
}
```

## Repository Contributors

Michael Flanigan  
email: [mick.flanigan@gmail.com](mick.flanigan@gmail.com)  
twitter: [@mjfii](https://twitter.com/mjfii)  

## Versioning

0.0.0.9000 - Initial deployment (2017-05-24)
