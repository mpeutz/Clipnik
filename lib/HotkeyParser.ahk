/*
HParse()
© Avi Aryan

5th Revision - 8/7/14
=========================================================================
Extract Autohotkey hotkeys from user-friendly shortcuts reliably and V.V
=========================================================================
==========================================
EXAMPLES - Pre-Runs
==========================================

msgbox % Hparse("Cntrol + ass + S", false)		;returns <blank>   	As 'ass' is out of scope and RemoveInvaild := false
msgbox % Hparse("Contrl + At + S")		;returns ^!s
msgbox % Hparse("^!s")			;returns	^!s		as the function-feed is already in Autohotkey format.
msgbox % Hparse("LeftContrl + X")		;returns Lcontrol & X
msgbox % Hparse("Contrl + Pageup + S")		;returns <blank>  As the hotkey is invalid
msgbox % HParse("PagUp + Ctrl", true)		;returns  ^PgUp  	as  ManageOrder is true (by default)
msgbox % HParse("PagUp + Ctrl", true, false)		;returns  <blank>  	as ManageOrder is false and hotkey is invalid	
msgbox % Hparse("Ctrl + Alt + Ctrl + K")		;returns  <blank> 	as two Ctrls are wrong
msgbox % HParse("Control + Alt")		;returns  ^Alt and NOT ^!
msgbox % HParse("Ctrl + F1 + Nmpd1")		;returns <blank>	As the hotkey is invalid
msgbox % HParse("Prbitscreen + f1")		;returns	PrintScreen & F1
msgbox % HParse("Prbitscreen + yyy")		;returns	PrintScreen		As RemoveInvalid is enabled by default.
msgbox % HParse("f1+ browser_srch")		;returns	F1 & Browser_Search
msgbox % HParse("Ctrl + joy1")			;returns	Ctrl & Joy1
msgbox % Hparse("pagup & paegdown")		;returns	PgUp & PgDn
MsgBox % HParse("Ctrl + printskreen", 1, 1, 1) 	; SEND Mode - on returns ^{printscreen}
msgbox % Hparse_rev("^!s")		;returns Ctrl+Alt+S
msgbox % Hparse_rev("Pgup & PgDn")		;returns Pageup & PgDn
*/



;###################################################################
;PARAMETERS - HParse() 		[See also Hparse_Rev() below]
;-------------------------------
;HParse(Hotkey, RemoveInvalid, ManageOrder, sendMd)
;###################################################################

;• Hotkey - The user shortcut such as (Control + Alt + X) to be converted

;• RemoveInvalid(true) - Remove Invalid entries such as the 'ass' from (Control + ass + S) so that the return is ^s. When false the function will return <blank> when an
;  invalid entry is found.
  
;• ManageOrder(true) - Change (X + Control) to ^x and not x^ so that you are free from errors. If false, a <blank> value is returned when the hotkey is found un-ordered.

