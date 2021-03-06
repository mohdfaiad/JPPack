unit JPP.MemIniFile;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.IniFiles, System.ZLib,
  Vcl.Graphics,  Vcl.Dialogs,
  JPL.Strings,
  JPP.Common.Procs
  ;


type


  {$region ' ---------------------- INT - TJppMemIniFile ----------------------- '}
  TJppMemIniFile = class(TMemIniFile)
  private
    FLeftStringBound: string;
    FRightStringBound: string;
    procedure SetLeftStringBound(const Value: string);
    procedure SetRightStringBound(const Value: string);
  public
    constructor Create(const FileName: string); overload;
    constructor Create(const FileName: string; const Encoding: TEncoding); overload;
    procedure WriteColor(const Section: string; const Ident: string; Color: TColor);
    function ReadColor(const Section: string; const Ident: string; Default: TColor): TColor;
    procedure WriteFontStyle(const Section: string; const Ident: string; FontStyles: TFontStyles);
    function ReadFontStyle(const Section: string; const Ident: string; Default: TFontStyles): TFontStyles;
    procedure WriteStrings(const Section: string; Items: TStrings; Compress: Boolean = False);
    procedure ReadStrings(const Section: string; Items: TStrings; ItemsCompressed: Boolean = False);

    procedure WriteBoundString(const Section, Ident, Value: string);
    function ReadBoundString(const Section, Ident, Default: string): string;
    procedure WriteInt64(const Section, Ident: string; const Value: Int64);
    function ReadInt64(const Section, Ident: string; const Default: Int64): Int64;
    procedure WriteDotFloat(const Section, Ident: string; Value: Double);
    function ReadDotFloat(const Section, Name: string; Default: Double): Double;

    property LeftStringBound: string read FLeftStringBound write SetLeftStringBound;
    property RightStringBound: string read FRightStringBound write SetRightStringBound;
  end;
  {$endregion}


implementation




{$region ' ------------------------ IMP - TJppMemIniFile --------------------------- '}

constructor TJppMemIniFile.Create(const FileName: string);
begin
  Create(Filename, nil);
end;

constructor TJppMemIniFile.Create(const FileName: string; const Encoding: TEncoding);
begin
  inherited Create(FileName, Encoding);
  FLeftStringBound := '[';
  FRightStringBound := ']';
end;

procedure TJppMemIniFile.WriteBoundString(const Section, Ident, Value: string);
begin
  WriteString(Section, Ident, FLeftStringBound + Value + FRightStringBound);
end;

function TJppMemIniFile.ReadBoundString(const Section, Ident, Default: string): string;
begin
  Result := TrimBounds(ReadString(Section, Ident, Default), FLeftStringBound, FRightStringBound);
end;

function TJppMemIniFile.ReadColor(const Section: string; const Ident: string; Default: TColor): TColor;
var
  sColor: string;
  xColor: integer;
begin
  sColor := ReadString(Section, Ident, ColorToString(Default));
  if not IdentToColor(sColor, xColor) then
  try
    xColor := StringToColor(sColor);
  except
    xColor := Default;
  end;

  Result := xColor;
end;

procedure TJppMemIniFile.WriteColor(const Section, Ident: string; Color: TColor);
begin
  WriteString(Section, Ident, ColorToString(Color));
end;

function TJppMemIniFile.ReadDotFloat(const Section, Name: string; Default: Double): Double;
var
  FloatStr: string;
begin
  FloatStr := ReadString(Section, Name, '');
  FloatStr := StringReplace(FloatStr, '.', FormatSettings.DecimalSeparator, []);
  Result := Default;
  if FloatStr <> '' then
    if not TryStrToFloat(FloatStr, Result) then Result := Default;
//  try
//    Result := StrToFloat(FloatStr);
//  except
//    on EConvertError do
//      // Ignore EConvertError exceptions
//    else
//      raise;
//  end;
end;

procedure TJppMemIniFile.WriteDotFloat(const Section, Ident: string; Value: Double);
var
  s: string;
begin
  s := FloatToStr(Value);
  s := StringReplace(s, FormatSettings.DecimalSeparator, '.', []);
  WriteString(Section, Ident, s);
end;

procedure TJppMemIniFile.WriteFontStyle(const Section: string; const Ident: string; FontStyles: TFontStyles);
begin
  WriteString(Section, Ident, FontStylesToStr(FontStyles));
