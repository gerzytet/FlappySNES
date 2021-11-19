arch 65816
norom
math pri on

; I don't really understand this marco.
macro seek(offset)
  org (((<offset>&$7F0000)>>1)|(<offset>&$7FFF))
  base <offset>
endmacro

%seek($8000); Fill Up to $FFFF (Bank 15) With Zero Bytes
incsrc "LIB/SNES.asm"        ; Include SNES Definitions
incsrc "LIB/SNES_HEADER.asm" ; Include Header & Vector Table
incsrc "LIB/SNES_GFX.asm"    ; Include Graphics Macros
incsrc "macros.asm"

; Variable Data
{
%seek(WRAM) ; 8Kb WRAM Mirror ($0000..$1FFF)
TileMap:
  ;mirror of first 1k of BG1 tilemap starts here
  fillbyte $00
  fill $400
;record format:
;for each n pipes (where n = NPipes)
;  1 byte x position (0..63)
;  4 bits y position of the top from the top (0..15), 4 bits gap length
;  all units in tiles
;I'll assume a limit of 6 pipes
;pipe data size, 6 * 2 bytes
NPipes:
  db $00
PipeData:
  fill $0C ;12 bytes
;other variables
ScrollXL:
  db $00
ScrollXH:
  db $00
BirdY:
  dw $0000
BirdV:
  dw $0000
RNG:
  db $00
IsPressed:
  db $00
NextPipeIndex:  ;index of the next pipe to randomize, times 2
  db $00
PendingPipeUpdate:
  db $00   ;1 if the pipe in NextPipeIndex has been resized and needs to be rewritten
Temp:
  dw $0000
IsCollision:
  db $00
}
; constants
{
!BIRD_ACCELERATION_16 = $0012
!BIRD_X_OFFSET_8 = $32
!BIRD_X_OFFSET_16 = $0032
!BIRD_SPRITE_WIDTH_16 = $0010
!PIPE_WIDTH_16 = $001A
!PIPE_PADDING_16 = $0003
}

