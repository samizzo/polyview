Unit P_RIP;

Interface

Procedure DisplayRIP(Fname : String; Buf : Word);

Implementation

Uses Graph, P_Graph1, P_Graph2;

Const
   { * signifies command has been coded }

   { level 0 commands }
   RIP_TEXT_WINDOW       = 'w';
   RIP_VIEWPORT          = 'v';
   RIP_RESET_WINDOWS     = '*'; {*}
   RIP_ERASE_WINDOW      = 'e';
   RIP_ERASE_VIEW        = 'E';
   RIP_GOTOXY            = 'g';
   RIP_HOME              = 'H';
   RIP_ERASE_EOL         = '>';
   RIP_COLOR             = 'c'; {*}
   RIP_SET_PALETTE       = 'Q';
   RIP_ONE_PALETTE       = 'a'; {*}
   RIP_WRITE_MODE        = 'W'; {*}
   RIP_MOVE              = 'm';
   RIP_TEXT              = 'T';
   RIP_TEXT_XY           = '@'; {*}
   RIP_FONT_STYLE        = 'Y'; {*}
   RIP_PIXEL             = 'X'; {*}
   RIP_LINE              = 'L'; {*}
   RIP_RECTANGLE         = 'R'; {*}
   RIP_BAR               = 'B'; {*}
   RIP_CIRCLE            = 'C'; {*}
   RIP_OVAL              = 'O'; {*}
   RIP_FILLED_OVAL       = 'o'; {*}
   RIP_ARC               = 'A'; {*}
   RIP_OVAL_ARC          = 'V'; {same as rip_oval}
   RIP_PIE_SLICE         = 'I'; {*}
   RIP_OVAL_PIE_SLICE    = 'i';
   RIP_BEZIER            = 'Z'; {*}
   RIP_POLYGON           = 'P'; {*}
   RIP_FILL_POLY         = 'p'; {*}
   RIP_FILL              = 'F'; {*}
   RIP_LINE_STYLE        = '='; {*}
   RIP_FILL_STYLE        = 'S'; {*}
   RIP_FILL_PATTERN      = 's'; {*}
   RIP_NO_MORE           = '#'; {*}

   RIP_POLY_NOEND        = 'l'; {*}

   { level 1 commands }
   RIP_MOUSE             = 'M';
   RIP_KILL_MOUSE_FIELDS = 'K';
   RIP_BEGIN_TEXT        = 'T';
   RIP_REGION_TEXT       = 't';
   RIP_END_TEXT          = 'E';
   RIP_GET_IMAGE         = 'C'; {*}
   RIP_PUT_IMAGE         = 'P'; {*}
   RIP_WRITE_ICON        = 'W';
   RIP_LOAD_ICON         = 'I';
   RIP_BUTTON_STYLE      = 'B';
   RIP_BUTTON            = 'U';
   RIP_DEFINE            = 'D';
   RIP_QUERY             = #27;
   RIP_COPY_REGION       = 'G';
   RIP_READ_SCENE        = 'R';
   RIP_FILE_QUERY        = 'F';

   { level 10 commands }
   RIP_ENTER_BLOCK_MODE  = #27;

   Places                : Array [1..5] of Longint = (1,36,1296,46656,1679616);

Var
   TcsCount,
   GrMode,
   I, J : Integer;
   Num1, X1, Y1, X2, Y2, X3, Y3, X4, Y4 : Longint;
   F : Text;
   Ch1 : Char;
   S : String;
   ProcessCommand : Boolean;
   PolyPoints : Array [1..512] of PointType;
   FillPattern : FillPatternType;
   Pal : PaletteType;
   TempComStr : Array [0..2047] of Char;

PROCEDURE DrawBezierCurve (px1, py1, px2, py2, px3, py3, px4, py4, count : Longint);
FUNCTION pow (x : REAL; y : WORD) : REAL;
VAR
  nt     : WORD;
  result : REAL;
BEGIN
 result := 1;
 FOR nt := 1 TO y DO
     result := result * x;
 pow := result;
END;

