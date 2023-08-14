#pre-reqs - App registered, env variables populated #TODO put in check for these things before script runs.

#variables 
$csvPath = 'C:\temp\templatefornewuser-v1.csv'
$RandomPasswordLength = 10

Function TrimImportData($newUser) {
    $fields = ($user | Get-Member -MemberType NoteProperty).Name 
    foreach ($field in $fields) {
        $user.$field = $($user.$field).trim()
    }
    Return $user
}

#TODO Update this function so it generates using middle name if not unique the first time before falling back to manually entering.
#TODO don't manually enter, its messy when running in bulk, just try two fallbacks then add to error
function GenerateUniqueMailNickname($user, $allUsers) {
    #Makes MailNickname in format of j.smith
    $suggestedMailnickname = "$($user.GivenName.ToCharArray()[0]).$($user.Surname)"
    if ($allUsers.MailNickname -notcontains $suggestedMailnickname) {
        Return @{
            MailNickname = $suggestedMailnickname
        }
    } else {
        $unique = $false
        while ($unique -eq $false) {
            $suggestedMailnickname = Read-Host "The MailNickname $($suggestedMailnickname) is not unique or too long, please enter a new one."
            if ($suggestedMailnickname.ToCharArray().Count -lt 64) {
                $unique = $allUsers.MailNickname -notcontains $suggestedMailnickname
            } else {
                Write-Warning "$($suggestedMailnickname) is too long, enter a name less than 64 Characters."
            }
        }
    }
    return @{
        MailNickname = $suggestedMailnickname
    }
}

function ConnectAzureAD($tenantID, $appID, $certThumbprint) {
    $connectedToAzureAD = $false
    if (($null -eq $connectedToAzureAD) -or ($connectedToAzureAD -eq $false)) {
        try {
            Get-AzureADTenantDetail
            $connectedToAzureAD = $true
        } catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] {
            Write-Host 'Connecting to AzureAD' -ForegroundColor Green
            try {
                Connect-AzureAD -TenantId $tenantID -ApplicationId $appID -CertificateThumbprint $certThumbprint
                $connectedToAzureAD = $true
            } catch {
                $connectedToAzureAD = $false
                Write-Warning "Could not connect to AzureAD. Exiting"
                Exit
            }   
        }
    }
    Return @{
        connectedToAzureAD = $connectedToAzureAD
    }
}
function GenerateRandomPassword($length) {

    $charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.ToCharArray()
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)
    $rng.GetBytes($bytes)
    $result = New-Object char[]($length)
  
    for ($i = 0 ; $i -lt $length ; $i++) {
        $result[$i] = $charSet[$bytes[$i]%$charSet.Length]
    }
 
    return -join $result
}

function CheckFieldIsUnique($field, $newUserField) {
    $allUsers.$field -notcontains $newUserField 
}

Function ValidateUpnDomain($upn, $allDomains) {
    $upnDomain = "$(($upn.split('@'))[1])"
    $domainIsValid = $allDomains.Name -contains $upnDomain 
    $domainIsValid
}

Function CreateNewAzureUser($user) { 
    $props = ($user | Get-Member | Where MemberType -eq NoteProperty).Name | Where {$_ -ne 'Password'} 
    $params = @{}
    $params['PasswordProfile'] = $user.Password 
    foreach ($prop in $props) {
        if (![String]::IsNullOrEmpty($user.$prop)) {
            $params[$prop] = $user.$prop
            }
        }  
    try { 
        New-AzureADUser @params -ErrorAction Stop
        $creationLog += "$($User.displayName) Successfully created."
    } Catch {
        $errorLog += "User $($User.displayName) could not be created: $($_.Exception)"
    }
}

#TODO MAKE FUNCTION TO VALIDATE PASSWORD MEETS TENANTS REQUIREMENTS, pass either the entered one from input or the randomly generated one before applying to user object.


