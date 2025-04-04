function TestForAdmin {
    # Check to see if current user is an admin. Bail if not. 
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ( -not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) ) {
        Write-Error -Message "This script requires administrative privileges. Exiting..." -ErrorId 1 -ErrorAction Stop
    }
}

function Remove-Profiles {

    <#
        .DESCRIPTION
        Remove-Profiles is a tool for listing or removing profiles on a Windows host.
        - When run without the "-Remove" flag, it will simply list all profiles on the host and label them with either "SKIP" or "TARGET".
          - "SKIP" items are profiles that are considered "essential".
          - "TARGET" items are profiles that would be removed by the cmdlet when run with the "-Remove" flag.
        - When run with the "-Remove" flag, all "non-essential" profiles will be deleted from the host.

        .PARAMETER Remove
        A failsafe. Activates the removal feature. Without it, the script is run in list-only mode.

        .PARAMETER Keep
        An array of usernames to keep. The following accounts are kept by default: "Administrator", "Default", "Public", "sshd", "OIT Help Desk"

        .EXAMPLE
        Remove-Profiles
        [NOTICE] Running in List Mode. To delete profiles, please re-run and specify the '-Remove' flag.
        [TARGET]: anw0044 (C:\Users\anw0044)
        [TARGET]: lls0016 (C:\Users\lls0016)
        [TARGET]: kjs0011 (C:\Users\kjs0011)
        [SKIP]: admin-yrt0002

        .EXAMPLE
        Remove-Profiles -Remove
        [NOTICE] Running in List Mode. To delete profiles, please re-run and specify the '-Remove' flag.
        [REMOVED]: anw0044 (C:\Users\anw0044)
        [REMOVED]: lls0016 (C:\Users\lls0016)
        [REMOVED]: kjs0011 (C:\Users\kjs0011)
        [SKIP]: admin-yrt0002

        .EXAMPLE
        Remove-Profiles -Remove -Keep "kjs0011"
        [NOTICE] Running in List Mode. To delete profiles, please re-run and specify the '-Remove' flag.
        [REMOVED]: anw0044 (C:\Users\anw0044)
        [REMOVED]: lls0016 (C:\Users\lls0016)
        [SKIP]: kjs0011
        [SKIP]: admin-yrt0002

        .LINK
        https://gitlab.uah.edu/systems/psprofilecleaner
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $Remove,

        # An array of additional profiles to keep.
        [Parameter()]
        [array]
        $Keep
    )

    # Get executing user's groups and display them:
    # Return ([ADSISearcher]"(sAMAccountName=$env:UserName)").FindOne().Properties.memberof

    # Check to see if current user is an admin. Bail if not. 
    TestForAdmin

    # Define essential profiles to keep. "Admin-" accounts are included by default.
    $essential_profiles = @(
        "Administrator", 
        "Default", 
        "Public",
        "sshd", 
        "OIT Help Desk"
    )

    # Add user-defined essential profiles as needed.
    if ( $Keep.count -gt 0 ) {
        foreach ( $item in $keep ) {
            $essential_profiles += $item
        }
    }

    function Test-IfEssential {
        param (
            [Parameter(
                Mandatory,
                Position = 0
            )]
            [string]
            $ProfileName
        )

        if ($essential_profiles -contains $ProfileName -or $ProfileName -imatch "admin-") {
            Return $true
        } else {
            Return $false
        }
    }

    if ( -not $Remove ) {
        Write-Host "[NOTICE] " -ForegroundColor Yellow -NoNewline
        Write-Host "Running in List Mode. To delete profiles, please re-run and specify the '-Remove' flag."
    }

    # Get the current logged-in user
    $current_user = (Get-WMIObject Win32_ComputerSystem).UserName -replace '.*\\'

    # Add the currently logged-in user to the exclusion list
    $essential_profiles += $current_user

    # Get all local user profiles
    $user_profiles = Get-WMIObject Win32_UserProfile | Where-Object { 
        $_.Special -eq $false -and $_.Loaded -eq $false
    }

    foreach ($profile in $user_profiles) {
        $profile_path = $profile.LocalPath
        $profile_name = $profile_path -replace 'C:\\Users\\', ''

        # Skip essential profiles
        if ( Test-IfEssential $profile_name ) {
            Write-Host "[SKIP]: $profile_name" -ForegroundColor DarkGray
            continue
        }

        # Remove the profile if Remove flag is specified. Otherwise list them.
        if ( $Remove ) {

            Write-Verbose "Removing profile: $profile_name ($profile_path)"
            try {
                $profile.Delete()
                Write-Host "[REMOVED]: $profile_name"
            }
            catch {
                Write-Host "[FAILED]: $profile_name - $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "[TARGET]: $profile_name ($profile_path)" -ForegroundColor Green
        }
    }

    if ( $Remove ) { 
        Write-Verbose "Non-essential user profiles cleanup complete."
    } else {
        Write-Host "Listing complete.`nWhen performing a removal, exclude essential profiles by specifying the 'Keep' parameter, along with an array of profile names to keep."
    }

}

Export-ModuleMember -Function * -Alias *