PROCEDURE Bezier (t : REAL; VAR x, y : INTEGER);
BEGIN
 x := TRUNC (pow (1 - t, 3) * px1 + 3 * t * pow (1 - t, 2) * px2 +
                3 * t * t * (1 - t) * px3 + pow (t, 3) * px4);
 y := TRUNC (pow (1 - t, 3) * py1 + 3 * t * pow (1 - t, 2) * py2 +
                3 * t * t * (1 - t) * py3 + pow (t, 3) * py4);
END;

VAR
 resolution, t : REAL;
 xc, yc       : INTEGER;
BEGIN
  IF count = 0 THEN EXIT;
  resolution := 1 / count;
  MOVETO (px1, py1);
  t := 0;
  WHILE t < 1 DO BEGIN
    Bezier (t, xc, yc);
    LINETO (xc, yc);
    t := t + resolution;
  END;
  LINETO (px4, py4);
END;

Function ConvMega(S : String) : Longint;
{ converts up to a 5 digit meganum to a longint value }
Var
   I : Word;
   J, K : Longint;
Begin
   If Length(S) > 5 then
   Begin
      ConvMega := -1;
      Exit;
   End;

   K := 0;
   For I := Length(S) downto 1 do
   Begin
      If S[I] in ['A'..'Z'] then
         J := Ord(S[I])-55
      else
      Begin
         J := Ord(S[I])-48; { 0..9 }
      End;
      K := K + (J*Places[Length(S)-I+1]);
   End;

   ConvMega := K;
End;

Procedure EGAVGAdrv; External;
{$L OBJ/EGAVGA.OBJ}