%seek($8000)
Start: {

  %SNES_INIT(!SLOWROM) ; Run SNES Initialisation Routine
  
  %LoadPAL(PipesPalFile, $00, datasize(PipesPalFile), 0)
  %LoadPAL(BirdPalFile,  $80, datasize(BirdPalFile),  0)
  %LoadVRAM(PipesFile, $0000, datasize(PipesFile),    0)
  %LoadVRAM(BirdFile, $4000,  datasize(BirdFile),     0)
  
  ; Setup Video
  lda.b #$10       ; DCBAPMMM: M = Mode, P = Priority, ABCD = BG1,2,3,4 Tile Size
  sta.w REG_BGMODE ; $2105: BG Mode 0, Priority 0, BG1 16x16, BG2-4 8x8 
  
  ;store 0 to all scroll registers
  stz.w REG_BG1HOFS
  stz.w REG_BG1HOFS
  stz.w REG_BG2HOFS
  stz.w REG_BG2HOFS
  stz.w REG_BG3HOFS
  stz.w REG_BG3HOFS
  stz.w REG_BG4HOFS
  stz.w REG_BG4HOFS
  
  stz.w REG_BG1VOFS
  stz.w REG_BG1VOFS
  stz.w REG_BG2VOFS
  stz.w REG_BG2VOFS
  stz.w REG_BG3VOFS
  stz.w REG_BG3VOFS
  stz.w REG_BG4VOFS
  stz.w REG_BG4VOFS
  
  stz.w REG_BG12NBA ; $210B: BG1 Tile Address = $0000, BG2 Tile Address = $0000 (VRAM Address / $1000)
  lda.b #$04 ;$1 * $400 base bg1 tile map address, 00 size (32x32 tilemap)
  sta.w REG_BG1SC
  
  ;test tile code, for reference
;  lda.b #$80 ;increment $2116 (VRAM address) when writing to $2119
;  sta.w REG_VMAIN
;  ldx.w #$0400 ;start tile map address at 0x400
;  stx.w REG_VMADDL
;  ;vhopppcc cccccccc
;  ;00000000 00000010
;  ldx.w #$0002 ;map entry 1
;  stx.w REG_VMDATAL

;  lda.b #$80 ;increment $2116 (VRAM address) when writing to $2119
;  sta.w REG_VMAIN
;  ldx.w #$0400 ;start tile map address at 0x400
;  stx.w REG_VMADDL
;  ldx.w TileMap
;  stx.w REG_VMDATAL

  ;ldx.w #$0002
  ;stx.w TileMap ;store map entry to wram mirror
  
  lda.b #%00000001
  sta.w REG_OBSEL ;sssnnbbb, s=size, n=name, b=base address.  b = 001, rest are 0
  
  ;register bird sprite
  stz.w REG_OAMADDH ;OAM address = $00...
  stz.w REG_OAMADDL ;00
  stz.w REG_OAMDATA ;x = 00000000
  stz.w REG_OAMDATA ;y = 00000000
  stz.w REG_OAMDATA ;c = 00000000, first sprite tile
  lda.b #$30
  sta.w REG_OAMDATA ;vhoopppN, no hv flip, priority = 3, sprite pallete 0, no name
  
  lda.b #$01
  sta.w REG_OAMADDH ;OAM addres = $01...
  stz.w REG_OAMADDL ;00
  lda.b #$02 ;s = 1, X = 0
  sta.w REG_OAMDATA
  
  .SetupPipesData: ;some default data
    lda.b #$06
	sta.w NPipes ;6 pipes
	
	;macro SETPIPE(ID, X, LENPOS) 
	;  lda.b {X}
	;  sta.w PipeData + {ID} << 1
	;  lda.b {LENPOS}
	;  sta.w PipeData + {ID} << 1 + 1
	;}
	
	lda.b #$08 ;x = 8
    sta.w PipeData	
	lda.b #$25 ;len = 2, gap = 5
	sta.w PipeData+1
	
	lda.b #$12 ;x = 18
	sta.w PipeData+2
	lda.b #$35 ;len = 3, gap = 5
	sta.w PipeData+3
	
	lda.b #$1c ;x = 28
    sta.w PipeData+4
	lda.b #$54 ;len = 5, gap = 4
	sta.w PipeData+5
	
	lda.b #$26 ;x = 38
    sta.w PipeData+6
	lda.b #$84 ;len = 8, gap = 4
	sta.w PipeData+7
	
	lda.b #$2E ;x = 46
    sta.w PipeData+8
	lda.b #$74 ;len = 7, gap = 4
	sta.w PipeData+9
	
	lda.b #$38 ;x = 56
	sta.w PipeData+10
	lda.b #$64 ;len = 6, gap = 4
	sta.w PipeData+11

  jsr DrawAllPipes_ax
  
  ;transfer $400 bytes from TileMap ($0000) to BG1 tile map ($0400, but apparently it only works if I put $800? odd.)
  ;answer: because, $400 is the word address, and $800 is the byte address.
  %LoadVRAM(TileMap, $0800, $0400, 0)
  
  lda.b #%00010001   ; Enable BG1, OBJ
  sta.w REG_TM ; $212C: Main Screen Designation
  
  lda.b #%00001111 ; Turn on screen, full brightness
  sta.w REG_INIDISP
  
  lda.b #$81
  sta.w REG_NMITIMEN  ;enable NMI V-blank interrupt and auto-joypad read
  
  lda.b #$00
  sep #%00010000 ;8 bit index registers
  ldx.b #$00
  ldy.b #$00
  }
  MainLoop: {
    jsr AdvanceRNG_ao
	
	lda.w ScrollXL
	inc
	sta.w ScrollXL ;/TODO
	bne +
	  lda.w ScrollXH
	  inc
	  and #$01
	  sta.w ScrollXH
	  jmp +
	+
	
	jsr DoPipeUpdates_ax
	
	%A()
	jsr CollisionCheck_Ax
	%a()
	
    wai
	
	
	
	lda.w ScrollXL
	sta.w REG_BG1HOFS
	lda.w ScrollXH
	sta.w REG_BG1HOFS
    
	jsr WritePipeUpdates_ax
	
	-
	lda.w REG_HVBJOY
	and #$01
	bne -
	lda.w REG_JOY1L
	
	rep #%00010000 ;16 bit index registers
	and #$80
	beq + ;if a is not pressed, jump over
	  lda.w IsPressed
	  bne ++
	    lda.w RNG
		eor.w BirdV
		sta.w RNG
	    ldx.w #$FE00
	    stx.w BirdV
		lda.b #$01
		sta.w IsPressed
		jmp ++
	+
	stz.w IsPressed
	++
	
	rep #%00100000 ;16 bit a register
	
	lda.w BirdV
	clc
	adc #!BIRD_ACCELERATION_16
	sta.w BirdV
	lda.w BirdY
	clc
	adc BirdV
	sta.w BirdY
	xba
	
	sep #%00010000 ;8 bit index registers
	sep #%00100000 ;8 bit a register
	
	jsr HandleCollision_ax
	
	stz.w REG_OAMADDH ;OAM address = $00...
    stz.w REG_OAMADDL ;00
	
	ldx.b #!BIRD_X_OFFSET_8
	stx.w REG_OAMDATA ;x = 50
	sta.w REG_OAMDATA ;y = a
  jmp MainLoop
}

  VBlank:
    rti

