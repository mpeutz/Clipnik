# Stitches PNGs vertically into one sheet: tools\sheet.ps1 <out.png> <in1.png> <in2.png> ...
$out = $args[0]
$files = $args[1..($args.Count - 1)]
Add-Type -AssemblyName System.Drawing
$imgs = @()
foreach ($f in $files) { $imgs += [System.Drawing.Image]::FromFile((Resolve-Path $f).Path) }
$w = 0; $h = 0
foreach ($i in $imgs) { if ($i.Width -gt $w) { $w = $i.Width }; $h += $i.Height + 12 }
$bmp = New-Object System.Drawing.Bitmap ([int]$w), ([int]$h)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.Clear([System.Drawing.Color]::FromArgb(255, 120, 60, 140))
$y = 0
foreach ($i in $imgs) { $gfx.DrawImage($i, 0, $y); $y += $i.Height + 12 }
$gfx.Dispose()
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
foreach ($i in $imgs) { $i.Dispose() }
"sheet $w x $h -> $out exists=" + (Test-Path $out)
