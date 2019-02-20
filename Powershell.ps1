Set-StrictMode -Version Latest
#$cmdPath = "$PSScriptRoot\CredentialScanner.exe"

$repoLogsOutput="C:\dockercredscan\"
$toolPath ="C:\dockercredscan\Tool\tools\CredentialScanner.exe"        
$dir = "C:\dockercredscan\.kitchen.yml"       
$searcher="C:\dockercredscan\Tool\tools\Searchers\buildsearchers.xml"              
Write-Output "$toolPath $dir $repoLogsOutput"
& $toolPath -I "$dir" -S $searcher -O "$repoLogsOutput" -f csv -cp
  
