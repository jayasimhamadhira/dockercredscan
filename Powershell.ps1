 [string]$ServerName="sqlcredscan.database.windows.net"
    [string]$UserName="jayasimha"
    [string]$Password="Admin@12345678"
    $DbName="sqlcredscan"
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
    $EU="svcenvdv@microsoft.com"
    $EP="P@sw0rd!13"
    $Subscription="c1bd9039-9169-41b6-9b75-6eef04aaf8a4"
    $AzureSubscriptionTenantId="72f988bf-86f1-41af-91ab-2d7cd011db47"
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
      $connection.Open()
     $command2 = $connection.CreateCommand() 
    $command2.CommandText = "EXEC dbo.usp_GetAvailableRepository" 
    $dataAdapt = new-object System.Data.SqlClient.SqlDataAdapter $command2
    $dataS2 = New-Object System.Data.DataSet
   Write-Host $dataAdapt.Fill($dataS2)       
   Write-Host $dataS2.Tables.Count
    #$readerresult=$command.ExecuteReader()
    if($dataS2.Tables.Count -gt 0 -And $dataS2.Tables[0].Rows.Count -gt 0)
    #if($readerresult.HasRows)
    {    
        $count = 1
                #while ($readerresult.Read())
                #{            
                    
                    $repopath =  $dataS2.Tables[0].Rows[0]["Repopath"]
                    $RepoName = $dataS2.Tables[0].Rows[0]["RepoName"]
                    $RepoId = $dataS2.Tables[0].Rows[0]["RepoID"]
                   # break;
                                  
                #}
            }
            else
            {
            $count = 0
            }
           # $readerresult.Close()
            if ($count -eq 1)
            {

       Write-output "entered into while block"
        #$query = “select top 1 * from SQLCredscan where IsAccessed = 0 and IsProcessed= 0” #Remove this code
        #$command = new-object system.data.sqlclient.sqlcommand($query,$connection)
        #$connection.Open()
        #$adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
        #$dataset = New-Object System.Data.DataSet
        #$adapter.Fill($dataSet) | Out-Null
        $connection.Close()
        #$table=$dataSet.Tables
        #$repopath=$table.Rows["Repopath"]
        #$RepoName=$table.Rows["RepoName"]
        $dir = "C:\Repoclone\$RepoName"  
        $toolPath ="C:\Credscan\tools\CredentialScanner.exe" 
        $searcher="C:\Credscan\tools\Searchers\buildsearchers.xml"
        $repoLogsOutput="C:\CSV\$RepoName"
        Write-Output "===Cloning repo $repopath===" 
        git clone $repopath $dir
        #$connection = New-Object System.Data.SqlClient.SqlConnection
        #$connection.ConnectionString = $connectionString
        #$connection.Open()
        #$query = “update SQLCredscan set IsAccessed=1 where RepoName='$RepoName' ” #Remove this code
        #$command = $connection.CreateCommand()
       # $command.CommandText = $query
       # $result = $command.ExecuteReader()
        Write-Output "$toolPath $dir $repoLogsOutput"
        & $toolPath -I "$dir" -S $searcher -O "$repoLogsOutput" -f csv -cp
       # $connection = New-Object System.Data.SqlClient.SqlConnection
       # $connection.ConnectionString = $connectionString
        $connection.Open()
        $query1 = "update Credscan12 set IsProcessed=1, IsAccessed = 0 where RepoID='$RepoId'"
        $command1 = $connection.CreateCommand()
        $command1.CommandText = $query1
        $result = $command1.ExecuteReader()
         $connection.Close()

        Set-AzureStorageBlobContent -Container $ContainerName -File "$repoLogsOutput-matches.csv" -Context $storeageaccount.Context -Force
        Write-Output "====Scan Completed and status updated===="
       # $connection = New-Object System.Data.SqlClient.SqlConnection
        #$connection.ConnectionString = $connectionString
        #$connection.Open()
        #$query = “select count (isprocessed) from SQLCredscan where isprocessed=0” #remove this code
        #$command = $connection.CreateCommand()
        #$command.CommandText = $query
        #$count = $command.ExecuteScalar()  #remove this code
        #$connection.Close()
        }
    }
    catch
    {
    throw $_.Exception
    }
}
until ($count -eq 0)
