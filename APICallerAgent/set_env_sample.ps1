$env:GEMINI_API_KEY = "AIxafjadljdaljaljdalljaljjlauVxZWV0"
$env:HF_TOKEN="hf_sjdlajdlajaljdasldsdadada Y"
$env:HTTPS_PROXY    = "http://proxy.mycompany.com:80"
$env:HTTP_PROXY     = "http://proxy.mycompany.com:80"

Write-Host "✅ Environment variables set:" -ForegroundColor Green
Write-Host "   GEMINI_API_KEY = $($env:GEMINI_API_KEY.Substring(0,8))..." -ForegroundColor Cyan
Write-Host "   HF_TOKEN       = $($env:HF_TOKEN.Substring(0,8))..." -ForegroundColor Cyan
Write-Host "   HTTPS_PROXY    = $env:HTTPS_PROXY" -ForegroundColor Cyan
Write-Host "   HTTP_PROXY     = $env:HTTP_PROXY" -ForegroundColor Cyan
