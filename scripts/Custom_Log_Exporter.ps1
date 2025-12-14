# --- CONFIGURAÇÃO ---
$API_KEY = "API_KEY_From_ipgeolocation.io"
$LogFile = "C:\ProgramData\failed_rdp.log"
# --------------------

Write-Host "A MONITORIZAR RDP" -ForegroundColor Cyan

if (-not (Test-Path $LogFile)) { New-Item -Path $LogFile -ItemType File -Force | Out-Null }

while ($true) {
    # Search for event ID 4625
    $Events = Get-WinEvent -LogName Security -FilterXPath "*[System[(EventID=4625)]] and *[System[TimeCreated[timediff(@SystemTime) <= 2000]]]" -ErrorAction SilentlyContinue

    if ($Events) {
        foreach ($Event in $Events) {
            $xml = [xml]$Event.ToXml()
            # extract IP e Username
            $IpAddress = $xml.Event.EventData.Data | Where-Object {$_.Name -eq "IpAddress"} | Select-Object -ExpandProperty "#text"
            $UserName = $xml.Event.EventData.Data | Where-Object {$_.Name -eq "TargetUserName"} | Select-Object -ExpandProperty "#text"

            if ($IpAddress -and $IpAddress.Length -gt 5 -and $IpAddress -ne "-") {
                
                $url = "https://api.ipgeolocation.io/ipgeo?apiKey=$API_KEY&ip=$IpAddress"
                try {
                    $response = Invoke-RestMethod -Uri $url -Method Get
                    
                    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $Country = $response.country_name
                    $Lat = $response.latitude
                    $Long = $response.longitude
                    
                    if ($Lat -and $Long) {
                        $LogEntry = "latitude:$Lat,longitude:$Long,destination_host:HONEYPOT,username:$UserName,source_host:$IpAddress,state:$response.state_prov,country:$Country,label:$Country - $IpAddress (User: $UserName),timestamp:$TimeStamp"
                        
                        $LogEntry | Out-File $LogFile -Append -Encoding utf8
                        Write-Host "ALERTA: $IpAddress ($Country) tentou entrar como '$UserName'" -ForegroundColor Red
                    }
                }
                catch {}
            }
        }
    }
    Start-Sleep -Seconds 1
}