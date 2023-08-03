#Generate Cert
$defaultCertStore = 'Cert:\CurrentUser\My'
$defaultRootPath = 'c:\temp\Certs\'
$appName = 'AutoMike'
$certThumbprint = ''

Function CreateSSCert([String]$subject, [String]$CertLocation) {
    $NewCert = New-SelfSignedCertificate -Subject $subject -CertStoreLocation $CertLocation
    Return @{
        Subject = $NewCert.Subject
        Thumbprint = $NewCert.Thumbprint
        DisplayName = $NewCert.Subject.Replace('CN=','')
        CertFullName = "$($defaultCertStore)\$($NewCert.Thumbprint)"
        certThumbprint = $NewCert.Thumbprint
    }
}

Function ExpCert([String]$cert, [String]$FileName, $password, [String]$rootpath) {
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

#Check if env variable is populated
If (![Environment]::getEnvironmentVariable('certPW')) {
    Write-Host "You have not created your certPW env variable, please do so before running this script, do this by running [Environment]::getEnvironmentVariable('certPW','<password>','Machine') as admin"
    exit
}
Write-Host "Using $([Environment]::getEnvironmentVariable('certPW')) as cert password." 
try {
    CreateFolderIfNotExist -path $defaultRootPath
} catch {
    Write-Host "Could not create folder $path"
}
ExpCert -cert $(CreateSSCert -subject 'test' -CertLocation $defaultCertStore).CertFullName -FileName 'testcert' -password "$($env:certPW)" -rootpath $defaultRootPath

#add code to import the cert pfx file, delete it after its confirmed that its added and store the thumbprint in an env variable
