Unit MediaTypes;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, fgl;

Type
  { TVideoFile }
  TVideoFile = Class
  Public
    Filename: String;
    Channel: String;
    StartDateTime: TDateTime;
    EndDateTime: TDateTime;
  End;

  { TVideoFiles }
  TVideoFiles = Class(Specialize TFPGObjectList<TVideoFile>);

Implementation

End.
