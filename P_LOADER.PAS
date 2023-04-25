{$I-}

Unit P_Loader;

Interface

Var
   NumLines : Word;

Function Load_ANSi_Text(Fname : String; MaxY : Byte; Buf, TempBuf : Word) : Boolean;
Function Load_RIP(Fname : String; Buf : Word) : Boolean;

Implementation

Uses P_RIP;

Var
   { Load_ANSi_Text vars }
   HighInt,
   ForeAttr,
   BackAttr,
   Blink    : Byte;

   Num,
   Fsize    : Longint;

   I, J, K  : Word;

   T, X, Y,
   Xsave,
   Ysave    : Integer;

   F        : File;

   Ch1, Ch2 : Char;

   Temp1,
   ANSIstr  : String;

   SemiPos  : Array [0..7] of Byte;
   AttrStr  : Array [0..7] of String;

Function Load_ANSi_Text(Fname : String; MaxY : Byte; Buf, TempBuf : Word) : Boolean;
{ Loads an ANSi/ASCii/Text file 'fname' and stores it in 'buf' }
Begin
   Load_ANSi_Text := True;

   Fillchar(Mem[Buf:0], 65535, 0);
   Fillchar(Mem[TempBuf:0], 65535, 0);

   ForeAttr := $07;
   BackAttr := $00;
   Blink := $00; { 0 or 128 }
   HighInt := $00; { 0 or 8 }

   X := 0;
   Y := 0;

   Xsave := 1;
   Ysave := 1;

   Assign(F, Fname);
   Reset(F, 1);
   If IOresult <> 0 then
   Begin
      Load_ANSi_Text := False;
      Exit;
   End;

   Fsize := Filesize(F);
   If Fsize > 65535 then Fsize := 65535;
   Blockread(F, Mem[TempBuf:0], Fsize);
   Num := 0;

   Repeat
{      BlockRead(F, Ch1, 1);}

      Ch1 := Chr(Mem[TempBuf:Num]);
      Inc(Num);

      If Ch1 = #27 then
      Begin
{         BlockRead(F, Ch2, 1);}

         Ch2 := Chr(Mem[TempBuf:Num]);
         Inc(Num);

         If Ch2 = '[' then
         Begin
            { we've got an ANSI escape sequence }
            ANSIstr := '';
            Repeat
               {BlockRead(F, Ch1, 1);}
               Ch1 := Chr(Mem[TempBuf:Num]);
               Inc(Num);

               ANSIstr := ANSIstr + Ch1;
            Until Ch1 in ['A', 'B', 'C', 'D', 'H', 'f', 's', 'u', 'J', 'K', 'm', 'h', 'l', 'p'];
{            Until Upcase(Ch1) in ['A'..'Z'];}

            { process ANSI command }
            Case Ch1 of
               'A' : Begin { cursor up command }
                        I := Pos('A', ANSIstr);
                        Delete(ANSIstr, I, 1);
                        Val(ANSIstr, I, J);
                        If ANSIstr = '' then
                           Y := Y - 1
                        else
                           Y := Y - I;
                        If Y < 0 then Y := 0;
                     End;
               'B' : Begin { cursor down command }
                        I := Pos('B', ANSIstr);
                        Delete(ANSIstr, I, 1);
                        Val(ANSIstr, I, J);
                        If ANSIstr = '' then
                           Y := Y + 1
                        else
                           Y := Y + I;
                     End;
               'C' : Begin { cursor right command }
                        I := Pos('C', ANSIstr);
                        Delete(ANSIstr, I, 1);
                        Val(ANSIstr, I, J);
                        If ANSIstr = '' then
                           X := X + 1
                        else
                           X := X + I;
                        If X > 79 then X := 79;
                     End;
               'D' : Begin { cursor left command }
                        I := Pos('D', ANSIstr);
                        Delete(ANSIstr, I, 1);
                        Val(ANSIstr, I, J);
                        If ANSIstr = '' then
                           X := X - 1
                        else
                           X := X - I;
                        If X < 0 then X := 0;
                     End;
               'H',
               'f' : Begin { move cursor to row/col command }
                        I := Pos(';', ANSIstr);
                        If I = 0 then
                        Begin
                           { either a row or nothing was specified }
                           I := Pos('H', ANSIstr);
                           If I = 0 then I := Pos('f', ANSIstr);
                           Delete(ANSIstr, I, 1);
                           Val(ANSIstr, I, J);
                           If I = 0 then { nothing }
                           Begin
                              X := 0;
                              Y := 0;
                           End else
                           Begin { only a row }
                              Y := I - 1;
                              If Y > 24 then X := 24;
                              X := 0;
                           End;
                        End else
                        Begin
                           { both a row and a col were specified }
                           Temp1 := ANSIstr;
                           Delete(Temp1, I, Length(Temp1));
                           Delete(ANSIstr, 1, I);
                           I := Pos('H', ANSIstr);
                           If I = 0 then I := Pos('f', ANSIstr);
                           Delete(ANSIstr, I, 1);
                           { temp1 = row }
                           { ansistr = col }
                           Val(ANSIstr, I, K);
                           Val(Temp1, J, K);
                           X := I - 1;
                           Y := J - 1;
                           If J = 0 then Y := 0;
                        End;
                     End;
               's' : Begin { save cursor location command }
                        Xsave := X + 1;
                        Ysave := Y + 1;
                     End;
               'u' : Begin { restore cursor location command }
                        X := Xsave - 1;
                        Y := Ysave - 1;
                     End;
               'J' : Begin { clear screen command }
                        { however, 2J is the clear screen command }
                        If ANSIstr = '2J' then
                        Begin
                           X := 0;
                           Y := 0;
                           Fillchar(Mem[Buf:0], 65535, 0);
                        End;
                     End;
               'K' : Begin { erase from cursor pos to end of line command }
                        For I := X to 79 do
                        Begin
                           Mem[Buf:(I*2)+(Y*160)] := 32;
                           Mem[Buf:(I*2)+(Y*160)+1] := ForeAttr+(BackAttr shl 4)+Blink+HighInt;
                        End;
                     End;
               'm' : Begin { set attributes command }
                        J := 0;
                        Fillchar(SemiPos, Sizeof(SemiPos), 0);
                        For I := 1 to Length(ANSIstr) do
                        Begin
                           If ANSIstr[I] = ';' then
                           Begin
                              SemiPos[J] := I;
                              Inc(J);
                           End;
                        End;

                        If J > 0 then { if there are semicolons }
                        Begin
                           Fillchar(AttrStr, Sizeof(AttrStr), 0);
                           For I := 0 to J do { do for all semicolons }
                           Begin { get codes for each semicolon }
                              K := 0;
                              Repeat
                                 Inc(K);
                              Until ANSIstr[K] in [';', 'm'];
                              Temp1 := ANSIstr;
                              Delete(Temp1, K, Length(Temp1));
                              AttrStr[I] := Temp1;
                              Delete(ANSIstr, 1, K);
                           End;

                           For I := 0 to J do
                           Begin
                              Val(AttrStr[I], K, T);
                              Case K of
                                 0 : Begin { attributes off }
                                        Blink := $00;
                                        ForeAttr := $07;
                                        BackAttr := $00;
                                        HighInt := $00;
                                     End;
                                 1 : Begin { high intensity }
                                        HighInt := 8;
                                     End;
                                 4 : Begin { underline }
                                     End;
                                 5 : Begin { blink }
                                        Blink := 128;
                                     End;
                                 7 : Begin { reverse }
                                     End;
                                 8 : Begin { invisible }
                                        ForeAttr := $00;
                                     End;
                                 { foreground attributes }
                                 30: ForeAttr := $00; { black }
                                 31: ForeAttr := $04; { red }
                                 32: ForeAttr := $02; { green }
                                 33: ForeAttr := $06; { yellow }
                                 34: ForeAttr := $01; { blue }
                                 35: ForeAttr := $05; { magenta }
                                 36: ForeAttr := $03; { cyan }
                                 37: ForeAttr := $07; { white }
                                 { background attributes }
                                 40: BackAttr := $00; { black }
                                 41: BackAttr := $04; { red }
                                 42: BackAttr := $02; { green }
                                 43: BackAttr := $06; { yellow }
                                 44: BackAttr := $01; { blue }
                                 45: BackAttr := $05; { magenta }
                                 46: BackAttr := $03; { cyan }
                                 47: BackAttr := $07; { white }
                              End;
                           End;
                        End else
                        Begin { no semicolons, so just a single attribute }
                           Delete(ANSIstr, Pos('m', ANSIstr), 1);
                           Val(ANSIstr, K, T);
                              Case K of
                                 0 : Begin { attributes off }
                                        Blink := $00;
                                        ForeAttr := $07;
                                        BackAttr := $00;
                                        HighInt := $00;
                                     End;
                                 1 : Begin { high intensity }
                                        HighInt := 8;
                                     End;
                                 4 : Begin { underline }
                                     End;
                                 5 : Begin { blink }
                                        Blink := 128;
                                     End;
                                 7 : Begin { reverse }
                                     End;
                                 8 : Begin { invisible }
                                        ForeAttr := $00;
                                     End;
                                 { foreground attributes }
                                 30: ForeAttr := $00; { black }
                                 31: ForeAttr := $04; { red }
                                 32: ForeAttr := $02; { green }
                                 33: ForeAttr := $06; { yellow }
                                 34: ForeAttr := $01; { blue }
                                 35: ForeAttr := $05; { magenta }
                                 36: ForeAttr := $03; { cyan }
                                 37: ForeAttr := $07; { white }
                                 { background attributes }
                                 40: BackAttr := $00; { black }
                                 41: BackAttr := $04; { red }
                                 42: BackAttr := $02; { green }
                                 43: BackAttr := $06; { yellow }
                                 44: BackAttr := $01; { blue }
                                 45: BackAttr := $05; { magenta }
                                 46: BackAttr := $03; { cyan }
                                 47: BackAttr := $07; { white }
                              End;

                        End;
                     End;
               'h' : Begin { set mode command }
                     End;
               'l' : Begin { turn off line wrap command }
                     End;
               'p' : Begin { redefine keyboard command }
                     End;

            else
               Seek(F, Filepos(F)-1);
            End;
         End else
         Begin
            { it's just two normal characters }
            If ((X*2)+(Y*160)) <> 0 then
            Begin
               Mem[Buf:(X*2)+(Y*160)+0] := Ord(Ch1);
               Mem[Buf:(X*2)+(Y*160)+1] := ForeAttr+(BackAttr shl 4)+Blink+HighInt;
            End else
            Begin
               { we're drawing the first character }
               Mem[Buf:(X*2)+(Y*160)+0] := Ord(Ch1);
               Mem[Buf:(X*2)+(Y*160)+1] := ForeAttr+(BackAttr shl 4)+Blink+HighInt;
            End;

            Inc(X);
            If X > 79 then
            Begin
               X := 0;
               Inc(Y);
            End;
            Mem[Buf:(X*2)+(Y*160)+0] := Ord(Ch2);
            Mem[Buf:(X*2)+(Y*160)+1] := ForeAttr+(BackAttr shl 4)+Blink+HighInt;
         End;
      End else
      Begin
         { it's a normal character }
         { check if it's a special character eg tab, cr, lf }
         Case Ch1 of
            #13 : Begin { carriage return }
                     X := 0;
                  End;
            #10 : Begin { line feed }
                     Inc(Y);
                  End;
            #9  : Begin { tab }
                     Inc(X, 8);
                     If X > 79 then
                     Begin
                        X := 0;
                        Inc(Y);
                     End;
                  End;
            #26 : Begin
                  End;
         else
            Begin
               If ((X*2)+(Y*160)) <> 0 then
               Begin
                  Mem[Buf:(X*2)+(Y*160)+0] := Ord(Ch1);
                  Mem[Buf:(X*2)+(Y*160)+1] := ForeAttr+(BackAttr shl 4)+Blink+HighInt;
               End else
               Begin
                  { we're drawing the first character }
                  Mem[Buf:0] := Ord(Ch1);
                  Mem[Buf:1] := ForeAttr+(BackAttr shl 4)+Blink+HighInt;
               End;

               Inc(X);
               If X = 80 then
               Begin
                  X := 0;
                  Inc(Y);
               End;
            End;
         End;
      End;
   Until (Num > Fsize) or (Y > 408) or (Ch1 = #26);
   Close(F);

   If Y > 408 then NumLines := 32640 else NumLines := Y*160 - (MaxY*160);
   If Y <= MaxY then NumLines := 0;
End; { of Procedure Load_ANSi_Text }

Function Load_RIP(Fname : String; Buf : Word) : Boolean;
{ Loads and displays a RIPscrip file }
Var
   RipF : Text;
Begin
   Load_RIP := True;
   Assign(RipF, Fname);
   Reset(RipF);
   If IOresult <> 0 then
   Begin
      Load_RIP := False;
      Exit;
   End;
   Close(RipF);

   DisplayRIP(Fname, Buf);
End; { of Procedure Load_RIP }

End.