#pre-reqs - App registered, env variables populated #TODO put in check for these things before script runs.

#variables 
$csvPath = 'C:\temp\templatefornewuser-v1.csv'


#functions #TODO remove this comment
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

#! MAIN ACTIVITIY
$azureADConnection = ConnectAzureAD -tenantID $env:AutoMikeTenantID -appID $env:AutoMikeAppId -certThumbprint $env:AutoMikeAADCertThumbprint
$allUsers = Get-AzureADUser -All:$true


#data inputs 
#TODO Create ability to take data from json object as well as CSV. - start with csv though
$newUsers = Import-Csv -Path $csvPath
$newUsers = $newUsers | Where-Object {![String]::IsNullOrEmpty($_)}


#Prepare data 
#Trims any leading or trailing blank spaces in inputs.
$newUsers = foreach ($user in $newUsers) {
    TrimImportData -newUser $user
    #Checks required fields are populated, if empty script will generate one for you.
    if ([String]::IsNullOrEmpty($user.MailNickname)) {
        $user.MailNickname = (GenerateUniqueMailNickname -user $user -allUsers $allUsers).MailNickname
    }
    
}


#!  $requiredFields = @('AccountEnabled', 'PasswordProfile', 'MailNickname', 'DisplayName') - Just do a check for each of these.


#! TESTING
Write-Host $user



#foreach required field ensure its populated, if not populated, auto generate. Will need a function for each

#TODO required fields as array, loop through each and make sure its populated, if not generate 

#add UPN if empty but verify it is unique, if not unique, try use middle initial if not empty, if it is then use more letters of first name until unique.

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




<#TODO Things to Test:
Generate MailNickname works and properly checks if unique.
Fields are properly submitting themselves to functions when empty.
#>

