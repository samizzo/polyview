{===========================================================================}
{=                                                                         =}
{= -^ PolyView v1.3b                                                       =}
{= -^ By jestyr / polyester (aka Sam Izzo)                                 =}
{= -^ Started on 04-02-1998                                                =}
{=                                                                         =}
{= -^ Updates                                                              =}
{=   --> 08-02-1998                                                        =}
{=         + added RIP support (EXE size nine times as big! bloody fonts!) =}
{=   --> 15-02-1998                                                        =}
{=         + added shell to DOS option (Alt-D), with swapping to disk      =}
{=   --> 16-02-1998                                                        =}
{=         + added SAUCE description loading                               =}
{=         + added ability to change drives                                =}
{=         + added ability to delete files                                 =}
{=         + added ability to copy files                                   =}
{=   --> 17-02-1998                                                        =}
{=         = rewrote light bar movement code and other code to make it     =}
{=           easier to update the file list when a file is deleted etc     =}
{=   --> 26-02-1998                                                        =}
{=         + added configuration file support (PV.INI) with limited options=}
{=                                                                         =}
{=                                                                         =}
{===========================================================================}

{$M 16384,0,10000}
{$I-,G+,N-}

Uses Graph, DOS, P_Utils, P_DOSmem, P_Loader, P_Viewer, P_Saver, P_Sauce, P_Config;

label here;

Const
   Title     = 'PolyView';
   Ver       = 'v1.3b';
   CopyRight = ' Copyright (c) 1998 Polyester';

   MaxFiles  = 512;

   UpKey     = #72;
   DownKey   = #80;
   HomeKey   = #71;
   EndKey    = #79;
   PageUp    = #73;
   PageDown  = #81;
   EnterKey  = #13;
   AltS      = #31;
   AltD      = #32;
   AltC      = #46;
   DelKey    = #83;
   InsKey    = #82;
   F1key     = #59;
   F2key     = #60;

   HexShifts : Array [0..3] of Byte = (0, 4, 8, 12);

Var
   FoundSAUCE,
   FindSAUCE : Boolean;
   TempHandle,
   SAUCEcnt : Word;
   Srec : SAUCErec;

   RedrawFrom : Word;

   FindStr,
   Temp, Temp2, Temp3,
   SaveDir,
   CurrDir   : String;

   FileList  : Array [1..MaxFiles] of Record
                                         Name : String[12];
                                         Attr : Byte; { attributes:
                                                        bit  0   - directory
                                                        bit  1   - drive
                                                        bits 2-7 - unused

                                                        if bit 1 = set,
                                                        bits 3-7 = drive number
                                                      }
                                         Author : Array [1..20] of Char;
                                         Title : Array [1..35] of Char;
                                      End;
   FindRec   : SearchRec;
   Key       : Char;

   FoundOne,
   NoMatch   : Boolean;

   NumFiles,
   I, J, K, Y,
   Sel       : Integer;

   F, F2     : File;

   X,
   TempBuf,
   ScrBuf,
   FileBuf   : Word;

   Fcb       : Array [0..36] of Byte;
   Fstr      : Array [0..2] of Byte;

Procedure PVmain; external;
{$L OBJ/PVMAIN.OBJ}

Procedure Redraw(From : Word);
Begin
   For I := 0 to 9 do
   Begin
      WriteStr(5, I+13, $07, '                                                                      ', ScrBuf);
      If I <= NumFiles then
      Begin
         WriteStr(5, I+13, $07, Filelist[I+From].Name, ScrBuf);

         For J := 1 to 20 do WriteCh(J+20, I+13, $07, Filelist[I+From].Author[J], ScrBuf);
         For J := 1 to 33 do WriteCh(J+41, I+13, $07, Filelist[I+From].Title[J], ScrBuf);
      End;
   End;
End;

