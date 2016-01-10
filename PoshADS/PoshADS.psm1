Function PoshADS {
    <#
    .SYNOPSIS
        List, extract, add, or remove alternate data streams from a given file in NTFS.
    .DESCRIPTION
        This function takes a FileSystem object and can list/alter it's alternate data streams (ADS).
    .PARAMETER File
        Host File to manipulate ADS.
        Example:
            $t = (Get-Item test.txt)
            -File $t  
    .PARAMETER Extract
        Extract all ADSes from the file
        Example:
            -Extract
    .PARAMETER AddFile
        Add an existing file as an ADS of a given host File
        Example:
            $new = (Get-Item newfile.txt)
            -Add $new
    .PARAMETER RemoveAll
        Remove all hidden ADS from given host File
        Example:
            -Remove
    .PARAMETER RemoveStream
        Remove a given named ADS from given host File
        Example:
            -RemoveStream 'hidden.txt'
    .PARAMETER OutputDirectory
        String path to a given output directory for extracting ADS from host File
        Example:
            -OutputDirectory "C:\Users\Phil\ADSOutputTestingDirectory"      
    .INPUTS
        Any File
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    .EXAMPLE
        #List ADS for File
        PoshADS C:\Users\Phil\SomeWordDoc.doc
    .EXAMPLE
        #List ADS for File
        Get-Item VisibleFile.txt | PoshADS
    .EXAMPLE
        #Remove all hidden data streams from file
        Get-Item VisibleFile.txt | PoshADS -RemoveAll
    .EXAMPLE
        #Add a file as a hidden ADS to the host file 
        $a = Get-Item HideContent.txt
        Get-Item VisibleFile.txt | PoshADS -AddFile $a
    .EXAMPLE
        #Extract ADS to an output directory
        Get-Item VisibleFile.txt | PoshADS -Extract -OutputDirectory "C:\Users\pschwartz\ADS"
    .FUNCTIONALITY
        General Command
    #>
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$True,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            HelpMessage='<File>')]
        [Alias('F')]
        [String]$File,

        [Parameter(Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            HelpMessage='Extract all ADS from given <File>')]
        [Alias('E')]
        [Switch]$Extract,

        [Parameter(Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            HelpMessage='Add given file to ADS of <File>')]
        [Alias('A')]
        [String]$AddFile,

        [Parameter(Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            HelpMessage='Remove all ADS from <File>')]
        [Alias('RMA')]
        [Switch]$RemoveAll,

        [Parameter(Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            HelpMessage='Remove an ADS from <File>')]
        [Alias('RMS')]
        [String]$RemoveStream,

        [Parameter(Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            HelpMessage='Output directory when extracting ADS files.')]
        [Alias('O')]
        [String]$OutputDirectory="ADSOutput"



    )
    Begin
    {
        #region FUNCTIONS

        # Retrieve all of the streams from the given file and format them with a custom object
        Function Retrieve-Streams {
            param (
                [System.IO.FileSystemInfo]$File,
                [Switch]$WriteOutput
            )

            $StreamsOutput = @()
            Get-Item $($File.FullName) -Stream * | % {
                $streamObject = New-Object PSObject
                $streamObject | Add-Member -MemberType NoteProperty -Name HostFile -Value ($File.Name)
                $streamObject | Add-Member -MemberType NoteProperty -Name Stream -Value ($($_.Stream))
                $streamObject | Add-Member -MemberType NoteProperty -Name Length -Value ($($_.Length))
                $StreamsOutput += $streamObject

                If ($WriteOutput) {
                    Write-Output $streamObject
                }
            }

            If (-Not $WriteOutput) {
                return $StreamsOutput
            }
        }

        # Extract streams from the given file to the output directory
        Function Extract-Streams {
            param (
                [System.IO.FileSystemInfo]$File,
                [System.IO.FileSystemInfo]$Out
            )

            Retrieve-Streams -File $File | % {
                $OutStreamName = $_.Stream -replace ":",""

                If (-Not (Test-Path "$($Out.FullName)\$($OutStreamName)")) {
                    Write-Output "Extracting ${File}:$($_.Stream) to $($Out.FullName)\$($_.Stream)..."
                    Get-Content $($File.FullName) -Stream "$Stream" | Add-Content "$($Out.FullName)\$($OutStreamName)"
                }
                Else {
                    Write-Output "The stream ${File}:$($_.Stream) has already been extracted to $($Out.FullName)\$($OutStreamName)."
                }
            }


        }

        # Add streams to a given file
        Function Add-Stream {
            param (
                [System.IO.FileSystemInfo]$File,
                [System.IO.FileSystemInfo]$FileToAdd
            )

            Try {
                $FileToAddName = $FileToAdd.Name
                If(Get-Item $File -Stream * | Where { $_.Stream -eq $($FileToAddName) }) {
                    Write-Output "The stream $($FileToAddName) already exists."
                }
                Else {
                    Write-Output "Adding stream ${File}:${FileToAddName}..."
                    Add-Content $($File.FullName) -Stream $($FileToAddName) -Value $(Get-Content $($FileToAdd.FullName))
                }
            }
            Catch {
                Write-Output "An error occured adding the file ${FileToAddName} to the ADS of file ${File}."
                Write-Error $_.Exception.Message
                Throw $_.Exception           
            }
        }

        # Remove streams from given File
        Function Remove-Streams {
            param(
                [System.IO.FileSystemInfo]$File,
                [String]$Stream=""
            )

            If (-Not $Stream) {
                # Ignore :$DATA, as it is the main stream i.e. the file’s primary contents.
                Retrieve-Streams -File $File | Where { $_.Stream -ne ':$DATA' } | % {
                    $s = $_.Stream
                    Write-Output "Removing data stream $s..."
                    Remove-Item $File -Stream $s
                }
            }
            Else {
                # Ignore :$DATA, as it is the main stream i.e. the file’s primary contents.
                Retrieve-Streams -File $File | Where { $_.Stream -ne ':$DATA' -And $_.Stream -eq "$Stream" } | % {
                    $s = $_.Stream
                    Write-Output "Removing data stream $s..."
                    Remove-Item $File -Stream $s
                }
            }

        }

        #endregion FUNCTIONS

    }
    Process
    {
        If (Test-Path $File) {
            $FileObject = Get-Item "$File"
            $FileName = $FileObject.Name

            Retrieve-Streams -File $FileObject -WriteOutput
        
            If ($AddFile) {
                Write-Output ""
                If (-Not (Test-Path $AddFile)) {
                    Write-Error "The file to add could not be found."
                    Break
                }
                Else {
                    $AddFileObject = Get-Item "$AddFile"
                    Add-Stream -File $FileObject -FileToAdd $AddFileObject
                }
            }

            If($Extract) {
                If (-Not (Test-Path "$OutputDirectory")) {
                    Write-Output "`r`nThe specified output directory does not exist, creating it..."
                    Try {
                        $Out = New-Item $OutputDirectory -ItemType Directory
                    }
                    Catch {
                        Write-Output "Creation of the output directory failed."
                        Write-Error $_.Exception.Message
                        Throw $_.Exception
                    }
                }
                Else {
                    $Out = Get-Item "$OutputDirectory"
                }

                Write-Output ""
                Extract-Streams -File $FileObject -Out $Out

            }

            If($RemoveAll) {
                Write-Output ""
                Remove-Streams -File $FileObject
            }
            ElseIf($RemoveStream) {
                Write-Output ""
                Remove-Streams -File $FileObject -Stream "$RemoveStream"
            }
        }
        Else {
            Write-Output "The File specified could not be found."
        }
    }
}
    