.Loop:
  jmp .Loop

;assumes 8 bit accumulator
AdvanceRNG_ao: {
  lda.w RNG
  asl
  asl
  adc RNG
  inc
  sta.w RNG
  rts
}
;draw all pipes from memory
;destroys a, x, and y
DrawAllPipes_ax: {
  lda.w NPipes
  asl
  tay
  .PipeLoop:
    dey
	dey
	lda.w PipeData,y      ;x coordinate
	tax
	lda.w PipeData+1,y    ;top length/gap
	
	phy
	jsr DrawPipe_aX
	ply
	cpy #$0000
	bne .PipeLoop
  rts
}

;subroutine DrawPipe
;args:
;  a: top length, gap length
;  x: x coordinate
;expects 16 bit index registers, and y=0
DrawPipe_aX: {
  pha     ;backup a
  and #$F0 ;isolate top length
  
  lsr #$4
  rep #%00100000 ; 16-bit a register
  and #$00FF
  tay ;y = a
  
  jmp .YTest
  .DrawTop:
      dey
	  lda.w #$0002 ;tile 1
	  sta.w TileMap,x
	  inx
	  inx
	  lda.w #$4002 ;tile 1, horizontal flip
	  sta.w TileMap,x
	  inx
	  inx
	  
	  jsr NextRow
	  
  .YTest:
	  cpy.w #$0000
	  bne .DrawTop
  .DrawTopTip:
      lda.w #$0004 ;tile 2
	  sta.w TileMap,x
	  inx
	  inx
	  lda.w #$4004 ;tile 2, horizontal flip
	  sta.w TileMap,x
	  inx
	  inx
	  jsr NextRow
  
  ;recall gap length
  lda.w #$0000 ;reset a
  sep #%00100000
  pla
  and #$0F
  rep #%00100000 ; 16-bit a register
  tay
  
  .DrawGap:
      dey
	  lda.w #$0000
	  sta.w TileMap,x
	  inx
	  inx
	  sta.w TileMap,x
	  inx
	  inx
	  jsr NextRow
	  cpy #$0000
	  bne .DrawGap 
  .DrawBottomTip:
      lda.w #$8004 ;tile 2, v flip
	  sta.w TileMap,x
	  inx
	  inx
	  lda.w #$C004 ;tile 2, vh flip
	  sta.w TileMap,x
	  inx
	  inx
	  jsr NextRow
  .DrawBottom:
      lda.w #$0002 ;tile 1
	  sta.w TileMap,x
	  inx
	  inx
	  lda.w #$4002 ;tile 1, horizontal flip
	  sta.w TileMap,x
	  inx
	  inx
	  jsr NextRow
	  
	  cpx #$0400
	  bcc .DrawBottom
  
  lda.w #$0000
  sep #%00100000 ;8 bit a register
  rts
}

