$ErrorActionPreference = 'Stop'

$toolsDir = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"

# Remove shim
Uninstall-BinFile -Name 'shelldone'

# Remove installed files
$itemsToRemove = @('shelldone', 'lib', 'hooks', 'completions', 'VERSION')
foreach ($item in $itemsToRemove) {
  $path = Join-Path $toolsDir $item
  if (Test-Path $path) {
    Remove-Item -Recurse -Force $path
  }
}

Write-Host 'shelldone has been uninstalled.' -ForegroundColor Yellow
