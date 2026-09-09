# Clicks "Continue" (or OK) on any AutoHotkey64 error/warning dialog so the affected thread ends without killing the script.
Add-Type -AssemblyName UIAutomationClient
$root = [System.Windows.Automation.AutomationElement]::RootElement
foreach ($p in (Get-Process AutoHotkey64 -ErrorAction SilentlyContinue)) {
  $cond = New-Object System.Windows.Automation.AndCondition((New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $p.Id)), (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, "#32770")))
  foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
    foreach ($name in @("Continue", "OK")) {
      $b = $w.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $name)))
      if ($b) { $r = $b.Current.BoundingRectangle; Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point([int]($r.X + $r.Width/2), [int]($r.Y + $r.Height/2)); $sig = "[DllImport(`"user32.dll`")] public static extern void mouse_event(uint f, uint x, uint y, uint d, System.IntPtr e);"; $m = Add-Type -MemberDefinition $sig -Name M -Namespace W -PassThru; $m::mouse_event(2,0,0,0,[IntPtr]::Zero); $m::mouse_event(4,0,0,0,[IntPtr]::Zero); "clicked $name on $($w.Current.Name)"; break }
    }
  }
}