;adds 60 to x.  helper for DrawPipe
NextRow: {
  ;jump to next row - 4 by adding 60 to x
  pha ;backup a
  txa ;a = x
  clc
  adc #$003c
  tax ;x = a
  pla
  rts
}
;adds 64 to x.  helper for DrawPipe
NextRowFull: {
  ;jump to next row by adding 64 to x
  pha ;backup a
  txa ;a = x
  clc
  adc #$0040
  tax ;x = a
  pla
  rts
}
;destroys a and x and y
DoPipeUpdates_ax: {
  ;tile index = scroll index / 16
  lda.w ScrollXL
  bit #$0F
  beq +
    rts
  +
  
  lda.w NextPipeIndex
  bne +
    lda.w ScrollXH
	beq +
	  rts
  +
  
  lda.w ScrollXL
  and #$F0
  clc
  rol
  ora ScrollXH
  rol
  rol
  rol
  rol
  rol
  ;subtract 4 from the position so the updated pipe is offscreen by the time it tried to update
  sec
  sbc #$04
  ldx.w NextPipeIndex

  ldy PipeData,x ;for later
  cmp PipeData,x
  bpl + ;if the current x tile index is more than the previous tile we need to update
    rts
  +
  
  lda.w RNG
  ;y position, then gap length
  ;y from 1 - 8 (0 - 7 + 1)
  ;length from 4 to 5
  and #%01110001
  clc
  ;add 4 to the top 4 bits, 4 to the bottom
  adc #%00010100
  inx
  sta.w PipeData,x
  
  tyx
  rep #%00010000 ; 16-bit index register
  ldy.w #$0000
  jsr DrawPipe_aX
  sep #%00010000 ; 8-bit index register
  
  ldx.b #$01
  stx.w PendingPipeUpdate
  rts
}
;destroys a, x, and y
;returns 8 bit a and index
;writes changes to the next pipe index from tilemap to BG1
WritePipeUpdates_ax: {
  ldx.w PendingPipeUpdate
  bne +
    rts
  +
  stz.w PendingPipeUpdate

  ldx.w NextPipeIndex
  lda.w PipeData,x ;get x position
  rep #%00110000 ;16 bit all registers
  and #$00FF
  tax
  
  lda.w #$0800
  clc
  stx.w Temp
  adc Temp
  lsr
  ;a = $400 + x_position >> 1
  sta.w REG_VMADDL
  
  ldy.w #$0010
  clc
  -
  lda.w TileMap,x
  sta.w REG_VMDATAL
  inx
  inx
  lda.w TileMap,x
  sta.w REG_VMDATAL
  
  pha
  txa
  clc
  adc #$083E ;(0x400 + 31) * 2
  ror
  sta.w REG_VMADDL
  rol
  sec
  sbc #$0800 ;(0x400) * 2
  tax
  pla
  
  dey
  cpy #$0000 ;should not set carry, as long as y doesn't overflow
  bne -
  
  clc
  lda.w NextPipeIndex
  adc #$0002
  sta.w NextPipeIndex
  lsr
  sep #%00110000 ;8 bit all registers
  cmp NPipes
  bne +
    stz.w NextPipeIndex
  +
  rts 
}
CollisionCheck_Ax: {
  stz.w IsCollision
  phy
  ldy.w NPipes
  -
    dey
	tyx
    jsr IsCollidingHelper_Ax
    cpy #$00
  bne -
  ply
  rts
}
; test if the bird is on top of a given pipe
; pipe index to check in x
IsCollidingHelper_Ax: {
  ; get screen x
  ; add flappy x
  ; add flappy sprite width
  ; mod to 9 bit value
  ; last pixel = value
  ; get tile index of pipe
  ; multiply by 8
  ; if last pixel >= tile pixel index
  ;   last pixel -= sprite width
  ;   if last pixel < tile pixel index
  ;     yes collision
  ;   tile pixel index += pipe width
  ;   if last pixel < tile pixel index
  ;     yes collision
  ;TODO: y test
  pha
  
  txa
  clc
  asl
  tax
  
  lda.w ScrollXL
  clc
  adc #!BIRD_X_OFFSET_16
  adc #!BIRD_SPRITE_WIDTH_16
  and #$01FF
  sta.w Temp
  lda.w PipeData,x
  and #$00FF
  clc
  asl
  asl
  asl
  adc #!PIPE_PADDING_16
  cmp Temp ;tile index - sprite, possible collision if negative or zero
  bpl .NoCollision
    pha
	lda.w Temp
	sec
	sbc #!BIRD_SPRITE_WIDTH_16
	sta.w Temp
	pla
	
	cmp Temp ;beginning of tile - beginning of bird, positive or zero means collision
    bmi +
	  jmp .Collision
    +
	
	clc
	adc #!PIPE_WIDTH_16-1
	cmp Temp ; end of tile - beginning of bird, positive or zero means collision
	bmi +
	  jmp .Collision
	+
	
  .NoCollision:
  pla
  rts
  .Collision
  pla
  ldx.b #$01
  stx.w IsCollision
  rts
}
HandleCollision_ax: {
  pha
  stz.w REG_OAMADDH
  lda.b #$01
  sta.w REG_OAMADDL
  
  lda.w IsCollision
  ;vhoopppN, no hv flip, priority = 3, sprite pallete 0 or 1, no name
  clc
  asl
  ora #$30
  stz.w REG_OAMDATA
  sta.w REG_OAMDATA
  
  pla
  rts
}


;tiles
;BANK 1
%seek($18000)
PipesFile:
incbin "pipes.bin" ; 352 bytes
PipesPalFile:
incbin "pipes.pal" ; 8   bytes
BirdFile:
incbin "bird.bin"  ; 320 bytes
BirdPalFile:
incbin "bird.pal"  ; 12 bytes
EndFiles: