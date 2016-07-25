#!/usr/bin/env tclsh

#Simple Tcl/Tk application to visualize binary numbers.

#Copyright (C) 2016 Gianfranco Gallizia

#Permission is hereby granted, free of charge, to any person
#obtaining a copy of this software and associated documentation
#files (the "Software"), to deal in the Software without
#restriction, including without limitation the rights to use, copy,
#modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software
#is furnished to do so, subject to the following conditions:

#The above copyright notice and this permission notice shall be
#included in all copies or substantial portions of the Software.

#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
#OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
#BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
#ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
#CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

package require Tk

#Helpers

#Converts a number into a list of binary digits
proc dec2bin {num {digits 32}} {
    if  {[string is digit $num]} {
            set output [list]
            while {$num > 0} {
                set mod [expr $num % 2]
                lappend output $mod
                incr digits -1
                if {$digits == 0} break
                set num [expr $num / 2]
            }

            while {$digits > 0} {
                lappend output 0
                incr digits -1
            }

            return [lreverse $output]
        } else {
            error "Invalid number: $num"
        }
}

#Converts a binary number into a decimal
proc bin2dec {num} {
    #Remove spaces
    set n [regsub -all {[[:space:]]+} $num ""]
    #Check there are no other characters except 0 and 1
    if [regexp {[01]+} $n] {
        set output 0
        set i 0
        foreach d [lreverse [split $n ""]] {
            if {$d eq 1} {
                set output [expr $output + (1 << $i)]
            }
            incr i
        }
        return $output
    } else {
        error "Invalid binary number: $num"
    }
}

proc dec2hex {num} {
    if {[string is digit $num]} {
        return [format %X $num]
        } else {
        error "Invalid number: $num"
    }
}

proc hex2dec {num} {
    if {[string is xdigit $num]} {
        return [scan $num %x]
        } else {
        error "Invalid number: $num"
    }
}

#Builds a point specification for a waveform polyline
proc waveCoords {binvals start middle offset} {
    set output [list]
    set prevBit [lindex $binvals 0]
    set hPos $start
    set vPos ""
    set top "[expr $middle - $offset]m"
    set bot "[expr $middle + $offset]m"
    if {$prevBit} {set vPos $top} else {set vPos $bot}
    #First point
    set output [lappend output "${start}m"]
    set output [lappend output "$vPos"]
    foreach bit $binvals {
        #Refresh vPos
        if {$bit} {set vPos $top} else {set vPos $bot}

        if {$prevBit != $bit} {
            #Keep X Coordinate
            set output [lappend output "${hPos}m"]
            #Add Y Coordinate
            set output [lappend output "$vPos"]
        }

        #Plot horizontal line
        set hPos [expr $hPos + 2 * $offset]
        set output [lappend output "${hPos}m"]
        set output [lappend output "$vPos"]
        #Save previous bit
        set prevBit $bit
    }
    return $output
}

#Returns a list of segments to draw a reference grid
proc gridCoords {start middle offset {points 32}} {
    set top "[expr $middle - $offset]m"
    set bot "[expr $middle + $offset]m"
    set hPos $start
    set hStep [expr 2 * $offset]
    set end [expr $start + $points * $hStep]

    #Bottom line first point
    set pointList [list "${start}m" $bot]
    #Bottom line end point
    set pointList [lappend pointList "${end}m" $bot]

    set output [lappend output $pointList]

    #Vertical segments
    for {set i 0} {$i < $points} {incr i} {
        set hPos [expr $hPos + $hStep]
        set pointList [list "${hPos}m" $top]
        set pointList [lappend pointList "${hPos}m" $bot]
        set output [lappend output $pointList]
    }

    return $output
}

#Globals
set decimalval 0
set hexval 0
set binval [list]
set wordstack [list]
set byteSelected 0
set gridVisible 0

#Intialize binval list
for {set i 0} {$i < 32} {incr i} {
    lappend binval 0
}

#UI elements

entry .decimal -textvariable decimalval -justify right
entry .hex -textvariable hexval -justify right

label .decLabel -text "Decimal"
label .hexLabel -text "Hexadecimal"

#Binary number labels are generated automatically
for {set i 0} {$i < 32} {incr i} {
    eval "label .bin$i -text 0 -relief sunken"
    eval "label .binLabel$i -text $i"
}

#Waveform canvas
canvas .wfc -height 1c -width 165m

#Word stack controls
button .btnAppend -text "Append Word" -command appendBinWord
frame .frmByteSel
radiobutton .frmByteSel.rdo0 -text "0:7" -variable byteSelected -value 0
radiobutton .frmByteSel.rdo1 -text "8:15" -variable byteSelected -value 1
radiobutton .frmByteSel.rdo2 -text "16:23" -variable byteSelected -value 2
radiobutton .frmByteSel.rdo3 -text "24:31" -variable byteSelected -value 3
checkbutton .frmByteSel.chkGrid -text "Grid" -variable gridVisible

