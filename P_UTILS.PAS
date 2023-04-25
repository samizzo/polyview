Unit P_Utils;

Interface

Var
   TextSeg : Word;
   IsCGA   : Boolean;

Procedure Cls;
Procedure SetMode(ModeNum : Byte);
Procedure Writestr(X, Y : Word; Col : Byte; _dooby : String; Where : Word);
Procedure Writech(X, Y : Word; Col : Byte; _dooby : Char; Where : Word);
Function Getkey : Char;
Function KeyPressed : Boolean;
Procedure Cursoff;
Procedure NormCurs;
Procedure BlockCurs;
Procedure GotoXY(X, Y : Byte);
Procedure Frame(X1, Y1, X2, Y2 : Byte; Where : Word);
Procedure Inputstr(PromptStr : String;          { Prompting string         }
                     X, Y      : Byte;          { X,Y pos for prompt       }
                     Len       : Byte;          { Length of input str      }
                     InputCol  : Byte;          { colour of input          }
                     PromCol   : Byte;          { colour of prompt         }
                     Upper     : Boolean;       { True = convert to upcase }
                 var Defstr    : String);       { Default string to display}
Function Exists(Fname : String) : Boolean;


Implementation

Var
   InsMode,
   _Extended : Boolean;
   _Ch       : Char;

Procedure Cls; Assembler;
Asm
   mov ax, 0003h
   int 10h
End;

Procedure SetMode(ModeNum : Byte);
Begin
   Case ModeNum of
      0 : Asm
             mov ax, 0003h
             int 10h
          End;
      1 : Asm
             mov ax, 0003h
             int 10h

             mov ax, 0040h
             push ax
             mov di, 004ch
             pop es
             { es:di -> 0040:004c = page (regen buffer) size in bytes }
             mov word ptr es:[di], 2000h

             mov di, 0084h
             { es:di -> 0040:0084 = rows on screen minus one }
             mov byte ptr es:[di], 1dh

             mov di, 0063h
             { es:di -> 0040:0063 = CRTC base io port address }
             mov dx, es:[di] { should be 3d4h on VGA }

             mov ax, 0c11h
             out dx, ax

             mov ax, 0d06h
             out dx, ax

             mov ax, 3e07h
             out dx, ax

             mov ax, 0ea10h
             out dx, ax

             mov ax, 8c11h
             out dx, ax

             mov ax, 0df12h
             out dx, ax

             mov ax, 0e715h
             out dx, ax

             mov ax, 0616h
             out dx, ax

             mov dx, 03cch
             in al, dx
             and al, 33h
             or al, 0c4h
             mov dx, 03c2h
             out dx, al
          End;
      2 : Asm
             mov ah, 12h
             mov bl, 30h
             mov al, 01h { set 350 scanlines }
             int 10h

             mov ax, 0003h
             int 10h

             mov ax, 1112h { set 8x8 font }
             mov bl, 00h
             int 10h
          End;
      3 : Asm
             mov ah, 12h
             mov bl, 30h
             mov al, 02h { set 400 scanlines }
             int 10h

             mov ax, 0003h
             int 10h

             mov ax, 1112h { set 8x8 font }
             mov bl, 00h
             int 10h
          End;
   End;

   CursOff;
End;

Procedure Writestr(X, Y : Word; Col : Byte; _dooby : String; Where : Word);
Begin
   Asm
      { setup starting location }
      mov ax, where
      mov es, ax
      mov di, x
      add di, di
      mov ax, y
      shl ax, 5
      add di, ax
      shl ax, 2
      add di, ax

      { setup length of string and colour }
      xor cx, cx
      mov cl, byte ptr [_dooby] { length of string }
      dec cl
      js @nup
      inc cl

      mov ah, col

      mov si, 1

      { draw it }
     @looper:
      mov al, byte ptr [_dooby+si]
      mov es:[di], ax
      add di, 2
      inc si
      dec cx
      jnz @looper

      { done }
     @nup:
   End;
End;

Procedure Writech(X, Y : Word; Col : Byte; _dooby : Char; Where : Word); Assembler;
Asm
   { setup starting location }
   mov ax, where
   mov es, ax
   mov di, x
   add di, di
   mov ax, y
   shl ax, 5
   add di, ax
   shl ax, 2
   add di, ax

   { setup length of string and colour }
   mov al, _dooby
   mov ah, col

   { draw it }
   mov es:[di], ax

   { done }
End;

Function Getkey : Char; Assembler;
Asm
   cmp _extended, 1
   je @doextended

   mov ah, 10h
   int 16h

   or al, al
   jz @specialkey

   cmp al, 224d
   jne @noextended

   mov _extended, 1
   mov _ch, ah
   xor al, al
   jmp @noextended

  @specialkey:
   mov _extended, 1
   mov _ch, ah
   jmp @noextended

  @doextended:
   mov al, _ch
   mov _extended, 0

  @noextended:
End;

Function KeyPressed : Boolean; Assembler;
Asm
   mov ah, 11h
   int 16h
   jnz @nokey
   mov al, 1
   jmp @outahere

  @nokey:
   xor al, al

  @outahere:
End;

Procedure Cursoff; Assembler;
Asm
   mov ah, 03h
   xor bx, bx
   int 10h
   or ch, 20h
   mov ah, 01h
   int 10h
End;

