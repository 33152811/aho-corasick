{***************************************************************************}
{�� ����AC�Զ������˫����Trie��; ֻ�ʺ�����ʹ���;                         }
{�� �ܣ������ַ�����ģʽƥ��,ռ�ÿռ����ACTrie�ϴ�,�����ʱ��ʼ����ʱ��
{�� �ߣ��e��  2016.08                                                       }
{***************************************************************************}
unit AhoCorasick.DoubleArrayTrie;

interface

uses
  System.Classes, System.Generics.Collections, AhoCorasick.Trie;

type
  {Base����: 1.ÿ��Ԫ�ر�ʾһ��Trie�ڵ�,��һ��״̬,��ʼ״̬S_Root����Ϊ FBase[1] = 1;
             2.���ĳ��״̬xΪһ�������Ĵ�,�� FBase [x]  ����Ϊ����(-FBase [x] );
   Check����: 1.ÿ��Ԫ�ر�ʾĳ��״̬��ǰ��״̬; S_Root: FCheck[0] = 0;
              2.���ĳ��״̬yΪһ�������Ĵ�,�Ҹôʲ�Ϊ�����ʵ�ǰ׺,�� FCheck [y]  ����Ϊ -FCheck [y] ;
   Fail����: ʧ�ܺ���ӳ��;
   ��ϵ����: <S_Curr_Idx:��ǰ״̬���±�, S_Next_Idx:ת��״̬���±�, Char: �����ַ�����ֵ>;
             1.FBase[S_Curr_Idx] + FMap[Char] = S_Next_Idx;
             2.FCheck[S_Next_Idx] = S_Curr_Idx;}
  TDoubleArrayTrie = class(TObject)
  private type
    TDAState = Integer;
  private const
    ROOT = 0;
    INVALID_MAP = 0;
  private
    FTrie: TTrie;
    FBase: TArray<Integer>;
    FCheck: TArray<Integer>;
    FFail: TArray<Integer>;
    FSize: Integer;
    FInited: Boolean;
    FFileName: string;
    FCaseInsensitive: Boolean;  //�Ƿ���Դ�Сд

    procedure ReSize(const aSize: Integer);
    function MapWords: Integer;
    procedure CalcArrayValue(const aBaseStart: Integer);
    function NextState(aCurrent: TDAState; const ACode: Word): TDAState;
    function GotoNext(aCurrent: TDAState; const AKey: Word): TDAState;
  public
    constructor Create();
    destructor Destroy; override;

    procedure CaseSensitive;
    function Init(const aFileName: string): Boolean;
    function Filter(aText: string): string;
    function HasBlackWord(const aText: string): Boolean;
  end;

function SuccessNodeCompareMapCode(const ALeft, ARight: PSuccessNode): Integer;
  
implementation

uses
  System.Generics.Defaults, System.SysUtils, System.Character;

var
  U_MAP: array[Word] of Word;
  U_Compare: IComparer<PSuccessNode>;

function SuccessNodeCompareMapCode(const ALeft, ARight: PSuccessNode): Integer;
begin
  Result := U_MAP[Word(ALeft.Key)] - U_MAP[Word(ARight.Key)];
end;
  
{ TDoubleArrayTrie }
constructor TDoubleArrayTrie.Create;
begin
  inherited Create;
  FInited := False;
  FCaseInsensitive := True;
end;

destructor TDoubleArrayTrie.Destroy;
begin
  ReSize(0);
  inherited;
end;

procedure TDoubleArrayTrie.ReSize(const aSize: Integer);
begin
  SetLength(FBase, aSize);
  SetLength(FCheck, aSize);
  SetLength(FFail, aSize);
  FSize := aSize;
end;

function TDoubleArrayTrie.MapWords: Integer;
var
  I: Integer;
  LCode: Word;
  LQueue: TQueue<TState>;
  LP: PSuccessNode;
  LCurr, LNext: TState;
begin
  for I := Low(U_MAP) to High(U_MAP) do
  begin
    U_MAP[I] := INVALID_MAP;
  end;
  
  FSize := 2;
  LCode := INVALID_MAP;   //�ַ���ʼ����

  LQueue := TQueue<TState>.Create;
  try
    for LP in FTrie.RootState.Success do
    begin
      LQueue.Enqueue(LP.State);

      if U_MAP[Word(LP.Key)] = INVALID_MAP then
      begin
        Inc(LCode);
        U_MAP[Word(LP.Key)] := LCode;
        //��ȡ���=1�Ŀ��
        Inc(FSize);
      end;
    end;      
    Result := FSize;

    //�������>1�Ľڵ�
    while LQueue.Count > 0 do
    begin
      LCurr := LQueue.Dequeue;
      for LP in LCurr.Success do
      begin
        LNext := LP.State;
        LQueue.Enqueue(LNext);

        if U_MAP[Word(LP.Key)] = INVALID_MAP then
        begin
          Inc(LCode);
          U_MAP[Word(LP.Key)] := LCode;
        end;
        Inc(FSize);
      end;
    end;

    ReSize(FSize);

    FBase[ROOT] := 1;
    FCheck[ROOT] := ROOT;
    FFail[ROOT] := ROOT;
    FTrie.RootState.Idx := ROOT;
  finally
    LQueue.Free;
  end;
end;

procedure TDoubleArrayTrie.CalcArrayValue(const aBaseStart: Integer);
var
  LQueue: TQueue<TState>;
  LP: PSuccessNode;
  LCurr, LNext: TDAState;
  LCurr_S, LNext_S: TState;
  LIdx, LBase, LOK: Integer;
begin
  LQueue := TQueue<TState>.Create;
  try
{����FCheck�����ֵ}  
    //���=1�Ľڵ�
    for LP in FTrie.RootState.Success do
    begin
      LCurr_S := LP.State;
      LQueue.Enqueue(LCurr_S);

      LCurr := FBase[ROOT] + U_MAP[Word(LP.Key)];
      if Length(LCurr_S.Emits) > 0 then
        FCheck[LCurr] := -ROOT
      else
        FCheck[LCurr] := ROOT;
      FFail[LCurr] := ROOT;
      LCurr_S.Idx := LCurr;
    end;

    //���>1�Ľڵ�
    while LQueue.Count > 0 do
    begin 
      LCurr_S := LQueue.Dequeue;
      LCurr := LCurr_S.Idx;
      if Length(LCurr_S.Success) = 0 then
        Continue;

      TArray.Sort<PSuccessNode>(LCurr_S.Success, U_Compare);
      if FBase[LCurr] = 0 then
      begin
        LIdx := aBaseStart;
        repeat      
          LOK := 0;
          LBase := LIdx - U_MAP[Word(LCurr_S.Success[0].Key)];
          for LP in LCurr_S.Success do
          begin
            LNext := LBase + U_MAP[Word(LP.Key)];
            if LNext >= FSize then
              ReSize(LNext + 1);
            LOK := LOK or FCheck[LNext] or FBase[LNext];
            if LOK <> 0 then
              Break;
          end;

          Inc(LIdx);
        until (LOK = 0);

        FBase[LCurr] := LBase;
      end;
      
      for LP in LCurr_S.Success do
      begin
        LNext_S := LP.State;
        LQueue.Enqueue(LNext_S);
        
        LNext := Abs(FBase[LCurr]) + U_MAP[Word(LP.Key)];
        if Length(LNext_S.Emits) > 0 then
          FCheck[LNext] := -LCurr
        else
          FCheck[LNext] := LCurr;
        LNext_S.Idx := LNext;
      end;
    end;

{����FFail�����ֵ}
    for LP in FTrie.RootState.Success do
    begin
      LQueue.Enqueue(LP.State);
    end;

    while LQueue.Count > 0 do
    begin 
      LCurr_S := LQueue.Dequeue;
      for LP in LCurr_S.Success do
      begin
        LNext_S := LP.State;
        LQueue.Enqueue(LNext_S);
        
        LNext := LNext_S.Idx;
        FFail[LNext] := LNext_S.Failure.Idx;
      end;
    end;

    FInited := True;
  finally
    LQueue.Free;
  end;
end;

procedure TDoubleArrayTrie.CaseSensitive;
begin
  FCaseInsensitive := False;
end;

function TDoubleArrayTrie.Init(const aFileName: string): Boolean;
var
  LStart: Integer;
begin
  FFileName := aFileName;
  FTrie := TTrie.Create;
  try
    if FTrie.Init(FFileName) then
    begin
      LStart := MapWords;
      CalcArrayValue(LStart);
    end;
    Result := FInited;
  finally
    FTrie.Free;
  end;
end;

function TDoubleArrayTrie.NextState(aCurrent: TDAState; const ACode: Word): TDAState;
begin
  Result := Abs(FBase[aCurrent]) + ACode;
  if Abs(FCheck[Result]) <> aCurrent then
    Result := -1;
    
  if (Result = -1) and (aCurrent = ROOT) then
    Result := ROOT;
end;

function TDoubleArrayTrie.GotoNext(aCurrent: TDAState; const AKey: Word): TDAState;
begin
  Result := NextState(aCurrent, U_Map[AKey]); // �Ȱ�Success��ת
  while Result = -1 do
  begin
    aCurrent := FFail[aCurrent];
    Result := NextState(aCurrent, U_Map[AKey])
  end;
end;

function TDoubleArrayTrie.Filter(aText: string): string;
var
  I, J, N, LStart: Integer;
  LText: string;
  LChar: Char;
  LCurr: TDAState;
begin
  if not FInited then
    Init(FFileName);

  if FCaseInsensitive then
    LText := aText.ToUpper;
  
  N := 0;
  LCurr := ROOT;
  for I := 1 to Length(LText) do
  begin
    Inc(N);
    LChar := LText[I];
    if not LChar.IsLetterOrDigit then
    begin
      Continue;
    end;
    LCurr := GotoNext(LCurr, Word(LChar));

    if Abs(FCheck[LCurr]) = ROOT then
    begin
      N := 0;
    end;
    if FCheck[LCurr] < 0 then
    begin
      LStart := I - N;
      for J := LStart to I do
        aText[J] := '*';

      N := 0;
    end;
  end;
  Result := aText;
end;

function TDoubleArrayTrie.HasBlackWord(const aText: string): Boolean;
var
  I: Integer;
  LChar: Char;
  LCurr: TDAState;
begin
  Result := False;
  if not FInited then
    Init(FFileName);

  LCurr := ROOT;
  for I := 1 to Length(aText) do
  begin
    LChar := aText[I];
    if LChar.IsPunctuation then
      Continue;

    if FCaseInsensitive then
      LChar := LChar.ToUpper;

    LCurr := GotoNext(LCurr, Word(LChar));
    if FCheck[LCurr] < 0 then
    begin
      Exit(True);
    end;
  end;
end;


initialization
  U_Compare := TComparer<PSuccessNode>.Construct(SuccessNodeCompareMapCode);

end.
