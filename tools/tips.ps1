# Prints the text of every tooltip window owned by AutoHotkey64 processes (one per line).
Add-Type -AssemblyName UIAutomationClient
$root = [System.Windows.Automation.AutomationElement]::RootElement
foreach ($p in (Get-Process AutoHotkey64 -ErrorAction SilentlyContinue)) {
  $cond = New-Object System.Windows.Automation.AndCondition((New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $p.Id)), (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, "tooltips_class32")))
  foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) { if ($w.Current.Name) { $w.Current.Name -replace "`r?`n", " " } }
}
