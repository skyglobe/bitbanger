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
        return [scan $num %X]
        } else {
        error "Invalid number: $num"
    }
}

#Globals
set decimalval 0
set hexval 0
set binval [list]

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

#Disable window resize
wm resizable . 0 0

#Event processing

#Procedures

proc changeBinText {} {
    global binval
    for {set i 0} {$i < 32} {incr i} {
        .bin$i configure -text [lindex $binval $i]
    }
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

#Bindings
bind .decimal <Return> decChanged
bind .hex <Return> hexChanged

for {set i 0} {$i < 32} {incr i} {
    bind .bin$i <1> "toggleBit $i"
}