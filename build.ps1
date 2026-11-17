# Rebuilds index.html from template.html and All_Prompts.txt.
# Run it from this folder after you edit All_Prompts.txt:
#   powershell -ExecutionPolicy Bypass -File build.ps1
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object Text.UTF8Encoding($false)
$template = [IO.File]::ReadAllText((Join-Path $here 'template.html'), [Text.Encoding]::UTF8)
$data = [IO.File]::ReadAllText((Join-Path $here 'All_Prompts.txt'), [Text.Encoding]::UTF8)
if ($data -match '(?i)</script') { throw 'All_Prompts.txt contains "</script", which would break the page.' }
[IO.File]::WriteAllText((Join-Path $here 'index.html'), $template.Replace('/*DATA*/', "`n" + $data), $utf8)
Write-Host "index.html rebuilt."
