$defaultCertStore = 'Cert:\CurrentUser\My'
$defaultRootPath = 'c:\temp\Certs\'
$appName = 'AutoMike'

Function CreateSSLCert([String]$subject, [String]$CertLocation, [String]$dnsname) {
    #currently uses default validity of 1 year, can change if required.
    $NewCert = New-SelfSignedCertificate -Subject $subject -CertStoreLocation $CertLocation -DnsName $dnsname -KeyExportPolicy Exportable -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -NotAfter $(Get-Date).AddYears(1)
    Return @{
        Subject        = $NewCert.Subject
        Thumbprint     = $NewCert.Thumbprint
        DisplayName    = $NewCert.Subject.Replace('CN=', '')
        CertFullName   = "$($defaultCertStore)\$($NewCert.Thumbprint)"
        certThumbprint = $NewCert.Thumbprint
    }
}

Function ExpCert([String]$cert, [String]$FileName, $password, [String]$rootpath) {
    Export-Certificate -Cert $cert -Type Cert -FilePath "$($rootpath)$($FileName).cer"
    $password = ConvertTo-SecureString -String $password -Force -AsPlainText
    Export-PfxCertificate -Password $password -Cert $cert -FilePath "$($rootpath)$($FileName).pfx"
    Write-Host "Certs have been exported to $($rootpath)" -ForegroundColor Green
    Return @{
        pfxFilepath = "$($rootpath)$($FileName).pfx"
    }
}

Function RegisterApp([String]$displayName, [String]$identifierUris, [String]$CustomKeyIdentifier, [String]$pfxPath, $certPW) {
    $app = New-AzureADApplication -DisplayName $displayName -IdentifierUris $identifierUris
    $pw = ConvertTo-SecureString -String $certPW -Force -AsPlainText
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate("$($pfxPath)", $pw)
    $keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())
    #Uploads app Cert to Azure
    New-AzureADApplicationKeyCredential `
        -ObjectId $app.ObjectId `
        -StartDate (Get-Date) `
        -EndDate $((Get-Date).AddYears(1).AddDays(-1)) `
        -Type AsymmetricX509Cert `
        -Usage Verify `
        -Value $keyValue
        #Don't know why I need this at this stage. -CustomKeyIdentifier $CustomKeyIdentifier `

    return @{
        AppId = $app.AppId
    }
}

Function CreateSP($appId, $userAdminstratorRoleID) {
    Add-AzureADDirectoryRoleMember -ObjectId $userAdminstratorRoleID -RefObjectId (New-AzureADServicePrincipal -AppId $appId).ObjectId
}

Function CreateFolderIfNotExist($path) {
    if  ((test-path $path) -eq $false) {
        [System.Collections.ArrayList]$patharr = $path.split('\') | Where-Object {![String]::IsNullOrEmpty($_)}
        $index = ($patharr.Count -1)
        $folderName = $patharr[$index]
        $patharr.RemoveAt($index)
        $rootpath = $patharr -join('\')
        New-Item -Path $rootpath -Name $folderName -ItemType Directory
    } 
}

#actual running of script here
#Env Variable created called certPW

#Check if env variable is populated
If (![Environment]::getEnvironmentVariable('certPW')) {
    Write-Host "You have not created your certPW env variable, please do so before running this script, do this by running [Environment]::setEnvironmentVariable('certPW','<password>','Machine') as admin"
    exit
}
#checks if AzureAD Module is installed and loaded. - TEST
$moduleinstalled = Get-Module -Name AzureAD
if (!$moduleinstalled) {
    Write-Host 'AzureAD Module is not installed, installing now.'
    try {
        Install-Module -Name AzureAD -Force -AllowClobber -Scope CurrentUser
        Import-Module AzureAD
    }
    catch {
        Write-Host 'Azure AD Module was not found and could not be installed automatically. Exiting'
        Exit
    }
}

#Initial check to see if already connected.
try {
    Get-AzureADTenantDetail
    $connected = $true
} catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] {
    Write-Host 'Connecting to AzureAD' -ForegroundColor Green
    $connected = $false
}

#if not connected, attempts to log in interactively.
$retries = 0
while (($connected -ne $true) -and ($retries -lt 4)) {
    try {
        $tenantDetails = Get-AzureADTenantDetail
        if ($null -ne $tenantDetails) {
            $connected = $true
        }
    }
    catch {
        try {
            Connect-AzureAD 
        }
        catch {
            $retries = $retries + 1
            if ($retries -gt 3) {
                Write-Host 'Max retries reached. Exiting' -ForegroundColor Red
            } else {
                Write-Host "Can`'t connect to Azure, retry attempt $($retries) of 3" -ForegroundColor Green
            }
        }  
    }
}    


if ($connected -eq $false) {
    Write-Host "Failed to connect to Azure-Ad"
    Exit
} else {
    $tenantDetails = Get-AzureADTenantDetail
    Write-Host "Adding app registration to tenant - $($tenantDetails.DisplayName)" -ForegroundColor Green
}

Write-Host "Using $([Environment]::getEnvironmentVariable('certPW')) as cert password." -ForegroundColor Green
#Creates cert folder if it doesn't already exist.
try {
    CreateFolderIfNotExist -path $defaultRootPath
}
catch {
    Write-Host "Could not create folder $path" -ForegroundColor Red
}
#Create Cert
Write-Host 'Creating Cert'  -ForegroundColor Green
$localAppCert = CreateSSLCert -subject "$($appName)-app" -CertLocation $defaultCertStore -dnsname "$($appName).com.au"
#Export cert
Write-Host 'Exporting Cert'  -ForegroundColor Green
$certExport = ExpCert -cert $localAppCert.CertFullName -FileName "$($appName)-app-cert" -password "$($env:certPW)" -rootpath $defaultRootPath
#register app and load cert
Write-Host 'Registering App and uploading cert'  -ForegroundColor Green
$newapp = RegisterApp -displayName $appName -identifierUris (Get-AzureADDomain | Where-Object {$_.Name -like "*.onmicrosoft.com"}).Name -pfxPath $certExport.pfxFilepath -certPW "$($env:certPW)"
#Create SP
Write-Host 'Creating Service Principal' -ForegroundColor Green
CreateSP -appId $newapp.AppId -userAdminstratorRoleID (Get-AzureADDirectoryRole | Where-Object { $_.DisplayName -eq 'User Administrator' }).ObjectId
#test and verify.


#temp write hosts 
Write-Host "Thumbprint - $($localappcert.certThumbprint)" -ForegroundColor Green
Write-Host "AppID - $($newapp.AppId)" -ForegroundColor Green
Write-Host "Tenant ID $($tenantDetails.ObjectId)" -ForegroundColor Green
#set env variables to use in other scripts.


# env variables to add:
# thumbprint
# AppID
# TenantID

#use a foreach to add each variable so I can just add to list when needed.

Disconnect-AzureAD 
