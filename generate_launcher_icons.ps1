Add-Type -AssemblyName System.Drawing

$logoPath = "e:\Mani dev\Simple_ADVT\simple_advt_app\assets\images\logo_hd.png"
$resDir = "e:\Mani dev\Simple_ADVT\simple_advt_app\android\app\src\main\res"

$densities = @{
    "mipmap-mdpi"    = 48
    "mipmap-hdpi"    = 72
    "mipmap-xhdpi"   = 96
    "mipmap-xxhdpi"  = 144
    "mipmap-xxxhdpi" = 192
}

$logo = [System.Drawing.Bitmap]::FromFile($logoPath)

function Create-RoundedRectanglePath([float]$x, [float]$y, [float]$width, [float]$height, [float]$radius) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $radius * 2
    $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    $path.AddArc($x + $width - $diameter, $y, $diameter, $diameter, 270, 90)
    $path.AddArc($x + $width - $diameter, $y + $height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($x, $y + $height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

foreach ($density in $densities.Keys) {
    $size = $densities[$density]
    $targetDir = Join-Path $resDir $density
    if (!(Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    # 1. Standard Squircle Launcher Icon
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $radius = [float]($size * 0.22)
    $path = Create-RoundedRectanglePath 1.0 1.0 ([float]($size - 2)) ([float]($size - 2)) $radius
    $whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.FillPath($whiteBrush, $path)

    # Subtle border
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(20, 79, 70, 229), 1)
    $g.DrawPath($pen, $path)

    # Draw logo centered
    $logoSize = [int]($size * 0.70)
    $offset = [int](($size - $logoSize) / 2)
    $g.DrawImage($logo, $offset, $offset, $logoSize, $logoSize)

    $launcherPath = Join-Path $targetDir "ic_launcher.png"
    $bmp.Save($launcherPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $g.Dispose()
    $bmp.Dispose()

    # 2. Round Launcher Icon
    $bmpRound = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gRound = [System.Drawing.Graphics]::FromImage($bmpRound)
    $gRound.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gRound.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gRound.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $gRound.Clear([System.Drawing.Color]::Transparent)

    $gRound.FillEllipse($whiteBrush, 1.0, 1.0, [float]($size - 2), [float]($size - 2))
    $gRound.DrawEllipse($pen, 1.0, 1.0, [float]($size - 2), [float]($size - 2))
    $gRound.DrawImage($logo, $offset, $offset, $logoSize, $logoSize)

    $roundPath = Join-Path $targetDir "ic_launcher_round.png"
    $bmpRound.Save($roundPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $gRound.Dispose()
    $bmpRound.Dispose()
    $whiteBrush.Dispose()
    $pen.Dispose()
    $path.Dispose()
}

$logo.Dispose()
Write-Host "ANDROID_LAUNCHER_ICONS_GENERATED_SUCCESS"
