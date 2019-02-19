Set-StrictMode -Version Latest
#$cmdPath = "$PSScriptRoot\CredentialScanner.exe"

$repoLogsOutput="C:\Users\saikiran\Desktop\"
$toolPath ="C:\Users\saikiran\Desktop\test\Tool\tools\CredentialScanner.exe"        
$dir = "C:\Users\saikiran\Desktop\test\Tool\msp_dev_current_28_12"       
$searcher="C:\Users\saikiran\Desktop\test\Tool\tools\Searchers\buildsearchers.xml"              
Write-Output "$toolPath $dir $repoLogsOutput"
& $toolPath -I "$dir" -S $searcher -O "$repoLogsOutput" -f csv -cp
  