#! MAIN ACTIVITIY
#TODO Create ability to take data from json object as well as CSV. - start with csv though
$newUsers = Import-Csv -Path $csvPath
$newUsers = $newUsers | Where-Object {![String]::IsNullOrEmpty($_)}
$azureADConnection = ConnectAzureAD -tenantID $env:AutoMikeTenantID -appID $env:AutoMikeAppId -certThumbprint $env:AutoMikeAADCertThumbprint
$allUsers = Get-AzureADUser -All:$true
$allDomains =  Get-AzureADDomain
$DefaultDomain = ($DefaultDomain = $allDomains | Where-Object {$_.IsDefault -eq $true}).Name
$creationLog = [System.Collections.ArrayList]@()
$errorLog = [System.Collections.ArrayList]@()
$invalidUsers = [System.Collections.ArrayList]@()

#Prepare data 
$newUsers = foreach ($user in $newUsers) {
    TrimImportData -newUser $user
    #Checks required fields are populated in CSV file, if empty script will generate for you.
    #MailNickname
    if ([String]::IsNullOrEmpty($user.MailNickname)) {
        $user.MailNickname = (GenerateUniqueMailNickname -user $user -allUsers $allUsers).MailNickname
    } 
    #AccountEnabled
    if (![String]::IsNullOrEmpty($user.AccountEnabled)) {
        #If not specified or can't parse input assume true.
        try {
            $user.AccountEnabled = [System.Convert]::ToBoolean($user.AccountEnabled)
        } catch {
            $user.AccountEnabled = $true 
        }
    } else {
        $user.AccountEnabled = $true
    }
    #Password Profile
    $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    if (![String]::IsNullOrEmpty($user.Password)) {
        $PasswordProfile.Password = $($user.Password)
    } else {
        $PasswordProfile.Password = GenerateRandomPassword -length $RandomPasswordLength
    }
    $user.Password = $PasswordProfile
    #DisplayName
    if ([String]::IsNullOrEmpty($user.DisplayName)) {
        $user.DisplayName = "$($user.GivenName) $($user.Surname)"
    }
    if (!(CheckFieldIsUnique -field "DisplayName" -newUserField $user.DisplayName)) {
        $errorLog += "User with display name $($user.displayName) already exists."
        $invalidUsers += $user
    }
    #UPN
    #Suggest a upn in the format of j.smith@primarydomain if not entered in inputs.
    if ([String]::IsNullOrEmpty($user.UserPrincipalName)) {
        $user.UserPrincipalName = "$($user.GivenName.ToCharArray()[0]).$($user.Surname)@$($DefaultDomain)"
    }
    if (!(ValidateUpnDomain -upn $user.UserPrincipalName -allDomains $allDomains)) {
        $errorLog += "The UPN $($user.UserPrincipalName) supplied for $($user.GivenName) $($user.Surname) is not a valid UPN for this tenant"
        $invalidUsers += $user
    } elseif (!(CheckFieldIsUnique -field "UserPrincipalName" -newUserField $user.UserPrincipalName)) {
        $errorLog += "User with UserPrincipalName $($user.UserPrincipalName) already exists."
        $invalidUsers += $user
    }
    $user.UserPrincipalName = $user.UserPrincipalName -replace ' ','' 
}
$invalidUsers = $invalidUsers | Select-Object -Unique
$newUsers = $newUsers | Where-Object {$invalidUsers.UserPrincipalName -notcontains $_.UserPrincipalName} | Select-Object -Unique
#Creates the user
foreach ($user in $newUsers) {
    CreateNewAzureUser -user $user
}

#!  $requiredFields = @('AccountEnabled', 'PasswordProfile', 'MailNickname', 'DisplayName', 'UPN') - Just do a check for each of these.



#! NEXT - Creating output object CSV

#TODO required fields as array, loop through each and make sure its populated, if not generate 
#TODO final output must log final details, get by checking the actual object where possible, where not use the submitted data (e.g. for password) - want this to be a csv file created from a custom PSObject
<# 
Things to output:
GivenName
Surname
middlename
mailnickname
upn
accountenabled
Department
password - $PasswordProfile.Password / $user.password.passwordprofile.password ? Maybe - speculating until tested.

When outputting to logs, add everything to an arraylist first, then output the lot rather than writing to disk each time, this will quicker.
#>


