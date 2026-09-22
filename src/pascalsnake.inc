{ Diretivas compartilhadas (dual Delphi / Free Pascal).

  Toda unit do projeto inclui este arquivo logo apos o 'unit ...;'. No Delphi
  ele so normaliza o define de plataforma; no FPC ativa o mode Delphi com
  strings longas.

  PASCALSNAKE_WINDOWS: definido quando o alvo e' Windows, em qualquer
  compilador (Delphi define MSWINDOWS; FPC define WINDOWS). }

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}
{$IFDEF MSWINDOWS}{$DEFINE PASCALSNAKE_WINDOWS}{$ENDIF}
{$IFDEF WINDOWS}{$IFNDEF PASCALSNAKE_WINDOWS}{$DEFINE PASCALSNAKE_WINDOWS}{$ENDIF}{$ENDIF}
