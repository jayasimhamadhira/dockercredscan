Set-StrictMode -Version Latest
#$cmdPath = "$PSScriptRoot\CredentialScanner.exe"

$repoLogsOutput="C:\dockercredscan\"
$toolPath ="C:\dockercredscan\tools\CredentialScanner.exe"        
$dir = "C:\dockercredscan\.kitchen.yml"       
$searcher="C:\dockercredscan\tools\Searchers\buildsearchers.xml"              
Write-Output "$toolPath $dir $repoLogsOutput"
& $toolPath -I "$dir" -S $searcher -O "$repoLogsOutput" -f csv -cp
  
