param (
    [string]$RepoOwner = "2vlad5",      # Владелец репозитория
    [string]$RepoName = "anejkaWalpersUpdater",           # Название репозитория
    [string]$Branch = "main",                   # Ветка (main/master)
    [string]$ConfigFile = "dates.cvs",        # Файл с диапазонами (в репозитории)
    [string]$ConfigFormat = "csv"              # Формат: "json" или "csv"
)

function Set-Wallpaper {
    param ([string]$ImagePath)
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    public static void SetWallpaper(string path) {
        SystemParametersInfo(20, 0, path, 3);
    }
}
'@
    [Wallpaper]::SetWallpaper($ImagePath)
}

function Show-Message {
    Add-Type -AssemblyName System.Windows.Forms
    [void][System.Windows.Forms.MessageBox]::Show(
        "Вы получили новое обновление!",
        "Обновление обоев",
        0,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}

function Download-File {
    param (
        [string]$Url,
        [string]$OutputPath
    )
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -ErrorAction Stop
        return $true
    } catch {
        Write-Error "Не удалось загрузить файл: $_"
        return $false
    }
}

# Формируем URL для загрузки конфигурационного файла
$configUrl = "https://github.com/$RepoOwner/$RepoName/raw/$Branch/$ConfigFile"
$configPath = "$env:TEMP\$ConfigFile"

# Скачиваем конфигурационный файл
Write-Host "Загружаем конфигурацию из GitHub: $configUrl"
if (-not (Download-File -Url $configUrl -OutputPath $configPath)) {
    Write-Error "Невозможно загрузить конфигурацию. Проверка дат отменена."
    exit 1
}

# Читаем конфигурацию
try {
    if ($ConfigFormat -eq "json") {
        $dateConfigs = Get-Content $configPath | ConvertFrom-Json
    } elseif ($ConfigFormat -eq "csv") {
        $dateConfigs = Import-Csv $configPath
    } else {
        Write-Error "Неподдерживаемый формат: $ConfigFormat. Используйте 'json' или 'csv'."
        exit 1
    }
} catch {
    Write-Error "Ошибка при разборе конфигурации: $_"
    exit 1
}

# Текущая дата
$today = Get-Date

# Ищем подходящий диапазон
$applicable = $dateConfigs | Where-Object {
    $start = [DateTime]::Parse($_.start)
    $end = [DateTime]::Parse($_.end)
    $today -ge $start -and $today -le $end
}

if ($applicable) {
    $wallpaperName = $applicable[0].wallpaperName
    Write-Host "Найден подходящий диапазон. Загружаем обои: $wallpaperName"

    # URL обоев
    $wallpaperUrl = "https://github.com/$RepoOwner/$RepoName/raw/$Branch/$wallpaperName"
    $wallpaperPath = "$env:TEMP\$wallpaperName"

    # Скачиваем обои
    if (Download-File -Url $wallpaperUrl -OutputPath $wallpaperPath) {
        # Устанавливаем обои
        Set-Wallpaper -ImagePath $wallpaperPath
        Show-Message
        Write-Host "Обои успешно установлены: $wallpaperPath"
    } else {
        Write-Host "Не удалось скачать обои."
    }
} else {
    Write-Host "Сегодня нет запланированных обновлений."
}

# Очищаем временные файлы (опционально)
# Remove-Item $configPath -Force
# Remove-Item $wallpaperPath -Force