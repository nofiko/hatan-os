# HATAN OS - إزالة خلفية الشعار (شفافية PNG)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Logo = Join-Path $Root "themes\icons\logo.png"

if (-not (Test-Path $Logo)) {
    Write-Host "لم يُعثر على: $Logo" -ForegroundColor Red
    exit 1
}

Write-Host "[HATAN OS] جاري إزالة الخلفية..." -ForegroundColor Cyan

python -c @"
from rembg import remove
from PIL import Image
from io import BytesIO
import numpy as np

path = r'$Logo'
with open(path, 'rb') as f:
    data = remove(f.read())
img = Image.open(BytesIO(data)).convert('RGBA')
arr = np.array(img)
ys, xs = np.where(arr[:, :, 3] > 10)
x0, y0, x1, y1 = xs.min(), ys.min(), xs.max(), ys.max()
pad = 8
x0 = max(0, x0 - pad); y0 = max(0, y0 - pad)
x1 = min(arr.shape[1] - 1, x1 + pad); y1 = min(arr.shape[0] - 1, y1 + pad)
img.crop((x0, y0, x1 + 1, y1 + 1)).save(path, optimize=True)
print('تم حفظ شعار بخلفية شفافة:', path, img.size)
"@

if ($LASTEXITCODE -ne 0) {
    Write-Host "تثبيت rembg: pip install `"rembg[cpu]`"" -ForegroundColor Yellow
    exit 1
}

& "$Root\scripts\sync-assets.ps1"
