Unit P_DOSmem;

Interface

Function DOS_malloc(NumPara : Word; var MemSeg : Word) : Boolean;
Function DOS_free(MemSeg : Word) : Boolean;

Implementation

Function DOS_malloc(NumPara : Word; var MemSeg : Word) : Boolean; Assembler;
Asm
   mov ah, 48h
   mov bx, numpara
   int 21h
   jc @error
   les di, memseg
   mov es:[di], ax
   mov ax, 1
   jmp @outahere

  @error:
   xor ax, ax

  @outahere:
End;

Function DOS_free(MemSeg : Word) : Boolean; Assembler;
Asm
   mov ax, memseg
   mov es, ax
   mov ah, 49h
   int 21h
   jc @error
   mov ax, 1
   jmp @outahere

  @error:
   xor ax, ax

  @outahere:
End;

End.