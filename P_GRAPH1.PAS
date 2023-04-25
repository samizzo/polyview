Unit P_Graph1;

Interface

Procedure Bold;
Procedure Goth;
Procedure Tscr;
Procedure Scri;

Implementation

Procedure Bold; External;
{$L OBJ/BOLD.OBJ}

Procedure Goth; External;
{$L OBJ/GOTH.OBJ}

Procedure Tscr; External;
{$L OBJ/TSCR.OBJ}

Procedure Scri; External;
{$L OBJ/SCRI.OBJ}

End.