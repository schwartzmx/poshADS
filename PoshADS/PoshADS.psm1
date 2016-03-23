Function PoshADS {
    <#
    .SYNOPSIS
        List, extract, add, or remove alternate data streams from a given file in NTFS.
    .DESCRIPTION
        This function takes a [String] path to a file and can list, add, remove, and extract it's alternate data streams (ADS).
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
    [cmdletbinding(DefaultParameterSetName="F")]
    param (
        [Parameter(Mandatory=$True,
            Position=1,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            HelpMessage='<File> to list all alternate data streams from.',
            ParameterSetName='F'
        )]
        [Parameter(Mandatory=$True,
            Position=1,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            HelpMessage='<File> to extract alternate data streams from.',
            ParameterSetName='Ext'
        )]
        [Parameter(Mandatory=$True,
            Position=1,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            HelpMessage='<File> to add an alternate data stream to.',
            ParameterSetName='Add'
        )]
        [Parameter(Mandatory=$True,
            Position=1,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            HelpMessage='<File> to remove all alternate data streams from.',
            ParameterSetName='RA'
        )]
        [Parameter(Mandatory=$True,
            Position=1,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True,
            HelpMessage='<File> to remove an alternate data stream from.',
            ParameterSetName='RS'
        )]
        [Alias('F')]
        [String]$File,

        [Parameter(Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            HelpMessage='Extract all ADS from given <File>',
            ParameterSetName='Ext')]
        [Alias('E')]
        [Switch]$Extract,

        [Parameter(Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            HelpMessage='Add given file to ADS of <File>',
            ParameterSetName='Add')]
        [Alias('A')]
        [String]$AddFile,

        [Parameter(Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            HelpMessage='Remove all ADS from <File>',
            ParameterSetName='RA')]
        [Alias('RMA')]
        [Switch]$RemoveAll,

        [Parameter(Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            HelpMessage='Remove an ADS from <File>',
            ParameterSetName='RS')]
        [Alias('RMS')]
        [String]$RemoveStream,

        [Parameter(Mandatory=$False,
            ValueFromPipeline=$False,
            ValueFromPipelineByPropertyName=$False,
            HelpMessage='Output directory when extracting ADS files.',
            ParameterSetName='Ext')]
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
                $OutStreamName = $_.Stream -Replace ":",""

                If (-Not (Test-Path "$($Out.FullName)\$($File.Name)_$($OutStreamName)")) {
                    Write-Output "Extracting $($File.Name):$($_.Stream) to $($Out.FullName)\$($File.Name)_$($OutStreamName)..."
                    Get-Content $($File.FullName) -Stream "$Stream" | Add-Content "$($Out.FullName)\$($File.Name)_$($OutStreamName)"
                }
                Else {
                    Write-Output "The stream $($File.Name):$($_.Stream) has already been extracted to $($Out.FullName)\$($File.Name)_$($OutStreamName)."
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
                If(Retrieve-Streams -File $File | Where { $_.Stream -eq $($FileToAdd.Name) }) {
                    Write-Output "The stream $($File.Name):$($FileToAddName) already exists."
                }
                Else {
                    Write-Output "Adding stream $($File.Name):${FileToAddName}..."
                    Add-Content $($File.FullName) -Stream $($FileToAddName) -Value $(Get-Content $($FileToAdd.FullName))
                }
            }
            Catch {
                Write-Output "An error occured adding the file ${FileToAddName} to the ADS of file $($File.Name)."
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
                    Write-Output "Removing stream $($File.Name):${s}..."
                    Remove-Item $File -Stream $s
                }
            }
            Else {
                $Streams = Retrieve-Streams -File $File | Where { $_.Stream -ne ':$DATA' -And $_.Stream -eq "$Stream" }
                If ($Streams.Length -gt 0) {
                    # Ignore :$DATA, as it is the main stream i.e. the file’s primary contents.
                    $Streams | % {
                        $s = $_.Stream
                        Write-Output "Removing stream $($File.Name):${s}..."
                        Remove-Item $File -Stream $s
                    }
                }
                Else {
                    Write-Output "The stream $($File.Name):${Stream} does not exist."
                }
            }

        }

        #endregion FUNCTIONS

    }
    Process
    {
        $Vb = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
        $IsDirectory = Test-Path "$File" -PathType Container
        If (-Not $IsDirectory -And (Test-Path "$File" -PathType Leaf)) {
            $FileObject = Get-Item "$File"

            # Display all Streams on only File param pass or Verbose
            If ($PSBoundParameters.Count -eq 1 -Or $Vb) {
                Retrieve-Streams -File $FileObject -WriteOutput
                Write-Output ""
            }
        
            If ($AddFile) {
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
                    Write-Output "The specified output directory does not exist, creating it..."
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

                Extract-Streams -File $FileObject -Out $Out
            }

            If($RemoveAll) {
                Remove-Streams -File $FileObject
            }
            ElseIf($RemoveStream) {
                Remove-Streams -File $FileObject -Stream "$RemoveStream"
            }
        }
        Else {
            If (-Not $IsDirectory) {
                Write-Output "The File specified: $File could not be found."
            }
        }
    }
}
    


