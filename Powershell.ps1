    [string]$ServerName="credscansql.database.windows.net"
    [string]$UserName="jayasimha"
    [string]$Password="Admin@12345678"
    $DbName="CredscanSQL"
    $Clonedir = "C:\Credscan\Repoclone"
    $RgName="Credscan-RG"  
    $RgLocation="Central US"
    $storageaccountName="credscanrepo"
    $ContainerName="credscan-container"
    $Armexist=Get-Module -Name AzureRM.* -ListAvailable
    if(!($Armexist.Count -gt 0))
    {
        Install-Module -Name AzureRm -AllowClobber -Force -Verbose
    }
    $rg=Get-AzureRmResourceGroup -Name $RgName -Location $RgLocation -ErrorAction SilentlyContinue
    if(!$rg)
    {
        New-AzureRmResourceGroup -Name $RgName -Location $RgLocation
    }
    $storeageaccount=Get-AzureRmStorageAccount -ResourceGroupName $RgName -Name $storageaccountName -ErrorAction SilentlyContinue
    if(!$storeageaccount)
    {
        $storeageaccount=New-AzureRmStorageAccount -ResourceGroupName $RgName  -Name $storageaccountName -Location $RgLocation -SkuName Standard_LRS -Kind BlobStorage -AccessTier Cool
        New-AzureRmStorageContainer -Name $ContainerName -ResourceGroupName $RgName -StorageAccountName $storeageaccount.StorageAccountName -PublicAccess Blob
    }
$count=1
$connectionString = “Server=$ServerName;uid=$UserName; pwd=$Password;Database=$DbName;Integrated Security=False;”
$connection = new-object system.data.SqlClient.SQLConnection($connectionString)
do
{
    try
    {
        $query = “select top 1 * from SQLCredscan where IsAccessed = 0 and IsProcessed= 0”
        $command = new-object system.data.sqlclient.sqlcommand($query,$connection)
        $connection.Open()
        $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
        $dataset = New-Object System.Data.DataSet
        $adapter.Fill($dataSet) | Out-Null
        $connection.Close()
        $table=$dataSet.Tables
        $repopath=$table.Rows["Repopath"]
        $RepoName=$table.Rows["RepoName"]
        $dir = "C:\Repoclone\$RepoName"  
        $toolPath ="C:\Credscan\tools\CredentialScanner.exe" 
        $searcher="C:\Credscan\tools\Searchers\buildsearchers.xml"
        $repoLogsOutput="C:\CSV\$RepoName"
        Write-Output "===Cloning repo $repopath===" 
        git clone $repopath $dir
        $connection = New-Object System.Data.SqlClient.SqlConnection
        $connection.ConnectionString = $connectionString
        $connection.Open()
        $query = “update SQLCredscan set IsAccessed=1 where RepoName='$RepoName' ”
        $command = $connection.CreateCommand()
        $command.CommandText = $query
        $result = $command.ExecuteReader()
        Write-Output "$toolPath $dir $repoLogsOutput"
        & $toolPath -I "$dir" -S $searcher -O "$repoLogsOutput" -f csv -cp
        $connection = New-Object System.Data.SqlClient.SqlConnection
        $connection.ConnectionString = $connectionString
        $connection.Open()
        $query = “update SQLCredscan set IsProcessed=1 where RepoName='$RepoName' ”
        $command = $connection.CreateCommand()
        $command.CommandText = $query
        $result = $command.ExecuteReader()
        Set-AzureStorageBlobContent -Container $ContainerName -File "$repoLogsOutput-matches.csv" -Context $storeageaccount.Context
        Write-Output "====Scan Completed and status updated===="
        $connection = New-Object System.Data.SqlClient.SqlConnection
        $connection.ConnectionString = $connectionString
        $connection.Open()
        $query = “select count (isprocessed) from SQLCredscan where isprocessed=0”
        $command = $connection.CreateCommand()
        $command.CommandText = $query
        $count = $command.ExecuteScalar()
        $connection.Close()
    }
    catch
    {
    }
}
until ($count -eq 0)
