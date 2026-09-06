Unit FrameImageViewer;

{$mode ObjFPC}{$H+}
{$WARN 6058 off : Call to subroutine "$1" marked as inline is not inlined}
Interface

Uses
  Classes, SysUtils, Forms, Controls, Grids, ComCtrls, fgl, BGRABitmap, Types;

Type

  { TViewerImage }

  TViewerImage = Class
  Private
    FFileName: String;
    FCaption: String;
    FThumbnail: TBGRABitmap;
  Public
    Constructor Create;
    Destructor Destroy; Override;

    Procedure InvalidateThumbnail;
    Function GetThumbnail(Const AWidth, AHeight: Integer): TBGRABitmap;

    Property FileName: String Read FFileName Write FFileName;
    Property Caption: String Read FCaption Write FCaption;
  End;

  { TViewerImageList }

  TViewerImageList = Class(Specialize TFPGObjectList<TViewerImage>)
  Public
    Procedure InvalidateThumbnails;
  End;

  { TFrameImageViewer }

  TFrameImageViewer = Class(TFrame)
    grdImages: TDrawGrid;
    ToolBar1: TToolBar;

    Procedure FrameResize(Sender: TObject);
    Procedure grdImagesDrawCell(Sender: TObject; aCol, aRow: Integer;
      aRect: TRect; aState: TGridDrawState);
  Private
    FImages: TViewerImageList;
    FThumbnailBorder: Integer;
    FThumbnailHeight: Integer;
    FThumbnailWidth: Integer;
    Procedure SetThumbnailBorder(Const AValue: Integer);
    Procedure UpdateGridLayout;

  Public
    Constructor Create(TheOwner: TComponent); Override;
    Destructor Destroy; Override;

    Procedure SetThumbnailSize(Const AWidth, AHeight: Integer);

    Procedure AddImage(Const AFilename, ACaption: String);
    Procedure ClearImages;

    Property ThumbnailWidth: Integer Read FThumbnailWidth;
    Property ThumbnailHeight: Integer Read FThumbnailHeight;
    Property ThumbnailBorder: Integer Read FThumbnailBorder Write SetThumbnailBorder;
  End;

Implementation

Uses
  BGRAThumbnail, BGRABitmapTypes;

  {$R *.lfm}

  { TViewerImage }

Constructor TViewerImage.Create;
Begin
  FThumbnail := nil;
End;

Destructor TViewerImage.Destroy;
Begin
  FreeAndNil(FThumbnail);

  Inherited Destroy;
End;

Procedure TViewerImage.InvalidateThumbnail;
Begin
  FreeAndNil(FThumbnail);
End;

Function TViewerImage.GetThumbnail(Const AWidth, AHeight: Integer): TBGRABitmap;
Begin
  If Not Assigned(FThumbnail) Then
    FThumbnail := GetFileThumbnail(FFileName, AWidth, AHeight, BGRAWhite, True);

  Result := FThumbnail;
End;

{ TViewerImageList }

Procedure TViewerImageList.InvalidateThumbnails;
Var
  oImage: TViewerImage;
Begin
  For oImage In Self Do
    oImage.InvalidateThumbnail;
End;

{ TFrameImageViewer }

Constructor TFrameImageViewer.Create(TheOwner: TComponent);
Begin
  Inherited Create(TheOwner);

  FThumbnailWidth := 320;
  FThumbnailHeight := 180;
  FThumbnailBorder := 4;

  FImages := TViewerImageList.Create(True);
End;

Destructor TFrameImageViewer.Destroy;
Begin
  FreeAndNil(FImages);

  Inherited Destroy;
End;

Procedure TFrameImageViewer.UpdateGridLayout;
Var
  iCellWidth, iCellHeight: Integer;
  iCols, iRows: Integer;
  iCaptionHeight: Integer;
Begin
  // Calculations
  iCaptionHeight := grdImages.Canvas.TextHeight('Ag') + 4;

  iCellWidth := FThumbnailWidth + (FThumbnailBorder * 2);
  iCellHeight := FThumbnailHeight + (FThumbnailBorder * 2) + iCaptionHeight;

  iCols := grdImages.ClientWidth Div iCellWidth;
  If iCols < 1 Then
    iCols := 1;

  If FImages.Count = 0 Then
    iRows := 1
  Else
    iRows := (FImages.Count + iCols - 1) Div iCols;

  // UI
  grdImages.DefaultColWidth := iCellWidth;
  grdImages.DefaultRowHeight := iCellHeight;
  grdImages.ColCount := iCols;
  grdImages.RowCount := iRows;

  grdImages.Invalidate;
End;

Procedure TFrameImageViewer.grdImagesDrawCell(Sender: TObject; aCol, aRow: Integer;
  aRect: TRect; aState: TGridDrawState);
Var
  iIndex: Integer;
  iLeft, iTop: Integer;
  oImage: TViewerImage;
  oThumbnail: TBGRABitmap;
Begin
  { Clear the complete cell }
  grdImages.Canvas.FillRect(aRect);

  iIndex := (aRow * grdImages.ColCount) + aCol;
  If iIndex >= FImages.Count Then
    Exit;

  oImage := FImages[iIndex];
  oThumbnail := oImage.GetThumbnail(FThumbnailWidth, FThumbnailHeight);

  If Assigned(oThumbnail) Then
  Begin
    iLeft := aRect.Left + ((aRect.Width - oThumbnail.Width) Div 2);
    iTop := aRect.Top + FThumbnailBorder;

    oThumbnail.Draw(grdImages.Canvas, iLeft, iTop, True);
  End;

  { Caption }
  grdImages.Canvas.TextOut(aRect.Left + FThumbnailBorder,
    aRect.Top + FThumbnailBorder + FThumbnailHeight + 2,
    oImage.Caption);
End;

Procedure TFrameImageViewer.FrameResize(Sender: TObject);
Begin
  UpdateGridLayout;
End;

Procedure TFrameImageViewer.SetThumbnailBorder(Const AValue: Integer);
Begin
  If FThumbnailBorder = AValue Then Exit;

  FThumbnailBorder := AValue;

  UpdateGridLayout;
End;

Procedure TFrameImageViewer.SetThumbnailSize(Const AWidth, AHeight: Integer);
Begin
  If (FThumbnailWidth = AWidth) And (FThumbnailHeight = AHeight) Then
    Exit;

  FThumbnailWidth := AWidth;
  FThumbnailHeight := AHeight;

  FImages.InvalidateThumbnails;

  UpdateGridLayout;
End;

Procedure TFrameImageViewer.AddImage(Const AFilename, ACaption: String);
Var
  oImage: TViewerImage;
Begin
  oImage := TViewerImage.Create;
  oImage.FileName := AFilename;
  oImage.Caption := ACaption;

  FImages.Add(oImage);

  UpdateGridLayout;
End;

Procedure TFrameImageViewer.ClearImages;
Begin
  FImages.Clear;

  UpdateGridLayout;
End;

End.
