Unit P_Saver;

Interface

Function Star_Saver(Buf : Word) : Boolean;

Implementation

Uses P_DOSmem;

Const
   NumStars = 1024;

Var
   Xval, Yval: Array [0..NumStars] of Integer;
   Zpos      : Array [0..NumStars] of Byte;
   I         : Word;
   Ytab      : Array [0..199] of Word;

Function Star_Saver;
Begin
   Fillchar(Mem[Buf:0], 65535, 0);

   For I := 0 to 199 do Ytab[I] := I*320;

   Asm
      mov ax, 0013h
      int 10h
   End;

   Randomize;

   For I := 0 to NumStars do
   Begin
      Xval[I] := Random(320)-160;
      Yval[I] := Random(200)-100;
      Zpos[I] := Random(254)+1;
   End;

   Asm
      { set up the palette }
      xor cx, cx
      mov dx, 3c8h                   { port for colour to change }

     @palloop:
      mov al, cl
      out dx, al                     { send it }
      neg al                         { make negative }
      shr al, 2
      inc dx                         { 3c9h = port for rgb values }
      out dx, al                     { send red }
      out dx, al                     { send green }
      out dx, al                     { send blue }
      dec dx                         { back to colour port }

      inc cl
      jnz @palloop                   { for all 256 colours }

      { this is the whole main loop }
     @mainloop:
      mov bx, numstars
      mov si, numstars*2
      mov ax, buf                    { es:di -> virtual screen }
      mov es, ax

      { the drawing loop }
     @drawloop:
      xor ch, ch
      mov cl, byte ptr [zpos+bx]
      or cx, cx
      jz @nup                        { if zpos is 0, don't do anything }

      { y = ((yval[i] shl 7) div zpos[i]) + 100 }
      mov ax, word ptr [yval+si]
      sal ax, 7                      { sal -> to keep sign intact }
      cwd
      idiv cx                        { do division -> dx:ax / cx }
      add ax, 100d
      cmp ax, 199d
      ja @nup                        { outa the screen? }
      mov di, ax
      { di = y }

      { x ((xval[I] shl 7) div zpos[I]) + 160 }
      mov ax, word ptr [xval+si]
      sal ax, 7
      cwd
      idiv cx
      add ax, 160d
      cmp ax, 319d
      ja @nup
      { ax = x }

      add di, di
      mov di, word ptr [ytab+di]     { get position from y-lookup table }
      add di, ax                     { add x-value }
      mov es:[di], cl                { chuck pixel on screen }

     @nup:

      sub byte ptr [zpos+bx], 3      { change zpos }
      sub si, 2
      dec bx
      jnz @drawloop                  { for all the stars }

      { wait for vertical retrace }
      mov dx, 3DAh                   { retrace port }
     @l1:
      in al, dx
      and al, 08h                    { test bit 3 }
      jnz @l1
     @l2:
      in al, dx
      and al, 08h                    { test bit 3 }
      jz @l2

      mov dx, ds                     { save ds }
      mov ax, 0a000h
      mov es, ax
      xor di, di                     { es:di -> video memory }
      mov ax, buf
      mov ds, ax
      xor si, si                     { ds:si -> virtual page }
      mov cx, 16000d
      db 66h; rep movsw              { copy virtual page -> video memory }
      mov ds, dx                     { restore ds }

      mov es, ax                     { es:di -> virtual page }
      xor di, di
      mov cx, 16000d
      db 66h; xor ax, ax
      db 66h; rep stosw              { clear virtual page }

      in al, 60h
      cmp al, 1
      je @endstars
      cmp al, 28
      je @endstars

      jmp @mainloop

     @endstars:

      mov ax, 0003h
      int 10h

      xor ax, ax
      mov es, ax
      mov di, 041ch
      mov ax, es:[di]
      mov es:[di-2], ax
   End;
End;

End.