Procedure NormCurs; Assembler;
Asm
   mov cx, 0c0dh                { 12, 13 = MDA/EGA/VGA normal size }
   mov al, iscga
   dec al
   jnz @nup
   mov cx, 0607h                { 06, 07 = CGA normal size         }

  @nup:
   mov ah, 01h
   int 10h
End;

Procedure BlockCurs; Assembler;
Asm
   mov cx, 000dh                { 00, 13 = MDA/EGA/VGA block size  }
   mov al, iscga
   dec al
   jnz @nup
   mov cx, 0007h                { 00, 07 = CGA block size          }

  @nup:
   mov ah, 01h
   int 10h
End;

Procedure GotoXY(X, Y : Byte); Assembler;
Asm
   mov ah, 02h
   xor bh, bh
   mov dl, x
   mov dh, y
   int 10h
End;

Procedure Frame(X1, Y1, X2, Y2 : Byte; Where : Word);
Var
   I, J : Byte;
Begin
   For I := Y1 to Y2 do
   For J := X1 to X2 do
   WriteCh(J, I, $1f, ' ', Where);

   For I := X1 to X2 do
   Begin
      WriteCh(I, Y1, $17, 'Ä', Where);
      WriteCh(I, Y2, $17, 'Ä', Where);
   End;

   WriteCh(X1, Y1, $17, 'Ú', Where);
   WriteCh(X2, Y1, $17, '¿', Where);
   WriteCh(X1, Y2, $17, 'À', Where);
   WriteCh(X2, Y2, $17, 'Ù', Where);

   For I := Y1+1 to Y2-1 do
   Begin
      WriteCh(X1, I, $17, '³', Where);
      WriteCh(X2, I, $17, '³', Where);
   End;

   For I := X1+2 to X2+2 do
   WriteCh(I, Y2+1, $08, Chr(Mem[Where:I*2 + (Y2+1)*160]), Where);

   For I := Y1+2 to Y2+1 do
   Begin
      WriteCh(X2+1, I, $08, Chr(Mem[Where:(X2+1)*2 + I*160]), Where);
      WriteCh(X2+2, I, $08, Chr(Mem[Where:(X2+2)*2 + I*160]), Where);
   End;
End;

Procedure Inputstr(PromptStr : String;          { Prompting string         }
                     X, Y      : Byte;          { X,Y pos for prompt       }
                     Len       : Byte;          { Length of input str      }
                     InputCol  : Byte;          { colour of input          }
                     PromCol   : Byte;          { colour of prompt         }
                     Upper     : Boolean;       { True = convert to upcase }
                 var Defstr    : String);       { Default string to display}
Var
   _I, _J, _X  : Byte;
   _str        : String;
   _key        : Char;

Begin
   Writestr(X, Y, PromCol, PromptStr, TextSeg);
   For _X := X+Length(PromptStr) to X+Length(PromptStr)+Len do
      Writech(_X, Y, InputCol, ' ', TextSeg);
   Writestr(X+Length(PromptStr), Y, InputCol, Defstr, TextSeg);

   InsMode := False;
   NormCurs;
   _X := X+Length(PromptStr) + Length(Defstr);
   X := X+Length(PromptStr);
   _I := Length(Defstr)+1;
   GotoXY(_X, Y);
   _str := Defstr;

   Repeat
      _key := Getkey;
      If Upper then _key := Upcase(_key);
      If _key = #0 then
      Begin
         _key := Getkey;
         { #75 left, #77 right }
         If _key = #77 then
         Begin
            If _X <= Length(_str)+X-1 then
            Begin
               Inc(_X);
               Inc(_I);
            End;
         End
            else
         If _key = #75 then
         Begin
            If _X > X then
            Begin
               Dec(_X);
               Dec(_I);
            End;
         End
            else
         If _key = #71 then
         Begin
            _X := X;
            _I := 1;
         End
            else
         If _key = #79 then
         Begin
            _X := X+Length(_str);
            _I := Length(_str)+1;
         End
            else
         If _key = #83 then
         Begin
            If _X <> X+Length(_str) then
            Delete(_str, _I, 1);
         End
            else
         If _key = #82 then
         Begin
            Insmode := not Insmode;
            If Insmode then BlockCurs else NormCurs;
         End;
      End
         else
      If _key = #8 then
      Begin
         If _I > 1 then
         Begin
            Dec(_I);
            Delete(_str, _I, 1);
            Dec(_X);
         End;
      End
         else
         If (_key <> #13) and (_key <> #27) then
         If InsMode then
         Begin
            If Length(_str) < Len+1 then
            Begin
               Insert(_key, _str, _I);
               Inc(_I);
               Inc(_X);
            End;
         End
            else
         Begin
            If _X <= X+Len then
            Begin
               Delete(_str, _I, 1);
               Insert(_key, _str, _I);
               Inc(_I);
               Inc(_X);
            End;
         End;

      Writestr(X, Y, InputCol, _str, TextSeg);
      For _j := X+Length(PromptStr)+Length(_str) to X+Length(PromptStr)+Len do Writech(_j, Y, InputCol, ' ', TextSeg);
      GotoXY(_X, Y);
   Until _key in [#27, #13];

   If _key = #13 then Defstr := _str;
End;

Function Exists(Fname : String) : Boolean;
Var
   F : File;
Begin
{$I-}
   Assign(F, Fname);
   Reset(F);
   Close(F);
   If IOresult <> 0 then Exists := False else Exists := True;
End;

Begin
   TextSeg := $B800;
   _Extended := False;
   IsCGA := False;
End.