# -----------------------------
# Install AD Domain Services
# -----------------------------
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# -----------------------------
# Terraform injected variables
# -----------------------------
$domainName  = "${domain_name}"
$netbiosName = "${netbios_name}"
$plainPass   = "${ad_password}"

$secpasswd = ConvertTo-SecureString $plainPass -AsPlainText -Force

# -----------------------------
# Install new AD Forest
# -----------------------------
Install-ADDSForest `
    -DomainName $domainName `
    -DomainNetbiosName $netbiosName `
    -SafeModeAdministratorPassword $secpasswd `
    -Force:$true

# Wait a bit for AD services to initialize
Start-Sleep -Seconds 60

# -----------------------------
# Create Organizational Units
# -----------------------------
$dcPath = "DC=" + ($domainName -replace "\.",",DC=")
New-ADOrganizationalUnit -Name "Users" -Path $dcPath -ProtectedFromAccidentalDeletion $false
New-ADOrganizationalUnit -Name "Groups" -Path $dcPath -ProtectedFromAccidentalDeletion $false

# -----------------------------
# Create Groups
# -----------------------------
$groups = @("Group1","Group2","Group3","Group4","Group5")
foreach ($grp in $groups) {
    New-ADGroup -Name $grp -GroupScope Global -Path ("OU=Groups," + $dcPath)
}

# -----------------------------
# Create Users
# -----------------------------
$users = @(
    @{Name="Alice Johnson"; Sam="alicej"; Email="alicej@$domainName"},
    @{Name="Bob Smith"; Sam="bobsmith"; Email="bobsmith@$domainName"},
    @{Name="Charlie Lee"; Sam="charliel"; Email="charliel@$domainName"},
    @{Name="Dana White"; Sam="danaw"; Email="danaw@$domainName"},
    @{Name="Evan Brown"; Sam="evanb"; Email="evanb@$domainName"}
)

$UserPassword = ConvertTo-SecureString "Welcome123!" -AsPlainText -Force

foreach ($user in $users) {
    New-ADUser -Name $user.Name -SamAccountName $user.Sam -UserPrincipalName $user.Email `
        -AccountPassword $UserPassword -Enabled $true -Path ("OU=Users," + $dcPath)
}

# -----------------------------
# Assign Users to Groups
# -----------------------------
for ($i=0; $i -lt $users.Count; $i++) {
    $userSam = $users[$i].Sam
    $groupName = $groups[$i]
    Add-ADGroupMember -Identity $groupName -Members $userSam
}