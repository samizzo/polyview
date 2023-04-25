Unit P_Viewer;

Interface

Uses DOS, P_Utils, P_Config;

Const
   MaxSpeed  = 24;
   MaxPgSpd  = 48;
   SpeedAdd  = 1;

   _Esc      = $01;
   _Up       = $48;
   _Down     = $50;
   _PgUp     = $49;
   _PgDown   = $51;
   _Home     = $47;
   _End      = $4f;
   _Enter    = $1c;
   _F2       = $3c;

Var
   Keydown   : Array [0..127] of Boolean;
   Oldkbint  : Procedure;

   Adder,
   Scanline  : Integer;

   Key       : Byte;

   MaxLine,
   Redraw    : Longint;

   RedrawIt  : Boolean;

Procedure DisplayBuffer(Buf : Word; Scanlines : Byte);

Implementation

{$F+}
Procedure MyKbd; Interrupt;
Begin
   Asm
      in al, 60h
      mov bl, al
      and bl, 7fh
      xor bh, bh

      mov ah, 1
      and al, 80h
      jz @nup
      xor ah, ah

     @nup:
      mov byte ptr keydown[bx], ah

      mov al, 20h
      out 20h, al
   End;
End; { of Procedure MyKbd }
{$F-}

Procedure DisplayBuffer(Buf : Word; Scanlines : Byte);
Var
   Temp, Temp2 : Integer;
   TempPtr : Pointer;
Begin
   Temp := Scanlines-1;
   ScanLine := 0;
   Redraw := 0;
   Adder := 0;
   Key := 0;
   Temp2 := DefaultTextMode;

   Fillchar(Keydown, Sizeof(Keydown), 0);
   Getintvec($09, @Oldkbint);
   Setintvec($09, @Mykbd);
   Move(Mem[Buf:0], Mem[TextSeg:0], 32000);

   Repeat
      If Keydown[_F2] then
      Begin
         Inc(Temp2);
         If Temp2 > 3 then Temp2 := 0;
         SetMode(Temp2);
         Keydown[_F2] := False;
         RedrawIt := True;
         ScanLines := TextModes[Temp2].ScanLines;
         Temp := ScanLines-1;
      End;

      Asm
         mov si, offset keydown
         mov bx, adder
         mov cx, scanline
         db 66h; mov di, word ptr redraw

(*         { check for F2 }
         cmp byte ptr [si+_f2], 1
         jne @no_f2
         inc temp2
         cmp temp2, 4
         jne @no_clip
         mov temp2, 0

        @no_clip:
         mov bx, temp2
         mov ax, 17d
         mul bx
         mov bx, ax

        @no_f2:
*)
         { check for up }
         cmp byte ptr [si+_up], 1
         jne @no_up

         cmp bx, -maxspeed
         jle @outa_up
         dec bx
         jmp @outa_up

        @no_up:
         cmp bx, 0
         jge @outa_up
         inc bx

      @outa_up:

         { check for down }
         cmp byte ptr [si+_down], 1
         jne @no_down

         cmp bx, maxspeed
         jge @outa_down
         inc bx
         jmp @outa_down

        @no_down:
         cmp bx, 0
         jle @outa_down
         dec bx

      @outa_down:

         { check for page up }
         cmp byte ptr [si+_pgup], 1
         jne @outa_pgup

         cmp bx, -maxpgspd
         jle @outa_pgup
         sub bx, 4

      @outa_pgup:

         { check for page down }
         cmp byte ptr [si+_pgdown], 1
         jne @outa_pgdown

         cmp bx, maxpgspd
         jge @outa_pgdown
         add bx, 4

      @outa_pgdown:

         { check for home key }
         cmp byte ptr [si+_home], 1
         jne @outa_home

         xor bx, bx
         xor cx, cx
         db 66h; xor di, di
         mov redrawit, 1

      @outa_home:

         { check for end key }
         cmp byte ptr [si+_end], 1
         jne @outa_end

         xor bx, bx
         xor cx, cx
         db 66h; mov di, word ptr maxline
         mov redrawit, 1

      @outa_end:

         add cx, bx { scanline = scanline + adder }

         cmp cx, temp { 15d }
         jle @not_too_big

         mov ax, cx
         mov dl, scanlines { 16 }
         idiv dl { scanline div totalscanlines }
         mov cl, ah
         xor ch, ch { scanline = scanline mod totalscanlines }

         xor ah, ah
         mov dx, ax
         shl ax, 5
         shl dx, 7
         add ax, dx { ax = 160*(scanline div totalscanlines }

         add di, ax

         mov redrawit, 1

        @not_too_big:

         cmp cx, 0d
         jge @not_too_small

         mov ax, cx
         mov dl, scanlines { 16d }
         idiv dl

         mov cl, ah
         xor ch, ch
         add cl, byte ptr temp { 15d }
         mov scanline, cx

         dec al
         cbw
         mov dx, ax
         sal ax, 5
         sal dx, 7
         add ax, dx
         db 66h; cbw
         db 66h; add di, ax

         mov redrawit, 1

        @not_too_small:

         db 66h; cmp di, 0
         jge @not_at_top

         xor bx, bx
         xor cx, cx
         db 66h; mov di, 0; dw 0;

        @not_at_top:

         db 66h; cmp di, word ptr maxline
         jl @not_at_bottom

         xor bx, bx
         xor cx, cx
         db 66h; mov di, word ptr maxline

        @not_at_bottom:

         mov adder, bx
         mov scanline, cx
         db 66h; mov word ptr redraw, di

         cli

         mov dx, 3dah
        @l1:
         in al, dx
         and al, 08h
         jz @l1
        @l2:
         in al, dx
         and al, 08h
         jnz @l2

         mov dx, 3d4h
         mov al, 08h
         out dx, al
         inc dx
         mov ax, scanline
         out dx, al

         cmp redrawit, 1
         jne @noredraw

         mov ax, textseg
         mov es, ax
         xor di, di

         mov dx, ds
         mov si, word ptr redraw
         mov ax, buf
         mov ds, ax

         mov cx, 2160d
         db 66h; rep movsw

         mov ds, dx

        @noredraw:

         sti
      End;
   Until Keydown[_Esc] or Keydown[_Enter];

   SetIntVec($09, @OldKbint);
End;

End.