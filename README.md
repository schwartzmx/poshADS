# poshADS
PowerShell wrapper for manipulating Alternate Data Streams.

Inspired by a short video by [DrapsTV](https://www.youtube.com/watch?v=qBrFW3gpjpM&spf), and a python wrapper [pyADS](https://github.com/RobinDavid/pyADS/) for manipulating ADS on Windows.

Beginning with PowerShell 3.0, Microsoft made interacting with the ADS of a file much easier as paths with `:` were very hard to interact with since it is an illegal character in a filename.  This is a small wrapper for manipulating and retrieving alternate data streams of a given File.

### Importing the Module
Copy the module folder to one of the paths in your `PSModulePath` below.
```PowerShell
$env:PSModulePath -replace ";","`r`n"
```
And then just import.
```PowerShell
Import-Module PoshADS
Get-Help PoshADS
```

### Examples
```PowerShell
#List ADS for File
Get-Item VisibleFile.txt | PoshADS

#Remove all hidden data streams from file
PoshADS VisibleFile.txt -RemoveAll

#Add contents of a file as a hidden ADS to the host file 
Get-Item VisibleFile.txt | PoshADS -AddFile 'C:\HiddenContent.txt'

#Extract all ADS to a given output directory
PoshADS VisibleFile.txt -Extract -OutputDirectory "C:\ADSOutput_VisibleFile"

```

```PowerShell
Import-Module PoshADS

# Load all files in the given directory to the hostfile as alternate data streams
$hostFile = 'C:\Users\pschwartz\host.txt'
$files = Get-ChildItem C:\Users\pschwartz\hide -Recurse

ForEach ($f in $files) {
    PoshADS $hostFile -AddFile $($f.FullName) | out-null
}

# List the ADS
PoshADS $hostFile
```

```PowerShell
Import-Module PoshADS

# Remove all "downloaded from internet" data streams
Get-ChildItem C:\Users\pschwartz\Downloads -Recurse | PoshADS -RemoveStream "Zone.Identifier" | Out-Null

Get-ChildItem C:\Users\pschwartz\Downloads -Recurse | PoshADS
```

###License
MIT