;+ SendMd(true) - returns ^{printscreen} instead of ^printscreen so that the hotkey properly works with the Send command
HParse(Hotkey, RemoveInvaild := true, ManageOrder := true, sendMd := false)
{
	Combo := "", _hotkey := ""
	firstkey := SubStr(Hotkey, 1, 1)
	if (firstkey = "^" || firstkey = "!" || firstkey = "+" || firstkey = "#")
		return Hotkey

	loop parse Hotkey, "+-&", A_Space
	{
		if (StrLen(A_LoopField) != 1)
		{
			parsed := Hparse_LiteRegexM(A_LoopField)
			if sendMd && (StrLen(parsed) > 1) && (InStr(parsed, "vk") != 1)
				parsed := "{" parsed "}"
			if !RemoveInvaild
			{
				if (parsed = "")
				{
					Combo := ""
					break
				}
				else
					Combo .= " & " . parsed
			}
			else if (parsed != "")
				Combo .= " & " . parsed
		}
		else
			Combo .= " & " . A_LoopField
	}

	non_hotkey := 0
	if (Combo != "")		;Convert the hotkey to perfect format
	{
		Combo := SubStr(Combo, 4)
		loop parse Combo, "&", A_Space
		{
			if !(A_LoopField = "^" || A_LoopField = "!" || A_LoopField = "+" || A_LoopField = "#")
				non_hotkey += 1
		}
		if (non_hotkey == 0)
		{
			rightest := SubStr(Combo, -1)
			Combo := SubStr(Combo, 1, -1)
			if (rightest = "^")
				rightest := "Ctrl"
			else if (rightest = "!")
				rightest := "Alt"
			else if (rightest = "+")
				rightest := "Shift"
			else
				rightest := "LWin"
			Combo := Combo . rightest
		}
		;Remove last non
		if (non_hotkey < 2)
		{
			if !InStr(Combo, "Joy")
			{
				Combo := StrReplace(Combo, A_Space "&" A_Space)
				temp := Combo
				loop parse temp
				{
					if (A_LoopField = "^" || A_LoopField = "!" || A_LoopField = "+" || A_LoopField = "#")
					{
						Combo := StrReplace(Combo, A_LoopField, , , , 1)
						_hotkey .= A_LoopField
					}
				}
				Combo := _hotkey . Combo

				if !ManageOrder				;ManageOrder
					if (Combo != temp)
						Combo := ""

				temp := "^!+#"		;just reusing the variable . Checking for Duplicates Actually.
				if (Combo != "")
				{
					loop parse temp
					{
						if InStr(Combo, A_LoopField, , , 2) {
							Combo := ""
							break
						}
					}
				}
			}
			else	;Managing Joy
			{
				Combo := StrReplace(Combo, "^", "Ctrl", , , 1)
				Combo := StrReplace(Combo, "!", "Alt", , , 1)
				Combo := StrReplace(Combo, "+", "Shift", , , 1)
				Combo := StrReplace(Combo, "#", "LWin", , , 1)
				if InStr(Combo, "&", , , 2)
					Combo := ""
			}
		}
		else if InStr(Combo, "&", , , 2)
			Combo := ""
	}

	return Combo
}

;###########################################################################################
;Hparse_rev(Keycombo)
;	Returns the user displayable format of Ahk Hotkey
;###########################################################################################

HParse_rev(Keycombo) {
	toreturn := ""
	if InStr(Keycombo, "&")
	{
		loop parse Keycombo, "&", A_Space A_Tab
			toreturn .= A_LoopField " + "
		return SubStr(toreturn, 1, -3)
	}
	else
	{
		Keycombo := StrReplace(Keycombo, "^", "Ctrl&", , , 1)
		Keycombo := StrReplace(Keycombo, "#", "Win&", , , 1)
		Keycombo := StrReplace(Keycombo, "+", "Shift&", , , 1)
		Keycombo := StrReplace(Keycombo, "!", "Alt&", , , 1)
		loop parse Keycombo, "&", A_Space A_Tab
			toreturn .= (StrLen(A_LoopField) = 1 ? StrUpper(A_LoopField) : A_LoopField) " + "
		return SubStr(toreturn, 1, -3)
	}
}

;------------------------------------------------------
;SYSTEM FUNCTIONS : NOT FOR USER'S USE
;------------------------------------------------------

; Fuzzy-matches a user-typed key name against the pattern list and returns the canonical key name.
Hparse_LiteRegexM(matchitem, primary := 1)
{
	regX := Hparse_ListGen("RegX", primary)
	keys := StrSplit(Hparse_ListGen("Keys", primary), "`n", "`r")
	matchit := matchitem
	linenumber := ""

	loop parse regX, "`n", "`r"
	{
		matchitem := matchit
		exitfrombreak := false

		loop parse A_LoopField, "*"
		{
			if (A_Index == 1)
				if (SubStr(matchitem, 1, 1) != A_LoopField) {
					exitfrombreak := true
					break
				}

			if Hparse_comparewith(matchitem, A_LoopField)
				matchitem := Hparse_Vanish(matchitem, A_LoopField)
			else {
				exitfrombreak := true
				break
			}
		}

		if !exitfrombreak {
			linenumber := A_Index
			break
		}
	}

	if (linenumber != "")
		return keys[linenumber]
	if (primary = 1)
		return Hparse_LiteRegexM(matchit, 2)
	return ""
}

; Removes everything up to and including the first occurrence of character.
Hparse_Vanish(matchitem, character) {
	return SubStr(matchitem, InStr(matchitem, character) + 1)
}

Hparse_comparewith(first, second)
{
	if IsInteger(first)
		return (first = second)
	return InStr(first, second) ? true : false
}

