$ErrorActionPreference = 'Stop'

$packageName = 'shelldone'
$version = '1.3.1'
$url = "https://github.com/nareshnavinash/shelldone/archive/refs/tags/v${version}.tar.gz"
$checksum = 'd37ab4c643709ed640da454b77907022036bf9851493b166cd8d793afb5a1007'
$checksumType = 'sha256'

$toolsDir = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"
$tempDir = Join-Path $env:TEMP "$packageName-install"

# Download and extract the tarball
$tarball = Join-Path $tempDir "shelldone-${version}.tar.gz"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

Get-ChocolateyWebFile -PackageName $packageName `
  -FileFullPath $tarball `
  -Url $url `
  -Checksum $checksum `
  -ChecksumType $checksumType

# Extract tarball (tar is available on Windows 10+)
& tar -xzf $tarball -C $tempDir

$extractedDir = Join-Path $tempDir "shelldone-${version}"

# Copy files to tools directory
Copy-Item -Path (Join-Path $extractedDir 'bin\shelldone') -Destination $toolsDir -Force
Copy-Item -Path (Join-Path $extractedDir 'lib') -Destination (Join-Path $toolsDir 'lib') -Recurse -Force
Copy-Item -Path (Join-Path $extractedDir 'hooks') -Destination (Join-Path $toolsDir 'hooks') -Recurse -Force
Copy-Item -Path (Join-Path $extractedDir 'completions') -Destination (Join-Path $toolsDir 'completions') -Recurse -Force
Copy-Item -Path (Join-Path $extractedDir 'VERSION') -Destination $toolsDir -Force

# Create shim for shelldone
Install-BinFile -Name 'shelldone' -Path (Join-Path $toolsDir 'shelldone')

# Clean up temp files
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue

Write-Host "shelldone $version installed successfully!" -ForegroundColor Green
Write-Host 'Add to your shell profile: eval "$(shelldone init bash)"' -ForegroundColor Cyan
