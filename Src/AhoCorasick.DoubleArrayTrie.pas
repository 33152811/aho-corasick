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
    ROOT = 1;
    INVALID_MAP = 0;
  private
    FTrie: TTrie;
    FBase: TArray<Integer>;
    FCheck: TArray<Integer>;
    FFail: TArray<Integer>;
    FUsed: TArray<Boolean>;
    FSize: Integer;
    FInited: Boolean;
    FFileName: string;
    FCaseInsensitive: Boolean;  //�Ƿ���Դ�Сд

    procedure ReSize(const aSize: Integer);
    procedure MapWords;
    procedure CalcArrayValue;
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
  U_CompareCode: IComparer<PSuccessNode>;

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
  SetLength(FUsed, aSize);
  FSize := aSize;
end;

procedure TDoubleArrayTrie.MapWords;
var
  LQueue: TQueue<TState>;
  LCode: Word;
  LP: PSuccessNode;
  LCurr_S: TState;
begin
  LQueue := TQueue<TState>.Create;
  try
    FSize := 2;  //�±�:0�޸����޷����,��ʹ��; 1ΪROOT�ڵ�
    LCode := INVALID_MAP;   //�ַ���ʼ����
    
    for LP in FTrie.RootState.Success do
    begin
      LQueue.Enqueue(LP.State);

      if U_MAP[Word(LP.Key)] = INVALID_MAP then
      begin
        Inc(FSize);  //��ȡ���=1�Ŀ��
        Inc(LCode);
        U_MAP[Word(LP.Key)] := LCode;
      end;
    end;      

    {�������>1�Ľڵ�}
    while LQueue.Count > 0 do
    begin
      LCurr_S := LQueue.Dequeue;
      for LP in LCurr_S.Success do
      begin
        LQueue.Enqueue(LP.State);

        Inc(FSize);
        if U_MAP[Word(LP.Key)] = INVALID_MAP then
        begin
          Inc(LCode);
          U_MAP[Word(LP.Key)] := LCode;
        end;
      end;
    end;

    ReSize(FSize);  //�����ڴ�

    {��ʼ��ROOT�ڵ�����}
    FBase[ROOT] := 1;
    FCheck[ROOT] := ROOT;
    FFail[ROOT] := ROOT;
    FTrie.RootState.Idx := ROOT;
  finally
    LQueue.Free;
  end;
end;

procedure TDoubleArrayTrie.CalcArrayValue;
var
  LQueue: TQueue<TState>;
  LP: PSuccessNode;
  LCurr, LNext: TDAState;
  LCurr_S, LNext_S: TState;
  LStart, LIdx, LBase: Integer;
begin
  LQueue := TQueue<TState>.Create;
  try
    LStart := 2;
    {�������=1�ڵ��Check,Failֵ}
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
      Inc(LStart);  //��ʼ���������<=1�Ľڵ�
    end;

    {���>1�Ľڵ�}
    while LQueue.Count > 0 do
    begin 
      LCurr_S := LQueue.Dequeue;
      LCurr := LCurr_S.Idx;
      if Length(LCurr_S.Success) = 0 then
        Continue;

      LCurr_S.QuickSort(U_CompareCode);
      {���㸸�ڵ�Baseֵ}
      if FBase[LCurr] = 0 then
      begin
        while FUsed[LStart] do
          Inc(LStart);

        LIdx := LStart;
        LNext := LStart;
        repeat
          LBase := LIdx - U_MAP[Word(LCurr_S.Success[0].Key)];
          for LP in LCurr_S.Success do
          begin
            LNext := LBase + U_MAP[Word(LP.Key)];
            if LNext >= FSize then
              ReSize(LNext + 1);
            if FUsed[LNext] then
              Break;
          end;

          Inc(LIdx);
        until not FUsed[LNext];

        FBase[LCurr] := LBase;
      end;

      {�����ӽڵ�Checkֵ}
      for LP in LCurr_S.Success do
      begin
        LNext_S := LP.State;
        LQueue.Enqueue(LNext_S);
        
        LNext := Abs(FBase[LCurr]) + U_MAP[Word(LP.Key)];
        if Length(LNext_S.Emits) > 0 then
          FCheck[LNext] := -LCurr
        else
          FCheck[LNext] := LCurr;
        FUsed[LNext] := True;
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
        
        FFail[LNext_S.Idx] := LNext_S.Failure.Idx;
      end;
    end;

    SetLength(FUsed, 0);
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
begin
  FFileName := aFileName;
  FTrie := TTrie.Create;
  try
    if FTrie.Init(FFileName) then
    begin
      MapWords;
      CalcArrayValue;
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
    if not LChar.IsLetterOrDigit then
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
  U_CompareCode := TComparer<PSuccessNode>.Construct(SuccessNodeCompareMapCode);

finalization
  U_CompareCode := nil;

end.
