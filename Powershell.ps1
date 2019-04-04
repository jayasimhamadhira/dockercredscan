    [string]$ServerName="sqlcredscan.database.windows.net"
    [string]$UserName="jayasimha"
    [string]$Password="Admin@12345678"
    $DbName="sqlcredscan"
    $RgName="Credscan-TFSV-RG"  
    $RgLocation="Central US"
    $storageaccountName="credscanrepo"
    $ContainerName="credscan-container"
    $tfvcRepositoryPath = "C:\TFVCRepopath"

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

 function CloneTFVCRepo($prjName,$url,$PAT,$tfvcRepositoryPath,$tfvctoolpath)
    {         
        try
        {
            $cs_userName = "v-jamad@microsoft.com"            

            New-Item -ItemType Directory -Path "$tfvcRepositoryPath\$prjName" -Force
            cd $tfvcRepositoryPath\$prjName                    
              #& "$tfvctoolpath\TFVCCloningExe\TFVCCloning.exe" $url $cs_userName $PAT $prjName gdbldsvc@microsoft.com $/$prjName $tfvcRepositoryPath\$prjName 
            & "$tfvctoolpath\HelperTool\TFVCCloning.exe" $url $cs_userName $PAT $prjName v-jamad@microsoft.com $/$prjName $tfvcRepositoryPath\$prjName             
        }
        catch [System.Exception]
        {
            $message=$_ -replace "The running command stopped because the preference variable ""ErrorActionPreference"" or common parameter is set to Stop: ",""    
            throw "$message"+"~Cloning"
     
        }        
    }  

    #New-Item -ItemType directory -Path "C:\TFVCRepopathCSV"
   # New-Item -ItemType directory -Path "C:\TFVCRepopath"

    $count=1

    do
   {

    $connection.Open()
    $command2 = $connection.CreateCommand() 
    $command2.CommandText = "Exec usp_GetTFVCRepository" 
    $dataAdapt = new-object System.Data.SqlClient.SqlDataAdapter $command2
    $dataS2 = New-Object System.Data.DataSet
   Write-Host $dataAdapt.Fill($dataS2)       
   Write-Host $dataS2.Tables.Count
   $connection.Close()

   if($dataS2.Tables.Count -gt 0 -And $dataS2.Tables[0].Rows.Count -gt 0)
    
    {    
   $count = 1
                    $repopath1 =  $dataS2.Tables[0].Rows[0]["OrganizationURL"]
                    $RepoName1 = $dataS2.Tables[0].Rows[0]["ProjectName"]
                    $RepoId1 = $dataS2.Tables[0].Rows[0]["ProjID"]
                
            }
            else
            {
            $count = 0
            }





    CloneTFVCRepo -prjName $RepoName1 -url $repopath1 -PAT "levn24wy5wmx2gkyv5qo64smhu3yj4wkqyn572n3hmaxnxusjnjq" -tfvctoolpath "C:\TFVCCloneTool" -tfvcRepositoryPath "C:\TFVCRepopath"

    ExecCredScan -projectName $RepoName1 -repoName $RepoName1 -searchersPath "C:\Credscan\tools\Searchers\buildsearchers.xml" -toolPath "C:\Credscan\tools\CredentialScanner.exe" -repositoryPath "C:\TFVCRepopath" -repoLogsOutput "C:\TFVCRepopathCSV"
    

     Set-AzureStorageBlobContent -Container $ContainerName -File "C:\TFVCRepopathCSV\$RepoName1-matches.csv" -Context $storeageaccount.Context -Force

         $connection.Open()
         $query1 = "update TFVC_CredScan set IsProcessed=1, IsAccessed = 0 where ProjID='$RepoId1' "
        $command1 = $connection.CreateCommand()
        $command1.CommandText = $query1
        $result = $command1.ExecuteReader()
         $connection.Close()

    }
    until ($count -eq 0)
    
    function ExecCredScan($projectName, $repoName, $searchersPath, $toolPath, $repoType, $accountName,$repositoryPath,$repoLogsOutput)
    {     
        try
        {

        #$repoLogsOutput = "$resultsPath\$accountName!!$projectName!!$repoName!!$repoType$Using:InstanceNo"     
            $dir = "$repositoryPath\$repoName"       

            $repoLogsOutput="C:\TFVCRepopathCSV\$projectName"
            Write-Output "$repoLogsOutput"
      
            & $toolPath -I "$dir" -S "$searchersPath" -O "$repoLogsOutput" -f csv -cp
        }
        catch [System.Exception]
        {
            $message=$_ -replace "The running command stopped because the preference variable ""ErrorActionPreference"" or common parameter is set to Stop: ",""    
            throw "$message"+"~Scanning"
        }  
    }

   
      # Set-AzureStorageBlobContent -Container $ContainerName -File "C:\TFVCRepopathCSV\$RepoName1-matches.csv" -Context $storeageaccount.Context -Force
        Write-Output "====Scan Completed and status updated===="
   

#until ($count -eq 0)
