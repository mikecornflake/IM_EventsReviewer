unit DataFilters;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fgl, FrameBase;

Type
  TDataFilter = Class
    ID: Integer;
    Name: String;
    Caption: String;
  end;

  TDataFilters = Class(Specialize TFPGObjectList<TDataFilter>);

implementation

end.

