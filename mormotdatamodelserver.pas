unit mormotdatamodelserver;

{$I Synopse.inc} // define HASINLINE USETYPEINFO CPU32 CPU64 SQLITE3_FASTCALL

interface

uses
  SysUtils,
  SynCommons,
  mORMot,
  mORMotSQLite3,
  SynSQLite3Static
  {$ifdef WITHLOG}
  ,SynLog
  {$endif}
  ;

{$I mORMotDataModel.inc}

type
  TDataServer = class(TSQLRestServerDB)
  protected
    fRootFolder: TFileName;
    fAppFolder: TFileName;
    aBaseSQL: RawUTF8;
  public
    constructor Create(const aRootFolder: TFileName); reintroduce;
    destructor Destroy; override;
    property RootFolder: TFileName read fRootFolder;
  published
    procedure GetInfoJSON(Ctxt: TSQLRestServerURIContext);
    procedure GetInfoHTML(Ctxt: TSQLRestServerURIContext);
  end;

implementation

uses
  SynSQLite3;

{ TDataServer }

constructor TDataServer.Create(const aRootFolder: TFileName);
var
  aModel:TSQLModel;
  U: TSQLAuthUser;
  aFunction:TUpFunction;
  i:integer;
  s:string;
begin
  fRootFolder := EnsureDirectoryExists(ExpandFileName(aRootFolder),true);
  fAppFolder := EnsureDirectoryExists(ExpandFileName(''),true);

  // define the log level
  {$ifdef WITHLOG}
  with TSQLLog.Family do begin
    PerThreadLog := ptIdentifiedInOnFile;
    Level := [sllError,sllCustom1];
    LevelStackTrace:=[sllNone];
    DestinationPath := fRootFolder+'..'+PathDelim+'log'+PathDelim;
    //DestinationPath := fRootFolder+'..'+PathDelim+'log';
    if not FileExists(DestinationPath) then
       CreateDir(DestinationPath);
  end;
  {$endif}

  aModel:=TSQLModel.Create([TSQLUp]);

  //TSQLMachine.AddFilterOrValidate('UpVersion',TSynValidateText.Create('{MinLength:3}'));
  //TSQLLogEntry.AddFilterOrValidate('UpOS',TSynValidateNonVoidText.Create);

  inherited Create(aModel,fRootFolder+'data.db3',True);

  DB.Synchronous := smNormal;
  DB.LockingMode := lmExclusive;

  CreateMissingTables;
  U := Self.SQLAuthUserClass.Create;
  U.ClearProperties;
  Self.Retrieve('LogonName=?',[],['Admin'],U);
  U.PasswordPlain := ADMINPASS;
  Self.Update(U);
  U.ClearProperties;
  Self.Retrieve('LogonName=?',[],['Supervisor'],U);
  U.PasswordPlain := SUPERVISORPASS;
  Self.Update(U);
  U.ClearProperties;
  Self.Retrieve('LogonName=?',[],['User'],U);
  U.PasswordPlain := USERPASS;
  Self.Update(U);
  U.Free;

  Self.ServiceMethodByPassAuthentication('GetInfoJSON');
  Self.ServiceMethodByPassAuthentication('GetInfoHTML');

  // make base SQL and translate enum into SQL
  aBaseSQL:='SELECT UpVersion,UpOS,UpWidget,Country,DateOfUse,(CASE UpFunction';
  for aFunction := Low(TUpFunction) to High(TUpFunction) do
  begin
    i:=ord(aFunction);
    s:=GetCaptionFromEnum(TypeInfo(TUpFunction),ord(aFunction));
    aBaseSQL:=aBaseSQL+' WHEN '+InttoStr(i)+' THEN '+QuotedStr(s);
  end;
  aBaseSQL:=aBaseSQL+' ELSE ''ErrorUnknown'' END) AS ''Action'',FPCVersion,LazarusVersion,CrossCPUOS,ExtraData,LogEntry FROM Up';

  //AddToServerWrapperMethod(Self,
  //        [fRootFolder+'..'+PathDelim+'templates'+PathDelim,'..\mORMotCurrent\CrossPlatform\templates','..\..\mORMotCurrent\CrossPlatform\templates']);
  {$ifdef WITHLOG}
  TSQLLog.Add.Log(sllCustom1,'Fpcupdeluxe server started !!');
  {$endif}
end;

destructor TDataServer.Destroy;
begin
  {$ifdef WITHLOG}
  TSQLLog.Add.Log(sllCustom1,'Closing fpcupdeluxe server.');
  {$endif}
  fModel.Free;
  Inherited;
end;

procedure TDataServer.GetInfoHTML(Ctxt: TSQLRestServerURIContext);
var
  aSQL:string;
  T:TSQLTableJSON;
  aCountry,aFPCVersion:string;
begin
  case Ctxt.Method of
    mGET:
    begin
      aSQL:=aBaseSQL;
      aCountry:=Ctxt.InputStringOrVoid['Country'];
      if Length(aCountry)>0 then aSQL:=aSQL+' WHERE Country = ' + QuotedStr(aCountry);
      aFPCVersion:=Ctxt.InputStringOrVoid['FPCVersion'];
      if Length(aFPCVersion)>0 then
      begin
        if Length(aCountry)>0 then aSQL:=aSQL+' AND ';
        aSQL:=aSQL+' WHERE FPCVersion = ' + QuotedStr(aFPCVersion);
      end;
      aSQL:=aSQL+';';
      T:=ExecuteList([TSQLUp],aSQL);
      Ctxt.Returns(T.GetHtmlTable,HTTP_SUCCESS,HTML_CONTENT_TYPE_HEADER);
    end;
  end;
end;

procedure TDataServer.GetInfoJSON(Ctxt: TSQLRestServerURIContext);
var
  aSQL:string;
  T:TSQLTableJSON;
  aCountry,aFPCVersion:string;
begin
  case Ctxt.Method of
    mGET:
    begin
      aSQL:=aBaseSQL;
      aCountry:=Ctxt.InputStringOrVoid['Country'];
      if Length(aCountry)>0 then aSQL:=aSQL+' WHERE Country = ' + QuotedStr(aCountry);
      aFPCVersion:=Ctxt.InputStringOrVoid['FPCVersion'];
      if Length(aFPCVersion)>0 then
      begin
        if Length(aCountry)>0 then aSQL:=aSQL+' AND ';
        aSQL:=aSQL+' WHERE FPCVersion = ' + QuotedStr(aFPCVersion);
      end;
      aSQL:=aSQL+';';
      T:=ExecuteList([TSQLUp],aSQL);
      // this will return a escaped json with result as title
      //Ctxt.Results([T.GetJSONValues(True)]);
      // this will return raw json without title
      Ctxt.Returns(T.GetJSONValues(True));
    end;
  end;
end;

initialization
{$ifndef ISDELPHI2010}
{$ifndef HASINTERFACERTTI} // circumvent a old FPC bug
TTextWriter.RegisterCustomJSONSerializerFromTextSimpleType(TypeInfo(TUpFunction));
{$endif}
{$endif}

end.
