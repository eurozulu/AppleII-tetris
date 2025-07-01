         ORG   $0C00
SETGR    EQU   $FB40
H2       EQU   $2C
V2       EQU   $2D
PLOT     EQU   $F800      ; Plot point Y,A
HLINE    EQU   $F819      ; plot Hline Y,A to H2,A
VLINE    EQU   $F828      ; plot Vline Y,A to Y,V2
HOME     EQU   $FC58
UP       EQU   $FC1A
RNDL     EQU   $4E        ; Random number
SETCOL   EQU   $F864
SCRN     EQU   $F871      ; read color at Y,A
KEYB     EQU   $C000      ; read kybd char
STROBE   EQU   $C010      ; reset keybd char
COUT     EQU   $FDED
LINPRT   EQU   $ED24
CROUT    EQU   $FD8E
WAIT     EQU   $FCA8
PRBYTE   EQU   $FDDA
KEYIN    EQU   $FD28
Start    JSR   ResetScore
         JSR   SetScreen
         JSR   ResetCounter
         JSR   ResetShape ; Sets new shape to top of the screen
MainLoop JSR   IncCounter

         LDA   CounterH   ; high byte of counter
         CMP   Level
         BCS   CounterTick ; Fire tick every 'level' count
         INC   RNDL       ; psudo random num.
         JSR   ProcessKey ; leaves last key in A
         CMP   EscKey     ; Check if esc pressed and exit
         BNE   MainLoop
         JSR   ShowBye
         RTS              ; Close Game

CounterTick JSR ResetCounter
         JSR   ShowScore
         JSR   MoveDown
         LDA   CollisionCol ; Check if we've hit anything
         BEQ   MainLoop   ; No collision, rejoin loop
Collision                 ; hit floor or other shape
         LDX   #01
         LDA   ShapePos,X ; check YPos not at top
         CMP   #02
         BCC   GameOver   ; already at top
         JSR   CheckLines
         JSR   ResetShape
         JMP   MainLoop

IncCounter CLC
         INC   CounterL
         BNE   incDone
         INC   CounterH
incDone  RTS

ResetCounter LDA #00
         STA   CounterL
         STA   CounterH
         RTS

GameOver LDX   #00
goLoop   LDA   SzGameOver,x
         BEQ   gameDone
         JSR   COUT
         INX
         JMP   goLoop
gameDone JSR   CROUT
         RTS
WipeShape                 ; draw in black to wipe
         LDA   #00
         JSR   SETCOL
         JMP   PlotShape
DrawShape                 ; draw in shape colour
         LDA   ShapeCol
         JSR   SETCOL
PlotShape
         LDX   #00
PlotLoop LDY   ShapePos,x ; each block in ShapePos
         INX
         LDA   ShapePos,x
         INX
         JSR   PLOT
         CPX   #08        ; 8 bytes (4 lots of x,y)
         BCC   PlotLoop
         RTS
ProcessKey
         LDA   KEYB       ; read current char in keyb
         CMP   #$80
         BCC   KeyDone    ; no key pressed
         STA   STROBE     ; clear keyb buf
         AND   #$7F       ; Turn into ascii
         CMP   #$08
         BEQ   MoveLeft
         CMP   #$15
         BEQ   MoveRight
         CMP   #$0A
         BEQ   MoveDown
         CMP   #$7A
         BEQ   RotLeft
         CMP   #$5A
         BEQ   RotLeft
         CMP   #$78
         BEQ   RotRight
         CMP   #$58
         BEQ   RotRight
         CMP   #$20
         BEQ   PauseGame
KeyDone
         RTS
PauseGame
         JSR   HOME
         JSR   ShowHitKey
         JSR   KEYIN
         JSR   HOME
         RTS
