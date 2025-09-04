####################### 
function Get-Type {
   param([string]$Type)
   $types = @(
       'System.Boolean', 'System.Byte[]', 'System.Byte', 'System.Char', 'System.DateTime',
       'System.Decimal', 'System.Double', 'System.Guid', 'System.Int16', 'System.Int32',
       'System.Int64', 'System.Single', 'System.UInt16', 'System.UInt32', 'System.UInt64'
   )
   if ($types -contains $Type) {
       return $Type
   }
   return 'System.String'
}
 
####################### 
<# 
.SYNOPSIS
Creates a DataTable based on an objects properties. 

.DESCRIPTION 
Converts objects into a Systam.Data.DataTable, making it easy to manipulate, export, or use object data in .Net-compatible systems

.INPUTS 
Object 
    Any object can be piped to Out-DataTable 
.OUTPUTS 
   System.Data.DataTable 
.EXAMPLE 
$dt = Get-psdrive| Out-DataTable 
This example creates a DataTable from the properties of Get-psdrive and assigns output to $dt variable 
.NOTES 
Adapted from script by Marc van Orsouw see link 
Version History 
v1.0  - Chad Miller - Initial Release 
v1.1  - Chad Miller - Fixed Issue with Properties 
v1.2  - Chad Miller - Added setting column datatype by property as suggested by emp0 
v1.3  - Chad Miller - Corrected issue with setting datatype on empty properties 
v1.4  - Chad Miller - Corrected issue with DBNull 
v1.5  - Chad Miller - Updated example 
v1.6  - Chad Miller - Added column datatype logic with default to string 
v1.7 - Chad Miller - Fixed issue with IsArray 
v1.8 - Abhishek Singh - Performance optimizations, syntax updates, better array handling
.LINK 
http://thepowershellguy.com/blogs/posh/archive/2007/01/21/powershell-gui-scripblock-monitor-script.aspx 
#> 
function Out-DataTable {
   [CmdletBinding()]
   param(
       [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
       [PSObject[]]$InputObject
   )
   Begin {
       $dt = [System.Data.DataTable]::new()
       $first = $true
   }
   Process {
       foreach ($object in $InputObject) {
           $dr = $dt.NewRow()
           foreach ($property in $object.PSObject.Properties) {
               if ($first) {
                   # Create DataColumn on the first iteration
                   $col = [System.Data.DataColumn]::new()
                   $col.ColumnName = $property.Name
                   if ($property.Value -and $property.Value -isnot [System.DBNull]) {
                       $col.DataType = [System.Type]::GetType((Get-Type $property.TypeNameOfValue))
                   } else {
                       $col.DataType = [System.String]
                   }
                   $dt.Columns.Add($col)
               }
               # Handle array properties
               if ($property.Value -is [Array]) {
                   $dr[$property.Name] = $property.Value | ConvertTo-Xml -As String -NoTypeInformation -Depth 1
               } else {
                   $dr[$property.Name] = $property.Value
               }
           }
           $dt.Rows.Add($dr)
           $first = $false
       }
   }
   End {
       return ,$dt
   }
}
