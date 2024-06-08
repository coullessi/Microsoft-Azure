Clear-Host
Write-Host "Getting the list of organizational units in the domain..." -ForegroundColor Yellow
$OUs = @()
    
$OUs += Get-ADOrganizationalUnit -Filter *

#$OUs | Format-Table Name, DistinguishedName -AutoSize

$adDomain = (Get-ADDomain).DNSRoot
if ($OUs.Count -eq 0) {
    Write-Host "No organizational units found. Exiting..." -ForegroundColor Yellow
    break
}
else {
    Write-Host -ForegroundColor Green "`nList of organizational units in the domain '$adDomain'"
    $ouNumbers = @()
    for ($i = 0; $i -lt $OUs.Count; $i++) {
        "$($i+1). $($OUs[$i])"
        $ouNumbers += $i + 1
    }
}

$arcServerOUs = @()
do {
    $ouNumber = Read-Host "`nSelect an organizational unit, e.g. 1, 2, 3."
    while ($ouNumber -notin $ouNumbers) {
        Write-Host "Enter a correct number. The number must be between 1 and $($ouNumbers.Count)" -ForegroundColor Yellow
        $ouNumber = Read-Host "Select an organizational unit, e.g. 1, 2, 3."
    }
    $arcServerOUs += $OUs[$ouNumber - 1]
    $selectedOU = $OUs[$ouNumber - 1]
    
    $OUs = $OUs | Where-Object { $_.DistinguishedName -ne $selectedOU.DistinguishedName }
    Write-Host "`nRemainng organizational units in the domain '$adDomain' to select from." -ForegroundColor Yellow

    $ouNumbers = @()
    for ($i = 0; $i -lt $OUs.Count; $i++) {
        "$($i+1). $($OUs[$i])"
        $ouNumbers += $i + 1
    }

    #$OUs | Format-Table Name, DistinguishedName -AutoSize
    $choice = Read-Host "Would you like to select another organizational unit to link the GPO to (Yes=Y / No=N)?"
    $choice = $choice.Trim('o', 'e', 's').ToUpper()
    while ($choice -notin "Y", "N") {
        Write-Host "Enter a correct answer. The answer must be Y or N" -ForegroundColor Yellow
        $choice = Read-Host "`nWould you like to select another organizational unit to link the GPO to (Yes=Y / No=N)?"
        $arcServerOUs += $OUs[$ouNumber - 1]
    }
    
    if ($choice -eq "N") {
        Write-Host "`nList of selected organizational units" -ForegroundColor Green
        $arcServerOUs.DistinguishedName
    }
    else {
        continue
    }
} while ($choice -eq "Y")
Write-host "`nExiting..."