end;

procedure TJppMemIniFile.WriteInt64(const Section, Ident: string; const Value: Int64);
begin
  WriteString(Section, Ident, IntToStr(Value));
end;

function TJppMemIniFile.ReadInt64(const Section, Ident: string; const Default: Int64): Int64;
var
  s: string;
  x: Int64;
begin
  s := ReadString(Section, Ident, 'ERR');
  if TryStrToInt64(s, x) then Result := x else Result := Default;
end;

function TJppMemIniFile.ReadFontStyle(const Section: string; const Ident: string; Default: TFontStyles): TFontStyles;
var
  s: string;
begin
  s := FontStylesToStr(Default);
  s := ReadString(Section, Ident, s);
  Result := StrToFontStyles(s);
end;

procedure TJppMemIniFile.WriteStrings(const Section: string; Items: TStrings; Compress: Boolean);
var
  s: string;
  StringStream: TStringStream;
  MemoryStream: TMemoryStream;
  Buffer: array[0..99] of Byte; //
  i, k, xRead: integer;
begin
  if not Compress then
  begin
    for i := 0 to Items.Count - 1 do
      WriteString(Section, 'Line_' + PadLeft(IntToStr(i + 1), 3, '0'), Items[i]);
  end

  else

  // compression
  begin

    s := Items.Text;
    StringStream := TStringStream.Create(s);
    MemoryStream := TMemoryStream.Create;
    try
      MemoryStream.Size := 0;
      ZCompressStream(StringStream, MemoryStream);

      MemoryStream.Position := 0;
      for i := 0 to MemoryStream.Size div SizeOf(Buffer) do
      begin
        s := '';
        xRead := MemoryStream.Read(Buffer, SizeOf(Buffer));
        for k := 0 to xRead - 1 do s := s + IntToHex(Buffer[k], 2);
        WriteString(Section, 'Buf_' + PadLeft(IntToStr(i + 1), 3, '0'), s);
      end;

    finally
      StringStream.Free;
      MemoryStream.Free;
    end;

  end;


end;

procedure TJppMemIniFile.ReadStrings(const Section: string; Items: TStrings; ItemsCompressed: Boolean);
var
  sl: TStringList;
  ss: TStringStream;
  ms: TMemoryStream;
  i, x, xp: integer;
  s, Hex: string;
  xb: Byte;
begin
  if SectionExists(Section) then
  begin

    sl := TStringList.Create;
    try

      ReadSectionValues(Section, sl);


      if not ItemsCompressed then
      begin
        for i := 0 to sl.Count - 1 do
        begin
          xp := Pos('=', sl[i]);
          if xp > 0 then sl[i] := Copy(sl[i], xp + 1, Length(sl[i]));
        end;

        Items.Assign(sl);
      end

      else


      // decompression
      begin

        ms := TMemoryStream.Create;
        ss := TStringStream.Create;
        try

          s := '';
          for i := 0 to sl.Count - 1 do
          begin
            xp := Pos('=', sl[i]);
            if xp > 0 then s := s + Copy(sl[i], xp + 1, Length(sl[i])); // zapisanie wszystkich warto�ci do �a�cucha s
          end;

          Items.Text := '';
          if s <> '' then
          begin

            for i := 1 to (Length(s) div 2) do
            begin
              x := (i * 2) - 1;
              Hex := '$' + Copy(s, x, 2);
              try
                xb := StrToInt(Hex);
              except
                Items.Text := ''; // niew�a�ciwe dane!!!
                //ShowMessage('Invalid input data!');
                Exit;
              end;
              ms.Write(xb, 1);
            end;

            ss.Size := 0;
            ms.Position := 0;
            ZDecompressStream(ms, ss);
            Items.Text := ss.DataString;

          end;

        finally
          ss.Free;
          ms.Free;
        end;

      end;


    finally
      sl.Free;
    end;

  end;
end;



procedure TJppMemIniFile.SetLeftStringBound(const Value: string);
begin
  if FLeftStringBound = Value then Exit;
  FLeftStringBound := Value;
end;

procedure TJppMemIniFile.SetRightStringBound(const Value: string);
begin
  if FRightStringBound = Value then Exit;
  FRightStringBound := Value;
end;

{$endregion TJppMemIniFile}

end.
