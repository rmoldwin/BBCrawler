SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER FUNCTION [dbo].[Clean2]
-- =============================================
-- Author:      Moldwin, Richard
-- Version:     3.0.2 (2026-10-08). Check with SELECT dbo.Clean2Version().
-- Create Date: 2026 Sep 28. Successor to dbo.Clean (2022 Aug 29 ... 2026-07-09).
--              GENERATED from clean2.py - edit the rules there and regenerate,
--              so SQL and Python stay identical.
-- Description: Comparison-key normalizer. Use as
--                  dbo.Clean2(dbo.CleanBritishSpelling2(Term))
--              Drops commas, NOS and the word 'type'; '/' and dashes become
--              spaces ('::' too); grade/type/acronym Roman numerals become
--              digits; 'non X' and bound prefixes (micro, pre, ...) join;
--              every minus sign is kept and written as U+2212 MINUS SIGN ('ALK-)', '5q-)');
--              karyotypes closed up ('del(5q)');
--              possessive 's dropped. Never changes letter case. Word rules
--              match whole words only. Not display text.
--   v3:        lowercase articles the/a/an removed (case-sensitive, guarded);
--              numerals before ';' ':'; no space before ';' ':'; trailing ';' ':'
--              dropped; 'pre-pre-B' -> 'prepreB'; Greek letters -> names;
--              '&' -> 'and'; double/special quotes -> straight single quote.
--
--   vs dbo.Clean:  no British spelling (it lives in CleanBritishSpelling2);
--   special characters from the same tables as CleanBritishSpelling2;
--   exact case-sensitive matching (BIN2) throughout; whole-word NOS/type/non,
--   so 'nose', 'types' and 'Canon' are safe; numerals also at the end of a
--   closing parenthetical, plus grade/type IV; apostrophe look-alikes; a
--   trailing period dropped. No loops, a single RETURN, every statement but
--   the first reads @s once, and consecutive replacements are nested into
--   few statements - so SQL Server actually inlines it.
-- =============================================
--
--   NVARCHAR(4000), not MAX: MAX strings are handled as large objects, and with
--   ~370 replacements per call that made Clean2 ~10x slower (3.7 s vs 0.4 s for
--   the 5,709 terms of CPC_MorphCodeList_2026Jul28). Terms are nvarchar(255).
--   An input longer than 4,000 characters would be truncated.
(
    @StringIn NVARCHAR(4000)
)
RETURNS NVARCHAR(4000)
WITH SCHEMABINDING
AS
BEGIN
    -- A variable does not keep a collation, so every comparison below names
    -- BIN2 explicitly: exact code points, case-sensitive, no linguistic
    -- expansions (under a linguistic collation 'ß' matches 'ss').
    -- NULL flows through every step as NULL; there is a single RETURN.
    DECLARE @s NVARCHAR(4000) = @StringIn;

    -- 0. Everything from '(specify' onward is dropped (as dbo.Clean). First, because it is the one step that must read the string twice - done here it costs nothing
    SET @s = REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'(Specify', N'(specify')
        , N'(SPECIFY', N'(specify');
    SET @s = LEFT(@s, CHARINDEX(N'(specify', (@s + N'(specify') COLLATE Latin1_General_100_BIN2) - 1);

    -- 1. Special characters - the SAME tables as dbo.CleanBritishSpelling2
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(8203), N'')  -- U+200B ZERO WIDTH SPACE
        , NCHAR(8204), N'')  -- U+200C ZERO WIDTH NON-JOINER
        , NCHAR(8205), N'')  -- U+200D ZERO WIDTH JOINER
        , NCHAR(8288), N'')  -- U+2060 WORD JOINER
        , NCHAR(65279), N'')  -- U+FEFF ZERO WIDTH NO-BREAK SPACE
        , NCHAR(173), N'')  -- U+00AD SOFT HYPHEN
        , NCHAR(8206), N'')  -- U+200E LEFT-TO-RIGHT MARK
        , NCHAR(8207), N'')  -- U+200F RIGHT-TO-LEFT MARK
        , NCHAR(8234), N'')  -- U+202A LEFT-TO-RIGHT EMBEDDING
        , NCHAR(8235), N'')  -- U+202B RIGHT-TO-LEFT EMBEDDING
        , NCHAR(8236), N'')  -- U+202C POP DIRECTIONAL FORMATTING
        , NCHAR(8237), N'')  -- U+202D LEFT-TO-RIGHT OVERRIDE
        , NCHAR(8238), N'')  -- U+202E RIGHT-TO-LEFT OVERRIDE
        , NCHAR(8294), N'')  -- U+2066 LEFT-TO-RIGHT ISOLATE
        , NCHAR(8295), N'')  -- U+2067 RIGHT-TO-LEFT ISOLATE
        , NCHAR(8296), N'')  -- U+2068 FIRST STRONG ISOLATE
        , NCHAR(8297), N'')  -- U+2069 POP DIRECTIONAL ISOLATE
        , NCHAR(9), N' ')  -- U+0009 CHARACTER TABULATION
        , NCHAR(10), N' ')  -- U+000A LINE FEED
        , NCHAR(13), N' ')  -- U+000D CARRIAGE RETURN
        , NCHAR(160), N' ')  -- U+00A0 NO-BREAK SPACE
        , NCHAR(8194), N' ')  -- U+2002 EN SPACE
        , NCHAR(8195), N' ')  -- U+2003 EM SPACE
        , NCHAR(8196), N' ')  -- U+2004 THREE-PER-EM SPACE
        , NCHAR(8197), N' ')  -- U+2005 FOUR-PER-EM SPACE
        , NCHAR(8198), N' ')  -- U+2006 SIX-PER-EM SPACE
        , NCHAR(8199), N' ')  -- U+2007 FIGURE SPACE
        , NCHAR(8200), N' ')  -- U+2008 PUNCTUATION SPACE
        , NCHAR(8201), N' ')  -- U+2009 THIN SPACE
        , NCHAR(8202), N' ');  -- U+200A HAIR SPACE
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(8239), N' ')  -- U+202F NARROW NO-BREAK SPACE
        , NCHAR(8287), N' ')  -- U+205F MEDIUM MATHEMATICAL SPACE
        , NCHAR(12288), N' ')  -- U+3000 IDEOGRAPHIC SPACE
        , NCHAR(8208), N'-')  -- U+2010 HYPHEN
        , NCHAR(8209), N'-')  -- U+2011 NON-BREAKING HYPHEN
        , NCHAR(8210), N'-')  -- U+2012 FIGURE DASH
        , NCHAR(8211), N'-')  -- U+2013 EN DASH
        , NCHAR(8212), N'-')  -- U+2014 EM DASH
        , NCHAR(8213), N'-')  -- U+2015 HORIZONTAL BAR
        , NCHAR(65112), N'-')  -- U+FE58 SMALL EM DASH
        , NCHAR(65123), N'-')  -- U+FE63 SMALL HYPHEN-MINUS
        , NCHAR(65293), N'-')  -- U+FF0D FULLWIDTH HYPHEN-MINUS
        , NCHAR(223), NCHAR(946))  -- U+00DF LATIN SMALL LETTER SHARP S, U+03B2 GREEK SMALL LETTER BETA
        , NCHAR(230), N'ae')  -- U+00E6 LATIN SMALL LETTER AE
        , NCHAR(198), N'Ae')  -- U+00C6 LATIN CAPITAL LETTER AE
        , NCHAR(339), N'oe')  -- U+0153 LATIN SMALL LIGATURE OE
        , NCHAR(338), N'Oe');  -- U+0152 LATIN CAPITAL LIGATURE OE

    -- 2. Remaining control characters removed (so the sentinels and markers used in steps 6 and 9e cannot occur in the input)
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(1), N'')  -- U+0001 control character
        , NCHAR(2), N'')  -- U+0002 start sentinel
        , NCHAR(3), N'')  -- U+0003 end sentinel
        , NCHAR(4), N'')  -- U+0004 control character
        , NCHAR(5), N'')  -- U+0005 control character
        , NCHAR(6), N'')  -- U+0006 control character
        , NCHAR(7), N'')  -- U+0007 BELL
        , NCHAR(8), N'')  -- U+0008 control character
        , NCHAR(11), N'')  -- U+000B control character
        , NCHAR(12), N'')  -- U+000C control character
        , NCHAR(14), N'')  -- U+000E control character
        , NCHAR(15), N'')  -- U+000F control character
        , NCHAR(16), N'')  -- U+0010 control character
        , NCHAR(17), N'')  -- U+0011 control character
        , NCHAR(18), N'')  -- U+0012 control character
        , NCHAR(19), N'')  -- U+0013 control character
        , NCHAR(20), N'')  -- U+0014 control character
        , NCHAR(21), N'')  -- U+0015 control character
        , NCHAR(22), N'')  -- U+0016 control character
        , NCHAR(23), N'')  -- U+0017 control character
        , NCHAR(24), N'')  -- U+0018 control character
        , NCHAR(25), N'')  -- U+0019 control character
        , NCHAR(26), N'')  -- U+001A control character
        , NCHAR(27), N'')  -- U+001B control character
        , NCHAR(28), N'')  -- U+001C control character
        , NCHAR(29), N'')  -- U+001D control character
        , NCHAR(30), N'')  -- U+001E control character
        , NCHAR(31), N'')  -- U+001F control character
        , NCHAR(127), N'');  -- U+007F control character

    -- 3. Apostrophe look-alikes, and (v3 R8) double and other special quotation marks, read as the ASCII apostrophe / straight single quote
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(8217), N'''')  -- U+2019 RIGHT SINGLE QUOTATION MARK
        , NCHAR(8216), N'''')  -- U+2018 LEFT SINGLE QUOTATION MARK
        , NCHAR(8219), N'''')  -- U+201B SINGLE HIGH-REVERSED-9 QUOTATION MARK
        , NCHAR(700), N'''')  -- U+02BC MODIFIER LETTER APOSTROPHE
        , NCHAR(697), N'''')  -- U+02B9 MODIFIER LETTER PRIME
        , N'`', N'''')
        , NCHAR(180), N'''')  -- U+00B4 ACUTE ACCENT
        , NCHAR(8242), N'''')  -- U+2032 PRIME
        , NCHAR(65287), N'''')  -- U+FF07 FULLWIDTH APOSTROPHE
        , N'"', N'''')
        , NCHAR(8220), N'''')  -- U+201C LEFT DOUBLE QUOTATION MARK
        , NCHAR(8221), N'''')  -- U+201D RIGHT DOUBLE QUOTATION MARK
        , NCHAR(8222), N'''')  -- U+201E DOUBLE LOW-9 QUOTATION MARK
        , NCHAR(8223), N'''')  -- U+201F DOUBLE HIGH-REVERSED-9 QUOTATION MARK
        , NCHAR(8218), N'''')  -- U+201A SINGLE LOW-9 QUOTATION MARK
        , NCHAR(171), N'''')  -- U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
        , NCHAR(187), N'''')  -- U+00BB RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
        , NCHAR(8249), N'''')  -- U+2039 SINGLE LEFT-POINTING ANGLE QUOTATION MARK
        , NCHAR(8250), N'''')  -- U+203A SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
        , NCHAR(12317), N'''')  -- U+301D REVERSED DOUBLE PRIME QUOTATION MARK
        , NCHAR(12318), N'''')  -- U+301E DOUBLE PRIME QUOTATION MARK
        , NCHAR(12319), N'''')  -- U+301F LOW DOUBLE PRIME QUOTATION MARK
        , NCHAR(65282), N'''');  -- U+FF02 FULLWIDTH QUOTATION MARK

    -- 3b. (v3 R6) Greek letters written as their names, a space on each side: 'β-catenin' = 'beta-catenin', 'γδ' = 'gamma-delta'. The extra spaces are collapsed in step 5
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(945), N' alpha ')  -- U+03B1 GREEK SMALL LETTER ALPHA
        , NCHAR(913), N' Alpha ')  -- U+0391 GREEK CAPITAL LETTER ALPHA
        , NCHAR(946), N' beta ')  -- U+03B2 GREEK SMALL LETTER BETA
        , NCHAR(914), N' Beta ')  -- U+0392 GREEK CAPITAL LETTER BETA
        , NCHAR(947), N' gamma ')  -- U+03B3 GREEK SMALL LETTER GAMMA
        , NCHAR(915), N' Gamma ')  -- U+0393 GREEK CAPITAL LETTER GAMMA
        , NCHAR(948), N' delta ')  -- U+03B4 GREEK SMALL LETTER DELTA
        , NCHAR(916), N' Delta ')  -- U+0394 GREEK CAPITAL LETTER DELTA
        , NCHAR(949), N' epsilon ')  -- U+03B5 GREEK SMALL LETTER EPSILON
        , NCHAR(917), N' Epsilon ')  -- U+0395 GREEK CAPITAL LETTER EPSILON
        , NCHAR(950), N' zeta ')  -- U+03B6 GREEK SMALL LETTER ZETA
        , NCHAR(918), N' Zeta ')  -- U+0396 GREEK CAPITAL LETTER ZETA
        , NCHAR(951), N' eta ')  -- U+03B7 GREEK SMALL LETTER ETA
        , NCHAR(919), N' Eta ')  -- U+0397 GREEK CAPITAL LETTER ETA
        , NCHAR(952), N' theta ')  -- U+03B8 GREEK SMALL LETTER THETA
        , NCHAR(920), N' Theta ')  -- U+0398 GREEK CAPITAL LETTER THETA
        , NCHAR(953), N' iota ')  -- U+03B9 GREEK SMALL LETTER IOTA
        , NCHAR(921), N' Iota ')  -- U+0399 GREEK CAPITAL LETTER IOTA
        , NCHAR(954), N' kappa ')  -- U+03BA GREEK SMALL LETTER KAPPA
        , NCHAR(922), N' Kappa ')  -- U+039A GREEK CAPITAL LETTER KAPPA
        , NCHAR(955), N' lambda ')  -- U+03BB GREEK SMALL LETTER LAMDA
        , NCHAR(923), N' Lambda ')  -- U+039B GREEK CAPITAL LETTER LAMDA
        , NCHAR(956), N' mu ')  -- U+03BC GREEK SMALL LETTER MU
        , NCHAR(924), N' Mu ')  -- U+039C GREEK CAPITAL LETTER MU
        , NCHAR(957), N' nu ')  -- U+03BD GREEK SMALL LETTER NU
        , NCHAR(925), N' Nu ')  -- U+039D GREEK CAPITAL LETTER NU
        , NCHAR(958), N' xi ')  -- U+03BE GREEK SMALL LETTER XI
        , NCHAR(926), N' Xi ')  -- U+039E GREEK CAPITAL LETTER XI
        , NCHAR(959), N' omicron ')  -- U+03BF GREEK SMALL LETTER OMICRON
        , NCHAR(927), N' Omicron ');  -- U+039F GREEK CAPITAL LETTER OMICRON
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(960), N' pi ')  -- U+03C0 GREEK SMALL LETTER PI
        , NCHAR(928), N' Pi ')  -- U+03A0 GREEK CAPITAL LETTER PI
        , NCHAR(961), N' rho ')  -- U+03C1 GREEK SMALL LETTER RHO
        , NCHAR(929), N' Rho ')  -- U+03A1 GREEK CAPITAL LETTER RHO
        , NCHAR(962), N' sigma ')  -- U+03C2 GREEK SMALL LETTER FINAL SIGMA
        , NCHAR(963), N' sigma ')  -- U+03C3 GREEK SMALL LETTER SIGMA
        , NCHAR(931), N' Sigma ')  -- U+03A3 GREEK CAPITAL LETTER SIGMA
        , NCHAR(964), N' tau ')  -- U+03C4 GREEK SMALL LETTER TAU
        , NCHAR(932), N' Tau ')  -- U+03A4 GREEK CAPITAL LETTER TAU
        , NCHAR(965), N' upsilon ')  -- U+03C5 GREEK SMALL LETTER UPSILON
        , NCHAR(933), N' Upsilon ')  -- U+03A5 GREEK CAPITAL LETTER UPSILON
        , NCHAR(966), N' phi ')  -- U+03C6 GREEK SMALL LETTER PHI
        , NCHAR(934), N' Phi ')  -- U+03A6 GREEK CAPITAL LETTER PHI
        , NCHAR(967), N' chi ')  -- U+03C7 GREEK SMALL LETTER CHI
        , NCHAR(935), N' Chi ')  -- U+03A7 GREEK CAPITAL LETTER CHI
        , NCHAR(968), N' psi ')  -- U+03C8 GREEK SMALL LETTER PSI
        , NCHAR(936), N' Psi ')  -- U+03A8 GREEK CAPITAL LETTER PSI
        , NCHAR(969), N' omega ')  -- U+03C9 GREEK SMALL LETTER OMEGA
        , NCHAR(937), N' Omega ');  -- U+03A9 GREEK CAPITAL LETTER OMEGA

    -- 3c. (v3 R7) '&' -> 'and'
    SET @s = REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'&', N' and ');

    -- 4. Punctuation: commas and '#' removed; '::' (gene fusion), '/' and '-' become spaces (every other dash is already '-'), except a minus sign - U+2212 anywhere, or '-' right before ')' - which is kept ('CD34− tumor', 'ALK-)', '5q-)'); a space is put before every '(' (karyotypes are closed up again in step 6b)
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N',', N'')
        , N'#', N'')
        , N'::', N' ')
        , N'/', N' ')
        , NCHAR(8722), NCHAR(14))  -- U+2212 MINUS SIGN, U+000E control character
        , N'-)', NCHAR(14) + N')')  -- U+000E control character
        , N'-', N' ')
        , N'(', N' (');

    -- 5. Tidy the ends: collapse spaces, trim, leading '+'/'?' (as dbo.Clean), trailing '.'
    -- collapse runs of spaces without a loop: BEL marks each space, 'BEL +
    -- space' pairs are dropped, then leftover marks. BEL cannot come from the
    -- input: step 2 removed every control character.
    SET @s = REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2, N' ', N' ' + NCHAR(7)), NCHAR(7) + N' ', N''), NCHAR(7), N'');  -- U+0007 BELL used as a marker
    SET @s = LTRIM(@s, N'+? ');
    SET @s = RTRIM(@s, N'. ');

    -- 6. Mark the start and end with sentinels U+0002 / U+0003 so a word at either end has a boundary to match against
    SET @s = NCHAR(2) + @s + NCHAR(3);  -- U+0002 start sentinel, U+0003 end sentinel

    -- 6b. Karyotype notation closed up again: 't (9;22)' 'del (5q)' -> 't(9;22)' 'del(5q)'; and ') (p' / ') (q' -> ')(p' / ')(q': 'inv(16) (p13;q22)' -> 'inv(16)(p13;q22)'
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' t (', N' t(')
        , N'(t (', N'(t(')
        , N'+t (', N'+t(')
        , N';t (', N';t(')
        , NCHAR(2) + N't (', NCHAR(2) + N't(')  -- U+0002 start sentinel
        , N' inv (', N' inv(')
        , N'(inv (', N'(inv(')
        , N'+inv (', N'+inv(')
        , N';inv (', N';inv(')
        , NCHAR(2) + N'inv (', NCHAR(2) + N'inv(')  -- U+0002 start sentinel
        , N' del (', N' del(')
        , N'(del (', N'(del(')
        , N'+del (', N'+del(')
        , N';del (', N';del(')
        , NCHAR(2) + N'del (', NCHAR(2) + N'del(')  -- U+0002 start sentinel
        , N' der (', N' der(')
        , N'(der (', N'(der(')
        , N'+der (', N'+der(')
        , N';der (', N';der(')
        , NCHAR(2) + N'der (', NCHAR(2) + N'der(')  -- U+0002 start sentinel
        , N' dup (', N' dup(')
        , N'(dup (', N'(dup(')
        , N'+dup (', N'+dup(')
        , N';dup (', N';dup(')
        , NCHAR(2) + N'dup (', NCHAR(2) + N'dup(')  -- U+0002 start sentinel
        , N' ins (', N' ins(')
        , N'(ins (', N'(ins(')
        , N'+ins (', N'+ins(')
        , N';ins (', N';ins(')
        , NCHAR(2) + N'ins (', NCHAR(2) + N'ins(');  -- U+0002 start sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' i (', N' i(')
        , N'(i (', N'(i(')
        , N'+i (', N'+i(')
        , N';i (', N';i(')
        , NCHAR(2) + N'i (', NCHAR(2) + N'i(')  -- U+0002 start sentinel
        , N' add (', N' add(')
        , N'(add (', N'(add(')
        , N'+add (', N'+add(')
        , N';add (', N';add(')
        , NCHAR(2) + N'add (', NCHAR(2) + N'add(')  -- U+0002 start sentinel
        , N' idic (', N' idic(')
        , N'(idic (', N'(idic(')
        , N'+idic (', N'+idic(')
        , N';idic (', N';idic(')
        , NCHAR(2) + N'idic (', NCHAR(2) + N'idic(')  -- U+0002 start sentinel
        , N') (p', N')(p')
        , N') (q', N')(q');

    -- 7. Possessive 's dropped at a word end: "Paget's disease" = "Paget disease"
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'''s ', N' ')
        , N'''s)', N')')
        , N'''s]', N']')
        , N'''s}', N'}')
        , N'''s:', N':')
        , N'''s;', N';')
        , N'''s' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N'''s ', N' ')
        , N'''s)', N')')
        , N'''s]', N']')
        , N'''s}', N'}')
        , N'''s:', N':')
        , N'''s;', N';')
        , N'''s' + NCHAR(3), NCHAR(3));  -- U+0003 end sentinel

    -- 8. NOS removed - uppercase whole word only (never inside adenosquamous, nose ...). Before the numerals, so 'CIN III, NOS' ends in its numeral
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' NOS ', N' ')
        , N' NOS)', N')')
        , N' NOS]', N']')
        , N' NOS}', N'}')
        , N' NOS:', N':')
        , N' NOS;', N';')
        , N' NOS' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N'(NOS ', N'(')
        , N'(NOS)', N'')
        , N'(NOS]', N'(]')
        , N'(NOS}', N'(}')
        , N'(NOS:', N'(:')
        , N'(NOS;', N'(;')
        , N'(NOS' + NCHAR(3), N'(' + NCHAR(3))  -- U+0003 end sentinel
        , N'[NOS ', N'[')
        , N'[NOS)', N'[)')
        , N'[NOS]', N'')
        , N'[NOS}', N'[}')
        , N'[NOS:', N'[:')
        , N'[NOS;', N'[;')
        , N'[NOS' + NCHAR(3), N'[' + NCHAR(3))  -- U+0003 end sentinel
        , N'{NOS ', N'{')
        , N'{NOS)', N'{)')
        , N'{NOS]', N'{]')
        , N'{NOS}', N'')
        , N'{NOS:', N'{:')
        , N'{NOS;', N'{;')
        , N'{NOS' + NCHAR(3), N'{' + NCHAR(3))  -- U+0003 end sentinel
        , N':NOS ', N':')
        , N':NOS)', N':)');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N':NOS]', N':]')
        , N':NOS}', N':}')
        , N':NOS:', N'::')
        , N':NOS;', N':;')
        , N':NOS' + NCHAR(3), N':' + NCHAR(3))  -- U+0003 end sentinel
        , N';NOS ', N';')
        , N';NOS)', N';)')
        , N';NOS]', N';]')
        , N';NOS}', N';}')
        , N';NOS:', N';:')
        , N';NOS;', N';;')
        , N';NOS' + NCHAR(3), N';' + NCHAR(3))  -- U+0003 end sentinel
        , NCHAR(2) + N'NOS ', NCHAR(2))  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS)', NCHAR(2) + N')')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS]', NCHAR(2) + N']')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS}', NCHAR(2) + N'}')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS:', NCHAR(2) + N':')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS;', NCHAR(2) + N';')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS' + NCHAR(3), NCHAR(2) + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , N' NOS ', N' ')
        , N' NOS)', N')')
        , N' NOS]', N']')
        , N' NOS}', N'}')
        , N' NOS:', N':')
        , N' NOS;', N';')
        , N' NOS' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N'(NOS ', N'(')
        , N'(NOS)', N'')
        , N'(NOS]', N'(]')
        , N'(NOS}', N'(}');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'(NOS:', N'(:')
        , N'(NOS;', N'(;')
        , N'(NOS' + NCHAR(3), N'(' + NCHAR(3))  -- U+0003 end sentinel
        , N'[NOS ', N'[')
        , N'[NOS)', N'[)')
        , N'[NOS]', N'')
        , N'[NOS}', N'[}')
        , N'[NOS:', N'[:')
        , N'[NOS;', N'[;')
        , N'[NOS' + NCHAR(3), N'[' + NCHAR(3))  -- U+0003 end sentinel
        , N'{NOS ', N'{')
        , N'{NOS)', N'{)')
        , N'{NOS]', N'{]')
        , N'{NOS}', N'')
        , N'{NOS:', N'{:')
        , N'{NOS;', N'{;')
        , N'{NOS' + NCHAR(3), N'{' + NCHAR(3))  -- U+0003 end sentinel
        , N':NOS ', N':')
        , N':NOS)', N':)')
        , N':NOS]', N':]')
        , N':NOS}', N':}')
        , N':NOS:', N'::')
        , N':NOS;', N':;')
        , N':NOS' + NCHAR(3), N':' + NCHAR(3))  -- U+0003 end sentinel
        , N';NOS ', N';')
        , N';NOS)', N';)')
        , N';NOS]', N';]')
        , N';NOS}', N';}')
        , N';NOS:', N';:')
        , N';NOS;', N';;');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N';NOS' + NCHAR(3), N';' + NCHAR(3))  -- U+0003 end sentinel
        , NCHAR(2) + N'NOS ', NCHAR(2))  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS)', NCHAR(2) + N')')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS]', NCHAR(2) + N']')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS}', NCHAR(2) + N'}')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS:', NCHAR(2) + N':')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS;', NCHAR(2) + N';')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS' + NCHAR(3), NCHAR(2) + NCHAR(3));  -- U+0002 start sentinel, U+0003 end sentinel

    -- 8b. Close up the space a removal can leave next to the start/end sentinel, so a numeral exposed by it is still recognised as trailing
    SET @s = REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' ' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , NCHAR(2) + N' ', NCHAR(2));  -- U+0002 start sentinel
    -- collapse runs of spaces without a loop: BEL marks each space, 'BEL +
    -- space' pairs are dropped, then leftover marks. BEL cannot come from the
    -- input: step 2 removed every control character.
    SET @s = REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2, N' ', N' ' + NCHAR(7)), NCHAR(7) + N' ', N''), NCHAR(7), N'');  -- U+0007 BELL used as a marker
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N': :', N':')
        , N' ;', N';')
        , N' :', N':')
        , N'::', N':');

    -- 8c. (v3 R1) Articles: lowercase whole words 'the', 'a', 'an' removed - never the first or last word, and 'a'/'an' kept after a label word ('type a', 'hepatitis a'). Case-sensitive: 'A' (type A, group A) is never touched. Before step 9, so 'type a' is still recognisable
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'type a ', N'type ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'type a)', N'type ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'type a;', N'type ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'type a:', N'type ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'type a' + NCHAR(3), N'type ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'type an ', N'type ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'type an)', N'type ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'type an;', N'type ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'type an:', N'type ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'type an' + NCHAR(3), N'type ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Type a ', N'Type ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Type a)', N'Type ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Type a;', N'Type ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Type a:', N'Type ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Type a' + NCHAR(3), N'Type ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Type an ', N'Type ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Type an)', N'Type ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Type an;', N'Type ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Type an:', N'Type ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Type an' + NCHAR(3), N'Type ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'group a ', N'group ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'group a)', N'group ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'group a;', N'group ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'group a:', N'group ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'group a' + NCHAR(3), N'group ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'group an ', N'group ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'group an)', N'group ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'group an;', N'group ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'group an:', N'group ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'group an' + NCHAR(3), N'group ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'Group a ', N'Group ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Group a)', N'Group ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Group a;', N'Group ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Group a:', N'Group ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Group a' + NCHAR(3), N'Group ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Group an ', N'Group ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Group an)', N'Group ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Group an;', N'Group ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Group an:', N'Group ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Group an' + NCHAR(3), N'Group ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'grade a ', N'grade ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'grade a)', N'grade ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'grade a;', N'grade ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'grade a:', N'grade ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'grade a' + NCHAR(3), N'grade ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'grade an ', N'grade ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'grade an)', N'grade ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'grade an;', N'grade ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'grade an:', N'grade ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'grade an' + NCHAR(3), N'grade ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Grade a ', N'Grade ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Grade a)', N'Grade ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Grade a;', N'Grade ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Grade a:', N'Grade ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Grade a' + NCHAR(3), N'Grade ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Grade an ', N'Grade ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Grade an)', N'Grade ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Grade an;', N'Grade ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Grade an:', N'Grade ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Grade an' + NCHAR(3), N'Grade ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'class a ', N'class ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'class a)', N'class ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'class a;', N'class ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'class a:', N'class ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'class a' + NCHAR(3), N'class ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'class an ', N'class ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'class an)', N'class ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'class an;', N'class ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'class an:', N'class ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'class an' + NCHAR(3), N'class ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Class a ', N'Class ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Class a)', N'Class ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Class a;', N'Class ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Class a:', N'Class ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Class a' + NCHAR(3), N'Class ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Class an ', N'Class ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Class an)', N'Class ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Class an;', N'Class ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Class an:', N'Class ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Class an' + NCHAR(3), N'Class ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'subtype a ', N'subtype ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'subtype a)', N'subtype ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'subtype a;', N'subtype ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'subtype a:', N'subtype ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'subtype a' + NCHAR(3), N'subtype ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'subtype an ', N'subtype ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'subtype an)', N'subtype ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'subtype an;', N'subtype ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'subtype an:', N'subtype ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'subtype an' + NCHAR(3), N'subtype ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'Subtype a ', N'Subtype ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Subtype a)', N'Subtype ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Subtype a;', N'Subtype ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Subtype a:', N'Subtype ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Subtype a' + NCHAR(3), N'Subtype ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Subtype an ', N'Subtype ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Subtype an)', N'Subtype ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Subtype an;', N'Subtype ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Subtype an:', N'Subtype ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Subtype an' + NCHAR(3), N'Subtype ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'pattern a ', N'pattern ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'pattern a)', N'pattern ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'pattern a;', N'pattern ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'pattern a:', N'pattern ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'pattern a' + NCHAR(3), N'pattern ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'pattern an ', N'pattern ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'pattern an)', N'pattern ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'pattern an;', N'pattern ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'pattern an:', N'pattern ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'pattern an' + NCHAR(3), N'pattern ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Pattern a ', N'Pattern ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Pattern a)', N'Pattern ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Pattern a;', N'Pattern ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Pattern a:', N'Pattern ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Pattern a' + NCHAR(3), N'Pattern ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Pattern an ', N'Pattern ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Pattern an)', N'Pattern ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Pattern an;', N'Pattern ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Pattern an:', N'Pattern ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Pattern an' + NCHAR(3), N'Pattern ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'variant a ', N'variant ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'variant a)', N'variant ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'variant a;', N'variant ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'variant a:', N'variant ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'variant a' + NCHAR(3), N'variant ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'variant an ', N'variant ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'variant an)', N'variant ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'variant an;', N'variant ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'variant an:', N'variant ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'variant an' + NCHAR(3), N'variant ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Variant a ', N'Variant ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Variant a)', N'Variant ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Variant a;', N'Variant ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Variant a:', N'Variant ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Variant a' + NCHAR(3), N'Variant ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Variant an ', N'Variant ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Variant an)', N'Variant ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Variant an;', N'Variant ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Variant an:', N'Variant ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Variant an' + NCHAR(3), N'Variant ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'form a ', N'form ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'form a)', N'form ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'form a;', N'form ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'form a:', N'form ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'form a' + NCHAR(3), N'form ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'form an ', N'form ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'form an)', N'form ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'form an;', N'form ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'form an:', N'form ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'form an' + NCHAR(3), N'form ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'Form a ', N'Form ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Form a)', N'Form ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Form a;', N'Form ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Form a:', N'Form ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Form a' + NCHAR(3), N'Form ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Form an ', N'Form ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Form an)', N'Form ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Form an;', N'Form ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Form an:', N'Form ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Form an' + NCHAR(3), N'Form ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'hepatitis a ', N'hepatitis ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'hepatitis a)', N'hepatitis ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'hepatitis a;', N'hepatitis ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'hepatitis a:', N'hepatitis ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'hepatitis a' + NCHAR(3), N'hepatitis ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'hepatitis an ', N'hepatitis ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'hepatitis an)', N'hepatitis ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'hepatitis an;', N'hepatitis ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'hepatitis an:', N'hepatitis ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'hepatitis an' + NCHAR(3), N'hepatitis ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Hepatitis a ', N'Hepatitis ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Hepatitis a)', N'Hepatitis ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Hepatitis a;', N'Hepatitis ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Hepatitis a:', N'Hepatitis ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Hepatitis a' + NCHAR(3), N'Hepatitis ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Hepatitis an ', N'Hepatitis ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Hepatitis an)', N'Hepatitis ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Hepatitis an;', N'Hepatitis ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Hepatitis an:', N'Hepatitis ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Hepatitis an' + NCHAR(3), N'Hepatitis ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'vitamin a ', N'vitamin ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'vitamin a)', N'vitamin ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'vitamin a;', N'vitamin ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'vitamin a:', N'vitamin ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'vitamin a' + NCHAR(3), N'vitamin ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'vitamin an ', N'vitamin ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'vitamin an)', N'vitamin ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'vitamin an;', N'vitamin ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'vitamin an:', N'vitamin ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'vitamin an' + NCHAR(3), N'vitamin ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Vitamin a ', N'Vitamin ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Vitamin a)', N'Vitamin ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Vitamin a;', N'Vitamin ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Vitamin a:', N'Vitamin ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Vitamin a' + NCHAR(3), N'Vitamin ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Vitamin an ', N'Vitamin ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Vitamin an)', N'Vitamin ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Vitamin an;', N'Vitamin ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Vitamin an:', N'Vitamin ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Vitamin an' + NCHAR(3), N'Vitamin ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'factor a ', N'factor ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'factor a)', N'factor ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'factor a;', N'factor ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'factor a:', N'factor ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'factor a' + NCHAR(3), N'factor ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'factor an ', N'factor ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'factor an)', N'factor ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'factor an;', N'factor ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'factor an:', N'factor ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'factor an' + NCHAR(3), N'factor ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'Factor a ', N'Factor ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Factor a)', N'Factor ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Factor a;', N'Factor ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Factor a:', N'Factor ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Factor a' + NCHAR(3), N'Factor ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Factor an ', N'Factor ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Factor an)', N'Factor ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Factor an;', N'Factor ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Factor an:', N'Factor ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Factor an' + NCHAR(3), N'Factor ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'protein a ', N'protein ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'protein a)', N'protein ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'protein a;', N'protein ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'protein a:', N'protein ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'protein a' + NCHAR(3), N'protein ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'protein an ', N'protein ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'protein an)', N'protein ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'protein an;', N'protein ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'protein an:', N'protein ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'protein an' + NCHAR(3), N'protein ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Protein a ', N'Protein ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Protein a)', N'Protein ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Protein a;', N'Protein ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Protein a:', N'Protein ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Protein a' + NCHAR(3), N'Protein ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Protein an ', N'Protein ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Protein an)', N'Protein ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Protein an;', N'Protein ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Protein an:', N'Protein ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Protein an' + NCHAR(3), N'Protein ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' the ', N' ')
        , N' the)', N')')
        , N' the]', N']')
        , N' the}', N'}')
        , N' the:', N':')
        , N' the;', N';')
        , N'(the ', N'(')
        , N'(the]', N'(]')
        , N'(the}', N'(}')
        , N'(the:', N'(:')
        , N'(the;', N'(;')
        , N'[the ', N'[')
        , N'[the)', N'[)')
        , N'[the}', N'[}')
        , N'[the:', N'[:')
        , N'[the;', N'[;')
        , N'{the ', N'{')
        , N'{the)', N'{)')
        , N'{the]', N'{]')
        , N'{the:', N'{:')
        , N'{the;', N'{;')
        , N':the ', N':')
        , N':the)', N':)')
        , N':the]', N':]')
        , N':the}', N':}')
        , N':the:', N'::')
        , N':the;', N':;')
        , N';the ', N';')
        , N';the)', N';)')
        , N';the]', N';]');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N';the}', N';}')
        , N';the:', N';:')
        , N';the;', N';;')
        , N' a ', N' ')
        , N' a)', N')')
        , N' a]', N']')
        , N' a}', N'}')
        , N' a:', N':')
        , N' a;', N';')
        , N'(a ', N'(')
        , N'(a]', N'(]')
        , N'(a}', N'(}')
        , N'(a:', N'(:')
        , N'(a;', N'(;')
        , N'[a ', N'[')
        , N'[a)', N'[)')
        , N'[a}', N'[}')
        , N'[a:', N'[:')
        , N'[a;', N'[;')
        , N'{a ', N'{')
        , N'{a)', N'{)')
        , N'{a]', N'{]')
        , N'{a:', N'{:')
        , N'{a;', N'{;')
        , N':a ', N':')
        , N':a)', N':)')
        , N':a]', N':]')
        , N':a}', N':}')
        , N':a:', N'::')
        , N':a;', N':;');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N';a ', N';')
        , N';a)', N';)')
        , N';a]', N';]')
        , N';a}', N';}')
        , N';a:', N';:')
        , N';a;', N';;')
        , N' an ', N' ')
        , N' an)', N')')
        , N' an]', N']')
        , N' an}', N'}')
        , N' an:', N':')
        , N' an;', N';')
        , N'(an ', N'(')
        , N'(an]', N'(]')
        , N'(an}', N'(}')
        , N'(an:', N'(:')
        , N'(an;', N'(;')
        , N'[an ', N'[')
        , N'[an)', N'[)')
        , N'[an}', N'[}')
        , N'[an:', N'[:')
        , N'[an;', N'[;')
        , N'{an ', N'{')
        , N'{an)', N'{)')
        , N'{an]', N'{]')
        , N'{an:', N'{:')
        , N'{an;', N'{;')
        , N':an ', N':')
        , N':an)', N':)')
        , N':an]', N':]');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N':an}', N':}')
        , N':an:', N'::')
        , N':an;', N':;')
        , N';an ', N';')
        , N';an)', N';)')
        , N';an]', N';]')
        , N';an}', N';}')
        , N';an:', N';:')
        , N';an;', N';;')
        , N' the ', N' ')
        , N' a ', N' ')
        , N' an ', N' ')
        , N' ' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N': :', N':')
        , N' ;', N';')
        , N' :', N':')
        , N'::', N':');

    -- 9. Trailing Roman numerals. 'Trailing' = at the end of the string, or at the end of a closing parenthetical. Mid-string numerals are left alone. Order: 'type <roman>' first (it needs the word), then the word 'type' goes (9b), then grade and acronym numerals - so 'Grade III type' ends in its numeral when those rules look

    -- 9a. type <roman> -> <digit>: the word 'type' is dropped (maintainer decision)
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' type IV)', N' 4)')
        , N' type IV' + NCHAR(3), N' 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' type IV ', N' 4 ')
        , N' type IV;', N' 4;')
        , N' type IV:', N' 4:')
        , N'(type IV)', N'(4)')
        , N'(type IV' + NCHAR(3), N'(4' + NCHAR(3))  -- U+0003 end sentinel
        , N'(type IV ', N'(4 ')
        , N'(type IV;', N'(4;')
        , N'(type IV:', N'(4:')
        , NCHAR(2) + N'type IV ', NCHAR(2) + N'type 4 ')  -- U+0002 start sentinel
        , N' type III)', N' 3)')
        , N' type III' + NCHAR(3), N' 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' type III ', N' 3 ')
        , N' type III;', N' 3;')
        , N' type III:', N' 3:')
        , N'(type III)', N'(3)')
        , N'(type III' + NCHAR(3), N'(3' + NCHAR(3))  -- U+0003 end sentinel
        , N'(type III ', N'(3 ')
        , N'(type III;', N'(3;')
        , N'(type III:', N'(3:')
        , NCHAR(2) + N'type III ', NCHAR(2) + N'type 3 ')  -- U+0002 start sentinel
        , N' type II)', N' 2)')
        , N' type II' + NCHAR(3), N' 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' type II ', N' 2 ')
        , N' type II;', N' 2;')
        , N' type II:', N' 2:')
        , N'(type II)', N'(2)')
        , N'(type II' + NCHAR(3), N'(2' + NCHAR(3))  -- U+0003 end sentinel
        , N'(type II ', N'(2 ');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'(type II;', N'(2;')
        , N'(type II:', N'(2:')
        , NCHAR(2) + N'type II ', NCHAR(2) + N'type 2 ')  -- U+0002 start sentinel
        , N' type I)', N' 1)')
        , N' type I' + NCHAR(3), N' 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' type I ', N' 1 ')
        , N' type I;', N' 1;')
        , N' type I:', N' 1:')
        , N'(type I)', N'(1)')
        , N'(type I' + NCHAR(3), N'(1' + NCHAR(3))  -- U+0003 end sentinel
        , N'(type I ', N'(1 ')
        , N'(type I;', N'(1;')
        , N'(type I:', N'(1:')
        , NCHAR(2) + N'type I ', NCHAR(2) + N'type 1 ')  -- U+0002 start sentinel
        , N' Type IV)', N' 4)')
        , N' Type IV' + NCHAR(3), N' 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' Type IV ', N' 4 ')
        , N' Type IV;', N' 4;')
        , N' Type IV:', N' 4:')
        , N'(Type IV)', N'(4)')
        , N'(Type IV' + NCHAR(3), N'(4' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Type IV ', N'(4 ')
        , N'(Type IV;', N'(4;')
        , N'(Type IV:', N'(4:')
        , NCHAR(2) + N'Type IV ', NCHAR(2) + N'Type 4 ')  -- U+0002 start sentinel
        , N' Type III)', N' 3)')
        , N' Type III' + NCHAR(3), N' 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' Type III ', N' 3 ')
        , N' Type III;', N' 3;')
        , N' Type III:', N' 3:');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'(Type III)', N'(3)')
        , N'(Type III' + NCHAR(3), N'(3' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Type III ', N'(3 ')
        , N'(Type III;', N'(3;')
        , N'(Type III:', N'(3:')
        , NCHAR(2) + N'Type III ', NCHAR(2) + N'Type 3 ')  -- U+0002 start sentinel
        , N' Type II)', N' 2)')
        , N' Type II' + NCHAR(3), N' 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' Type II ', N' 2 ')
        , N' Type II;', N' 2;')
        , N' Type II:', N' 2:')
        , N'(Type II)', N'(2)')
        , N'(Type II' + NCHAR(3), N'(2' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Type II ', N'(2 ')
        , N'(Type II;', N'(2;')
        , N'(Type II:', N'(2:')
        , NCHAR(2) + N'Type II ', NCHAR(2) + N'Type 2 ')  -- U+0002 start sentinel
        , N' Type I)', N' 1)')
        , N' Type I' + NCHAR(3), N' 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' Type I ', N' 1 ')
        , N' Type I;', N' 1;')
        , N' Type I:', N' 1:')
        , N'(Type I)', N'(1)')
        , N'(Type I' + NCHAR(3), N'(1' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Type I ', N'(1 ')
        , N'(Type I;', N'(1;')
        , N'(Type I:', N'(1:')
        , NCHAR(2) + N'Type I ', NCHAR(2) + N'Type 1 ')  -- U+0002 start sentinel
        , N' TYPE IV)', N' 4)')
        , N' TYPE IV' + NCHAR(3), N' 4' + NCHAR(3));  -- U+0003 end sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' TYPE IV ', N' 4 ')
        , N' TYPE IV;', N' 4;')
        , N' TYPE IV:', N' 4:')
        , N'(TYPE IV)', N'(4)')
        , N'(TYPE IV' + NCHAR(3), N'(4' + NCHAR(3))  -- U+0003 end sentinel
        , N'(TYPE IV ', N'(4 ')
        , N'(TYPE IV;', N'(4;')
        , N'(TYPE IV:', N'(4:')
        , NCHAR(2) + N'TYPE IV ', NCHAR(2) + N'TYPE 4 ')  -- U+0002 start sentinel
        , N' TYPE III)', N' 3)')
        , N' TYPE III' + NCHAR(3), N' 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' TYPE III ', N' 3 ')
        , N' TYPE III;', N' 3;')
        , N' TYPE III:', N' 3:')
        , N'(TYPE III)', N'(3)')
        , N'(TYPE III' + NCHAR(3), N'(3' + NCHAR(3))  -- U+0003 end sentinel
        , N'(TYPE III ', N'(3 ')
        , N'(TYPE III;', N'(3;')
        , N'(TYPE III:', N'(3:')
        , NCHAR(2) + N'TYPE III ', NCHAR(2) + N'TYPE 3 ')  -- U+0002 start sentinel
        , N' TYPE II)', N' 2)')
        , N' TYPE II' + NCHAR(3), N' 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' TYPE II ', N' 2 ')
        , N' TYPE II;', N' 2;')
        , N' TYPE II:', N' 2:')
        , N'(TYPE II)', N'(2)')
        , N'(TYPE II' + NCHAR(3), N'(2' + NCHAR(3))  -- U+0003 end sentinel
        , N'(TYPE II ', N'(2 ')
        , N'(TYPE II;', N'(2;')
        , N'(TYPE II:', N'(2:');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(2) + N'TYPE II ', NCHAR(2) + N'TYPE 2 ')  -- U+0002 start sentinel
        , N' TYPE I)', N' 1)')
        , N' TYPE I' + NCHAR(3), N' 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' TYPE I ', N' 1 ')
        , N' TYPE I;', N' 1;')
        , N' TYPE I:', N' 1:')
        , N'(TYPE I)', N'(1)')
        , N'(TYPE I' + NCHAR(3), N'(1' + NCHAR(3))  -- U+0003 end sentinel
        , N'(TYPE I ', N'(1 ')
        , N'(TYPE I;', N'(1;')
        , N'(TYPE I:', N'(1:')
        , NCHAR(2) + N'TYPE I ', NCHAR(2) + N'TYPE 1 ');  -- U+0002 start sentinel

    -- 9b. The word 'type' removed - whole word, any of type/Type/TYPE, never as the first word ('Type A thymoma' keeps it); 'types', 'subtype', 'typical' untouched
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'type ' + NCHAR(15), N'type' + NCHAR(17) + NCHAR(15))  -- U+000F control character, U+0011 control character
        , N'Type ' + NCHAR(15), N'Type' + NCHAR(17) + NCHAR(15))  -- U+000F control character, U+0011 control character
        , N'TYPE ' + NCHAR(15), N'TYPE' + NCHAR(17) + NCHAR(15))  -- U+000F control character, U+0011 control character
        , N' type ', N' ')
        , N' type)', N')')
        , N' type]', N']')
        , N' type}', N'}')
        , N' type:', N':')
        , N' type;', N';')
        , N' type' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N'(type ', N'(')
        , N'(type)', N'')
        , N'(type]', N'(]')
        , N'(type}', N'(}')
        , N'(type:', N'(:')
        , N'(type;', N'(;')
        , N'(type' + NCHAR(3), N'(' + NCHAR(3))  -- U+0003 end sentinel
        , N'[type ', N'[')
        , N'[type)', N'[)')
        , N'[type]', N'')
        , N'[type}', N'[}')
        , N'[type:', N'[:')
        , N'[type;', N'[;')
        , N'[type' + NCHAR(3), N'[' + NCHAR(3))  -- U+0003 end sentinel
        , N'{type ', N'{')
        , N'{type)', N'{)')
        , N'{type]', N'{]')
        , N'{type}', N'')
        , N'{type:', N'{:')
        , N'{type;', N'{;');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'{type' + NCHAR(3), N'{' + NCHAR(3))  -- U+0003 end sentinel
        , N':type ', N':')
        , N':type)', N':)')
        , N':type]', N':]')
        , N':type}', N':}')
        , N':type:', N'::')
        , N':type;', N':;')
        , N':type' + NCHAR(3), N':' + NCHAR(3))  -- U+0003 end sentinel
        , N';type ', N';')
        , N';type)', N';)')
        , N';type]', N';]')
        , N';type}', N';}')
        , N';type:', N';:')
        , N';type;', N';;')
        , N';type' + NCHAR(3), N';' + NCHAR(3))  -- U+0003 end sentinel
        , N' Type ', N' ')
        , N' Type)', N')')
        , N' Type]', N']')
        , N' Type}', N'}')
        , N' Type:', N':')
        , N' Type;', N';')
        , N' Type' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N'(Type ', N'(')
        , N'(Type)', N'')
        , N'(Type]', N'(]')
        , N'(Type}', N'(}')
        , N'(Type:', N'(:')
        , N'(Type;', N'(;')
        , N'(Type' + NCHAR(3), N'(' + NCHAR(3))  -- U+0003 end sentinel
        , N'[Type ', N'[');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'[Type)', N'[)')
        , N'[Type]', N'')
        , N'[Type}', N'[}')
        , N'[Type:', N'[:')
        , N'[Type;', N'[;')
        , N'[Type' + NCHAR(3), N'[' + NCHAR(3))  -- U+0003 end sentinel
        , N'{Type ', N'{')
        , N'{Type)', N'{)')
        , N'{Type]', N'{]')
        , N'{Type}', N'')
        , N'{Type:', N'{:')
        , N'{Type;', N'{;')
        , N'{Type' + NCHAR(3), N'{' + NCHAR(3))  -- U+0003 end sentinel
        , N':Type ', N':')
        , N':Type)', N':)')
        , N':Type]', N':]')
        , N':Type}', N':}')
        , N':Type:', N'::')
        , N':Type;', N':;')
        , N':Type' + NCHAR(3), N':' + NCHAR(3))  -- U+0003 end sentinel
        , N';Type ', N';')
        , N';Type)', N';)')
        , N';Type]', N';]')
        , N';Type}', N';}')
        , N';Type:', N';:')
        , N';Type;', N';;')
        , N';Type' + NCHAR(3), N';' + NCHAR(3))  -- U+0003 end sentinel
        , N' TYPE ', N' ')
        , N' TYPE)', N')')
        , N' TYPE]', N']');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' TYPE}', N'}')
        , N' TYPE:', N':')
        , N' TYPE;', N';')
        , N' TYPE' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N'(TYPE ', N'(')
        , N'(TYPE)', N'')
        , N'(TYPE]', N'(]')
        , N'(TYPE}', N'(}')
        , N'(TYPE:', N'(:')
        , N'(TYPE;', N'(;')
        , N'(TYPE' + NCHAR(3), N'(' + NCHAR(3))  -- U+0003 end sentinel
        , N'[TYPE ', N'[')
        , N'[TYPE)', N'[)')
        , N'[TYPE]', N'')
        , N'[TYPE}', N'[}')
        , N'[TYPE:', N'[:')
        , N'[TYPE;', N'[;')
        , N'[TYPE' + NCHAR(3), N'[' + NCHAR(3))  -- U+0003 end sentinel
        , N'{TYPE ', N'{')
        , N'{TYPE)', N'{)')
        , N'{TYPE]', N'{]')
        , N'{TYPE}', N'')
        , N'{TYPE:', N'{:')
        , N'{TYPE;', N'{;')
        , N'{TYPE' + NCHAR(3), N'{' + NCHAR(3))  -- U+0003 end sentinel
        , N':TYPE ', N':')
        , N':TYPE)', N':)')
        , N':TYPE]', N':]')
        , N':TYPE}', N':}')
        , N':TYPE:', N'::');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N':TYPE;', N':;')
        , N':TYPE' + NCHAR(3), N':' + NCHAR(3))  -- U+0003 end sentinel
        , N';TYPE ', N';')
        , N';TYPE)', N';)')
        , N';TYPE]', N';]')
        , N';TYPE}', N';}')
        , N';TYPE:', N';:')
        , N';TYPE;', N';;')
        , N';TYPE' + NCHAR(3), N';' + NCHAR(3))  -- U+0003 end sentinel
        , N' type ', N' ')
        , N' Type ', N' ')
        , N' TYPE ', N' ');

    -- 9c. Close up again after the 'type' removal
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' ' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N': :', N':')
        , N' ;', N';')
        , N' :', N':')
        , N'::', N':');

    -- 9d. grade <roman> -> grade <digit>: the word 'grade' is kept
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' grade IV)', N' grade 4)')
        , N' grade IV' + NCHAR(3), N' grade 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' grade IV ', N' grade 4 ')
        , N' grade IV;', N' grade 4;')
        , N' grade IV:', N' grade 4:')
        , N'(grade IV)', N'(grade 4)')
        , N'(grade IV' + NCHAR(3), N'(grade 4' + NCHAR(3))  -- U+0003 end sentinel
        , N'(grade IV ', N'(grade 4 ')
        , N'(grade IV;', N'(grade 4;')
        , N'(grade IV:', N'(grade 4:')
        , NCHAR(2) + N'grade IV)', NCHAR(2) + N'grade 4)')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade IV' + NCHAR(3), NCHAR(2) + N'grade 4' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'grade IV ', NCHAR(2) + N'grade 4 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade IV;', NCHAR(2) + N'grade 4;')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade IV:', NCHAR(2) + N'grade 4:')  -- U+0002 start sentinel
        , N' grade III)', N' grade 3)')
        , N' grade III' + NCHAR(3), N' grade 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' grade III ', N' grade 3 ')
        , N' grade III;', N' grade 3;')
        , N' grade III:', N' grade 3:')
        , N'(grade III)', N'(grade 3)')
        , N'(grade III' + NCHAR(3), N'(grade 3' + NCHAR(3))  -- U+0003 end sentinel
        , N'(grade III ', N'(grade 3 ')
        , N'(grade III;', N'(grade 3;')
        , N'(grade III:', N'(grade 3:')
        , NCHAR(2) + N'grade III)', NCHAR(2) + N'grade 3)')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade III' + NCHAR(3), NCHAR(2) + N'grade 3' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'grade III ', NCHAR(2) + N'grade 3 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade III;', NCHAR(2) + N'grade 3;')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade III:', NCHAR(2) + N'grade 3:');  -- U+0002 start sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' grade II)', N' grade 2)')
        , N' grade II' + NCHAR(3), N' grade 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' grade II ', N' grade 2 ')
        , N' grade II;', N' grade 2;')
        , N' grade II:', N' grade 2:')
        , N'(grade II)', N'(grade 2)')
        , N'(grade II' + NCHAR(3), N'(grade 2' + NCHAR(3))  -- U+0003 end sentinel
        , N'(grade II ', N'(grade 2 ')
        , N'(grade II;', N'(grade 2;')
        , N'(grade II:', N'(grade 2:')
        , NCHAR(2) + N'grade II)', NCHAR(2) + N'grade 2)')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade II' + NCHAR(3), NCHAR(2) + N'grade 2' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'grade II ', NCHAR(2) + N'grade 2 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade II;', NCHAR(2) + N'grade 2;')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade II:', NCHAR(2) + N'grade 2:')  -- U+0002 start sentinel
        , N' grade I)', N' grade 1)')
        , N' grade I' + NCHAR(3), N' grade 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' grade I ', N' grade 1 ')
        , N' grade I;', N' grade 1;')
        , N' grade I:', N' grade 1:')
        , N'(grade I)', N'(grade 1)')
        , N'(grade I' + NCHAR(3), N'(grade 1' + NCHAR(3))  -- U+0003 end sentinel
        , N'(grade I ', N'(grade 1 ')
        , N'(grade I;', N'(grade 1;')
        , N'(grade I:', N'(grade 1:')
        , NCHAR(2) + N'grade I)', NCHAR(2) + N'grade 1)')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade I' + NCHAR(3), NCHAR(2) + N'grade 1' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'grade I ', NCHAR(2) + N'grade 1 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade I;', NCHAR(2) + N'grade 1;')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade I:', NCHAR(2) + N'grade 1:');  -- U+0002 start sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' Grade IV)', N' Grade 4)')
        , N' Grade IV' + NCHAR(3), N' Grade 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' Grade IV ', N' Grade 4 ')
        , N' Grade IV;', N' Grade 4;')
        , N' Grade IV:', N' Grade 4:')
        , N'(Grade IV)', N'(Grade 4)')
        , N'(Grade IV' + NCHAR(3), N'(Grade 4' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Grade IV ', N'(Grade 4 ')
        , N'(Grade IV;', N'(Grade 4;')
        , N'(Grade IV:', N'(Grade 4:')
        , NCHAR(2) + N'Grade IV)', NCHAR(2) + N'Grade 4)')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade IV' + NCHAR(3), NCHAR(2) + N'Grade 4' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'Grade IV ', NCHAR(2) + N'Grade 4 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade IV;', NCHAR(2) + N'Grade 4;')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade IV:', NCHAR(2) + N'Grade 4:')  -- U+0002 start sentinel
        , N' Grade III)', N' Grade 3)')
        , N' Grade III' + NCHAR(3), N' Grade 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' Grade III ', N' Grade 3 ')
        , N' Grade III;', N' Grade 3;')
        , N' Grade III:', N' Grade 3:')
        , N'(Grade III)', N'(Grade 3)')
        , N'(Grade III' + NCHAR(3), N'(Grade 3' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Grade III ', N'(Grade 3 ')
        , N'(Grade III;', N'(Grade 3;')
        , N'(Grade III:', N'(Grade 3:')
        , NCHAR(2) + N'Grade III)', NCHAR(2) + N'Grade 3)')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade III' + NCHAR(3), NCHAR(2) + N'Grade 3' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'Grade III ', NCHAR(2) + N'Grade 3 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade III;', NCHAR(2) + N'Grade 3;')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade III:', NCHAR(2) + N'Grade 3:');  -- U+0002 start sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' Grade II)', N' Grade 2)')
        , N' Grade II' + NCHAR(3), N' Grade 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' Grade II ', N' Grade 2 ')
        , N' Grade II;', N' Grade 2;')
        , N' Grade II:', N' Grade 2:')
        , N'(Grade II)', N'(Grade 2)')
        , N'(Grade II' + NCHAR(3), N'(Grade 2' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Grade II ', N'(Grade 2 ')
        , N'(Grade II;', N'(Grade 2;')
        , N'(Grade II:', N'(Grade 2:')
        , NCHAR(2) + N'Grade II)', NCHAR(2) + N'Grade 2)')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade II' + NCHAR(3), NCHAR(2) + N'Grade 2' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'Grade II ', NCHAR(2) + N'Grade 2 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade II;', NCHAR(2) + N'Grade 2;')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade II:', NCHAR(2) + N'Grade 2:')  -- U+0002 start sentinel
        , N' Grade I)', N' Grade 1)')
        , N' Grade I' + NCHAR(3), N' Grade 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' Grade I ', N' Grade 1 ')
        , N' Grade I;', N' Grade 1;')
        , N' Grade I:', N' Grade 1:')
        , N'(Grade I)', N'(Grade 1)')
        , N'(Grade I' + NCHAR(3), N'(Grade 1' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Grade I ', N'(Grade 1 ')
        , N'(Grade I;', N'(Grade 1;')
        , N'(Grade I:', N'(Grade 1:')
        , NCHAR(2) + N'Grade I)', NCHAR(2) + N'Grade 1)')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade I' + NCHAR(3), NCHAR(2) + N'Grade 1' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'Grade I ', NCHAR(2) + N'Grade 1 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade I;', NCHAR(2) + N'Grade 1;')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade I:', NCHAR(2) + N'Grade 1:');  -- U+0002 start sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' GRADE IV)', N' GRADE 4)')
        , N' GRADE IV' + NCHAR(3), N' GRADE 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' GRADE IV ', N' GRADE 4 ')
        , N' GRADE IV;', N' GRADE 4;')
        , N' GRADE IV:', N' GRADE 4:')
        , N'(GRADE IV)', N'(GRADE 4)')
        , N'(GRADE IV' + NCHAR(3), N'(GRADE 4' + NCHAR(3))  -- U+0003 end sentinel
        , N'(GRADE IV ', N'(GRADE 4 ')
        , N'(GRADE IV;', N'(GRADE 4;')
        , N'(GRADE IV:', N'(GRADE 4:')
        , NCHAR(2) + N'GRADE IV)', NCHAR(2) + N'GRADE 4)')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE IV' + NCHAR(3), NCHAR(2) + N'GRADE 4' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'GRADE IV ', NCHAR(2) + N'GRADE 4 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE IV;', NCHAR(2) + N'GRADE 4;')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE IV:', NCHAR(2) + N'GRADE 4:')  -- U+0002 start sentinel
        , N' GRADE III)', N' GRADE 3)')
        , N' GRADE III' + NCHAR(3), N' GRADE 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' GRADE III ', N' GRADE 3 ')
        , N' GRADE III;', N' GRADE 3;')
        , N' GRADE III:', N' GRADE 3:')
        , N'(GRADE III)', N'(GRADE 3)')
        , N'(GRADE III' + NCHAR(3), N'(GRADE 3' + NCHAR(3))  -- U+0003 end sentinel
        , N'(GRADE III ', N'(GRADE 3 ')
        , N'(GRADE III;', N'(GRADE 3;')
        , N'(GRADE III:', N'(GRADE 3:')
        , NCHAR(2) + N'GRADE III)', NCHAR(2) + N'GRADE 3)')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE III' + NCHAR(3), NCHAR(2) + N'GRADE 3' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'GRADE III ', NCHAR(2) + N'GRADE 3 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE III;', NCHAR(2) + N'GRADE 3;')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE III:', NCHAR(2) + N'GRADE 3:');  -- U+0002 start sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' GRADE II)', N' GRADE 2)')
        , N' GRADE II' + NCHAR(3), N' GRADE 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' GRADE II ', N' GRADE 2 ')
        , N' GRADE II;', N' GRADE 2;')
        , N' GRADE II:', N' GRADE 2:')
        , N'(GRADE II)', N'(GRADE 2)')
        , N'(GRADE II' + NCHAR(3), N'(GRADE 2' + NCHAR(3))  -- U+0003 end sentinel
        , N'(GRADE II ', N'(GRADE 2 ')
        , N'(GRADE II;', N'(GRADE 2;')
        , N'(GRADE II:', N'(GRADE 2:')
        , NCHAR(2) + N'GRADE II)', NCHAR(2) + N'GRADE 2)')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE II' + NCHAR(3), NCHAR(2) + N'GRADE 2' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'GRADE II ', NCHAR(2) + N'GRADE 2 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE II;', NCHAR(2) + N'GRADE 2;')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE II:', NCHAR(2) + N'GRADE 2:')  -- U+0002 start sentinel
        , N' GRADE I)', N' GRADE 1)')
        , N' GRADE I' + NCHAR(3), N' GRADE 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' GRADE I ', N' GRADE 1 ')
        , N' GRADE I;', N' GRADE 1;')
        , N' GRADE I:', N' GRADE 1:')
        , N'(GRADE I)', N'(GRADE 1)')
        , N'(GRADE I' + NCHAR(3), N'(GRADE 1' + NCHAR(3))  -- U+0003 end sentinel
        , N'(GRADE I ', N'(GRADE 1 ')
        , N'(GRADE I;', N'(GRADE 1;')
        , N'(GRADE I:', N'(GRADE 1:')
        , NCHAR(2) + N'GRADE I)', NCHAR(2) + N'GRADE 1)')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE I' + NCHAR(3), NCHAR(2) + N'GRADE 1' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'GRADE I ', NCHAR(2) + N'GRADE 1 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE I;', NCHAR(2) + N'GRADE 1;')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE I:', NCHAR(2) + N'GRADE 1:');  -- U+0002 start sentinel

    -- 9d-ii. a numeral right after a converted one: 'grade II/III' -> 'grade 2 III' -> 'grade 2 3'
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' 1 IV)', N' 1 4)')
        , N' 1 IV' + NCHAR(3), N' 1 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' 1 IV ', N' 1 4 ')
        , N' 1 IV;', N' 1 4;')
        , N' 1 IV:', N' 1 4:')
        , N' 1 III)', N' 1 3)')
        , N' 1 III' + NCHAR(3), N' 1 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' 1 III ', N' 1 3 ')
        , N' 1 III;', N' 1 3;')
        , N' 1 III:', N' 1 3:')
        , N' 1 II)', N' 1 2)')
        , N' 1 II' + NCHAR(3), N' 1 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' 1 II ', N' 1 2 ')
        , N' 1 II;', N' 1 2;')
        , N' 1 II:', N' 1 2:')
        , N' 1 I)', N' 1 1)')
        , N' 1 I' + NCHAR(3), N' 1 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' 1 I ', N' 1 1 ')
        , N' 1 I;', N' 1 1;')
        , N' 1 I:', N' 1 1:')
        , N' 2 IV)', N' 2 4)')
        , N' 2 IV' + NCHAR(3), N' 2 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' 2 IV ', N' 2 4 ')
        , N' 2 IV;', N' 2 4;')
        , N' 2 IV:', N' 2 4:')
        , N' 2 III)', N' 2 3)')
        , N' 2 III' + NCHAR(3), N' 2 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' 2 III ', N' 2 3 ')
        , N' 2 III;', N' 2 3;')
        , N' 2 III:', N' 2 3:');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' 2 II)', N' 2 2)')
        , N' 2 II' + NCHAR(3), N' 2 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' 2 II ', N' 2 2 ')
        , N' 2 II;', N' 2 2;')
        , N' 2 II:', N' 2 2:')
        , N' 2 I)', N' 2 1)')
        , N' 2 I' + NCHAR(3), N' 2 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' 2 I ', N' 2 1 ')
        , N' 2 I;', N' 2 1;')
        , N' 2 I:', N' 2 1:')
        , N' 3 IV)', N' 3 4)')
        , N' 3 IV' + NCHAR(3), N' 3 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' 3 IV ', N' 3 4 ')
        , N' 3 IV;', N' 3 4;')
        , N' 3 IV:', N' 3 4:')
        , N' 3 III)', N' 3 3)')
        , N' 3 III' + NCHAR(3), N' 3 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' 3 III ', N' 3 3 ')
        , N' 3 III;', N' 3 3;')
        , N' 3 III:', N' 3 3:')
        , N' 3 II)', N' 3 2)')
        , N' 3 II' + NCHAR(3), N' 3 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' 3 II ', N' 3 2 ')
        , N' 3 II;', N' 3 2;')
        , N' 3 II:', N' 3 2:')
        , N' 3 I)', N' 3 1)')
        , N' 3 I' + NCHAR(3), N' 3 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' 3 I ', N' 3 1 ')
        , N' 3 I;', N' 3 1;')
        , N' 3 I:', N' 3 1:');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' 4 IV)', N' 4 4)')
        , N' 4 IV' + NCHAR(3), N' 4 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' 4 IV ', N' 4 4 ')
        , N' 4 IV;', N' 4 4;')
        , N' 4 IV:', N' 4 4:')
        , N' 4 III)', N' 4 3)')
        , N' 4 III' + NCHAR(3), N' 4 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' 4 III ', N' 4 3 ')
        , N' 4 III;', N' 4 3;')
        , N' 4 III:', N' 4 3:')
        , N' 4 II)', N' 4 2)')
        , N' 4 II' + NCHAR(3), N' 4 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' 4 II ', N' 4 2 ')
        , N' 4 II;', N' 4 2;')
        , N' 4 II:', N' 4 2:')
        , N' 4 I)', N' 4 1)')
        , N' 4 I' + NCHAR(3), N' 4 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' 4 I ', N' 4 1 ')
        , N' 4 I;', N' 4 1;')
        , N' 4 I:', N' 4 1:');

    -- 9e. ALL-CAPS acronym + roman -> acronym + digit (CIN III = CIN 3, RAEB II = RAEB 2). Rule: the two characters before the trailing numeral are both A-Z. Done with plain replacements and markers instead of a LIKE test, so SQL Server can inline it

    -- 9e-i. mark the space before a whole-word I/II/III (followed by a space, ')' or the end)
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' III ', NCHAR(4) + N'III ')  -- U+0004 control character
        , N' III)', NCHAR(4) + N'III)')  -- U+0004 control character
        , N' III' + NCHAR(3), NCHAR(4) + N'III' + NCHAR(3))  -- U+0003 end sentinel, U+0004 control character
        , N' III;', NCHAR(4) + N'III;')  -- U+0004 control character
        , N' III:', NCHAR(4) + N'III:')  -- U+0004 control character
        , N' II ', NCHAR(4) + N'II ')  -- U+0004 control character
        , N' II)', NCHAR(4) + N'II)')  -- U+0004 control character
        , N' II' + NCHAR(3), NCHAR(4) + N'II' + NCHAR(3))  -- U+0003 end sentinel, U+0004 control character
        , N' II;', NCHAR(4) + N'II;')  -- U+0004 control character
        , N' II:', NCHAR(4) + N'II:')  -- U+0004 control character
        , N' I ', NCHAR(4) + N'I ')  -- U+0004 control character
        , N' I)', NCHAR(4) + N'I)')  -- U+0004 control character
        , N' I' + NCHAR(3), NCHAR(4) + N'I' + NCHAR(3))  -- U+0003 end sentinel, U+0004 control character
        , N' I;', NCHAR(4) + N'I;')  -- U+0004 control character
        , N' I:', NCHAR(4) + N'I:');  -- U+0004 control character

    -- 9e-ii. a capital right before the mark gets a marker in front of it ...
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'A' + NCHAR(4), NCHAR(5) + N'A' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'B' + NCHAR(4), NCHAR(5) + N'B' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'C' + NCHAR(4), NCHAR(5) + N'C' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'D' + NCHAR(4), NCHAR(5) + N'D' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'E' + NCHAR(4), NCHAR(5) + N'E' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'F' + NCHAR(4), NCHAR(5) + N'F' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'G' + NCHAR(4), NCHAR(5) + N'G' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'H' + NCHAR(4), NCHAR(5) + N'H' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'I' + NCHAR(4), NCHAR(5) + N'I' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'J' + NCHAR(4), NCHAR(5) + N'J' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'K' + NCHAR(4), NCHAR(5) + N'K' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'L' + NCHAR(4), NCHAR(5) + N'L' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'M' + NCHAR(4), NCHAR(5) + N'M' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'N' + NCHAR(4), NCHAR(5) + N'N' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'O' + NCHAR(4), NCHAR(5) + N'O' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'P' + NCHAR(4), NCHAR(5) + N'P' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'Q' + NCHAR(4), NCHAR(5) + N'Q' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'R' + NCHAR(4), NCHAR(5) + N'R' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'S' + NCHAR(4), NCHAR(5) + N'S' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'T' + NCHAR(4), NCHAR(5) + N'T' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'U' + NCHAR(4), NCHAR(5) + N'U' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'V' + NCHAR(4), NCHAR(5) + N'V' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'W' + NCHAR(4), NCHAR(5) + N'W' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'X' + NCHAR(4), NCHAR(5) + N'X' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'Y' + NCHAR(4), NCHAR(5) + N'Y' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'Z' + NCHAR(4), NCHAR(5) + N'Z' + NCHAR(4));  -- U+0004 control character, U+0005 control character

    -- 9e-iii. ... which is promoted if the character before THAT is also a capital
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'A' + NCHAR(5), N'A' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'B' + NCHAR(5), N'B' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'C' + NCHAR(5), N'C' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'D' + NCHAR(5), N'D' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'E' + NCHAR(5), N'E' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'F' + NCHAR(5), N'F' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'G' + NCHAR(5), N'G' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'H' + NCHAR(5), N'H' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'I' + NCHAR(5), N'I' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'J' + NCHAR(5), N'J' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'K' + NCHAR(5), N'K' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'L' + NCHAR(5), N'L' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'M' + NCHAR(5), N'M' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'N' + NCHAR(5), N'N' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'O' + NCHAR(5), N'O' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'P' + NCHAR(5), N'P' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'Q' + NCHAR(5), N'Q' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'R' + NCHAR(5), N'R' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'S' + NCHAR(5), N'S' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'T' + NCHAR(5), N'T' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'U' + NCHAR(5), N'U' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'V' + NCHAR(5), N'V' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'W' + NCHAR(5), N'W' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'X' + NCHAR(5), N'X' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'Y' + NCHAR(5), N'Y' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'Z' + NCHAR(5), N'Z' + NCHAR(6));  -- U+0005 control character, U+0006 control character

    -- 9e-iv. two capitals confirmed: the space mark becomes the convert mark
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(6) + N'A' + NCHAR(4), N'A' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'B' + NCHAR(4), N'B' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'C' + NCHAR(4), N'C' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'D' + NCHAR(4), N'D' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'E' + NCHAR(4), N'E' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'F' + NCHAR(4), N'F' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'G' + NCHAR(4), N'G' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'H' + NCHAR(4), N'H' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'I' + NCHAR(4), N'I' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'J' + NCHAR(4), N'J' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'K' + NCHAR(4), N'K' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'L' + NCHAR(4), N'L' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'M' + NCHAR(4), N'M' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'N' + NCHAR(4), N'N' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'O' + NCHAR(4), N'O' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'P' + NCHAR(4), N'P' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'Q' + NCHAR(4), N'Q' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'R' + NCHAR(4), N'R' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'S' + NCHAR(4), N'S' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'T' + NCHAR(4), N'T' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'U' + NCHAR(4), N'U' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'V' + NCHAR(4), N'V' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'W' + NCHAR(4), N'W' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'X' + NCHAR(4), N'X' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'Y' + NCHAR(4), N'Y' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'Z' + NCHAR(4), N'Z' + NCHAR(8));  -- U+0006 control character, U+0004 control character, U+0008 control character

    -- 9e-v. convert the confirmed numeral, then remove all markers (restoring the space)
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(8) + N'III ', N' 3 ')  -- U+0008 control character
        , NCHAR(8) + N'III)', N' 3)')  -- U+0008 control character
        , NCHAR(8) + N'III' + NCHAR(3), N' 3' + NCHAR(3))  -- U+0008 control character, U+0003 end sentinel
        , NCHAR(8) + N'III;', N' 3;')  -- U+0008 control character
        , NCHAR(8) + N'III:', N' 3:')  -- U+0008 control character
        , NCHAR(8) + N'II ', N' 2 ')  -- U+0008 control character
        , NCHAR(8) + N'II)', N' 2)')  -- U+0008 control character
        , NCHAR(8) + N'II' + NCHAR(3), N' 2' + NCHAR(3))  -- U+0008 control character, U+0003 end sentinel
        , NCHAR(8) + N'II;', N' 2;')  -- U+0008 control character
        , NCHAR(8) + N'II:', N' 2:')  -- U+0008 control character
        , NCHAR(8) + N'I ', N' 1 ')  -- U+0008 control character
        , NCHAR(8) + N'I)', N' 1)')  -- U+0008 control character
        , NCHAR(8) + N'I' + NCHAR(3), N' 1' + NCHAR(3))  -- U+0008 control character, U+0003 end sentinel
        , NCHAR(8) + N'I;', N' 1;')  -- U+0008 control character
        , NCHAR(8) + N'I:', N' 1:')  -- U+0008 control character
        , NCHAR(5), N'')  -- U+0005 control character
        , NCHAR(6), N'')  -- U+0006 control character
        , NCHAR(4), N' ')  -- U+0004 control character
        , NCHAR(8), N' ');  -- U+0008 control character

    -- 9f. (v3) The space before a karyotype ('pre t(9;22)', 'Non del(5q)') is protected, so steps 10/10b never glue a word onto it (a second pass would split it again)
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' t(', NCHAR(17) + N't(')  -- U+0011 control character
        , N' inv(', NCHAR(17) + N'inv(')  -- U+0011 control character
        , N' del(', NCHAR(17) + N'del(')  -- U+0011 control character
        , N' der(', NCHAR(17) + N'der(')  -- U+0011 control character
        , N' dup(', NCHAR(17) + N'dup(')  -- U+0011 control character
        , N' ins(', NCHAR(17) + N'ins(')  -- U+0011 control character
        , N' i(', NCHAR(17) + N'i(')  -- U+0011 control character
        , N' add(', NCHAR(17) + N'add(')  -- U+0011 control character
        , N' idic(', NCHAR(17) + N'idic(');  -- U+0011 control character

    -- 10. The whole word non/Non/NON joins the next word: 'Non small' = 'Nonsmall'
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' non ', N' non')
        , N'(non ', N'(non')
        , N'[non ', N'[non')
        , N'{non ', N'{non')
        , N':non ', N':non')
        , N';non ', N';non')
        , NCHAR(2) + N'non ', NCHAR(2) + N'non')  -- U+0002 start sentinel
        , N' Non ', N' Non')
        , N'(Non ', N'(Non')
        , N'[Non ', N'[Non')
        , N'{Non ', N'{Non')
        , N':Non ', N':Non')
        , N';Non ', N';Non')
        , NCHAR(2) + N'Non ', NCHAR(2) + N'Non')  -- U+0002 start sentinel
        , N' NON ', N' NON')
        , N'(NON ', N'(NON')
        , N'[NON ', N'[NON')
        , N'{NON ', N'{NON')
        , N':NON ', N':NON')
        , N';NON ', N';NON')
        , NCHAR(2) + N'NON ', NCHAR(2) + N'NON')  -- U+0002 start sentinel
        , N' non ', N' non')
        , N'(non ', N'(non')
        , N'[non ', N'[non')
        , N'{non ', N'{non')
        , N':non ', N':non')
        , N';non ', N';non')
        , NCHAR(2) + N'non ', NCHAR(2) + N'non')  -- U+0002 start sentinel
        , N' Non ', N' Non')
        , N'(Non ', N'(Non');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'[Non ', N'[Non')
        , N'{Non ', N'{Non')
        , N':Non ', N':Non')
        , N';Non ', N';Non')
        , NCHAR(2) + N'Non ', NCHAR(2) + N'Non')  -- U+0002 start sentinel
        , N' NON ', N' NON')
        , N'(NON ', N'(NON')
        , N'[NON ', N'[NON')
        , N'{NON ', N'{NON')
        , N':NON ', N':NON')
        , N';NON ', N';NON')
        , NCHAR(2) + N'NON ', NCHAR(2) + N'NON');  -- U+0002 start sentinel

    -- 10b. Bound prefixes join the next word like 'non': 'micro invasive' = 'microinvasive'; (v3 R5) a repeated prefix first: 'pre pre B' -> 'prepreB'
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' micro micro ', N' micromicro')
        , N' micro ', N' micro')
        , N'(micro micro ', N'(micromicro')
        , N'(micro ', N'(micro')
        , NCHAR(2) + N'micro micro ', NCHAR(2) + N'micromicro')  -- U+0002 start sentinel
        , NCHAR(2) + N'micro ', NCHAR(2) + N'micro')  -- U+0002 start sentinel
        , N'micromicro ', N'micromicro')
        , N' Micro micro ', N' Micromicro')
        , N' Micro ', N' Micro')
        , N'(Micro micro ', N'(Micromicro')
        , N'(Micro ', N'(Micro')
        , NCHAR(2) + N'Micro micro ', NCHAR(2) + N'Micromicro')  -- U+0002 start sentinel
        , NCHAR(2) + N'Micro ', NCHAR(2) + N'Micro')  -- U+0002 start sentinel
        , N'Micromicro ', N'Micromicro')
        , N' pre pre ', N' prepre')
        , N' pre ', N' pre')
        , N'(pre pre ', N'(prepre')
        , N'(pre ', N'(pre')
        , NCHAR(2) + N'pre pre ', NCHAR(2) + N'prepre')  -- U+0002 start sentinel
        , NCHAR(2) + N'pre ', NCHAR(2) + N'pre')  -- U+0002 start sentinel
        , N'prepre ', N'prepre')
        , N' Pre pre ', N' Prepre')
        , N' Pre ', N' Pre')
        , N'(Pre pre ', N'(Prepre')
        , N'(Pre ', N'(Pre')
        , NCHAR(2) + N'Pre pre ', NCHAR(2) + N'Prepre')  -- U+0002 start sentinel
        , NCHAR(2) + N'Pre ', NCHAR(2) + N'Pre')  -- U+0002 start sentinel
        , N'Prepre ', N'Prepre')
        , N' post post ', N' postpost')
        , N' post ', N' post');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'(post post ', N'(postpost')
        , N'(post ', N'(post')
        , NCHAR(2) + N'post post ', NCHAR(2) + N'postpost')  -- U+0002 start sentinel
        , NCHAR(2) + N'post ', NCHAR(2) + N'post')  -- U+0002 start sentinel
        , N'postpost ', N'postpost')
        , N' Post post ', N' Postpost')
        , N' Post ', N' Post')
        , N'(Post post ', N'(Postpost')
        , N'(Post ', N'(Post')
        , NCHAR(2) + N'Post post ', NCHAR(2) + N'Postpost')  -- U+0002 start sentinel
        , NCHAR(2) + N'Post ', NCHAR(2) + N'Post')  -- U+0002 start sentinel
        , N'Postpost ', N'Postpost')
        , N' extra extra ', N' extraextra')
        , N' extra ', N' extra')
        , N'(extra extra ', N'(extraextra')
        , N'(extra ', N'(extra')
        , NCHAR(2) + N'extra extra ', NCHAR(2) + N'extraextra')  -- U+0002 start sentinel
        , NCHAR(2) + N'extra ', NCHAR(2) + N'extra')  -- U+0002 start sentinel
        , N'extraextra ', N'extraextra')
        , N' Extra extra ', N' Extraextra')
        , N' Extra ', N' Extra')
        , N'(Extra extra ', N'(Extraextra')
        , N'(Extra ', N'(Extra')
        , NCHAR(2) + N'Extra extra ', NCHAR(2) + N'Extraextra')  -- U+0002 start sentinel
        , NCHAR(2) + N'Extra ', NCHAR(2) + N'Extra')  -- U+0002 start sentinel
        , N'Extraextra ', N'Extraextra')
        , N' poly poly ', N' polypoly')
        , N' poly ', N' poly')
        , N'(poly poly ', N'(polypoly')
        , N'(poly ', N'(poly');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(2) + N'poly poly ', NCHAR(2) + N'polypoly')  -- U+0002 start sentinel
        , NCHAR(2) + N'poly ', NCHAR(2) + N'poly')  -- U+0002 start sentinel
        , N'polypoly ', N'polypoly')
        , N' Poly poly ', N' Polypoly')
        , N' Poly ', N' Poly')
        , N'(Poly poly ', N'(Polypoly')
        , N'(Poly ', N'(Poly')
        , NCHAR(2) + N'Poly poly ', NCHAR(2) + N'Polypoly')  -- U+0002 start sentinel
        , NCHAR(2) + N'Poly ', NCHAR(2) + N'Poly')  -- U+0002 start sentinel
        , N'Polypoly ', N'Polypoly')
        , N' atrio atrio ', N' atrioatrio')
        , N' atrio ', N' atrio')
        , N'(atrio atrio ', N'(atrioatrio')
        , N'(atrio ', N'(atrio')
        , NCHAR(2) + N'atrio atrio ', NCHAR(2) + N'atrioatrio')  -- U+0002 start sentinel
        , NCHAR(2) + N'atrio ', NCHAR(2) + N'atrio')  -- U+0002 start sentinel
        , N'atrioatrio ', N'atrioatrio')
        , N' Atrio atrio ', N' Atrioatrio')
        , N' Atrio ', N' Atrio')
        , N'(Atrio atrio ', N'(Atrioatrio')
        , N'(Atrio ', N'(Atrio')
        , NCHAR(2) + N'Atrio atrio ', NCHAR(2) + N'Atrioatrio')  -- U+0002 start sentinel
        , NCHAR(2) + N'Atrio ', NCHAR(2) + N'Atrio')  -- U+0002 start sentinel
        , N'Atrioatrio ', N'Atrioatrio')
        , N' tubulo tubulo ', N' tubulotubulo')
        , N' tubulo ', N' tubulo')
        , N'(tubulo tubulo ', N'(tubulotubulo')
        , N'(tubulo ', N'(tubulo')
        , NCHAR(2) + N'tubulo tubulo ', NCHAR(2) + N'tubulotubulo')  -- U+0002 start sentinel
        , NCHAR(2) + N'tubulo ', NCHAR(2) + N'tubulo');  -- U+0002 start sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'tubulotubulo ', N'tubulotubulo')
        , N' Tubulo tubulo ', N' Tubulotubulo')
        , N' Tubulo ', N' Tubulo')
        , N'(Tubulo tubulo ', N'(Tubulotubulo')
        , N'(Tubulo ', N'(Tubulo')
        , NCHAR(2) + N'Tubulo tubulo ', NCHAR(2) + N'Tubulotubulo')  -- U+0002 start sentinel
        , NCHAR(2) + N'Tubulo ', NCHAR(2) + N'Tubulo')  -- U+0002 start sentinel
        , N'Tubulotubulo ', N'Tubulotubulo')
        , N' bronchiolo bronchiolo ', N' bronchiolobronchiolo')
        , N' bronchiolo ', N' bronchiolo')
        , N'(bronchiolo bronchiolo ', N'(bronchiolobronchiolo')
        , N'(bronchiolo ', N'(bronchiolo')
        , NCHAR(2) + N'bronchiolo bronchiolo ', NCHAR(2) + N'bronchiolobronchiolo')  -- U+0002 start sentinel
        , NCHAR(2) + N'bronchiolo ', NCHAR(2) + N'bronchiolo')  -- U+0002 start sentinel
        , N'bronchiolobronchiolo ', N'bronchiolobronchiolo')
        , N' Bronchiolo bronchiolo ', N' Bronchiolobronchiolo')
        , N' Bronchiolo ', N' Bronchiolo')
        , N'(Bronchiolo bronchiolo ', N'(Bronchiolobronchiolo')
        , N'(Bronchiolo ', N'(Bronchiolo')
        , NCHAR(2) + N'Bronchiolo bronchiolo ', NCHAR(2) + N'Bronchiolobronchiolo')  -- U+0002 start sentinel
        , NCHAR(2) + N'Bronchiolo ', NCHAR(2) + N'Bronchiolo')  -- U+0002 start sentinel
        , N'Bronchiolobronchiolo ', N'Bronchiolobronchiolo');

    -- 12. Remove the sentinels; collapse spaces BEFORE tidying parentheses (a removal can leave two spaces after '('); tidy the ends again, since removals can expose a leading '+'/'?' or trailing '.'
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(2), N'')  -- U+0002 start sentinel
        , NCHAR(3), N'')  -- U+0003 end sentinel
        , NCHAR(14), NCHAR(8722))  -- U+000E control character, U+2212 MINUS SIGN
        , NCHAR(15), N'')  -- U+000F control character
        , NCHAR(17), N' ');  -- U+0011 control character
    -- collapse runs of spaces without a loop: BEL marks each space, 'BEL +
    -- space' pairs are dropped, then leftover marks. BEL cannot come from the
    -- input: step 2 removed every control character.
    SET @s = REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2, N' ', N' ' + NCHAR(7)), NCHAR(7) + N' ', N''), NCHAR(7), N'');  -- U+0007 BELL used as a marker
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'( ', N'(')
        , N' )', N')')
        , N'()', N'')
        , N'{(', N'{ (')
        , N'[(', N'[ (')
        , N': :', N':')
        , N' ;', N';')
        , N' :', N':')
        , N'::', N':');
    -- collapse runs of spaces without a loop: BEL marks each space, 'BEL +
    -- space' pairs are dropped, then leftover marks. BEL cannot come from the
    -- input: step 2 removed every control character.
    SET @s = REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2, N' ', N' ' + NCHAR(7)), NCHAR(7) + N' ', N''), NCHAR(7), N'');  -- U+0007 BELL used as a marker
    SET @s = LTRIM(@s, N'+? ');
    SET @s = RTRIM(@s, N'. ;:');

    RETURN @s;
END


GO
