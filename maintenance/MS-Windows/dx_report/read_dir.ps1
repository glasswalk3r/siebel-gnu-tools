Param(
[Parameter(Position=1, Mandatory=$True, ValueFromPipeline=$False)] [Object] $user
)

$total = ((Get-ChildItem -filter *.dx $user.outbox).Count)

if ( $total -eq $null ) {

    $total = 0

}

$user.totalOfDX = $total
$user