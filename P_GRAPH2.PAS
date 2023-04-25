Unit P_Graph2;

Interface

Procedure Sans;
Procedure Simp;
Procedure Trip;
Procedure Euro;
Procedure Lcom;
Procedure Litt;

Implementation

Procedure Sans; External;
{$L OBJ/SANS.OBJ}

Procedure Simp; External;
{$L OBJ/SIMP.OBJ}

Procedure Trip; External;
{$L OBJ/TRIP.OBJ}

Procedure Euro; External;
{$L OBJ/EURO.OBJ}

Procedure Lcom; External;
{$L OBJ/LCOM.OBJ}

Procedure Litt; External;
{$L OBJ/LITT.OBJ}

End.