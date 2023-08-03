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