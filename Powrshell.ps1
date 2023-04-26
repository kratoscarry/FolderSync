# Script will sync $source_folder into $target_folder and delete non relevant files. 

param ($source_folder, $target_folder, $cleanup_target = "TRUE", $log_file = "sync.log")

function Write-Log {
    Param ([string]$log_string, [string]$log_level = "INFO")
    $time_stamp = (Get-Date).toString("dd-MM-yyyy HH:mm:ss")
    $log_message = "$time_stamp [$log_level] $log_string"
    Add-content $log_file -value $log_message
    if ($log_level = "INFO") {
        Write-Host $log_message
    }
    elseif ($log_level = "ERROR") {
        Write-Error $log_message
    }
    elseif ($log_level = "WARNING") {
        Write-Warning $log_message
    }
    else {
        Write-Error "Wrong log level: $log_level"
        exit 1
    }
}

if (!(Test-Path -Path $source_folder -PathType Container)) {
    Write-Log "Source folder doesn't exist: $source_folder" "ERROR"
    exit 1
}

if (Test-Path -Path $target_folder -PathType Leaf) {
    Write-Log"Target object is file. Can't create target folder with the same name: $target_folder" "ERROR"
    exit 1
}

$source_content = Get-ChildItem -Path $source_folder -Recurse
if ($null -eq $source_content) { 
    $source_content = [array]
}

$target_content = Get-ChildItem -Path $target_folder -Recurse
if ($null -eq $target_content) { 
    $target_content = [array]
}

Write-Log "*** Started syncing $source_folder into $target_folder ***"

$differences = Compare-Object -ReferenceObject $source_content -DifferenceObject $target_content


foreach ($difference in $differences) {
    if ($difference.SideIndicator -eq "<=") {
        $source_object_path = $difference.InputObject.FullName
        $target_object_path = $source_object_path.Replace($source_folder, $target_folder)
        if (Test-Path -Path $source_object_path -PathType Leaf) {
            $hash_source_file = (Get-FileHash $source_object_path -Algorithm SHA256).Hash
            if (Test-Path -Path $target_object_path -PathType Leaf) {
                $hash_target_file = (Get-FileHash $target_object_path -Algorithm SHA256).Hash
            }
            else {
                $hash_target_file = $null
            }
            if ( $hash_source_file -ne $hash_target_file ) {
                Write-Log "Copied file $source_object_path into $target_object_path"
		
                Copy-Item -Path $source_object_path -Destination $target_object_path
            }
            else {
                Write-Log "Same file, will not sync $source_object_path into $target_object_path"
            }
        }
        elseif (Test-Path -Path $target_object_path -PathType Container) {
            Write-Log "Folder already exists, will not sync $source_object_path into $target_object_path"
        }
        else {
            Write-Log "Synced folder $source_object_path into $target_object_path"
            Copy-Item -Path $source_object_path -Destination $target_object_path
        }        
    }
    elseif (($difference.SideIndicator -eq "=>") -and $cleanup_target -eq "TRUE") {
        $target_object_path = $difference.InputObject.FullName
        $source_object_path = $target_object_path.Replace($target_folder, $source_folder)
        if (!(Test-Path -Path $source_object_path) -and (Test-Path -Path $target_object_path)) {
            Remove-Item -Path $target_object_path -Recurse -Force
            Write-Log "Removed $target_object_path from $target_folder"
        }
    }
}
Write-Log "*** Ended syncing $source_folder into $target_folder ***"