param( [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $false)] [string] $cfg )

$ErrorActionPreference = "stop"

function stopServices {
    
    param( [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $false)] [object] $services )
    
    write-host "Stopping related services..."
    
    foreach ($i in $services) {
    
        $serviceName = $i.InnerText

        'Stopping "' + $serviceName + '" service'

        $service = Stop-Service $serviceName -PassThru -Force

        if ( $service -ne $null ) {

            if ( $service.Status -ne 'Stopped' ) {

                throw "Could not stop $serviceName. Aborting..."

            } else {

                "$serviceName was stopped successfully"
                
            }

        }

    }    

}

function restoreServices {
    
    param( [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $false)] [object] $services,
           [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $false)] [int] $waitTime )
    
    write-host "Restarting related services..."
    
    $servicesReversed = @()
    
    foreach ( $i in $services) { $servicesReversed = $servicesReversed + $i.innerText }
    
    [array]::Reverse($servicesReversed)
    
    foreach ($serviceName in $servicesReversed) {
    
        Write-Host "Starting $serviceName service"

        $service = Start-Service $serviceName -PassThru

        if ( $service -ne $null ) {

            if ( $service.Status -ne 'Running' ) {

                throw "Could not start $serviceName. Aborting..."

            } else {

                Write-Host "$serviceName was started successfully"

            }

        }

        Write-Host "Waiting $waitTime seconds to give time to the process start correctly"

        Start-Sleep -Seconds $waitTime
        
    }

}

function getBackupDir {
    param( [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $false)] [string] $format,
           [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $false)] [string] $root,
           [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $false)] [object] $date )

    $formatOptions =  $format -split "_"
    
    $options = @()
    
    foreach ( $option in $formatOptions ) {
    
        $options += $started.($option)
    
    }
    
    ($root + "\" + ( $options -join "_" ))

}

try {

    $started = Get-Date

    $config = [xml] [string]::join("\n",(Get-Content -read 5kb $cfg))
    [void] [Reflection.Assembly]::LoadFile($config.compSRF.logging.log4netDLL)
    
    stopServices($config.compSRF.windowsServices.GetElementsByTagName("service"))
    
    $toolsBin = $config.compSRF.SiebelTools.root + $config.compSRF.SiebelTools.bin
    
    $pids = [System.Collections.Hashtable] @{}
    
    $srfBackupDir = getBackupDir -format $config.compSRF.SiebelTools.backup.srfSubdirFormat -root $config.compSRF.SiebelTools.backup.dirRoot -date $started
    
    if ( Test-Path $srfBackupDir ) {
    
        Write-Host $srfBackupDir "already exists"
    
    } else {
    
        New-Item -type 'directory' $srfBackupDir    
    
    }
    
    $srfToCopy = @()
    
    foreach ($lang in $config.compSRF.languagePacks.GetElementsByTagName("lang")) {
    
        if ( $lang.HasAttribute("srfFilename") ) {

            $destinationSRF = $config.compSRF.SiebelTools.serverRoot + "\" + $lang.InnerText + "\" + $lang.GetAttribute("srfFilename")
            $srfToCopy = $srfToCopy + $destinationSRF
            $jobName = $lang.InnerText + " SRF full compilation"
            
            $options = "/c " + $config.compSRF.SiebelTools.root + $config.compSRF.SiebelTools.cfg + " /d " + $config.compSRF.SiebelTools.dataSource + " /u " 
            $options += $config.compSRF.SiebelTools.user + " /p " + $config.compSRF.SiebelTools.password
            $options += " /bc '" + $config.compSRF.SiebelTools.siebelRepository + "' " + $destinationSRF + " /tl " + $lang.InnerText
        
            $process = (Start-Process -PassThru -FilePath $toolsBin -ArgumentList $options)
            
            Write-Host $process.ProcessName "for" $jobName "with PID =" $process.Id "started"
            
            $pids.Add($process.Id, $process)
        
        } else {
        
            throw "Cannot find SRF filename attribute in the configuration file"
        
        }
        
    }
    
    While ($pids.Count -gt 0) {

        foreach ($processId in $pids.Keys) {
        
            $process = $pids.$processId
        
            if ( $process.HasExited ) {
            
                Write-Host $process.ProcessName $process.Id "finished"
                $pids.Remove($processId)
                break
            
            }

        }
        
        Start-Sleep -Seconds $config.compSRF.SiebelTools.timeToWait
       
    }
    
    write-host "copying SRF files"
    
    foreach ($srf in $srfToCopy ) {

        Copy-Item $srf $srfBackupDir -Verbose    
    
    }
    
    restoreServices -services $config.compSRF.windowsServices.GetElementsByTagName("service") -waitTime $config.compSRF.timeToWait
    $finished = Get-Date
    
    $timeDiff =  $finished - $started
    write-host "Compilation took " $timeDiff.TotalMinutes "minutes to complete"
    
} catch {

    $error[0].exception

} finally {

}