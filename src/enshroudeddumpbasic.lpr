program enshroudeddumpbasic;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes;

const
  DumpSize = 512;

var
  F: TFileStream;
  Buffer: array[0..DumpSize - 1] of Byte;
  ReadCount: Integer;
  I, J: Integer;

begin
  if ParamCount <> 1 then
  begin
    WriteLn('Usage: EnshroudedDump <savefile>');
    Halt(1);
  end;

  F := TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyNone);
  try
    WriteLn('File: ', ParamStr(1));
    WriteLn('Size: ', F.Size, ' bytes');
    WriteLn;

    ReadCount := F.Read(Buffer, SizeOf(Buffer));

    I := 0;
    while I < ReadCount do
    begin
      Write(IntToHex(I, 8), '  ');

      for J := 0 to 15 do
      begin
        if I + J < ReadCount then
          Write(IntToHex(Buffer[I + J], 2), ' ')
        else
          Write('   ');
      end;

      Write(' ');

      for J := 0 to 15 do
      begin
        if I + J < ReadCount then
        begin
          if (Buffer[I + J] >= 32) and (Buffer[I + J] <= 126) then
            Write(Chr(Buffer[I + J]))
          else
            Write('.');
        end;
      end;

      WriteLn;
      Inc(I, 16);
    end;

  finally
    F.Free;
  end;
end.
