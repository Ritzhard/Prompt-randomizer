# Builds index.html from template.html + All_Prompts.txt (Danbooru tags only) + All_Prompts_Creative.txt (descriptive).
# All the prompt splitting happens here, once, so the page only has to read a small, ready-made data block.
# The page gets both versions of every prompt and a "Danbooru tags only" switch.
# Run it from this folder after the prompt files change:
#   powershell -ExecutionPolicy Bypass -File build.ps1
#
# Safety rule (applied in both versions to every character on the short quality line, i.e. minors, kids,
# the elderly and creatures):
#   - no body-shape tags and no revealing clothing tags in any section;
#   - revealing alternate outfits (swimsuits, bunny suits, lingerie...) are dropped;
#   - swimsuit-version entries are left out entirely;
#   - they are never used by true random.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object Text.UTF8Encoding($false)
$danLines = [IO.File]::ReadAllLines((Join-Path $here 'All_Prompts.txt'), [Text.Encoding]::UTF8)
$crePath = Join-Path $here 'All_Prompts_Creative.txt'
$creLines = @(); if (Test-Path $crePath) { $creLines = [IO.File]::ReadAllLines($crePath, [Text.Encoding]::UTF8) }

# --- helpers (these mirror what the page used to do in the browser) ---------------------------
function TrimTail([string]$t){ ($t.Trim() -replace '[,\s]+$', '') }
function SplitTop([string]$s){
  $out = New-Object Collections.Generic.List[string]; $depth = 0; $cur = New-Object Text.StringBuilder
  for ($i = 0; $i -lt $s.Length; $i++) {
    $c = $s[$i]
    if ($c -eq '\' -and $i + 1 -lt $s.Length) { [void]$cur.Append($c).Append($s[$i+1]); $i++; continue }
    if ($c -eq '(') { $depth++ } elseif ($c -eq ')') { $depth = [Math]::Max(0, $depth - 1) }
    if ($c -eq ',' -and $depth -eq 0) { $t = $cur.ToString().Trim(); if ($t) { $out.Add($t) }; [void]$cur.Clear() }
    else { [void]$cur.Append($c) }
  }
  $t = $cur.ToString().Trim(); if ($t) { $out.Add($t) }
  ,$out
}
# Body-type tags that survive in the last section; everything else there (scenery, lighting, framing) is dropped.
$BODY_RE = '^(?:.*breasts.*|.*flat chest.*|(adult|mature|young|teenage|old|middle-aged)( (man|woman|women|male|female))?|child|tall( (fe)?male)?|short|skinny|manly|male focus|dark skin|fat man|.*petite.*|.*slender.*|slim.*|thin|.*athletic.*|.*muscular.*|.*toned.*|abs|.*curvy.*|.*wide hips.*|.*thick thighs.*|.*chubby.*|.*plump.*|fat|.*stocky.*|.*bulky.*|round|huge|.*giantess.*|.*masculine.*|.*broad shoulders.*|.*androgynous.*|.*otoko no ko.*|.*-skinned.*|tan|.*pale skin.*|.*grey skin.*|(dark )?elf|.*monster.*|animal|.*robot.*|.*mecha musume.*|.*creature.*|ghost|were.*|.*beast.*|.*horse man.*|.*goblin.*|witch|.*raccoon.*|.*bear|.*wolf|.*chibi.*|.*armored rider.*|(fe)?male)$'
$COUNTS = @('solo, 1girl', 'solo, 1boy', 'solo, no humans', '2girls', '2boys', '1boy, 1girl', 'solo, 1other')

# Safety lists for short-quality-line characters (descriptive words and their Danbooru tags).
$REVEAL = '(?i)\b(bikinis?|swimsuits?|swimwear|lingerie|underwear|panties|bra|cleavage|sideboob|underboob|navel|midriff|crop top|tube top|bandeau|leotard|playboy bunny|bunny suit|garter straps?|garter belt|see-through|sheer|revealing|backless|high slit|side slit|cutouts?|o-ring|fishnets?|latex|skin tight|bare (chest|stomach|midriff|back|thighs|hips?)|strapless|sarashi|chest wrap|body chain|belly chain|thigh straps?|loincloth|seductive|alluring|sultry|sexy|lewd|breasts?|flat chest|curvy|wide hips|thick thighs|voluptuous|crotch|hip vent|underbust|pelvic curtain|highleg|high-cut|abs|shirtless|topless|stomach|pectorals|toned|thighs|nipples|areolae?|ass|butt crack|pantyshot|upskirt|cameltoe|thong|skindentation|groin)\b'
# The section after the body features starts with the camera group: (straight-on), (from front), (from side)...
$CAM_RE = '^\((from [a-z]+|straight-on|facing viewer)'
# A revealing alternate outfit is dropped whole; a swimsuit-version entry (tag or outfit says swimsuit) is left out whole.
$OUTFIT_BAN = '(?i)\b(bikinis?|swimsuits?|swimwear|lingerie|underwear|leotard|bunny|playboy|negligee|race queen)\b'
$SWIM_ENTRY = '(?i)\b(swimsuits?|swimwear)\b'
$script:stripped = @{}
function Clean([string]$s, [string]$code){
  $kept = New-Object Collections.Generic.List[string]
  foreach ($t in (SplitTop $s)) {
    if ($t.StartsWith('(') -and $t.EndsWith(')')) {
      $inner = New-Object Collections.Generic.List[string]
      foreach ($u in (SplitTop ($t.Substring(1, $t.Length - 2)))) { if ($u -match $REVEAL) { $script:stripped[$code] = 1 } else { $inner.Add($u) } }
      if ($inner.Count) { $kept.Add('(' + ($inner -join ', ') + ')') }
    } elseif ($t -match $REVEAL) { $script:stripped[$code] = 1 } else { $kept.Add($t) }
  }
  $kept -join ', '
}

function SceneParts([string]$raw, [string]$gender, [string]$maleFallback){
  $flat = New-Object Collections.Generic.List[string]
  foreach ($t in (SplitTop $raw)) {
    if ($t.StartsWith('(') -and $t.EndsWith(')')) { foreach ($u in (SplitTop ($t.Substring(1, $t.Length - 2)))) { $flat.Add($u.Trim()) } }
    else { $flat.Add($t.Trim()) }
  }
  $low = @($flat | ForEach-Object { ($_.ToLower() -replace ':[\d.]+$', '') })
  $has = { param($w) $low -ccontains $w }
  if (& $has 'no humans') { $cnt = 2 } elseif (& $has '2girls') { $cnt = 3 } elseif (& $has '2boys') { $cnt = 4 }
  elseif ((& $has '1boy') -and (& $has '1girl')) { $cnt = 5 } elseif (& $has '1other') { $cnt = 6 }
  elseif ($gender -eq 'male') { $cnt = 1 } else { $cnt = 0 }
  $body = New-Object Collections.Generic.List[string]; $seen = @{}
  for ($i = 0; $i -lt $flat.Count; $i++) {
    if (-not $flat[$i]) { continue }
    $bare = $low[$i] -creplace "^[a-z .'-]+: ", ''
    if ($bare -cmatch $BODY_RE -and -not $seen.ContainsKey($low[$i])) { $seen[$low[$i]] = 1; $body.Add(($flat[$i] -replace ':[\d.]+$', '')) }
  }
  if ($gender -eq 'male' -and $body.Count -eq 0) { $body.Add($maleFallback) }
  @($cnt, ($body -join ', '))
}
function J([string]$s){
  if ($null -eq $s) { return '""' }
  $sb = New-Object Text.StringBuilder; [void]$sb.Append('"')
  foreach ($ch in $s.ToCharArray()) {
    switch ($ch) {
      '"'  { [void]$sb.Append('\"') } '\'  { [void]$sb.Append('\\') }
      "`n" { [void]$sb.Append('\n') } "`r" { } "`t" { [void]$sb.Append('\t') }
      '<'  { [void]$sb.Append('<') }
      default { if ([int]$ch -lt 32) { [void]$sb.Append(('\u{0:x4}' -f [int]$ch)) } else { [void]$sb.Append($ch) } }
    }
  }
  [void]$sb.Append('"'); $sb.ToString()
}
function JArr($items){ '[' + ((@($items) | ForEach-Object { J $_ }) -join ',') + ']' }

# --- read one prompt file into entries -------------------------------------------------------
function ReadEntries([string[]]$src, [string]$maleFallback){
  $res = New-Object Collections.Generic.List[object]
  $part = 0
  for ($i = 0; $i -lt $src.Count; $i++) {
    if ($src[$i] -match '^PART (\d+) \| ') { $part = [int]$Matches[1]; continue }
    if (-not ($src[$i] -match '^={20,}\s*$' -and $i + 1 -lt $src.Count -and $src[$i+1].IndexOf(' | ') -gt 0 -and $src[$i+1] -notmatch '^[=#/\s]')) { continue }
    $f = @($src[$i+1].Split('|') | ForEach-Object { $_.Trim() })
    $j = $i + 2; $notes = New-Object Collections.Generic.List[string]
    while ($j -lt $src.Count -and $src[$j] -notmatch '^={20,}\s*$') { $notes.Add($src[$j].Trim()); $j++ }
    $k = $j + 1; $q = ''; $br = New-Object Collections.Generic.List[string]; $outfits = New-Object Collections.Generic.List[object]
    while ($k -lt $src.Count -and $src[$k].Trim() -ne '') {
      $ln = $src[$k]
      if ($ln.StartsWith('(masterpiece')) { $q = $ln }
      elseif ($ln.StartsWith('BREAK ')) { $br.Add($ln.Substring(6).Trim()) }
      elseif ($ln.StartsWith('OUTFIT ')) {
        $p = @($ln.Substring(7).Split('|') | ForEach-Object { $_.Trim() })
        if ($p.Count -ge 2 -and $p[0] -and $p[1]) { $outfits.Add(@($p[0], (TrimTail $p[1]), $(if ($p.Count -ge 3) { TrimTail $p[2] } else { '' }))) }
      }
      $k++
    }
    $i = $k
    if ($br.Count -lt 3) { continue }

    $n = $br.Count; $sceneRaw = $br[$n-1]
    $boy = $sceneRaw -cmatch '\b(1boy|2boys)\b'; $girl = $sceneRaw -cmatch '\b(1girl|2girls)\b'
    $multi = ($boy -and $girl) -or ($sceneRaw -cmatch '\b(2girls|2boys)\b')
    $gender = if ($boy -and $girl) { 'other' } elseif ($boy) { 'male' } elseif ($girl) { 'female' } else { 'other' }
    $cut = $sceneRaw.IndexOf('Wada Arco style'); if ($cut -ge 0) { $sceneRaw = $sceneRaw.Substring(0, $cut) }
    $sp = SceneParts $sceneRaw $gender $maleFallback

    $oi = -1; for ($x = 1; $x -lt $n - 1; $x++) { if ($br[$x] -match $CAM_RE) { $oi = $x; break } }
    if ($oi -lt 0) { $oi = [Math]::Min(1, $n - 2) }
    $face = $br[0]; $tag = ''
    if ($part -ge 3 -and $face.StartsWith('(')) {
      $idx = $face.IndexOf(':1.1),')
      if ($idx -gt 0 -and $idx -lt 220) { $tag = $face.Substring(0, $idx + 6); $face = $face.Substring($idx + 6).Trim() }
    }
    $bodyParts = @(); for ($x = 1; $x -lt $oi; $x++) { $bodyParts += (TrimTail $br[$x]) }
    $toks = New-Object Collections.Generic.List[string]; foreach ($t in (SplitTop $br[$oi])) { $toks.Add($t) }
    $cam = New-Object Collections.Generic.List[string]
    if ($toks.Count -and $toks[0] -match $CAM_RE) { $cam.Add($toks[0]); $toks.RemoveAt(0) }
    while ($toks.Count -and $toks[0] -cmatch '^(looking |over the shoulder)') { $cam.Add($toks[0]); $toks.RemoveAt(0) }
    $camOnly = @($cam)
    $poseLine = if ($oi + 1 -lt $n - 1) { TrimTail $br[$oi + 1] } else { '' }
    if ($poseLine) { $cam.Add($poseLine) }
    $extra = @(); for ($x = $oi + 2; $x -lt $n - 1; $x++) { $extra += (TrimTail $br[$x]) }

    $res.Add([pscustomobject]@{
      part = $part; code = $f[0]; name = $f[1]; group = $f[2]; notes = ($notes -join "`n")
      lite = ($q.IndexOf('glossy skin') -lt 0); gender = $gender; multi = $multi
      tag = $tag; face = (TrimTail $face); body = ($bodyParts -join ', '); clothes = (TrimTail ($toks -join ', ')); pose = ($cam -join ', ')
      cnt = $sp[0]; bt = $sp[1]; extra = $extra; camOnly = $camOnly; outfits = $outfits
    })
  }
  return ,$res
}
function CleanEntry($v, [string]$code){
  $v.face = Clean $v.face $code; $v.body = Clean $v.body $code; $v.clothes = Clean $v.clothes $code
  $v.pose = Clean $v.pose $code; $v.bt = Clean $v.bt $code
  $v.extra = @($v.extra | ForEach-Object { Clean $_ $code } | Where-Object { $_ })
}

# --- pair the two versions and write the records ---------------------------------------------
$dan = ReadEntries $danLines 'male focus'
$cre = ReadEntries $creLines 'masculine'
$creBy = @{}; foreach ($ce in $cre) { $creBy["$($ce.part)|$($ce.code)"] = $ce }

$records = New-Object Collections.Generic.List[string]
$skipped = 0; $leftOut = New-Object Collections.Generic.List[string]; $droppedOutfits = 0; $outfitCount = 0
$paired = 0; $unpaired = New-Object Collections.Generic.List[string]
foreach ($d in $dan) {
  if ($d.part -eq 1) { $skipped++; continue }   # custom prompts are hidden on the site
  $code = $d.code
  $ce = $creBy["$($d.part)|$code"]
  # Both versions come from the same file, so they line up; if one ever does not, the page shows the Danbooru one.
  if ($ce -and ($ce.outfits.Count -ne $d.outfits.Count -or @($ce.extra).Count -ne @($d.extra).Count)) { $ce = $null }
  if (-not $ce) { $unpaired.Add("$code $($d.name)") }
  if ($d.lite) {
    # Swimsuit-version entries of minors are left out entirely.
    if ($d.tag -match $SWIM_ENTRY -or $d.clothes -match $SWIM_ENTRY -or ($ce -and $ce.clothes -match $SWIM_ENTRY)) { $leftOut.Add("$code $($d.name)"); continue }
    CleanEntry $d $code; if ($ce) { CleanEntry $ce $code }
  }
  $outD = New-Object Collections.Generic.List[string]; $outC = New-Object Collections.Generic.List[string]
  for ($x = 0; $x -lt $d.outfits.Count; $x++) {
    $od = $d.outfits[$x]; $oc = $null; if ($ce) { $oc = $ce.outfits[$x] }
    if ($d.lite -and ($od[0] -match $OUTFIT_BAN -or $od[1] -match $OUTFIT_BAN -or ($oc -and $oc[1] -match $OUTFIT_BAN))) { $droppedOutfits++; continue }
    $dc = $od[1]; $dp = $od[2]; if ($d.lite) { $dc = Clean $dc $code; $dp = Clean $dp $code }
    $dpFull = if ($dp) { (@($d.camOnly) + @($dp)) -join ', ' } else { '' }
    $outD.Add('[' + (J $od[0]) + ',' + (J $dc) + ',' + (J $dpFull) + ']'); $outfitCount++
    if ($ce) {
      $cc = $oc[1]; $cpz = $oc[2]; if ($d.lite) { $cc = Clean $cc $code; $cpz = Clean $cpz $code }
      $cpFull = if ($cpz) { (@($ce.camOnly) + @($cpz)) -join ', ' } else { '' }
      $outC.Add('[' + (J $cc) + ',' + (J $cpFull) + ']')
    }
  }
  $g = (@{ female = 0; male = 1; other = 2 })[$d.gender]
  $flags = ([int]$d.lite) + 2 * ([int]$d.multi)
  $fields = @(
    (J $code), (J $d.name), $d.part, (J $d.group), $g, $flags, (J $d.tag), (J $d.face), (J $d.body),
    (J $d.clothes), (J $d.pose), $d.cnt, (J $d.bt), (J $d.notes), (JArr $d.extra), ('[' + ($outD -join ',') + ']')
  )
  if ($ce) {
    $paired++
    $fields += ('[' + (@((J $ce.face), (J $ce.body), (J $ce.clothes), (J $ce.pose), (J $ce.bt), (JArr $ce.extra), ('[' + ($outC -join ',') + ']')) -join ',') + ']')
  }
  $records.Add('[' + ($fields -join ',') + ']')
}

$json = '[' + ($records -join ",`n") + ']'
$template = [IO.File]::ReadAllText((Join-Path $here 'template.html'), [Text.Encoding]::UTF8)
if ($template.IndexOf('/*DATA*/') -lt 0) { throw 'template.html has no /*DATA*/ marker.' }
[IO.File]::WriteAllText((Join-Path $here 'index.html'), $template.Replace('/*DATA*/', $json), $utf8)
Write-Host ("index.html rebuilt: {0} characters ({1} with the creative version too), {2} alternate outfits ({3} custom prompts left out)." -f $records.Count, $paired, $outfitCount, $skipped)
if ($unpaired.Count) { Write-Host ("  Danbooru version only: " + ($unpaired -join '; ')) }
Write-Host ("Safety rule: {0} swimsuit-version entries of minors left out, {1} revealing outfits dropped, revealing or body tags removed from {2} entries." -f $leftOut.Count, $droppedOutfits, $script:stripped.Count)
if ($leftOut.Count) { Write-Host ("  Left out: " + ($leftOut -join '; ')) }
