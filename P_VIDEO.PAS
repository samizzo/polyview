Unit P_Video;

Interface

Procedure Vid80x25;
Procedure Vid80x30;
Procedure Vid80x43;
Procedure Vid80x50;

Implementation

Procedure Vid80x25; external;
{$L VIDMODES/80X25.OBJ}

Procedure Vid80x30; external;
{$L VIDMODES/80X30.OBJ}

Procedure Vid80x43; external;
{$L VIDMODES/80X43.OBJ}

Procedure Vid80x50; external;
{$L VIDMODES/80X50.OBJ}

End.