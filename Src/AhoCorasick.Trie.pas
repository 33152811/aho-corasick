{***************************************************************************}
{�� ����AC�Զ���Trie��                                                      }
{�� �ܣ��ַ�����ģƥ��:���ڷִʡ��ߴʹ���
{�� �ߣ��e��  2016.08                                                       }
{***************************************************************************}
unit AhoCorasick.Trie;

interface

uses
  System.Classes, System.Generics.Collections, System.Generics.Defaults, AhoCorasick.Interval;

type
  { ״̬�������¹���:
    ת����: ״̬S_Curr������C����ת��S_Next,�����������������ת,��ת��ʧЧ����;
    ʧЧ����: S_Fail := Goto(Fail(S_Curr), C); S_Fail״̬�ڵ�Ӧ������������:
    1.�Ӹ�S_Fail����ֱ��S_Root�������������ַ�,��S_Curr�����������������ַ�����ȫ��ͬ;
    2.����S_FailӦ���Ƿ��������Ľڵ���Ŷ���������һ��;
    3.�����������������1��2�Ľڵ�,��S_Curr �� S_Root;
    ���к���: ��ʾ��FSM����ýڵ�ʱ,��ƥ������е����дʿ�������ȫƥ�� }
  PSuccessNode = ^TSuccessNode;
  TSuccess = TArray<PSuccessNode>;
  TEmits = TArray<TEmit>;
  TState = class(TObject)
  private
    FDepth: Integer;    // ģʽ���ĳ���,Ҳ�Ǹ�״̬�����
    FSuccNum: Integer;
    FSuccess: TSuccess; // ת������
    FFailure: TState;   // ʧЧ����,�����ƥ��,����ת����״̬
    FEmits: TEmits;     // ֻҪ��״̬�ɴ�,���¼ģʽ��
  public
    Idx: Integer;
    constructor Create(const ADepth: Integer);
    destructor Destroy; override;
    function AddEmit(const AKeyword: string): TEmit; overload;
    procedure AddEmit(const AEmits: TEmits); overload;
    function GotoLeaf(const AChar: Char): TState; // ת����(����Successת��)
    function AddLeaf(const AChar: Char): TState;  // ���һ��״̬��Success����
    function IsWordHead: Boolean; inline;         // �Ƿ�Ϊ��ͷ
    procedure QuickSort(const aCompare: IComparer<PSuccessNode>);

    property Success: TSuccess read FSuccess;
    property Failure: TState read FFailure write FFailure;
    property Depth: Integer read FDepth;
    property Emits: TEmits read FEmits; // ��ȡ�ýڵ�����ģʽ��(��)
  end;

  TSuccessNode = record
    Key: Char;
    State: TState;
  end;

  TTrie = class(TObject)
  private
    FFileName: string;         // �ֵ�ʿ�
    FRootState: TState;        // ���ڵ�
    FEmits: TList<TEmit>;      // ƥ��,����״̬�ڵ�����ظ�,��˱������б���һ���ͷ�
    FParses: TList<TEmit>;     // ƥ����(���ͷ�)
    FTokens: TList<TToken>;    // �ִʽ��(���ͷ�)
    FItlTree: TIntervalTree;   //
    FFailuresCreated: Boolean; // �Ƿ�����failure��
    FCaseInsensitive: Boolean; // �Ƿ���Դ�Сд
    FAllowOverlaps: Boolean;   // �Ƿ�����ģʽ����λ����ǰ���ص�
    FOnleyWholeWord: Boolean;  // �Ƿ�ֻƥ����������

    function CreateFragment(aEmit: TEmit; aText: string; aLastCollectedPos: Integer): TToken;
    function CreateMatch(aEmit: TEmit; aText: string): TToken;
    procedure RemovePartialMatches(aSearch: string);
    procedure CreateFailures;
    procedure CheckFailuresCreated;
    procedure ClearParseResult;
    procedure CLearTokenResult;
    procedure StoreEmits(aPos: Integer; aCurrent: TState);
    class function NextState(aCurrent: TState; const AChar: Char): TState;
    class function GotoNext(aCurrent: TState; const AChar: Char): TState;
  public
    constructor Create;
    destructor Destroy; override;

    procedure CaseSensitive;
    procedure RemoveOverlaps;
    procedure OnlyWholeWords;

    procedure AddKeyword(const aKey: string);
    function Tokenize(const aText: string): TList<TToken>;
    function ParseText(const aText: string): TList<TEmit>; // ģʽƥ��,����ֵ�������ͷ�
    function Filter(aText: string): string;
    function HasBlackWord(const aText: string): Boolean;
    function LoadKeywordsFromFile(const aFileName: string): Boolean;
    function Init(const aFileName: string): Boolean;
    property RootState: TState read FRootState;
  end;

function SuccessNodeCompareOrd(const ALeft, ARight: PSuccessNode): Integer;

implementation

uses
  System.SysUtils, System.StrUtils, System.Character;

var
  U_CompareOrd: IComparer<PSuccessNode>;

function IsSkipChar(var AChar: Char; const aCaseInsensitive: Boolean): Boolean;
begin
  Result := not AChar.IsLetterOrDigit;
  if Result then
    Exit;
  if aCaseInsensitive then
    AChar := AChar.ToUpper;
end;

function SuccessNodeCompareOrd(const ALeft, ARight: PSuccessNode): Integer;
begin
  Result := Word(ALeft^.Key) - Word(ARight^.Key);
end;

{ TState }
constructor TState.Create(const ADepth: Integer);
begin
  inherited Create;

  FSuccNum := 0;
  FDepth := ADepth;
  Failure := nil;
  if FDepth = 0 then
    FFailure := Self;
end;

destructor TState.Destroy;
var
  LP: PSuccessNode;
begin
  for LP in FSuccess do
  begin
    LP.State.Free;
    Dispose(LP);
  end;
  SetLength(FSuccess, 0);
  SetLength(FEmits, 0);
  inherited;
end;

procedure TState.AddEmit(const AEmits: TEmits);
var
  LEmit: TEmit;
begin
  for LEmit in AEmits do
  begin
    SetLength(FEmits, Length(FEmits) + 1);
    FEmits[high(FEmits)] := LEmit;
  end;
end;

function TState.AddEmit(const AKeyword: string): TEmit;
begin
  SetLength(FEmits, Length(FEmits) + 1);
  Result := TEmit.Create(0, Length(AKeyword) - 1, AKeyword);
  FEmits[high(FEmits)] := Result;
end;

function TState.AddLeaf(const AChar: Char): TState;
var
  LP: PSuccessNode;
begin
  Result := GotoLeaf(AChar);
  if not Assigned(Result) then
  begin
    Result := TState.Create(FDepth + 1);

    New(LP);
    LP^.Key := AChar;
    LP^.State := Result;
    Inc(FSuccNum);
    SetLength(FSuccess, FSuccNum);
    FSuccess[FSuccNum - 1] := LP;

    QuickSort(U_CompareOrd);
  end;
end;

// @param AChar ϣ�������ַ�ת��
// @Result ת�ƽ��
function TState.GotoLeaf(const AChar: Char): TState;
var
  L, R, C: Integer;
begin
  Result := nil;

  L := 0;
  R := FSuccNum - 1;
  while L <= R do
  begin
    C := (L + R) shr 1;
    if FSuccess[C]^.Key < AChar then
      L := C + 1
    else
    begin
      R := C - 1;
      if FSuccess[C]^.Key = AChar then
        Result := FSuccess[C]^.State;
    end;
  end;
end;

function TState.IsWordHead: Boolean;
begin
  Result := (FDepth = 1);
end;

procedure TState.QuickSort(const aCompare: IComparer<PSuccessNode>);
begin
  TArray.Sort<PSuccessNode>(FSuccess, aCompare);
end;

{ TTrie }
procedure TTrie.CaseSensitive;
begin
  FCaseInsensitive := False;
end;

procedure TTrie.RemoveOverlaps;
begin
  FAllowOverlaps := False;
end;

procedure TTrie.OnlyWholeWords;
begin
  FOnleyWholeWord := True;
end;

constructor TTrie.Create;
begin
  inherited Create;

  FCaseInsensitive := True;
  FAllowOverlaps := True;
  FOnleyWholeWord := False;

  FRootState := TState.Create(0);
  FFailuresCreated := False;

  FEmits := TList<TEmit>.Create;
  FParses := TList<TEmit>.Create;
  FTokens := TList<TToken>.Create;
end;

destructor TTrie.Destroy;
var
  I: Integer;
begin
  if Assigned(FRootState) then
    FRootState.Free;

  for I := 0 to FEmits.Count - 1 do
  begin
    FEmits[I].Free;
  end;
  FEmits.Free;

  ClearParseResult;
  FParses.Free;

  CLearTokenResult;
  FTokens.Free;

  inherited;
end;

procedure TTrie.ClearParseResult;
var
  I: Integer;
begin
  if FAllowOverlaps then
  begin
    for I := 0 to FParses.Count - 1 do
      FParses[I].Free;
  end
  else
  begin
    if Assigned(FItlTree) then
      FItlTree.Free;
  end;
  FParses.Clear;
end;

procedure TTrie.CLearTokenResult;
var
  I: Integer;
begin
  for I := 0 to FTokens.Count - 1 do
    FTokens[I].Free;

  FTokens.Clear;
end;

procedure TTrie.AddKeyword(const aKey: string);
var
  LKey: string;
  LCurr: TState;
  LChar: Char;
  LEmit: TEmit;
begin
  if Length(aKey) <= 0 then
    Exit;

  if FCaseInsensitive then
    LKey := aKey.ToUpper;

  LCurr := FRootState;
  for LChar in LKey do
  begin
    if not LChar.IsLetterOrDigit then
      Continue;

    LCurr := LCurr.AddLeaf(LChar);
  end;
  LEmit := LCurr.AddEmit(aKey);
  FEmits.Add(LEmit);
  FFailuresCreated := False;
end;

procedure TTrie.CheckFailuresCreated;
begin
  if not FFailuresCreated then
    CreateFailures;
end;

procedure TTrie.CreateFailures;
var
  LQueue: TQueue<TState>;
  LCurr, LNext: TState;
  LPreFail, LNextFail: TState;
  LP: PSuccessNode;
begin
  LQueue := TQueue<TState>.Create;
  try
    // ��һ���������Ϊ1�Ľڵ��failure��Ϊ���ڵ�
    for LP in FRootState.Success do
    begin
      LCurr := LP^.State;
      LCurr.Failure := FRootState;
      LQueue.Enqueue(LCurr);
    end;

    // �ڶ�����Ϊ��� > 1 �Ľڵ㽨��failure������һ��bfs
    while LQueue.Count > 0 do
    begin
      LCurr := LQueue.Dequeue;
      // ת��Ҷ�ڵ��Char����
      for LP in LCurr.Success do
      begin
        LNext := LP^.State;
        LQueue.Enqueue(LNext);

        // ���¶����ҵ�S_Fail
        LPreFail := LCurr.Failure;
        while NextState(LPreFail, LP^.Key) = nil do
          LPreFail := LPreFail.Failure;

        LNextFail := NextState(LPreFail, LP^.Key);
        LNext.Failure := LNextFail;
        // �������ʼ������б�
        LNext.AddEmit(LNextFail.Emits)
      end;
    end;

    FFailuresCreated := True;
  finally
    LQueue.Free;
  end;
end;

procedure TTrie.StoreEmits(aPos: Integer; aCurrent: TState);
var
  LNew, LOld: TEmit;
begin
  for LOld in aCurrent.Emits do
  begin
    LNew := TEmit.Create(aPos - LOld.Size + 1, aPos, LOld.Keyword);
    FParses.Add(LNew);
  end;
end;

function TTrie.LoadKeywordsFromFile(const aFileName: string): Boolean;
var
  LLines: TStringList;
  LKey: string;
begin
  Result := False;
  if not FileExists(aFileName) then
    Exit;

  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(aFileName, TEncoding.UTF8);
    for LKey in LLines do
    begin
      AddKeyword(Trim(LKey));
    end;
    Result := True;
  finally
    LLines.Free;
  end;
end;

function TTrie.Init(const aFileName: string): Boolean;
begin
  FFileName := aFileName;
  if LoadKeywordsFromFile(FFileName) then
    CreateFailures;

  Result := FFailuresCreated;
end;

class function TTrie.GotoNext(aCurrent: TState; const AChar: Char): TState;
begin
  Result := NextState(aCurrent, AChar); // �Ȱ�Success��ת
  while Result = nil do
  begin
    aCurrent := aCurrent.Failure;
    Result := NextState(aCurrent, AChar)
  end;
end;

class function TTrie.NextState(aCurrent: TState; const AChar: Char): TState;
begin
  Result := aCurrent.GotoLeaf(AChar);
  if (Result = nil) and (aCurrent.Depth = 0) then
    Result := aCurrent;
end;

function TTrie.CreateFragment(aEmit: TEmit; aText: string; aLastCollectedPos: Integer): TToken;
var
  LCount: Integer;
begin
  LCount := Length(aText) + 1;
  if Assigned(aEmit) then
    LCount := aEmit.GetStart;
  Dec(LCount, aLastCollectedPos);
  Result := TFragmentToken.Create(MidStr(aText, aLastCollectedPos, LCount));
end;

function TTrie.CreateMatch(aEmit: TEmit; aText: string): TToken;
begin
  Result := TMatchToken.Create(MidStr(aText, aEmit.GetStart, aEmit.Size), aEmit);
end;

function TTrie.Tokenize(const aText: string): TList<TToken>;
var
  LLastCollectedPos: Integer;
  LEmit: TEmit;
begin
  ClearParseResult;
  ParseText(aText);

  LLastCollectedPos := 1;
  for LEmit in FParses do
  begin
    if LEmit.GetStart - LLastCollectedPos > 0 then
      FTokens.Add(CreateFragment(LEmit, aText, LLastCollectedPos));
    FTokens.Add(CreateMatch(LEmit, aText));
    LLastCollectedPos := LEmit.GetEnd + 1;
  end;

  if Length(aText) - LLastCollectedPos > 0 then
    FTokens.Add(CreateFragment(nil, aText, LLastCollectedPos));
  Result := FTokens;
end;

function TTrie.ParseText(const aText: string): TList<TEmit>;
var
  I: Integer;
  LText: string;
  LChar: Char;
  LCurr: TState;
begin
  CheckFailuresCreated;
  ClearParseResult;

  if FCaseInsensitive then
    LText := aText.ToUpper;

  I := 0;
  LCurr := FRootState;
  for LChar in LText do
  begin
    Inc(I);
    if not LChar.IsLetterOrDigit then
      Continue;

    LCurr := GotoNext(LCurr, LChar);
    StoreEmits(I, LCurr);
  end;

  if FOnleyWholeWord then
    RemovePartialMatches(LText);

  if not FAllowOverlaps then
  begin
    FItlTree := TIntervalTree.Create(TList<TInterval>(FParses));
    FItlTree.RemoveOverlaps(TList<TInterval>(FParses));
  end;

  Result := FParses;
end;

function TTrie.Filter(aText: string): string;
var
  I, J, N, LStart: Integer;
  LText: string;
  LChar: Char;
  LCurr: TState;
begin
  CheckFailuresCreated;

  if FCaseInsensitive then
    LText := aText.ToUpper;

  N := 0;
  LCurr := FRootState;
  for I := 1 to Length(LText) do
  begin
    Inc(N);
    LChar := LText[I];
    if not LChar.IsLetterOrDigit then
    begin
      Continue;
    end;
    LCurr := GotoNext(LCurr, LChar);

    if LCurr.IsWordHead then
    begin
      N := 0;
    end;
    if Length(LCurr.Emits) > 0 then
    begin
      LStart := I - N;
      for J := LStart to I do
        aText[J] := '*';

      N := 0;
    end;
  end;
  Result := aText;
end;

function TTrie.HasBlackWord(const aText: string): Boolean;
var
  I: Integer;
  LChar: Char;
  LCurr: TState;
begin
  Result := False;
  CheckFailuresCreated;

  LCurr := FRootState;
  for I := 1 to Length(aText) do
  begin
    LChar := aText[I];
    if not LChar.IsLetterOrDigit then
      Continue;

    if FCaseInsensitive then
      LChar := LChar.ToUpper;

    LCurr := GotoNext(LCurr, LChar);
    if Length(LCurr.Emits) > 0 then
    begin
      Exit(True);
    end;
  end;
end;

procedure TTrie.RemovePartialMatches(aSearch: string);
var
  LSize: Integer;
  I: Integer;
  LEmit: TEmit;
begin
  LSize := Length(aSearch);
  for I := FParses.Count - 1 downto 0 do
  begin
    LEmit := FParses[I];
    if ((LEmit.GetStart = 1) or (not Char(aSearch[LEmit.GetStart - 1]).IsLetterOrDigit)) and
      ((LEmit.GetEnd = LSize) or (not Char(aSearch[LEmit.GetEnd + 1]).IsLetterOrDigit)) then
    begin
      Continue;
    end;

    FParses.Remove(LEmit);
    LEmit.Free;
  end;
end;

initialization
  U_CompareOrd := TComparer<PSuccessNode>.Construct(SuccessNodeCompareOrd);

finalization
  U_CompareOrd := nil;

end.
