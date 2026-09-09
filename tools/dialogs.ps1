# Lists top-level windows of AutoHotkey64.exe processes and dumps dialog text (error/warning boxes).
Add-Type -AssemblyName UIAutomationClient
$root = [System.Windows.Automation.AutomationElement]::RootElement
foreach ($p in (Get-Process AutoHotkey64 -ErrorAction SilentlyContinue)) {
  $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $p.Id)
  foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
    "PID $($p.Id) WINDOW: '$($w.Current.Name)' class=$($w.Current.ClassName)"
    $doc = $w.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Document)))
    if ($doc) { "  TEXT: " + $doc.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern).DocumentRange.GetText(-1) }
    $texts = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Text)))
    foreach ($t in $texts) { if ($t.Current.Name) { "  TEXT: " + $t.Current.Name } }
  }
}
