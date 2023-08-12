#pre-reqs - App registered, env variables populated #TODO put in check for these things before script runs.

#variables 
$csvPath = 'C:\temp\templatefornewuser-v1.csv'
$RandomPasswordLength = 10

Function TrimImportData($newUser) {
    $fields = ($user | Get-Member -MemberType NoteProperty).Name 
    foreach ($field in $fields) {
        $user.$field = $($user.$field).trim()
    Return $user
    }
}

#TODO Update this function so it generates using middle name if not unique the first time before falling back to manually entering.
function GenerateUniqueMailNickname($user, $allUsers) {
    #Makes MailNickname in format of j.smith
    $suggestedMailnickname = "$($user.FirstName.ToCharArray()[0]).$($user.lastName)"
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

#TODO MAKE FUNCTION TO VALIDATE PASSWORD MEETS TENANTS REQUIREMENTS, pass either the entered one from input or the randomly generated one before applying to user object.


#! MAIN ACTIVITIY
$azureADConnection = ConnectAzureAD -tenantID $env:AutoMikeTenantID -appID $env:AutoMikeAppId -certThumbprint $env:AutoMikeAADCertThumbprint
$allUsers = Get-AzureADUser -All:$true
$DefaultDomain = ($DefaultDomain = Get-AzureADDomain | Where-Object {$_.IsDefault -eq $true}).Name

#data inputs 
#TODO Create ability to take data from json object as well as CSV. - start with csv though
$newUsers = Import-Csv -Path $csvPath
$newUsers = $newUsers | Where-Object {![String]::IsNullOrEmpty($_)}


#Prepare data 
$newUsers = foreach ($user in $newUsers) {
    TrimImportData -newUser $user
    #Checks required fields are populated, if empty script will generate for you.
    if ([String]::IsNullOrEmpty($user.MailNickname)) {
        $user.MailNickname = (GenerateUniqueMailNickname -user $user -allUsers $allUsers).MailNickname
    }

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

    $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    if (![String]::IsNullOrEmpty($user.Password)) {
        $PasswordProfile.Password = $($user.Password)
    } else {
        $PasswordProfile.Password = GenerateRandomPassword -length $RandomPasswordLength
    }
    $user.Password = $PasswordProfile
}


#!  $requiredFields = @('AccountEnabled', 'PasswordProfile', 'MailNickname', 'DisplayName') - Just do a check for each of these.


#! TESTING
$user
Write-Host $user



#foreach required field ensure its populated, if not populated, auto generate. Will need a function for each

#TODO required fields as array, loop through each and make sure its populated, if not generate 

#add UPN if empty but verify it is unique, if not unique, try use middle initial if not empty, if it is then use more letters of first name until unique or manually enter.

#groups
#TODO get groups with membership above a certain threshold and suggest users get added to these if not already in provided groups list. Have threshold easy to adjust


#determine what data we already have vs what we need to create
#TODO create function to generate password with certain parameters
#TODO if UPN empty then get most commonly used domain in tenant, suggest a UPN with format of j.smith@domain, if not empty then verify the domain is valid before proceeding, if not valid change to the 
#TODO .onmicrosoft domain and advise user why this happened.


#Verification of data - may get combined with above.




#final user advise of what will be created, prompt for confirmation after review
#TODO create a flag somewhere that can enable zero touch run once error handling and validation are 100%



#TODO final output must log final details, get by checking the actual object where possible, where not use the submitted data (e.g. for password)
<# 
Things to output:
Firstname
Lastname
middlename
mailnickname
upn
accountenabled
Department
password - $PasswordProfile.Password / $user.password.passwordprofile.password ? Maybe - speculating until tested.
#>



<#TODO Things to Test:
Generate MailNickname works and properly checks if unique.
Fields are properly submitting themselves to functions when empty.
#>