Procedure ParseCfgFile;
{$I PV_INI.PAS}
Begin
   { initialise mode parameters }
   RIPModes[0].ModeNum := EGAhi;
   RIPModes[0].ModeDesc := 'EGA 640x350x16';
   RIPModes[1].ModeNum := VGAmed;
   RIPModes[1].ModeDesc := 'VGA 640x350x16';
   RIPModes[2].ModeNum := VGAhi;
   RIPModes[2].ModeDesc := 'VGA 640x480x16';

   TextModes[0].Desc := 'VGA25';
   TextModes[0].MaxY := 24;
   TextModes[0].ScanLines := 16;
   TextModes[1].Desc := 'VGA30';
   TextModes[1].MaxY := 29;
   TextModes[1].ScanLines := 16;
   TextModes[2].Desc := 'EGA43';
   TextModes[2].MaxY := 42;
   TextModes[2].ScanLines := 8;
   TextModes[3].Desc := 'VGA50';
   TextModes[3].MaxY := 49;
   TextModes[3].ScanLines := 8;

   (*TextModePtr[4] := Ptr(Seg(@Vid80x43^), Ofs(@Vid80x43^)); { 80x43x16c }
   TextModeDescs[4] := '80x25x16c';
   TextModePtr[5] := Ptr(Seg(@Vid80x50^), Ofs(@Vid80x50^)); { 80x50x16c }
   TextModeDescs[5] := '80x50x16c';*)

   Temp := ParamStr(0);
   Delete(Temp, Pos('.', Temp), Length(Temp));
   Temp := Temp + '.INI';

   If not Exists(Temp) then
   Begin
      Write('þ Config file not found!  Creating new config..');

      DefaultRIPMode := 0;
      DefaultTextMode := 0;
      NumVESAModes := 0;
      BlockPage := False;

      Assign(CfgFile, Temp);
      Rewrite(CfgFile);
      WriteConfig;
      Close(CfgFile);
   End;

   { parse the config file }
   Assign(CfgFile, Temp);
   Reset(CfgFile);
   While not eof(CfgFile) do
   Begin
      Readln(CfgFile, Temp);
      If (Temp <> '') and not (Temp[1] in [';', ' ', #255])then
      Begin { it's a config item }
         Temp2 := Temp;
         Delete(Temp2, Pos('=', Temp2), Length(Temp2));
         Delete(Temp, 1, Pos('=', Temp));
         For I := 1 to Length(Temp2) do Temp2[I] := Upcase(Temp2[I]);
         If Temp2 = 'TEXTMODE' then
         Begin { default text mode }
            Val(Temp, DefaultTextMode, I);
            If DefaultTextMode > 5 then DefaultTextMode := 0;
         End else
         If Temp2 = 'RIPMODE' then
         Begin { default RIP mode }
            Val(Temp, DefaultRIPMode, I);
            If DefaultRIPMode > 2 then DefaultRIPMode := 0;
         End else
         If Temp2 = 'BLOCKPAGE' then
         Begin
            If Temp[1] = '0' then
               BlockPage := False
            else
               BlockPage := True;
         End else
         If Temp2 = 'VESAMODES' then
         Begin { number of VESA modes }
            Val(Temp, NumVESAModes, I);
            If NumVESAModes <> 0 then
            Begin
               If NumVESAModes > 10 then NumVESAModes := 10;

               For I := 1 to NumVESAModes do { read in mode params }
               Begin
                  Readln(CfgFile, Temp);
                  Temp2 := Temp;
                  Delete(Temp, 1, Pos('=', Temp)); { get just params }
                  Delete(Temp, Pos(',', Temp), Length(Temp)); { get mode num }

                  If Length(Temp) <> 4 then
                  Begin
                     For I := 1 to 4-Length(Temp) do Temp := '0' + Temp;
                  End;

                  X := 0;
                  For J := 1 to Length(Temp) do
                  Begin
                     If Upcase(Temp[J]) in ['A'..'F'] then
                     Begin
                        K := Ord(Temp[J]) - 55;
                        X := X + K shl HexShifts[4-J];
                     End else
                     Begin { it's just a number }
                        Val(Temp[J], K, Y);
                        X := X + K shl HexShifts[4-J];
                     End;
                  End;

                  VESAModes[I].ModeNum := X;

                  Temp := Temp2;
                  Delete(Temp, 1, Pos(',', Temp));
                  Delete(Temp, Pos(',', Temp), Length(Temp));
                  Val(Temp, J, K);
                  VESAModes[I].Xres := J;

                  Temp := Temp2;
                  Delete(Temp, 1, Pos(',', Temp));
                  Delete(Temp, 1, Pos(',', Temp));
                  Val(Temp, J, K);
                  VESAModes[I].Xres := J;
               End;
            End;
         End;
      End;
   End;
   Close(CfgFile);
End; { of ParseCfg procedure }

Procedure LogDir;
Var
   OldDir : String;
Begin
   Fillchar(Filelist, Sizeof(Filelist), 0);

   GetDir(0, OldDir);

   I := 0;

   FindFirst('*.*', Directory, FindRec);
   While DOSerror = 0 do
   Begin
      Inc(I);
      FileList[I].Name := FindRec.Name;
      ChDir(FileList[I].Name);
      If IOresult <> 0 then Dec(I)
         else
      Begin
         Filelist[I].Attr := 1;
         ChDir(OldDir);
      End;
      If FileList[I].Name = '.' then
      Begin
         FileList[I].Name := '\';

         FileList[I].Title[1] := 'R';
         FileList[I].Title[2] := 'o';
         FileList[I].Title[3] := 'o';
         FileList[I].Title[4] := 't';
         FileList[I].Title[5] := ' ';
         FileList[I].Title[6] := 'd';
         FileList[I].Title[7] := 'i';
         FileList[I].Title[8] := 'r';
         FileList[I].Title[9] := 'e';
         FileList[I].Title[10] := 'c';
         FileList[I].Title[11] := 't';
         FileList[I].Title[12] := 'o';
         FileList[I].Title[13] := 'r';
         FileList[I].Title[14] := 'y';
      End else
      If FileList[I].Name = '..' then
      Begin
         FileList[I].Title[1] := 'P';
         FileList[I].Title[2] := 'r';
         FileList[I].Title[3] := 'e';
         FileList[I].Title[4] := 'v';
         FileList[I].Title[5] := 'i';
         FileList[I].Title[6] := 'o';
         FileList[I].Title[7] := 'u';
         FileList[I].Title[8] := 's';
         FileList[I].Title[9] := ' ';
         FileList[I].Title[10] := 'd';
         FileList[I].Title[11] := 'i';
         FileList[I].Title[12] := 'r';
         FileList[I].Title[13] := 'e';
         FileList[I].Title[14] := 'c';
         FileList[I].Title[15] := 't';
         FileList[I].Title[16] := 'o';
         FileList[I].Title[17] := 'r';
         FileList[I].Title[18] := 'y';
      End else
      Begin
         FileList[I].Title[1] := 'D';
         FileList[I].Title[2] := 'i';
         FileList[I].Title[3] := 'r';
         FileList[I].Title[4] := 'e';
         FileList[I].Title[5] := 'c';
         FileList[I].Title[6] := 't';
         FileList[I].Title[7] := 'o';
         FileList[I].Title[8] := 'r';
         FileList[I].Title[9] := 'y';
      End;
      FindNext(FindRec);
   End;

   FindFirst('*.*', Hidden+Sysfile+Readonly+Archive, FindRec);
   While DOSerror = 0 do
   Begin
      Inc(I);

      If I <= 512 then
      Begin
         FileList[I].Name := FindRec.Name;
         FileList[I].Attr := 0;
         FindNext(FindRec);
      End;
   End;

   Asm
      mov byte ptr temp, 0
      mov cl, 1d

   @looper:
      mov dl, cl
      add dl, 64

      mov byte ptr fstr[0], dl
      mov byte ptr fstr[1], ':'
      mov byte ptr fstr[2], 0

      mov ah, 29h
      mov al, 06h
      mov si, offset fstr
      push ds
      pop es
      mov di, offset fcb
      int 21h

      cmp al, 0ffh
      je @invalid_drive

      inc byte ptr temp
      mov bl, byte ptr temp
      xor bh, bh
      mov al, cl
      add al, 64
      mov byte ptr temp[bx], al

     @invalid_drive:

      inc cl
      cmp cl, 27d
      jne @looper
   End;

   For J := 1 to Length(Temp) do
   Begin
      Inc(I);
      FileList[I].Name := '[ '+Temp[J]+': ]';

      FileList[I].Attr := 2 + (Ord(Temp[J])-65) shl 3;

      K := Ord(Temp[J])-64;
      Asm
         mov ax, 4408h { check if block device removable }
         mov bx, k
         mov k, 0ffffh
         int 21h
         jc @error
         mov k, ax
        @error:
      End;

      If K = 0 then  { removable }
      Begin
         FileList[I].Title[1] := 'R';
         FileList[I].Title[2] := 'e';
         FileList[I].Title[3] := 'm';
         FileList[I].Title[4] := 'o';
         FileList[I].Title[5] := 'v';
         FileList[I].Title[6] := 'a';
         FileList[I].Title[7] := 'b';
         FileList[I].Title[8] := 'l';
         FileList[I].Title[9] := 'e';
         FileList[I].Title[10] := ' ';
         FileList[I].Title[11] := 'm';
         FileList[I].Title[12] := 'e';
         FileList[I].Title[13] := 'd';
         FileList[I].Title[14] := 'i';
         FileList[I].Title[15] := 'a';
      End else
      If K = 1 then { fixed }
      Begin
         FileList[I].Title[1] := 'F';
         FileList[I].Title[2] := 'i';
         FileList[I].Title[3] := 'x';
         FileList[I].Title[4] := 'e';
         FileList[I].Title[5] := 'd';
         FileList[I].Title[6] := ' ';
         FileList[I].Title[7] := 'm';
         FileList[I].Title[8] := 'e';
         FileList[I].Title[9] := 'd';
         FileList[I].Title[10] := 'i';
         FileList[I].Title[11] := 'a';
      End else { unknown }
      Begin
         { might be a CD-ROM drive }
         Asm
            mov ax, 1500h { CD-ROM installation check }
            xor bx, bx
            mov k, -1
            int 2fh

            or bx, bx
            jz @no_cd
            mov k, cx

           @no_cd:
         End;

         If K <> -1 then { CD-ROM found! }
         Begin
            { k = CD-ROM starting drive letter }
            If Temp[J] = Chr(K+65) then
            Begin
               FileList[I].Title[1] := 'C';
               FileList[I].Title[2] := 'D';
               FileList[I].Title[3] := '-';
               FileList[I].Title[4] := 'R';
               FileList[I].Title[5] := 'O';
               FileList[I].Title[6] := 'M';
               FileList[I].Title[7] := ' ';
               FileList[I].Title[8] := 'd';
               FileList[I].Title[9] := 'r';
               FileList[I].Title[10] := 'i';
               FileList[I].Title[11] := 'v';
               FileList[I].Title[12] := 'e';
            End;
         End else
         Begin
            FileList[I].Title[1] := 'U';
            FileList[I].Title[2] := 'n';
            FileList[I].Title[3] := 'k';
            FileList[I].Title[4] := 'n';
            FileList[I].Title[5] := 'o';
            FileList[I].Title[6] := 'w';
            FileList[I].Title[7] := 'n';
         End;
      End;
   End;

   If I > 512 then I := 512;
   NumFiles := I;

   FindSAUCE := True;
   SAUCEcnt := 1;
End;

Procedure DrawMain;
Begin
   Move(Mem[Seg((@PVmain)^):Ofs((@PVmain)^)], Mem[ScrBuf:0], 4000);
   WriteStr(72, 9, $07, Ver, ScrBuf);
   WriteStr(22, 12, $0B, '                                        ', ScrBuf);
   J := Length(CurrDir)+21;
   If J > 61 then J := 61;
   For I := 22 to J do WriteCh(I, 12, $0B, CurrDir[I-21], ScrBuf);

   LogDir;
   RedrawFrom := 1;
   Redraw(RedrawFrom);

   Asm
      mov dx, ds

      mov ax, textseg
      mov es, ax
      xor di, di
      mov ax, scrbuf
      mov ds, ax
      xor si, si
      mov cx, 1000d
      db 66h; rep movsw
      mov ds, dx
   End;
End;

Begin
   Writeln(Title, ' ', Ver, ' ', CopyRight);
   Writeln('Written by Jestyr[Poly] - 04.02.1998');
   Writeln;

   ParseCfgFile;

   If not DOS_malloc(65536 shr 4, FileBuf) then
   Begin
      Writeln('þ Error!  Unable to allocate 64k buffer!');
      Writeln(' -> PolyView requires at least 256k free conventional memory to run!');
      Writeln;
      Halt(1);
   End;

   If not DOS_malloc(65536 shr 4, ScrBuf) then
   Begin
      Writeln('þ Error!  Unable to allocate 64k buffer!');
      Writeln(' -> PolyView requires at least 256k free conventional memory to run!');
      Writeln;

      DOS_free(FileBuf);
      Halt(1);
   End;

   If not DOS_malloc(65536 shr 4, TempBuf) then
   Begin
      Writeln('þ Error!  Unable to allocate 64k buffer!');
      Writeln(' -> PolyView requires at least 256k free conventional memory to run!');
      Writeln;

      DOS_free(FileBuf);
      DOS_free(ScrBuf);
      Halt(1);
   End;

   Fillchar(Mem[FileBuf:0], 65535, 0);
   Fillchar(Mem[ScrBuf:0], 65535, 0);
   Fillchar(Mem[TempBuf:0], 65535, 0);

   SAUCEcnt := 1;

   Cls;
   CursOff;
   GetDir(0, CurrDir);
   SaveDir := CurrDir;
   DrawMain;

   Sel := 1;
   Y := 13;
   Key := #0;

   Repeat
      If FindSAUCE then
      Begin
         If (FileList[SAUCEcnt].Attr and 1 <> 1) and (FileList[SAUCEcnt].Attr and 2 <> 2) then
         Begin
            Temp := FileList[SAUCEcnt].Name+#0;
            Asm
               mov foundsauce, 0

               push ds

               mov ah, 3dh { open file }
               xor al, al
               mov dx, offset temp[1] { ds:dx -> ASCIZ filename }
               int 21h

               pop ds

               mov temphandle, ax

               mov bx, ax
               mov ah, 42h { set file position }
               mov al, 02h { origin - end of file }
               xor dx, dx
               xor cx, cx
               int 21h

               cmp dx, 0
               jg @not_small
               cmp ax, 128d
               jb @too_small { filesize is < 128 bytes }

            @not_small:
               { otherwise, filesize is > 128 bytes }

               mov bx, temphandle
               mov ah, 42h { set file position }
               mov al, 02h { origin - end of file }
               mov dx, -128d { move file position to filesize-128 }
               mov cx, 0ffffh
               int 21h

               mov ah, 3fh { read from file }
               mov bx, temphandle
               mov cx, 128d { number of bytes }
               mov dx, offset srec { ds:dx -> buffer }
               int 21h

               mov ax, word ptr srec.id
               cmp ax, 4153h { 'AS' }
               jne @too_small
               mov ax, word ptr srec.id+2
               cmp ax, 4355h { 'CU' }
               jne @too_small
               mov al, byte ptr srec.id+4
               cmp al, 45h { 'E' }
               jne @too_small

               { found SAUCE }
               mov foundsauce, 1

            @too_small:
               mov ah, 3eh { close file }
               mov bx, temphandle
               int 21h
            End;

            If FoundSAUCE then
            Begin
               Move(Srec.Author, FileList[SAUCEcnt].Author, 20);
               Move(Srec.Title, FileList[SAUCEcnt].Title, 35);

               Redraw(RedrawFrom);
            End;
         End;

         Asm
            inc saucecnt
            mov ax, numfiles
            cmp saucecnt, ax
            jbe @nup
            mov saucecnt, 1
            mov findsauce, false

           @nup:
         End;
      End;

      WriteStr(4, Y, $17, '              ', ScrBuf);
      WriteStr(5, Y, $17, FileList[Sel].Name, ScrBuf);

      Asm
         mov dx, ds

         mov ax, textseg
         mov es, ax
         xor di, di
         mov ax, scrbuf
         mov ds, ax
         xor si, si
         mov cx, 1000d
         db 66h; rep movsw
         mov ds, dx

         mov key, 1
         xor bx, bx
         mov ah, 11h
         int 16h
         jz @nokey
         mov bx, 1

        @nokey:

         or bx, bx
         jz @outa_here

         call getkey
         mov key, al

      @outa_here:
      End;

      WriteStr(4, Y, $07, '              ', ScrBuf);
      WriteStr(5, Y, $07, FileList[Sel].Name, ScrBuf);

      WriteStr(14, 24, $02, TextModes[DefaultTextMode].Desc, ScrBuf);

      If Key = #0 then
      Begin
         Key := Getkey;
         Case Key of
            UpKey   : Begin
                         Dec(Sel);
                         If Sel = 0 then Sel := 1
                            else
                         Begin
                            Dec(Y);
                            If Y = 12 then
                            Begin
                               Y := 13;
                               Dec(RedrawFrom);
                               Redraw(RedrawFrom);
                            End;
                         End;
                      End;
            DownKey : Begin
                         Inc(Sel);
                         If Sel > NumFiles then Sel := NumFiles
                            else
                         Begin
                            Inc(Y);
                            If Y = 23 then
                            Begin
                               Y := 22;
                               Inc(RedrawFrom);
                               Redraw(RedrawFrom);
                            End;
                         End;
                      End;
            HomeKey : Begin
                         Sel := 1;
                         Y := 13;
                         RedrawFrom := 1;
                         Redraw(RedrawFrom);
                      End;
            EndKey  : Begin
                         Sel := NumFiles;
                         If Sel < 10 then
                         Begin
                            Y := Sel+12;
                         End else
                         Begin
                            Y := 22;
                            RedrawFrom := NumFiles - 9;
                            Redraw(RedrawFrom);
                         End;
                      End;
            PageUp  : Begin
                         If Y = 13 then
                         Begin
                            RedrawFrom := RedrawFrom - 9;
                            Sel := Sel - 9;
                         End else
                         Begin
                            Y := 13;
                            Sel := RedrawFrom;
                         End;

                         If Sel < 1 then
                         Begin
                            Sel := 1;
                            RedrawFrom := 1;
                         End;

                         Redraw(RedrawFrom);
                      End;
            PageDown: Begin
                         If NumFiles < 10 then
                         Begin
                            Sel := NumFiles;
                            Y := Sel+12;
                         End else
                         Begin
                            If Sel > NumFiles-9 then
                            Begin
                               Sel := NumFiles;
                               RedrawFrom := NumFiles - 9;
                               Y := 22;
                            End else
                            Begin
                               If Y = 22 then
                               Begin
                                  RedrawFrom := RedrawFrom + 9;
                                  Sel := Sel + 9;
                               End else
                               Begin
                                  Y := 22;
                                  Sel := RedrawFrom + 9;
                               End;
                            End;

                            Redraw(RedrawFrom);
                         End;
                      End;
            DelKey  : Begin { delete a file }
                         If FileList[Sel].Attr = 0 then
                         Begin
                            Frame(10, 10, 70, 12, TextSeg);
                            I := 40-(Length(FileList[Sel].Name)+15) div 2;
                            WriteStr(I, 11, $17, 'Delete '+FileList[Sel].Name+' ? [Y/N]', TextSeg);
                            Repeat
                               Key := Upcase(Getkey);
                            Until Key in ['Y', 'N', #27];
                            If Key = 'Y' then
                            Begin
                               Assign(F, FileList[Sel].Name);
                               Erase(F);

                               Dec(NumFiles);

                               If Sel < NumFiles then
                               For I := Sel to NumFiles do
                               Begin
                                  Move(FileList[I+1], FileList[I], Sizeof(FileList[I]));
                               End;

                               If Sel <= 10 then
                               Begin
                                  If RedrawFrom > 1 then
                                  Begin
                                     Dec(RedrawFrom);
                                     Dec(Sel);
                                  End;
                               End else
                               If Sel > NumFiles-10 then
                               Begin
                                  Dec(RedrawFrom);
                                  Dec(Sel);
                               End;
                               Redraw(RedrawFrom);
                            End;
                            Key := #0;
                         End;
                      End;
            AltC, { copy a file }
            InsKey  : Begin
                         If FileList[Sel].Attr = 0 then
                         Begin
                            Frame(3, 10, 77, 12, TextSeg);
                            WriteStr(5, 11, $17, 'Directory:', TextSeg);
                            Temp := '';
                            InputStr('', 16, 11, 59, $0f, $0f, True, Temp);
                            CursOff;
                            If Temp <> '' then
                            Begin
                               ChDir(Temp);
                               If IOresult = 0 then
                               Begin
                                  If Temp[Length(Temp)] <> '\' then Temp := Temp + '\' + FileList[Sel].Name;
                                  ChDir(CurrDir);
                                  If Exists(Temp) then
                                  Begin
                                     Asm
                                        mov dx, ds

                                        mov ax, textseg
                                        mov es, ax
                                        xor di, di
                                        mov ax, scrbuf
                                        mov ds, ax
                                        xor si, si
                                        mov cx, 1000d
                                        db 66h; rep movsw

                                        mov ds, dx
                                     End;

                                     Frame(10, 10, 70, 12, TextSeg);
                                     I := 40-(Length(Temp)+25) div 2;
                                     WriteStr(I, 11, $17, Temp+' exists! Overwrite? [Y/N]', TextSeg);
                                     Repeat
                                        Key := Upcase(Getkey);
                                     Until Key in ['Y', 'N', #27];

                                     If Key in ['N', #27] then Goto here;
                                  End;
                                  Assign(F, FileList[Sel].Name);
                                  Reset(F, 1);
                                  Assign(F2, Temp);
                                  Rewrite(F2, 1);
                                  Repeat
                                     BlockRead(F, Mem[TempBuf:0], 65535, I);
                                     BlockWrite(F2, Mem[TempBuf:0], I, J);
                                  Until (I = 0) or (J <> I);
                                  Close(F);
                                  Close(F2);
                               here:
                               End else
                               Begin
                                  Asm
                                     mov dx, ds

                                     mov ax, textseg
                                     mov es, ax
                                     xor di, di
                                     mov ax, scrbuf
                                     mov ds, ax
                                     xor si, si
                                     mov cx, 1000d
                                     db 66h; rep movsw

                                     mov ds, dx
                                  End;

                                  Frame(10, 10, 70, 12, TextSeg);
                                  WriteStr(29, 11, $17, 'Cannot find directory!', TextSeg);
                                  WriteStr(34, 12, $17, ' Press a key ', TextSeg);
                                  Asm
                                     xor ax, ax
                                     int 16h
                                  End;
                               End;
                            End;
                         End;
                      End;
            AltS    : Begin { start screen saver }
                         Star_Saver(TempBuf);
                         CursOff;
                      End;
            AltD    : Begin { DOS shell }
                         Cls;
                         NormCurs;
                         Temp := GetEnv('COMSPEC');
                         If Temp = '' then Temp := 'C:\COMMAND.COM';
                         Temp2 := GetEnv('PROMPT');
                         If Temp2 = '' then Temp2 := '$p$g';
                         Temp2 := '/K PROMPT Type EXIT to return to PolyView$_' + Temp2 + ' [PV] ';

                         DOS_free(TempBuf);
                         DOS_free(ScrBuf);
                         DOS_free(FileBuf);

                         SwapVectors;
                         Exec(Temp, Temp2);
                         SwapVectors;
                         CursOff;

                         DOS_malloc(65536 shr 4, TempBuf);
                         DOS_malloc(65536 shr 4, ScrBuf);
                         DOS_malloc(65536 shr 4, FileBuf);

                         GetDir(0, CurrDir);
                         LogDir;

                         Move(Mem[Seg((@PVmain)^):Ofs((@PVmain)^)], Mem[ScrBuf:0], 4000);
                         WriteStr(72, 9, $07, Ver, ScrBuf);
                         WriteStr(22, 12, $0B, '                                        ', ScrBuf);
                         J := Length(CurrDir)+21;
                         If J > 61 then J := 61;
                         For I := 22 to J do WriteCh(I, 12, $0B, CurrDir[I-21], ScrBuf);

                         WriteStr(64, 12, $08, '............', ScrBuf);
                         WriteStr(64, 12, $02, FindStr, ScrBuf);

                         If Sel > NumFiles then
                         Begin
                            Sel := NumFiles;
                            If NumFiles > 9 then
                               RedrawFrom := NumFiles-10
                            else
                               RedrawFrom := 1;
                         End;

                         Redraw(RedrawFrom);

                         Asm
                            mov dx, ds

                            mov ax, textseg
                            mov es, ax
                            xor di, di
                            mov ax, scrbuf
                            mov ds, ax
                            xor si, si
                            mov cx, 1000d
                            db 66h; rep movsw

                            mov ds, dx
                         End;
                      End;
            F2key   : Begin
                         Inc(DefaultTextMode);
                         If DefaultTextMode > 3 then DefaultTextMode := 0;
                      End;
         End;
      End else
      Begin
         Case Key of
            EnterKey  : Begin
                           If FileList[Sel].Attr and 1 = 1 then { dir }
                           Begin
                              ChDir(FileList[Sel].Name);
                              GetDir(0, CurrDir);
                              LogDir;
                              RedrawFrom := 1;
                              Redraw(RedrawFrom);
                              Sel := 1;
                              Y := 13;
                              WriteStr(22, 12, $0B, '                                        ', ScrBuf);
                              J := Length(CurrDir)+21;
                              If J > 61 then J := 61;
                              For I := 22 to J do
                                 WriteCh(I, 12, $0B, CurrDir[I-21], ScrBuf);

                              FindStr := '';
                              WriteCh(63, 12, $0B, '[', ScrBuf);
                              WriteStr(64, 12, $08, '............', ScrBuf);
                           End else
                           If FileList[Sel].Attr and 2 = 2 then { drive }
                           Begin
                              I := 65+(FileList[Sel].Attr shr 3);
                              Temp3 := Chr(I) + ':';
                              { 0 = A:, 1 = B:, etc }
                              GetDir(0, Temp);
                              ChDir(Temp3);
                              FindFirst('*.*', AnyFile, FindRec);
                              If DOSerror <> 0 then
                              Begin
                                 ChDir(Temp);
                                 Frame(10, 10, 70, 12, TextSeg);
                                 WriteStr(28, 11, $17, 'Unable to change drives!', TextSeg);
                                 WriteStr(33, 12, $17, ' Press a key ', TextSeg);
                                 Asm
                                    xor ax, ax
                                    int 16h
                                 End;
                              End else
                              Begin
                                 LogDir;
                                 RedrawFrom := 1;
                                 Redraw(RedrawFrom);
                                 Sel := 1;
                                 Y := 13;
                                 WriteStr(22, 12, $0B, '                                        ', ScrBuf);
                                 GetDir(0, CurrDir);
                                 J := Length(CurrDir)+21;
                                 If J > 61 then J := 61;
                                 For I := 22 to J do
                                 WriteCh(I, 12, $0B, CurrDir[I-21], ScrBuf);

                                 FindStr := '';
                                 WriteCh(63, 12, $0B, '[', ScrBuf);
                                 WriteStr(64, 12, $08, '............', ScrBuf);
                              End;
                           End else
                           Begin
                              Temp := FileList[Sel].Name;
                              Delete(Temp, 1, Pos('.', Temp));
                              If Temp = 'RIP' then Load_RIP(FileList[Sel].Name, TempBuf)
                                 else
                              Begin
                                 Load_ANSi_Text(FileList[Sel].Name, TextModes[DefaultTextMode].MaxY, FileBuf, TempBuf);
                                 MaxLine := NumLines;
                                 Fillchar(Mem[TextSeg:0], 32767, 0);

                                 SetMode(DefaultTextMode);
                                 CursOff;
                                 DisplayBuffer(FileBuf, TextModes[DefaultTextMode].Scanlines);

                                 Asm
                                    mov ah, 12h
                                    mov bl, 30h
                                    mov al, 02h
                                    int 10h

                                    mov ax, 0003h
                                    int 10h
                                 End;

                                 Port[$3D4] := $08;
                                 Port[$3D5] := $00;
                                 Port[$3D4] := $0C;
                                 Port[$3D5] := $00;
                                 Port[$3D4] := $0D;
                                 Port[$3D5] := $00;
                              End;

                              CursOff;
                           End;
                        End;
            #8        : Begin
                           Delete(FindStr, Length(FindStr), 1);
                           WriteCh(63, 12, $0B, '[', ScrBuf);
                           WriteStr(64, 12, $08, '............', ScrBuf);
                           WriteStr(64, 12, $02, FindStr, ScrBuf);

                           If FindStr <> '' then
                           Begin
                              For I := NumFiles downto 1 do
                              Begin
                                 For J := 1 to Length(FindStr) do
                                 Begin
                                    If FileList[I].Name[J] <> FindStr[J] then
                                       NoMatch := True;
                                 End;

                                 If not NoMatch then
                                 Begin
                                    Sel := I;
                                    FoundOne := True;
                                 End;
                                 NoMatch := False;
                              End;

                              If Sel < 9 then
                              Begin
                                 RedrawFrom := 1;
                                 Redraw(RedrawFrom);
                                 Y := Sel+12
                              End else
                              Begin
                                 If Sel < 10 then
                                 Begin
                                    RedrawFrom := 1;
                                    Y := Sel+12;
                                 End else
                                 Begin
                                    RedrawFrom := Sel-9;
                                    Y := 22;
                                 End;
                                 Redraw(RedrawFrom);
                              End;
                           End;
                        End;
            #32..#255 : Begin
                           If Length(FindStr) < 12 then
                           Begin
                              FindStr := FindStr + UpCase(Key);

                              WriteStr(64, 12, $02, FindStr, ScrBuf);

                              FoundOne := False;

                              For I := NumFiles downto 1 do
                              Begin
                                 For J := 1 to Length(FindStr) do
                                 Begin
                                    If FileList[I].Name[J] <> FindStr[J] then
                                       NoMatch := True;
                                 End;

                                 If not NoMatch then
                                 Begin
                                    Sel := I;
                                    FoundOne := True;
                                 End;
                                 NoMatch := False;
                              End;

                              If FoundOne then
                              Begin
                                 If Sel < 10 then
                                 Begin
                                    RedrawFrom := 1;
                                    Redraw(RedrawFrom);
                                    Y := Sel+12;
                                 End else
                                 Begin
                                    RedrawFrom := Sel-9;
                                    Redraw(RedrawFrom);
                                    Y := 22;
                                 End;
                              End;
                           End;
                        End;
         End;
      End;
   Until Key = #27;

   DOS_free(TempBuf);
   DOS_free(ScrBuf);
   DOS_free(FileBuf);

   Cls;
   ChDir(SaveDir);
   Writeln(Title, ' ', Ver, ' ', CopyRight);
   Writeln('Written by Jestyr[Poly] (aka Sam Izzo) - 04.02.1998');
   Writeln(' - Bye! -');
   Writeln;
(*Writeln('ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿');
Writeln('³                                                                             ³');
Writeln('³  -^ ', Title, ' ', ' ', Ver, ' ', CopyRight, '                           ³');
Writeln('³  -^ By jestyr / polyester (aka Sam Izzo)                                    ³');
Writeln('³  -^ jestyr@acidnet.org                                                      ³');
Writeln('³                                                                             ³');
Writeln('ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ');*)
End.