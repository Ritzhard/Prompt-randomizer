# Builds index.html from template.html + All_Prompts.txt.
# All the prompt splitting happens here, once, so the page only has to read a small, ready-made data block.
# Run it from this folder after you edit All_Prompts.txt:
#   powershell -ExecutionPolicy Bypass -File build.ps1
#
# Safety rule (applied to every character on the short quality line, i.e. minors, kids, the elderly and creatures):
#   - no body-shape tags and no revealing clothing tags in any section;
#   - revealing alternate outfits (swimsuits, bunny suits, lingerie...) are dropped;
#   - swimsuit-version entries are left out entirely;
#   - they are never used by true random.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object Text.UTF8Encoding($false)
$lines = [IO.File]::ReadAllLines((Join-Path $here 'All_Prompts.txt'), [Text.Encoding]::UTF8)

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
$BODY_RE = '^(?:.*breasts.*|.*flat chest.*|(adult|mature|young|teenage|old|middle-aged)( (man|woman|women|male|female))?|child|tall( female)?|short|.*petite.*|.*slender.*|slim.*|thin|.*athletic.*|.*muscular.*|.*toned.*|abs|.*curvy.*|.*wide hips.*|.*thick thighs.*|.*chubby.*|.*plump.*|fat|.*stocky.*|.*bulky.*|round|huge|.*giantess.*|.*masculine.*|malet|.*broad shoulders.*|.*androgynous.*|.*otoko no ko.*|.*-skinned.*|tan|.*pale skin.*|.*grey skin.*|(dark )?elf|.*monster.*|animal|.*robot.*|.*mecha musume.*|.*creature.*|ghost|were.*|.*beast.*|.*horse man.*|.*goblin.*|witch|.*raccoon.*|.*bear|.*wolf|.*chibi.*|.*armored rider.*|(fe)?male)$'
$COUNTS = @('solo, 1girl', 'solo, 1boy', 'solo, no humans', '2girls', '2boys', '1boy, 1girl', 'solo, 1other')

# Safety lists for short-quality-line characters.
$REVEAL = '(?i)\b(bikinis?|swimsuits?|swimwear|lingerie|underwear|panties|bra|cleavage|sideboob|underboob|navel|midriff|crop top|tube top|bandeau|leotard|playboy bunny|bunny suit|garter straps?|garter belt|see-through|sheer|revealing|backless|high slit|side slit|cutouts?|o-ring|fishnets?|latex|skin tight|bare (chest|stomach|midriff|back|thighs|hips?)|strapless|sarashi|chest wrap|body chain|belly chain|thigh straps?|loincloth|seductive|alluring|sultry|sexy|lewd|breasts?|flat chest|curvy|wide hips|thick thighs|voluptuous|crotch|hip vent|underbust|pelvic curtain|highleg|high-cut|abs|shirtless|topless)\b'
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

