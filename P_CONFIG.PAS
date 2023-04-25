Unit P_Config;

Interface

Var
   RIPModes : Array [0..2] of Record
                 ModeNum : Integer;
                 ModeDesc : String[14];
              End;
   TextModes : Array [0..5] of Record
                  Desc : String[10];
                  ScanLines,
                  MaxY : Byte;
               End;
   VESAModes : Array [1..10] of Record
                  ModeNum : Word;
                  Xres, Yres : Byte;
               End;
   TempPtr : Pointer;
   BlockPage : Boolean;
   NumVESAModes,
   DefaultRIPMode,
   DefaultTextMode : Word;
   CfgFile : Text;

Implementation

End.