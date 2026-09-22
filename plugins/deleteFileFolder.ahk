; Originally from Clipjump by Avi Aryan (Apache License 2.0). Modified by mpeutz, 2026: ported to AutoHotkey v2.
;@Plugin-Name Delete [File/Folder]
;@Plugin-Description Deletes clips that are [File/Folder] type from a channel.
;@Plugin-Author Avi
;@Plugin-Version 0.3
;@Plugin-Tags clip management file folder

;@Plugin-param1 The channels whose clips of type "[File/folder]" are to be deleted separated by space. If this param is empty,
;@Plugin-param1 all channels that exist are taken into account.
;@Plugin-param1 So if you click OK without any parameter, the whole clipnik database will be cleaned of [File/Folder] data-type clips.


plugin_deleteFileFolder(zchannels := "") {
	global
	local zbkCh, cleaned, zCfactor, zSomething_deleted, zFormat
	Critical "On" 				; As all clip files are disturbed, it is necessary to be non-interruptible
	if (zchannels = "")
		loop CN.Total 	; Cn.total contains total channels
			zchannels .= A_Index - 1 " "
	zchannels := Trim(zchannels, " ")
	if (zchannels = "")
		return 0
	zbkCh := CN.NG 	; create backup of current channel
	CN["CURSAVE" CN.N] := CURSAVE, CN["TEMPSAVE" CN.N] := TEMPSAVE 	; put CURSAVE (stores total clips in a channel) and TEMPSAVE in the object
	cleaned := 0

	API.blockMonitoring(1) 	; block Clipboard monitoring as Clipboard will be heavily changed during the process
	loop parse zchannels, A_Space
	{
		if FileExist("cache\clips" (zCfactor := A_LoopField ? A_LoopField : "")) 	;for ch. 0, we have cache\clips
		{
			API.showTip("Deleting Clips of type [File/Folder] from channel " A_LoopField) 	; show tip
			changeChannel(A_LoopField) 		; change Channel to the one to be examined
			zSomething_deleted := 1

			while zSomething_deleted	;  clearClip() changes clips locn and so loop over files in the directory becomes invalid. So we start it again.
			{
				zSomething_deleted := 0
				loop files "cache\clips" zCfactor "\*.avc"
				{
					ONCLIPBOARD := 0 	; This var is made 1 by the OnClipboardChange callback that responds to system clipboard change.
					try A_Clipboard := ClipFileRead(A_LoopFileFullPath) 	; read clip file to clipboard
					zFormat := getClipboardFormat() 				; get its format
					if (zFormat == "[" TXT.TIP_file_folder "]") 	; if format is file/folder
					{
						clearClip(SubStr(A_LoopFileName, 1, -4)) 	; clear the file/folder clip
						zSomething_deleted := 1
						cleaned++
						break
					}
				}
			}

		}
	}
	Critical "Off" 	; Off Critical so that if ONCLIPBOARDCHANGE: wants, it can update the var ONCLIPBOARD
	while !ONCLIPBOARD 		; wait for the final ONCLIPBOARD to be 1
	{
		if A_Index > 40		; break if something unexpected happened
			break
		Sleep 5
	}
	API.showTip("Delete [File/Folder] Plugin Finished`n`nCleaned " cleaned " items", 1700) 		; remove the tip after 800 ms
	changeChannel(zbkCh) 		;change channel back
	API.blockMonitoring(0)
}
