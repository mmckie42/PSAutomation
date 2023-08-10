#Generate Cert
$defaultCertStore = 'Cert:\CurrentUser\My'
$defaultRootPath = 'c:\temp\Certs\'
$appName = 'AutoMike-test'


Function CreateSSLCert([String]$subject, [String]$CertLocation, [String]$dnsname) {
    #currently uses default validity of 1 year, can change if required.
    $NewCert = New-SelfSignedCertificate -Subject $subject -CertStoreLocation $CertLocation -KeyExportPolicy Exportable -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -NotAfter $(Get-Date).AddYears(1)
    Return @{
        Subject        = $NewCert.Subject
        Thumbprint     = $NewCert.Thumbprint
        DisplayName    = $NewCert.Subject.Replace('CN=', '')
        CertFullName   = "$($defaultCertStore)\$($NewCert.Thumbprint)"
        certThumbprint = $NewCert.Thumbprint
    }
}

Function ExportCert([String]$cert, [String]$FileName, $password, [String]$rootpath) {
    Export-Certificate -Cert $cert -Type Cert -FilePath "$($rootpath)$($FileName).cer"
    $password = ConvertTo-SecureString -String $password -Force -AsPlainText
    Export-PfxCertificate -Password $password -Cert $cert -FilePath "$($rootpath)$($FileName).pfx"
    Write-Host "Certs have been exported to $($rootpath)"
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
#Pre-Reqs
#Env Variable created called certPW

#FIX THE BELOW ENV VAR STUFF
#Check if env variable is populated
If (![Environment]::getEnvironmentVariable('certPW')) {
    Write-Host "You have not created your certPW env variable, please do so before running this script, do this by running [Environment]::setEnvironmentVariable('certPW','<password>','User') as admin"
    exit
}
Write-Host "Using $([Environment]::getEnvironmentVariable('certPW')) as cert password." 
try {
    CreateFolderIfNotExist -path $defaultRootPath
} catch {
    Write-Host "Could not create folder $path"
}
$appcert = CreateSSLCert -subject "$($appName)-app" -CertLocation $defaultCertStore
ExportCert -cert $appcert.CertFullName -FileName "$($appName)-app-cert" -password "$($env:certPW)" -rootpath $defaultRootPath
Write-Host "Password set to $($env:certPW)"



