Import-Module ActiveDirectory

Function Set-DCAllowSystemOnlyChange
{
	param ([switch]$Set)
	if ($Set)
	{
		Write-Host "Checking is registry key is set to allow changes to AD System Only Attributes is set."
		$ntds_vals = (Get-Item HKLM:\System\CurrentControlSet\Services\NTDS\Parameters).GetValueNames()
		if ( $ntds_vals -eq "Allow System Only Change")
		{
			$kval = Get-ItemProperty HKLM:\System\CurrentControlSet\Services\NTDS\Parameters -name "Allow System Only Change"
			if ($kval -eq "1")
			{
		    	Write-Host "Allow System Only Change key is already set"    
			}
			else
			{
		    	Write-Host "Allow System Only Change key is not set"
				Write-Host "Creating key and setting value to 1"
				Set-ItemProperty HKLM:\System\CurrentControlSet\Services\NTDS\Parameters -name "Allow System Only Change" -Value 0 | Out-Null
			}
		}
		else
		{
			New-ItemProperty HKLM:\System\CurrentControlSet\Services\NTDS\Parameters -name "Allow System Only Change" -Value 1 -PropertyType "DWord" | Out-Null
		}
	}
	else
	{
		
		$ntds_vals = (Get-Item HKLM:\System\CurrentControlSet\Services\NTDS\Parameters).GetValueNames()
		if ( $ntds_vals -eq "Allow System Only Change")
		{
			Write-Host "Disabling Allow System Only Change Attributes on server"
			Set-ItemProperty HKLM:\System\CurrentControlSet\Services\NTDS\Parameters -name "Allow System Only Change" -Value 0 | Out-Null
		}
	}
}
Function Create-WMIFilters
{
	# Based on function from http://gallery.technet.microsoft.com/scriptcenter/f1491111-9f5d-4c83-b436-537eca9e8d94
    # Name,Query,Description
    $WMIFilters = @(
					('Virtual Machines', 'SELECT * FROM Win32_ComputerSystem WHERE Model = "Virtual Machine"', 'Hyper-V'),
                    ('Workstation 32-bit', 'Select * from WIN32_OperatingSystem where ProductType=1 Select * from Win32_Processor where AddressWidth = "32"', ''),
                    ('Workstation 64-bit', 'Select * from WIN32_OperatingSystem where ProductType=1 Select * from Win32_Processor where AddressWidth = "64"', ''),
                    ('Workstations', 'SELECT * FROM Win32_OperatingSystem WHERE ProductType = "1"', ''),
                    ('Domain Controllers', 'SELECT * FROM Win32_OperatingSystem WHERE ProductType = "2"', ''),
                    ('Servers', 'SELECT * FROM Win32_OperatingSystem WHERE ProductType = "3"', ''),
                    ('Windows 2000', 'select * from Win32_OperatingSystem where Version like "5.0%"', 'This is used to filter out GPOs that are only meant for Windows 2000 systems and should not apply to newer OSes eventhough Windows 2000 does not support WMI filtering'),
                    ('Windows XP', 'select * from Win32_OperatingSystem where (Version like "5.1%" or Version like "5.2%") and ProductType = "1"', ''),
                    ('Windows Vista', 'select * from Win32_OperatingSystem where Version like "6.0%" and ProductType = "1"', ''),
                    ('Windows 7', 'select * from Win32_OperatingSystem where Version like "6.1%" and ProductType = "1"', ''),
                    ('Windows Server 2003', 'select * from Win32_OperatingSystem where Version like "5.2%" and ProductType = "3"', ''),
                    ('Windows Server 2008', 'select * from Win32_OperatingSystem where Version like "6.0%" and ProductType = "3"', ''),
                    ('Windows Server 2008 R2', 'select * from Win32_OperatingSystem where Version like "6.1%" and ProductType = "3"', ''),
                    ('Windows Vista and Windows Server 2008', 'select * from Win32_OperatingSystem where Version like "6.0%" and ProductType<>"2"', ''),
                    ('Windows Server 2003 and Windows Server 2008', 'select * from Win32_OperatingSystem where (Version like "5.2%" or Version like "6.0%") and ProductType="3"', ''),
                    ('Windows 2000, XP and 2003', 'select * from Win32_OperatingSystem where Version like "5.%" and ProductType<>"2"', '')
                )

    $defaultNamingContext = (get-adrootdse).defaultnamingcontext 
    $configurationNamingContext = (get-adrootdse).configurationNamingContext 
    $msWMIAuthor = "Administrator@" + [System.DirectoryServices.ActiveDirectory.Domain]::getcurrentdomain().name
    
	Write-Host "Starting creation of WMI Filters:"
    for ($i = 0; $i -lt $WMIFilters.Count; $i++) 
    {
        $WMIGUID = [string]"{"+([System.Guid]::NewGuid())+"}"   
        $WMIDN = "CN="+$WMIGUID+",CN=SOM,CN=WMIPolicy,CN=System,"+$defaultNamingContext
        $WMICN = $WMIGUID
        $WMIdistinguishedname = $WMIDN
        $WMIID = $WMIGUID

        $now = (Get-Date).ToUniversalTime()
        $msWMICreationDate = ($now.Year).ToString("0000") + ($now.Month).ToString("00") + ($now.Day).ToString("00") + ($now.Hour).ToString("00") + ($now.Minute).ToString("00") + ($now.Second).ToString("00") + "." + ($now.Millisecond * 1000).ToString("000000") + "-000"

        $msWMIName = $WMIFilters[$i][0]
        $msWMIParm1 = $WMIFilters[$i][2] + " "
        $msWMIParm2 = "1;3;10;" + $WMIFilters[$i][1].Length.ToString() + ";WQL;root\CIMv2;" + $WMIFilters[$i][1] + ";"

        $Attr = @{"msWMI-Name" = $msWMIName;"msWMI-Parm1" = $msWMIParm1;"msWMI-Parm2" = $msWMIParm2;"msWMI-Author" = $msWMIAuthor;"msWMI-ID"=$WMIID;"instanceType" = 4;"showInAdvancedViewOnly" = "TRUE";"distinguishedname" = $WMIdistinguishedname;"msWMI-ChangeDate" = $msWMICreationDate; "msWMI-CreationDate" = $msWMICreationDate}
        $WMIPath = ("CN=SOM,CN=WMIPolicy,CN=System,"+$defaultNamingContext)
    	
		Write-Host "Adding WMI Filter for: $msWMIName"
        New-ADObject -name $WMICN -type "msWMI-Som" -Path $WMIPath -OtherAttributes $Attr | Out-Null
    }
	Write-Host "Finished adding WMI Filters"
}

Set-DCAllowSystemOnlyChange -Set
Create-WMIFilters
Set-DCAllowSystemOnlyChange 