function SceneParts([string]$raw, [string]$gender){
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
  if ($gender -eq 'male' -and $body.Count -eq 0) { $body.Add('masculine') }
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

# --- read entries -------------------------------------------------------------------------
$records = New-Object Collections.Generic.List[string]
$part = 0; $skipped = 0; $leftOut = New-Object Collections.Generic.List[string]; $droppedOutfits = 0; $outfitCount = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^PART (\d+) \| ') { $part = [int]$Matches[1]; continue }
  if ($lines[$i] -match '^={20,}\s*$' -and $i + 1 -lt $lines.Count -and $lines[$i+1].IndexOf(' | ') -gt 0 -and $lines[$i+1] -notmatch '^[=#/\s]') {
    $f = @($lines[$i+1].Split('|') | ForEach-Object { $_.Trim() })
    $j = $i + 2; $notes = New-Object Collections.Generic.List[string]
    while ($j -lt $lines.Count -and $lines[$j] -notmatch '^={20,}\s*$') { $notes.Add($lines[$j].Trim()); $j++ }
    $k = $j + 1; $q = ''; $br = New-Object Collections.Generic.List[string]; $outfits = New-Object Collections.Generic.List[object]
    while ($k -lt $lines.Count -and $lines[$k].Trim() -ne '') {
      $ln = $lines[$k]
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
    if ($part -eq 1) { $skipped++; continue }   # custom prompts are hidden on the site
    $code = $f[0]
    $lite = $q.IndexOf('glossy skin') -lt 0

    $n = $br.Count; $sceneRaw = $br[$n-1]
    $boy = $sceneRaw -cmatch '\b(1boy|2boys)\b'; $girl = $sceneRaw -cmatch '\b(1girl|2girls)\b'
    $multi = ($boy -and $girl) -or ($sceneRaw -cmatch '\b(2girls|2boys)\b')
    $gender = if ($boy -and $girl) { 'other' } elseif ($boy) { 'male' } elseif ($girl) { 'female' } else { 'other' }
    $cut = $sceneRaw.IndexOf('Wada Arco style'); if ($cut -ge 0) { $sceneRaw = $sceneRaw.Substring(0, $cut) }
    $sp = SceneParts $sceneRaw $gender

    $oi = -1; for ($x = 1; $x -lt $n - 1; $x++) { if ($br[$x].StartsWith('(from')) { $oi = $x; break } }
    if ($oi -lt 0) { $oi = [Math]::Min(1, $n - 2) }
    $face = $br[0]; $tag = ''
    if ($part -ge 3 -and $face.StartsWith('(')) {
      $idx = $face.IndexOf(':1.1),')
      if ($idx -gt 0 -and $idx -lt 220) { $tag = $face.Substring(0, $idx + 6); $face = $face.Substring($idx + 6).Trim() }
    }
    $bodyParts = @(); for ($x = 1; $x -lt $oi; $x++) { $bodyParts += (TrimTail $br[$x]) }
    $toks = New-Object Collections.Generic.List[string]; foreach ($t in (SplitTop $br[$oi])) { $toks.Add($t) }
    $cam = New-Object Collections.Generic.List[string]
    if ($toks.Count -and $toks[0].StartsWith('(from')) { $cam.Add($toks[0]); $toks.RemoveAt(0) }
    while ($toks.Count -and $toks[0] -cmatch '^(looking |over the shoulder)') { $cam.Add($toks[0]); $toks.RemoveAt(0) }
    $camOnly = @($cam)
    $poseLine = if ($oi + 1 -lt $n - 1) { TrimTail $br[$oi + 1] } else { '' }
    if ($poseLine) { $cam.Add($poseLine) }
    $extra = @(); for ($x = $oi + 2; $x -lt $n - 1; $x++) { $extra += (TrimTail $br[$x]) }

    $faceS = TrimTail $face; $bodyS = $bodyParts -join ', '; $clothesS = TrimTail ($toks -join ', '); $poseS = $cam -join ', '; $btS = $sp[1]
    if ($lite) {
      # Swimsuit-version entries of minors are left out entirely.
      if ($tag -match $SWIM_ENTRY -or $clothesS -match $SWIM_ENTRY) { $leftOut.Add("$code $($f[1])"); continue }
      $faceS = Clean $faceS $code; $bodyS = Clean $bodyS $code; $clothesS = Clean $clothesS $code; $poseS = Clean $poseS $code; $btS = Clean $btS $code
      $extra = @($extra | ForEach-Object { Clean $_ $code } | Where-Object { $_ })
    }
    $outJ = New-Object Collections.Generic.List[string]
    foreach ($o in $outfits) {
      $oc = $o[1]; $op = $o[2]
      if ($lite) { if ($oc -match $OUTFIT_BAN -or $o[0] -match $OUTFIT_BAN) { $droppedOutfits++; continue }; $oc = Clean $oc $code; $op = Clean $op $code }
      $opFull = if ($op) { (@($camOnly) + @($op)) -join ', ' } else { '' }
      $outJ.Add('[' + (J $o[0]) + ',' + (J $oc) + ',' + (J $opFull) + ']'); $outfitCount++
    }

    $g = (@{ female = 0; male = 1; other = 2 })[$gender]
    $flags = ([int]$lite) + 2 * ([int]$multi)
    $rec = '[' + (@(
      (J $code), (J $f[1]), $part, (J $f[2]), $g, $flags, (J $tag), (J $faceS), (J $bodyS),
      (J $clothesS), (J $poseS), $sp[0], (J $btS), (J ($notes -join "`n")),
      ('[' + ((@($extra | ForEach-Object { J $_ })) -join ',') + ']'),
      ('[' + ($outJ -join ',') + ']')
    ) -join ',') + ']'
    $records.Add($rec)
  }
}

$json = '[' + ($records -join ",`n") + ']'
$template = [IO.File]::ReadAllText((Join-Path $here 'template.html'), [Text.Encoding]::UTF8)
if ($template.IndexOf('/*DATA*/') -lt 0) { throw 'template.html has no /*DATA*/ marker.' }
[IO.File]::WriteAllText((Join-Path $here 'index.html'), $template.Replace('/*DATA*/', $json), $utf8)
Write-Host ("index.html rebuilt: {0} characters, {1} alternate outfits ({2} custom prompts left out)." -f $records.Count, $outfitCount, $skipped)
Write-Host ("Safety rule: {0} swimsuit-version entries of minors left out, {1} revealing outfits dropped, revealing or body tags removed from {2} entries." -f $leftOut.Count, $droppedOutfits, $script:stripped.Count)
if ($leftOut.Count) { Write-Host ("  Left out: " + ($leftOut -join '; ')) }