#Word stack canvas
canvas .wsc -height 8c
button .btnUpdate -text "Update Waveforms" -command updateWaveForms
button .btnClear -text "Clear Waveforms" -command clearWordStack

#Set window title
wm title . "Bit Banger"

#Place elements on a grid

#Row 0: description labels
grid .decLabel -row 0 -column 0 -columnspan 16
grid .hexLabel -row 0 -column 16 -columnspan 16

#Row 1: text entries
grid .decimal -row 1 -column 0 -columnspan 16 -sticky ew
grid .hex -row 1 -column 16 -columnspan 16 -sticky ew

#Row 2: binary labels
#Row 3: bit number labels
for {set i 31} {$i >= 0} {incr i -1} {
    grid .bin$i -row 2 -column $i -sticky ew
    grid .binLabel$i -row 3 -column [expr 31 - $i]
    #Set the columns to have all the same width
    grid columnconfigure . [expr 31 - $i] -weight 1 -uniform a
}

#Row 4: the waveform canvas
grid .wfc -row 4 -column 0 -columnspan 32 -sticky ew

#Row 5: Word stack controls
grid .btnAppend -row 5 -column 0 -columnspan 16 -sticky ew
grid .frmByteSel -row 5 -column 16 -columnspan 16 -sticky ew
grid .frmByteSel.rdo0 -row 0 -column 0
grid .frmByteSel.rdo1 -row 0 -column 1
grid .frmByteSel.rdo2 -row 0 -column 2
grid .frmByteSel.rdo3 -row 0 -column 3
grid .frmByteSel.chkGrid -row 0 -column 4

#Row 6: Word stack canvas
grid .wsc -row 6 -column 0 -columnspan 32 -sticky ew

#Row 7: Update button
grid .btnUpdate -row 7 -column 0 -columnspan 16 -sticky ew
grid .btnClear -row 7 -column 16 -columnspan 16 -sticky ew

#Disable window resize
wm resizable . 0 0

#Event processing

#Procedures

proc changeBinText {} {
    global binval
    for {set i 0} {$i < 32} {incr i} {
        .bin$i configure -text [lindex $binval $i]
    }
    set coords [waveCoords $binval 2.5 3 2.5]
    .wfc delete all
    .wfc create line $coords
}

proc toggleBit {index} {
    global binval decimalval
    if {[string is digit $index]} {
        if {$index < 0 || $index > 31} {
            error "Invalid index: $index"
        }
        set value [expr ! [lindex $binval $index]]
        set binval [lreplace $binval $index $index $value]
    } else {
            error "Invalid index: $index"
    }
    changeBinText
    set decimalval [bin2dec $binval]
    decChanged
}

proc decChanged {} {
    global decimalval hexval binval
    if {![string is digit $decimalval]} {
        set decimalval 0
    }
    set hexval [dec2hex $decimalval]
    set binval [dec2bin $decimalval]
    changeBinText
}

proc hexChanged {} {
    global decimalval hexval binval
    if {![string is xdigit $hexval]} {
        set hexval 0
    }
    set decimalval [hex2dec $hexval]
    set binval [dec2bin $decimalval]
    changeBinText
}

proc appendBinWord {} {
    global wordstack binval
    if {[llength $wordstack] > 32} {
        unset wordstack
        set wordstack [list]
    }
    set wordstack [lappend wordstack $binval]
}

proc clearWordStack {} {
    global wordstack
    unset wordstack
    set wordstack [list]
    .wsc delete all
}

proc updateWaveForms {} {
    global wordstack byteSelected gridVisible
    set indices [list]

    switch -exact $byteSelected {
        0 {set indices {24 31}}
        1 {set indices {16 23}}
        2 {set indices {8 15}}
        3 {set indices {0 7}}
    }

    #Waveform words
    for {set i 0} {$i < 8} {incr i} {
        set word$i [list]
    }

    #Build waveform words
    foreach w $wordstack {
        set slice [lreverse [lrange $w [lindex $indices 0] [lindex $indices 1]]]
        for {set i 0} {$i < 8} {incr i} {
            set word$i [lappend word$i [lindex $slice $i]]
        }
    }

    #Clear canvas
    .wsc delete all

    #Plot waveforms
    for {set i 0} {$i < 8} {incr i} {
        set middle [expr ($i + 1) * 7]

        if {$gridVisible} {
            #Draw reference grid
            foreach l [gridCoords 2.5 $middle 2.5 [llength $wordstack]] {
            .wsc create line $l -dash .
            }
        }

        set v [set word$i]
        .wsc create line [waveCoords $v 2.5 $middle 2.5]
    }
}

#Bindings
bind .decimal <Return> decChanged
bind .hex <Return> hexChanged

for {set i 0} {$i < 32} {incr i} {
    bind .bin$i <1> "toggleBit $i"
}
