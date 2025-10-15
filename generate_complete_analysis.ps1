# PowerShell script to generate complete database analysis including distinct values
param(
    [string]$Server = "SPR-JEOFFREY-C\SQLEXPRESS",
    [string]$Database = "MESRecovery",
    [string]$OutputPath = "Analysis\MESanalysis.csv"
)

$connectionString = "Server=$Server;Database=$Database;Integrated Security=true;Connection Timeout=60;"
$connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)

try {
    $connection.Open()
    Write-Host "Connected to database successfully"
    
    # Get all columns with their metadata
    $getColumnsQuery = @"
SELECT 
    c.TABLE_SCHEMA,
    c.TABLE_NAME, 
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.IS_NULLABLE,
    CASE WHEN EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc 
        JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME 
            AND kcu.TABLE_SCHEMA = tc.TABLE_SCHEMA 
            AND kcu.TABLE_NAME = tc.TABLE_NAME
        WHERE tc.TABLE_SCHEMA = c.TABLE_SCHEMA 
            AND tc.TABLE_NAME = c.TABLE_NAME 
            AND kcu.COLUMN_NAME = c.COLUMN_NAME 
            AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
    ) THEN 1 ELSE 0 END AS IS_PRIMARY_KEY,
    CASE WHEN EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc 
        JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME 
            AND kcu.TABLE_SCHEMA = tc.TABLE_SCHEMA 
            AND kcu.TABLE_NAME = tc.TABLE_NAME
        WHERE tc.TABLE_SCHEMA = c.TABLE_SCHEMA 
            AND tc.TABLE_NAME = c.TABLE_NAME 
            AND kcu.COLUMN_NAME = c.COLUMN_NAME 
            AND tc.CONSTRAINT_TYPE = 'FOREIGN KEY'
    ) THEN 1 ELSE 0 END AS IS_FOREIGN_KEY
FROM INFORMATION_SCHEMA.COLUMNS c
INNER JOIN INFORMATION_SCHEMA.TABLES t ON c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME
WHERE t.TABLE_TYPE = 'BASE TABLE'
ORDER BY c.TABLE_SCHEMA, c.TABLE_NAME, c.ORDINAL_POSITION
"@
    
    $command = New-Object System.Data.SqlClient.SqlCommand($getColumnsQuery, $connection)
    $command.CommandTimeout = 120
    $reader = $command.ExecuteReader()
    
    $results = @()
    $totalColumns = 0
    
    # First pass: collect all column metadata
    while ($reader.Read()) {
        $totalColumns++
        $schema = $reader["TABLE_SCHEMA"]
        $table = $reader["TABLE_NAME"]
        $column = $reader["COLUMN_NAME"]
        $dataType = $reader["DATA_TYPE"]
        $isNullable = $reader["IS_NULLABLE"]
        $isPrimaryKey = $reader["IS_PRIMARY_KEY"]
        $isForeignKey = $reader["IS_FOREIGN_KEY"]
        
        # Infer foreign table name for foreign keys
        $foreignTableName = ""
        if ($isForeignKey -eq 1) {
            if ($column.ToLower().EndsWith("_id")) {
                $foreignTableName = $column.Substring(0, $column.Length - 3)
            } else {
                $foreignTableName = $column
            }
        }
        
        $results += [PSCustomObject]@{
            TABLE_SCHEMA = $schema
            TABLE_NAME = $table
            COLUMN_NAME = $column
            DATA_TYPE = $dataType
            ALLOWS_NULLS = if ($isNullable -eq "YES") { "TRUE" } else { "FALSE" }
            IS_PRIMARY_KEY = if ($isPrimaryKey -eq 1) { "TRUE" } else { "FALSE" }
            IS_FOREIGN_KEY = if ($isForeignKey -eq 1) { "TRUE" } else { "FALSE" }
            FOREIGN_TABLE_NAME = $foreignTableName
            DISTINCT_VALUES = 0  # Will be computed in second pass
        }
    }
    
    $reader.Close()
    Write-Host "Collected metadata for $totalColumns columns"
    
    # Second pass: compute distinct values
    Write-Host "Computing distinct values for each column..."
    $processed = 0
    
    foreach ($result in $results) {
        $processed++
        $schema = $result.TABLE_SCHEMA
        $table = $result.TABLE_NAME
        $column = $result.COLUMN_NAME
        $dataType = $result.DATA_TYPE
        
        $fullTableName = "[$schema].[$table]"
        $fullColumnName = "[$column]"
        
        try {
            # Skip problematic data types
            if ($dataType -in @("text", "ntext", "image", "varbinary")) {
                $distinctCount = 0
            } else {
                # Try different approaches based on data type
                $distinctQuery = "SELECT COUNT(DISTINCT CAST($fullColumnName AS NVARCHAR(MAX))) FROM $fullTableName"
                $distinctCommand = New-Object System.Data.SqlClient.SqlCommand($distinctQuery, $connection)
                $distinctCommand.CommandTimeout = 60
                $distinctCount = $distinctCommand.ExecuteScalar()
            }
            
            $result.DISTINCT_VALUES = $distinctCount
            
            if ($processed % 50 -eq 0) {
                Write-Host "Processed $processed/$totalColumns columns..."
            }
        }
        catch {
            Write-Host "Warning: Could not compute distinct values for $schema.$table.$column : $($_.Exception.Message)"
            $result.DISTINCT_VALUES = 0
        }
    }
    
    # Create output directory if it doesn't exist
    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force
    }
    
    # Write results to CSV
    Write-Host "Writing results to: $OutputPath"
    $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "Analysis complete! Processed $totalColumns columns."
    Write-Host "Output saved to: $OutputPath"
}
catch {
    Write-Host "Error: $($_.Exception.Message)"
    exit 1
}
finally {
    if ($connection.State -eq "Open") {
        $connection.Close()
    }
}
