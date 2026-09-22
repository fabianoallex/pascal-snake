unit Snake.DUnitXCompat;

{ Adaptador fino: expoe a API de asserts do FPCUnit (AssertEquals, AssertTrue,
  AssertFalse) por cima do Assert do DUnitX, para que o CORPO dos testes seja
  identico nas duas suites -- so' muda a declaracao das fixtures ([Test] contra
  secao published). Mesmo padrao do Redis.DUnitXCompat do pascal-redis-faa. }

interface

uses
  DUnitX.TestFramework;

type
  TAssert = class
  public
    class procedure AssertEquals(AExpected, AActual: Integer); overload;
    class procedure AssertEquals(const AMessage: string;
      AExpected, AActual: Integer); overload;
    class procedure AssertTrue(ACondition: Boolean); overload;
    class procedure AssertTrue(const AMessage: string;
      ACondition: Boolean); overload;
    class procedure AssertFalse(ACondition: Boolean); overload;
    class procedure AssertFalse(const AMessage: string;
      ACondition: Boolean); overload;
  end;

implementation

class procedure TAssert.AssertEquals(AExpected, AActual: Integer);
begin
  Assert.AreEqual(AExpected, AActual);
end;

class procedure TAssert.AssertEquals(const AMessage: string;
  AExpected, AActual: Integer);
begin
  Assert.AreEqual(AExpected, AActual, AMessage);
end;

class procedure TAssert.AssertTrue(ACondition: Boolean);
begin
  Assert.IsTrue(ACondition);
end;

class procedure TAssert.AssertTrue(const AMessage: string;
  ACondition: Boolean);
begin
  Assert.IsTrue(ACondition, AMessage);
end;

class procedure TAssert.AssertFalse(ACondition: Boolean);
begin
  Assert.IsFalse(ACondition);
end;

class procedure TAssert.AssertFalse(const AMessage: string;
  ACondition: Boolean);
begin
  Assert.IsFalse(ACondition, AMessage);
end;

end.
