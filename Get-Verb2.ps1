Function Get-Verb2 {
    Get-Verb | `
        Select-Object -ExpandProperty Verb | `
        Format-ColumnTable -ColumnCount 7 -Padded
}
