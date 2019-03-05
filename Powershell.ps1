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
     $EU=""
    $EP=""
    $Subscription=""
    $AzureSubscriptionTenantId=""
    $azureAccountName = $EU
    $azurePassword = ConvertTo-SecureString $EP -AsPlainText -Force
    $psCred = New-Object System.Management.Automation.PSCredential($azureAccountName, $azurePassword)
    Start-Sleep -Seconds 2
    $login = Add-AzureRmAccount -SubscriptionName $Subscription -TenantId $AzureSubscriptionTenantId -Credential $psCred 
    if (!$login)
    { 
	    return
	} 
    $login
    Write-output "login completed"
        #Set-AzureRmContext cmdlet to set authentication information for cmdlets that we run in this PS session.
         Set-AzureRmContext -SubscriptionName $Subscription
   $rg=Get-AzureRmResourceGroup -Name $RgName -Location $RgLocation -ErrorAction SilentlyContinue
    if(!$rg)
    {
        write-output "Resource Group Created"
        New-AzureRmResourceGroup -Name $RgName -Location $RgLocation
    }
    $storeageaccount=Get-AzureRmStorageAccount -ResourceGroupName $RgName -Name $storageaccountName -ErrorAction SilentlyContinue
    if(!$storeageaccount)
    {
    	Write-output "Storage account created"
        $storeageaccount=New-AzureRmStorageAccount -ResourceGroupName $RgName  -Name $storageaccountName -Location $RgLocation -SkuName Standard_LRS -Kind BlobStorage -AccessTier Cool
        New-AzureRmStorageContainer -Name $ContainerName -ResourceGroupName $RgName -StorageAccountName $storeageaccount.StorageAccountName -PublicAccess Blob
	Write-output "Container created"
    }
$count=1
$connectionString = "Server=$ServerName;uid=$UserName; pwd=$Password;Database=$DbName;Integrated Security=False;"
$connection = new-object system.data.SqlClient.SQLConnection($connectionString)
Write-output "credential formed"
do
{
    try
    {
    	Write-output "entered into while block"
        $query = "select top 1 * from Credscan12 where IsAccessed = 0 and IsProcessed= 0"
        $command = new-object system.data.sqlclient.sqlcommand($query,$connection)
        $connection.Open()
        $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
        $dataset = New-Object System.Data.DataSet
        $adapter.Fill($dataSet) | Out-Null
        $connection.Close()
        $table=$dataSet.Tables
	write-output $table
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
        $query = "update Credscan12 set IsAccessed=1 where RepoName='$RepoName' "
        $command = $connection.CreateCommand()
        $command.CommandText = $query
        $result = $command.ExecuteReader()
        Write-Output "$toolPath $dir $repoLogsOutput"
        & $toolPath -I "$dir" -S $searcher -O "$repoLogsOutput" -f csv -cp
        $connection = New-Object System.Data.SqlClient.SqlConnection
        $connection.ConnectionString = $connectionString
        $connection.Open()
        $query = "update Credscan12 set IsProcessed=1 where RepoName='$RepoName'"
        $command = $connection.CreateCommand()
        $command.CommandText = $query
        $result = $command.ExecuteReader()
	$connection.Close()
        Set-AzureStorageBlobContent -Container $ContainerName -File "$repoLogsOutput-matches.csv" -Context $storeageaccount.Context
        Write-Output "====Scan Completed and status updated===="
        $connection = New-Object System.Data.SqlClient.SqlConnection
        $connection.ConnectionString = $connectionString
        $connection.Open()
        $query = "select count (isprocessed) from Credscan12 where isprocessed=0"
        $command = $connection.CreateCommand()
        $command.CommandText = $query
        $count = $command.ExecuteScalar()
        $connection.Close()
    }
    catch
    {
    	write-output $_.Exception
    }
}
until ($count -eq 0)
