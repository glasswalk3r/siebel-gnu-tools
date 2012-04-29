set-strictmode -version 2.0

#    COPYRIGHT AND LICENCE
#
#    This software is copyright (c) 2012 of Alceu Rodrigues de Freitas Junior, glasswalk3r@yahoo.com.br
#
#    This file is part of Siebel GNU Tools.
#
#    Siebel GNU Tools is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    Siebel GNU Tools is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Siebel GNU Tools.  If not, see <http://www.gnu.org/licenses/>.

# this script considers that the Windows server has all Siebel services installed
# edit the array services if your configuration is different

# order here is important to stop/start the services correctly
$services = @('W3SVC','siebsrvr_SIEBEL_foobar','gtwyns')

$timeToWait = 180

$now = get-date

$logFile = 'results-' + $now.Day.ToString() + $now.Month.ToString() + $now.Year.ToString() + '.txt'

'[' + $now.ToString() + '] Starting management of disks' | Out-File $logFile

try {

    foreach ($serviceName in $services) {

        "Stopping $serviceName service" | Out-File -Append $logFile

        $service = Stop-Service $serviceName -PassThru -Force

        if ( $service -ne $null ) {

            if ( $service.Status -ne 'Stopped' ) {

                throw "Could not stop $serviceName. Aborting..."

            } else {

                "$serviceName was stopped successfully" | Out-File -Append $logFile

            }

        }

    }

    "Defragmenting drives" | Out-File -Append $logFile
    "Defragmenting drive C:" | Out-File -Append $logFile

    defrag c: -v 2>&1 | Out-File -Append $logFile

    "Defragmenting drive D:" | Out-File -Append $logFile

    defrag d: -v 2>&1 | Out-File -Append $logFile

    [array]::Reverse($services)

    foreach ($serviceName in $services) {

        "Starting $serviceName service" | Out-File -Append $logFile

        $service = Start-Service $serviceName -PassThru

        if ( $service -ne $null ) {

            if ( $service.Status -ne 'Running' ) {

                throw "Could not start $serviceName. Aborting..."

            } else {

                "$serviceName was started successfully" | Out-File -Append $logFile

            }

        }

        "Waiting $timeToWait seconds to give time to the process start correctly" | Out-File -Append $logFile

        Start-Sleep -Seconds $timeToWait

    }   

} catch {

    $error[0].exception | Out-File -Append $logFile

} finally {

}