;######################   DANGER    ################################
;SIMPLY DONT EDIT BELOW THIS . MORE OFTEN THAN NOT, YOU WILL MESS IT.
;###################################################################
Hparse_ListGen(what,primary:=1){
if (primary == 1)
{
if (what = "Regx")
Rvar := 
(
"L*c*t
r*c*t
l*s*i
r*s*i
l*a*t
r*a*t
S*p*c
C*t*r
A*t
S*f
W*N
t*b
E*r
E*s*c
B*K
D*l
I*S
H*m
E*d
P*u
p*d
l*b*t
r*b*t
m*b*t
up
d*n
l*f
r*t
F*1
F*2
F*3
F*4
F*5
F*6
F*7
F*8
F*9
F*10
F*11
F*12
N*p*Do
N*p*D*v
N*p*M*t
N*p*d*Ad
N*p*S*t
N*p*E*r
s*l*k
c*l
n*l*k
p*s
c*t*b
pa*s
b*r*k
x*b*1
x*b*2
z*z*z*z*callmelazybuthtisisaworkaround"
)
;====================================================
;# Original return values below (in respect with their above positions, dont EDIT)
if (what = "Keys")
Rvar := 
(
"LControl
RControl 
LShift
RShift
LAlt
RAlt
space
^
!
+
#
Tab
Enter
Escape
Backspace
Delete
Insert
Home
End
PgUp
PgDn
LButton
RButton
MButton
Up
Down
Left
Right
F1
F2
F3
F4
F5
F6
F7
F8
F9
F10
F11
F12
NumpadDot
NumpadDiv
NumpadMult
NumpadAdd
NumpadSub
NumpadEnter
ScrollLock
CapsLock
NumLock
PrintScreen
CtrlBreak
Pause
Break
XButton1
XButton2
A_lazys_workaround"
)
}
else
{
;here starts the second preference list.
if (what = "Regx")
Rvar:=
(
"N*p*0
N*p*1
N*p*2
N*p*3
N*p*4
N*p*5
N*p*6
N*p*7
N*p*8
N*p*9
F*13
F*14
F*15
F*16
F*17
F*18
F*19
F*20
F*21
F*22
F*23
F*24
N*p*I*s
N*p*E*d
N*p*D*N
N*p*P*D
N*p*L*f
N*p*C*r
N*p*R*t
N*p*H*m
N*p*Up
N*p*P*U
N*p*D*l
J*y*1
J*y*2
J*y*3
J*y*4
J*y*5
J*y*6
J*y*7
J*y*8
J*y*9
J*y*10
J*y*11
J*y*12
J*y*13
J*y*14
J*y*15
J*y*16
J*y*17
J*y*18
J*y*19
J*y*20
J*y*21
J*y*22
J*y*23
J*y*24
J*y*25
J*y*26
J*y*27
J*y*28
J*y*29
J*y*30
J*y*31
J*y*32
B*_B*k
B*_F*r
B*_R*e*h
B*_S*p
B*_S*c
B*_F*t
B*_H*m
V*_M*e
V*_D*n
V*_U
M*_N*x
M*_P
M*_S*p
M*_P*_P
L*_M*l
L*_M*a
L*_A*1
L*_A*2
"
)
if (what = "keys")
Rvar:=
(
"Numpad0
Numpad1
Numpad2
Numpad3
Numpad4
Numpad5
Numpad6
Numpad7
Numpad8
Numpad9
F13
F14
F15
F16
F17
F18
F19
F20
F21
F22
F23
F24
NumpadIns
NumpadEnd
NumpadDown
NumpadPgDn
NumpadLeft
NumpadClear
NumpadRight
NumpadHome
NumpadUp
NumpadPgUp
NumpadDel
Joy1
Joy2
Joy3
Joy4
Joy5
Joy6
Joy7
Joy8
Joy9
Joy10
Joy11
Joy12
Joy13
Joy14
Joy15
Joy16
Joy17
Joy18
Joy19
Joy20
Joy21
Joy22
Joy23
Joy24
Joy25
Joy26
Joy27
Joy28
Joy29
Joy30
Joy31
Joy32
Browser_Back
Browser_Forward
Browser_Refresh
Browser_Stop
Browser_Search
Browser_Favorites
Browser_Home
Volume_Mute
Volume_Down
Volume_Up
Media_Next
Media_Prev
Media_Stop
Media_Play_Pause
Launch_Mail
Launch_Media
Launch_App1
Launch_App2
"
)
}
;<<<<<<<<<<<<<<<<END>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
return Rvar
}