MoveDown
         INC   YPos       ; Move the shape one square down
         JSR   `
         BEQ   moveDone   ; If black, no collision
         DEC   YPos       ; revert move
         JSR   UpdatePos
         JSR   DrawShape
         JMP   moveDone
MoveLeft
         DEC   XPos       ; Move the shape one square down
         JSR   MoveShape
         BEQ   moveDone   ; If black, move ok
         INC   XPos       ; revert move
         JSR   UpdatePos
         JSR   DrawShape
         JMP   moveDone
MoveRight
         INC   XPos       ; Move the shape one square to right
         JSR   MoveShape
         BEQ   moveDone   ; If black, move ok
         DEC   XPos       ; revert move
         JSR   UpdatePos
         JSR   DrawShape  ; redraw in old position
moveDone RTS


RotLeft  JSR   DecRot
         JSR   MoveShape
         BEQ   moveDone
         JSR   IncRot     ; revert rotation
         JSR   UpdatePos
         JSR   DrawShape
         JMP   moveDone

RotRight JSR   IncRot
         JSR   MoveShape
         BEQ   moveDone
         JSR   DecRot
         JSR   UpdatePos
         JSR   DrawShape
         JMP   moveDone

MoveShape JSR  WipeShape  ; Wipe in current position
         JSR   UpdatePos  ; pick up new state
         JSR   ColDetect
         BNE   msDone     ; non black = collision, abort
         JSR   DrawShape  ; redraw in new position
         LDA   #00        ; return zero = OK
msDone   RTS

IncRot   LDY   Rotation
         CPY   #03
         BCC   incRDone
         LDY   #$FF       ; Rolling over 03->0
incRDone INY
         STY   Rotation
         RTS

DecRot   DEC   Rotation
         BPL   decRDone
         LDY   #03        ;;roll over0 > 3
         STY   Rotation
decRDone RTS

ColDetect LDX  #00        ; check each block for black
ColLoop  LDY   ShapePos,x ; load Y with relative XPos
         INX
         LDA   ShapePos,x
         INX
         JSR   SCRN
         BNE   CheckColDone ; Non black found
         CPX   #08
         BCC   ColLoop
CheckColDone STA CollisionCol
         RTS
UpdatePos                 ; Update ShapePos with state
         LDX   #00        ; index in shapepos
         LDA   XPos       ; copy X,Y into first bytes
         STA   ShapePos
         INX
         LDA   YPos
         STA   ShapePos,x
         INX
                          ; copy Shape offsets into remaining bytes
         LDY   ShapeOffset
CopyLoop LDA   Shapes,y   ; copy relative coords to temp
         STA   TempX
         INY
         LDA   Shapes,y
         STA   TempY
         INY
         JSR   RotateCoords ; Adjust relatives for rotation
         LDA   TempX      ; Add rotated to XY and store in pos
         CLC
         ADC   XPos
         STA   ShapePos,x
         INX
         LDA   TempY
         CLC
         ADC   YPos
         STA   ShapePos,x
         INX
         CPX   #08
         BCC   CopyLoop
         RTS
ResetShape                ; Select new shape and place at top of screen
         LDA   #20        ; half width pos
         STA   XPos
         LDA   #01        ; top of screen
         STA   YPos
         LDA   #00
         STA   Rotation   ; zero rotation
         LDA   RNDL       ; select "random" shape
         AND   #06
         JSR   CalcSHOffset
         STA   ShapeOffset
         LDA   RNDL       ; set random color
         AND   #11
         ADC   #01        ; never black
         STA   ShapeCol
         JSR   UpdatePos
         RTS
RotateCoords              ; adjust TempX,TempY for rotation
         LDA   Rotation
         CMP   #01
         BEQ   Rot90
         CMP   #02
         BEQ   Rot180
         CMP   #03
         BEQ   Rot270
                          ; Zero rotation, do nothing
RotateDone
         RTS
Rot90    JSR   InvertTempY
         JSR   FlipCoords
         RTS
Rot180   JSR   InvertTempY
         JSR   InvertTempX
         RTS
Rot270   JSR   InvertTempX
         JSR   FlipCoords
         RTS
InvertTempY
         LDA   TempY
         EOR   #$FF
         CLC
         ADC   #01
         STA   TempY
         RTS
InvertTempX
         LDA   TempX
         EOR   #$FF
         CLC
         ADC   #01
         STA   TempX
         RTS
FlipCoords                ; Switch TempX,TempY around
         TYA              ; preserve Y
         PHA
         LDA   TempX
         LDY   TempY
         STA   TempY
         STY   TempX
         PLA
         TAY
         RTS
CalcSHOffset TAX          ; Set A to Shape offset
         LDA   #00
sosLoop  CPX   #00
         BEQ   sosDone
         CLC
         ADC   #06        ; skip 6 bytes per shape
         DEX
         JMP   sosLoop
sosDone  RTS
CheckLines LDA #00
         STA   Scratch    ; completed line count
         JSR   ShapeBounds ; Checks lines shape is on.
linesLoop LDA  TempY      ; highest Y of shape
         CMP   TempX      ; lowest Y of shape
         BCC   linesEnd
         JSR   CheckLine
         CMP   #00
         BEQ   skipLine   ; Line contains breaks
         LDA   TempY
         JSR   HighlightLine
         INC   Scratch
skipLine DEC   TempY
         JMP   linesLoop
linesEnd
         LDA   Scratch
         CMP   #00
         BEQ   linesDone  ; no lines completed
         ASL              ; double line count
         JSR   AddScore
         JSR   Pause
         JSR   DelHighlight
linesDone RTS
Pause    LDA   $FF        ; Wait for a short time to show highlight lines
pauseLoop
         JSR   WAIT
         JSR   WAIT
         RTS
CheckLine TAX             ; store A in X
         LDY   H1
         INY              ; skip boarder
lineChkLoop TXA
         JSR   SCRN
         BEQ   lineChkDone ; black found
         INY
         CPY   H2
         BCC   lineChkLoop
lineChkDone
         RTS

DelHighlight
         LDX   V2
         DEX              ; skip border
dhlLoop  TXA
         LDY   H1         ; look for highlight colour
         INY              ;skip border
         JSR   SCRN
         CMP   HighltCol  ; Check if its highlight colour
         BNE   noHL
         JSR   ScrollLine
         JMP   dhlLoop
noHL     DEX
         BNE   dhlLoop
dhlDone  RTS

ScrollLine TXA            ;Preserve X
         PHA
scrlLoop
         JSR   CopyLine
         DEX
         BNE   scrlLoop
         PLA              ; restore x
         TAX
         RTS

CopyLine LDY   H1         ; Copy line at X-1, into X
cpyLoop  INY
         CPY   H2
         BCS   cpyDone
         DEX              ; Check line above color
         TXA
         JSR   SCRN
         JSR   SETCOL
         INX
         TXA
         JSR   PLOT
         JMP   cpyLoop
cpyDone  RTS

HighlightLine             ; highligh line in A
         TAX
         LDA   HighltCol
         JSR   SETCOL
         TXA
         LDY   H1
         INY              ; skip border
hlLoop   TXA
         JSR   PLOT
         INY
         CPY   H2
         BCC   hlLoop
         RTS
ShapeBounds LDA #$FF      ; Sets TempX = lowest Y, TempY = Highest Y in shape
         STA   TempX      ; Lowest value
         LDA   #00
         STA   TempY      ; high value
         LDX   #00
sboundsLoop INX           ; move to Y
         LDA   ShapePos,x
         CMP   TempX      ; check if lower than low
         BCS   sboundsHigher
         STA   TempX
sboundsHigher CMP TempY   ; check if higher than high
         BCC   sboundsLower ; pos < TempY/high
         STA   TempY
sboundsLower INX
         CPX   #08
         BCC   sboundsLoop
         RTS
ResetScore LDA #00
         STA   Score
         LDX   #01
         STA   Score,X
         RTS
AddScore CLC
         ADC   Score
         BCC   noRoll
         LDA   #01
         INC   Score,X
noRoll
         STA   Score
         RTS
SetScreen JSR  SETGR
         JSR   HOME
         JSR   SetBorder
         JSR   DrawBoundry
         RTS
DrawBoundry
         LDA   BoundryCol ; Set boundry colour
         JSR   SETCOL
         LDY   H1         ; Draw a line at bottom of screen
         LDA   V2
         JSR   HLINE
         LDA   #00        ; draw vertical line on left
         LDY   H1
         JSR   VLINE
         LDA   #00        ; draw vertical line on right
         LDY   H2
         JSR   VLINE
         RTS
SetBorder
         LDA   BoardHeight
         STA   V2
         LDA   #39
         CLC
         SBC   BoardWidth
         LSR              ; divide remaining in half
         STA   H1
         LDA   #39
         CLC
         SBC   H1
         STA   H2
         RTS

PrintHex JSR PRBYTE
         LDA #$A0
         JSR COUT
         RTS

ShowScore JSR  UP
         LDX   #00
scoreLoop LDA  SzScore,x
         BEQ   scoreDone
         JSR   COUT
         INX
         JMP   scoreLoop
scoreDone
                          ; Print decimal in X low / A High
         LDX   #01
         LDA   Score,x
         LDX   Score
         JSR   LINPRT
         JSR   CROUT
         RTS
ShowBye  LDX   #00
byeLoop  LDA   SzBye,x
         BEQ   byeDone
         JSR   COUT
         INX
         JMP   byeLoop
byeDone  JSR   CROUT
         RTS
ShowHitKey LDX #00
hitkeyLoop LDA SzHitKey,x
         BEQ   hitkeyDone
         JSR   COUT
         INX
         JMP   hitkeyLoop
hitkeyDone JSR CROUT
         RTS
Level    DB    #8         ; performance limiter
Score    DS    2          ; 16-bit score count
H1       DS    1          ; Left side of screen
                          ; Shape State, Position,Rotation
XPos     DS    1
YPos     DS    1
Rotation DS    1
CounterL DS    1          ; 16 bit counter
CounterH DS    1

ShapeOffset DS 1          ; offset of shapetable of current shape
ShapeCol DS    1          ; colour of shape
ShapePos DS    08         ;
TempX    DS    1
TempY    DS    1
Scratch  DS    1
CollisionCol DS 1         ; colour of last collision check
BoundryCol DB  #013
HighltCol DB   #$0E
BoardWidth DB  #12
BoardHeight DB #39
EscKey   DB    #$1B
SzScore  ASC   "               Score: "
         DB    0
SzHitKey asc   "         Hit a Key to resume"
         DB    0
SzBye    asc   "Bye"
         DB    0
SzGameOver asc "Game Over"
         DB    0

                          ;

Shapes   HEX   FF,00,00,FF,01,00 ; T shape
         HEX   00,FF,01,00,02,00 ; J Shape
         HEX   01,00,02,00,02,FF ; L Shape
         HEX   00,FF,01,00,01,FF ; O Shape
         HEX   FF,00,00,FF,01,FF ; Z Shape
         HEX   01,00,FF,FF,00,FF ; S Shape
         HEX   FF,00,01,00,02,00 ; I Shape
