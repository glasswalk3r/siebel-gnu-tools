param( 
[Parameter(Position=0, Mandatory=$False, ValueFromPipeline=$False)] [Int] $maxThreads = 10,
[Parameter(Position=0, Mandatory=$False, ValueFromPipeline=$False)] [Int] $sleepTimer = 500, 
[Parameter(Position=0, Mandatory=$False, ValueFromPipeline=$False)] [Int] $maxWaitAtEnd = 600, 
[Parameter(Position=0, Mandatory=$False, ValueFromPipeline=$False)] [String] $outputType = "GridView",
[Parameter(Position=0, Mandatory=$False, ValueFromPipeline=$False)] [String] $cfg = "dx_mon.xml" )

"Killing existing jobs . . ."
Get-Job | Remove-Job -Force
"Done."

$config = [xml] [string]::join("\n",(Get-Content -read 5kb $cfg))

$credentials = Get-Credential
$plainCred = $credentials.GetNetworkCredential()

$conn = new-object system.data.oledb.oledbconnection
$conn.ConnectionString = ("Provider=" + $config.dxReport.OLEDB.provider + ";Data Source=" + $config.dxReport.OLEDB.datasource + ";" + $config.dxReport.OLEDB.loginString + "=" + $plainCred.Username + ";" + $config.dxReport.OLEDB.passwordString + "=" + $plainCred.Password + ";")
$conn.open()

Remove-Variable credentials
Remove-Variable plainCred

$query = @"
SELECT A.APP_SERVER_NAME, 
       B.LOGIN, 
       C.LAST_UPD,
       D.NAME
FROM SIEBEL.S_NODE A, 
     SIEBEL.S_USER B, 
     SIEBEL.S_DOCK_STATUS C, 
     SIEBEL.S_POSTN D, 
     SIEBEL.S_PARTY E, 
     SIEBEL.S_CONTACT F
WHERE A.NODE_TYPE_CD = 'REMOTE'
      AND A.EFF_END_DT IS NULL
      AND A.EMP_ID   = B.ROW_ID
      AND C.NODE_ID  = A.ROW_ID
      AND C.TYPE     = 'SESSION'
      AND C.LOCAL_FLG = 'Y'
      AND E.ROW_ID = B.PAR_ROW_ID
      AND F.PAR_ROW_ID = E.ROW_ID
      AND F.PR_HELD_POSTN_ID = D.ROW_ID
"@

$cmd = new-object system.data.oledb.oledbcommand
$cmd.Connection = $conn
$cmd.CommandText = $query

$reader = $cmd.ExecuteReader()

$data = @()

$i = 0

$tzn = [System.TimeZoneInfo]::Local

While ($reader.read()) {

    if ( $reader.IsDbNull(0) -or $reader.IsDbNull(1) ) {
    
        Write-Error "A row recovered from database has null in one of the columns"
    
    } else {
    
        $obj = New-Object Object
        $obj | Add-Member NoteProperty server -value $reader.getValue(0)
        $obj | Add-Member NoteProperty login -value $reader.getValue(1)
        $obj | Add-Member NoteProperty lastSynchSession -value ([System.TimeZoneInfo]::ConvertTimeFromUtc($reader.getValue(2), $tzn))
        $obj | Add-Member NoteProperty primaryHeldPosition -value $reader.getValue(3)
        $obj | Add-Member NoteProperty totalOfDX -value 0
        $obj | Add-Member NoteProperty outbox -value ('\\' + $reader.getValue(0) + '\' + $config.dxReport.siebelInstallPath + '\' + $reader.getValue(1) + '\outbox')
        
        $data = $data + $obj
        
        Clear-Variable obj
        
    }
            
}

$reader.close()
$conn.close()

$activity = "Counting DX Files"

foreach ( $user in $data ) {

    While ($(Get-Job -state running).count -ge $MaxThreads){
    
        Write-Progress  -Activity "Counting DX Files" -Status "Waiting for threads to close" -CurrentOperation "$i threads created - $($(Get-Job -state running).count) threads open" -PercentComplete ($i / $data.count * 100)
        Start-Sleep -Milliseconds $SleepTimer
        
    }

    $jobName = 'count DX files of ' + $user.login
    
    $i++
    
    try {

        Start-Job -FilePath $config.dxReport.scriptFile -ArgumentList $user  -Name $jobName | Out-Null
        
    } catch {
    
        write-host $error[0].exception –foregroundcolor red
    
    }        

    Write-Progress  -Activity $activity -Status "Starting Threads" -CurrentOperation "$i threads created - $($(Get-Job -state running).count) threads open" -PercentComplete ($i / $data.count * 100)

}

$Complete = Get-date

While ($(Get-Job -State Running).count -gt 0){

    $jobsStillRunning = ""
    
    ForEach ($job  in $(Get-Job -state running)) {
    
        $jobsStillRunning += ", $($job.name)"
        
    }
    
    $jobsStillRunning = $jobsStillRunning.Substring(2)
    Write-Progress  -Activity $activity -Status "$($(Get-Job -State Running).count) threads remaining" -CurrentOperation "$jobsStillRunning" -PercentComplete ($(Get-Job -State Completed).count / $(Get-Job).count * 100)

    If ($(New-TimeSpan $Complete $(Get-Date)).totalseconds -ge $MaxWaitAtEnd) {
        
        "Killing all jobs still running . . ."
        Get-Job -State Running | Remove-Job -Force
        
    }
    
    Start-Sleep -Milliseconds $SleepTimer
    
}

"Reading all jobs"

If ($OutputType -eq "Text") {

    ForEach($Job in Get-Job) {

        $obj = Receive-Job $Job
        "$($Job.Name) = " + $obj.totalOfDX
        "****************************************"

    }

} Else {

    $jobs = Get-Job
    $returnData = @()
    
    try {
    
        foreach ( $i in $jobs ) {
        
            $returnData = $returnData + ( $i | Receive-Job )
        
        }
        
        $returnData | Select-Object * -ExcludeProperty RunspaceId | out-gridview
    
    } catch {
    
        write-host $error[0].exception –foregroundcolor red
    
    }

}