Procedure DisplayRIP(Fname : String; Buf : Word);
Begin
   I := EGA;
   GrMode := EGAhi;
   InitGraph(I, GrMode, '');

   Assign(F, Fname);
   Reset(F);

   Asm
      mov processcommand, 0
      mov tcscount, 0
   End;

   Repeat
      { read RIPscrip command }
      Read(F, Ch1);

      Case Ch1 of
         '\' : Begin
                  Read(F, Ch1);
                  If (Ch1 = '\') or (Ch1 = '!') then
                  Begin
                     ProcessCommand := True;

                     TempComStr[TcsCount] := Ch1;
                     Inc(TcsCount);
                     if tcscount > 2047 then halt;
                  End else Read(F, Ch1);
               End;
         '!' : ProcessCommand := False; { start of a RIPscrip command line }
         '|' : ProcessCommand := True;{ end of RIPscrip command }
         #13,#10 : { do nothing }
         else
         Begin
            TempComStr[TcsCount] := Ch1;
            Inc(TcsCount);
            if tcscount > 2047 then halt;
         End;
      End;

      If ProcessCommand then
      Begin
         { process RIPscrip command }
         If TempComStr[0] = RIP_NO_MORE then
         Begin
            Ch1 := #26;
            TempComStr[0] := #0;
         End;

         If TempComStr[0] <> #0 then
         Begin
            If TempComStr[0] in ['1'..'9'] then
            Begin
               Case TempComStr[1] of
                  RIP_GET_IMAGE  : Begin
                                      { format: x1:2, y1:2, x2:2, y2:2, res:1 }

                                      { x1 }
                                      X1 := ConvMega(TempComStr[2] + TempComStr[3]);

                                      { y1 }
                                      Y1 := ConvMega(TempComStr[4] + TempComStr[5]);

                                      { x2 }
                                      X2 := ConvMega(TempComStr[6] + TempComStr[7]);

                                      { y2 }
                                      Y2 := ConvMega(TempComStr[8] + TempComStr[9]);

                                      GetImage(X1, Y1, X2, Y2, Ptr(Buf, 0)^);
                                   End;
                  RIP_PUT_IMAGE  : Begin
                                      { format: x:2, y:2, mode:2, res:1 }

                                      { x }
                                      X1 := ConvMega(TempComStr[2] + TempComStr[3]);

                                      { y }
                                      Y1 := ConvMega(TempComStr[4] + TempComStr[5]);

                                      { mode }
                                      Num1 := ConvMega(TempComStr[6] + TempComStr[7]);

                                      PutImage(X1, Y1, Ptr(Buf, 0)^, Num1);
                                   End;
               End;
            End
            else
            Case TempComStr[0] of
               RIP_RESET_WINDOWS : Begin
                                      SetGraphMode(GrMode);
                                      ClearDevice;
                                   End;
               RIP_ONE_PALETTE   : Begin
                                      { format: colour:2, value:2 }

                                      { colour }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { value }
                                      X2 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      SetPalette(X1, X2);
                                   End;
               RIP_COLOR         : Begin
                                      { format: colour:2 }

                                      { current drawing colour }
                                      Num1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      SetColor(Num1);
                                   End;
               RIP_LINE_STYLE    : Begin
                                      { format: style:2, user_pat:4, thich:2 }

                                      { style }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { user_pat }
                                      X2 := ConvMega(TempComStr[3] + TempComStr[4] + TempComStr[5] + TempComStr[6]);

                                      { thick }
                                      X3 := ConvMega(TempComStr[7] + TempComStr[8]);

                                      SetLineStyle(X1, X2, X3);
                                   End;
               RIP_WRITE_MODE    : Begin
                                      { format: mode:2 }

                                      { drawing mode for gfx primitives }
                                      Num1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      SetWriteMode(Num1);
                                   End;
               RIP_BEZIER        : Begin
                                      { format: x1:2, y1:2, x2:2, y2:2, x3:2, y3:2, x4:2, y4:2, cnt:2 }

                                      { x1 }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { y1 }
                                      Y1 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      { x2 }
                                      X2 := ConvMega(TempComStr[5] + TempComStr[6]);

                                      { y2 }
                                      Y2 := ConvMega(TempComStr[7] + TempComStr[8]);

                                      { x3 }
                                      X3 := ConvMega(TempComStr[9] + TempComStr[10]);

                                      { y3 }
                                      Y3 := ConvMega(TempComStr[11] + TempComStr[12]);

                                      { x4 }
                                      X4 := ConvMega(TempComStr[13] + TempComStr[14]);

                                      { y4 }
                                      Y4 := ConvMega(TempComStr[15] + TempComStr[16]);

                                      { count }
                                      Num1 := ConvMega(TempComStr[17] + TempComStr[18]);

                                      DrawBezierCurve(X1, Y1, X2, Y2, X3, Y3, X4, Y4, Num1);
                                   End;
               RIP_FILL_STYLE    : Begin
                                      { format: pattern:2, colour:2 }

                                      { fill pattern }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { fill colour }
                                      X2 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      SetFillStyle(X1, X2);
                                   End;
               RIP_PIXEL         : Begin
                                      { format: x:2, y:2 }

                                      { x }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { y }
                                      X2 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      X3 := GetColor;
                                      Putpixel(X1, X2, X3);
                                   End;
               RIP_FILL          : Begin
                                      { format: x:2, y:2, border:2 }

                                      { x }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { y }
                                      X2 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      { border }
                                      X3 := ConvMega(TempComStr[5] + TempComStr[6]);

                                      FloodFill(X1, X2, X3);
                                   End;
               RIP_LINE          : Begin
                                      { format: x1:2, y1:2, x2:2, y2:2 }

                                      { x1 }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { y1 }
                                      Y1 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      { x2 }
                                      X2 := ConvMega(TempComStr[5] + TempComStr[6]);

                                      { y2 }
                                      Y2 := ConvMega(TempComStr[7] + TempComStr[8]);

                                      Line(X1, Y1, X2, Y2);
                                   End;
               RIP_FONT_STYLE    : Begin
                                      { format: font:2, direction:2, size:2, res:2 }

                                      { font number }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { direction }
                                      X2 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      { size }
                                      X3 := ConvMega(TempComStr[5] + TempComStr[6]);

                                      SetTextStyle(X1, X2, X3);
                                   End;
               RIP_TEXT_XY       : Begin
                                      { format: x:2, y:2, text-string }

                                      { x }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { y }
                                      X2 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      S := '';

                                      { text string }
                                      For I := 5 to TcsCount-1 do
                                      S := S + TempComStr[I];

                                      OutTextXY(X1, X2, S);
                                   End;
               RIP_FILL_POLY     : Begin
                                      { format: npoints:2, x1:2, y1:2, ... xn:2, yn:2 }

                                      { number of points }
                                      Num1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      Fillchar(PolyPoints, Sizeof(PolyPoints), 0);

                                      { for each point }
                                      J := 3;
                                      For I := 1 to Num1 do
                                      Begin
                                         PolyPoints[I].X := ConvMega(TempComStr[J] + TempComStr[J+1]);

                                         Inc(J, 2);

                                         PolyPoints[I].Y := ConvMega(TempComStr[J] + TempComStr[J+1]);

                                         Inc(J, 2);
                                      End;

                                      Inc(Num1);
                                      PolyPoints[Num1] := PolyPoints[1];

                                      FillPoly(Num1, PolyPoints);
                                   End;
               RIP_POLYGON       : Begin
                                      { format: npoints:2, x1:2, y1:2, ... xn:2, yn:2 }

                                      { number of points }
                                      Num1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      Fillchar(PolyPoints, Sizeof(PolyPoints), 0);

                                      { for each point }
                                      J := 3;
                                      For I := 1 to Num1 do
                                      Begin
                                         PolyPoints[I].X := ConvMega(TempComStr[J] + TempComStr[J+1]);

                                         Inc(J, 2);

                                         PolyPoints[I].Y := ConvMega(TempComStr[J] + TempComStr[J+1]);

                                         Inc(J, 2);
                                      End;

                                      Inc(Num1);
                                      PolyPoints[Num1] := PolyPoints[1];

                                      DrawPoly(Num1, PolyPoints);
                                   End;
               RIP_FILLED_OVAL   : Begin
                                      { format: x_centre:2, y_centre:2, x_rad:2, y_rad:2 }

                                      { x centre }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { y centre }
                                      Y1 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      { x radius }
                                      X3 := ConvMega(TempComStr[5] + TempComStr[6]);

                                      { y radius }
                                      X4 := ConvMega(TempComStr[7] + TempComStr[8]);

                                      FillEllipse(X1, Y1, X3, X4);
                                   End;
               RIP_RECTANGLE     : Begin
                                      { format: x1:2, y1:2, x2:2, y2:2 }

                                      { x1 }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { y1 }
                                      Y1 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      { x2 }
                                      X2 := ConvMega(TempComStr[5] + TempComStr[6]);

                                      { y2 }
                                      Y2 := ConvMega(TempComStr[7] + TempComStr[8]);

                                      Rectangle(X1, Y1, X2, Y2);
                                   End;
               RIP_BAR           : Begin
                                      { format: x1:2, y1:2, x2:2, y2:2 }

                                      { x1 }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { y1 }
                                      Y1 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      { x2 }
                                      X2 := ConvMega(TempComStr[5] + TempComStr[6]);

                                      { y2 }
                                      Y2 := ConvMega(TempComStr[7] + TempComStr[8]);

                                      Bar(X1, Y1, X2, Y2);
                                   End;
               RIP_FILL_PATTERN  : Begin
                                      { format: c1:2, c2:2, c3:2, c4:2, c5:2, c6:2, c7:2, c8:2, colour:2 }

                                      J := 1;
                                      For I := 1 to 8 do
                                      Begin
                                         FillPattern[I] := ConvMega(TempComStr[J] + TempComStr[J+1]);
                                         Inc(J, 2);
                                      End;

                                      { colour }
                                      Num1 := ConvMega(TempComStr[17] + TempComStr[18]);

                                      SetFillPattern(FillPattern, Num1);
                                   End;
               RIP_OVAL_ARC,
               RIP_OVAL          : Begin
                                      { format: x:2, y:2, stang:2, endang:2, x_rad:2, y_rad:2 }

                                      { x centre }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { y centre }
                                      Y1 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      { start angle }
                                      X2 := ConvMega(TempComStr[5] + TempComStr[6]);

                                      { end angle }
                                      Y2 := ConvMega(TempComStr[7] + TempComStr[8]);

                                      { x-radius }
                                      X3 := ConvMega(TempComStr[9] + TempComStr[10]);

                                      { y-radius }
                                      Y3 := ConvMega(TempComStr[11] + TempComStr[12]);

                                      Ellipse(X1, Y1, X2, Y2, X3, Y3);
                                   End;
               RIP_PIE_SLICE     : Begin
                                      { format: x:2, y:2, stang:2, endang:2, radius:2 }

                                      { x centre }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { y centre }
                                      Y1 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      { start angle }
                                      X2 := ConvMega(TempComStr[5] + TempComStr[6]);

                                      { end angle }
                                      Y2 := ConvMega(TempComStr[7] + TempComStr[8]);

                                      { radius }
                                      X3 := ConvMega(TempComStr[9] + TempComStr[10]);

                                      PieSlice(X1, Y1, X2, Y2, X3);
                                   End;
               RIP_POLY_NOEND    : Begin
                                      { format: npoints:2, x1:2, y1:2, ... xn:2, yn:2 }

                                      { number of points }
                                      Num1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      Fillchar(PolyPoints, Sizeof(PolyPoints), 0);

                                      { for each point }
                                      J := 3;
                                      For I := 1 to Num1 do
                                      Begin
                                         PolyPoints[I].X := ConvMega(TempComStr[J] + TempComStr[J+1]);

                                         Inc(J, 2);

                                         PolyPoints[I].Y := ConvMega(TempComStr[J] + TempComStr[J+1]);

                                         Inc(J, 2);
                                      End;

                                      DrawPoly(Num1, PolyPoints);
                                   End;
               RIP_SET_PALETTE   : Begin
                                      { format: c1:2, c2:2, ... c16:2 }

                                      Fillchar(Pal, Sizeof(Pal), 0);
                                      Pal.Size := 16;

                                      { for each colour }
                                      J := 1;
                                      For I := 0 to 15 do
                                      Begin
                                         Pal.Colors[I] := ConvMega(TempComStr[J] + TempComStr[J+1]);

                                         Inc(J, 2);
                                      End;

                                      SetAllPalette(Pal);
                                   End;
               RIP_CIRCLE        : Begin
                                      { format: x_centre:2, y_centre:2, radius:2 }

                                      { x_centre }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { y_centre }
                                      Y1 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      { radius }
                                      Num1 := ConvMega(TempComStr[5] + TempComStr[6]);

                                      Circle(X1, Y1, Num1);
                                   End;
               RIP_ARC           : Begin
                                      { format: x:2, y:2, start_ang:2, end_ang:2, radius:2 }

                                      { x1 }
                                      X1 := ConvMega(TempComStr[1] + TempComStr[2]);

                                      { y1 }
                                      Y1 := ConvMega(TempComStr[3] + TempComStr[4]);

                                      { start_ang }
                                      X2 := ConvMega(TempComStr[5] + TempComStr[6]);

                                      { end_ang }
                                      Y2 := ConvMega(TempComStr[7] + TempComStr[8]);

                                      { radius }
                                      X3 := ConvMega(TempComStr[9] + TempComStr[10]);

                                      Arc(X1, Y1, X2, Y2, X3);
                                   End;
            End;
         End;

         ProcessCommand := False;
         TcsCount := 0;
      End;
   Until (Ch1 = #26);

   Close(F);

   Asm
     @looper:
      xor ax, ax
      int 16h

      cmp al, 13d
      je @end_prog
      cmp al, 27d
      je @end_prog
      jmp @looper

     @end_prog:
   End;

   CloseGraph;
End;

Begin
   RegisterBGIDriver(@EGAVGAdrv);
   RegisterBGIFont(@Bold);
   RegisterBGIFont(@Euro);
   RegisterBGIFont(@Goth);
   RegisterBGIFont(@Lcom);
   RegisterBGIFont(@Litt);
   RegisterBGIFont(@Sans);
   RegisterBGIFont(@Scri);
   RegisterBGIFont(@Simp);
   RegisterBGIFont(@Trip);
   RegisterBGIFont(@Tscr);
End.