/*
WM_MOUSEMOVE() v0.01
	Callback to enable ToolTips for Controls
	Called whenever the mouse hovers over a control, this function shows a tooltip for the control over
    which it is hovering. The tooltip text is looked up by the control's variable name.

By:
	Avi Aryan
	Extracted from "Settings GUI Plug.ahk" to make it more public
*/

; Tooltip texts keyed by control name (v1 used <name>_TT globals)
controlTips() {
	global TXT
	static tips := ""
	if IsObject(tips)
		return tips
	tips := Map()
	tips.CaseSense := "Off"
	; **** Settings GUI **************************
	tips["NEW_LIMITMAXCLIPS"] := TXT.SET_T_limitmaxclips
	tips["NEW_MAXCLIPS"] := TXT.SET_T_maxclips
	tips["NEW_THRESHOLD"] := TXT.SET_T_threshold
	tips["NEW_COPYBEEP"] := TXT.SET_T_copybeep
	tips["NEW_QUALITY"] := TXT.SET_T_quality
	tips["NEW_KEEPSESSION"] := TXT.SET_T_keepsession
	tips["NEW_ISMESSAGE"] := TXT.SET_T_ismessage
	tips["new_default_pformat"] := TXT.SET_T_pformat
	tips["NEW_DAYSTOSTORE"] := TXT.SET_T_daystostore
	tips["NEW_ISIMAGESTORED"] := TXT.SET_T_images
	tips["pst_k"] := TXT.SET_T_pst
	tips["actmd_k"] := TXT.SET_T_actmd
	tips["chnl_K"] := TXT.SET_T_chnl
	tips["cfilep_K"] := TXT.SET_T_cfilep
	tips["cfolderp_K"] := TXT.SET_T_cfolderp
	tips["cfiled_K"] := TXT.SET_T_cfiled
	tips["hldClip_K"] := TXT.SET_T_holdClip
	tips["PITSWP_K"] := TXT.SET_T_pitswp
	tips["NEW_ischannelmin"] := TXT.SET_T_ischannelmin
	tips["plugM_k"] := TXT.SET_t_PLUGM
	tips["new_PreserveClipPos"] := TXT.SET_T_keepactivepos
	tips["org_K"] := TXT.SET_org
	tips["new_startSearch"] := TXT.SET_T_startSearch
	tips["new_revFormat2def"] := TXT.SET_T_revFormat2def
	tips["hst_K"] := TXT.SET_T_histshort
	tips["new_winClipjump"] := TXT.SET_T_winClipjump
	; **** Channel Organizer *********************
	tips["chOrgToggleLeftRight"] := TXT.ORG_toggleLeftRight
	tips["chOrg_search"] := TXT.ORG_search
	tips["chorgNew"] := TXT.ORG_createnew
	tips["chOrgUp"] := TXT.ORG_up
	tips["chOrgDown"] := TXT.ORG_down
	tips["chOrgEdit"] := TXT.ORG_edit
	tips["chorg_openPastemode"] := TXT.ORG_openPastemode
	tips["chOrg_props"] := TXT.ORG_props
	tips["chOrgCut"] := TXT.ORG_cut
	tips["chOrgCopy"] := TXT.ORG_copy
	tips["chOrgDelete"] := TXT.ORG_delete
	return tips
}

WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
	static prevControl := ""
	global HoverTip_Text
	ctrl := GuiCtrlFromHwnd(hwnd)
	currControl := ctrl ? ctrl.Name : ""
	if (currControl != prevControl && currControl != "")
	{
		ToolTip(, , , 4)	;remove the old Tooltip
		tips := controlTips()
		HoverTip_Text := tips.Has(currControl) ? tips[currControl] : ""
		SetTimer(HoverTip_Show, -650)
		prevControl := currControl
	}
}

global HoverTip_Text := ""

HoverTip_Show(*) {
	global HoverTip_Text
	if (HoverTip_Text != "")
		ToolTip(HoverTip_Text, , , 4)
	SetTimer(CJ_TooltipOff(4), -8000)
}
